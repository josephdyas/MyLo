;##############################################################################
;
;  rootbus.asm
; 32 bit Root Bus driver for Mylo
; Functions
; =============================================================================
; DRIVER HEADER
rootbus_driver:
	Signature	dd 'MYOS'
	DriverEntry	dd EntryPoint_rootbus_driver-rootbus_driver
	ImageSize	dd rootbus_driver_end-rootbus_driver
;==================================================================
virtual at 0
VDDO KERNEL_DEVICE_DRIVER_OBJECT
end virtual

rootBusPCIBuffer db 100h dup(0)
;==================================================================
; Pci Driver Entry Point
; ebx = Driver Objetct
EntryPoint_rootbus_driver:

	mov dword [ebx+VDO.AddDevice], RootBusDriver_AddDevice
	mov [ebx+VDO.RemoveDevice], RootBusDriver_RemoveDevice
	mov [ebx+VDO.ScanBus], RootBusDriver_ScanBus
	mov dword [ebx+VDO.DeviceObject], 0
	mov word [ebx+VDO.DeviceType], SD_SYSTEM_ROOT_BUS
	mov word [ebx+VDO.BusType], SD_ROOT_BUS
	
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
; Search Main System buses and Devices
; ebx = Device Object
RootBusDriver_ScanBus:
	push ebx
;Search the PCI HOST CONTROLLER
	mov dx,PCI_CONFIG_ADDRESS
	mov eax,ecx
	out dx,eax
	mov dx,PCI_CONFIG_DATA
	in eax,dx
      mov ebx,eax
      cmp eax,0xffffffff ; test if exist a device
      jz root_bus_no_pci_host
	push ecx
	mov edi, rootBusPCIBuffer
	cld
;copy PCI device space into a buffer
	  ;****************************
	    root_bus_dataloop:
			cmp  cl,PCI_BLOCKINFOSIZE
			jae exit_root_bus_get_pci
			mov eax,ecx
			mov dx,PCI_CONFIG_ADDRESS
			out dx,eax
			mov dx,PCI_CONFIG_DATA
			insd
			add cl,4 ; get four bytes from port and store in edi and increment edi
			jmp root_bus_dataloop
	  ;****************************
root_bus_no_pci_host:


exit_root_bus_get_pci:
	mov bl, SD_ROOT_BUS	; bus type
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
	pop esi ; restore Device Object
	call IOReportDevice

	ret
;==================================================================
rootbus_driver_end: