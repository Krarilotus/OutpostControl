import sys, os, re, zipfile
sys.path.insert(0, r'C:\Users\Monsterfish_\AppData\Local\Temp\shcw\tunnelers')
from t import EXT
mine_src=open(r'H:\shc-modding\outpost-control\module\init.lua',encoding='utf8').read()
mine={}
for m in re.finditer(r'K\.(AOB_\w+)\s*=\s*((?:"[^"]*"\s*(?:\.\.\s*)?)+)', mine_src):
    s=''.join(re.findall(r'"([^"]*)"', m.group(2)))
    if m.group(1)=='AOB_SLIDER': continue
    mine[m.group(1)]=s.strip()
mine['AOB_SIZE']=mine.pop('AOB_SIZE',None) or ''
rx=re.compile(r'["\']((?:[0-9A-Fa-f?]{1,2}\s+){5,}[0-9A-Fa-f?]{1,2})["\']')
others=set()
root=r'H:\steam\steamapps\common\Stronghold Crusader Extreme UCP3 new\ucp\modules'
log=open(r'H:\steam\steamapps\common\Stronghold Crusader Extreme UCP3 new\ucp3.log',encoding='utf8',errors='ignore').read()
active=set(re.findall(r'enabling extension: (\S+) version: (\S+)', log))
for name,ver in active:
    if name=='outpost-control': continue
    d=os.path.join(root,'%s-%s'%(name,ver)); z=d+'.zip'
    texts=[]
    if os.path.isdir(d):
        for dp,dn,fn in os.walk(d):
            for f in fn:
                if f.endswith(('.lua','.yml')): texts.append(open(os.path.join(dp,f),encoding='utf8',errors='ignore').read())
    elif os.path.isfile(z):
        zz=zipfile.ZipFile(z)
        for n in zz.namelist():
            if n.endswith(('.lua','.yml')): texts.append(zz.read(n).decode('utf8','ignore'))
    for t in texts:
        for m in rx.finditer(t): others.add((m.group(1), name))
print(len(active),'active modules', len(others),'patterns')
ranges=[]
for p,name in others:
    p2=re.sub(r'\?\?','?',p)
    try: hits=[h for h in EXT.find(p2) if h]
    except Exception: continue
    if 1<=len(hits)<=2:
        for h in hits: ranges.append((h, h+len(p2.split()), name, p2[:40]))
for k,p in mine.items():
    if not p: continue
    hits=[h for h in EXT.find(p) if h]
    if len(hits)!=1: print('MINE', k, 'hits', len(hits)); continue
    a=hits[0]; b=a+len(p.split())
    for (c,d,name,s) in ranges:
        if c < b and a < d: print(k, hex(a), 'overlaps', name, hex(c), s)
