#!/usr/bin/env python3
"""rbs - RISC-V bootstrap: preparation-host source & dependency tool.

PREPARATION-HOST ONLY. Never runs on the RISC-V target.

Subcommands
  list                      show packages
  pin     [PKG...]          download, verify upstream signature, record sha256 in package.sh
  fetch   [PKG...]          download if missing and verify recorded sha256 (strict)
  analyze [PKG...]          extract sources and statically scan build systems
  probe   PKG               run upstream configure under a tracing PATH (host-native),
                            record every executable actually invoked
  resolve                   build dependency graph, detect cycles, topo-sort,
                            write manifest.lock (JSON) and manifest.order (plain text)

Package metadata lives in packages/<name>/package.sh. Only top-level
`pkg_*=` assignments are read here; shell functions are for the target.
"""
import argparse, hashlib, json, os, re, shutil, subprocess, sys, tarfile, tempfile, time, urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PKGDIR = os.path.join(ROOT, "packages")
SRCDIR = os.path.join(ROOT, "sources")
KEYDIR = os.path.join(ROOT, "keys")
ANADIR = os.path.join(ROOT, "build", "analysis")
TARGET = "riscv64-unknown-linux-musl"

LIST_FIELDS = ("build_tools", "build_deps", "runtime_deps", "provides", "outputs",
               "optional_tools", "cycle_break", "provides_files")

# --------------------------------------------------------------------- metadata
ASSIGN = re.compile(r'^(pkg_[a-z0-9_]+)=(.*)$')

def _expand(val, env):
    return re.sub(r'\$\{(pkg_[a-z0-9_]+)\}', lambda m: env.get(m.group(1), m.group(0)), val)

def parse_pkg(path):
    """Parse top-level pkg_* assignments. Supports "..." / '...' / bare, incl. multi-line quotes."""
    env, lines, i = {}, open(path).read().split("\n"), 0
    while i < len(lines):
        m = ASSIGN.match(lines[i])
        i += 1
        if not m:
            continue
        key, rest = m.group(1), m.group(2)
        if rest[:1] in ('"', "'"):
            q = rest[0]
            buf = rest[1:]
            while q not in buf:
                buf += "\n" + lines[i]; i += 1
            val = buf[:buf.index(q)]
            if q == '"':
                val = _expand(val, env)
        else:
            val = _expand(rest.split("#")[0].strip(), env)
        env[key] = val
    meta = {k[4:]: v for k, v in env.items()}
    for f in LIST_FIELDS:
        meta[f] = meta.get(f, "").split()
    meta["stage"] = int(meta.get("stage", "99"))
    meta["_path"] = path
    if meta.get("name") != os.path.basename(os.path.dirname(path)):
        sys.exit(f"error: {path}: pkg_name must equal directory name")
    for req in ("name", "version", "source_url", "verify"):
        if not meta.get(req):
            sys.exit(f"error: {path}: missing pkg_{req}")
    return meta

def load_all():
    pk = {}
    for d in sorted(os.listdir(PKGDIR)):
        p = os.path.join(PKGDIR, d, "package.sh")
        if os.path.isfile(p):
            pk[d] = parse_pkg(p)
    return pk

def select(pk, names):
    if not names:
        return list(pk.values())
    bad = [n for n in names if n not in pk]
    if bad:
        sys.exit(f"error: unknown package(s): {' '.join(bad)}")
    return [pk[n] for n in names]

def src_file(m):
    return os.path.join(SRCDIR, os.path.basename(m["source_url"]))

# --------------------------------------------------------------------- download
def download(url, dest):
    if os.path.exists(dest):
        return dest
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    tmp = dest + ".part"
    for attempt in range(4):
        try:
            # curl honours the agent proxy/CA config of the prep host
            subprocess.run(["curl", "-fsSL", "--retry", "3", "-o", tmp, url], check=True)
            os.replace(tmp, dest)
            print(f"  downloaded {os.path.basename(dest)}")
            return dest
        except subprocess.CalledProcessError:
            time.sleep(2 ** attempt)
    sys.exit(f"error: download failed: {url}")

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()

def keyring(name):
    """Return a dearmored keyring usable by gpgv, built under build/keyrings."""
    src = os.path.join(KEYDIR, name)
    if not os.path.exists(src):
        sys.exit(f"error: key file {src} missing; run keys/fetch-keys.sh")
    out = os.path.join(ROOT, "build", "keyrings", name + ".kbx")
    if not os.path.exists(out) or os.path.getmtime(out) < os.path.getmtime(src):
        os.makedirs(os.path.dirname(out), exist_ok=True)
        data = open(src, "rb").read()
        if b"-----BEGIN PGP" in data:
            data = subprocess.run(["gpg", "--dearmor"], input=data, capture_output=True, check=True).stdout
        open(out, "wb").write(data)
    return out

def gpgv(kr, *args):
    r = subprocess.run(["gpgv", "--keyring", kr, *args], capture_output=True, text=True)
    return r.returncode == 0, r.stderr

def verify_upstream(m, path):
    """Verify a downloaded file with its upstream signature. Returns a description string."""
    method = m["verify"]
    kind, _, arg = method.partition(":")
    if kind == "gpg-detached":
        sig = download(m["sig_url"], path + "." + m["sig_url"].rsplit(".", 1)[1])
        ok, err = gpgv(keyring(arg), sig, path)
        if not ok:
            sys.exit(f"error: BAD SIGNATURE for {path}\n{err}")
        signer = re.findall(r'using \S+ key (\S+)', err)
        return f"gpg-detached ok ({arg}, key {signer[0] if signer else '?'})"
    if kind == "gpg-sums":
        keyname, _, sums_url = arg.partition(":")
        sums = download(sums_url, os.path.join(SRCDIR, "kernel-sha256sums.asc"))
        ok, err = gpgv(keyring(keyname), sums)
        if not ok:
            sys.exit(f"error: BAD SIGNATURE on {sums_url}\n{err}")
        want = [l.split()[0] for l in open(sums) if l.strip().endswith(" " + os.path.basename(path))]
        if not want or want[0] != sha256(path):
            sys.exit(f"error: {path} does not match signed checksum list")
        return f"gpg-signed sha256sums ok ({keyname})"
    if kind == "gpg-clearsigned-sums":
        # busybox publishes <file>.sig as a clear-signed sha256 sum list
        sig = download(m["sig_url"], path + ".sig")
        ok, err = gpgv(keyring(arg), sig)
        if not ok:
            sys.exit(f"error: BAD SIGNATURE on {m['sig_url']}\n{err}")
        txt = open(sig).read()
        if sha256(path) not in txt:
            sys.exit(f"error: {path} sha256 not present in signed {sig}")
        return f"gpg clear-signed checksum ok ({arg})"
    if kind == "tofu":
        return "tofu (no verifiable upstream key on allowed hosts; sha256 pinned at first fetch)"
    sys.exit(f"error: {m['name']}: unknown verify method {method}")

def set_sha(m, digest):
    p = m["_path"]
    txt = open(p).read()
    txt, n = re.subn(r'^pkg_sha256=.*$', f'pkg_sha256={digest}', txt, flags=re.M)
    if n != 1:
        sys.exit(f"error: {p}: needs exactly one pkg_sha256= line")
    open(p, "w").write(txt)

def cmd_pin(a):
    pk = load_all()
    log = {}
    lp = os.path.join(ROOT, "build", "verification.json")
    if os.path.exists(lp):
        log = json.load(open(lp))
    for m in select(pk, a.pkgs):
        path = download(m["source_url"], src_file(m))
        how = verify_upstream(m, path)
        d = sha256(path)
        if m.get("sha256") and m["sha256"] != d:
            sys.exit(f"error: {m['name']}: pinned sha256 {m['sha256']} != downloaded {d}. Refusing to re-pin.")
        set_sha(m, d)
        log[m["name"]] = {"file": os.path.basename(path), "sha256": d, "verification": how}
        print(f"{m['name']:22} {d}  {how}")
        os.makedirs(os.path.dirname(lp), exist_ok=True)
        json.dump(log, open(lp, "w"), indent=2, sort_keys=True)

def cmd_fetch(a):
    pk = load_all()
    bad = 0
    for m in select(pk, a.pkgs):
        if not m.get("sha256"):
            print(f"error: {m['name']}: no pkg_sha256 recorded; run 'rbs.py pin {m['name']}'"); bad += 1; continue
        path = download(m["source_url"], src_file(m))
        d = sha256(path)
        if d != m["sha256"]:
            print(f"error: {m['name']}: CHECKSUM MISMATCH {d} != {m['sha256']}"); bad += 1
        else:
            print(f"ok  {m['name']:22} {os.path.basename(path)}")
    sys.exit(1 if bad else 0)

# --------------------------------------------------------------------- analysis
AC_PROG = {
    "AC_PROG_CC": ["cc"], "AC_PROG_CXX": ["c++"], "AC_PROG_CPP": ["cpp"],
    "AC_PROG_AWK": ["awk"], "AC_PROG_SED": ["sed"], "AC_PROG_GREP": ["grep"],
    "AC_PROG_EGREP": ["grep"], "AC_PROG_FGREP": ["grep"], "AC_PROG_YACC": ["yacc"],
    "AC_PROG_LEX": ["lex"], "AM_PROG_LEX": ["lex"], "AC_PROG_RANLIB": ["ranlib"],
    "AM_PROG_AR": ["ar"], "AC_PROG_INSTALL": ["install"], "AC_PROG_MKDIR_P": ["mkdir"],
    "AC_PROG_LN_S": ["ln"], "AM_INIT_AUTOMAKE": ["make"], "AC_PROG_MAKE_SET": ["make"],
    "gl_EARLY": ["m4-runtime?"], "AM_PROG_AS": ["as"], "LT_INIT": ["sed", "grep"],
    "AC_PROG_LIBTOOL": ["sed", "grep"], "AM_PATH_PYTHON": ["python3"],
    "AC_PATH_PROG_PERL": ["perl"], "AM_GNU_GETTEXT": ["gettext?"],
}
PROGCALL = re.compile(r'\b(AC_(?:CHECK|PATH)_(?:PROGS?|TOOLS?|TARGET_TOOLS?))\(\s*\[?(\w+)\]?\s*,\s*\[?([^\],)]+)')
KNOWN_TOOLS = {"perl", "python", "python3", "bison", "yacc", "flex", "lex", "m4", "makeinfo",
               "texi2dvi", "help2man", "bc", "awk", "gawk", "sed", "grep", "tar", "xz", "gzip",
               "bzip2", "patch", "diff", "cmp", "find", "xargs", "install", "cpio", "gperf",
               "autoconf", "automake", "autoreconf", "libtool", "pkg-config", "cmake", "ninja",
               "meson", "openssl", "expect", "runtest", "git", "ld", "as", "ar", "ranlib",
               "objcopy", "objdump", "nm", "strip", "readelf", "msgfmt", "xgettext", "dtc"}

def extract(m):
    # keyed by source file: packages sharing a tarball share one extraction
    dest = os.path.join(ANADIR, "src", re.sub(r'\.tar\..*$', '', os.path.basename(m["source_url"])))
    stamp = os.path.join(dest, ".extracted-" + (m.get("sha256") or "unpinned"))
    if os.path.exists(stamp):
        return dest
    shutil.rmtree(dest, ignore_errors=True)
    os.makedirs(dest)
    path = src_file(m)
    if not os.path.exists(path):
        sys.exit(f"error: {path} missing; run fetch first")
    subprocess.run(["tar", "-xf", path, "-C", dest, "--no-same-owner"], check=True)
    open(stamp, "w").close()
    return dest

def top(dest):
    ents = [e for e in os.listdir(dest) if not e.startswith(".")]
    return os.path.join(dest, ents[0]) if len(ents) == 1 else dest

def analyze_tree(srcroot):
    found = {"required": set(), "potential": set(), "libraries": set(), "pkgconfig": set(),
             "cmake_packages": set(), "shebangs": set(), "build_system": set()}
    # LLVM is huge; limit the walk for monorepos.
    for dirpath, dirs, files in os.walk(srcroot):
        dirs[:] = [d for d in dirs if d not in (".git", "test", "tests", "testsuite", "unittests", "doc", "docs")]
        depth = dirpath[len(srcroot):].count(os.sep)
        for f in files:
            p = os.path.join(dirpath, f)
            if f in ("configure.ac", "configure.in"):
                found["build_system"].add("autoconf")
                txt = open(p, errors="replace").read()
                for mac, tools in AC_PROG.items():
                    if re.search(r'\b' + mac + r'\b', txt):
                        found["required"].update(t for t in tools if not t.endswith("?"))
                for _, var, names in PROGCALL.findall(txt):
                    found["potential"].update(n for n in names.split() if re.match(r'^[\w.+-]+$', n))
                found["libraries"].update(re.findall(r'AC_(?:CHECK|SEARCH)_LIBS?\(\s*\[?(\w+)', txt))
                found["pkgconfig"].update(re.findall(r'PKG_CHECK_MODULES\(\s*\[?\w+\]?\s*,\s*\[?([\w.+-]+)', txt))
            elif f == "CMakeLists.txt" and depth <= 2:
                found["build_system"].add("cmake")
                txt = open(p, errors="replace").read()
                found["cmake_packages"].update(re.findall(r'find_package\(\s*(\w+)', txt))
                for names in re.findall(r'find_program\(\s*\w+\s+(?:NAMES\s+)?([\w.+\- ]+)', txt):
                    found["potential"].update(names.split()[:3])
            elif f in ("Makefile", "Makefile.in", "GNUmakefile", "Kbuild", "Makefile.am") and depth <= 3:
                found["build_system"].add("make")
                for line in open(p, errors="replace"):
                    if line.startswith("\t"):
                        for w in re.findall(r'(?<![\w$/.-])([a-z][\w+-]*)\b', line[:200]):
                            if w in KNOWN_TOOLS:
                                found["potential"].add(w)
            elif f == "build.sh" and depth == 0:
                found["build_system"].add("build.sh")
            elif f == "meson.build" and depth == 0:
                found["build_system"].add("meson")
            if depth <= 2 and not f.endswith((".c", ".h", ".cpp", ".texi", ".po")):
                try:
                    with open(p, "rb") as fh:
                        head = fh.read(80)
                    if head.startswith(b"#!"):
                        interp = head[2:].split(b"\n")[0].split()
                        if interp:
                            name = os.path.basename(interp[0].decode(errors="replace"))
                            if name == "env" and len(interp) > 1:
                                name = interp[1].decode(errors="replace")
                            found["shebangs"].add(name)
                except OSError:
                    pass
    return {k: sorted(v) for k, v in found.items()}

def cmd_analyze(a):
    pk = load_all()
    os.makedirs(ANADIR, exist_ok=True)
    seen = {}
    for m in select(pk, a.pkgs):
        key = m["source_url"]
        if key not in seen:
            seen[key] = analyze_tree(top(extract(m)))
        res = dict(seen[key])
        json.dump(res, open(os.path.join(ANADIR, m["name"] + ".json"), "w"), indent=1)
        print(f"{m['name']:22} {','.join(res['build_system']) or '?':14} required={' '.join(res['required'])}")

# --------------------------------------------------------------------- probe
WRAPPER = """#!/bin/sh
printf '%s\\n' "{name}" >> "{log}"
exec "{real}" "$@"
"""

def cmd_probe(a):
    """Controlled configure probe on the prep host.

    Every executable on PATH is replaced by a logging shim; configure is run
    out-of-tree. The resulting set of *executed* tools supplements static analysis.
    It reflects host-native behaviour and is therefore advisory; the definitive
    check is the hermetic native build on RISC-V (scripts/target/build-pkg.sh).
    """
    pk = load_all()
    m = select(pk, [a.pkg])[0]
    src = top(extract(m))
    work = os.path.join(ROOT, "build", "probe", m["name"])
    shutil.rmtree(work, ignore_errors=True)
    shim, bld = os.path.join(work, "bin"), os.path.join(work, "build")
    os.makedirs(shim); os.makedirs(bld)
    log = os.path.join(work, "exec.log")
    for d in os.environ["PATH"].split(":"):
        if not os.path.isdir(d):
            continue
        for n in os.listdir(d):
            real = os.path.join(d, n)
            t = os.path.join(shim, n)
            if os.path.exists(t) or not os.access(real, os.X_OK) or os.path.isdir(real):
                continue
            with open(t, "w") as f:
                f.write(WRAPPER.format(name=n, log=log, real=real))
            os.chmod(t, 0o755)
    cfg = os.path.join(src, "configure")
    if not os.path.exists(cfg):
        sys.exit(f"{m['name']}: no configure script; probe supports autoconf packages only")
    env = {"PATH": shim, "HOME": work, "LC_ALL": "C", "CONFIG_SHELL": os.path.join(shim, "sh"),
           "FORCE_UNSAFE_CONFIGURE": "1"}
    opts = m.get("configure_opts", "").replace("$PREFIX", "/probe").replace("$SYSROOT", "/").replace("$SYSROOT_REL", "/")
    opts = [o for o in opts.split() if "sysroot" not in o]
    r = subprocess.run([os.path.join(shim, "sh"), cfg, "--prefix=/probe", *opts], cwd=bld, env=env,
                       stdout=open(os.path.join(work, "configure.log"), "w"), stderr=subprocess.STDOUT)
    used = sorted(set(open(log).read().split())) if os.path.exists(log) else []
    host_cc = {"cc", "gcc", "c++", "g++", "clang", "clang++", "cpp", "x86_64-linux-gnu-gcc",
               "x86_64-linux-gnu-gcc-13", "gcc-13", "as", "ld", "collect2"}
    res = {"configure_rc": r.returncode, "executed": used,
           "executed_non_compiler": [u for u in used if u not in host_cc]}
    json.dump(res, open(os.path.join(ANADIR, m["name"] + ".probe.json"), "w"), indent=1)
    print(f"{m['name']}: configure rc={r.returncode}; executed: {' '.join(res['executed_non_compiler'])}")

# --------------------------------------------------------------------- resolve
HOST_TOOLS_STAGE0 = ["cmake", "ninja", "cc", "c++", "python3", "make", "sh", "sed", "gcc", "ar", "ranlib", "clang-18"]

def tarjan(graph):
    idx, low, stack, on, out, n = {}, {}, [], set(), [], [0]
    sys.setrecursionlimit(10000)
    def sc(v):
        idx[v] = low[v] = n[0]; n[0] += 1; stack.append(v); on.add(v)
        for w in graph.get(v, ()):
            if w not in idx:
                sc(w); low[v] = min(low[v], low[w])
            elif w in on:
                low[v] = min(low[v], idx[w])
        if low[v] == idx[v]:
            comp = []
            while True:
                w = stack.pop(); on.discard(w); comp.append(w)
                if w == v:
                    break
            out.append(comp)
    for v in sorted(graph):
        if v not in idx:
            sc(v)
    return out

def cmd_resolve(a):
    pk = load_all()
    providers = {}
    for m in pk.values():
        for t in m["provides"]:
            providers.setdefault(t, []).append(m["name"])
    errors, warnings, unresolved = [], [], []
    graph, edges = {n: set() for n in pk}, []

    def add(frm, to, kind, why):
        graph[frm].add(to); edges.append({"from": frm, "to": to, "kind": kind, "why": why})

    for m in pk.values():
        n = m["name"]
        if m.get("toolchain") == "gcc" and "llvm-bootstrap" in m["build_deps"] + m["runtime_deps"]:
            errors.append(f"{n}: pkg_toolchain=gcc but depends on llvm-bootstrap")
        for d in m["build_deps"]:
            if d not in pk:
                errors.append(f"{n}: build dependency '{d}' is not a known package")
            else:
                add(n, d, "build-lib", "declared")
        for d in m["runtime_deps"]:
            if d not in pk:
                errors.append(f"{n}: runtime dependency '{d}' is not a known package")
            else:
                add(n, d, "runtime", "declared")
        if m["stage"] == 0:
            for t in m["build_tools"]:
                if not shutil.which(t):
                    unresolved.append({"package": n, "tool": t, "where": "prep-host", "reason": "not installed on prep host"})
            continue
        for t in m["build_tools"]:
            cands = [p for p in providers.get(t, []) if p != n]
            if m.get("toolchain") == "gcc":
                # Clang independence: stage-3+ packages may not take tools from the bootstrap LLVM.
                cands = [p for p in cands if p != "llvm-bootstrap"]
            if t in m["cycle_break"]:
                continue
            if not cands:
                unresolved.append({"package": n, "tool": t, "where": "target", "reason": "no package provides it"})
                continue
            # Edge to the lowest-stage provider: the minimum needed to build.
            best = min(cands, key=lambda p: (pk[p]["stage"], p))
            add(n, best, "build-tool", t)
        # cross-check against analysis/probe results
        ap = os.path.join(ANADIR, n + ".json")
        if os.path.exists(ap):
            an = json.load(open(ap))
            declared = set(m["build_tools"]) | set(m["optional_tools"]) | set(m["cycle_break"]) | {"cc", "c++", "cpp", "install", "mkdir", "ln"}
            for t in an["required"]:
                if t not in declared and t not in ("make",) and t not in providers:
                    unresolved.append({"package": n, "tool": t, "where": "target", "reason": "found by configure.ac analysis, no provider"})
                elif t not in declared and t not in ("install", "mkdir", "ln"):
                    warnings.append(f"{n}: analysis found '{t}' (AC_PROG) not declared in pkg_build_tools")
        pp = os.path.join(ANADIR, n + ".probe.json")
        if os.path.exists(pp):
            pr = json.load(open(pp))
            declared = set(m["build_tools"]) | set(m["optional_tools"])
            for t in pr["executed_non_compiler"]:
                if t in KNOWN_TOOLS and t not in declared and t not in providers.get(t, [None])[0:0]:
                    if t not in ("sed", "grep", "awk", "install", "mkdir", "ln") or t not in declared:
                        warnings.append(f"{n}: probe executed '{t}' which is not in pkg_build_tools")

    cycles = [sorted(c) for c in tarjan(graph) if len(c) > 1 or (c[0] in graph[c[0]])]
    for c in cycles:
        errors.append("dependency cycle (declare pkg_cycle_break or split a package): " + " -> ".join(c))

    # Kahn topological sort, deterministic (stage, name)
    order, indeg = [], {n: 0 for n in pk}
    rev = {n: set() for n in pk}
    for n, deps in graph.items():
        for d in deps:
            rev[d].add(n); indeg[n] += 1
    ready = sorted([n for n in pk if indeg[n] == 0], key=lambda n: (pk[n]["stage"], n))
    while ready:
        n = ready.pop(0); order.append(n)
        for r in rev[n]:
            indeg[r] -= 1
            if indeg[r] == 0:
                ready.append(r)
        ready.sort(key=lambda n: (pk[n]["stage"], n))
    for n in order:
        for d in graph[n]:
            if pk[d]["stage"] > pk[n]["stage"]:
                errors.append(f"{n} (stage {pk[n]['stage']}) depends on later-stage {d} (stage {pk[d]['stage']})")
    for m in pk.values():
        if not m.get("sha256"):
            errors.append(f"{m['name']}: source not pinned (pkg_sha256 empty)")

    vlog = {}
    vp = os.path.join(ROOT, "build", "verification.json")
    if os.path.exists(vp):
        vlog = json.load(open(vp))
    lock = {
        "format": 1, "target": TARGET, "isa": "rv64gc", "abi": "lp64d", "libc": "musl",
        "packages": [{
            "name": n, "version": pk[n]["version"], "stage": pk[n]["stage"],
            "source_url": pk[n]["source_url"], "sha256": pk[n].get("sha256", ""),
            "verification": vlog.get(n, {}).get("verification", "not verified in this tree"),
            "build_deps": sorted(pk[n]["build_deps"]), "build_tools": pk[n]["build_tools"],
            "runtime_deps": pk[n]["runtime_deps"], "resolved_edges": sorted(graph[n]),
            "where": "prep-host" if pk[n]["stage"] == 0 else "target-native",
        } for n in order],
        "edges": sorted(edges, key=lambda e: (e["from"], e["to"])),
        "cycles": cycles, "unresolved": unresolved, "warnings": sorted(set(warnings)), "errors": errors,
    }
    with open(os.path.join(ROOT, "manifest.lock"), "w") as f:
        # one package / edge per line: compact, and diffs stay readable
        f.write("{\n")
        items = list(lock.items())
        for i, (k, v) in enumerate(items):
            end = ",\n" if i < len(items) - 1 else "\n"
            if isinstance(v, list) and v:
                f.write(f" {json.dumps(k)}: [\n")
                f.write(",\n".join("  " + json.dumps(x, sort_keys=True) for x in v))
                f.write("\n ]" + end)
            else:
                f.write(f" {json.dumps(k)}: {json.dumps(v)}{end}")
        f.write("}\n")
    with open(os.path.join(ROOT, "manifest.order"), "w") as f:
        f.write("# stage name version source-file sha256  (generated by rbs.py resolve; consumed by target sh)\n")
        for n in order:
            f.write(f"{pk[n]['stage']} {n} {pk[n]['version']} {os.path.basename(pk[n]['source_url'])} {pk[n].get('sha256','-')}\n")
    for w in sorted(set(warnings)):
        print("warning:", w)
    for u in unresolved:
        print(f"UNRESOLVED: {u['package']}: tool '{u['tool']}' ({u['where']}): {u['reason']}")
    for e in errors:
        print("ERROR:", e)
    print(f"order ({len(order)}): {' '.join(order)}")
    if len(order) != len(pk):
        print("ERROR: topological sort incomplete (cycle)")
    sys.exit(1 if errors or len(order) != len(pk) else 0)

def cmd_list(a):
    for m in sorted(load_all().values(), key=lambda m: (m["stage"], m["name"])):
        print(f"stage{m['stage']} {m['name']:22} {m['version']:10} {'pinned' if m.get('sha256') else 'UNPINNED'}  {m['verify'].split(':')[0]}")

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = ap.add_subparsers(dest="cmd", required=True)
    for c in ("pin", "fetch", "analyze"):
        p = sp.add_parser(c); p.add_argument("pkgs", nargs="*")
    p = sp.add_parser("probe"); p.add_argument("pkg")
    sp.add_parser("resolve"); sp.add_parser("list")
    a = ap.parse_args()
    {"pin": cmd_pin, "fetch": cmd_fetch, "analyze": cmd_analyze, "probe": cmd_probe,
     "resolve": cmd_resolve, "list": cmd_list}[a.cmd](a)

if __name__ == "__main__":
    main()
