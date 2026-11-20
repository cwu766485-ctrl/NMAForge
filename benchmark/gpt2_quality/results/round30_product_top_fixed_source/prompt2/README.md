# GPT-2 Round 30 second-prompt Product Top replay

This is an additional fixed-package functional replay. The package and RTL are unchanged from the Round 30 QAT evidence. `generated_inputs_and_goldens.tar.gz` contains the generated layer/prompt inputs and independent golden payloads, excluding simulator build products. The raw VCS compile/run and Make logs are retained.

Prompt `[2,19,71,5]` generated `[79,77,69,68]`. Each of four Product Top logit rows has 256 signed INT32 values and matches the independent integer Golden. Runtime mode is prefix recompute in one Top instance, with no reset and no Host intermediate-tensor writes. This does not establish language-model quality or incremental KV Decode.
