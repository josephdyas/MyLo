;  32 bit pci driver for MyLo
;==================================================================
; DRIVER HEADER
pci_driver:
	Signature	dd 'MYOS'
	DriverEntry	dd EntryPoint_pci_driver-pci_driver
	ImageSize	dd pci_driver_end-pci_driver
;==================================================================
virtual at 0
VDDO KERNEL_DEVICE_DRIVER_OBJECT
end virtual
virtual at 0
VDO KERN_DEVICE_OBJECT
virtual at 0
VPCI_H	PCI_HEADER_TYPE_0
end virtual

prev_device		dd 0
PCI_buffer		dd 0
PCI_deviceindex	dd 0
PCI_deviceid	db 0
PCI_deviceCount	dd 0
PCI_current_bus	db 

;TODO: initialize the DeviceClass field
;==================================================================
; Pci Driver Entry Point
; ebx = Driver Objetct
EntryPoint_pci_driver:

	mov [ebx+VDDO.AddDevice], PciDriver_AddDevice
	mov [ebx+VDDO.RemoveDevice], PciDriver_RemoveDevice 
	mov [ebx+VDDO.ScanBus], PciDriver_ScanBus
	mov dword [ebx+VDDO.DeviceObject], 0
	mov word [ebx+VDDO.DeviceType], SD_PCI_BUS
	mov word [ebx+VDDO.BusType], SD_ROOT_BUS

	ret
;==================================================================
; ebx = Driver Object
; edx = Parent Bus Device Object
; ecx = Bus, Device, Function/Interface
PciDriver_AddDevice:

	call IOCreateDevice
	mov edi, eax
; fill the Device Object
	mov word [edi+VDO.DeviceType], SD_PCI_HOST_BRIDGE
	mov word [edi+VDO.BusType], SD_ROOT_BUS
	mov dword [edi+VDO.DriverObject], ebx
	mov dword [edi+VDO.DeviceParent], edx
	mov dword [edi+VDO.Address], ecx
; attach the new device to Driver device list
	mov eax, [ebx+VDDO.DeviceObject]
	mov [edi+VDO.NextDevice], eax
	mov [ebx+VDDO.DeviceObject], edi

	ret
;==================================================================
; ebx = Driver Objetct
PciDriver_RemoveDevice:

	ret
;==================================================================
PciDriver_ScanBus:

	mov [PCI_current_bus], 0
	mov ebx, 2000h
	call AllocMemory
	push eax
	mov ebx, eax
	add eax, 2000h-400h
	mov edx, eax
	push edx
	movzx ecx, byte [PCI_current_bus]
	call PciDriver_ScanPciBus
	pop edi
	pop esi
	mov ecx, eax
	push dword 0	; Current PCI Header variable
	push dword 0	; Current Pci Device index (returned by PciDriver_ScanPciBus)
	xor eax, eax
;<<****** report each device to the IO Manager
repeat_report_devices:
	push ecx	; save device counter
	mov eax, [esp+4]
	mov ebx, [edi+eax]
	mov bl, SD_PCI_BUS	; bus type
;Function/Interface, Device, Bus, BusType
;swap ebx( ABCD -> DCBA)
	xchg bh, bl
	ror ebx, 16
	xchg bh, bl
	; mov BusType to bl
	rol ebx, 8
	mov eax, [esp+8]
	mov edx, dword [esi+eax+VPCI_H.RevisionID]
; RevisionID, ProgIF/Protocol, SubClass, ClassCode
;swap edx( ABCD -> DCBA)
	xchg dh, dl
	ror edx, 16
	xchg dh, dl
;VendorID, DeviceID
	mov ecx, dword [esi+eax+VPCI_H.VendorID]
	call IOReportDevice
	add dword [esp+4], 4
	add dword [esp+8], 100h
	pop ecx
	loop repeat_report_devices
;>>******
	add esp, 2*4	; restore stack
	ret
; =================================================================
; Scan the PCI bus searching for devices
; ebx = Device structure buffer
; edx = Device structure index buffer
; ecx = Bus Number
align 4

PciDriver_ScanPciBus:

	push esi edi

	mov [PCI_buffer], ebx
	mov [PCI_deviceindex], edx
	shl ecx, 16
	bts ecx, 31
	mov edx, ecx
	or edx, 0x8000ff00
	mov [prev_device], edx
;****************************
pciscanloop:
	cmp ecx,edx
	jae pciscanexit
	push edx
	mov dx,PCI_CONFIG_ADDRESS
	mov eax,ecx
	out dx,eax
	mov dx,PCI_CONFIG_DATA
	in eax,dx
	cmp eax, dword [prev_device]
	jnz pciscancontinue
	 add ecx,100h
	 pop edx
	 jmp pciscanloop
  pciscancontinue:
      mov [prev_device],eax
      mov ebx,eax
      cmp eax,0xffffffff ; test if exist a device
      jz pciscanexitgetdata
	push ecx
	mov edi,[PCI_buffer]
	cld
;copy PCI device space into a buffer
	  ;****************************
	    dataloop:
			cmp  cl,PCI_BLOCKINFOSIZE
			jae exitdataloop
			mov eax,ecx
			mov dx,PCI_CONFIG_ADDRESS
			out dx,eax
			mov dx,PCI_CONFIG_DATA
			insd
			add cl,4 ; get four bytes from port and store in edi and increment edi
			jmp dataloop
	  ;****************************
	    exitdataloop:
; convert the PCI device address to mylo pci device address
	    mov ebx,ecx
	    and ecx,PCI_BUS_MASK
	    mov eax,ecx ; Bus number
	    mov ecx,ebx
	    shr ecx,PCI_FUNCTION_OFFSET
	    and ecx,0x07
	    mov al,cl ; Function
	    shr ebx,PCI_DEVICE_OFFSET
	    and ebx,0x1f
	    mov ah,bl ; device number
	    shl eax,8
	    mov al,[PCI_deviceid]
	    mov ecx,[PCI_deviceindex]
	    mov dword [ecx],eax
	    add [PCI_deviceindex],4
	  pop ecx
	  mov eax,ecx
	  add [PCI_buffer],100h ; next device on buffer
	  inc byte [PCI_deviceid] ; next device index
	  inc [PCI_deviceCount] ; count the number of devices found
	pciscanexitgetdata:
	pop edx
	add ecx,100h ; next device to scan
 jmp pciscanloop
;****************************
pciscanexit:
      mov eax,[PCI_deviceCount]
      pop edi esi
      ret
;==================================================================

align 4
; -----------------------------------------------------------------
; os_pci_read_reg -- Read from a register on a PCI device
;  IN:	BL  = Bus number
;	CL  = Device/Slot/Function number
;	DL  = Register number (0-15)
; OUT:	EAX = Register information
;	All other registers preserved
PciReadReg32:

	shl ebx, 16			; Move Bus number to bits 23 - 16
	shl ecx, 8			; Move Device/Slot/Fuction number to bits 15 - 8
	mov bx, cx
	shl edx, 2
	mov bl, dl
	and ebx, 0x00ffffff		; Clear bits 31 - 24
	or ebx, 0x80000000		; Set bit 31
	mov eax, ebx
	mov dx, PCI_CONFIG_ADDRESS
	out dx, eax
	mov dx, PCI_CONFIG_DATA
	in eax, dx

	ret
; -----------------------------------------------------------------
; ebx = PCI Device address dd 0|0000000|00000000|00000|000|000000|00b
;			      / \     / \      / \   / \ / \	/ \
;			     E	  Res	  Bus	  Dev	F    Reg    0
PciReadRegB:

	or ebx, 0x80000000		; Set bit 31
	mov eax, ebx
	and al, 0xfc
	mov dx, PCI_CONFIG_ADDRESS
	out dx, eax
	mov dx, PCI_CONFIG_DATA
	and bl, 11b
	or  dl, bl
	xor eax,eax
	in al, dx

	ret
;------------------------------------------------------------------
;						 bh	   bl
; ebx = PCI Device address dd 0|0000000|00000000|00000|000|000000|00b
;			      / \     / \      / \   / \ / \	/ \
;			     E	  Res	  Bus	  Dev	F    Reg    0
PciReadRegD:

	or ebx, 080000000h		; Set bit 31
	mov eax, ebx
	mov dx, PCI_CONFIG_ADDRESS
	out dx, eax
	mov dx, PCI_CONFIG_DATA
	in eax, dx

	ret
;==================================================================
; ebx = PCI Device address
; edx = data
PciWriteRegB:
	push edx
	or ebx, 080000000h		; Set bit 31
	mov eax, ebx
	and al, 0fch
	mov dx, PCI_CONFIG_ADDRESS
	out dx, eax
	pop eax
	mov dx, PCI_CONFIG_DATA
	and bl, 11b
	or  dl, bl
	out dx, al

	ret
;------------------------------------------------------------------
PciWriteRegW:
	push edx
	or ebx, 080000000h		; Set bit 31
	mov eax, ebx
	and al, 0fch
	mov dx, PCI_CONFIG_ADDRESS
	out dx, eax
	pop eax
	mov dx, PCI_CONFIG_DATA
	and bl, 11b
	or  dl, bl
	out dx, ax
	ret
;==================================================================
; ebx = PCI Device address
; edx = data
PciWriteRegD:
	push edx
	or ebx, 0x80000000		; Set bit 31
	mov eax, ebx
	mov dx, PCI_CONFIG_ADDRESS
	out dx, eax
	pop eax
	mov dx, PCI_CONFIG_DATA
	out dx, eax
	ret
;==================================================================
InitPCI:
	mov eax, 0x80000000		; Bit 31 set for 'Enabled'
	mov ebx, eax
	mov dx, PCI_CONFIG_ADDRESS
	out dx, eax
	in eax, dx
	xor edx, edx
	cmp eax, ebx
	sete dl 			; Set byte if equal, otherwise clear
       ; mov byte [os_PCIEnabled], dl
	ret
;==================================================================
; Search and return a index into PCI device buffer (returned by ScanPCIBus)
; of desired device.
; ebx = device address buffer
; edx =: dl = class, dh = subclass, dxl = ProgIF, dxh = RevisionID
; ecx = max number of devices
virtual at 0
	pci32_pciehci PCI_HEADER_TYPE_0
end virtual

PciQueryDevice:

	push esi
	push edi
;---------------------------------------
	test ecx,ecx
	jnz search_pci_device
	mov eax, -1
	jmp pqdc_exit
search_pci_device:
	push ebx
	mov esi, ebx
	mov ebx, edx
	shr ebx, 16
	jmp pqdc_while_test
;While ******************************>>
pqdc_loop_search_device:
	mov al, byte [esi+pci32_pciehci.ClassCode]
	cmp al, dl
	jnz pqdc_get_next_pci
	mov al, byte [esi+pci32_pciehci.SubClass]
	cmp al, dh
	jnz pqdc_get_next_pci
	mov al, byte [esi+pci32_pciehci.ProgIF]
	cmp al, bl
	jz pqdc_device_found
pqdc_get_next_pci:		
	dec ecx
	add esi, 0x100
pqdc_while_test:
	cmp ecx, 0
	jg pqdc_loop_search_device
;************************************<<
pqdc_device_not_found:
	pop ebx
	mov eax, -1
	jmp pqdc_exit
;$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
pqdc_device_found:
	pop ebx
	sub esi, ebx
	shr esi, 8		; Device address buffer to device index (zero based)  
	mov eax, esi
pqdc_exit:
	pop edi
	pop esi
	ret
;==================================================================
; ebx =: bxh = bus, bxl = device, bh = func, bl = index
MakePciAddress:

	shr ebx, 8
	mov eax, ebx
	shl bh, 3
	and eax, 111b
	or bh, al
	xor bl,bl
	mov eax, ebx
	ret
;==================================================================
pci_driver_end:
