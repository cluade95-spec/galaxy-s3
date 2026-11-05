#!/usr/bin/env python3
# Count the files of every project in a repo manifest WITHOUT downloading file contents:
# per project, a blobless depth-1 fetch (commit + trees only) and `git ls-tree -r` to count files.
# (Sizes are NOT measured: `git ls-tree -l` on a blobless clone would fetch every blob, i.e. the file contents.)
# Usage: measure-source-size.py <default.xml> <scratch dir> <out.tsv> [jobs]
# Metadata only; scratch repos are deleted after each project. Not a clone of the source tree.
import sys,os,subprocess,shutil,xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
man,scratch,out=sys.argv[1:4]; jobs=int(sys.argv[4]) if len(sys.argv)>4 else 6
r=ET.parse(man).getroot()
rem={x.get('name'):x for x in r.findall('remote')}
d=r.find('default'); defrem=d.get('remote'); defrev=d.get('revision')
BASE={'github':'https://github.com/','aosp':'https://android.googlesource.com/'}
removed={x.get('name') for x in r.findall('remove-project')}
projs=[]
for p in r.findall('project'):
    n=p.get('name'); 
    if n in removed: continue
    rn=p.get('remote') or defrem
    if rn not in BASE: projs.append((p.get('path') or n,n,rn,None,None,p.get('groups') or '')); continue
    rev=p.get('revision') or rem[rn].get('revision') or defrev
    projs.append((p.get('path') or n,n,rn,BASE[rn]+n,rev,p.get('groups') or ''))
os.makedirs(scratch,exist_ok=True)
def one(t):
    path,name,rn,url,rev,groups=t
    if url is None: return (path,name,rn,groups,'SKIP-remote','','')
    d=os.path.join(scratch,path.replace('/','_'))
    shutil.rmtree(d,ignore_errors=True); os.makedirs(d)
    try:
        subprocess.run(['git','init','-q',d],check=True)
        f=subprocess.run(['git','-C',d,'fetch','-q','--depth','1','--filter=blob:none',url,rev],capture_output=True,text=True,timeout=300)
        if f.returncode: return (path,name,rn,groups,'FAIL',f.stderr.strip()[:120].replace('\t',' '),'')
        o=subprocess.run(['git','-C',d,'ls-tree','-r','FETCH_HEAD'],capture_output=True,text=True,timeout=300).stdout
        n=sum(1 for l in o.splitlines() if ' blob ' in l)
        return (path,name,rn,groups,'OK','',str(n))
    except Exception as e:
        return (path,name,rn,groups,'FAIL',str(e)[:100],'')
    finally: shutil.rmtree(d,ignore_errors=True)
with ThreadPoolExecutor(jobs) as ex, open(out,'w') as o:
    o.write('path\tname\tremote\tgroups\tstatus\terror\tfiles\n')
    for i,res in enumerate(ex.map(one,projs)):
        o.write('\t'.join(res)+'\n'); o.flush()
        if i%40==0: print(i,len(projs),res[0],res[4],flush=True)
print('done',len(projs))
