# Round 4 DAMS Opportunity Analysis

The passive monitor samples the Product Top without driving DUT signals. It
records descriptor issue, engine busy/ready/done, accepted SPAD transactions,
response owner, resource stalls, completion retirement, fault/abort/reset, and
dependency masks.

Evidence files:

- `/tmp/nmaforge_round4_top_smoke/dams_trace.csv`
- `/tmp/nmaforge_round4_top_smoke/dams_state.csv`
- `/tmp/nmaforge_round4_h16_qkv_trace2/dams_state.csv`
- `/tmp/nmaforge_round4_cnn_trace/dams_state.csv`
- `/tmp/nmaforge_round4_final_attention_20261115/dams_trace.csv`

Top Smoke contains 360 multi-engine busy cycles across existing engine pairs.
H16 QKV, H64 QKV/attention, and CNN traces contain zero multi-engine busy
cycles because their dependency chains serialize the work. The existing
dispatcher already issues legal independent engine commands and preserves
ordered retirement. These traces show no incremental opportunity for another
DAMS scheduler.

Decision: `NO_INCREMENTAL_OPPORTUNITY`; stop product DAMS RTL development until
a real descriptor pair demonstrates an unused legal overlap window. Keep the
passive trace for future Fault-Causal DV ownership and epoch analysis.
