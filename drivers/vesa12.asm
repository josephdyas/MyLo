;##############################################################################
;
;                              VESA12.INC
;
;                 Vesa 1.2 functions for MYOS -  by JosephDias - 02.2019
;##############################################################################

; FUNCTIONS

; ClearScreen80x25
; PutChar80x25
; Putstty80x25
; Scrollup80x25

Puts = Putstty80x25
NewLine = NewLine80x25
ClearScreen = ClearScreen80x25


;##############################################################################
;                             EMBEDDED DRIVERS

LDR_cursorpsc  db 0
LDR_cursorpsr  db 2
char_color     db 0x07

FRAME_BUFFER   = 0

;==============================================================================
GetCursorPosition:
        mov al, [LDR_cursorpsc]
        mov ah, [LDR_cursorpsr]
        ret
;==============================================================================
SetCursorPosition:
        mov [LDR_cursorpsc], al
        mov [LDR_cursorpsr], ah
        ret
SetCursorBegin:
        mov byte [LDR_cursorpsc], 00h
        mov byte [LDR_cursorpsr], 02h
        ret
;==============================================================================
; interrupt handle for keyboard management
DR_KeyboardISR:


        ret

; TEXT 80x25 video mode
;==============================================================================
; clear the display text buffer

ClearScreen80x25:

       push eax
       push ecx
       push edi
       mov ax,0x0700
       mov edi,0xb8000+(2*160)
       mov ecx,1840
       rep stosw

       mov  byte [LDR_cursorpsc],0
       mov  byte [LDR_cursorpsr],2

       pop edi
       pop ecx
       pop eax
       ret
;==============================================================================
; set a cursor character "_" on current cursor position
SetCursor80x25:

        push ecx
        push ebx

repeat_SetCursor80x25:

        cmp [LDR_cursorpsc],80
        je next_line_printstring2_SetCursor80x25
        cmp [LDR_cursorpsr],25
        je next_pageprintstring2_SetCursor80x25

       mov  dl, byte [LDR_cursorpsc]
       mov  dh, byte  [LDR_cursorpsr]

        mov ah,0x07
        mov al,'_'
        push eax
        mov edi,0xb8000
        movzx ecx,dh
        movzx ebx,dl
        mov eax,160           ; two bytes per character
        mul word cx
        add edi,eax
        shr ebx, 1
        add edi,ebx
        pop eax
        mov word [edi],ax

        pop ebx
        pop ecx
        ret

next_line_printstring2_SetCursor80x25:

        mov [LDR_cursorpsc],0
        inc [LDR_cursorpsr]

        jmp repeat_SetCursor80x25

next_pageprintstring2_SetCursor80x25:

        call Scrollup80x25
        mov byte [LDR_cursorpsc],0
        mov byte [LDR_cursorpsr],24
        jmp repeat_SetCursor80x25

;==============================================================================

;==============================================================================
;       put a character on current cursor position
; al = character
; dh = row
; dl = colunn

PutChar80x25:
        push ecx
        push ebx

        mov ah, [char_color]
        push eax
        mov edi,0xb8000
        movzx ecx,dh
        movzx ebx,dl
        mov eax,160           ; two bytes per character
        mul word cx
        add edi,eax
        shl ebx, 1
        add edi,ebx
        pop eax
        mov word [edi],ax

        pop ebx
        pop ecx
        ret
;==============================================================================
; put a character on cursor position in TTY mode
; al = character to be printed

PutChartty80x25:

        push esi
        push edi

print_repeat_printstring2:

        cmp [LDR_cursorpsc],80
        je next_line_printstring2
        cmp [LDR_cursorpsr],25
        je next_pageprintstring2

        cmp al,0
        je sai_printstring2

        mov dl,[LDR_cursorpsc]
        mov dh,[LDR_cursorpsr]

        call PutChar80x25

        inc [LDR_cursorpsc]

        call SetCursor80x25

        jmp sai_printstring2

next_line_printstring2:

        mov [LDR_cursorpsc],0
        inc [LDR_cursorpsr]

        jmp print_repeat_printstring2

new_line_printstring2:

        mov [LDR_cursorpsc],0
        inc [LDR_cursorpsr]
        jmp print_repeat_printstring2
next_pageprintstring2:

        call Scrollup80x25
        mov byte [LDR_cursorpsc],0
        mov byte [LDR_cursorpsr],24
        jmp print_repeat_printstring2

sai_printstring2:

        pop edi
        pop esi

        ret
;==============================================================================
;==============================================================================
;               print a string at current cursor position in TTY mode
; esi = terminating null string
PrintK:
	mov esi, ebx
Putstty80x25:

        push esi edi ebx ecx

print_repeat_printstring_32:
        lodsb
print_repeat_printstring_return_32:
        cmp [LDR_cursorpsc],80
        je next_line_printstring_32
        cmp [LDR_cursorpsr],25
        je next_pageprintstring_32

        test al,al
        jz sai_printstring_32

        cmp al,0dh
        je new_line_printstring_32

        mov dl,[LDR_cursorpsc]
        mov dh,[LDR_cursorpsr]

        call PutChar80x25
        inc byte [LDR_cursorpsc]

        jmp print_repeat_printstring_32

next_line_printstring_32:

        mov [LDR_cursorpsc],0
        inc [LDR_cursorpsr]

        jmp print_repeat_printstring_return_32

new_line_printstring_32:

        mov [LDR_cursorpsc],0
        inc [LDR_cursorpsr]
        jmp print_repeat_printstring_32
next_pageprintstring_32:

        call Scrollup80x25
        mov byte [LDR_cursorpsc],0
        mov byte [LDR_cursorpsr],24
        jmp print_repeat_printstring_return_32

sai_printstring_32:

        pop ecx ebx edi esi
        ret
;==============================================================================
;       scroll up one linw of the video buffer
;  scroll screen up

Scrollup80x25:

        push eax
        push ecx
        push edi
        push esi

        mov edi,0xb8000 + 160*2
        mov esi,0xb8000 + (160*3)

        mov ecx,80*23
        rep movsw

        mov ax,0x0f00
        mov ecx,80
        rep stosw

        pop esi
        pop edi
        pop ecx
        pop eax
        ret

;==============================================================================
;               jump to next line
NewLine80x25:

        mov [LDR_cursorpsc],0
        inc [LDR_cursorpsr]
        ret

;==============================================================================


SetCharColor80x25:

        mov byte [char_color],al
        ret

;==============================================================================
;==============================================================================
;          return one character on video buffer

BackSpacetty80x25:

       push esi
       push eax
       push edx
       push edi

       cmp  byte [LDR_cursorpsc],0
       jz   BackSpace80x25_return_line_32
       cmp  byte [LDR_cursorpsr],0
       jz   BackSpace80x25_return_page_32

BackSpacetty80x25_continue_32:

       mov al,0
       mov dh,[LDR_cursorpsr]
       mov dl,[LDR_cursorpsc]

       call PutChar80x25

       dec byte [LDR_cursorpsc]

       call SetCursor80x25

       pop edi
       pop edx
       pop eax
       pop esi
       ret

BackSpace80x25_return_line_32:

       mov al,0
       mov dh,[LDR_cursorpsr]
       mov dl,[LDR_cursorpsc]

       call PutChar80x25

       dec byte [LDR_cursorpsr]
       mov byte [LDR_cursorpsc],79
       call SetCursor80x25

       pop edi
       pop edx
       pop eax
       pop esi
       ret

BackSpace80x25_return_page_32:

        cmp byte [LDR_cursorpsc],0
        jnz BackSpacetty80x25_continue_32

        mov byte [LDR_cursorpsc],0
        mov byte [LDR_cursorpsr],0

        call SetCursor80x25

        pop edi
        pop edx
        pop eax
        pop esi
        ret

;==============================================================================