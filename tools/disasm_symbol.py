# Static disassembly helper used in Phase 1 (read-only; never executes the analysed binary).
# Usage: python3 -I disasm_symbol.py <elf-file> <exported-symbol> [max-instructions]
# Needs: pip install capstone pyelftools (in a virtualenv).
import sys, capstone
from elftools.elf.elffile import ELFFile
path, sym = sys.argv[1], sys.argv[2]
maxn = int(sys.argv[3]) if len(sys.argv) > 3 else 200
f = open(path,'rb'); e = ELFFile(f)
syms = {}
for secname in ('.dynsym','.symtab'):
    s = e.get_section_by_name(secname)
    if s:
        for x in s.iter_symbols():
            if x['st_value']: syms[x.name] = (x['st_value'], x['st_size'])
if sym not in syms: print('no sym', sym); sys.exit(1)
addr, size = syms[sym]
thumb = addr & 1; a = addr & ~1
if size == 0: size = 600
data = None
for seg in e.iter_segments():
    if seg['p_type']=='PT_LOAD' and seg['p_vaddr'] <= a < seg['p_vaddr']+seg['p_filesz']:
        off = a - seg['p_vaddr'] + seg['p_offset']; f.seek(off); data = f.read(size); break
md = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB if thumb else capstone.CS_MODE_ARM)
n=0
for i in md.disasm(data, a):
    print('%x: %s %s' % (i.address, i.mnemonic, i.op_str)); n+=1
    if n>=maxn: break
