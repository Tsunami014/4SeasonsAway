import os.path
import math

types = {
    #         I  D  0xT (Type is 4 bits, or one hex value)
    'grass': (0, 1, 0x0),
    'dirt':  (1, 0, 0x0)
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

lastX = None
def handleLn(ln):
    global lastX
    ln = ln.strip(' \r\n').replace(' ', '').lower()
    scrc, ln = ln[0], ln[1:]
    scr = {'<': 0, '>': 1}[scrc]
    coords, typ = ln.split('-')
    x, y = (int(i) for i in coords.split(','))
    dat = 0
    hstr = 'IOSXXXXD TTTTYYYY'
    datstr = ' 1111DDDD'
    width = 1
    if ':' in typ:
        typ, dat = typ.split(':')
        dat = int(dat)-1
        d = types[typ]
        if d[1] == 0:
            raise ValueError(
                f'Object {typ} cannot have data, but has been provided some!'
            )
        if d[0] == 0:
            width = dat
            dat = x + dat
            if dat >= 16:
                raise ValueError(
                    f'Input x {x} and width {width} combined ({dat}) is greater than 16!'
                )
        else:
            if dat+y >= 16:
                raise ValueError(
                    f'Input y {y} and height {dat} combined ({y+dat}) is greater than 16!'
                )
            dat = y + dat
        hstr += datstr
    else:
        d = types[typ]
        if d[1] == 1:
            dat = 0
            hstr += datstr
        # TODO: When there become structures, ensure the width for each one is set properly
    overshadowed = 0
    if lastX is None:
        lastX = x+width
    else:
        if x+width < lastX:
            overshadowed = 1
        else:
            lastX = x+width
    return makeHex(hstr, d[0], overshadowed, scr, x, d[1], d[2], y, dat)

outdat = []
chr = None
tmp = []
for ln in dat:
    if ln == '\n' or ln[0] == '#':
        continue
    if chr != ln[0]:
        outdat.append(tmp)
        tmp = []
        lastX = None
        chr = ln[0]
    tmp.append(ln)
outdat.append(tmp)

outdat = [sorted(i, key=lambda x: int(x[1:x.index(',')])) for i in outdat]
outdat = [[handleLn(j) for j in i] for i in outdat]

lastX = None
prevTlmp = handleLn('> 0,0 - Dirt')  # This is so when starting the first item is never seen. TODO: Can we do something else instead?

out = '; NOTE: Auto generated with `tilemap.py`, will be written over next run of that file\nTilemap:\n' + \
    '  .db '+prevTlmp+'  ; Offscreen tile to ensure the code still works. This will never be visible.\n' + \
    '\n'.join('  .db ' + ',    '.join(i) for i in outdat[1:])

with open(pth+'tilemap.asm', 'w+') as f:
    f.write(out + '\n\n')

