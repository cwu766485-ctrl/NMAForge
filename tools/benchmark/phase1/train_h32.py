#!/usr/bin/env python3
"""Disjoint-triple periodic recall task; fixed H32/L2/H2/FFN128 post-LN model.

No pretrained claim. FP32 admission precedes INT8 export; simple baselines and
an explicit perfect task oracle prevent overstating synthetic-task quality.
"""
import argparse,hashlib,json,math,random
from pathlib import Path
import torch
from torch import nn
from torch.nn import functional as F
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--epochs',type=int,default=60);p.add_argument('--train',type=int,default=1024);p.add_argument('--test',type=int,default=128);a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=True);torch.set_num_threads(1);torch.manual_seed(20261112);torch.use_deterministic_algorithms(True)
def data(n,seed,used):
 rng=random.Random(seed);out=[]
 while len(out)<n:
  abc=tuple(rng.sample(range(32),3))
  # Prevent cyclic rotations of any trajectory crossing splits.
  canonical=min(abc,abc[1:]+abc[:1],abc[2:]+abc[:2])
  if canonical in used:continue
  used.add(canonical);out.append([abc[i%3] for i in range(17)])
 return out
used=set();train=data(a.train,20261112,used);test=data(a.test,20261113,used)
assert not {tuple(x) for x in train}&{tuple(x) for x in test}
class Block(nn.Module):
 def __init__(self):
  super().__init__()
  for n in ['q','k','v','wo']:setattr(self,n,nn.Linear(32,32,bias=False))
  self.up=nn.Linear(32,128,bias=False);self.down=nn.Linear(128,32,bias=False);self.ln1=nn.LayerNorm(32,eps=1/64);self.ln2=nn.LayerNorm(32,eps=1/64)
 def forward(self,x):
  b,t,_=x.shape;q,k,v=[getattr(self,n)(x).reshape(b,t,2,16).transpose(1,2) for n in ['q','k','v']]
  scores=(q@k.transpose(-1,-2))/4;scores=scores.masked_fill(torch.ones(t,t,dtype=torch.bool).triu(1),-1e9)
  att=(torch.softmax(scores*math.log(2),-1)@v).transpose(1,2).reshape(b,t,32)
  y=self.ln1(x+self.wo(att));z=self.up(y);z=torch.where(z<=-2,0,torch.where(z>=2,z,z*(z+2)/4))
  return self.ln2(y+self.down(z))
class Model(nn.Module):
 def __init__(self):
  super().__init__();self.emb=nn.Embedding(32,32);self.pos=nn.Embedding(16,32);self.blocks=nn.ModuleList([Block(),Block()])
 def forward(self,t):
  x=self.emb(t)+self.pos(torch.arange(t.shape[1]))
  for block in self.blocks:x=block(x)
  return F.linear(x,self.emb.weight)
m=Model();tr=torch.tensor(train);tt=torch.tensor(test);opt=torch.optim.AdamW(m.parameters(),lr=.003)
def metrics(seq):
 with torch.no_grad():
  logits=m(seq[:,:16]);v=logits[:,4:];target=seq[:,5:];ce=float(F.cross_entropy(v.reshape(-1,32),target.reshape(-1)));acc=float((v.argmax(-1)==target).float().mean())
 return dict(accuracy=acc,cross_entropy=ce,perplexity=math.exp(ce))
for ep in range(a.epochs):
 for ids in torch.randperm(len(tr)).split(64):
  logits=m(tr[ids,:16]);loss=F.cross_entropy(logits[:,2:].reshape(-1,32),tr[ids,3:].reshape(-1));opt.zero_grad();loss.backward();nn.utils.clip_grad_norm_(m.parameters(),1);opt.step()
  with torch.no_grad():
   for b in m.blocks:b.up.weight.clamp_(-.49,.49)
 if (ep+1)%10==0:print('EPOCH',ep+1,float(loss),metrics(tt),flush=True)
fp=metrics(tt);counts=[0]*32;big=[[0]*32 for _ in range(32)]
for seq in train:
 for pos in range(4,16):counts[seq[pos+1]]+=1;big[seq[pos]][seq[pos+1]]+=1
unigram=max(range(32),key=lambda x:counts[x]);bp=[max(range(32),key=lambda x:row[x]) for row in big]
base={k:sum(fn(seq,pos)==seq[pos+1] for seq in test for pos in range(4,16))/(len(test)*12) for k,fn in [('unigram',lambda s,p:unigram),('copy_current',lambda s,p:s[p]),('trained_bigram',lambda s,p:bp[s[p]]),('lag3_task_oracle',lambda s,p:s[p-2])]}
quality={'task':'period-3 recall of three distinct random vocabulary symbols; causal next-token, not language modeling','split':'disjoint triples including cyclic rotations; all token IDs shared, compositions unseen','train':metrics(tr),'fp32':fp,'baselines':base,'fp32_admitted':fp['accuracy']>=.9 and fp['accuracy']-max(base[k] for k in ['unigram','copy_current','trained_bigram'])>=.5,'train_count':len(train),'test_count':len(test),'overlap':0,'seed':20261112,'framework':str(torch.__version__)}
(a.out/'fp32_quality.json').write_text(json.dumps(quality,indent=2)+'\n');torch.save(m.state_dict(),a.out/'fp32_state.pt')
if not quality['fp32_admitted']:print('FP32_QUALITY_REJECT',quality,flush=True);raise SystemExit(2)
def q(t,s):return (t.detach()*s).round().clamp(-128,127).to(torch.int32).tolist()
layers=[]
for b in m.blocks:
 d={'weights':{**{('wo' if n=='wo' else 'w'+n):q(getattr(b,n).weight.T,16) for n in ['q','k','v','wo']},'wup':q(b.up.weight.T,256),'wdown':q(b.down.weight.T,16)},'shifts':{'qkv':5,'wo':3,'wup':4,'wdown':4}}
 for i in [1,2]:
  ln=getattr(b,'ln'+str(i));d['gamma'+str(i)]=[round(float(v)*32768*16) for v in ln.weight.detach()];d['beta'+str(i)]=[round(float(v)*16) for v in ln.bias.detach()]
 layers.append(d)
emb=q(m.emb.weight,16)
out={'name':'phase1_h32_l2_period3_postln','shape':{'hidden':32,'layers':2,'heads':2,'head_dim':16,'context':16,'ffn':128,'vocab':32},'scope':quality['task'],'embeddings':emb,'positions':q(m.pos.weight,16),'layers':layers,'lm_head':[[emb[t][f] for t in range(32)] for f in range(32)],'lm_shift':0,'gelu_shift':4,'training':quality,'heldout':test,'prompt':test[0]}
(a.out/'h32_int8.json').write_text(json.dumps(out,indent=2)+'\n');print('FP32_QUALITY_PASS',quality,'model_sha256',hashlib.sha256((a.out/'h32_int8.json').read_bytes()).hexdigest(),flush=True)
