;  32 bit pci driver for MyLo
;==================================================================
; DRIVER HEADER
pci_driver:
	pci_driver_Signature	   dd 'MYOS'
	pci_driver_DriverEntry	   dd EntryPoint_pci_driver-pci_driver
	pci_driver_ImageSize	   dd pci_driver_end-pci_driver
;==================================================================
virtual at 0
VPCI_H	PCI_HEADER_TYPE_0
end virtual

prev_device		dd 0
PCI_buffer		dd 0
PCI_deviceindex dd 0
PCI_deviceid	db 0
PCI_deviceCount dd 0
PCI_current_bus db 0

PCI_current_do	dd 0

;TODO: initialize the DeviceClass field
;==================================================================
; Pci Driver Entry Point
; ebx = Driver Object
EntryPoint_pci_driver:
	mov [ebx+VDDO.AddDevice], PciDriver_AddDevice_def
	mov [ebx+VDDO.RemoveDevice], PciDriver_RemoveDevice_def
	mov [ebx+VDDO.IORoutine], PciDriver_IORoutine_def
	mov [ebx+VDDO.DeviceControl], PciDriver_DeviceControl_def
	mov word [ebx+VDDO.DeviceType], SD_PCI_BUS
	mov dword [ebx+VDDO.DeviceClass], 00000006h
	mov word [ebx+VDDO.BusType], SD_ROOT_BUS
	xor eax,eax
	mov [ebx+VDDO.ReferenceCount], eax
	mov [ebx+VDDO.DeviceObject], eax
	ret
;==================================================================
;
PciDriver_IORoutine_def:


;==================================================================
; ebx = Device Object
; edx = Device Control Code
; ecx = IO buffer
; esi = Aditional information
PciDriver_DeviceControl_def:
	mov [PCI_current_do], ebx
	mov eax, edx
	and eax, 0ff000000h
	cmp eax, SD_USER_DEVICE_COMMAND
	je PciDriver_HUserDevCommand
	cmp eax, SD_SYSTEM_DEVICE_COMMAND
	je PciDriver_HSystemDeviceCommand
	jmp PciDriver_UnknowCommandCode
;----------------------------------
; SYSTEM DEVICE COMMAND
PciDriver_HSystemDeviceCommand:
	mov eax, edx
	cmp al, IOCC_INIT_DEVICE
		jne PciDriver_HSystemDeviceCommand2
		call PciDriver_ScanBus_def
		xor eax, eax
		ret
PciDriver_HSystemDeviceCommand2:
	jmp PciDriver_UnknowIOCommandCode
;------------------------------------------
;USER DEVICE COMMAND
PciDriver_HUserDevCommand:
	mov eax, edx
	cmp al, IOC_READ_CONFIGSPACE
	jne PciDriver_HUserDevCommand2
		mov ebx, ecx ; BufferAddress
		mov edx, esi ; Device Address
		call PciDriver_ReadDeviceConfigSpace_def
		ret
PciDriver_HUserDevCommand2:
	jmp PciDriver_UnknowIOCommandCode
;------------------------------------------
; UNKNOW COMMAND CODE
PciDriver_UnknowIOCommandCode:
	mov ebx,Error_no_io_command_code
	call  PrintK_def
	mov eax, -1
	ret
PciDriver_UnknowCommandCode:
	mov ebx,Error_no_command_code
	call  PrintK_def
	mov eax, -1
	ret
Error_no_command_code db 'Undefined System Command code',13,0
Error_no_io_command_code db 'Undefined IO Command code',13,0
	
;==================================================================
; ebx = Driver Object
; edx = Parent Bus Device Object
; ecx = DeviceId, DeviceVendor
; esi = Bus/Device/Function|Interface/0
; eax <= DeviceObject
PciDriver_AddDevice_def:
	push esi
; Checks if already exist a device object
;------------->
	mov esi, [ebx+VDDO.DeviceObject]
	jmp PciDriver_AddDevice_test_search_device
PciDriver_AddDevice_search_device:
	cmp dword [esi+VDO.DeviceVendor], ecx
	jz PciDriver_AddDevice_device_exist
	mov esi, [esi+VDO.NextDevice]
PciDriver_AddDevice_test_search_device:
	test esi,esi
	jnz PciDriver_AddDevice_search_device
;-------------<
	pop esi
	call IOCreateDevice_def
	mov edi, eax
; fill the Device Object
	mov word [edi+VDO.DeviceType], SD_PCI_HOST_BRIDGE
	mov word [edi+VDO.BusType], SD_ROOT_BUS
	mov dword [edi+VDO.DriverObject], ebx
	mov dword [edi+VDO.DeviceParent], edx
	mov dword [edi+VDO.DeviceId], ecx
	mov dword [edi+VDO.Address], esi	; saved as SLoader PCI Device Address - See Pci Header File
; attach the new device to Driver device list
	mov eax, [ebx+VDDO.DeviceObject]	; last device assigned
	mov [edi+VDO.NextDevice], eax
	mov [ebx+VDDO.DeviceObject], edi
	inc dword [ebx+VDDO.ReferenceCount]
	mov eax,edi
	ret
PciDriver_AddDevice_device_exist:
	mov esi, mylo_debug_device_exist
	call PrintK_def
	mov eax, -1
	ret
;==================================================================
; ebx = Driver Object
PciDriver_RemoveDevice_def:

	ret
;==================================================================
;	ebx = BufferAddress;
;	edx = Device Address
PciDriver_ReadDeviceConfigSpace_def:
	push ebx
	mov ebx, edx
	;Convert Device Address to PCI Device Address
	call MakePciAddress_def
	mov ecx, eax
	bts ecx, 31
	pop edi
	mov dx, PCI_CONFIG_ADDRESS
	mov eax,ecx
	out dx,eax
	mov dx, PCI_CONFIG_DATA
	in eax,dx
	cmp eax,0xffffffff
	jz rdcs_error_device_not_found
	cld
;copy PCI device space into a buffer
	;****************************
	rdcs_dataloop:
		cmp  cl,PCI_BLOCKINFOSIZE
		jae rdcs_exitdataloop
		mov eax,ecx
		mov dx,PCI_CONFIG_ADDRESS
		out dx,eax
		mov dx,PCI_CONFIG_DATA
		insd
		add cl,4 ; get four bytes from port and store in edi and increment edi
		jmp rdcs_dataloop
	;****************************
	rdcs_exitdataloop:
; convert the PCI device address to mylo pci device address -  See Pci header file
	xor eax, eax
	ret
rdcs_error_device_not_found:
	;mov eax, -1
	ret
;==================================================================
PciDriver_ScanBus_def:
	mov [PCI_current_bus], 0
	mov ebx, 2000h
	call AllocMemory_def
	push eax
	mov edi, eax
	mov edx, eax
	mov ecx, 2000h/4
	xor eax,eax
	rep stosd
	
	mov ebx, edx
	add edx, 2000h-400h
	push edx
	movzx ecx, byte [PCI_current_bus]
	call PciDriver_ScanPciBus_def
	pop edi	; device index buffer
	pop esi	; device structure buffer
	
	mov ecx, eax
	push dword 0	; Current PCI Header variable
	push dword 0	; Current Pci Device index (returned by PciDriver_ScanPciBus)
	push dword 0 	; Devices count
	xor eax, eax
;<<****** report each device to the IO Manager
repeat_report_devices:
	mov [esp], ecx
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
	push esi edi	; save pci header buffer and index buffer
	mov esi, [PCI_current_do]
	call IOReportDevice_def
	test eax,eax
	js repeat_test_report_devices
	mov ebx, eax
	mov edx, SD_SYSTEM_DEVICE_COMMAND+IOCC_INIT_DEVICE
	call IODeviceControl_def	
repeat_test_report_devices:
	pop edi esi
	add dword [esp+8], 100h
	add dword [esp+4], 4
	mov ecx, [esp]
	loop repeat_report_devices
;>>******
PciDriver_ScanBus_exit:
	add esp, 3*4	; restore stack
	ret
; =================================================================
; Scan the PCI bus searching for devices
; ebx = Device structure buffer
; edx = Device structure index buffer
; ecx = Bus Number
align 4

PciDriver_ScanPciBus_def:

	push esi edi

	mov [PCI_buffer], ebx
	mov [PCI_deviceindex], edx
	shl ecx, 16
	bts ecx, 31
	mov edx, ecx
	or edx, 08000ff00h	; test the dev/function from 0 to max ff. On bus defined on ecx
	mov [prev_device], 0ffffffffh
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
; convert the PCI device address to mylo pci device address -  See Pci header file
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
PciReadReg32_def:

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
;			                  / \     / \      / \   / \ / \	/ \
;			                 E	  Res	  Bus	  Dev	F    Reg    0
PciReadRegB_def:

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
PciReadRegD_def:

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
PciWriteRegB_def:
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
PciWriteRegW_def:
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
PciWriteRegD_def:
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
InitPCI_def:
	xor eax, eax; 0x80000000		; Bit 31 set for 'Enabled'
	bts eax, 31
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

PciQueryDevice_def:

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
; convert the MyLo Pci Device Address to Pci device Address.
; ebx =: bxh = bus, bxl = device, bh = func, bl = index
MakePciAddress_def:
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
