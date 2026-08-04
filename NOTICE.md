# NOTICE

This repository packages and redistributes upstream software published by the
[terragrunt](https://github.com/gruntwork-io/terragrunt) project. The
Apache-2.0 license in [`LICENSE`](LICENSE) covers the OCX pipeline files
authored here. It does **not** cover any upstream-derived asset — the
redistributed bytes carry their own license, recorded below.

The package logo is upstream's own mark
([`docs/src/assets/logo-dark.svg`](https://github.com/gruntwork-io/terragrunt/blob/main/docs/src/assets/logo-dark.svg)),
re-encoded to 512 px for catalog identification only. No endorsement is
implied, and no trademark claim is made. "Terragrunt" and "Gruntwork" are marks
of Gruntwork, LLC.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `terragrunt` | `ghcr.io/ocx-contrib/gruntwork-io/terragrunt` | `MIT` |

---

## `terragrunt`

Upstream: <https://github.com/gruntwork-io/terragrunt>
Published to `ghcr.io/ocx-contrib/gruntwork-io/terragrunt`.

| Component | SPDX | Holder |
|---|---|---|
| terragrunt | **MIT** | Copyright (c) 2016 Gruntwork, LLC |

Verified at the Phase 1.5 license gate:

```
$ gh api repos/gruntwork-io/terragrunt/license --jq '{spdx: .license.spdx_id, path: .path}'
{"path":"LICENSE.txt","spdx":"MIT"}
```

The raw `LICENSE.txt` blob was read as well: unmodified MIT text opening
"The MIT License (MIT) / Copyright (c) 2016 Gruntwork, LLC", with no added
clauses, no field-of-use restriction and no commercial carve-out. MIT is
permissive and grants redistribution of the compiled binary subject to its
notice-retention condition.

Upstream's release assets are **raw uncompressed binaries** — one file per
platform with no archive around it, and therefore no `LICENSE` file travelling
alongside. (The `.tar.gz` and `.zip` twins shipped beside each raw asset are
not an exception: each contains that single binary and nothing else.) The
notice is therefore retained here instead. The canonical text is
<https://github.com/gruntwork-io/terragrunt/blob/main/LICENSE.txt>, and every
published manifest carries an `org.opencontainers.image.source` annotation
pointing at this repository alongside `org.opencontainers.image.licenses: MIT`.

The published binaries are statically linked Go builds that vendor third-party
modules under permissive licenses, enumerated in the `go.mod` / `go.sum` of the
tagged upstream source for each mirrored version.

terragrunt is an *orchestrator* for OpenTofu/Terraform and does not embed
either of them: it execs whatever `terraform`/`tofu` binary the host provides.
No HashiCorp- or OpenTofu-licensed code is redistributed by this package.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle. The only transformations are
the executable mode bit — GitHub serves raw release assets as `0644`, and
`prepare` chmods the declared binary to `0755` so it can be run at all — and
the file *name*, from the upstream `terragrunt_<os>_<arch>` to the plain
`terragrunt` the tool expects to be invoked as. The bytes are unchanged.
