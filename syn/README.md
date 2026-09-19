# Private ASIC-flow overlay

The public NMAForge repository does not include foundry libraries, SRAM macro
models, technology-specific macro wrappers, DC setup files or generated PPA
artefacts. Those files are license- and NDA-controlled and are ignored.

The public evidence in `docs/verification/TSMC28_SYNTHESIS_REPORT.md` is a sanitized
pre-layout result. To reproduce it internally, maintain a private overlay with
the appropriate standard-cell/SRAM timing views, macro adapter and constraints;
keep all absolute paths and library identifiers outside Git.
