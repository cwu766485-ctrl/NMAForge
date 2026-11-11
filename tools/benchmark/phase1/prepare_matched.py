#!/usr/bin/env python3
"""Parameterize the reviewed clocked adapter generator with the admitted model."""
from pathlib import Path
source=Path(__file__).resolve().parents[1]/"stage_c/prepare_bench.py"
s=source.read_text()
assert s.count("(root/'benchmark/research/stage_c/models/h32_l2_int8.json')")==1
assert s.count("[(16,16,16),(16,16,32),(32,32,64),(1,16,32)]")==1
s=s.replace("p.add_argument('--out',type=Path,required=True);", "p.add_argument('--out',type=Path,required=True);p.add_argument('--model',type=Path,required=True);")
s=s.replace("(root/'benchmark/research/stage_c/models/h32_l2_int8.json')", "a.model")
s=s.replace("[(16,16,16),(16,16,32),(32,32,64),(1,16,32)]", "[(4,4,32),(16,16,16),(16,16,32),(32,32,64),(1,16,32),(4,16,32),(8,16,32)]")
exec(compile(s,str(source),'exec'), {'__file__':str(source),'__name__':'__main__'})
