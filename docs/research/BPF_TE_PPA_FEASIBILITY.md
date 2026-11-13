# BPF-TE PPA Feasibility

Elaboration and simulation of the isolated RTL prototype pass with VCS
`V-2023.12-SP1_Full64`. Standard-cell synthesis, STA, and SRAM macro mapping
are `BLOCKED/NOT_MEASURED`: no legal PDK library, SDC, or compatible four-port
SRAM macro was supplied for this worktree. Behavioral SRAM capacity cannot be
used as an ASIC area claim.

Expected implementation costs are four small round-robin pointers, two
metadata tag stages per bank, bank request muxing, and epoch comparison. Exact
register count, area, timing, and power require synthesis under the target
library and macro contract. H1 is therefore an interface feasibility result,
not an ASIC readiness result.

Standalone VCS elaboration is the only structural evidence in this sprint; no
synthesis or STA pass is implied by it.
