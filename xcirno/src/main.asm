org 0x7C00
bits 16

%define ENDL 0x0A

start:
    jmp main

puts:
    ; Save caller registers
    push si
    push ax

.loop:
    ; Reads byte at DS:SI to AL then adds 1 to SI
    lodsb

    ; if 0x0 (NULL-terminator), go to done
    or al, al
    jz .done

    ; calls BIOS video service
    ; AH = 0x0E (print one char and move the cursor)
    ; where AL is the char
    ; BH = 0 is the page number
    mov ah, 0x0e
    mov bh, 0           
    int 0x10            ; interrupt
    
    jmp .loop

.done:
    ; Set back to caller original registers
    pop ax
    pop si
    ret

main:
    ; Initialize everything to 0
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Put sp behind boot location
    mov sp, 0x7C00

    ; Point SI to msg
    mov si, msg

    ; Call puts label using si as arg
    call puts

    hlt

.halt:
    jmp .halt

msg: db 'hello_world!', ENDL, 0

times 510-($-$$) db 0

dw 0AA55h 