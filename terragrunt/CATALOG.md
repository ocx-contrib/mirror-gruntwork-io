---
title: terragrunt
description: Orchestration for OpenTofu/Terraform at scale — DRY configuration, dependency-ordered runs across many units, and remote state wiring from one HCL file
keywords: terragrunt,terraform,opentofu,iac,infrastructure-as-code,hcl,orchestration,devops,gruntwork,cli
---

# terragrunt

[terragrunt](https://github.com/gruntwork-io/terragrunt) is a flexible
orchestration tool from [Gruntwork](https://gruntwork.io) that lets
Infrastructure as Code written in OpenTofu/Terraform scale past a single root
module. A `terragrunt.hcl` per unit declares the module source, its inputs and
its `dependency` edges; terragrunt builds the DAG, wires remote state and
provider configuration in, and runs the underlying `tofu`/`terraform` binary
across every unit in dependency order.

## What's included

- **terragrunt** — the binary. `terragrunt run --all plan` walks the whole
  dependency graph, `terragrunt stack` drives generated stacks, `terragrunt
  find` / `list` discover the units in a tree, `terragrunt render` resolves a
  configuration with every `include`, function and variable expanded, and
  `terragrunt hcl fmt` / `hcl validate` canonicalise and check the HCL itself.
  The OpenTofu shortcuts (`apply`, `plan`, `init`, `output`, …) forward to the
  underlying binary.

## Requires a `tofu` or `terraform` binary

terragrunt orchestrates OpenTofu/Terraform — it does not embed it. The `run`,
`apply`, `plan` and `init` verbs exec whatever `terraform_binary` resolves to
(`terraform` by default; set `TG_TF_PATH=tofu` for OpenTofu), so that binary
must be installed separately and on `PATH`. The configuration-only verbs —
`hcl fmt`, `hcl validate`, `find`, `list`, `info` — need nothing but
terragrunt itself.

## Quick start

```hcl
# live/prod/app/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::git@github.com:acme/modules.git//app?ref=v1.4.0"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  subnet_ids = dependency.vpc.outputs.private_subnet_ids
}
```

```sh
terragrunt find --format=json     # what units exist in this tree
terragrunt hcl fmt                # canonicalise every .hcl file
terragrunt run --all plan         # plan every unit in dependency order
```

## Install with ocx

```sh
ocx install ocx.sh/gruntwork-io/terragrunt
```

```sh
# or pin a specific version
ocx install ocx.sh/gruntwork-io/terragrunt:1.1.2
```

## Links

- [terragrunt on GitHub](https://github.com/gruntwork-io/terragrunt)
- [Documentation](https://docs.terragrunt.com/)
- [Configuration reference](https://docs.terragrunt.com/reference/hcl/)
