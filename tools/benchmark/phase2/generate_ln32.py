#!/usr/bin/env python3
"""Independent Python division oracle plus fixed full LN32 integer Golden."""
import argparse,json,math,random
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);rng=random.Random(20261115)
mask=(1<<64)-1
def sat(x):return max(-(1<<31),min((1<<31)-1,x))
def oracle(xs,gs,bs,eps):
 total=sum(xs);q=abs(total)//32;mean=-q if total<0 else q
 var=sum((x-mean)**2 for x in xs)//32;root=math.isqrt(var+max(1,eps));assert root
 inv=(1<<30)//root
 return [sat((sat(((x-mean)*g)>>15)*inv>>30)+b)for x,g,b in zip(xs,gs,bs)]
cases=[]
for i in range(40):
 x=[rng.randrange(-32768,32768)for _ in range(32)];g=[rng.randrange(-65536,65536)for _ in x];b=[rng.choice([-(1<<31),(1<<31)-1,-1,0,1,123])for _ in x];eps=[0,1,2,65535][i%4]
 if i==0:x=[0]*32
 if i==1:x=[-1]+[0]*31
 if i==2:x=[-33]+[0]*31
 if i==3:x=[32767,-32768]*16
 if i==4:x=[-(1<<31)]*32
 if i==5:x=[(1<<31)-1]*32
 if i==6:x=[2]*31+[3]
 if i==7:x=[-2]*31+[-3]
 if i%3==0:g=[32768]*32;b=[0]*32
 cases.append((i,eps,x,g,b,oracle(x,g,b,eps)))
with (a.out/'vectors.txt').open('w')as f:
 f.write(str(len(cases))+'\n')
 for i,eps,x,g,b,y in cases:
  f.write(f'{i} {eps}\n')
  for row in zip(x,g,b,y):f.write(' '.join(f'{v&0xffffffff:08x}'for v in row)+'\n')
# Mean is checked against generic RTL's exact magnitude divide +32bitcast.
values={0,1,-1,31,-31,32,-32,33,-33,2**31-1,-2**31,2**63-1,-2**63}
for q in [2**31-1,2**31,2**31+1]:
 for remainder in [0,1,31]:
  for sign in [-1,1]:values.add(sign*(q*32+remainder))
for _ in range(1200):values.add(rng.randrange(-2**63,2**63))
mean_count=len(values)
with (a.out/'mean.txt').open('w')as f:
 f.write(str(len(values))+'\n')
 for v in sorted(values):
  mag=abs(v);q=mag//32;err=q>2**31;mean=(-q if v<0 else q)&0xffffffff
  f.write(f'{v&mask:016x} {mean:08x} {int(err)}\n')
values={0,1,31,32,33,2**32-1,2**63,2**64-1}
for _ in range(1200):values.add(rng.randrange(2**64))
with (a.out/'variance.txt').open('w')as f:
 f.write(str(len(values))+'\n')
 for v in sorted(values):f.write(f'{v:016x} {v//32:016x}\n')
(a.out/'oracle.json').write_text(json.dumps({'full_vectors':len(cases),'mean_cases':mean_count,'variance_cases':len(values),'numeric_domain':'first4 and random signed16; constant INT32_MIN/MAX stress beyond normative general LN input domain; mean/variance state probes cover arbitrary64bit accumulators','formula':'abs(sum)//32 restore sign; generic >2^31 error; unsignedsum_sq//32; Python arbitrary precision independent of RTL shifts'},indent=2)+'\n')
print('PHASE2_LN32_ORACLE_PASS vectors=40 mean/variance independently generated')
