@echo off
del bootloader.bin
del kernel.bin
del os.bin
nasm -f bin bootloader.asm -o bootloader.bin
nasm -f bin kernel.asm -o kernel.bin
type bootloader.bin kernel.bin > os.bin
qemu-system-i386 -drive format=raw,file=os.bin