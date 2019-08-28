;==============================================================================
align 4
counterTime dd 0

ShowTime:
	push edi esi ecx
	mov esi,strprintdword_32_put
	add esi,2
	mov eax, [counterTime]
	call ConvertHexDword
	mov ecx, 10
	mov esi,strprintdword_32_put
	mov edi, 0b8000h+2
	mov ah, 07h
loop_show_time:
	lodsb
	stosw
	loop loop_show_time
	inc dword [counterTime]
	pop ecx esi edi
	ret
strprintdword_32_put db '0xXXXXXXXX'
;==============================================================================
; eax = number to be displayed
PrintDword:

	push esi edi
	mov esi,strprintdword_32
	add esi,2
	call ConvertHexDword
	mov esi,strprintdword_32
	call Putstty80x25
	pop edi esi
	ret
PrintWord:

	push esi edi
	mov esi,strprintword_32
	add esi,2
	call ConvertHexWord
	mov esi,strprintword_32
	call Putstty80x25
	pop edi esi
	ret

strprintword_32  db '0xXXXX',0dh,0
strprintdword_32 db '0xXXXXXXXX',0dh,0
;==============================================================================
; esi = address of the buffer to receiv string
; eax = dword,word or byte to convert
ConvertHexDword:

	push esi edi ebx ecx

	mov edi,esi
	add edi,7
	mov ebx,eax
	mov ecx,8
	cld					; decrement edi
	jmp  repeat_converthexdword

ConvertHexWord:

	push esi edi ebx ecx

	mov edi,esi
	add edi,3
	mov ebx,eax
	mov ecx,4
	cld		  ; decrement edi
	jmp  repeat_converthexdword

ConvertHexByte:
	push esi edi ebx ecx

	mov edi,esi
	add edi,1
	mov ebx,eax
	mov ecx,2
	cld		  ; decrement edi

repeat_converthexdword:

	cmp ecx,0
	jz  exit_converthexdword
	mov esi,hextable
	and eax,0fh
	mov al, byte [esi+eax]
	stosb
	shr ebx,4
	mov eax,ebx
	dec ecx
	sub edi,2
	jmp repeat_converthexdword

exit_converthexdword:

	pop ecx ebx edi esi
	ret

hextable db '0123456789ABCDEF'
;============================================================================
;############################################################################
; esi = address of memory to show data
DumpMemory:;,param

;--------------------------------------
      push edi esi ebx

      cld
      mov esi,dump_clear
      mov edi,dump_line
      mov ecx,(dump_clearE-dump_clear)
      rep movsb

      pop ebx
      pop esi
;--------------------------------------

      ;mov esi,[param]
      mov ecx,256

; convert the offset of the first 16 bytes

      call NewLine80x25

      mov  edx,ecx

      push esi
      mov eax,esi
      mov esi, dump_line
   ;   add esi,2
      call ConvertHexDword
      pop ebx
      mov esi,ebx
      mov [dump_currentbyte],dump_byteslow
      mov [dump_currentchar],0
      mov ecx,8

; convert the first 8 bytes

repeat_dump_bytelow:

	test edx,edx
	jz exit_dump		; the number of bytes to dump was reached

	mov al, byte [esi]
;------------------------------------
; test if is a ASCII character

	cmp al,0x20
	jb dump_continue1
	cmp al,0x7d
	ja dump_continue1

	push esi
	mov esi,dump_ASCII
	add esi, [dump_currentchar]
	mov byte [esi],al
	pop esi
	;jmp dump_continue1

dump_continue1:

	inc [dump_currentchar]
;------------------------------------
	mov esi,[dump_currentbyte]
	push ebx
	call ConvertHexByte
	pop ebx

	inc ebx
	mov esi,ebx
	add [dump_currentbyte],3
	dec edx 		 ; decrement the number of total bytes
	dec ecx
	jcxz dump_bytehigh
	jmp repeat_dump_bytelow
;+++++++++++++++++++++++++++++++++++++++++++
dump_bytehigh:


      mov [dump_currentbyte],dump_byteshigh
      mov ecx,8

repeat_dump_bytehigh:

	test edx,edx
	jz exit_dump		; the number of bytes to dump was reached

	mov al, byte [esi]
;------------------------------------
; test if is a ASCII character
	cmp al,0x20
	jb dump_continue2
	cmp al,0x7d
	ja dump_continue2

	push esi
	mov esi,dump_ASCII
	add esi,[dump_currentchar]
	mov byte [esi],al
	pop esi
	;jmp dump_continue2

dump_continue2:

	inc [dump_currentchar]
;------------------------------------
	mov esi,[dump_currentbyte]
	push ebx
	call ConvertHexByte
	pop ebx

	inc ebx
	mov esi,ebx
	add [dump_currentbyte],3
	dec edx
	dec ecx
	jcxz exit_repeat_dump_bytehigh
	jmp repeat_dump_bytehigh

;-------------------------------------

exit_repeat_dump_bytehigh:

	test edx,edx
	jz exit_dump		; the number of bytes to dump was reached

; convert the offset of the first 16 bytes
     ; print the row
      push esi
      push edx
      push ebx
      mov esi,dump_line
      call Putstty80x25

      cld
      mov esi,dump_clear
      mov edi,dump_line
      mov ecx,(dump_clearE-dump_clear)
      rep movsb

      pop ebx
      pop edx
      pop esi

      push esi
      mov eax,esi
      mov esi, dump_line
    ;  add esi,2
      call ConvertHexDword
      pop ebx
      mov esi,ebx
      mov [dump_currentchar],0
      mov [dump_currentbyte],dump_byteslow
      mov ecx,8
      jmp repeat_dump_bytelow

exit_dump:

      mov esi,dump_line
      call Putstty80x25
exit_dump_error:
	pop edi
      ret
;------------------------------------------------------------------------
dump_currentchar dd 0
dump_currentbyte dd ?
dump_line	db 'XXXXXXXXh| ' ; 11
dump_byteslow	db 'XX XX XX XX XX XX XX XX : ' ; 26
dump_byteshigh	db 'XX XX XX XX XX XX XX XX |' ; 25
dump_ASCII	db '................|',0dh,0   ;19

dump_clear	db 'XXXXXXXXh| ' ; 11
		db 'XX XX XX XX XX XX XX XX : ' ; 26
		db 'XX XX XX XX XX XX XX XX |' ; 25
		db '................|',0dh,0   ;19
dump_clearE:
;===============================================================================
;===============================================================================
; ebx = Device Information Block Buffer
; edx = Number of Devices
virtual at edi
	pciconfigspace PCI_HEADER_TYPE_0
end virtual
ShowPciDevInfo:
	push esi edi ecx

	mov edi, ebx
	push edx
	mov esi, boot_pcidevices
	call Putstty80x25
	pop ecx
loop_put_devices:
	mov ebx, dword [edi]
	mov ax, bx
	mov esi, boot_deviceVendor+2	; VendorID
	call ConvertHexWord
	shr ebx, 16
	mov ax, bx
	mov esi, boot_deviceID+2    ; DeviceID
	call ConvertHexWord
	mov ebx, dword [pciconfigspace.RevisionID]
	mov al, bl
	mov esi, boot_deviceRev+2	; Revision
	call ConvertHexByte
	shr ebx,8
	mov al, bl
	mov esi, boot_deviceProgIF+2	 ; Programmer Interface
	call ConvertHexByte
	shr ebx,8
	mov al, bl
	mov esi, boot_deviceSubClass+2	   ; SubClass
	call ConvertHexByte
	shr ebx,8
	mov al, bl
	mov esi, boot_deviceClass+2	; Class Code
	call ConvertHexByte
	movzx eax, byte [pciconfigspace.InterruptLine]
	mov esi, boot_deviceBar0+2
	call ConvertHexByte

	mov esi, boot_deviceID
	call Putstty80x25
	add edi, 100h
	loop loop_put_devices

	pop ecx edi esi
	ret
;===============================================================================
; ebx = Device Address Information buffer
; edx = Number Of Devices

ShowPciAddressInfo:
	push esi edi ecx

	mov edi, ebx
	push edx

	mov esi, boot_pcidevices2
	call Putstty80x25
	pop ecx
loop_put_devices2:
	mov ebx, dword [edi]
	mov al, bl
	mov esi, boot_deviceindex+4
	call ConvertHexByte
	shr ebx, 8
	mov al, bl
	mov esi, boot_deviceFunc+4
	call ConvertHexByte
	shr ebx, 8
	mov al, bl
	mov esi, boot_deviceDev+4
	call ConvertHexByte
	shr ebx, 8
	mov al, bl
	mov esi, boot_deviceBus+4
	call ConvertHexByte
	mov esi, boot_deviceindex
	call Putstty80x25
	add edi, 4
	loop loop_put_devices2
	pop ecx edi esi
	ret
;--------------------------------------
;===============================================================================
ShowEhciConfig:


	ret
;===============================================================================
;===============================================================================
; Show the value in a queue head
;	ebx = address of the Queue Head
virtual at edi
	sqh_pipe EHCI_PIPE
end virtual

ShowQueueHead:
	push edi esi

	mov edi, ebx

	mov eax, [sqh_pipe.NextQH]
	lea esi, [sqh_NextQH+10]
	call ConvertHexDword
	mov eax, [sqh_pipe.Token]
	lea esi, [sqh_Token+9]
	call ConvertHexDword
	mov eax, [sqh_pipe.Flags]
	lea esi, [sqh_Flags+9]
	call ConvertHexDword
	mov eax, [sqh_pipe.CurrentTD]
	lea esi, [sqh_CurrentTD+9]
	call ConvertHexDword
	mov eax, [sqh_pipe.Overlay.NextTD]
	lea esi, [sqh_Overlay+18]
	call ConvertHexDword
	mov esi, sqh_string
	call Puts

	pop esi edi
	ret
;--------------------------------------
sqh_string:
sqh_NextQH		db 'NextQH: 0x00000000',0dh
sqh_Token		db 'Token: 0x00000000',0dh
sqh_Flags		db 'Flags: 0x00000000',0dh
sqh_CurrentTD	db 'CurTD: 0x00000000',0dh
sqh_Overlay		db 'Overlay.NextTD: 0x00000000',0dh,0
;===============================================================================
;===============================================================================
; Show the values in a Transfer Descritor
;	ebx = address of the Transfer Descritor
virtual at edi
	std_td EHCI_TD
end virtual

ShowTransferDescriptor:
	push edi esi

	mov edi, ebx

	mov eax, [std_td.NextTD]
	lea esi, [std_NextTD+10]
	call ConvertHexDword
	mov eax, [std_td.Token]
	lea esi, [std_Token+9]
	call ConvertHexDword
	mov eax, [std_td.BufferPointers]
	lea esi, [std_BufferPointers+10]
	call ConvertHexDword

	mov esi, std_string
	call Puts

	pop esi edi
	ret
;--------------------------------------
std_string:
std_NextTD			db 'NextTD: 0x00000000',0dh
std_Token			db 'Token: 0x00000000',0dh
std_BufferPointers	db 'Buffer: 0x00000000',0dh,0
;===============================================================================
