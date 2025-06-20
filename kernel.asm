BITS 16
ORG 0x1000

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x8000
    sti

    call beep_sound
    call clear_screen
    mov si, welcome_msg
    call print_string_green  ; Changed to green version
    call print_newline

main_loop:
    ; Print prompt "> "
    mov si, prompt_msg
    call print_string

    ; Read a line from keyboard into buffer
    mov di, input_buffer
    call read_line

    ; Parse command stored at input_buffer
    mov si, input_buffer
    call parse_command

    jmp main_loop


game_guess:
    pusha

    call clear_screen
    mov si, guess_intro_msg
    call print_string_newline

    ; Генерация случайного числа (0..99)
    mov ah, 0
    int 0x1A          ; таймер BIOS CX:DX
    mov ax, dx
    xor dx, dx
    mov cx, 100
    div cx            ; ax = случайное число 0..99
    mov [guess_number], al

.guess_loop:
    mov si, guess_prompt_msg
    call print_string
    mov di, input_buffer
    call read_line

    ; Конвертация введенного числа
    mov si, input_buffer
    call atoi
    mov bx, ax              ; guessed number

    mov al, [guess_number]  ; target number

    cmp bx, ax
    je .correct

    ja .too_big
    jb .too_small

.too_big:
    mov si, guess_too_big_msg
    call print_string_newline
    jmp .guess_loop

.too_small:
    mov si, guess_too_small_msg
    call print_string_newline
    jmp .guess_loop

.correct:
    mov si, guess_correct_msg
    call print_string_newline

    popa
    ret

guess_intro_msg db "Guess a number from 0 to 99", 0
guess_prompt_msg db "Your guess: ", 0
guess_too_big_msg db "Too big!", 0
guess_too_small_msg db "Too small!", 0
guess_correct_msg db "Correct! Congrats!", 0
guess_number db 0

; игра "подбрось монетку" - угади орёл (0) или решка (1)

game_coin:
    pusha
    call clear_screen
    mov si, coin_intro_msg
    call print_string_newline

    ; Генерация случайного числа (0 или 1)
    mov ah, 0
    int 0x1A
    mov al, dl
    and al, 1
    mov [coin_flip], al

    mov si, coin_prompt_msg
    call print_string
    mov di, input_buffer
    call read_line

    ; Конвертация пользователя (0 или 1)
    mov si, input_buffer
    call atoi
    cmp ax, 0
    je .check_guess
    cmp ax, 1
    je .check_guess

    mov si, coin_invalid_input_msg
    call print_string_newline
    jmp game_coin

.check_guess:
    cmp ax, [coin_flip]
    je .win
    mov si, coin_lose_msg
    call print_string_newline
    jmp game_coin

.win:
    mov si, coin_win_msg
    call print_string_newline

    popa
    ret

coin_intro_msg db "Coin toss! Guess 0 (heads) or 1 (tails)", 0
coin_prompt_msg db "Your guess (0/1): ", 0
coin_invalid_input_msg db "Invalid input. Try 0 or 1.", 0
coin_win_msg db "You won!", 0
coin_lose_msg db "Try again.", 0
coin_flip db 0

; Камень-ножницы-бумага
; Пользователь вводит 0 (камень), 1 (ножницы), 2 (бумага)
; Программа генерирует случайно выбор и сообщает победителя

game_rps:
    pusha
    call clear_screen
    mov si, rps_intro_msg
    call print_string_newline

    ; Генерация выбора компьютера (0..2)
    mov ah, 0
    int 0x1A
    mov al, dl
    xor dx, dx
    mov cx, 3
    div cx
    mov [rps_computer_choice], al

    mov si, rps_prompt_msg
    call print_string
    mov di, input_buffer
    call read_line

    ; Конвертация пользователя
    mov si, input_buffer
    call atoi
    cmp ax, 0
    jb .invalid_input
    cmp ax, 2
    ja .invalid_input

    mov [rps_player_choice], ax

    ; Сравнение и определение победителя
    mov al, [rps_player_choice]
    mov bl, [rps_computer_choice]

    cmp al, bl
    je .draw

    ; игрок выиграл при 0(камень)-1(ножницы), 1(ножницы)-2(бумага), 2(бумага)-0(камень)
    ; вычислим (player - computer + 3) % 3
    mov ah, 0
    mov dx, 3
    sub al, bl
    add al, 3
    xor ah, ah
    div dx
    mov al, ah           ; остаток в ah, нам нужно ((player - comp + 3) mod 3)
    cmp ah, 1
    je .player_win

    jmp .computer_win

.draw:
    mov si, rps_draw_msg
    call print_string_newline
    jmp .end_game

.player_win:
    mov si, rps_player_win_msg
    call print_string_newline
    jmp .end_game

.computer_win:
    mov si, rps_computer_win_msg
    call print_string_newline
    jmp .end_game

.invalid_input:
    mov si, rps_invalid_msg
    call print_string_newline
    jmp game_rps

.end_game:
    popa
    ret

rps_intro_msg db "Rock-Paper-Scissors: enter 0-rock,1-scissors,2-paper",0
rps_prompt_msg db "Your choice: ",0
rps_draw_msg db "Draw!",0
rps_player_win_msg db "You win!",0
rps_computer_win_msg db "You lose!",0
rps_invalid_msg db "Invalid input.",0
rps_player_choice db 0
rps_computer_choice db 0

; ------- Circle data ------- ;
center_x dw 0
center_y dw 0
radius dw 0
color db 0
x dw 0
y dw 0
decision dw 0
; --- New Commands Data --- ;
command_time db "time", 0
command_mem db "mem", 0
command_rand db "rand", 0

time_msg db "Current time: ",0
mem_msg db "Memory: ",0
rand_msg db "Random number: ",0
; -------- Commands --------- ;

; parse_command expects si = input buffer (null terminated)
; Command: either "echo " then text, or "clear"

print_rand:
    pusha
    mov si, rand_msg
    call print_string_newline
    mov ah, 0x00
    int 0x1A            ; Get system timer tick count low word in CX:DX (on AH=0)
    ; После вызова:
    ; CX:DX — количество тиков с запуска (1/18.2 сек)

    ; берем просто DL для простоты (8 бит рандом)
    mov al, dl
    call print_bcd_two_digits
    call print_newline
    popa
    ret

print_mem:
    pusha
    mov si, mem_msg
    call print_string_newline

    mov ah, 0x00
    int 0x12            ; Получить размер памяти в KB (EAX 0 не требуется в BIOS)

    ; AX = количество килобайт
    mov ax, ax          ; размер в килобайтах
    mov bx, 10
    mov si, mem_val_buffer + 5
    mov byte [si], 0
    ; Конвертация числа ax в строку
    mov cx, 0

    mov dx, 0
.mem_convert_loop:
    mov dx, 0
    div bx
    add dl, '0'
    dec si
    mov [si], dl
    inc cx
    test ax, ax
    jnz .mem_convert_loop

    mov si, mem_msg
    call print_string
    call print_char       ; space
    mov si, si           ; текущий si — начало числа
    call print_string_newline

    popa
    ret

mem_val_buffer times 6 db 0

print_time:
    pusha
    mov ah, 0x02       ; Get RTC time
    int 0x1A
    jc .error          ; если ошибка - вывести сообщение
    mov si, time_msg
    call print_string_newline

    ; CH - hours (BCD), CL - minutes (BCD), DH - seconds (BCD)
    mov al, ch
    call print_bcd_two_digits
    mov al, ':'
    call print_char
    mov al, cl
    call print_bcd_two_digits
    mov al, ':'
    call print_char
    mov al, dh
    call print_bcd_two_digits

    call print_newline
    jmp .done
.error:
    mov si, err_unknown
    call print_string_newline
.done:
    popa
    ret

print_bcd_two_digits: ; AL = BCD byte, prints two digits
    pusha
    mov ah, al
    shr ah, 4
    and ah, 0x0F
    add ah, '0'
    mov al, ah
    call print_char
    mov al, al       ; AL = original BCD
    and al, 0x0F
    add al, '0'
    call print_char
    popa
    ret

command_guess db "guess", 0
command_coin db "coin", 0
command_rps db "rps", 0

parse_command:
    push si

    mov cx, 5
    mov di, command_echo
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_echo

    pop si
        push si
    mov cx, 5
    mov di, command_guess
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_guess
    pop si

    push si
    mov cx, 4
    mov di, command_coin
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_coin
    pop si

    push si
    mov cx, 3
    mov di, command_rps
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_rps
    pop si
    push si

    mov cx, 5
    mov di, command_clear
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_clear

    pop si
    push si

    mov cx, 8
    mov di, command_shutdown
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_shutdown

    pop si
    push si

    mov cx, 4
    mov di, command_calc
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_calc

    pop si
    push si

    mov cx, 4
    mov di, command_help
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_help

    pop si
    push si

    mov cx, 5
    mov di, command_gtest
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_gtest

    pop si
    push si
    mov cx, 4
    mov di, command_time
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_time
    pop si
    push si
    mov cx, 3
    mov di, command_mem
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_mem
    pop si
    
    push si
    mov cx, 4
    mov di, command_rand
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_rand
    pop si
    push si
    mov cx, 3
    mov di, command_cls
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_cls
    pop si

    push si
    mov cx, 4
    mov di, command_date
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_date
    pop si

    push si
    mov cx, 4
    mov di, command_beep
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_beep
    pop si

    push si
    mov cx, 6
    mov di, command_uptime
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_uptime
    pop si

    push si
    mov cx, 4
    mov di, command_info
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_info
    pop si

    push si
    mov cx, 5
    mov di, command_wait
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_wait
    pop si

    push si
    mov cx, 6
    mov di, command_invert
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_invert
    pop si

    push si
    mov cx, 5
    mov di, command_fill
    mov si, input_buffer
    cld
    repe cmpsb
    je .is_fill
    pop si

    mov si, err_unknown
    call print_string_newline
    ret

.is_guess:
    pop si
    call game_guess
    ret

.is_coin:
    pop si
    call game_coin
    ret

.is_rps:
    pop si
    call game_rps
    ret

.is_mouse:
    pop si
    call mouse_mode
    ret
.is_beep:
    pop si
    call beep_sound
    ret
.is_wait:
    pop si
    add si, 5          ; пропустить "wait "
    call wait_seconds
    ret
.is_invert:
    pop si
    call invert_screen
    ret
.is_fill:
    pop si
    add si, 5          ; пропустить "fill "
    call fill_screen
    ret
.is_echo:
    pop si
    add si, 5
    call print_string_green_newline
    ret

.is_clear:
    pop si
    call clear_screen
    ret

.is_shutdown:
    pop si
    call shutdown
    ret
.is_time:
    pop si
    call print_time
    ret
.is_mem:
    pop si
    call print_mem
    ret
.is_rand:
    pop si
    call print_rand
    ret
.is_calc:
    pop si
    add si, 4        ; Skip past "calc "
    call calculate
    ret
.is_help:
    pop si
    mov si, help_msg
    call print_string_newline
    ret
.is_gtest:
    pop si
    call gtest
    ret
.is_cls:
    pop si
    call clear_screen
    mov byte [text_color], 3    ; вернуть белый цвет по умолчанию
    ret
.is_date:
    pop si
    call print_date
    ret
.is_uptime:
    pop si
    call print_uptime
    ret
.is_info:
    pop si
    mov si, info_msg
    call print_string_newline
    ret

beep_sound:
    pusha
    mov si, beep_msg
    call print_string_newline

    ; Включить звук на динамике (port 0x61)
    in al, 0x61
    or al, 3
    out 0x61, al

    ; Установить частоту по умолчанию на PIT (Например, 440Hz)
    mov bx, 0x1234      ; значение для ножки канала 2, тут можно пропустить
    mov ax, 0xB6        ; 10110110b - установка канала 2
    out 0x43, al

    ; Немного подождать (~100ms)
    mov cx, 0xFFFF
.wait_loop:
    loop .wait_loop

    ; Отключить звук
    in al, 0x61
    and al, 0xFC
    out 0x61, al

    popa
    ret


invert_screen:
    pusha
    mov si, invert_msg
    call print_string_newline

    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov cx, 320*200

.loop_invert:
    mov al, [es:di]
    xor al, 0xFF       ; инвертируем байт
    mov [es:di], al
    inc di
    loop .loop_invert

    popa
    ret

wait_seconds:
    pusha
    mov si, wait_msg
    call print_string_newline

    ; Конвертация аргумента (ASCII номер в AL)
    mov bl, [si]
    sub bl, '0'
    cmp bl, 9
    ja .end_wait        ; если не 0-9 - сразу выходим

    mov cx, 18          ; тиков за 1 секунду (~18.2)
    xor bh, bh    ; очистить BH
    mov bl, bl    ; здесь просто сохранить BL (текущее уже в BL)

    mul cx              ; ax = bl * 18 (примерно тики)

    ; Получить текущее значение тика BIOS'а (int 0x1A ah=0)
    mov ah, 0
    int 0x1A
    mov si, cx          ; стартовый tick (CX:DX в CX, DX)

.wait_loop:
    mov ah, 0
    int 0x1A            ; обновить счетчик тиков
    sub cx, si
    cmp cx, ax          ; проверяем прошло ли ax тиков
    jb .wait_loop

    mov si, wait_done_msg
    call print_string_newline

.end_wait:
    popa
    ret


fill_screen:
    pusha
    mov al, [si]
    sub al, '0'
    cmp al, 255
    ja .invalid_color

    mov si, fill_msg
    call print_string_newline

    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov cx, 320*200
    mov al, al        ; цвет из параметра

.loop_fill:
    mov [es:di], al
    inc di
    loop .loop_fill

    jmp .done

.invalid_color:
    mov si, color_invalid_msg
    call print_string_newline

.done:
    popa
    ret

mouse_mode:
    pusha

    ; Установить VGA mode 13h
    mov ax, 0x0013
    int 0x10

    ; Очистить экран белым (цвет 15)
    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov cx, 320*200
    mov al, 15
    rep stosb

    mov si, mouse_msg
    call print_string_newline

    ; Инициализация мыши (int 0x33)
    mov ax, 0x0000
    int 0x33
    cmp ax, 0
    je .mouse_not_found

    ; Покажем указатель мыши
    mov ax, 0x0001
    int 0x33

    ; Начальная позиция квадрата
    mov cx, 160      ; X
    mov dx, 100      ; Y

.run_loop:
    ; Получить состояние мыши и координаты
    mov ax, 3
    int 0x33

    ; AX = status, CX = x, DX = y
    ; Максимум 319x199

    mov si, cx
    cmp si, 4
    jb .skip_x_min
    cmp cx, 316
    ja .skip_x_max
    mov cx, cx
    jmp .set_x
.skip_x_min:
    mov cx, 4
.skip_x_max:
    mov cx, 316
.set_x:
    
    mov si, dx
    cmp si, 4
    jb .skip_y_min
    cmp dx, 196
    ja .skip_y_max
    mov dx, dx
    jmp .set_y
.skip_y_min:
    mov dx, 4
.skip_y_max:
    mov dx, 196
.set_y:

    ; Стереть старый квадрат: закрасить 4x4 по предыдущему координате белым
    mov ax, 0xA000
    mov es, ax
    mov di, prev_pos
    mov bx, [di]
    mov si, [di + 2]
    call clear_square

    ; Нарисовать квадрат 4x4 чёрного цвета по новым координатам (cx, dx)
    mov bx, cx
    mov si, dx
    call draw_square_black_4

    ; Сохранить текущие координаты как предыдущие
    mov [prev_pos], cx
    mov [prev_pos+2], dx

    ; Проверяем клавишу ESC для выхода
    mov ah, 0x01
    int 0x16
    jz .run_loop         ; нет, продолжаем
    mov ah, 0x00
    int 0x16
    cmp al, 0x1B         ; ESC?
    jne .run_loop

    ; Выход: вернуть текстовый режим 0x03
    mov ax, 0x0003
    int 0x10

    popa
    ret

.mouse_not_found:
    mov si, err_no_mouse
    call print_string_newline
    popa
    ret

err_no_mouse db "Mouse not detected.",0

prev_pos dw 0,0

clear_square:
    ; вход: BX=х, SI=Y
    mov cx, 4           ; 4 строки
.clear_row_loop:
    push cx
    mov di, 0
    mov cx, 4           ; 4 столбца
.clear_col_loop:
    mov ax, si
    mov bx, 320
    mul bx       ; ax = si * 320
    add ax, bx   ; ax + bx = адрес внутри линии
    add di, ax
    mov al, 15          ; белый цвет
    mov es:[di], al
    inc di
    loop .clear_col_loop

draw_square_black_4:
    ; вход: BX= х, SI=Y
    mov cx, 4           ; 4 строки
.draw_row_loop:
    push cx
    mov di, 0
    mov cx, 4           ; 4 столбца
.draw_col_loop:
    mov ax, si
    mov bx, 320
    mul bx             ; ax = si * 320
    add ax, bx
    add di, ax
    mov al, 0          ; черный цвет
    mov es:[di], al
    inc di
    loop .draw_col_loop

    pop cx
    inc si
    loop .draw_row_loop
    ret

color_ok_msg db "Text color changed.",0

print_uptime:
    pusha
    mov si, uptime_msg
    call print_string_newline

    mov ah, 0x00
    int 0x1A            ; системный таймер tick count в CX:DX
    ; Нас интересует CX:DX двойное слово тиков (~18.2 тика в сек)
    ; Для простоты покажем только CX*18.2 (1 минута примерно)
    ; Поскольку большой точности не нужно, покажем значение DX / 18 (сек)

    mov ax, dx          ; младшее слово тиков
    mov bx, 18          ; делитель
    xor dx, dx
    div bx              ; AX = секунда (просто округление)

    ; Конвертируем в строку
    mov si, uptime_buffer + 5
    mov byte [si], 0

    test ax, ax
    jnz .conv_digits
    dec si
    mov byte [si], '0'
    jmp .print_str

.conv_digits:
    mov di, 10
.loop_conv:
    dec si
    xor dx, dx
    div di
    add dl, '0'
    mov [si], dl
    test ax, ax
    jnz .loop_conv

.print_str:
    mov si, uptime_msg
    call print_string
    call print_char   ; пробел
    mov si, si       ; pointer to number string
    call print_string_newline

    popa
    ret

uptime_msg db "Uptime (approxim. seconds): ",0
uptime_buffer times 6 db 0

; ----- Graphics Test ----- ;
gtest:
    pusha           ; Save all registers

    ; Set video mode 13h (320x200, 256 colors)
    mov ax, 0x0013
    int 0x10

    ; Fill screen with white (color 15)
    mov ax, 0xA000  ; VGA memory segment
    mov es, ax
    xor di, di      ; Start at beginning of video memory
    mov cx, 320*200 ; Number of pixels
    mov al, 15      ; White color
    rep stosb       ; Fill screen

    ; Draw green circle (color 2) at (200,200) with radius 20
    mov cx, 50     ; X center
    mov dx, 50     ; Y center
    mov si, 20      ; Radius
    mov bl, 2       ; Green color
    call draw_circle

    popa            ; Restore all registers
    ret

; Circle drawing subroutine
; Input: CX = x center, DX = y center, SI = radius, BL = color
draw_circle:
    pusha

    mov [center_x], cx
    mov [center_y], dx
    mov [radius], si
    mov [color], bl

    ; Initialize variables
    mov word [x], si    ; x = radius
    mov word [y], 0     ; y = 0
    mov ax, 1
    sub ax, si
    sub ax, si
    mov [decision], ax  ; decision = 1 - 2*radius

.draw_loop:
    ; Plot 8 symmetric points
    mov cx, [center_x]
    mov dx, [center_y]
    add cx, [x]
    add dx, [y]
    call plot_pixel     ; (x + xc, y + yc)

    mov cx, [center_x]
    mov dx, [center_y]
    add cx, [x]
    sub dx, [y]
    call plot_pixel     ; (x + xc, -y + yc)

    mov cx, [center_x]
    mov dx, [center_y]
    sub cx, [x]
    add dx, [y]
    call plot_pixel     ; (-x + xc, y + yc)

    mov cx, [center_x]
    mov dx, [center_y]
    sub cx, [x]
    sub dx, [y]
    call plot_pixel     ; (-x + xc, -y + yc)

    mov cx, [center_x]
    mov dx, [center_y]
    add cx, [y]
    add dx, [x]
    call plot_pixel     ; (y + xc, x + yc)

    mov cx, [center_x]
    mov dx, [center_y]
    add cx, [y]
    sub dx, [x]
    call plot_pixel     ; (y + xc, -x + yc)

    mov cx, [center_x]
    mov dx, [center_y]
    sub cx, [y]
    add dx, [x]
    call plot_pixel     ; (-y + xc, x + yc)

    mov cx, [center_x]
    mov dx, [center_y]
    sub cx, [y]
    sub dx, [x]
    call plot_pixel     ; (-y + xc, -x + yc)

    ; Update y
    inc word [y]

    ; Update decision parameter
    mov ax, [decision]
    cmp ax, 0
    jg .decision_gt_0

    ; decision <= 0
    add ax, [y]
    add ax, [y]
    inc ax
    mov [decision], ax
    jmp .check_loop

.decision_gt_0:
    ; decision > 0
    dec word [x]
    mov ax, [decision]
    add ax, [y]
    add ax, [y]
    sub ax, [x]
    sub ax, [x]
    inc ax
    mov [decision], ax

.check_loop:
    ; Continue while x >= y
    mov ax, [x]
    cmp ax, [y]
    jge .draw_loop

    popa
    ret

; Plot pixel at (CX, DX) with color [color]
plot_pixel:
    pusha

    ; Check bounds (0 <= x < 320, 0 <= y < 200)
    cmp cx, 320
    jae .skip
    cmp dx, 200
    jae .skip

    ; Calculate address: 0xA000 + y*320 + x
    mov ax, dx
    mov bx, 320
    mul bx          ; ax = y*320
    add ax, cx      ; ax = y*320 + x
    mov di, ax
    mov al, [color]
    mov [es:di], al ; Write pixel

.skip:
    popa
    ret

; ----- Calculator function -----
calculate:
    pusha
    
    ; New line before first prompt
    call print_newline
    
    ; Prompt for first number
    mov si, prompt_num1
    call print_string
    mov di, num1_buffer
    call read_line
    call print_newline  ; New line after input
    
    ; Prompt for second number
    mov si, prompt_num2
    call print_string
    mov di, num2_buffer
    call read_line
    call print_newline  ; New line after input
    
    ; Prompt for operator
    mov si, prompt_operator
    call print_string
    mov di, operator_buffer
    call read_line
    call print_newline  ; New line after input
    
    ; Convert first number
    mov si, num1_buffer
    call atoi
    mov bx, ax
    
    ; Convert second number
    mov si, num2_buffer
    call atoi
    mov cx, ax
    
    ; Get operator
    mov al, [operator_buffer]
    
    ; Perform calculation
    cmp al, '+'
    je .do_addition
    cmp al, '-'
    je .do_subtraction
    
    ; Invalid operator
    mov si, invalid_operator_msg
    call print_string_newline
    jmp .done
    
.do_addition:
    add bx, cx
    jmp .print_result
    
.do_subtraction:
    sub bx, cx
    
.print_result:
    ; New line before result
    call print_newline
    
    ; Convert result to string
    mov si, result_buffer + 5
    mov byte [si], 0
    mov ax, bx
    
    ; Handle zero case
    test ax, ax
    jnz .convert_digits
    dec si
    mov byte [si], '0'
    jmp .print
    
.convert_digits:
    mov di, 10
.convert_loop:
    dec si
    xor dx, dx
    div di
    add dl, '0'
    mov [si], dl
    test ax, ax
    jnz .convert_loop
    
.print:
    mov si, result_msg
    call print_string
    mov si, result_buffer + 5
.find_start:
    dec si
    cmp byte [si], 0
    jne .find_start
    inc si
    call print_string_newline
    
    ; New line after result
    call print_newline
    
.done:
    popa
    ret

; ----- Helper function for newline -----
print_newline:
    pusha
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char
    popa
    ret

atoi:
    push bx
    push cx
    push dx
    xor ax, ax
    xor cx, cx
    xor bx, bx
    
.convert_loop:
    lodsb
    test al, al
    jz .done
    sub al, '0'
    cmp al, 9
    ja .invalid
    mov cx, 10
    mul cx
    add bx, ax
    jmp .convert_loop
    
.invalid:
    xor bx, bx
    
.done:
    mov ax, bx
    pop dx
    pop cx
    pop bx
    ret


; ----- Data for calculator -----
prompt_num1 db "Number 1 >> ", 0
prompt_num2 db "Number 2 >> ", 0
prompt_operator db "Operator >> ", 0
result_msg db "Result: ", 0
invalid_operator_msg db "Invalid operator. Use + or -", 0
num1_buffer times 6 db 0
num2_buffer times 6 db 0
operator_buffer times 2 db 0
result_buffer times 6 db 0

shutdown:
    ; Print message
    mov si, shutdown_msg
    call print_string

    ; Try ACPI power off - write 0 to port 0x604 (Power Management Control Register)
    mov dx, 0x604
    mov al, 0
    out dx, al

    ; Fallback: send APM shutdown via int 0x15
    mov ax, 0x5300
    mov bx, 0x0001
    int 0x15

    ; If above fails, halt CPU forever
.shutdown_halt:
    hlt
    jmp .shutdown_halt

command_shutdown db "shutdown", 0
shutdown_msg db "Shutting down...", 0x0D, 0x0A, 0
command_calc db "calc", 0
calc_error_msg db "Invalid calculation format. Use: calc X + Y or calc X - Y", 0


; -------- Utilities ---------

; read_line
; Reads keyboard input until Enter (CR 0x0D).
; Echoes characters, supports Backspace.
; Stores characters into [di], appends zero terminator.

read_line:
    push di
    mov cx, 0           ; length

.read_char:
    mov ah, 0x00
    int 0x16            ; BIOS keyboard read (blocking)
    cmp al, 0x0D        ; Enter key?
    je .done

    cmp al, 0x08        ; Backspace?
    jne .store_char

    ; Backspace handling
    cmp cx, 0
    je .read_char       ; nothing to erase
    dec cx
    dec di
    ; Move cursor back, print space, move cursor back again
    mov ah, 0x0E
    mov al, 0x08        ; backspace
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_char

.store_char:
    ; Store char
    mov [di], al
    inc di
    inc cx

    ; Echo char
    mov ah, 0x0E
    mov bl, 0x07
    mov bh, 0
    int 0x10

    jmp .read_char

.done:
    mov byte [di], 0    ; null terminate string

    pop di
    ret

; print_string
; si = pointer to null terminated string
print_string:
    pusha
.next_char:
    lodsb
    cmp al, 0
    je .done_str
    call print_char
    jmp .next_char
.done_str:
    popa
    ret

; print_string_newline
; Prints string then newline (CR+LF)
print_string_newline:
    ; Print newline before (CR+LF)
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char

    ; Print the string itself
    call print_string

    ; Print newline after (CR+LF)
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char
    ret

print_date:
    pusha
    mov ah, 0x04       ; Get RTC date
    int 0x1A
    jc .error
    mov si, date_msg
    call print_string_newline

    ; CH = Century (BCD), CL = Year (BCD)
    ; DH = Month (BCD), DL = Day (BCD)

    mov al, dh
    call print_bcd_two_digits
    call print_char
    mov al, '/'
    call print_char
    mov al, dl
    call print_bcd_two_digits
    call print_char
    mov al, '/'
    call print_char
    mov al, ch
    call print_bcd_two_digits
    mov al, cl
    call print_bcd_two_digits

    call print_newline
    jmp .done
.error:
    mov si, err_unknown
    call print_string_newline
.done:
    popa
    ret

date_msg db "Current date: ",0

print_string_green_newline:
    ; Print newline before (CR+LF)
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char

    ; Print the string itself
    call print_string_green

    ; Print newline after (CR+LF)
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char
    ret

print_string_green:
    pusha
    mov ah, 0x03       ; Get cursor position first (to maintain position)
    xor bh, bh         ; Page 0
    int 0x10
    ; DH = row, DL = column
    
.next_char:
    lodsb
    cmp al, 0
    je .done_str
    
    ; Write character with attribute
    mov ah, 0x09       ; BIOS write character and attribute
    mov bh, 0          ; Page 0
    mov bl, 0x02       ; Green on black (attribute)
    mov cx, 1          ; Write 1 character
    int 0x10
    
    ; Move cursor forward
    inc dl
    mov ah, 0x02       ; Set cursor position
    int 0x10
    
    jmp .next_char
    
.done_str:
    popa
    ret

; ===== NEW FUNCTION =====
; print_char_green: prints character in green
; AL = char to print
print_char_green:
    mov ah, 0x0E
    mov bl, 0x02  ; Green color
    mov bh, 0
    int 0x10
    ret

; Clear screen: scroll whole screen up 25 lines, moves cursor to 0,0
clear_screen:
    mov ah, 0x06    ; scroll up
    mov al, 0       ; lines to scroll (0=clear entire window)
    mov bh, 0x07    ; attribute white on black
    mov cx, 0       ; upper-left corner (row=0, col=0)
    mov dx, 0x184f  ; lower-right corner (row=24, col=79)
    int 0x10

    ; Set cursor position (0,0)
    mov ah, 0x02
    mov bh, 0x00
    mov dx, 0x0000
    int 0x10
    ret

; print_char
; AL = char to print, teletype mode
print_char:
    pusha
    mov ah, 0x0E       ; teletype output function
    mov bh, 0          ; video page number (usually 0)
    mov dl, al         ; сохранить символ

    mov al, [text_color]
    cmp al, 1
    je .green
    cmp al, 2
    je .red
    cmp al, 3
    je .white

    ; если цвет неизвестен — отдаем по умолчанию белый:
.white:
    mov bl, 7          ; белый
    jmp .print_char
.green:
    mov bl, 2          ; зеленый
    jmp .print_char
.red:
    mov bl, 4          ; красный

.print_char:
    mov al, dl         ; вернуть символ
    int 0x10

    popa
    ret


; ----- Data -----
welcome_msg db "CatOS v1.2",0

prompt_msg db "> ", 0

info_msg db "CatOS v1.2 by RedCatTeam", 0
command_color db "color ", 0    ; note: пробел важен для парсинга параметра
command_cls   db "cls", 0
command_date  db "date", 0
command_uptime db "uptime", 0
command_info  db "info", 0
text_color db 3       ; 1=green, 2=red, 3=white (default)
command_echo db "echo ", 0
command_clear db "clear", 0
command_help db "help", 0
command_gtest db "gtest",0
color_invalid_msg db "Invalid color code. Use 1-green, 2-red, 3-white",0

help_msg db "Commands: echo <TEXT>, clear, help, shutdown, calc, mem, rand, time, cls, date, uptime, info, guess, coin, rps",0

err_unknown db "Unknown command.", 0x0D, 0x0A, 0

input_buffer times 128 db 0
command_mouse db "mouse", 0
command_beep db "beep", 0
command_wait db "wait ", 0  ; c пробелом (для аргумента)
command_invert db "invert", 0
command_fill db "fill ", 0  ; c пробелом (для аргумента)

beep_msg db "Beep!",0
wait_msg db "Waiting... ",0
wait_done_msg db "Done waiting.",0
invert_msg db "Screen colors inverted.",0
fill_msg db "Screen filled.",0
mouse_msg db "Mouse mode active. Use mouse to move square. Press ESC to exit.",0