# Fault-Causal DV Preparation

This is a specification for the next research phase. It does not change the UVM environment or claim a V0/V1 result.

## Transaction ownership graph

Each accepted SPAD request is a node keyed by `{fabric_epoch, engine, command_id, request_sequence}`. Edges connect request acceptance to registered response, operand consumption, writeback and completion commit. A response may satisfy only the owner and epoch recorded at acceptance. Duplicate, late or orphan responses are explicit failures.

## Fault phases

Fault injection points are classified as `PRE_ACCEPT`, `ACCEPTED_IN_FLIGHT`, `RESPONSE_RETURN`, `WRITEBACK`, `COMPLETION_COMMIT` and `POST_COMMIT`. The model records fault type (parity, protection, descriptor, AXI, timeout), source and cycle. It does not use DUT arithmetic output as a Golden.

## Commit prefix and retirement

The independent scoreboard tracks the architecturally committed prefix of output words and completion words. A fault may stop future writes, but it cannot erase a previously committed prefix. Ordered retirement checks completion queue order, error priority and visibility of all four completion words.

## Epoch/reset/abort

Reset and abort increment an independent epoch model. Requests and responses from an older epoch are rejected after drain rules are applied. Accepted AXI bursts must reach their protocol terminal beat; compute responses must either be consumed by the owning command or be explicitly discarded by the documented abort/reset path.

## Coverage-guided generation

Generation targets requirement-valid crosses only: engine × phase × fault, owner × backpressure, accepted-read × reset, writeback × abort, completion × fault priority and concurrent independent engines. Impossible crosses are excluded with a reasoned waiver. Mutation selection is based on uncovered causal edges, not a larger random test count.

## V0/V1 experiment contract

V0 is the existing directed/random UVM and independent Golden. V1 may add the graph, phase model, commit-prefix checker and requirement-guided sequence selection, but must use the same DUT, mutation set, seed budget and simulator configuration. Report mutation detection rate, tests to target coverage, runtime, functional/SVA/code coverage, false positives and held-out regression results. No V1 benefit is claimed until those paired measurements exist.
