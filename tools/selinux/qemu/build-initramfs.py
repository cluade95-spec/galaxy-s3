#!/usr/bin/env python3
# Write a minimal "newc" cpio initramfs: /init, /sepolicy, /dev/console and empty mount points. No external tools needed.
# Usage: build-initramfs.py <init binary> <compiled policy> <out.cpio>
import sys,os
init,pol,out=sys.argv[1:4]
ino=[0x1000]
def ent(name,mode,data=b'',rdev=(0,0)):
    ino[0]+=1
    nm=name.encode()+b'\0'
    fields=(ino[0],mode,0,0,1,0,len(data),0,0,rdev[0],rdev[1],len(nm),0)
    b=('070701'+''.join('%08x'%v for v in fields)).encode()+nm
    b+=b'\0'*((4-len(b)%4)%4)
    b+=data+b'\0'*((4-len(data)%4)%4)
    return b
blob=b''
for d in ('dev','proc','sys'): blob+=ent(d,0o040755)
blob+=ent('dev/console',0o020600,rdev=(5,1))
blob+=ent('init',0o100755,open(init,'rb').read())
blob+=ent('sepolicy',0o100644,open(pol,'rb').read())
blob+=ent('TRAILER!!!',0)
open(out,'wb').write(blob)
print(out,len(blob),'bytes')
