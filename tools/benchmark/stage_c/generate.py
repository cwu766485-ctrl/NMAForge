#!/usr/bin/env python3
"""Shape-driven two-layer staged CMDQ mapper; only embeddings are host inputs.

Golden arithmetic uses the existing block reference, independently of reference.py.
Workspace is reused only after full ordered completion and exhaustive readback.
"""
import sys,json,argparse,hashlib,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sys.path[:0]=[str(ROOT/'sw/tools'),str(ROOT/'dv/block/compute/matrix/ref')]
from cimforge_mapper import Mapper,Tensor,OP_GEMM,OP_REQUANT,OP_RESIDUAL,OP_LAYERNORM,OP_GELU,OP_CAUSAL_SOFTMAX,OP_KV_WRITE,OP_KV_READ,FLAG_PACK_I8,FLAG_PACK_I8_TILE_A,FLAG_BIAS,_pack_matrix_a_physical,_pack_matrix_b_physical,tensor_storage_words
from ai_a3_reference import gemm_i8_i32,requant_i8,layernorm_q15,gelu_q8_8,residual_i32,softmax_q15
from generate_h16_incremental_decode import write_pairs,descriptor_manifest
P=0xa55aa55a

def generate(model,out):
 m=json.loads(model.read_text());s=m['shape'];H=s['hidden'];D=s['head_dim'];C=s['context'];F=s['ffn'];heads=s['heads'];L=s['layers'];V=s['vocab'];R=4
 if H!=heads*D or any(x%4 for x in [H,D,C,F,V]) or D>16 or C>16:raise ValueError('unsupported existing KV scatter geometry')
 mapper=Mapper();mapper.next_addr=0x1000;mapper.task_id=0x4000
 def tensor(n,mat,layout):
  rows=len(mat);cols=len(mat[0]);vals=(_pack_matrix_a_physical(mat,rows) if layout=='matrix_a_tile' else _pack_matrix_b_physical(mat) if layout=='matrix_b_tile' else [v for row in mat for v in row]);return mapper.tensor(n,(rows,cols),'i8_packed' if 'tile' in layout else 'i32',layout,vals)
 # All immutable weights, normalization parameters, input embeddings, and live KV.
 wt=[];kt=[];vt=[];params=[]
 for li,l in enumerate(m['layers']):
  w={}
  for n in ['q','k','v']:
   for head in range(heads):w[n,head]=tensor(f'L{li}_{n}{head}_W',[row[head*D:(head+1)*D] for row in l['weights']['w'+n]],'matrix_b_tile')
  for head in range(heads):w['wo',head]=tensor(f'L{li}_wo{head}_W',l['weights']['wo'][head*D:(head+1)*D],'matrix_b_tile')
  for n in ['up','down']:w[n]=tensor(f'L{li}_{n}_W',l['weights']['w'+n],'matrix_b_tile')
  wt.append(w);params.append({n:mapper.tensor(f'L{li}_{n}',(H,),'i32','vector',l[n]) for n in ['gamma1','beta1','gamma2','beta2']})
  kt.append(mapper.tensor(f'L{li}_key',(heads*D*C,),'i8_packed','matrix_b_cache',[0]*(heads*D*C//4)));vt.append(mapper.tensor(f'L{li}_value',(heads*C*D,),'i8_packed','matrix_b_cache',[0]*(heads*C*D//4)))
 lm=tensor('lm_weight',m['lm_head'],'matrix_b_tile');inputs=[];tokens=m['prompt'][:12]
 for pos,tok in enumerate(tokens):
  row=[max(-128,min(127,a+b)) for a,b in zip(m['embeddings'][tok],m['positions'][pos])];rows=[row]+[[0]*H for _ in range(R-1)]
  inputs.append((tensor(f't{pos}_input_packed',rows,'matrix_a_tile'),tensor(f't{pos}_input_i32',rows,'row-major'),rows))
 initial={}
 for t in mapper.tensors.values():
  for i,v in enumerate(tensor_storage_words(t)):initial[t.addr+4*i]=v&0xffffffff
 persistent_end=mapper.next_addr;workspace=(persistent_end+255)&~255
 key=[[[[0]*D for _ in range(C)] for _ in range(heads)] for _ in range(L)];val=[[[[0]*D for _ in range(C)] for _ in range(heads)] for _ in range(L)]
 out.mkdir(parents=True,exist_ok=True);stages=[];high=workspace
 # Golden helper records every output and poisons every word written.
 for pos,(xi8,xi32,xrows) in enumerate(inputs):
  mapper.next_addr=workspace;start=len(mapper.descriptors);gold={};poison=set();records={};stage_init={};kv_records={}
  def emit32(name,rows):
   t=tensor(f't{pos}_{name}',[[0]*len(rows[0]) for _ in rows],'row-major')
   for i,v in enumerate(v for row in rows for v in row):gold[t.addr+4*i]=v&0xffffffff;poison.add(t.addr+4*i)
   records[name]={'addr':t.addr,'rows':rows,'layout':'i32'};return t
  def emit8(name,rows):
   t=tensor(f't{pos}_{name}',[[0]*len(rows[0]) for _ in rows],'matrix_a_tile')
   for i,v in enumerate(_pack_matrix_a_physical(rows,R)):gold[t.addr+4*i]=v&0xffffffff;poison.add(t.addr+4*i)
   records[name]={'addr':t.addr,'rows':rows,'layout':'matrix_a_tile'};return t
  def gemm(name,a,ar,b,br,shift=0):
   rows=gemm_i8_i32(ar,br,shift=shift);t=emit32(name,rows);mapper.add(name,OP_GEMM,a,t,src1=b,m=R,n=len(br[0]),k_or_length=len(br)//4,aux0=1,shift=shift);return t,rows
  def quant(name,t,rows,shift=0):
   qr=[requant_i8(row,shift) for row in rows];qt=emit8(name,qr);mapper.add(name,OP_REQUANT,t,qt,m=R,n=len(rows[0]),k_or_length=R*len(rows[0]),flags=FLAG_PACK_I8|FLAG_PACK_I8_TILE_A,aux0=1,shift=shift);return qt,qr
  for li,l in enumerate(m['layers']):
   pref=f'L{li}_';sh=l['shifts'];qw={};qr={}
   for n in ['q','k','v']:
    for head in range(heads):
     br=[row[head*D:(head+1)*D] for row in l['weights']['w'+n]];raw,rr=gemm(pref+n+str(head)+'_raw',xi8,xrows,wt[li][n,head],br,sh['qkv']);qw[n,head],qr[n,head]=quant(pref+n+str(head),raw,rr)
     if n in ['k','v']:(key if n=='k' else val)[li][head][pos]=qr[n,head][0][:]
   for head in range(heads):
    for fg in range(D//4):
     # B[feature,token]: token groups select columns; four source features/word.
     corr=(pos//4)*(D*4-16)+fg*16
     mapper.add(pref+f'append_k{head}_{fg}',OP_KV_WRITE,qw['k',head],kt[li],src0_offset=fg*16,dst_offset=corr,k_or_length=1,aux0=(head<<16)|pos,src0_stride=4,src1_stride=D*C)
    mapper.add(pref+f'append_v{head}',OP_KV_WRITE,qw['v',head],vt[li],k_or_length=D,flags=1,aux0=(head<<16)|pos,src0_stride=16,src1_stride=D*C)
   read={}
   for kind,cache,state in [('k',kt[li],key[li]),('v',vt[li],val[li])]:
    for head in range(heads):
     mat=[list(col) for col in zip(*state[head])] if kind=='k' else state[head];words=_pack_matrix_b_physical(mat)
     t=mapper.tensor(f't{pos}_{pref}{kind}read{head}',(D,C),'i8_packed','matrix_b_tile',[0]*len(words));read[kind,head]=t
     mapper.add(pref+f'read_{kind}{head}',OP_KV_READ,cache,t,k_or_length=D*C//4,aux0=head<<16,src1_stride=D*C)
     kv_records[li,kind,head]=words
     for i,v in enumerate(words):gold[t.addr+4*i]=v&0xffffffff;poison.add(t.addr+4*i);gold[cache.addr+head*D*C+4*i]=v&0xffffffff
   proj=[];prows=[]
   for head in range(heads):
    kbr=[list(col) for col in zip(*key[li][head])]
    scores,sr=gemm(pref+f'score{head}',qw['q',head],qr['q',head],read['k',head],kbr)
    pr=[softmax_q15(sr[0][:pos+1])+[0]*(C-pos-1)]+[[0]*C for _ in range(R-1)];pt=emit32(pref+f'prob{head}',pr)
    # Softmax operates only on the live row. Padding is an explicit zero constant,
    # initialized once; it is not a host-provided Transformer activation.
    for i in range(C,R*C):poison.discard(pt.addr+4*i);stage_init[pt.addr+4*i]=0
    mapper.add(pref+f'softmax{head}',OP_CAUSAL_SOFTMAX,scores,pt,k_or_length=C,aux0=pos)
    p8,p8r=quant(pref+f'prob8{head}',pt,pr,8);av,avr=gemm(pref+f'av{head}',p8,p8r,read['v',head],val[li][head]);av8,av8r=quant(pref+f'av8{head}',av,avr,7)
    wb=l['weights']['wo'][head*D:(head+1)*D];o,orr=gemm(pref+f'wo{head}',av8,av8r,wt[li]['wo',head],wb,sh['wo']);proj.append(o);prows.append(orr)
   merge_rows=[[0]*H for _ in range(R)];merged=proj[0];merge_rows=prows[0]
   for head in range(1,heads):
    merge_rows=[residual_i32(a,b) for a,b in zip(merge_rows,prows[head])];n=emit32(pref+'merged',merge_rows);mapper.add(pref+'merge',OP_RESIDUAL,merged,n,src1=proj[head],k_or_length=R*H,aux0=1);merged=n
   r1rows=[residual_i32(a,b) for a,b in zip(merge_rows,xrows)];r1=emit32(pref+'res1',r1rows);mapper.add(pref+'res1',OP_RESIDUAL,merged,r1,src1=xi32,k_or_length=R*H,aux0=1)
   def ln(name,src,rows,num):
    nr=[layernorm_q15(row,l['gamma'+str(num)],l['beta'+str(num)]) for row in rows];n=emit32(pref+name,nr)
    for r in range(R):mapper.add(pref+name+str(r),OP_LAYERNORM,src,n,src1=params[li]['gamma'+str(num)],bias=params[li]['beta'+str(num)],k_or_length=H,flags=FLAG_BIAS,aux0=1,src0_offset=r*H*4,dst_offset=r*H*4)
    return n,nr
   ln1,ln1r=ln('ln1',r1,r1rows,1);ln1p,ln1pr=quant(pref+'ln1_i8',ln1,ln1r)
   up,upr=gemm(pref+'up',ln1p,ln1pr,wt[li]['up'],l['weights']['wup'],sh['wup']);gr=[[gelu_q8_8(v) for v in row] for row in upr];gt=emit32(pref+'gelu',gr);mapper.add(pref+'gelu',OP_GELU,up,gt,k_or_length=R*F,aux0=1)
   gp,gpr=quant(pref+'gelu_i8',gt,gr,m['gelu_shift']);down,dr=gemm(pref+'down',gp,gpr,wt[li]['down'],l['weights']['wdown'],sh['wdown'])
   r2r=[residual_i32(a,b) for a,b in zip(dr,ln1r)];r2=emit32(pref+'res2',r2r);mapper.add(pref+'res2',OP_RESIDUAL,down,r2,src1=ln1,k_or_length=R*H,aux0=1)
   ln2,ln2r=ln('ln2',r2,r2r,2);xi8,xrows=quant(pref+'ln2_i8',ln2,ln2r);xi32=emit32(pref+'next_input_i32',xrows);mapper.add(pref+'next_input_i32',OP_REQUANT,ln2,xi32,k_or_length=R*H,aux0=1)
  logits,logr=gemm('logits',xi8,xrows,lm,m['lm_head'],m['lm_shift'])
  descs=mapper.descriptors[start:]
  if len(descs)>128:raise ValueError(f'{len(descs)} descriptors exceed current stage')
  for i,d in enumerate(descs):d.wait_mask=1 if i else 0;d.clear_mask=1 if i else 0;d.signal_mask=1 if i+1<len(descs) else 0
  high=max(high,mapper.next_addr)
  # Verify row0 intermediate tensors against the independent scalar model below.
  stages.append({'name':f't{pos}','position':pos,'kind':'prefill' if pos<4 else 'decode','descs':descs,'gold':gold,'poison':poison,'records':records,'zero_padding':stage_init,'logits':logr[0],'kv_records':kv_records})
  for addr,v in stage_init.items():initial[addr]=v
 # queues reserve full advertised depth, not just descriptors used.
 db=(high+4095)&~4095;cb=db+8192;end=cb+2048
 if end>128*1024:raise ValueError(f'SPAD high water {end} >128KiB')
 write_pairs(out/'initial_memory.memh',initial);manifest=[]
 from reference import cache_new,one
 rc=cache_new(m)
 for i,st in enumerate(stages):
  ref=one(m,rc,tokens[i],i);records=st['records']
  assert st['logits']==ref['logits'],('logits',i)
  for li,lr in enumerate(ref['layers']):
   for name in ['merged','res1','ln1','ln1_i8','up','gelu','gelu_i8','down','res2','ln2','ln2_i8']:assert records[f'L{li}_{name}']['rows'][0]==lr[name],(i,li,name)
   for head in range(heads):
    for n in 'qkv':assert records[f'L{li}_{n}{head}']['rows'][0]==lr[n][head*D:(head+1)*D]
    for a,b in [('score','scores'),('prob','prob'),('prob8','p8'),('av','av'),('av8','av8'),('wo','wo')]:assert records[f'L{li}_{a}{head}']['rows'][0]==lr['heads'][head][b],(i,li,head,a)
  for li in range(L):
   for kind in ['k','v']:
    for head in range(heads):
     mat=ref['cache'][li][kind][head]
     # Scalar pack independently: B groups four columns, then four K lanes.
     if kind=='k':mat=[list(c) for c in zip(*mat)]
     packed=[]
     for cg in range(0,len(mat[0]),4):
      for kg in range(0,len(mat),4):
       for col in range(cg,cg+4):packed.append(sum((mat[kg+b][col]&255)<<(8*b) for b in range(4)))
     assert st['kv_records'][li,kind,head]==packed,(i,li,kind,head,'independent KV')
  prefix=out/f'stage_{i}_t{i}';words=[len(st['descs']),db,cb]+[w for d in st['descs'] for w in d.words()];Path(str(prefix)+'_desc.memh').write_text(''.join(f'{w:08x}\n' for w in words));write_pairs(Path(str(prefix)+'_golden.memh'),st['gold']);write_pairs(Path(str(prefix)+'_poison.memh'),{x:P for x in st['poison']})
  manifest.append({'index':i,'name':st['name'],'position':i,'kind':st['kind'],'descriptors':len(st['descs']),'golden_words':len(st['gold']),'descriptor_contract':[descriptor_manifest(d) for d in st['descs']],'tensors':{k:{'address':v['addr'],'shape':[len(v['rows']),len(v['rows'][0])],'layout':v['layout']} for k,v in records.items()},'logits':st['logits']})
 result={'model_sha256':hashlib.sha256(model.read_bytes()).hexdigest(),'shape':s,'stages':manifest,'prefill_tokens':4,'decode_tokens':8,'embedding_host_only':True,'independent_scalar_crosscheck':True,'memory':{'persistent_end':persistent_end,'workspace_begin':workspace,'workspace_end':high,'workspace_bytes':high-workspace,'descriptor_base':db,'completion_base':cb,'high_water_bytes':end,'capacity_bytes':131072,'queue_entries':128},'source_rtl_tree':'479f24f33af0ccfa87fd7458ac9c43f94aae7398'}
 (out/'manifest.json').write_text(json.dumps(result,indent=2)+'\n');print('H32_GENERATOR_PASS',len(stages),end,manifest[0]['descriptors']);return result
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--model',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();generate(a.model,a.out)
