set -e
rm ./code.nes || true
./asm6.exe ./code.asm ./code.nes
