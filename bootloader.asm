BITS 16
ORG 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    ; Save boot drive
    mov [boot_drive], dl

    ; Print loading message
    mov si, loading_msg
    call print_string

    ; Reset disk system
    mov ah, 0x00
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; Load kernel - try reading sectors one by one
    mov bx, 0x1000      ; Destination
    mov cx, 0x0002      ; Cylinder 0, Sector 2
    mov dh, 0           ; Head 0

.load_sectors:
    mov ah, 0x02        ; Read sectors
    mov al, 1           ; Read 1 sector at a time
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; Move to next sector
    add bx, 512         ; Next memory location
    inc cl              ; Next sector
    cmp cl, 8          ; Read sectors 2-8 (7 sectors total)
    jbe .load_sectors

    ; Jump to kernel
    jmp 0x0000:0x1000

disk_error:
    mov si, disk_err_msg
    call print_string
    hlt
    jmp $

print_char:
    mov ah, 0x0E
    mov bh, 0
    mov bl, 0x07
    int 0x10
    ret

print_string:
    pusha
.next_char:
    lodsb
    test al, al
    jz .done
    call print_char
    jmp .next_char
.done:
    popa
    ret

loading_msg db "Loading CatOS...", 0x0D, 0x0A, 0
disk_err_msg db "Disk error! Press any key to reboot", 0x0D, 0x0A, 0
boot_drive db 0

times 510-($-$$) db 0
dw 0xAA55