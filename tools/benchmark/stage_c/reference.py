#!/usr/bin/env python3
"""Scalar H32 reference. Imports numeric contracts only, never mapper/Golden."""
import sys,math,json,copy,argparse
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[3]/'sw/tools'))
from reference_tiny_gpt2_int8 import matvec,requant,layer_norm,softmax_q15,gelu_q8_8,sat_i8,clamp,I32_MIN,I32_MAX

def cache_new(m):
 s=m['shape'];return [{k:[[[0]*s['head_dim'] for _ in range(s['context'])] for _ in range(s['heads'])] for k in ['k','v']} for _ in m['layers']]
def one(m,cache,token,pos):
 s=m['shape'];h=s['hidden'];hd=s['head_dim'];ctx=s['context'];slot=pos%ctx;visible=min(pos+1,ctx)
 x=[sat_i8(a+b) for a,b in zip(m['embeddings'][token],m['positions'][slot])];tr=[]
 for li,l in enumerate(m['layers']):
  w=l['weights'];sh=l['shifts'];d={'input':x[:]};qkv={}
  for n in 'qkv':
   raw=matvec(x,w['w'+n],sh['qkv']);d[n+'_raw']=raw;qkv[n]=requant(raw,0);d[n]=qkv[n]
  for head in range(s['heads']):
   for n in 'kv':cache[li][n][head][slot]=qkv[n][head*hd:(head+1)*hd]
  merged=[0]*h;d['heads']=[]
  for head in range(s['heads']):
   q=qkv['q'][head*hd:(head+1)*hd];scores=[sum(a*b for a,b in zip(q,k)) for k in cache[li]['k'][head]]
   prob=softmax_q15(scores[:visible])+[0]*(ctx-visible);p8=requant(prob,8)
   av=[sum(p8[t]*cache[li]['v'][head][t][f] for t in range(ctx)) for f in range(hd)];av8=requant(av,7)
   wo=matvec(av8,w['wo'][head*hd:(head+1)*hd],sh['wo']);merged=[clamp(a+b,I32_MIN,I32_MAX) for a,b in zip(merged,wo)]
   d['heads'].append({'scores':scores,'prob':prob,'p8':p8,'av':av,'av8':av8,'wo':wo})
  d['merged']=merged;d['res1']=[clamp(a+b,I32_MIN,I32_MAX) for a,b in zip(merged,x)]
  d['ln1']=layer_norm(d['res1'],l['gamma1'],l['beta1']);d['ln1_i8']=requant(d['ln1'],0)
  d['up']=matvec(d['ln1_i8'],w['wup'],sh['wup']);d['gelu']=[gelu_q8_8(v) for v in d['up']];d['gelu_i8']=requant(d['gelu'],m['gelu_shift'])
  d['down']=matvec(d['gelu_i8'],w['wdown'],sh['wdown']);d['res2']=[clamp(a+b,I32_MIN,I32_MAX) for a,b in zip(d['down'],d['ln1'])]
  d['ln2']=layer_norm(d['res2'],l['gamma2'],l['beta2']);d['ln2_i8']=requant(d['ln2'],0);x=d['ln2_i8'];tr.append(d)
 return {'layers':tr,'logits':matvec(x,m['lm_head'],m['lm_shift']),'cache':copy.deepcopy(cache)}
def main():
 p=argparse.ArgumentParser();p.add_argument('--model',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();m=json.loads(a.model.read_text());correct=total=0;nll=0
 for seq in m['heldout']:
  c=cache_new(m)
  for pos,tok in enumerate(seq[:-1]):
   r=one(m,c,tok,pos)
   if pos<4:continue
   ls=r['logits'];target=seq[pos+1];peak=max(ls);ex=[math.exp((v-peak)/256) for v in ls];prob=ex[target]/sum(ex);nll-=math.log(max(prob,1e-300));correct+=max(range(len(ls)),key=lambda i:(ls[i],-i))==target;total+=1
 q={'predictions':total,'accuracy':correct/total,'cross_entropy':nll/total,'perplexity':math.exp(nll/total),'logit_scale':256,'positions':'4..15 teacher-forced, full causal prefill0..3','quality_policy':'measured PTQ; no imposed accuracy PASS threshold'}
 a.out.write_text(json.dumps(q,indent=2)+'\n');print('H32_INT8_QUALITY',q)
if __name__=='__main__':main()
