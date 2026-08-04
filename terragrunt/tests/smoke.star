# terragrunt/tests/smoke.star — stable across upstream terragrunt releases.
#
# Asserts the contract (exit codes, version SHAPE, and the bytes terragrunt's
# own HCL writer produced), never help/version prose.
#
# HERMETIC BY CONSTRUCTION, AND THAT IS THE HARD PART HERE. terragrunt is an
# OpenTofu/Terraform WRAPPER: its headline verbs (`run`, `apply`, `plan`,
# `init`) exec a `tofu`/`terraform` binary that no container image in the test
# matrix ships, and provisioning one would be testing a Terraform install
# rather than this artifact. So every assertion below drives a verb terragrunt
# answers ENTIRELY FROM ITS OWN CODE:
#
#   * `hcl fmt`  — terragrunt's HCL parser + canonical writer, in-process
#   * `find`     — terragrunt's configuration discovery walk, in-process
#
# Both were measured on v1.1.0 and v1.1.2 in a NON-GIT directory with `HOME`
# unset: exit 0, empty stderr. Neither a `tofu` binary, nor git, nor a writable
# HOME is reachable from the tested path, which is why the Linux container legs
# in ../../mirror-base.yml provision nothing.

TERRAGRUNT = "terragrunt.exe" if ocx.target_platform.os == ocx.os.Windows else "terragrunt"

# ─── Tier 1 + 2: liveness on the composed PATH + version SHAPE ──────────────
#
# The digits are the contract; the banner around them is not. `terragrunt
# --version` prints `terragrunt version v1.1.2` today — the regex survives a
# reprint, an `expect.eq` on the whole line would not, and an
# `expect.contains(stdout, "terragrunt")` would break on a rebrand.
#
# This call is also the proof that `asset_type.name` did its job: the upstream
# asset is named `terragrunt_linux_amd64`, and argv[0] here is the short name,
# resolved off the bundle's composed PATH. Without the rename there would be no
# `terragrunt` on PATH at all.
r_version = ocx.run(TERRAGRUNT, "--version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ─── Hermetic fixtures ──────────────────────────────────────────────────────
#
# `cwd` defaults to the scratch root, so every path below stays relative —
# correct on Windows too, with no separator juggling.
#
# `probe.hcl` is valid HCL that is deliberately NOT in canonical form: `a =  1`
# has a doubled space around `=`, and `     b="two"` is over-indented with no
# spaces at all. Both are things only a real parse-and-rewrite can normalise —
# a byte copier leaves them exactly as they are.
ocx.write_file("probe.hcl", """locals {
  a =  1
     b="two"
}
""")

# The NEGATIVE CONTROL's fixture: a truncated assignment. `a = ` with no
# right-hand side is a parse error, not a formatting nit, so a tool that merely
# echoed its input back would exit 0 on it.
ocx.write_file("bad.hcl", """locals {
  a =
""")

# ─── Tier 3a: `hcl fmt --check` DETECTS the unformatted file ────────────────
#
# Inverted exit polarity by design: `--check` returns 1 when a file needs
# formatting. Asserting this direction FIRST is what makes Tier 3c meaningful —
# without it, a `--check` that always returned 0 would look identical.
r_check_before = ocx.run(TERRAGRUNT, "hcl", "fmt", "--file", "probe.hcl", "--check", "--no-color")
expect.eq(r_check_before.exit_code, 1)

# ─── Tier 3b: the rewrite, asserted on the BYTES terragrunt wrote ───────────
#
# The assertion is on the FILE, not on stdout: `hcl fmt` writes its progress
# line to stderr and leaves stdout empty, so there is no output to assert on
# even if prose were allowed. Counts rather than a whole-file compare, so the
# check is immune to line-ending choice on Windows.
r_fmt = ocx.run(TERRAGRUNT, "hcl", "fmt", "--file", "probe.hcl", "--no-color")
expect.ok(r_fmt)

formatted = ocx.read_file("probe.hcl")
expect.eq(formatted.count("a = 1"), 1)          # doubled space collapsed
expect.eq(formatted.count("a =  1"), 0)         # …and the original form is gone
expect.eq(formatted.count("b = \"two\""), 1)    # spacing inserted around `=`
expect.eq(formatted.count("b=\"two\""), 0)      # …and the original form is gone

# ─── Tier 3c: `--check` now agrees the file is canonical ────────────────────
#
# The other half of the polarity pin. Together with Tier 3a this proves
# `--check` is reading the file rather than returning a constant.
r_check_after = ocx.run(TERRAGRUNT, "hcl", "fmt", "--file", "probe.hcl", "--check", "--no-color")
expect.ok(r_check_after)

# ─── Tier 3d: THE NEGATIVE CONTROL — malformed HCL must be REJECTED ─────────
#
# `hcl fmt` is rewrite-shaped, and a rewriter that never parsed its input would
# pass every assertion above by copying bytes through. It cannot pass this one:
# the truncated assignment has no canonical form, and only a real parser can
# fault it.
r_bad = ocx.run(TERRAGRUNT, "hcl", "fmt", "--file", "bad.hcl", "--no-color")
expect.ne(r_bad.exit_code, 0)

# ─── Tier 3e: configuration DISCOVERY, on machine-readable output ───────────
#
# `find` walks a directory tree looking for terragrunt configurations and
# classifies what it finds. `--format=json` is terragrunt's own encoder, so the
# assertion lands on structured output rather than on a rendered table.
#
# The count is the assertion, not `expect.ok`: `find` exits 0 when it discovers
# NOTHING, so an exit-code-only check would green a walk that never descended.
# Exactly one component must be reported — the unit — and not the enclosing
# directory as well.
ocx.mkdir("stack/unit")
ocx.write_file("stack/unit/terragrunt.hcl", """terraform {
  source = "./mod"
}
""")
r_find = ocx.run(TERRAGRUNT, "find", "--format=json", "--no-color", "--working-dir", "stack")
expect.ok(r_find)
expect.eq(r_find.stdout.count("\"type\""), 1)
expect.contains(r_find.stdout, "unit")

# No Tier 4: metadata.json declares PATH only (proven by the Tier 1 liveness
# call resolving `terragrunt` off the composed PATH).
