#!/usr/bin/env bash
set -euo pipefail
make -C dv/block/control/sim descriptor-validator-regress DESCRIPTOR_VALIDATOR_OUT=/tmp/nmaforge_round30_deit_descriptor_validator
make -C dv/subsystem/top_smoke/sim ai_smoke AI_RANDOM_CASES=0 AI_SEED=300029
make -C dv/subsystem/top_smoke/sim ai_deit_round30_top_repack_256k AI_DEIT_R30_LAYOUT=q_dense AI_DEIT_R30_RUN=/tmp/nmaforge_round30_deit_q_dense_retry
make -C dv/subsystem/top_smoke/sim ai_deit_round30_top_repack_256k AI_DEIT_R30_LAYOUT=k_major AI_DEIT_R30_RUN=/tmp/nmaforge_round30_deit_k_major
make -C dv/subsystem/top_smoke/sim ai_deit_round30_top_repack_256k AI_DEIT_R30_LAYOUT=v_matrix_b AI_DEIT_R30_RUN=/tmp/nmaforge_round30_deit_v_matrix_b
