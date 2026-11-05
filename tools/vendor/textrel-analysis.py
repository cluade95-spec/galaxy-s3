#!/usr/bin/env python3
# For each ELF with DT_TEXTREL: count relocations that land in executable (PF_X) segments vs total.
# Read-only static analysis; never executes files. Usage: python3 -I textrel-analysis.py <system dir> <out.tsv>
import os,sys,struct
from elftools.elf.elffile import ELFFile
from elftools.elf.dynamic import DynamicSection
from elftools.elf.relocation import RelocationSection
root,out=sys.argv[1],sys.argv[2]
rows=[]
for r,ds,fs in os.walk(root):
    for f in sorted(fs):
        p=os.path.join(r,f)
        if os.path.islink(p): continue
        try:
            if open(p,'rb').read(4)!=b'\x7fELF': continue
            e=ELFFile(open(p,'rb'))
        except Exception: continue
        if e['e_machine']!='EM_ARM': continue
        dyn=[s for s in e.iter_sections() if isinstance(s,DynamicSection)]
        if not dyn or not any(t.entry.d_tag=='DT_TEXTREL' for t in dyn[0].iter_tags()): continue
        xs=[(s['p_vaddr'],s['p_vaddr']+s['p_memsz']) for s in e.iter_segments() if s['p_type']=='PT_LOAD' and s['p_flags']&1]
        tot=tx=0; kinds={}
        for s in e.iter_sections():
            if isinstance(s,RelocationSection):
                for rel in s.iter_relocations():
                    tot+=1
                    a=rel['r_offset']
                    if any(lo<=a<hi for lo,hi in xs):
                        tx+=1; t=rel['r_info_type']; kinds[t]=kinds.get(t,0)+1
        rows.append((os.path.relpath(p,root),os.path.getsize(p),tot,tx,','.join('%d:%d'%kv for kv in sorted(kinds.items()))))
rows.sort(key=lambda x:-x[3])
with open(out,'w') as o:
    o.write('path\tsize\ttotal_relocs\trelocs_in_text\ttext_reloc_types\n')
    for x in rows: o.write('\t'.join(map(str,x))+'\n')
print(len(rows),'textrel ELFs')
