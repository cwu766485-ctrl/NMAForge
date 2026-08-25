# Private board-reference contract

The XCZU15EG board flow requires a board-owner supplied Vivado reference
project that contains the validated PS DDR/MIO configuration. That project,
schematics and mechanical drawings are intentionally excluded from the public
repository.

Set the local environment variable below before invoking the board-build flow:

```powershell
$env:NMAFORGE_VENDOR_XPR = '<path-to-private-board-reference.xpr>'
```

The public scripts copy only the configuration needed to build the PS/PL block
design; they do not redistribute any vendor source or generated hardware file.
