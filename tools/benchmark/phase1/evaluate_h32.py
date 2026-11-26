#!/usr/bin/env python3
"""Blind disjoint-triple check of a fixed checkpoint and fixed INT8 artifact.

Only the model/data declarations are loaded from the trainer AST; neither its
optimizer nor its data/export side effects execute. Numeric reference never
imports the descriptor generator.
"""
import argparse,ast,json,math,random,sys
from pathlib import Path
import torch
from torch import nn
from torch.nn import functional as F
p=argparse.ArgumentParser();p.add_argument('--checkpoint',type=Path,required=True);p.add_argument('--model',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();torch.set_num_threads(1)
source=Path(__file__).with_name('train_h32.py');tree=ast.parse(source.read_text());declarations=[n for n in tree.body if isinstance(n,(ast.FunctionDef,ast.ClassDef)) and n.name in ['data','Block','Model']]
assert len(declarations)==3
exec(compile(ast.Module(body=declarations,type_ignores=[]),str(source),'exec'))
model=Model();model.load_state_dict(torch.load(a.checkpoint,map_location='cpu',weights_only=True));model.eval();qmodel=json.loads(a.model.read_text())
used=set();train=data(1024,20261112,used);validation=data(128,20261113,used);blind=data(128,20261114,used);seq=torch.tensor(blind)
with torch.no_grad():
 logits=model(seq[:,:16])[:,4:];target=seq[:,5:];loss=float(F.cross_entropy(logits.reshape(-1,32),target.reshape(-1)));fpacc=float((logits.argmax(-1)==target).float().mean())
sys.path.insert(0,str(source.parents[1]/'stage_c'));from reference import one,cache_new
correct=total=0;nll=0
for s in blind:
 cache=cache_new(qmodel)
 for pos,tok in enumerate(s[:-1]):
  r=one(qmodel,cache,tok,pos)
  if pos<4:continue
  ls=r['logits'];target=s[pos+1];peak=max(ls);prob=math.exp((ls[target]-peak)/256)/sum(math.exp((v-peak)/256)for v in ls);nll-=math.log(max(prob,1e-300));correct+=max(range(32),key=lambda i:(ls[i],-i))==target;total+=1
counts=[0]*32;big=[[0]*32 for _ in range(32)]
for s in train:
 for pos in range(4,16):counts[s[pos+1]]+=1;big[s[pos]][s[pos+1]]+=1
uni=max(range(32),key=lambda x:counts[x]);bp=[max(range(32),key=lambda x:row[x])for row in big]
bases={k:sum(fn(s,p)==s[p+1]for s in blind for p in range(4,16))/total for k,fn in [('unigram',lambda s,p:uni),('copy_current',lambda s,p:s[p]),('trained_bigram',lambda s,p:bp[s[p]]),('lag3_rule_oracle',lambda s,p:s[p-2])]}
out={'scope':'fresh blind period3 triples, excluded train and monitored validation rotations; fixed weights, no retraining','seed':20261114,'sequences':128,'predictions':total,'fp32':{'accuracy':fpacc,'cross_entropy':loss,'perplexity':math.exp(loss)},'int8':{'accuracy':correct/total,'cross_entropy':nll/total,'perplexity':math.exp(nll/total)},'baselines':bases,'overlap':0,'status':'PASS' if fpacc>=.9 and correct/total>=.9 else 'FAIL','limitation':'synthetic lag3 memory diagnostic; rule oracle perfect; not natural-language quality or unseen task generalization'}
a.out.write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2));assert out['status']=='PASS'
