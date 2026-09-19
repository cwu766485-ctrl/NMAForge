# Installed Synopsys capability map

| API flow | Product/entry point | Host evidence |
|---|---|---|
| sim/debug | VCS + Verdi | `$VCS_HOME/bin/vcs`, `$VERDI_HOME/bin/verdi` |
| lint/cdc | SpyGlass | `$SPYGLASS_HOME/bin/sg_shell` |
| formal/lec | VC Formal + Formality | `vc_static_shell`, `fm_shell` |
| synth | Design Compiler / DC NXT | `dc_shell`, `dcnxt_shell` |
| apr | ICC / ICC2 | `icc_shell`, `icc2_shell` |
| sta/power | PrimeTime / PrimePower | `pt_shell`, `primepower` |
| extraction | StarRC | `starrc_shell` |
| dft/atpg | TestMAX | `dft_shell`, `tmax`, `cv_shell` |
| dft integration | TestMAX libraries/resources | `dft_mbist.sldb`, `dft_lbist.sldb`, `smart_bist.tpl`, `stp_bist.tpl` |

The presence of a binary or `.sldb` resource proves installation only. License checkout and a successful run log are required to report a capability as usable.
