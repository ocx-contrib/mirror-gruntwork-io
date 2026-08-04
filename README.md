# mirror-gruntwork-io

OCX mirror for [terragrunt](https://github.com/gruntwork-io/terragrunt), the
OpenTofu/Terraform orchestrator published by
[Gruntwork](https://gruntwork.io). One repository, one spec directory per
package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [terragrunt](https://github.com/gruntwork-io/terragrunt) | [`terragrunt/mirror.yml`](terragrunt/mirror.yml) | `ghcr.io/ocx-contrib/gruntwork-io/terragrunt` | [`ocx.sh/gruntwork-io/terragrunt`](https://index.ocx.sh/gruntwork-io/terragrunt) | `MIT` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

`gruntwork-io` is the org handle of Gruntwork, LLC, which publishes terragrunt
alongside terratest, cloud-nuke, git-xargs and boilerplate — a namespace that
plausibly holds more than one package, so the org names it and the package is
`gruntwork-io/terragrunt`.

## Layout

```
mirror-base.yml         repo-wide policy every spec inherits via `extends:`
terragrunt/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. Restate a block in full or
not at all. `terragrunt/mirror.yml` does not restate it at all, which removes
the trap structurally.

## Platforms

`terragrunt` publishes five platform entries: both Linux arches, both macOS
arches and `windows/amd64`. Upstream ships one Go binary per platform with no
musl/gnu split, and all four declared Linux artifacts were byte-measured at
**both ends** of the mirrored range, v1.1.0 and v1.1.2: no `PT_INTERP`, no
`DT_NEEDED`, no UPX stub (`strings -a | grep -c '^UPX'` → 0, section table
intact at offset 400). `os.features` states what an artifact requires *of the
host*, so both Linux keys are **bare** — `+libc.glibc` would hide the package
from Alpine and `+libc.musl` would hide it from every glibc host it in fact
runs on. The `alpine:3.20` container leg on both arches in `mirror-base.yml` is
what turns that claim into evidence; the measurement transcript is recorded
above the `assets:` block in `terragrunt/mirror.yml`.

**`windows/arm64` is deliberately excluded**: upstream ships no
`terragrunt_windows_arm64*` asset at any in-range release — the only Windows
targets are `amd64` and `386`. Declaring it would boot a `windows-11-arm`
runner that self-skips per version and reports SUCCESS having tested nothing.

Upstream also publishes `terragrunt_linux_386` and `terragrunt_windows_386.exe`.
ocx's architecture enum is `amd64` and `arm64` only, so neither is expressible
as a platform key and neither is mirrored.

### Three assets per platform, and why the raw one wins

Every platform ships the **same build three times**: a raw uncompressed binary,
a `.tar.gz` and a `.zip`. The archives are not a different layout — they add no
wrapper directory, no `LICENSE`, and crucially **they do not rename the file**:

```
$ tar tvzf terragrunt_linux_amd64.tar.gz
-rw-r--r-- runner/runner 88907938 …  terragrunt_linux_amd64
```

A single member, still platform-suffixed, still mode `0644`. So an archive buys
nothing over the raw asset while costing a decompression layer. Every pattern
takes the **raw** file, and `asset_type.name: terragrunt` does the rename once,
centrally — without it the bundle would put `terragrunt_linux_amd64` on `PATH`,
not `terragrunt`.

**End-anchors are load-bearing, not decoration.** `terragrunt_linux_amd64` is a
strict prefix of *both* `terragrunt_linux_amd64.tar.gz` *and*
`terragrunt_linux_amd64.zip`, so an unanchored pattern matches **three** assets
— an ambiguous match, which is a hard error rather than a silent skip. The `$`
is what makes each pattern resolve to exactly one file; on Windows `\.exe$`
does the same job against `.exe.tar.gz` and `.exe.zip`.

Resolution was verified **both ways on every in-range release** (v1.1.0,
v1.1.1, v1.1.2): each of the five patterns matches exactly one asset out of 27,
every time, leaving the same 22 unmatched (the archive twins, the two 386
builds, `SHA256SUMS` with its four signature sidecars, and the signing key). A
pattern matching zero would be silently skipped rather than reported, so this
check is not optional.

Asset names carry **no version token at all** — `terragrunt_linux_amd64` is
byte-identical as a *name* across all three releases — so the usual "upstream
shipped the previous version's binaries under a new tag" check cannot be made
from the filename. It was made from the binary instead: each downloaded
artifact was run locally and `terragrunt --version` reported the tag it came
from.

### The Windows `.exe` question, measured

`asset_type: binary` **preserves** an upstream `.exe` suffix and never
*synthesises* one, so whether a per-platform `name: terragrunt.exe` override is
needed is an empirical question, not a guess. Upstream's raw Windows asset
already carries the suffix, and a windows-only `pipeline prepare` confirms it
survives — **no override is needed**:

```
$ tar tvf .ocx-mirror/winwork/1.1.2_.../windows_amd64/bundle.tar.xz
-rwxr-xr-x 0/0   91064936 …  terragrunt.exe
```

That listing also shows `prepare` chmodding `0755`, which it does for the names
`metadata.json` declares — see below.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `terragrunt/mirror.yml` | hand | yes — see below |
| `terragrunt/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `terragrunt/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec terragrunt/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The binaries claim

`terragrunt/metadata.json` declares `binaries: ["terragrunt"]` by hand, and
`mirror-base.yml` sets `bin_scan: "off"` — forced, not preferred. Every asset
is a raw binary, so it lands at the bundle content root and `PATH` is a bare
`${installPath}`; the scan only inspects an interface-visible
`${installPath}/<dir>` entry, so with no subdirectory to point at, `auto` and
`verify` both fail spec load at exit 65 rather than offer a hollow check.

The hand list is **load-bearing beyond documentation** here: GitHub serves raw
release assets with mode `0644` (measured on all four downloaded Linux assets —
and the `.tar.gz` twin carries its member at `0644` too), and `prepare` chmods
`0755` exactly the names `metadata.json` declares. An undeclared binary would
ship non-executable, and `bin_scan: auto` could not rescue it — the scan only
reports candidates it finds *already* executable. The name is declared **bare**,
without `.exe`; the Windows bundle still comes out `terragrunt.exe` at `0755`.

## Container legs provision nothing

No `containers[].setup` anywhere, and that is a measured decision rather than
an omission. Two things could have forced one and neither does:

- **Linkage** — `readelf -d` reports zero `DT_NEEDED` on all four Linux
  artifacts, so there is no shared library for a stock image to be missing.
- **Shell-outs** — terragrunt is an OpenTofu/Terraform *wrapper*, and its
  headline verbs (`run`, `apply`, `plan`, `init`) exec a `tofu`/`terraform`
  binary that no stock image ships. The smoke test therefore does not use them.

Installing a Terraform toolchain into a leg would prove *less*, not more: a
bare image plus nothing is the honest claim this artifact can make.

## The smoke test

`terragrunt/tests/smoke.star` drives only verbs terragrunt answers **entirely
from its own code** — its HCL parser/writer (`hcl fmt`) and its configuration
discovery walk (`find`). Both were measured on v1.1.0 and v1.1.2 in a *non-git*
directory with `HOME` unset: exit 0, empty stderr. Neither a `tofu` binary, nor
git, nor a writable `HOME` is reachable from the tested path.

- `terragrunt --version` matches a version **shape** regex — the digits are the
  contract, the banner is not. That call doubles as proof that
  `asset_type.name` did its job: `argv[0]` is the short name, resolved off the
  bundle's composed `PATH`.
- `hcl fmt --check` on a deliberately mis-formatted file must exit **1**, and
  on the same file after `hcl fmt` must exit **0**. Both directions are pinned,
  because a `--check` that returned a constant would look identical from one
  side.
- The rewrite is asserted on the **bytes terragrunt wrote**, not on stdout
  (`hcl fmt` logs to stderr and leaves stdout empty). Substring *counts* rather
  than a whole-file compare, so the check is immune to Windows line endings.
- **A negative control.** `hcl fmt` is rewrite-shaped, and a rewriter that never
  parsed its input would pass every assertion above by copying bytes through.
  A truncated assignment (`a = ` with no right-hand side) has no canonical form,
  so only a real parser can fault it — it must exit non-zero.
- `find --format=json` must report **exactly one** component for a tree holding
  one unit. The count is the assertion, not the exit code: `find` exits 0 when
  it discovers *nothing*, so an exit-code-only check would green a walk that
  never descended.

All three in-range versions were run locally against real native bundles before
the first push, and red was proven reachable by mutating an expectation
(`expected 1 == 99`).

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
package's redistribution license is recorded in [`NOTICE.md`](NOTICE.md). The
logo is upstream's own mark, re-encoded for catalog identification only.
