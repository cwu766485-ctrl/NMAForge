# NMAForge naming and ABI compatibility

**NMAForge** is the canonical public project, repository and documentation
name. It means *Near-Memory Accelerator Forge* and describes the implemented
all-digital near-memory architecture without implying analog CIM.

## Canonical public names

- Repository and working directory: `NMAForge`.
- GitHub repository: `nmaforge-axi-tensor-accelerator`.
- New board-flow environment variables and human-facing log messages use the
  `NMAFORGE_` prefix.

## Compatibility names intentionally retained

- `CIMFORGE_*` register definitions, descriptor constants and C helpers are
  the released software/RTL ABI. Renaming them would break firmware, tests and
  generated descriptor fixtures.
- Existing source filenames such as `cimforge_regs.h` and generated local
  Vivado artefact stems are compatibility identifiers, not the public brand.

## Rule for future changes
Use **NMAForge** in new public documentation, UI strings, logs and scripts.
Change a `CIMFORGE_*` identifier only as a deliberate, versioned ABI migration
with matching RTL, software and verification updates.
