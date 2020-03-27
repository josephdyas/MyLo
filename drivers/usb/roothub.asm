;  32 bit driver for MyLo
;==================================================================
; DRIVER HEADER

roothub_driver:
	roothub_driver_Signature	   dd 'MYOS'
	roothub_driver_DriverEntry	   dd roothub_driver_EntryPoint-roothub_driver
	roothub_driver_ImageSize	   dd roothub_driver_end-roothub_driver
;==================================================================
; Structures and variables.

RootHub_gDriverObject dd ?
;TODO: initialize the DeviceClass field
;==================================================================
; Pci Driver Entry Point
; ebx = Driver Object
roothub_driver_EntryPoint:
	mov [ebx+VDDO.AddDevice], RootHub_AddDevice_def
	mov [ebx+VDDO.RemoveDevice], RootHub_RemoveDevice_def
	mov [ebx+VDDO.IORoutine], RootHub_IORoutine_def
	mov [ebx+VDDO.DeviceControl], RootHub_DeviceControl_def
	mov word [ebx+VDDO.DeviceType], SD_USB_ROOT_HUB
	mov dword [ebx+VDDO.DeviceClass], 00000006h
	mov word [ebx+VDDO.BusType], SD_DEVICE_CONTROLLER
	xor eax,eax
	mov [ebx+VDDO.ReferenceCount], eax
	mov [ebx+VDDO.DeviceObject], eax
	ret
;==================================================================
;
RootHub_IORoutine_def:


;==================================================================
; ebx = Device Object
; edx = Device Control Code
; ecx = IO buffer
; esi = Aditional information
RootHub_DeviceControl_def:
	mov [PCI_current_do], ebx
	mov eax, edx
	and eax, 0ff000000h
	cmp eax, SD_USER_DEVICE_COMMAND
	je RootHub_HUserDevCommand
	cmp eax, SD_SYSTEM_DEVICE_COMMAND
	je RootHub_HSystemDeviceCommand
	jmp RootHub_UnknowCommandCode
;----------------------------------
; SYSTEM DEVICE COMMAND
RootHub_HSystemDeviceCommand:
	mov eax, edx
	cmp al, IOCC_INIT_DEVICE
		jne RootHub_HSystemDeviceCommand2
		call RootHub_InitDevice_def
		xor eax, eax
		ret
RootHub_HSystemDeviceCommand2:
	jmp RootHub_UnknowIOCommandCode
;------------------------------------------
;USER DEVICE COMMAND
RootHub_HUserDevCommand:
	jmp RootHub_UnknowCommandCode
;------------------------------------------
; UNKNOW COMMAND CODE
RootHub_UnknowIOCommandCode:
	mov ebx,DriverError_no_io_command_code
	call  PrintK_def
	mov eax, -1
	ret
RootHub_UnknowCommandCode:
	mov ebx,DriverError_no_command_code
	call  PrintK_def
	mov eax, -1
	ret
;==================================================================
; ebx = Driver Object
; edx = Parent Bus Device Object
; ecx = DeviceId, DeviceVendor
; esi = Bus/Device/Function|Interface/0
; eax <= DeviceObject
RootHub_AddDevice_def:
	push esi
; Checks if already exist a device object
;------------->
	mov esi, [ebx+VDDO.DeviceObject]
	jmp RootHub_AddDevice_test_search_device
RootHub_AddDevice_search_device:
	cmp dword [esi+VDO.DeviceVendor], ecx
	jz RootHub_AddDevice_device_exist
	mov esi, [esi+VDO.NextDevice]
RootHub_AddDevice_test_search_device:
	test esi,esi
	jnz RootHub_AddDevice_search_device
;-------------<
	pop esi
	call IOCreateDevice_def
	mov edi, eax
; fill the Device Object
	mov word [edi+VDO.DeviceType], 0; Device Type managed by this driver;SD_PCI_HOST_BRIDGE
	mov word [edi+VDO.BusType], 0;Bus type where this device is atached;SD_ROOT_BUS
	mov dword [edi+VDO.DriverObject], ebx
	mov dword [edi+VDO.DeviceParent], edx
	mov dword [edi+VDO.DeviceId], ecx
	mov dword [edi+VDO.Address], esi	; saved as MyLO PCI Device Address - See Pci Header File
; attach the new device to Driver device list
	mov eax, [ebx+VDDO.DeviceObject]	; last device assigned
	mov [edi+VDO.NextDevice], eax
	mov [ebx+VDDO.DeviceObject], edi
	inc dword [ebx+VDDO.ReferenceCount]
	mov eax,edi
	ret
RootHub_AddDevice_device_exist:
	mov esi, mylo_debug_device_exist
	call PrintK_def
	mov eax, -1
	ret
;==================================================================
; ebx = Driver Object
RootHub_RemoveDevice_def:

	ret
;==================================================================
RootHub_InitDevice_def:

	mov ebx, roothub_initOk
	call PrintK_def
	ret
roothub_initOk db 'Root Hub Init call Ok...',13,0
	ret
;==================================================================
; DRIVER SPECIFIC IMPLEMENTATION ROUTINES
;==================================================================
;==================================================================
include '..\driversdata.asm'
roothub_driver_end:
