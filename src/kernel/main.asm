;boot

%define ENDL 0x0D, 0x0A

bits 16
org 0x7c00

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
