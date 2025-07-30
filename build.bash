set -e
rm ./code.nes ./code.fns || true
./NESASM3.exe ./code.asm
