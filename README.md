# 4 Seasons Away
A platformer for the NES about finding a friend.

Built using the ASM6 compiler.

## "I just want to run the code"
1. Run `build.bash` or `./buildLinux` (double click in file explorer or run in terminal, I don't care)
2. Ensure it created a file `code.nes`
3. Run an NES emulator such as the provided `nester.exe` and select Open ROM and select the `code.nes`
4. Play!

## Editing/Running
**To edit the code**: Edit the `code.asm` file.

**To edit the tileset**: A program such as yychr is required. Use it to edit `tiles.chr`.

**To build**: Run `build.bash` or `./buildLinux` depending on your OS.

**To run**: Run `code.nes` using an NES emulator (after building). `nester.exe` is provided, but for debugging another such as [FCEUX](https://fceux.com/web/download.html) is recommended.

## Opcodes
A very nice list of opcodes for the NES' hardware can be found [here](https://wiki.preterhuman.net/NES_Programming_Guide), and the instructions for the specific ASM6 assembler can be found [here](./Instructs.txt).

