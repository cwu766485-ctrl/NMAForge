# Elaboration-time product geometry. Validation must match the loaded bitstream.
set SPAD_WORDS_PER_BANK [expr {[info exists ::env(SPAD_WORDS_PER_BANK)] ? $::env(SPAD_WORDS_PER_BANK) : 8192}]
if {$SPAD_WORDS_PER_BANK ni {8192 32768}} {
    error "XCZU15EG product profile requires 8192 or 32768 SPAD words/bank"
}
set SPAD_BYTES [expr {16 * $SPAD_WORDS_PER_BANK}]
