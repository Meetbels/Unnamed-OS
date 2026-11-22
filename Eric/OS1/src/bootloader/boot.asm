org 0x7C00 
bits 16

%define ENDL 0x0D, 0X0A


;
; FAT12 header
; 
jmp short start 
nop

bdb_oem: db 'MSWIN4.1'
bdb_bytes_per_sector: dw 512
bdb_sectors_per_cluster: db 1
bdb_reserved_sector: dw 1
bdb_fat_count: db 2
bdb_dir_entires_count: dw 0E0h
bdb_total_sectors: dw 2880
bdb_media_descriptor_type: db 0F0h
bdb_sectors_per_fat: dw 9
bdb_sectors_per_track: dw 18
bdb_heads: dw 2
bdb_hidden_sectors: dd 0
bdb_large_sector_count: dd 0

; Extended boot record
ebr_drive_number: db 0
db 0
ebr_signature: db 29h
ebr_volume_id: db 0, 0, 0, 0
ebr_volume_label: db 'NANOBYTE OS' ; 11 bytes, padded with spaces
ebr_system_id: db 'FAT12   ' ; 8 bytes

start:
    jmp main

;
; Prints a string to the screen.
; Params:
;   - ds:si points to string
puts:
    push si
    push ax

.loop:
    lodsb
    or al, al
    jz .done

    mov ah, 0x0e
    mov bh, 0
    int 0x10
    jmp .loop

.done:
    pop ax
    pop si
    ret

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h                     ;wait for keypress
    jmp 0FFFFh:0                ;jump to to beginning of BIOS, should reboot

.halt:
    cli                         ;disable interrupts so we cant get cpu out of halt state
    hlt

;
; Converts LBA address to CHS address
; Params:
;   - ax: LBA address
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
;

lba_to_chs:
    push ax
    push dx

    xor dx, dx
    div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                        ; dx = LBA % SectorsPerTrack

    inc dx
    mov cx, dx

    xor dx, dx
    div word [bdb_heads]

    mov dh, dl
    mov ch, al
    shl ah, 6
    or cl, ah

    pop ax
    mov dl, al
    pop ax
    ret


;
; Reads sectors from a disk
; Parameters:
; - ax: LBA address
; - cl: number of sectors to read (up to 128)
; - dl: drive number
; - es:bx: memory address where to store read data
;
disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx
    call lba_to_chs
    pop ax
    

    mov ah, 02h
    mov di, 3

.retry:
    pusha
    stc         ;set carry flag, some BIOSes don't set it
    int 13h
    jnc .done

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    jmp floppy_error

.done:
    popa
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret


;
; resets disk controller
; Params:
;   dl: drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret


main:
    ;setup data segments
    mov ax, 0
    mov ds, ax
    mov es, ax

    ;setup stack
    mov ss, ax
    mov sp, 0x7C00

    ;read something from floppy disk
    ;BIOS should set DL to drive number
    mov [ebr_drive_number], dl

    mov ax, 1           ;LBA=1, second sector from disk
    mov cl, 1           ;1 sector to read
    mov bx, 0x7E00      ;data should be after the bootloader
    call disk_read

    mov si, msg_hello
    call puts

    cli ;disable interrupts
    hlt

.halt:
    jmp .halt


msg_read_failed: db 'Read from disk failed!', ENDL, 0
msg_hello: db 'Hello World!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h

