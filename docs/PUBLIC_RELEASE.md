# Public GitHub release guide

NMAForge is suitable for a public portfolio repository only as a **sanitized
source snapshot**. Do not publish the existing repository history until every
old commit has been reviewed: it may contain removed teaching material, board
collateral or machine-specific artefacts.

## Included in the public snapshot

- Current synthesizable RTL, public FPGA scripts, software ABI/mapper and
  verification source.
- Architecture, specification, test plan and sanitized implementation evidence.
- Generic scripts that do not embed credentials, license strings, PDK paths or
  vendor project contents.

## Explicitly excluded

- Foundry PDK, `.db`/`.lib`, SRAM macro models, LEF/GDS/NDM, extracted data,
  netlists and physical-design databases.
- Vendor board schematics, drawings, vendor Vivado projects, XSA/bit/LTX and
  any generated board deliverable.
- VCS/SpyGlass/Vivado databases, waveforms, coverage databases and logs.
- Credentials, network endpoints, local user names, absolute local paths and
  private interview/chat material.

The repository `.gitignore` enforces the common cases; it cannot protect files
that are already tracked. Remove such files from the public release index
before the first public commit.

## Safe publication workflow

1. Keep this engineering repository and its history private.
2. Create a **new empty GitHub repository** named
   `nmaforge-axi-tensor-accelerator` with no README, license or `.gitignore`.
3. Export the reviewed working tree into a new directory outside this checkout;
   do not copy `.git`, `syn/out`, `fpga/**/build`, VCS artefacts or any ignored
   private overlay.
4. In the new directory, run `git init`, `git add -A`, inspect
   `git status --short`, `git diff --cached --check`, then make the first
   commit. Review the staged file list before pushing.
5. Add the GitHub remote and push only that new history. Never force-push the
   private engineering history to a public remote.

The root English and Chinese README files state the scope and evidence boundary
that should be used for a portfolio presentation.
