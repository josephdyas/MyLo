;##############################################################################
;
;  rootbus.asm
; 32 bit Root Bus driver for Mylo
; Functions
; =============================================================================
; DRIVER HEADER
rootbus_driver:
	rootbus_driver_Signature       dd 'MYOS'
	rootbus_driver_DriverEntry     dd EntryPoint_rootbus_driver-rootbus_driver
	rootbus_driver_ImageSize       dd rootbus_driver_end-rootbus_driver
;==================================================================

virtual at 0
VPCI_H1	PCI_HEADER_TYPE_1
end virtual

rootBusPCIBuffer db 100h dup(0)
root_bus_prev_device dd 0
;==================================================================
; Pci Driver Entry Point
; ebx = Driver Objetct
EntryPoint_rootbus_driver:

	mov dword [ebx+VDDO.AddDevice], RootBusDriver_AddDevice
	mov [ebx+VDDO.IORoutine], RootBusDriver_IORoutine
	mov [ebx+VDDO.DeviceControl], RootBusDriver_DeviceControl
	mov [ebx+VDDO.RemoveDevice], RootBusDriver_RemoveDevice
	mov dword [ebx+VDDO.DeviceObject], 0
	mov word [ebx+VDDO.DeviceType], SD_SYSTEM_ROOT_BUS
	mov word [ebx+VDDO.BusType], SD_ROOT_BUS
	ret
;==================================================================
; ebx = Driver Object
; edx = Parent Bus Device Object
; ecx = Bus, Device, Function/Interface
RootBusDriver_AddDevice:

	ret
;==================================================================
; ebx = Driver Objetct
RootBusDriver_RemoveDevice:

	ret
;==================================================================
;
RootBusDriver_IORoutine:


;==================================================================
; ebx = Device Object
; edx = Device Control Code
; ecx = inpurt output buffer
RootBusDriver_DeviceControl:

	mov eax, edx
	and eax, 0ff000000h
	cmp eax, SD_SYSTEM_DEVICE_CONTROL
	je RootBusDriver_HSystemDeviceControl
	cmp eax, SD_DEVICE_CONTROL
	je RootBusDriver_HDevControl
	jmp RootBusDriver_UnknowControlCode
RootBusDriver_HSystemDeviceControl:
	mov eax, edx
	cmp al, IO_CONTROL_COMMAND_INIT_DEVICE
	je RootBusDriver_HScanBus
	jmp RootBusDriver_UnknowControlCode

RootBusDriver_HDevControl:
	mov eax, ebx
	shr eax, 8
	cmp al, 0
; TODO
	jmp RootBusDriver_UnknowControlCode
RootBusDriver_HScanBus:
	call RootBusDriver_ScanBus
	xor eax,eax
	ret
RootBusDriver_UnknowControlCode:
	mov eax, -1
	ret
;==================================================================
; Search Main System buses and Devices
RootBusDriver_ScanBus:
	xor edx,edx
	or edx, 0x8000ff00
	mov [root_bus_prev_device], 0fffffffh
	xor ecx,ecx
	bts ecx, 31
;****************************
root_bus_pciscanloop:
	cmp ecx,edx
	jae root_bus_no_pci_host
	push edx
	mov dx,PCI_CONFIG_ADDRESS
	mov eax,ecx
	out dx,eax
	mov dx,PCI_CONFIG_DATA
	in eax,dx
	cmp eax, dword [root_bus_prev_device]
	jnz root_bus_pciscancontinue
	 add ecx,100h
	 pop edx
	 jmp root_bus_pciscanloop
  root_bus_pciscancontinue:
      mov [root_bus_prev_device],eax
      mov ebx,eax
      cmp eax,0xffffffff ; test if exist a device
      jz root_bus_pciscanexitgetdata
	push ecx
	mov edi,rootBusPCIBuffer
	cld
;copy PCI device space into a buffer
	  ;****************************
	    root_bus_dataloop:
			cmp  cl,PCI_BLOCKINFOSIZE
			jae root_bus_dataloop_exit
			mov eax,ecx
			mov dx,PCI_CONFIG_ADDRESS
			out dx,eax
			mov dx,PCI_CONFIG_DATA
			insd
			add cl,4 ; get four bytes from port and store in edi and increment edi
			jmp root_bus_dataloop
	  ;****************************
	  root_bus_dataloop_exit:
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
	mov ebx, eax
	pop ecx
	pop edx
	jmp exit_root_bus_get_pci
root_bus_pciscanexitgetdata:
	pop edx
	add ecx,100h ; next device to scan
	jmp root_bus_pciscanloop
;****************************
root_bus_no_pci_host:
	add esp, 4
	mov ebx, kiom_root_bus_pci_host_not_found
	call PrintK
	mov eax, -1
	jmp RootBusDriver_ScanBus_exit
exit_root_bus_get_pci:	
	mov edi, rootBusPCIBuffer
	mov bl, SD_ROOT_BUS	; bus type
;Function/Interface, Device, Bus, BusType
;swap ebx( ABCD -> DCBA)
	xchg bh, bl
	ror ebx, 16
	xchg bh, bl
	; mov BusType to bl
	rol ebx, 8
	mov edx, dword [edi+VPCI_H1.RevisionID]
; RevisionID, ProgIF/Protocol, SubClass, ClassCode
;swap edx( ABCD -> DCBA)
	xchg dh, dl
	ror edx, 16
	xchg dh, dl
;VendorID, DeviceID
	mov ecx, dword [edi+VPCI_H1.VendorID]
	xor esi, esi	; empty Parent Device Object (Root Bus)
	call IOReportDevice
	test eax, eax
	js root_bus_driver_pci_report_error
	mov ebx, eax
	mov edx, SD_SYSTEM_DEVICE_CONTROL+IO_CONTROL_COMMAND_INIT_DEVICE
	call IODeviceControl
	jmp RootBusDriver_ScanBus_exit
root_bus_driver_pci_report_error:
	mov ebx, kiom_root_bus_pci_report_error
	call PrintK
	mov eax, -1
RootBusDriver_ScanBus_exit:
	ret
;==================================================================
rootbus_driver_end: