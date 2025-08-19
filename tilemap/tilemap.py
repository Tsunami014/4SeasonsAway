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
    return ['$'+o[i*2]+o[i*2+1] for i in range(len(o)//2)]

pth = os.path.abspath(__file__+'/../')+'/'
with open(pth+'tilemap.dat') as f:
    dat = f.readlines()

def handleLn(ln):
    ln = ln.strip(' \r\n').replace(' ', '').lower()
    scrc, ln = ln[0], ln[1:]
    scr = {'<': 0, '>': 1}[scrc]
    coords, typ = ln.split('-')
    dat = 0
    hstr = 'I0SXXXXD TTTTYYYY'
    datstr = ' 1111DDDD'
    if ':' in typ:
        typ, dat = typ.split(':')
        d = types[typ]
        if d[1] == 0:
            raise ValueError(
                f'Object {typ} cannot have data, but has been provided some!'
            )
        hstr += datstr
    else:
        d = types[typ]
        if d[1] == 1:
            dat = 0
            hstr += datstr
    x, y = coords.split(',')
    return makeHex(hstr, d[0], scr, x, d[1], d[2], y, dat)

outdat = [
    handleLn(ln)
    for ln in dat if ln != '' and ln[0] != '#'
]

out = 'Tilemap:\n' + \
    '\n'.join('  .db ' + \
        ',    '.join(
            ', '.join(outdat[i*5+j])
        for j in range(min(len(outdat)-i*5, 5)))
    for i in range(math.ceil(len(outdat)/5)))

with open(pth+'tilemap.asm', 'w+') as f:
    f.write(out)

