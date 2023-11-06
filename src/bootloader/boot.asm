;
; bootloader
;
%define ENDL 0x0D, 0x0A

bits 16
org 0x7c00

;
; fat12 header
;
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'         ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880               ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h               ; F0 = 3.5 floppy
bdb_sectors_per_fat:        dw 9                  ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

;
; extended boot record
;
ebr_drive_number:           db 0 ; 0x00 floppy, 0x80 hdd
                            db 0 ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 10h, 20h, 30h, 40h ; serial number
ebr_volume_label:           db 'miika os   '      ; 11 bytes
ebr_system_id:              db 'FAT12   '         ; 8 bytes

;
; code
;
start:
  jmp main

puts:
  ; save registers we will modify
  push si
  push ax


.loop:
  lodsb         ; loads next character in al
  or al, al     ; check if al is 0
  jz .done      ; if so, we are done

  mov ah, 0x0e  ; call bios interrupt
  int 0x10      ; to print character in al

  jmp .loop     ; otherwise, loop


.done:
  ; restore registers
  pop ax      ; ax is now 0
  pop si      ; si is now the address of the string
  ret


main:
  ; setup data segments
  mov ax, 0
  mov ds, ax
  mov es, ax
  
  ; setup stack
  mov ss, ax      ; stack segment is data segment
  mov sp, 0x7c00  ; stack grows down from 0x7c00

  ; read from floppy
  ; bios should set dl to drive number
  mov [ebr_drive_number], dl

  mov ax, 1 ; lba=1, second sector from disk
  mov cl, 1 ; 1 sector to read
  mov bx, 0x7E00
  call disk_read


  ; print message
  mov si, msg_hello
  call puts

  cli ; disable interrupt, cpu can't get out of halted state
  hlt

;
; error handlers
;
floppy_error:
  mov si, msg_read_failed
  call puts
  jmp wait_key_and_reboot

wait_key_and_reboot:
  mov ah, 0
  int 16h
  jmp 0FFFFh:0
  hlt

.halt:
  cli ; disable interrupts 
  hlt 

;
; disk routines
;

; convert lba address to chs address
; param:
; - ax : lba address
; return:
; - cx [bits 0-5]: sector number
; - cx [bits 6-15]: cylinder
; - dh: head

lba_to_chs:
  push ax
  push dx

  xor dx, dx ; dx = 0
  div word [bdb_sectors_per_track] ; ax = lba / bdb_sectors_per_track
  ; dx = lba % bdb_sectors_per_track

  inc dx ; dx = (lba % bdb_sectors_per_track + 1) = sector
  mov cx, dx ; cx = sector

  xor dx, dx ; dx = 0
  div word [bdb_heads] ; ax = (lba / bdb_sectors_per_track) / heads = cylinder
  ; dx = (lba / bdb_sectors_per_track) % heads = head
  mov dh, dl ; dh = head
  mov ch, al ; ch = cylinder (lower 8 bits)
  shl ah, 6 
  or cl, ah ; put upper 2 bits of cylinder to cl

  pop ax
  mov dl, al ; restore dl
  pop ax
  ret

; read sectors from a disk
; param
; - ax: lba address
; - cl: number of sectors to read (up to 128)
; - dl: drive number
; - ex:bx: memory address where to store read data
disk_read:
  push ax ; save registers we will modify
  push bx 
  push cx 
  push dx 
  push di

  push cx ; temporarily save cl (number of sectors to read)
  call lba_to_chs ; compute chs
  pop ax ; al = number of sectors to read
  
  mov ah, 02h
  mov di, 3 ; retry count

.retry:
  pusha ; save all registers, we dont know what the bios modifies
  stc ; set carry flag, some BIOSes dont set it
  
  int 13h ; carry flag cleared = success
  jnc .done ; jump if carry not set

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

  pop di ; restore modified registers
  pop dx 
  pop cx 
  pop bx 
  pop ax
  ret

; reset disk controller
; param:
; dl: drive number
disk_reset:
  pusha
  mov ah, 0
  stc
  int 13h
  jc floppy_error
  popa
  ret

msg_hello:
  db 'Hello, World!', ENDL, 0
msg_read_failed:
  db 'Read failed!', ENDL, 0

times 510-($-$$) db 0 ; pad with zeros until 510 bytes
dw 0AA55h             ; boot signature
