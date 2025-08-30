@echo off
IF EXIST code.nes DEL code.nes
asm6.exe code.asm code.nes
