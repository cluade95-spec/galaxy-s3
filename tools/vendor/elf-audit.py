#!/usr/bin/env python3
# Audit every ELF file under a directory: machine, ABI flags, type (PIE or not), text relocations, NEEDED, symbols.
# Usage (needs pyelftools): python3 -I elf-audit.py <extracted /system dir> <out.json>
# Read-only; never executes the files it inspects. Used for the Phase 3/4 audits; re-run on VERIFIED firmware.
import os,sys,hashlib,json,collections
from elftools.elf.elffile import ELFFile
from elftools.elf.dynamic import DynamicSection
from elftools.elf.sections import SymbolTableSection
root=sys.argv[1]; out=sys.argv[2]
rows=[]
for r,ds,fs in os.walk(root):
    if '.git' in ds: ds.remove('.git')
    for f in fs:
        p=os.path.join(r,f); rel=os.path.relpath(p,root)
        if os.path.islink(p):
            rows.append(dict(path=rel,kind='symlink',target=os.readlink(p))); continue
        try: b=open(p,'rb').read()
        except Exception: continue
        row=dict(path=rel,size=len(b),sha256=hashlib.sha256(b).hexdigest(),kind='file')
        if b[:4]==b'\x7fELF':
            try:
                e=ELFFile(open(p,'rb'))
                row.update(kind='elf',etype=e['e_type'],machine=e['e_machine'],eclass=e['e_ident']['EI_CLASS'],flags=hex(e['e_flags']))
                needed=[];soname=None;textrel=False;flags1=0;bind_now=False
                for s in e.iter_sections():
                    if isinstance(s,DynamicSection):
                        for t in s.iter_tags():
                            if t.entry.d_tag=='DT_NEEDED': needed.append(t.needed)
                            elif t.entry.d_tag=='DT_SONAME': soname=t.soname
                            elif t.entry.d_tag=='DT_TEXTREL': textrel=True
                            elif t.entry.d_tag=='DT_FLAGS' and (t.entry.d_val&4): textrel=True
                            elif t.entry.d_tag=='DT_FLAGS_1': flags1=t.entry.d_val
                und=[];dfn=[]
                ds_=e.get_section_by_name('.dynsym')
                if ds_:
                    for sym in ds_.iter_symbols():
                        if not sym.name: continue
                        if sym['st_shndx']=='SHN_UNDEF': und.append(sym.name)
                        else: dfn.append(sym.name)
                interp=None
                for seg in e.iter_segments():
                    if seg['p_type']=='PT_INTERP': interp=seg.get_interp_name()
                row.update(needed=needed,soname=soname,textrel=textrel,pie=bool(flags1&0x08000000),interp=interp,undef=und,defs=dfn)
            except Exception as ex:
                row.update(kind='elf-error',err=str(ex))
        rows.append(row)
json.dump(rows,open(out,'w'))
c=collections.Counter(r['kind'] for r in rows); print(dict(c))
