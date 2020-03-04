;##############################################################################
;
;	CODE AND DATA FOR INTERRUPT MANAGEMENT
;	MyOS Joseph Dias - 02.2019 - 03.2019
;
;##############################################################################
struct idt_entry32
	offset1 	dw ?
	selector	dw ?
	ist			db ?
	type		db ?
	offset2 	dw ?
ends

virtual at 0
	V_idtentry idt_entry32
end virtual
;==============================================================================
InitializeInterruptSystem_def:
;Routeirqs
	cli
;icw1
	mov	al,0x11 	;  send icw4  after
	out	0x20,al
	call	pic_delay
	out	0xA0,al
	call	pic_delay
;icw2
	mov	al,0x20 	;  irq0 - 7 from 20h to 27h
	out	0x21,al
	call	pic_delay
	mov	al,0x28 	;  irq8 - 15 from 28 to 30
	out	0xA1,al
	call	pic_delay
;icw3
	mov	al,0x04 	;  slave at irq2
	out	0x21,al
	call	pic_delay
	mov	al,0x02 	;  at irq9
	out	0xA1,al
	call	pic_delay
;icw4
	mov	al,0x01 	;  80x86 mode
	out	0x21,al
	call	pic_delay
	out	0xA1,al
	call	pic_delay
	mov	al,255		; mask all irq's
	out	0xA1,al
	call	pic_delay
	out	0x21,al
	call	pic_delay
	mov	ecx,0x1000
	cld
picl1:	call	pic_delay
	loop	picl1
	mov	al,255		; mask all irq's
	out	0xA1,al
	call	pic_delay
	out	0x21,al
	call	pic_delay
	cli
	jmp build_interrupttable

pic_delay:
	jmp	pdl1
pdl1:	ret
;------------------------------------------------------------------------------

; Set the Interrupt Descriptor Table
build_interrupttable:

	mov edi,0x1000
	mov edx, sys_int_list
	mov ebx,(int_list_end-sys_int_list)/4	; number of interrupts

repeat_build_interruptable:

	mov word [edi+V_idtentry.selector], os_code   ; sytem code segment
       ; mov al,10001110b
	mov byte [edi+V_idtentry.type],10001110b
	mov byte [edi+V_idtentry.ist],0

	mov eax, dword [edx]
	mov word [edi+V_idtentry.offset1],ax
	shr eax,16
	mov word [edi+V_idtentry.offset2],ax

	add edx,4	       ; next procedure address
	add edi,8
	dec ebx
	cmp ebx,0
	jnz repeat_build_interruptable
;------------------------------------------------------------------------------
	mov esi, idt_descriptor
	mov ax, int_list_end-sys_int_list-1  ; size of IDT
	mov word [esi],ax
	mov dword [esi+0x02], 0x1000
; Load the IDT Table
	lidt [esi]
	ret
;==============================================================================
align 4
sys_int_list:

    dd	 s0,s1,s2,s3,s4,s5,s6,s7,s8,s9,sa,sb,sc,sd,se,sf

    dd	 unknown,unknown,unknown,unknown
    dd	 unknown,unknown,unknown,unknown
    dd	 unknown,unknown,unknown,unknown
    dd	 unknown,unknown,unknown,unknown

    dd	 irq0,irq1,irq2 ,irq3 ,irq4 ,irq5 ,irq6 ,irq7
    dd	 irq8,irq9,irq10,irq11,irq12,irq13,irq14,irq15
;
    dd	 unknown,unknown,unknown,unknown
    dd	 unknown,unknown,unknown,unknown
    dd	 unknown,unknown,unknown,unknown
    dd	 unknown,unknown,unknown,unknown

    dd	 unknown,unknown,unknown,unknown
    dd	 unknown,unknown,unknown,unknown
    dd	 unknown,unknown,unknown,unknown
    dd	 unknown,unknown,unknown,unknown
int_list_end:
align 4

;=============================================================================
; Divide by zero
s0:
      mov ax,0x0700 + "0"
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_s0:
      stosw
      loop clearvideo2_s0
      mov ecx,0xffffff
loopkey2:
      loop loopkey2
      cli
      hlt
      iretd
align 4
;#############################################################################
; Debug
s1:
      mov ax,0x0700 + "D"
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_s1:
      stosw
      loop clearvideo2_s1
      cli
      hlt
      iretd
align 4
;#############################################################################
; Non-Maskable Interrupt
s2:
      mov ax,0x0742
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_s2:
      stosw
      loop clearvideo2_s2
      cli
      hlt
      iretd
align 4
;#############################################################################
; Breakpoint
s3:
      mov ax,0x0743
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_s3:
      stosw
      loop clearvideo2_s3
      cli
      hlt
      iretd
align 4
;#############################################################################
; Overflow
s4:
      mov ax,0x0744
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_s4:
      stosw
      loop clearvideo2_s4
      cli
      hlt
      iretd
align 4
;#############################################################################
; Bound Range Exceded
s5:
      mov ax,0x0745
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_s5:
      stosw
      loop clearvideo2_s5
      cli
      hlt
      iretd
align 4
;#############################################################################
; Invalid Opcode
s6:
      mov ax,0x0700+'O'
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_s6:
      stosw
      loop clearvideo2_s6
      cli
      hlt
      iretd
align 4
;#############################################################################
; Device No Available
s7:
      mov ax,0x0747
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_s7:
      stosw
      loop clearvideo2_s7
      cli
      hlt
      iretd
align 4
;#############################################################################
; Double Fault
s8:
      mov ax,0x0748
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_s8:
      stosw
      loop clearvideo2_s8
       cli
      hlt
      iretd
align 4
;#############################################################################
; Coprocessor Segment
s9:
      mov ax,0x0749
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_s9:
      stosw
      loop clearvideo2_s9
      cli
      hlt
      iretd
align 4
;#############################################################################
; Invalid TSS
sa:
      mov ax,0x0750
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_sa:
      stosw
      loop clearvideo2_sa
      cli
      hlt
      iretd
align 4
;#############################################################################
; Segment Not Present
sb:
      mov ax,0x0700+'A'
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_sb:
      stosw
      loop clearvideo2_sb
	cli
      hlt
	iretd
align 4
;#############################################################################
; Stack-Segment Fault
sc:
      mov ax,0x0752
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_sc:
      stosw
      loop clearvideo2_sc
      cli
      hlt
      iretd
align 4
;#############################################################################
; General Protection Fault
GPF db 'General Protection Fault. error: ',0
align 4
sd:

	call ClearScreen80x25_def
	mov ecx,GPF
	call Putstty80x25_def
	cli
	hlt
	iretd
align 4
;#############################################################################
; Reserved
se:
      mov ax,0x0754
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_se:
      stosw
      loop clearvideo2_se
      cli
      hlt
      iretd
align 4
;#############################################################################
; x87 FLoating-Point Exception
sf:
      mov ax,0x0755
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_sf:
      stosw
      loop clearvideo2_sf
      cli
      hlt
      iretd
timerate dd 10
align 4
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
irq0:
	cmp dword [timerate], 0
	jle counttick
	dec dword [timerate]
	jmp exit_timer_tick
counttick:
	mov dword [timerate], 10
	call ShowTime_def
exit_timer_tick:
;******************************************
;SEND EOI
	push eax
	mov al,20h
	out 20h,al  ; acknowledge the interrupt to the PIC
	pop eax
;******************************************
      iretd
;#############################################################################
listrun db 0
align 4
irq1:
	cmp byte [listrun], 0
	jnz listruning
	mov byte [listrun], 1
listruning:

	;call DR_KeyboardISR_def		    ; kbd Driver

;******************************************
;SEND EOI
	push eax    ;; make sure you don't damage current state
	in al,60h   ;; read information from the keyboard

	mov al,20h
	out 20h,al  ;; acknowledge the interrupt to the PIC
	pop eax     ;; restore state
;******************************************

	iretd
align 4
;#############################################################################
irq2:
      mov ax,0x0763
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_irq2:
      stosw
      loop clearvideo2_irq2

      iretd
align 4
;#############################################################################
irq3:
      mov ax,0x0764
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_irq3:
      stosw
      loop clearvideo2_irq3

      iretd
align 4
;#############################################################################
irq4:
      mov ax,0x0765
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_irq4:
      stosw
      loop clearvideo2_irq4

      iretd
align 4
;#############################################################################
irq5:
      mov ax,0x0754
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_irq5:
      stosw
      loop clearvideo2_irq5

      iretd
align 4
;#############################################################################
irq6:
      mov ax,0x0766
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_irq6:
      stosw
      loop clearvideo2_irq6

      iretd
align 4
;#############################################################################
irq7:

      ;  call EhciISR
;******************************************
;SEND EOI
	push eax    ;; make sure you don't damage current state
	mov   al,0x20
	out   0x20,al		    ; send EOI to primary   PIC
	out   0xa0,al		    ; send EOI to secondary PIC
	pop eax     ;; restore state
;******************************************
      iretd

      mov ax,0x0765
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_irq7:
      stosw
      loop clearvideo2_irq7

      iretd
align 4
;#############################################################################
irq8:
      mov ax,0x0766
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_irq8:
      stosw
      loop clearvideo2_irq8

      iretd
align 4
;#############################################################################
irq9:
      mov ax,0x0767
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_irq9:
      stosw
      loop clearvideo2_irq9

      iretd
align 4
;#############################################################################
irq10:
      mov ax,0x0768
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_irq10:
      stosw
      loop clearvideo2_irq10

      iretd

;#############################################################################
align 4
irq11:

      iretd
align 4
;#############################################################################
irq12:
      mov ax,0x0770
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_irq12:
      stosw
      loop clearvideo2_irq12

      iretd
align 4
;#############################################################################
irq13:
      mov ax,0x0771
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_irq13:
      stosw
      loop clearvideo2_irq13

      iretd
align 4
;#############################################################################
irq14:
      mov ax,0x0772
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_irq14:
      stosw
      loop clearvideo2_irq14

      iretd
align 4
;#############################################################################
irq15:
      mov ax,0x0773
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_irq15:
      stosw
      loop clearvideo2_irq15

      iretd
align 4
;#############################################################################

unknown:

      mov ax,0x07c5
      mov edi,0xb8000	   ; video buffer
      mov ecx,2001
clearvideo2_unknown:
      stosw
      loop clearvideo2_unknown

      iretd
align 4
;============================================================================