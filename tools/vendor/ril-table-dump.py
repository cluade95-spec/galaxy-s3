#!/usr/bin/env python3
# Dump the request table of a Marvell libmarvell-ril.so (STATIC, never executes it) next to Android 7 request names.
# Usage: python3 -I ril-table-dump.py <libmarvell-ril.so> <ril.h from LineageOS cm-14.1> <out.tsv>
# Layout found in the community-dump build (moderate confidence, re-verify on official firmware):
#   RIL_RadioFunctions {version, onRequest, onStateRequest, supports, onCancel, getVersion} found via RIL_Init's data;
#   onRequest indexes 12-byte entries {id, category, handler}; category 8 or no handler = answered with RIL_E_REQUEST_NOT_SUPPORTED.
import sys,re,struct
from elftools.elf.elffile import ELFFile
so,hdr,out=sys.argv[1:4]
names={}
for m in re.finditer(r'#define\s+RIL_REQUEST_(\w+)\s+(\d+)',open(hdr).read()): names[int(m.group(2))]=m.group(1)
e=ELFFile(open(so,'rb'))
def rd(a,n):
    for s in e.iter_segments():
        if s['p_type']=='PT_LOAD' and s['p_vaddr']<=a<s['p_vaddr']+s['p_filesz']:
            e.stream.seek(s['p_offset']+a-s['p_vaddr']); return e.stream.read(n)
BASE=0xa3698  # derived from onRequest's literal pool in the dump build; differs in other builds -> recompute by disassembly
rows=[]
for i in range(1,138):
    n=names.get(i,'?')
    if i<=123:
        idw,cat,h=struct.unpack('<3I',rd(BASE+12*i,12))
        ok = idw==i
        state='UNSUPPORTED(answers not-supported)' if (cat==8 or h==0) else 'HANDLER'
        rows.append((i,n,state if ok else 'TABLE-MISMATCH'))
    else:
        rows.append((i,n,'OUTSIDE-TABLE(not table data; unsafe to forward)'))
with open(out,'w') as f:
    f.write('id\tandroid7_name\tvendor_ril_state\n')
    for r in rows: f.write('%d\t%s\t%s\n'%r)
print(sum(1 for r in rows if r[2]=='HANDLER'),'handlers;',sum(1 for r in rows if r[2].startswith('UNSUPP')),'unsupported;',sum(1 for r in rows if r[2].startswith('OUTSIDE')),'outside')
