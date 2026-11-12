#!/usr/bin/env python3
"""Independent packed-byte decoder and conservative dispatch contract checks."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[3]/'sw/tools'))
from shape_aware_dispatch import map_matmul

def signed(byte):return byte-256 if byte>127 else byte

def unpack(words):return [signed((w>>(8*i))&255) for w in words for i in range(4)]
count=0
for m in (1,4,8,16):
 for k in (16,32,63,64,65,96,127,128,129):
  aa=[[(r*7+i*3)%256-128 for i in range(k)] for r in range(m)]
  bb=[[(i*5+c*11)%256-128 for c in range(16)] for i in range(k)]
  for policy in ('legacy','shape-aware'):
   desc,av,bv=map_matmul(aa,bb,policy=policy,isolated=True)
   ax,bx=unpack(av),unpack(bv)
   if desc.op==0x52:
    ar=[ax[r*((k+15)//16*16):r*((k+15)//16*16)+k] for r in range(m)]
    br=[bx[i*16:i*16+16] for i in range(k)]
   else:
    ar=[[0]*k for _ in range(16)];br=[[0]*16 for _ in range(k)]
    ix=0
    for rg in range(0,m,4):
     for kg in range(0,k,4):
      for r in range(rg,rg+4):ar[r][kg:kg+4]=ax[ix:ix+4];ix+=4
    ix=0
    for cg in range(0,16,4):
     for kg in range(0,k,4):
      for c in range(cg,cg+4):
       for lane in range(4):br[kg+lane][c]=bx[ix];ix+=1
   assert ar[:m]==aa and br==bb
   assert desc.op==(0x30 if policy=='shape-aware' and m>=8 and k in (16,32,64,128) else 0x52)
   count+=1
try:map_matmul([[1]*16]*8,[[1]*16]*16,policy='shape-aware')
except ValueError:pass
else:raise AssertionError('missing isolated opt-in accepted')
print(f'ROUND2_MAPPER_REFERENCE_PASS cases={count} dynamic_optin_rejected=1')
