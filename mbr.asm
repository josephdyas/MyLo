
format binary as "dat"

ERROR1_SIZE	= 26  ;bytes
ERROR2_SIZE	= 18
ERROR3_SIZE	= 29
ERROR4_SIZE	= 29

include '%FASM%\include\macro\struct.inc'

struct MBR_ENTRY
	DriveAtt db ?
	CHSStart db 3 dup(?)
	PartitionType db ?
	CHSEnd	db 3 dup(?)
	LBAstart dd ?
	NumOfSectors dd ?
ends

use16
org 0x7c00
start:
	cli
	xor ax,ax
	mov ss,ax
	mov sp,0x7fff
	sti
;set video mode
	mov ah,00h			    ;video mode function
	mov al,03h			    ;80x25 mode
	int 0x10			     ;video interruption

;#############################################################################
;test if int 13h extensions is present

	clc			;clear flag carry
	xor dx,dx
	mov ah,41h		;teste int 13 extensions function
	mov dl, 0x80
	mov bx,0x55aa
	int 0x13		;interrut 13h
	mov ax,bx
	jc  not13		;if carry=1 jump to not extensions presente function
	jmp continue_load	;if carry=0 extensions present

not13:
	mov si, ERROR1
	call prints
	jmp exit

;#############################################################################
; Load the Bootload from disk with int 13h extension (LBA)

continue_load:
	mov si,loadBootloader
	call prints
	mov ax, word [entry0.LBAstart]
	mov word [absolute], ax
	mov word [secread], 32
	xor ax,ax
	mov word [buffers], ax
	mov bx, 0x8000
	mov [bufferf], bx
	call readdisk
	jmp 0x0000:0x8000
;#############################################################################
error_to_load_bootloader:
	mov si,ERROR3
	mov cx,ERROR3_SIZE
	jmp printerror
error_read_disk:
	mov si,ERROR2
	mov cx,ERROR2_SIZE
	jmp printerror
error_read_disk_parameters:
	mov si,ERROR4
	mov cx,29
printerror:
	call prints
;#############################################################################
exit:
	cli
	hlt
	mov	ah,00h		    ;subfuncao de aguardar tecla
	int	16h		    ;interrupção de teclado
;reset
	push	40h
	pop	ds
	mov	word [0072h],0
	jmp	0f000h:0fff0h

;##############################################################################
;print routine

prints:
	 cld
	 xor ax,ax
	 mov ds,ax
	 mov ax,0b800h
	 mov es,ax
	 xor di,di
  lp:
	 lodsb			;lodsb load then byte from ds:si to ax register
	 cmp al,00h
	 jz sai
	 mov ah,07h
	 mov word[es:di],ax
	 add di,02h
	 dec cx
	 jmp lp
    sai:
	 ret
;############################################################################
;	Disk read routine   - using int 13h extension

readdisk:

	xor ax,ax
	mov ds,ax
	mov es,ax
	mov si,DAP
	mov dl,80h
	mov ah,42h
	clc
	int 13h 	; carry flag set if error, clear if no error
	jc error_read_disk
	ret

; print a word value on screen like a string
printword:

	push cs
	pop es

	push di
	push si
	mov si,strprintword +2

	lea di,[si+3]
	mov bx,ax
	mov cx,4
	cld		  ; decrement di

repeat_converthex:
	cmp cx,0
	jz  exit_converthex
	mov si,hextable
	and ax,0fh
	add si,ax
	mov al, byte [es:si]
	ds stosb
	shr bx,4
	mov ax,bx
	dec cx
	sub di,2
	jmp repeat_converthex
exit_converthex:
	mov si,strprintword
	mov cx, 6
	call prints
	pop si
	pop di
	ret

hextable db '0123456789abcdef'
strprintword db '0xXXXX',0

;##############################################################################
;======================
;DAP structure	      ; DAP is a structure used by the int13 to read and write a disk
;DAP to read FAT
DAP	 db 10h 	; size of the struct
zr	 db 00h 	; should be 0
secread  dw 0x0000	    ; number of sector to be read
bufferf  dw 0x0000	 ; offset of the destination buffer
buffers  dw 0x0000	 ; segment of the destination buffer
absolute dq 0x0000	 ; absolute number of the start of the sectors to be read (1st sector of drive has number 0)

;======================
;     Messages
ERROR1	db "INT 13h ex is not present!" 	;26 bytes
ERROR2	db "Error to read disk" 		;18 bytes
ERROR3	db "Error! BootLoader not found. "	;29 bytes
ERROR4	db "Erro to read disk parameters!"	; 29
loadBootloader db "Carregando Bootloader...",0

endboot:
;##############################################################################
;complete the number of bytes  to align with 512 bytes and put the magic number
codesize = (endboot-start)
;----------------------------------------------------------
if codesize > 446
display 'Code Greather than 446 bytes'
err
end if
;----------------------------------------------------------
times (446 - codesize) db 0
entry0 MBR_ENTRY
entry1 MBR_ENTRY
entry2 MBR_ENTRY
entry3 MBR_ENTRY
magic dw 0xaa55
;##############################################################################
