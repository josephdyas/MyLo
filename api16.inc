;##############################################################################
;===============================================================================
; use the INT 0x15, eax= 0xE820 BIOS function to get a memory map
; inputs: es:di -> destination buffer for 24 byte entries
; outputs: bp = entry count, trashes all registers except esi
mmap_ent dw ?
do_e820:
        xor ebx, ebx            ; ebx must be 0 to start
        xor bp, bp              ; keep an entry count in bp
        mov edx, 0x0534D4150    ; Place "SMAP" into edx
        mov eax, 0xe820
        mov [es:di + 20], dword 1 ; force a valid ACPI 3.X entry
        mov ecx, 24             ; ask for 24 bytes
        int 0x15
        jc short .failed        ; carry set on first call means "unsupported function"
        mov edx, 0x0534D4150    ; Some BIOSes apparently trash this register?
        cmp eax, edx            ; on success, eax must have been reset to "SMAP"
        jne short .failed
        test ebx, ebx           ; ebx = 0 implies list is only 1 entry long (worthless)
        je short .failed
        jmp short .jmpin
.e820lp:
        mov eax, 0xe820         ; eax, ecx get trashed on every int 0x15 call
        mov [es:di + 20], dword 1       ; force a valid ACPI 3.X entry
        mov ecx, 24             ; ask for 24 bytes again
        int 0x15
        jc short .e820f         ; carry set means "end of list already reached"
        mov edx, 0x0534D4150    ; repair potentially trashed register
.jmpin:
        jcxz .skipent           ; skip any 0 length entries
        cmp cl, 20              ; got a 24 byte ACPI 3.X response?
        jbe short .notext
        test byte [es:di + 20], 1 ; if so: is the "ignore this data" bit clear?
        je short .skipent
.notext:
        mov ecx, [es:di + 8]    ; get lower uint32_t of memory region length
        or ecx, [es:di + 12]    ; "or" it with upper uint32_t to test for zero
        jz .skipent             ; if length uint64_t is 0, skip entry
        inc bp                  ; got a good entry: ++count, move to next storage spot
        add di, 24
.skipent:
        test ebx, ebx           ; if ebx resets to 0, list is complete
        jne short .e820lp
.e820f:
        mov [mmap_ent], bp      ; store the entry count
        clc                     ; there is "jc" on end of list to this point, so the carry must be cleared
        ret
.failed:
        stc                     ; "function unsupported" error exit
        ret
;===============================================================================
getkey:
        add   bx,0x0101
        xor   eax,eax

  gk1:

        push  ebx ecx edx esi edi ebp
        mov   ax ,0x0000     ; read key, with wait
        int   0x16
   ; shr   ax , 8      ; scancode
        pop   ebp edi esi edx ecx ebx

        push cs
        pop ds
        mov cx,1
        call printkey

        jmp getkey
;===============================================================================
; get a null terminate string and passe to print routine to put on video
puts:
        push ds
        push cs
        pop ds
        cld
        mov cx,0
repeatstringnull:
        cmp byte [si],0
        je printstring
        inc cx
        inc si
        jmp repeatstringnull
printstring:
       sub si,cx
       cmp cx,0
       jz sai_printstring
prints:
print_repeat_printstring:
        lodsb
printkey:

        cmp [cursorpsc],80
        je next_line_printstring
        cmp cx,0
        jz sai_printstring
        cmp al,0dh
        je new_line_printstring

        push cx
        push ax
;----------------------------
        mov ax, 160
        mov bl, [cursorpsr]
        mul bl
        mov di, ax
        movzx ax, byte [cursorpsc]
        shl ax, 1
        add di, ax
        mov ax, 0xb800
        mov es, ax
        pop ax
        mov ah, 0x07
        mov word [es:di], ax
        inc byte [cursorpsc]
;----------------------------
        pop cx
        dec cx
        jmp print_repeat_printstring

next_line_printstring:

        mov [cursorpsc],0
        inc byte [cursorpsr]
        jmp print_repeat_printstring

new_line_printstring:

        mov [cursorpsc],0
        inc byte [cursorpsr]
        dec cx
        jmp print_repeat_printstring
sai_printstring:
        pop ds
        ret
;===============================================================================
printlogo:
        mov si, systemlogo
        mov bx,1                        ; line number to start print
        mov dl,0x03
        mov cx,LOGO_SIZE                ; number of characteres to print
        call setchar
        ret
;===============================================================================
configvideo:

        mov ah,00h           ;video mode function
        mov al,03h           ;80x25 mode
        int 10h              ;video interruption
; set active display page 0
        mov al, 00h
        mov ah, 05h
        int 10h
;Hidden the cursor because we do not use bios to print strings
        mov ah,01h
        mov ch,37h
        int 10h

        mov [cursorpsr], 2
        mov [cursorpsc], 0
;   set the background color
        call set_backgound
        ret
;===============================================================================
;##############################################################################
;print routine
set_backgound:

        push es
        cld
        mov ax,0xb800
        mov es,ax
        mov di,0
        mov cx,2001
        mov ax,0x0700
  lp_clear:
        dec cx
        cmp cx,0
        jz sai_clear
        stosw
        jmp lp_clear
    sai_clear:
        pop es
         ret
;===============================================================================
;==============================================================================
; procedure to print a set of characteres on console - 80x25 bios mode
; cx = number of bytes
; si = address of the string to be printed
; dl = character attribute
; bx = line where the print start
setchar:
        push es
        push ds
        push cs
        pop  ds
        cld
        mov ax,0b800h
        mov es,ax
        mov di,0
        dec bx
        imul bx,0xa0
        add di,bx
  lp:
        ds lodsb                  ;lodsb load then byte from ds:si to ax register
        cmp cx,00h
        jz sai
        dec cx
        mov ah,dl;[charcolorback]
        mov word[es:di],ax
        add di,02h
        jmp lp
    sai:
        pop ds
        pop es
        ret

;=============================================================================
;##############################################################################
; si = address of the buffer to receiv string
; ax = word to convert
ConvertHexWord_16:

        push es
        push cs
        pop es
        push bx
        push cx

        mov di,si
        add di,3
        mov bx,ax
        mov cx,4
        cld               ; decrement di
        jmp  repeat_converthex_16

ConvertHexByte_16:

        push es
        push cs
        pop es
        push bx
        push cx

        mov di,si
        add di,1
        mov bx,ax
        mov cx,2
        cld               ; decrement edi

repeat_converthex_16:
        cmp cx,0
        jz  exit_converthex_16
        mov si,hextable_16
        and ax,0fh
        add si,ax
        mov al, byte [es:si]
        ds stosb
        shr bx,4
        mov ax,bx
        dec cx
        sub di,2
        jmp repeat_converthex_16

exit_converthex_16:
        pop cx
        pop bx
        pop es
        ret

hextable_16 db '0123456789abcdef'

;##############################################################################
; print a set of data on screen
printdata:
          push cs
          pop es
print_repeat_printstring_printdata:

        ds lodsb
        cmp [es:cursorpsc],80
        je next_line_printstring_printdata
        cmp [es:cursorpsr],20
        je next_pageprintstring_printdata
        cmp cx,0
        je sai_printstring_printdata

        push cx

        mov ah,0ah
        mov bx,0
        mov cx,1
        int 10h

        inc [es:cursorpsc]
        mov dl,[es:cursorpsc]
        mov dh,[es:cursorpsr]

        mov ah,02h
        mov bx,0
        int 10h
        pop cx
        dec cx
        jmp print_repeat_printstring_printdata

next_line_printstring_printdata:

        mov [es:cursorpsc],0
        inc [es:cursorpsr]

        jmp print_repeat_printstring_printdata

next_pageprintstring_printdata:

sai_printstring_printdata:
        ret

;===============================================================================