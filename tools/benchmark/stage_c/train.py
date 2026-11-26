#!/usr/bin/env python3
"""Deterministic synthetic H32/L2 Post-LN training; no pretrained-model claim."""
import argparse,json,math,random,hashlib
from pathlib import Path
import torch
from torch import nn
from torch.nn import functional as F
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--epochs',type=int,default=60);p.add_argument('--train',type=int,default=2048);p.add_argument('--test',type=int,default=256);a=p.parse_args()
torch.set_num_threads(1);torch.manual_seed(20261110);torch.use_deterministic_algorithms(True)
def sequences(n,seed,heldout=False):
 r=random.Random(seed);out=[]
 for _ in range(n):
  mode=r.randrange(4);states=list(range(28));random.Random(20261110+mode).shuffle(states);state=r.choice(states[21:] if heldout else states[:21]);s=[mode,state+4]
  for pos in range(2,17):state=(state+mode*5+pos*3)%28;s.append(state+4)
  out.append(s)
 return out
class Block(nn.Module):
 def __init__(self):
  super().__init__()
  for k in ['q','k','v','wo']:setattr(self,k,nn.Linear(32,32,bias=False))
  self.up=nn.Linear(32,128,bias=False);self.down=nn.Linear(128,32,bias=False);self.ln1=nn.LayerNorm(32,eps=1/64);self.ln2=nn.LayerNorm(32,eps=1/64)
 def forward(self,x):
  b,t,_=x.shape;q,k,v=[getattr(self,n)(x).reshape(b,t,2,16).transpose(1,2) for n in ['q','k','v']]
  score=(q@k.transpose(-1,-2))/4
  score=score.masked_fill(torch.ones(t,t,dtype=torch.bool).triu(1),float('-inf'))
  # Hardware uses base-2 exponentiation of scores in Q8.8.
  att=(torch.softmax(score*math.log(2),-1)@v).transpose(1,2).reshape(b,t,32)
  y=self.ln1(x+self.wo(att));z=self.up(y);g=torch.where(z<=-2,0,torch.where(z>=2,z,z*(z+2)/4))
  return self.ln2(y+self.down(g))
class Model(nn.Module):
 def __init__(self):
  super().__init__();self.emb=nn.Embedding(32,32);self.pos=nn.Embedding(16,32);self.blocks=nn.ModuleList([Block(),Block()])
 def forward(self,t):
  x=self.emb(t)+self.pos(torch.arange(t.shape[1]))
  for block in self.blocks:x=block(x)
  return F.linear(x,self.emb.weight)
m=Model();train=torch.tensor(sequences(a.train,20261111));test=sequences(a.test,20261112,True);tt=torch.tensor(test);opt=torch.optim.AdamW(m.parameters(),lr=.006)
for epoch in range(a.epochs):
 for ids in torch.randperm(len(train)).split(128):
  logits=m(train[ids,:16]);loss=F.cross_entropy(logits.reshape(-1,32),train[ids,1:].reshape(-1));opt.zero_grad();loss.backward();nn.utils.clip_grad_norm_(m.parameters(),1);opt.step()
  with torch.no_grad():
   for block in m.blocks:block.up.weight.clamp_(-.49,.49)
 if (epoch+1)%10==0:print('epoch',epoch+1,'loss',float(loss),flush=True)
with torch.no_grad():
 logits=m(tt[:,:16]);ce=float(F.cross_entropy(logits.reshape(-1,32),tt[:,1:].reshape(-1)));acc=float((logits.argmax(-1)==tt[:,1:]).float().mean());decode_ce=float(F.cross_entropy(logits[:,4:,:].reshape(-1,32),tt[:,5:].reshape(-1)));decode_acc=float((logits[:,4:,:].argmax(-1)==tt[:,5:]).float().mean())
def q(t,s):return (t.detach()*s).round().clamp(-128,127).to(torch.int32).tolist()
def w(layer,s):return q(layer.weight.T,s)
layers=[]
for i,b in enumerate(m.blocks):
 d={'weights':{**{('wo' if n=='wo' else 'w'+n):w(getattr(b,n),16) for n in ['q','k','v','wo']},'wup':w(b.up,256),'wdown':w(b.down,16)},'shifts':{'qkv':5,'wo':3,'wup':4,'wdown':4}}
 for n in [1,2]:
  ln=getattr(b,'ln'+str(n));d['gamma'+str(n)]=[round(float(v)*32768*16) for v in ln.weight.detach()];d['beta'+str(n)]=[round(float(v)*16) for v in ln.bias.detach()]
 layers.append(d)
# Embeddings/LayerNorm use scale16; QKV scale8, GELU Q8.8.
emb=q(m.emb.weight,16);pos=q(m.pos.weight,16)
out={'name':'stage_c_h32_l2_synthetic_postln','seed':20261110,'shape':{'hidden':32,'layers':2,'heads':2,'head_dim':16,'context':16,'ffn':128,'vocab':32},'scope':'trained synthetic finite-state next-token task; not pretrained GPT-2/Qwen','embeddings':emb,'positions':pos,'layers':layers,'lm_head':[[emb[t][f] for t in range(32)] for f in range(32)],'lm_shift':0,'gelu_shift':4,'training':{'epochs':a.epochs,'train_sequences':a.train,'split':'mode-stratified disjoint initial states:21train/7test per mode; seeds20261110+mode','distinct_train_trajectories':len({tuple(v) for v in train.tolist()}),'distinct_test_trajectories':len({tuple(v) for v in test}),'train_test_trajectory_overlap':len({tuple(v) for v in train.tolist()} & {tuple(v) for v in test}),'float_decode_accuracy':decode_acc,'float_decode_cross_entropy':decode_ce,'test_sequences':a.test,'float_accuracy':acc,'float_cross_entropy':ce,'float_perplexity':math.exp(ce),'framework':str(torch.__version__),'algorithm':'AdamW lr .006 deterministic CPU; PTQ power-of-two scales; piecewise GELU'},'heldout':test,'prompt':test[0]}
a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(out,indent=2)+'\n');print('H32_TRAIN_PASS',acc,ce,hashlib.sha256(a.out.read_bytes()).hexdigest())
