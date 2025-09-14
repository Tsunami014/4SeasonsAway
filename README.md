# 4 Seasons Away
![Banner](./Banner.png)
A platformer for the NES about finding a friend.

This project is written in assembly for the NES. Yes, THE 40 year old NES. The console the original Mario bros was made on. The NES stopped being supported in 1995. Yes, I did have to write it in assembly. The assembly code specific to the NES' specific microcontroller that is probably not being made anymore.

This project was going to be a side-scrolling platformer. Turns out this stuff is hard. So it devolved to not having enemies, not having the player, and now not being able to go left. So now, it's just the platforms. Close enough, right? But I reckon getting anything to work on this thing is a grand feat in itself.

This project was somewhat made with AI. I wrote all of the code myself (that's why it works and looks readable), but I used AI for debugging. But an annoyingly large amount of the time (I'd put it at 98%), debugging myself was either faster or the only way to do it as AI just could not figure out the problem, however simple. And you've never seen debugging be hard until you've debugged assembly. AI can be helpful *occasionally*, but it can also be a big waste of time stating things that are not the problem or are not the solution (and I only know that because I wrote my own code). So I probably wasted more time using it than I would've than if I just did it all myself. Such is life.

# Please note
Because the game is incomplete, please note:
1. The friend does not exist yet. (But the house does!)
2. You cannot go left. Implementing the 2 functions required would take me too much time. But the code is built around the idea that one day if I implement it I can easily go left without modifying too much other stuff.
3. There are no scrolling stoppers, so the screen will scroll past where it should be able to if this game were finished. This is because there is no player to go through doors with anyway!
4. There is a visual glitch when transitioning between areas. This is because there is no level transitions. If there were, it would not occur.
5. There is no player or enemies. This game is incomplete as mentioned before.
6. At the end there is grey. If you go far enough, it will start reading the wrong values and cause glitched tiles to appear.

Built using the ASM6 compiler.

# Demo video
Please note in this video the game is not lagging or stuttering, that is me letting go of the right button so you can see it (if you don't believe me go do it yourself)

https://github.com/user-attachments/assets/e6633d12-9f4f-47b6-8527-3d61760c32d1

# "I just want to run the code"
## Easy way
1. Go to the [releases](https://github.com/Tsunami014/4SeasonsAway/releases)
2. Download the demo exe of the latest release and play! (Tested; wine works on it too)
    - The exe runs a precompiled version of the code with the `nester.exe` emulator. There is a 'double size' option in the 'Options' menu if you want :)
## Build the source code way
1. Download repo however
1. Run `build.bat` or `./buildLinux` (double click in file explorer or run in terminal, I don't care)
2. Ensure it created a file `code.nes`
3. Run said file in an NES emulator (such as the provided `nester.exe`)
    - In the provided nester emulator, select Open ROM and select the `code.nes` to run it. Again, there is the double size option if required
4. Play!

## Editing/Running
**To edit the code**: Edit the `.asm` files in the main folder. `code.asm` is the main file which includes other files in the folder.

**To edit the tileset**: A program such as yychr is required. Use it to edit `tiles.chr`.

**To build**: Run `build.bat` or `./buildLinux` depending on your OS.

**To run**: Run `code.nes` using an NES emulator (after building). `nester.exe` is provided, but for debugging another such as [FCEUX](https://fceux.com/web/download.html) is recommended.

### Tilemaps
You will notice a tilemap folder. In it contains;
- `tilemap.asm`; the generated asm file. This contains the data the game will use when compiling, and is auto generated.
- `tilemap.dat`; the original tilemap data in a form that is easy to see and use
- `tilemap.py`; the conversion script to convert the `tilemap.dat` into the `tilemap.asm`
- `tilemap.md`; helpful documentation on how the original and converted forms of the tilemap data look like

To edit the tilemap;
1. Read up in `tilemap.md` about the format required, *only need to know about the `.dat` format though*
2. Write tilemap data in `tilemap.dat`
3. Convert it by running the `tilemap.py`. This will work without any external libraries.
4. Compile and run the main code (see above)

### Opcodes
A very nice list of opcodes for the NES' hardware can be found [here](https://wiki.preterhuman.net/NES_Programming_Guide), and the instructions for the specific ASM6 assembler can be found [here](./Instructs.txt).

