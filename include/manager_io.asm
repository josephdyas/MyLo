;##############################################################################
;				INPUT OUTPUT MANAGER
; Contain procedures for IO management on Mylo
; joseph dias, 2016@08.2019
;##############################################################################
; Internal functions
;	InitIOManager	- Init the Input Output Manager sctructures, buffers and variables
;	AllocDriverObject - Return a driver structure
;	AllocDeviceObject -
;	RegisterDrivers - 
;	InitDeviceSystem -
; Imported Functions
;	AllocMemory
;	PrintK
; Exported functions
;	CreateDeviceObject -
;	MatchDeviceDriver -

virtual at 0
MIOVDDO KERNEL_DEVICE_DRIVER_OBJECT
end virtual
;==============================================================================
InitIOManager:
;clear the DriverObject bitmap
	mov edi, gKernelDriverObjectBitmap
	xor eax,eax
	mov ecx, 16/4
	rep stosd
;clear the Deviceobject bitmap
	mov edi,gKernelDeviceObjectBitmap 
	xor eax,eax
	mov ecx, 16/4
	rep stosd
; alloc and clear a buffer to hold Driver's structures 
	mov ebx, 2000h
	call AllocMemory
	mov [gKernelDriverObjectPool], eax
	mov edi, eax
	xor eax,eax
	mov ecx, 2000h/64
	mov [gKDriverOPsize], ecx
	rep stosd
;allocate and clear a buffer to hold Devices's structures
	mov ebx, 2000h
	call AllocMemory
	mov [gKernelDeviceObjectPool], eax
	mov edi, eax
	xor eax,eax
	mov ecx, 2000h/64
	mov [gKDeviceOPsize], ecx
	rep stosd
	call InitDeviceSystem
	ret
;==============================================================================
InitDeviceSystem:
	call RegisterDrivers
;search a PCI Bus Driver
	mov esi, [gKernelDriverObjectPool]
	mov ecx, [gKDriverOPsize]
;****>>
search_pci_bus_driver:
	mov ax, [esi+MIOVDDO.DeviceType]
	cmp ax, SD_PCI_BUS
	jz pci_bus_driver_found
	add esi, sizeof.KERNEL_DEVICE_DRIVER_OBJECT
	loop search_pci_bus_driver
;****<<
	mov ebx, kiom_pci_bus_driver_not_found
	call PrintK
	or eax, -1
	jmp exit_InitDeviceSystem
pci_bus_driver_found:
	mov eax, [esi+MIOVDDO.ScanBus]
	call eax

exit_InitDeviceSystem:
	ret
;==============================================================================
; Register all Drivers from DriverList on System
RegisterDrivers:
	lea esi, [gKernelDriverList]
loop_load_drivers:
	lodsd
	test eax, eax
	jz exit_retister_drivers
	push eax
	call AllocDriverObject
	mov ebx, eax
	pop eax
	mov [ebx], eax
	mov edx, eax
	add edx, [eax+4]
	; ebx = DriverObject
	call edx	; call the driver entry
	jmp loop_load_drivers
exit_retister_drivers:
	ret
;==============================================================================
AllocDriverObject: 
	lea esi, [gKernelDriverObjectBitmap]
	lodsd
	xor ecx,ecx
repeat_search_driver_object:
	cmp eax, -1
	jnz get_driver_object	; test if all bits are 1`s
	cmp cl, 4
	jz no_driver_object
	inc ecx
	lodsd
	jmp repeat_search_driver_object
get_driver_object:
	push ecx
	push eax	
	xor ecx,ecx
loop_get_driver_object:
	shr eax, 1
	jnc return_driver_object
	inc ecx
	jmp loop_get_driver_object
return_driver_object:
	pop eax
	bts eax, ecx
	mov [esi-4], eax ; save back the bitmap with the bit allocated
	pop eax
	shl eax, 5 ; eax*32 ( get the bit offset into 16 bytes array)
	add eax, ecx
	shl eax, 6 ; eax*64 ( get the DriverObject offset)
	add eax, [gKernelDriverObjectPool]
	jmp exit_alloc_driver_object
no_driver_object:
	mov eax, -1
exit_alloc_driver_object:
	ret
;==============================================================================
AllocDeviceObject: 
	lea esi, [gKernelDeviceObjectBitmap]
	lodsd
	xor ecx,ecx
repeat_search_device_object:
	cmp eax, -1
	jnz get_device_object	; test if all bits are 1`s
	cmp cl, 4
	jz no_device_object
	inc ecx
	lodsd
	jmp repeat_search_device_object
get_device_object:
	push ecx
	push eax	
	xor ecx,ecx
loop_get_device_object:
	shr eax, 1
	jnc return_device_object
	inc ecx
	jmp loop_get_device_object
return_device_object:
	pop eax
	bts eax, ecx
	mov [esi-4], eax ; save back the bitmap with the bit allocated
	pop eax
	shl eax, 5 ; eax*32 ( get the bit offset into 16 bytes array)
	add eax, ecx
	shl eax, 6 ; eax*64 ( get the DriverObject offset)
	add eax, [gKernelDeviceObjectPool] 
	jmp exit_alloc_device_object
no_device_object:
	mov eax, -1
exit_alloc_device_object:
	ret
;==============================================================================
;
CreateDeviceObject:

	ret
;==============================================================================


;==============================================================================