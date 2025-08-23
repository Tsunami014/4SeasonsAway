# The original tilemap data format (`tilemap.dat`)
Each line is a new object.

Any blank line or line starting with `#` will be ignored.

The format for the object lines are like so:
```
<scr><x>, <y> - <name><dat>
e.g.

< 10, 20 - Wall
> 15, 2 - Wall
```
TODO: Better examples when more objects are added

Where:
- `<name>` is the name of the object. [See below list](#objects).
- `<x>` and `<y>` are the x and y coordinates of the object. X ranges from 0-32, Y from 0-30.
- `<scr>`; Either `<` or `>` representing the screen. `<` is screen 0 and `>` is screen 1. They don't reverse, so if you had < then > then < it would cover 3 screens; screen 0, then 1, then 2 (but screen 2 would override screen 0).
- `<dat>`; extra data per object, again specified in [below object list](#objects). If included, must have `:` preceeding it. (See examples)

Case is insensitive, and all spaces will be removed so do whatever you like.

# The converted tilemap data format (`tilemap.asm`)
This file contains a label `Tilemap:` which is required in other code. This label defines where the start of the tilemap data is.

All tilemap data is stored in `.db` instructions.

Each `.db` holds multiple objects where each is separated by many spaces so it's quite obvious.

Each object will look like one of these:
```
when   0
IOSXXXXD TTTTYYYY
when   1
IOSXXXXD TTTTYYYY 1111????
```
Where:
- `X` = X position
- `Y` = Y position
- `S` = Screen number. If this value differs from the object before it it is determined to be on a new screen.
- `D/I` = object type info
- `O` = Overshadowed; whether this object's end X position is less than the previous object's. This means that when the previous object is offscreen, this one should be too.
- `T` = object type
- `?` = object data

## Reasoning
- The X and Y values are 4 bits as the screen is 32x30 tiles, but each block is a 2x2 tile so it ends out being 16x15, enough for 4 bits
- The reason it's `SXXXX0` is the next column value is `SXXXXX`, but as explained before the tiles are 2x2. This means that the lowest bit is not used (it's ANDed out anyway).
- The Y is before the T so it can quickly check whether to run or not, but have to roll over for the T when it does. This is faster than rolling over the Y every single tile.
- D is at the start so I can go 2 + (byte1 AND 00000001) to get either 2 or 3 depending on whether it has data bits or not - the correct number!
- I is at the end as I can do `BPL` or `BMI` instead of an `AND` then `BNE`
- The width and height are x + width and y + height so I can just do screen pos < value instead of screen pos < value + initial pos
- The data starts with `1111` as this means the code knows if that byte is a data byte or not. This means no object can have a type of `1111`, but that's OK
- The overshadowed flag is because I had spare space and didn't want to calculate it for each object every time

# Objects
The object has 4 bits for the type, specifying what object it is, but also a D and I bit. The D specifies if there is any data attached, and combined tells how the object is rendered.

If I=0, the object only is one block in width.
## Special object types
(`?` = unused bit)

| `D``I` |    Data    | What it is |
|--------|------------|------------|
| `0``1` |  no data   | A single block. |
| `0``0` |  no data   | A structure (collection of multiple blocks). |
| `1``0` | `1111WWWW` | A horizontal line of blocks. `W` is x + the width. |
| `1``1` | `1111HHHH` | A vertical line of blocks. `H` is y + the height. |

## Object table
| Obj name | I | D | hex type |
|----------|---|---|----------|
| Wall     | 0 | 1 |    0     |

