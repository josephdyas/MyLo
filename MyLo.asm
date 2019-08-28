;##############################################################################
;		       BOOTLOADER - MYOS SYSTEM
;
; Developed by Joseph Dias - Octuber, 2016 - 02.2018
; Version 0.0.1
;
;##############################################################################
format binary as "dat"

BootLoaderSize = 4000h

LOADERR_STRING_SIZE	= 27		; bytes
LOGO_SIZE		= (endsystemlogo-systemlogo)
FAT_ADDRESS		= 0x1000	; address where load the FAT
ROOT_ADDRESS		= 0x3000	; Address where load the Root Directory
DIRECTORY_BUFFER	= 0x5000	; Buffer used to store the temporary directory on a search
BOOTLOADER_ADDRESS	= 0x8000	; Address where the bootload was loaded
CONFIG_ADDRESS		= 0x0600
MMAP_ADDRESS		= 0xC000+2	; number of entrys (word) + Memory Map
SYSTEM_INFO_BASE	= 0x2000

macro SLEEP
{
   hlt
   nop
   hlt
}

include '..\MyOS\src\include\asm\struct.inc'
include 'include\manager_memory.inc'
include 'include\manager_io.inc'
include 'include\drivers.inc'

use16
org 0x8000
;##############################################################################
file_start:
jmp start
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
OEMID		db "MYOS 0.1"	; information about pendrive 8GB "red"
bytepersec	dw 0   ;0x200
secperclus	db 0   ;0x08
reservsec	dw 0   ;0x08b2
numberoffat	db 0   ;0x02
Numberrootentry dw 0
totalseccount	dw 0
mediadesc	db 0	; f8h for hard disks
secperfat16	dw 0	; sectors per FAT for FAT12/16
;--------------------------------------------------------------------------
secpertrack	dw 0	;0x3f
numberhead	dw 0	;0xff
hiddensec	dd 0	;0x000002	; sectors before the partition
secinpartition	dd 0	;0x00ef17fe	   (x512 = 8GB)
;--------------------------------------------------------------------------
secperfat	dd 0	;0x3ba7
flags		dw 0	;
fatversion	dw 0
rootstartclus	dd 0	;0x02	;Cluster Number of the begin of the Root Directory
setnumfsinfo	dw 0	;0x01	;Sector Number of the File System Information Sector
secnumbacboot	dw 0	;0x06	;Sector Number of the Backup Boot Sector (Referenced from the Start of the Partition)
Reserved	db 12 dup(?)
logdrivnumpart	db 0		;Logical Drive Number of Partition
Unused		db 0
;--------------------------------------------------------------------------
extbootsig	db 0		; boot signature
serialnum	dd 0		;
vollabel	db "NO NAME    "; must contain 11 bytes
systemID	db "FAT32   "	; must contain 8 bytes
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
start:
	cli
	xor ax,ax
	mov ss,ax
	mov sp,0x7fff
	sti
;set the data segment
	push cs
	pop ds
;-------------------------------------------------------------------------------
	call configvideo   ;set video mode - text 80x25
	call printlogo	   ;set the background with system logo
;==============================================================================
; -------------------------------------------------
; test 32 bits archtecture

    pushf
    pop   ax
    mov   dx,ax
    xor   ax,0x4000
    push  ax
    popf
    pushf
    pop   ax
    and   ax,0x4000
    and   dx,0x4000
    cmp   ax,dx
    jnz   cpufine
    mov si,errorsystem32
    call puts
    hlt
  cpufine:
; 32 bits processor ok
; ----------------------------------------------------
;    cli
;    mov   ax,0x2000		 ; stack segment (same as above)
;    mov   ss,ax
;    mov   esp,0xfffc		 ; ensure same as 16-bit value
;    sti
    xor   eax,eax
    xor   ebx,ebx
    xor   ecx,ecx
    xor   edx,edx
    xor   esi,esi
    xor   edi,edi
    xor   ebp,ebp
;==============================================================================
; clear the keyboard buffer
    mov   dx,100
  cloop1:
    mov   cx,100
  cloop2:
    in	  al,0x64
    loop  cloop2
    test  al,1
    jz	  exit_cloop
    in	  al,0x60
    dec   dx
    jnz   cloop1
  exit_cloop:
;=============================================================================
; GET VESA INFORMATION
    push es
    push 0
    pop es

    mov   ax,0x4f00			; VESA BIOS function
    mov   di,0x600
    int   0x10

    cmp   ax,0x004f
    je	  version
    mov   si,VesaNo
    call  puts
    jmp   vesanotfound
  version:
    mov   ax,[es:di+4]		; AH = major, AL = minor version
    mov   dx,ax
    add   ah,0x30
    add   al,0x30
    mov   [Vesaver+14],ah	; replace x.x in string with numbers
    mov   [Vesaver+16],al	; update offsets if string is modified
    mov   si,Vesaver
    call  puts
  vesanotfound:
    pop es
;==========================================================================
; GET PHYSICAL MEMORY MAP
	mov si, GetMemoryMapstr
	call puts
	mov al,0
	mov di,MMAP_ADDRESS
	mov cx,128
repeat_clean:
	es stosb
	jcxz continue_mmap
	dec cx
	jmp repeat_clean
continue_mmap:
; Get the memory MAP
	push word 0
	pop es
	mov di,MMAP_ADDRESS	 ; address of memory where the map will stored
      ;  add di,2
	call do_e820
	jnc mmap_ok
	mov si,mmaperror
	call puts
	jmp getkey
mmap_ok:
	mov di,MMAP_ADDRESS
	mov ax,[mmap_ent]
	mov [es:di-2],ax      ; mumber of entry on buffer begin

	jmp SwitchMode
;==========================================================================
; SWITCH TO 32 BIT PROTECTED MODE

SwitchMode:

os_data        equ  os_data_l-gdt_descriptor	; GDTs
os_code        equ  os_code_l-gdt_descriptor
tss_seg        equ  TSSS			; address of the tss segment
tss_des        equ  tss_l-gdt_descriptor	; address of the selector to tss

	mov ax, 0
	mov es, ax
	mov ds, ax
;------------------------------------------------------------------------------
; disable all interrupts
	cli				; disable all irqs
	cld
	mov	al,255			; mask all irqs
	out	0xa1,al
	out	0x21,al
empty_8042:
	in	al, 0x64		; Enable A20
	test	al, 2
	jnz	empty_8042
	mov	al, 0xd1
	out	0x64, al
empty_8042_2:
	in	al, 0x64
	test	al, 2
	jnz	empty_8042_2
	mov	al, 0xdf
	out	0x60, al
;------------------------------------------------------------------------------
; Set the global descriptor table

	lgdt [gdt_descriptor]	; Load GDT
;------------------------------------------------------------------------------
; Enabling 32 bit protected mode

	mov	eax, cr0
	or	dword eax, 0x00000001	; protected mode
       ; and	 eax, 10011111b *65536*256 + 0xffffff ; caching enabled
	mov	cr0, eax
	jmp	farjmp
	nop
	nop
	farjmp:
	mov	ax,os_data
	mov	ds,ax
	mov	es,ax
	mov	fs,ax
	mov	gs,ax
	mov	ss,ax
	mov	esp,0x2fff
	jmp	pword os_code:protected_mode_code
;==============================================================================
include 'api16.inc'

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
; 32 BITS CODE
use32
align 4
protected_mode_code:
	call ClearScreen80x25
;==============================================================================
; INITIALIZE IDT AND INTERRUPTS PROCEDURES

	call InitializeInterruptSystem
	
;==============================================================================
; SET THE TASK STATE SEGMENT

;	 mov eax, tss_seg
;	 mov edi, tss_l
;	 mov [edi+2],ax
;	 shr eax, 16
;	 mov [edi+4], al
;	 shr eax, 8
;	 mov [edi+7], al
;	 mov ax, tss_des
;	 ltr ax 		 ;Load the Task State Descriptor
;==============================================================================

;--------------------------------------
; set the timer counter
	mov al, 0x36
	out 0x43, al
	mov ax, 11931
	out 0x40, al
	shr ax, 8
	out 0x40, al
;--------------------------------------
; start the interrupt handle
	mov al,11111110b	   ; unmask irq 0 - timer and irq 1 - Keyboard
	out 0x21,al
	mov ecx,32
     ready_for_irqs:
	mov   al,0x20
	out   0x20,al		    ; send EOI to primary   PIC
	out   0xa0,al		    ; send EOI to secondary PIC
	loop  ready_for_irqs	    ; flush the queue
	sti
;==============================================================================
; INITIALIZE MEMORY MANAGMENT
	mov ebx, G_BlockList
	mov edx, 100000h/PF_SIZE ;Number of page frames for 1 Megabyte
	mov ecx, 100000h
	call InitializeBlockList
	call InitializeMemoryManager
;==============================================================================
; INITIALIZE I/O MANAGMENT
	call InitIOManager
	test eax,eax
	js StopSystem	; Stop system boot if -1
;==============================================================================

;  Get CPU identification
cpuid_0   equ  SYSTEM_INFO_BASE + 0x1c	  ;28
cpuid_1   equ  SYSTEM_INFO_BASE + 0x2c	  ;44
cpuid_2   equ  SYSTEM_INFO_BASE + 0x3c	  ;60
cpuid_3   equ  SYSTEM_INFO_BASE + 0x4c	  ;76
cpuid_4   equ  SYSTEM_INFO_BASE + 0X5c

    mov  esi,boot_cpuid
    call Putstty80x25

    pushfd				 ;Save EFLAGS
    pushfd				 ;Store EFLAGS
    xor dword [esp],0x00200000		 ;Invert the ID bit in stored EFLAGS
    popfd				 ;Load stored EFLAGS (with ID bit inverted)
    pushfd				 ;Store EFLAGS again (ID bit may or may not be inverted)
    pop eax				 ;eax = modified EFLAGS (ID bit may or may not be inverted)
    xor eax,[esp]			 ;eax = whichever bits were changed
    popfd				 ;Restore original EFLAGS
    and eax,0x00200000			 ;eax = zero if ID bit can't be changed, else non-zero
    jnz cpuidok

    mov esi,boot_cpuiderror
    call Putstty80x25
dontcpuid:
    jmp StopSystem
cpuidok:
     mov esi,0
     mov edi,cpuid_0
repeat_getcpuid:
     mov eax,esi
     cpuid
     mov     [edi+00], eax
     mov     [edi+04], ebx
     mov     [edi+08], edx
     mov     [edi+12], ecx
     add     edi,4*4
     cmp     esi,5
     jge     get_cpuid_done
     cmp     esi,[cpuid_0]
     jge     get_cpuid_done
     inc     esi
     jmp     repeat_getcpuid

get_cpuid_done:

      mov ecx,12
      mov esi,cpuid_0+4
      mov edi,boot_cpuidname+6	  ; cpu id name string
      rep movsb
      mov esi,boot_cpuidname
      call Putstty80x25
     ; mov esi, boot_cpuidExFunc
     ; call Putstty80x25
;-----------------------------
; Get CPU brand and max clock
	mov esi, 0x80000002
	mov edi, cpuid_brandString
repeat_get_cpu_brand:
	mov eax, esi
	cpuid
	mov [edi], eax
	mov [edi+4], ebx
	mov [edi+8], ecx
	mov [edi+12], edx
	inc esi
	add edi,4*4
	cmp esi,0x80000005
	jne repeat_get_cpu_brand
;-----------------------------

	mov esi,cpuid_brandString
	call Putstty80x25
	call NewLine80x25
;==============================================================================
; DETECT PCI DEVICES
	mov esi,boot_pcibus
	call Putstty80x25

	mov esi,boot_devices
	call Putstty80x25

;	 mov ebx, 1000h
;	 call AllocMemory
;	 mov [gPciStructBuffer], eax
;	 mov ebx, eax
;	 mov edx, gPciDeviceIndex
;	 call ScanPCIBus
;	 mov [gPciDeviceCount], eax
;
;	 mov ebx, gPciDeviceIndex
;	 mov edx, eax
;	 call ShowPciInfo
	jmp StopSystem

	jmp search_echi_host_controller

;==============================================================================
; SEARCH AND INITIALIZE EHCI HOST CONTROLLER
cursor	dw ?
porttest dd 0
ehcidescAddress dd ?
ehcilastdevindex dd 0
ehcicount db 0
virtual at 0
	operacional2 EHCI_OPERACIONAL_REGISTER
end virtual
virtual at 0
ehcidescriptor1 EHCI_DESCRIPTOR
end virtual
;TODO - change the PciQueryDevice method to simplife query
align 4
search_echi_host_controller:
	mov esi, boot_searchehci
	call Puts
;----------------------------
	xor eax,eax
	mov edi, gEhciDescriptorBuffer
	mov ecx, sizeof.EHCI_DESCRIPTOR*2
	rep stosd
;----------------------------
	mov byte [ehcicount], 0
	mov ebx, [gPciStructBuffer]
	mov ecx, [gPciDeviceCount]
	jmp sehci_while_test
; while----------------------
sehci_while_do:
	add [ehcilastdevindex], eax
	mov esi, boot_ehciconfig
	call Puts
	hlt
	nop
;--------------------------------------
; initialize the Host Controller
	mov ebx, gEhciDescriptorBuffer
	call AllocEhciDescriptor ; Descriptor Buffer
	mov [ehcidescAddress], eax
	mov edx,eax
;------------------
	mov eax, [ehcilastdevindex]
	mov ebx, [gPciStructBuffer]
	shl eax, 8	; eax*256
	add ebx, eax
;------------------
	mov eax, [ehcilastdevindex]
	mov ecx, gPciDeviceIndex
	mov ecx, [ecx+eax*4]
	call EhciInit	; Ehci Config Space, Device Descriptor, pci config address (bus/dev/func/index)
	test eax,eax
	jnz ehci_init_error
	inc byte [ehcicount]
	inc dword [ehcilastdevindex]
	mov eax, [ehcilastdevindex]
	mov ecx, [gPciDeviceCount]
	sub ecx, eax
	mov ebx,[gPciStructBuffer]
	shl eax, 8
	add ebx, eax
sehci_while_test:
	mov edx, 0x0020030C	  ; EHCI Class, SubClass and Version
	call PciQueryDevice
	cmp eax, -1
	jne sehci_while_do
; end_while------------------
	mov al, [ehcicount]
	test al,al
	jnz ehci_config_exit
	mov esi, boot_echidevicenotfound
	call Puts
	jmp StopSystem
ehci_init_error:
	mov esi, boot_ehcideviceiniterror
	call Puts
	jmp StopSystem
ehci_config_exit:
	jmp RunSystem
;==============================================================================
virtual at 0
V_ehcidescriptor EHCI_DESCRIPTOR
end virtual

RunSystem:
	call ClearScreen
testsystem:
	call SetCursorBegin
	mov esi, gEhciDescriptorBuffer
	mov eax, [esi+V_ehcidescriptor.pciConfigSpace]
	jmp ehci_handle_while_test
;**************************>>
ehci_handle_do:
	push esi
	mov eax, [esi+V_ehcidescriptor.ehciOpReg]
	mov eax, [eax+operacional2.command]
	call PrintDword
	mov eax, [esi+V_ehcidescriptor.ehciOpReg]
	mov eax, [eax+operacional2.status]
	call PrintDword
	mov eax, [esi+V_ehcidescriptor.ehciOpReg]
	mov eax, [eax+operacional2.asynclistadd]
	call PrintDword
	call NewLine80x25
	pop ebx
	call EhciISR
	add esi, sizeof.EHCI_DESCRIPTOR
	mov eax, [esi+V_ehcidescriptor.pciConfigSpace]
ehci_handle_while_test:
	test eax,eax
	jnz ehci_handle_do
;**************************>>
	hlt
	nop
	jmp testsystem
;--------------------------------------
StopSystem:
	hlt
	nop
	jmp StopSystem
;==============================================================================
;AUXILIAR CODE FOR 32 BITS MODE

include 'include\manager_memory.asm'
include 'include\manager_io.asm'
include 'driver\sys32.asm'
include 'driver\vesa12.asm'
include 'driver\pci32.asm'
include 'driver\ehci.asm'
include 'api32.inc'
;#############################################################################
; GLOBAL CONSTANTS AND VARIABLES
align 04h
include 'BootloaderVariables.inc'
include 'BootloaderData.inc'
;#############################################################################

sizeofcode = ($ - $$)

if sizeofcode > BootLoaderSize ; 16 KB
display 'code Greather than 16 KB'
err
end if

times (BootLoaderSize - ($-$$)) db 0
;----------------------------------
