;
; bootloader
;
%define ENDL 0x0D, 0x0A

bits 16
org 0x7c00


; fat12 header
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


; extended boot record
ebr_drive_number:           db 0 ; 0x00 floppy, 0x80 hdd
                            db 0 ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 10h, 20h, 30h, 40h ; serial number
ebr_volume_label:           db 'miika os   '      ; 11 bytes
ebr_system_id:              db 'FAT12   '         ; 8 bytes


; code

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

  ; print message
  mov si, msg_hello
  call puts

  hlt

.halt:
  jmp .halt


msg_hello:
  db 'Hello, World!', ENDL, 0

times 510-($-$$) db 0 ; pad with zeros until 510 bytes
dw 0AA55h             ; boot signature
