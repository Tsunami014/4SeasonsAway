import os.path
import math

types = {
    #        I  D  0xT (Type is 4 bits, or one hex value)
    'wall': (0, 1, 0x0)
}

def makeHex(fmt, *args):
    args = [int(i) for i in args]
    prevc = None
    numbits = 0
    tmp = ""
    for c in fmt.replace(" ", "")+" ":
        if c != prevc:
            if prevc is not None:
                if prevc == '0':
                    tmp += '0'*numbits
                elif prevc == '1':
                    tmp += '1'*numbits
                else:
                    a = args.pop(0)
                    binstr = "{0:b}".format(a).rjust(numbits, "0")
                    if len(binstr) > numbits:
                        raise ValueError(
                            f'Input {a} ({binstr}) is longer than the space avaliable ({numbits} bits)!'
                        )
                    tmp += binstr
            prevc = c
            numbits = 1
        else:
            numbits += 1
    o = hex(int(tmp, 2))[2:].upper()
    o = '0'*(math.floor(tmp.index('1')/4)) + o
    return ', '.join('$'+o[i*2]+o[i*2+1] for i in range(len(o)//2))

pth = os.path.abspath(__file__+'/../')+'/'
with open(pth+'tilemap.dat') as f:
    dat = f.readlines()

def handleLn(ln):
    ln = ln.strip(' \r\n').replace(' ', '').lower()
    scrc, ln = ln[0], ln[1:]
    scr = {'<': 0, '>': 1}[scrc]
    coords, typ = ln.split('-')
    x, y = (int(i) for i in coords.split(','))
    dat = 0
    hstr = 'I0SXXXXD TTTTYYYY'
    datstr = ' 1111DDDD'
    if ':' in typ:
        typ, dat = typ.split(':')
        dat = int(dat)
        d = types[typ]
        if d[1] == 0:
            raise ValueError(
                f'Object {typ} cannot have data, but has been provided some!'
            )
        if d[0] == 0:
            dat = x + dat
        else:
            dat = y + dat
        hstr += datstr
    else:
        d = types[typ]
        if d[1] == 1:
            dat = 0
            hstr += datstr
    return makeHex(hstr, d[0], scr, x, d[1], d[2], y, dat)

outdat = []
chr = None
tmp = []
for ln in dat:
    if ln == '\n' or ln[0] == '#':
        continue
    if chr != ln[0]:
        outdat.append(tmp)
        tmp = []
        chr = ln[0]
    tmp.append(handleLn(ln))
outdat.append(tmp)

prevTlmp = handleLn('> 0,0 - Wall: 1')  # This is so when starting the first item is never seen. TODO: Can we do something else instead?

out = '; NOTE: Auto generated with `tilemap.py`, will be written over next run of that file\nTilemap:\n' + \
    '  .db '+prevTlmp+'  ; Offscreen tile to ensure the code still works. This will never be visible.\n' + \
    '\n'.join('  .db ' + ',    '.join(i) for i in outdat[1:])

with open(pth+'tilemap.asm', 'w+') as f:
    f.write(out + '\n\n')

