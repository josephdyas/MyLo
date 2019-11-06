;===============================================================================
; BootLoader variables and structures

;======================
;DAP structure      ; DAP is a structure used by the int13 to read and write a disk
;DAP to read FAT
dap      db 16      ; size of the struct  16 bytes
zr       db 0       ; should be 0
secread  dw 0       ; number of sector to be read
bufferf  dw 0       ; offset of the destination buffer
buffers  dw 0       ; segment of the destination buffer
absolute dq 0       ; absolute number of the start of the sectors to be read (1st sector of drive has number 0)

;=============================================
EBDAseg         dw 0              ; segment of the EBDA
dsdtoff         dw 0              ;
buffer          db 100h dup(?)    ;
cursorpsr       db 0
cursorpsc       db 0
charcolor       db 0x0f         ; characters color
charcolorback   db 0x0f ; background color
logoline        dw 1
logolines       dw 0
;=============================================
; variables used by FileSystem
directoryentry dw ?               ; address of the directory entry on directory
FATentry       dw ?
Firstclusterab dw ?
FILENAME       db 13 dup(0)
FILENAMES      db 13 dup(0)
filesize       dw ?          ; in sectors
loadsize       dw ?
loaddirectory  db 0
loadbuffers    dw ?
loadbufferf    dw ?
filebuffers    dw ?
filebufferf    dw ?
nextname       dw ?
segmentcount   dw ?         ; used to count the numbers of cluster were read
currentcluster dw ?
;--------------------------------------------------
; Directory entry struct   FAT32
DIRENTRYS:
DIR_Name           db 11 dup(0)
DIR_Attr           db ?
DIR_NTRes          db ?
DIR_CrtTimeTenth   db ?
DIR_CrtTime        dw ? ; creation time
DIR_CrtDate        dw ? ; creation date
DIR_LstAccDate     dw ? ; last access date
DIR_FstClusHI      dw ? ; high word of the entry's first cluster
DIR_WrtTime        dw ? ; time of last write
DIR_WrtDate        dw ? ; date of last write
DIR_FstClusLO      dw ? ; low word of this entry's first cluster
DIR_FileSize       dd ? ;32-bit word holding the file size
;=============================================================
; used by Memory Detect code
e820entry:
mmap_BaseAddrLow    dd ?   ; Low 32 Bits of Base Address
mmap_BaseAddrHigh   dd ?   ; High 32 Bits of Base Address
mmap_LengthLow      dd ?   ; Low 32 Bits of Length in Bytes
mmap_LengthHigh     dd ?   ; High 32 Bits of Length in Bytes
mmap_Type           dd ?   ; Address type of  this range.
mmap_TypeExt        dd ?   ; ACPI 3.0 Extended Attributes bitfield
;=============================================================
; GDT TABLE
align 4
gdt_descriptor:
; first gdt entry - not used
; the first gdt entry is not used by processor, so can be used to hold
; the gdt size and address for use in lgdt, and hold the idt size
; the idt cames after the gdt and tss segment after the idt
; thus, the address of the tss is the gdt size plus idt size.
; the gdt is loaded at the memory begin.
        dw     GDT_DESCRIPTOR_END-gdt_descriptor-1     ; size of the gdt
        dd     gdt_descriptor         ; address of gdt
        dw     0x0000
; code segment for os code
os_code_l:

        dw     0xffff
        dw     0x0000
        db     0x00
        dw     11011111b *256 +10011010b  ; multiply by 256 mov the byte
        db     0x00                       ; for high byte word
;data segment for os code
os_data_l:

        dw     0xffff
        dw     0x0000
        db     0x00
        dw     11011111b *256 +10010010b
        db     0x00
; code segment for user
user_code_l:

        dw     0xffff
        dw     0x0000
        db     0x00
        dw     11011111b *256 +11111010b
        db     0x00
; data segment for user
user_data_l:

        dw     0xffff
        dw     0x0000
        db     0x00
        dw     11011111b *256 +11110010b
        db     0x00
;task state segment for os
tss_l:
        dw     TSSE-TSSS-1       ;size of the structure
        dw     0x0000         ; address
        db     0x00          ; address
        dw     00010000b *256 +10001001b
        db     0x0000          ; address

GDT_DESCRIPTOR_END:
; Task state segment struct
TSSS:
tss.back   dw 0,0
tss.esp0   dd 0x58fff
tss.ss0    dw os_data,os_data
tss.esp1   dd 0
tss.ss1    dw 0,0
tss.esp2   dd 0
tss.ss2    dw 0,0
tss.cr3    dd 0
tss.eip    dd 0
tss.eflags dd 0
tss.eax    dd 0
tss.ecx    dd 0
tss.edx    dd 0
tss.ebx    dd 0
tss.esp    dd 0
tss.ebp    dd 0
tss.esi    dd 0
tss.edi    dd 0
tss.es     dw 0,0
tss.cs     dw 0,0
tss.ss     dw 0,0
tss.ds     dw 0,0
tss.fs     dw 0,0
tss.gs     dw 0,0
tss.ldt    dw 0,0
tss.trap   dw 0
tss.io     dw TSSE-TSSS
TSSE:
;=============================================================
; IDT descriptor values is set at run time
align 4
idt_descriptor:
      dw  0x0000         ; size of IDT - 1
      dd  0x00000000     ; IDT address
      dw  0x0000
IDTE:
;#############################################################################
;Enhanced Host Controller - EHCI and USB
align 32
getDeviceDescriptorCmd  db 80h,06h,00h,01h,00h,00h,12h,00h
setDeviceAddressCmd     db 00h,05h,00h,00h,00h,00h,00h,00h

gEhciDescriptorBuffer db sizeof.EHCI_DESCRIPTOR*8 dup(0)
;#############################################################################
; Memory Management
; set the Block Chain address
virtual at BLOCK_CHAIN_ADDRESS
G_bc BLOCK_CHAIN
end virtual
;create the BlockList and fill with BlockChain address
G_BlockList BLOCK_LIST <G_bc._4KB,-1>,<G_bc._8KB,-1>,<G_bc._16KB,-1>,<G_bc._32KB,-1>,<G_bc._64KB,-1>,<G_bc._128KB,-1>,<G_bc._256KB,-1>,<G_bc._512KB,-1>
;#############################################################################
; Input Output Management
gKDriverOPsize	dd ?	; size of driver object pool in DriverObject entries
gKDeviceOPsize	dd ?
gKernelDriverObjectPool dd ?
gKernelDeviceObjectPool dd ?
gKernelDriverObjectBitmap db 16 dup (0)
gKernelDeviceObjectBitmap db 16 dup (0)
; contain the list of address of the drivers
gKernelDriverList	dd pci_driver
					dd ehci_driver
					dd 0
					dd 0
					dd 0
					dd 0
					dd 0
;#############################################################################
; Peripheral Comunication Inferface - PCI
gPciStructBuffer dd ?
gPciDeviceCount dd ?
gPciDeviceIndex db 256 dup(?)
