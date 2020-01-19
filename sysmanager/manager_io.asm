;##############################################################################
;				INPUT OUTPUT MANAGER
; Contain procedures for IO management on Mylo
; Joseph Dias, 2016@08.2019
;##############################################################################
; Internal functions
;	InitIOManager	- Init the Input Output Manager sctructures, buffers and variables
;	AllocDriverObject - Return a driver structure
;	AllocDeviceObject - Return a device structure
;	RegisterDrivers -
;	InitDeviceSystem -
; Imported Functions
;	AllocMemory
;	PrintK
; Exported functions
;	IODeviceConrol	- Send to device a Device Control Command
;	IOCreateDevice -
;	IOReportDevice - Used by Bus Drivers to report devices found on the bus.


virtual at 0
VDDO KERNEL_DEVICE_DRIVER_OBJECT
end virtual
virtual at 0
VDO KERNEL_DEVICE_OBJECT
end virtual

virtual at 0
MIOVDDO KERNEL_DEVICE_DRIVER_OBJECT
end virtual
virtual at 0
MIOVDO KERNEL_DEVICE_OBJECT
end virtual
;==============================================================================
InitIOManager_def:
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
	call AllocMemory_def
	mov [gKernelDriverObjectPool], eax
	mov edi, eax
	xor eax, eax
	mov ecx, 2000h/64
	mov [gKDriverOPsize], ecx
	rep stosd
;allocate and clear a buffer to hold Devices's structures
	mov ebx, 2000h
	call AllocMemory_def
	mov [gKernelDeviceObjectPool], eax
	mov edi, eax
	xor eax,eax
	mov ecx, 2000h/64
	mov [gKDeviceOPsize], ecx
	rep stosd
	call RegisterDrivers_def
	call InitDeviceSystem_def
	ret
;==============================================================================
InitDeviceSystem_def:
; Call the System Root Bus Driver to scan pci buses

;search for a Root Bus Driver
	mov esi, [gKernelDriverObjectPool]
	mov ecx, [gKDriverOPsize]
;****>>
search_root_bus_driver:
	mov ax, [esi+MIOVDDO.DeviceType]
	cmp ax, SD_SYSTEM_ROOT_BUS
	jz root_bus_driver_found
	add esi, sizeof.KERNEL_DEVICE_DRIVER_OBJECT
	loop search_root_bus_driver
;****<<
	mov ebx, kiom_root_bus_driver_not_found
	call PrintK_def
	or eax, -1
	jmp exit_InitDeviceSystem
root_bus_driver_found:
	mov edx, SD_SYSTEM_DEVICE_COMMAND+IOCC_INIT_DEVICE
	mov eax, [esi+MIOVDDO.DeviceControl]
	call eax

exit_InitDeviceSystem:
	ret
;==============================================================================
; Register all Drivers from DriverList on System
RegisterDrivers_def:
	lea esi, [gKernelDriverList]
loop_load_drivers:
	lodsd
	test eax, eax
	jz exit_register_drivers
	push eax
	call AllocDriverObject_def
	mov ebx, eax
	pop eax
	mov [ebx], eax
	mov edx, eax
	add edx, [eax+4]
	; ebx = DriverObject
	call edx	; call the driver entry
	jmp loop_load_drivers
exit_register_drivers:
	ret
;==============================================================================
AllocDriverObject_def:
	push esi ecx
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
	pop ecx esi
	ret
;==============================================================================
AllocDeviceObject_def: 
	push ebx edx ecx esi
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
	shl eax, 6 ; eax*64 ( get the DeviceObject offset)
	add eax, [gKernelDeviceObjectPool]
	jmp exit_alloc_device_object
no_device_object:
	mov eax, -1
exit_alloc_device_object:
	pop esi ecx edx ebx
	ret
;==============================================================================
; Alloc and return a Device Object
; eax <- DeviceObject
IOCreateDevice_def:
	
	call AllocDeviceObject_def
	ret
;==============================================================================
; Send a device control command
; ebx = Device Object
; edx = Control Code
; ecx = input/output buffer
IODeviceControl_def:
	mov eax, [ebx+MIOVDO.DriverObject]
	mov eax, [eax+MIOVDDO.DeviceControl]
	call eax
	ret
;==============================================================================
;Description: Used by Bus Drivers to report a device found on the bus.

; ebx = Bus, Device, Function/Interface, BusType
; edx = RevisionID,ProgIF,SubClass,ClassCode
; ecx = DeviceID, VendorID
; esi = Parent Bus Device Object
IOReportDevice_def:	

	push ebx
	push esi
	push ecx
	
	mov ecx, [gKDriverOPsize]
	movzx eax, bl
	mov esi, [gKernelDriverObjectPool]
	and edx, 00ffffffh ; Filter RevisionID, need to match Device Driver Class field
; esi = Driver Object address
;**************************>>
repeat_match_bus_driver_mdd:
	cmp word [esi+MIOVDDO.BusType], ax
	jz match_dd_class_mdd
	jmp match_next_driver
match_dd_class_mdd:
	cmp edx, [esi+MIOVDDO.DeviceClass]
	jz device_driver_match_mdd
match_next_driver:
	add esi, sizeof.KERNEL_DEVICE_DRIVER_OBJECT
	loop repeat_match_bus_driver_mdd
	add esp, 3*4
	;TODO: remove debug message
	push edx
	mov ebx, mylo_debug_drive_not_found
	call PrintK_def
	pop ebx
	call PrintDword_def
	mov eax, -1
	ret
;**************************<<
device_driver_match_mdd:
	pop ecx			; DeviceID, DeviceVendor
	pop edx 		; Parent Bus Device Object
	mov ebx, esi	; Device Driver Object
	pop esi 		
	and esi, 0ffffff00h ; Bus, Device, Function/Interface, 0
	mov eax, [ebx+MIOVDDO.AddDevice]
	call eax	;return device object or error code
	ret
;==============================================================================