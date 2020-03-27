;##############################################################################
;
;  EHCI.asm
; 32 bit Ehci driver for Mylo
; Functions
; -------------------------------------
; INTERNAL FUNCTIONS	 
; EhciInit - Initizalize the HC and structures need to work.
; EhciIsr - HCD Interrupt Service Routine.
; EhciIsrPortCheck - Check a port change detected by EhciIsr.
; EhciNewDevice - Used to detect and configure new devices connected.
; EhciSetGetDeviceDescriptor - Inititalize the QH and qTD to get
;	device descriptor in Device Detection.
; EhciSetDeviceAddress - Initialize the QH and qTD to set Device Address.							    
; AllocDeviceDescriptor - Alloc a HCD device descriptor structure.
; AllocControlPipe - Alloc a QH for a Control Endpoint.
; FreeDeviceDescriptor - Free the device descriptor
; FreeControlPipe - Free the Control Pipe
;--------------------------------------
; IMPORTED FUNCTIONS
; PrintK
;==============================================================================
; DRIVER HEADER
ehci_driver:
	ehci_driver_Signature	    dd 'MYOS'
	ehci_driver_DriverEntry     dd EntryPoint_ehci_driver-ehci_driver
	ehci_driver_ImageSize	    dd ehci_driver_end-ehci_driver
;==============================================================================	
virtual at 0
VEHCI_DESC EHCI_DESCRIPTOR
end virtual
virtual at 0
VPCIEHCI PCI_HEADER_TYPE_0
end virtual

virtual at esi
operational EHCI_OPERATIONAL_REGISTER
end virtual

virtual at 0
ehci_pipe EHCI_PIPE
end virtual

virtual at 0
transfer_descriptor EHCI_TD32
end virtual
virtual at 0
HCD_devicedescriptor HCD_DEVICE_DESCRIPTOR
end virtual
virtual at 0
setup_packet SETUP_PACKET
end virtual

PciRegister dd ? ;Pci Register read with IO Control command from PCI Driver.
EhciEECPReg dd ?
gCurrentEhciDO dd ?;Used to hold Device Object to be handled for some functions
;==============================================================================
;Enhanced Host Controller - EHCI and USB
align 32
EhciDriver_getDeviceDescriptorCmd  db 80h,06h,00h,01h,00h,00h,12h,00h
EhciDriver_setDeviceAddressCmd     db 00h,05h,00h,00h,00h,00h,00h,00h

gEhciDescriptorBuffer db sizeof.EHCI_DESCRIPTOR*8 dup(0)
gEhciConfigTD db 32*3 dup(0)
gEhciConfigPipe	db 64 dup(0) ; Queue Head used to config new devices
;==============================================================================
; Pci Driver Entry Point
; ebx = Driver Object
EntryPoint_ehci_driver:

	mov [ebx+VDDO.AddDevice], EhciDriver_AddDevice_def
	mov [ebx+VDDO.RemoveDevice], EhciDriver_RemoveDevice_def
	mov [ebx+VDDO.IORoutine], EhciDriver_IORoutine_def
	mov [ebx+VDDO.DeviceControl], EhciDriver_DeviceControl_def
	mov word [ebx+VDDO.DeviceType], SD_ENHANCED_HOST_CONTROLLER
	mov dword [ebx+VDDO.DeviceClass], 0020030ch
	mov word [ebx+VDDO.BusType], SD_PCI_BUS
	xor eax,eax
	mov [ebx+VDDO.ReferenceCount], eax
	mov [ebx+VDDO.DeviceObject], eax
	
;----------------------------
;clear the EHCI DESCRIPTOR BUFFER
	xor eax,eax
	mov edi, gEhciDescriptorBuffer
	mov ecx, sizeof.EHCI_DESCRIPTOR*2
	rep stosd
;----------------------------
	ret
;==============================================================================
;
EhciDriver_IORoutine_def:

	ret
;==============================================================================
; ebx = Device Object
; edx = Device Control Code
; ecx = inpurt output buffer
; esi = More information
EhciDriver_DeviceControl_def:

	mov [gCurrentEhciDO], ebx
	mov eax, edx
	and eax, 0ff000000h
	cmp eax, SD_SYSTEM_DEVICE_COMMAND
	je EhciDriver_HSystemDeviceCommand
	cmp eax, SD_USER_DEVICE_COMMAND
	je EhciDriver_HUserDevCommand
	jmp EhciDriver_UnknowControlCode
;----------------------------------
; SYSTEM DEVICE COMMAND
EhciDriver_HSystemDeviceCommand:
	mov eax, edx
	cmp al, IOCC_INIT_DEVICE
		jne EhciDriver_HSystemDeviceCommand2
		call EhciDriver_InitDevice_def
		ret
EhciDriver_HSystemDeviceCommand2:
	jmp EhciDriver_UnknowControlCode
;------------------------------------------
;USER DEVICE COMMAND
EhciDriver_HUserDevCommand:
	mov eax, edx
	;cmp al, 0;IOC_READ_CONFIGSPACE
	
	jmp EhciDriver_UnknowControlCode
;------------------------------------------
; UNKNOW COMMAND CODE
EhciDriver_UnknowControlCode:
	mov eax, -1
	ret
;==============================================================================
; ebx = Driver Object
; edx = Parent Bus Device Object
; ecx = DeviceId, DeviceVendor
; esi = Bus/Device/Function|Interface/0
; eax <= DeviceObject
EhciDriver_AddDevice_def:
	
	;TODO: Remove this debug
	DEBUG_IN
	mov ebx, mylo_debug_ehci_add_device
	call PrintK_def
	DEBUG_OUT
	
	call IOCreateDevice_def
	mov edi, eax
; fill the Device Object
	mov word [edi+VDO.DeviceType], SD_ENHANCED_HOST_CONTROLLER
	mov word [edi+VDO.BusType], SD_PCI_BUS
	mov dword [edi+VDO.DriverObject], ebx
	mov dword [edi+VDO.DeviceParent], edx
	mov dword [edi+VDO.DeviceId], ecx
	mov dword [edi+VDO.Address], esi
; attach the new device to Driver device list
	mov eax, [ebx+VDDO.DeviceObject]	; last device assigned
	mov [edi+VDO.NextDevice], eax
	mov [ebx+VDDO.DeviceObject], edi
	inc dword [ebx+VDDO.ReferenceCount]
	mov eax, edi
	ret
;==============================================================================
; ebx = Driver Objetct
EhciDriver_RemoveDevice_def:

	ret
	
;==============================================================================
;ebx = address and register number
Ehci_PciReadRegD_def:
	;-----------------------
	xor eax,eax
	mov [PciRegister], eax
	mov eax, [gCurrentEhciDO]
	;mov edi, [eax+VEhciDescriptor];Reserved+8]
	mov esi, ebx
	mov ebx, [eax+VDO.DeviceParent]
	mov edx, SD_USER_DEVICE_COMMAND+IOC_READ_PCIREGISTERD
	lea ecx, [PciRegister]
	call IODeviceControl_def
	mov eax, [PciRegister]
	ret
;==============================================================================
; ebx = pci addres with register address
; edx = value to write
Ehci_PciWriteRegB_def:
	mov esi, ebx
	mov [PciRegister], edx
	mov eax, [gCurrentEhciDO]
	;mov edi, [eax+VEhciDescriptor]
	mov ebx, [eax+VDO.DeviceParent]
	mov edx, SD_USER_DEVICE_COMMAND+IOC_WRITE_PCIREGISTERB
	mov ecx, PciRegister
	call IODeviceControl_def
	ret
;==============================================================================
; ebx = pci addres with register address
; edx = value to write
Ehci_PciWriteRegW_def:
	mov esi, ebx
	mov [PciRegister], edx
	mov eax, [gCurrentEhciDO]
	;mov edi, [eax+VEhciDescriptor]
	mov ebx, [eax+VDO.DeviceParent]
	mov edx, SD_USER_DEVICE_COMMAND+IOC_WRITE_PCIREGISTERW
	lea ecx, [PciRegister]
	call IODeviceControl_def
	ret
;==============================================================================
;TODO - error handler
EhciDriver_Erro_Read_PciConfig:
EhciDriver_Erro_Read_PciRegister:
	mov eax, -1
	DebugMessage 'This is a Sheet Error to Read Pci Data'
	ret
VEhciDescriptor = VDO.Reserved+8
;==============================================================================
EhciDriver_InitDevice_def:

	mov ebx, 2000h ; 8 Kb
	call AllocMemory_def
	mov edi, [gCurrentEhciDO]
	mov dword [edi+VDO.Reserved], eax		; buffer to hold ehci structures.
	add eax, 1f00h
	mov dword [edi+VDO.Reserved+4], eax	; buffer to hold Pci Config Space data for the current controller.
	call AllocEhciDescriptor_def
	mov dword [edi+VDO.Reserved+8], eax	; Ehci Descriptor
	;Read Ehci Pci configuration Space
	mov ebx, [edi+VDO.DeviceParent]
	mov edx, SD_USER_DEVICE_COMMAND+IOC_READ_CONFIGSPACE
	mov ecx, [edi+VDO.Reserved+4]
	mov esi, [edi+VDO.Address]
	call IODeviceControl_def
	test eax,eax
	jnz EhciDriver_Erro_Read_PciConfig
	mov eax, [gCurrentEhciDO] ; gCurrentEhciDO
	;eax = Device Obejct
	;edi = Ehci Descriptor
	mov ebx, [eax+VDO.Address]
	mov edi, [eax+VEhciDescriptor]
	mov esi, [eax+VDO.Reserved+4]
	call Ehci_MakePciAddress_def
; Fill Host Controller descriptor
	mov [edi+VEHCI_DESC.pciConfigSpace], eax
	mov [edi+VEHCI_DESC.configSpaceMMIO], esi
	mov edx, dword [esi+VPCIEHCI.BAR0]
	mov [edi+VEHCI_DESC.ehciMMIO], edx
	;get size of CAPLENGTH to get Operational Register
	;address
	movzx eax, byte [edx]
	lea eax, [edx+eax]
	mov [edi+VEHCI_DESC.ehciOpReg], eax
	lea eax, [edx+04h]
	mov [edi+VEHCI_DESC.ehciSParams], eax
	lea eax, [edx+08h]
	mov [edi+VEHCI_DESC.ehciCParams], eax
;Check Extented Cap. Register.
	mov eax, dword [eax] ; eax = HCCPARAMS
	shr eax, 8
	and eax, 0ffh	; al = EHCI Extented Cap. Pointer.
	mov [edi+VEHCI_DESC.ehciExCParamOffset], eax
	test eax,eax
	jnz @f ;ehci_eecp_present
;ehci_eecp_not_present:
	mov ebx, ehci_eecp_not_present
	call PrintK_def
	jmp initialize_host_controller
ehci_eecp_not_present db 'Ehci EECP not present...',13,0
;&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
@@: ;ehci_eecp_present:
;get eecp register value from pci config space
; retrive eecp register offset and read its value from pci config space
; ebx = bus/dev/func address at PCI config space
; eax = eecp offset from EHCI HCCPARAMS
	mov ebx, [edi+VEHCI_DESC.pciConfigSpace]
	mov bl, al
	mov [EhciEECPReg], ebx
	call Ehci_PciReadRegD_def
	cmp eax, -1
	jne @f
	DebugMessage 'Erro to read eecp offset...'
	ret
@@:
	clc
	bt eax, 0		     ; Test if the eecp Legact Support. Capability ID, 1 = Legact Support
	jc @f;ehci_legacy_support
	mov ebx, ehci_no_legacy_support
	call PrintK_def
	jmp initialize_host_controller
ehci_no_legacy_support db 'Ehci No Legacy Support...',13,0
;&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
@@: ;ehci_legacy_support:
;<<************************************
; set OS Ownership
	mov ecx, 3
set_os_ehci_Ownership:
	mov edx, 1
	mov ebx, [EhciEECPReg]
	add bl, 3		; HC OS Owned Semaphore byte offset (into 4 bytes register)
	call Ehci_PciWriteRegB_def
	; SLEEP - macro to wait at least 10 miliseconds before continue
	;SLEEP			
	mov ebx, [EhciEECPReg]
	call Ehci_PciReadRegD_def
	cmp eax, -1
	jne @f
	DebugMessage 'Erro to check Os ehci ounwership'
	ret
@@:
	clc
	bt eax, 16
	jnc os_ehci_owned
	dec ecx
	jnz set_os_ehci_Ownership
	mov esi, boot_osunebletoownerehci
	call Puts
	mov eax, -1
	ret
;&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
;************************************>>
; clear the SMI interrupts
os_ehci_owned:
; clear the processor interrups to avoid interrupt during
	cli	; clear interrupt flag
	mov ebx, [EhciEECPReg]
	add bl, 4
	push ebx
	call Ehci_PciReadRegD_def
	cmp eax, -1
	jne @f
	pop ebx
	DebugMessage 'Erro to check Os ehci ounwership'
	ret
@@:
	mov edx, eax
	mov bx, 2000h	; keep only SMI on PCI Command Enable.
	and dx, bx
	pop ebx
	call Ehci_PciWriteRegW_def
;------------------------------------------------------------------------------
; configure the controller
initialize_host_controller:
	sti
	DebugMessage 'Ehci Device init ok...'
	ret
;ehci_eecp_present_ok db 'Configure the Host Controller...',13,0
	cli
	mov eax, [gCurrentEhciDO]
	mov edi, [eax+VEhciDescriptor]
	mov esi, [edi+VEHCI_DESC.ehciOpReg]
; clear Host Controller interrupt's
	xor eax, eax
	mov dword [operational.interrupt], eax
; re enable cpu interrupts
	sti
ehci_stop_controller:
	mov eax, [operational.status]
	clc
	bt eax, 12
	jc ehci_reset_hc
; Stop the host controller if it is running
	mov al, byte [operational.command]
	and al, 0feh
	mov byte [operational.command], al
	SLEEP
	jmp ehci_stop_controller
	mov esi, boot_stop_hc
	call Puts
	mov eax, 1
	ret
;&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
ehci_reset_hc:
	mov al, byte [operational.command]
	or al, 02h
	mov byte [operational.command], al
	SLEEP
ehci_wait_host_reset:
	mov al, byte [operational.command]
	clc
	bt  eax, 1
	jnc ehci_reset_ok
	SLEEP
	jmp ehci_wait_host_reset
ehci_reset_ok:
;==============================================================================
; Alloc and initiliaze memory for Host Controller
	mov eax, [gCurrentEhciDO]
	mov ebx, [eax+VDO.Reserved] ; Address of the Buffer for EHCI structures
	mov dword [edi+VEHCI_DESC.ehciframebuffer], ebx; FRAME_LIST_BASE
	lea eax, [ebx+QUEUEHEAD_LIST_OFFSET]; 2KB
	mov dword [edi+VEHCI_DESC.ehciCpBuffer], eax ; QUEUE_HEAD_LIST - Asynchronous List can be 32 byte aligned
	lea eax, [ebx+ELEMENT_QUEUEHEAD_LIST_OFFSET]
	mov dword [edi+VEHCI_DESC.ehciCtdBuffer], eax
	mov dword [edi+VEHCI_DESC.ehciConfigPipe], gEhciConfigPipe
	mov dword [edi+VEHCI_DESC.ehciConfigTD], gEhciConfigTD
	lea eax, [ebx+HCD_DESCRIPTOR_LIST_OFFSET]
	mov dword [edi+VEHCI_DESC.ehciddBuffer], eax
	xor eax,eax
	mov dword [edi+VEHCI_DESC.ehciCPipeBitmap], eax
	mov dword [edi+VEHCI_DESC.ehciddBitmap], eax
;--------------------------------------
; initilize the frame list
	mov esi, [edi+VEHCI_DESC.ehciframebuffer]
	push edi
	mov edi, esi
	mov eax, 03h	; empty link pointer + EHCI_TYPE_QH + T bit
	mov ecx, 256
	rep stosd
;--------------------------------------
; initialize Queue Head for assyncronus transfers
;******************
	mov edi,[esp]
	mov esi, [edi+VEHCI_DESC.ehciCpBuffer]
	push esi
	xor ebx,ebx
	inc ebx
	mov edx, EHCI_DEV_ADDRESS0+DEFAULT_ENDPOINT+EPS_HIGH+DEFAULT_PCKT_SIZE+NAK_COUNT_RELOUD
	mov ecx, 32
;**************************************
	loop_fill_QH_list:
	lea eax, [esi+128+EHCI_TYPE_QH]
	mov [esi+ehci_pipe.NextQH], eax
	mov [esi+ehci_pipe.Token], edx
	mov eax, HBAND_PIPE_MULTI
	mov [esi+ehci_pipe.Flags], eax
	mov [esi+ehci_pipe.Overlay.NextTD], ebx 	; mark the next Transfer Descriptor as invalid
	add esi, 128
	dec ecx
	jnz loop_fill_QH_list
;**************************************
;------------------------------
; set the default pipe to point to first QH, eax = ehci descriptor
	pop edi 		; first QH
	mov eax, [esp]	; ehci descriptor
	mov eax, [eax+VEHCI_DESC.ehciConfigPipe]
	mov [eax+ehci_pipe.NextQH], edi
;------------------------------
	sub esi, 128 ; back to last Queue Head
	mov [esi+ehci_pipe.NextQH], eax 	; link the last queue head with the default pipe QH (create the ring).
; set the default pipe QH as list Head (with H-bit)
	mov esi, EHCI_DEV_ADDRESS0+DEFAULT_ENDPOINT+EPS_HIGH+DEFAULT_PCKT_SIZE+QUEUE_HEAD_HBIT+NAK_COUNT_RELOUD
	mov [eax+ehci_pipe.Token], esi
	mov [eax+ehci_pipe.Overlay.NextTD], ebx
	mov esi, HBAND_PIPE_MULTI
	mov [eax+ehci_pipe.Flags], esi
;--------------------------------------
;initialize Transfer Descriptor for assyncronus transfers
; edi = ehci descriptor
	pop edi
	mov esi, [edi+VEHCI_DESC.ehciCtdBuffer]
	mov ecx, 32
	xor eax,eax
	inc eax
;******************
	loop_fill_eQH_list:
	mov [esi+transfer_descriptor.NextTD], eax
	mov [esi+transfer_descriptor.AlternateNextTD], eax
	add esi, 64
	dec ecx
	jnz loop_fill_eQH_list
;******************
;--------------------------------------
; Initialize the Host Controller
; set the periodic list and async list
	mov esi, [edi+VEHCI_DESC.ehciOpReg]
	mov eax, [edi+VEHCI_DESC.ehciCpBuffer]
	mov [operational.asynclistadd], eax
	mov eax, [edi+VEHCI_DESC.ehciframebuffer]
	mov [operational.framelistbase], eax
; set the segment (for 64 bits) and periodic list index
	xor eax, eax
	mov [operational.segment], eax	; set the 4G segment
	mov [operational.frameindex], eax
; put the host controller to run
	mov eax, [operational.command]
	or eax, 1h
	mov [operational.command], eax
; set all ports to be routed to enhanced host controller (2.0)
	xor eax,eax
	inc eax
	mov [operational.configflag], eax
; enable the async schedule
	mov eax, [operational.command]
	bts eax, 5
	mov [operational.command], eax
;--------------------------------------
; TODO: CALL THE ROOT HUB
	xor eax,eax	; set to 0 for 0 errors
	ret
;==============================================================================
; handle the ehci events
; ebx = Host Controller descriptor
virtual at 0
	OPISR EHCI_OPERATIONAL_REGISTER
end virtual
EhciISR_def:
	push edi esi ecx
	mov edi, ebx
	mov esi, [edi+VEHCI_DESC.ehciOpReg]
;--------------------------------------
; CHECK PORT CHANGE
	mov eax, [esi+OPISR.status]
	clc
	bt eax, 2
	jnc isr_status_port_no_change
	bts eax, 2
	mov [esi+OPISR.status], eax	; clear the Port Change Detect bit
	;mov ebx, edi
	call EhciIsrPortCheck_def
isr_status_port_no_change:
;------------------------------------------------------------------------------
; CHECK OTHER EVENT
	pop ecx esi edi
	ret
;==============================================================================
; Used by ehci isr to check a port change for initialize new devices on new
; devices connection or clear features of a disconnected device.
; ebx = Host Controller descriptor.
EhciIsrPortCheck_def:
	push esi edi ecx ; push 1

	mov edi, ebx
	mov esi, [edi+VEHCI_DESC.ehciOpReg]
	lea esi, [esi+OPISR.portsc]
	xor ecx,ecx
;<<************************************
loop_check_port_change:
	mov eax, [esi+ecx*4]
	clc
	bt eax, 1
	jnc port_not_change
	bts eax, 1 
	mov [esi+ecx*4], eax		; clear the connect status change bit
	;cmp ecx, 4
	;jg check_next_port
	jmp port_change_found
check_next_port:
port_not_change:
	inc ecx
	cmp ecx, 08h
	jnz loop_check_port_change
;************************************>>
	jmp EhciPortCheckExit
port_change_found:
	mov eax, [esi+ecx*4]
	bt eax, 0
	jnc devicedisconected
; 1 -----------------------------------
	mov ebx, edi
	lea edx, [esi+ecx*4]
	; mov ecx, ecx
	call EhciNewDevice_def
;jump_newdevice:
	jmp check_next_port
; 2 -----------------------------------
devicedisconected:
	push esi ecx
; clear the all data associated with device
	mov ebx, ecx
	xor ecx, ecx
	mov esi, [edi+VEHCI_DESC.ehciddBuffer]
;<<************************************
; search device descriptor using the port number
search_device_descriptor:
	mov al, byte [esi+HCD_devicedescriptor.PortNumber]
	cmp al, bl
	jz device_descriptor_found
	add esi, sizeof.HCD_DEVICE_DESCRIPTOR
	inc ecx
	cmp ecx, 32
	jnz search_device_descriptor
;TODO
	jmp search_device_descriptor
;************************************>>
; free the Control Pipe and Device Descriptor
; associated with device (Control pipe should be free first)
device_descriptor_found:
	mov ebx, edi
	mov edx, esi
	call FreeControlPipe_def
	mov ebx, edi
	mov edx, esi
	call FreeDeviceDescriptor_def
;TODO
	;mov esi, boot_devicedisconnect
	;call Puts
	pop ecx esi
	jmp check_next_port
;--------------------------------------
EhciPortCheckExit:
	pop ecx edi esi ; pop 1
	ret
;==============================================================================
; Get information and config new devices
; ebx = Host Controller descriptor
; edx = port register address
; ecx = port number
EhciNewDevice_def:
	push esi edi ecx; push 1
; Set the Queue Head for Get_device_descriptor request
	mov edi, ebx
	mov esi, [edi+VEHCI_DESC.ehciOpReg]
; save port number and port register for sencond reset
	push edx	; push 2
	push ecx	; push 3 used on second reset
	push ecx	; push 4 used to save the port number on device descritor
;--------------------------------------
;First Port Reset
	mov eax, [edx]
	btr eax, 2	   ; clear the bit Port Enabled
	bts eax, 8     ; set the bit Port Reset
	mov [edx], eax
;wait_port_reset:
	SLEEP
	SLEEP
	mov eax, [edx]
	btr eax, 8	; clear the Port Reset
	mov [edx], eax
	SLEEP
	SLEEP
	mov eax, [edx]
	bt eax, 2
	jc portenabled
;TODO
	;mov esi, boot_portnotenabled
	;call Puts
	add esp, 3*4	; remove push 2, 3 and 4 before exit
	pop ecx edi esi     ; pop 1
	ret
;&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
portenabled:
;--------------------------------------
; alloc and initialize a device descriptor and control pipe
alloc_newdevice_descriptor:
	mov ebx, edi
	call AllocDeviceDescriptor_def
	pop edx 	; pop 4
	mov [eax+HCD_devicedescriptor.PortNumber], dl
	push eax	; push 4 save the device descriptor on stack
	mov ebx, edi
	call AllocControlPipe_def
	mov ebx, eax
	mov eax, [esp]
	mov [eax+HCD_devicedescriptor.ControlPipe], ebx
initialize_newdevice_transfer:
; set the QH and TD
;mov ebx, ebx
	mov edx, [edi+VEHCI_DESC.ehciConfigTD]
	lea ecx, [eax+HCD_devicedescriptor.UsbDeviceDescriptor]
repeat_initialize_newdevice_transfer:
	push edx	; push 5 
	push ebx	; push 6
	call EhciSetGetDeviceDescriptor_def
; clear the usb interrupt bit
	mov eax, 011111b
	mov [operational.status], eax
;<<************************************
wait_reclamation_bit:
	mov eax, [operational.status]
	bt eax, 13
	jc wait_reclamation_bit
;************************************>>
	mov eax, [esp]	       ; pop 6
	mov edx, [esp+4]	 ; pop 5
	lea edx, [edx+060h]
	xor ecx,ecx
	mov [eax+ehci_pipe.Overlay.Token], ecx
	mov [eax+ehci_pipe.Overlay.NextTD], edx
;<<************************************
wait_for_transfer_complete:
	mov eax, [operational.status]
	bt eax, 0
	jnc wait_for_transfer_complete
;************************************>>
; Test for transfer errors
	bt eax, 1
	jnc transfer_ok_1
	pop ebx
	pop edx
	jmp repeat_initialize_newdevice_transfer
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
transfer_ok_1:
	add esp, 2*4

	bts eax, 0
	mov [operational.status], eax	; acknowledge the interrupt
;--------------------------------------
; second port reset and device address assignment
	pop esi 	; pop 4 - device descriptor
	pop ecx 	; pop 3 - port number
	pop edx 	; pop 2 - port address
	mov eax, [edx]
	bts eax, 8	; set the bit Port Reset
	btr eax, 2		; clear the bit port enable
	mov [edx], eax
;wait_port_reset2:
	SLEEP
	SLEEP
	mov eax, [edx]
	btr eax, 8	; clear the Port Reset
	mov [edx], eax
	SLEEP
	SLEEP
wait_port_be_enabled1:
	mov eax, [edx]
	bt eax, 2
	jc portenabled2
	jmp wait_port_be_enabled1
	pop ecx edi esi     ; pop 1
	ret
;&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
;--------------------------------------
portenabled2:
; esi = device descriptor
; set the QH and TD
	mov ebx, [esi+HCD_devicedescriptor.ControlPipe]
	mov edx, [edi+VEHCI_DESC.ehciConfigTD]
; port number is used as device address
; mov ecx, ecx
	inc ecx
	mov [esi+HCD_devicedescriptor.DeviceAddress], cl
repeat_initialize_newdevice_transfer2:
	push ecx
	push edx	; push 2
	push ebx	; push 3
	call EhciSetDeviceAddress_def
;--------------------------------------
	mov esi, [edi+VEHCI_DESC.ehciOpReg]
; clear the usb interrupt bit
	mov eax, 011111b
	mov [operational.status], eax
;<<************************************
wait_reclamation_bit_2:
	mov eax, [operational.status]
	bt eax, 13
	jnc wait_reclamation_bit_2
;************************************>>
	mov eax, [esp]	       
	mov edx, [esp+4]
	lea edx, [edx+060h]
	xor ecx,ecx
	mov [eax+ehci_pipe.Overlay.Token], ecx	       
	mov [eax+ehci_pipe.Overlay.NextTD], edx
;<<************************************
wait_for_transfer_complete_2:
	mov eax, [operational.status]
	bt eax, 0
	jnc wait_for_transfer_complete_2
;************************************>>
; Test for transfer errors
	bt eax, 1
	jnc transfer_ok_2
	pop ebx 	; pop 3
	pop edx 	; pop 2
	pop ecx
	jmp repeat_initialize_newdevice_transfer2
transfer_ok_2:
	add esp, 3*4
;----------------------------
; acknowledge the interrupt
	bts eax, 0
	mov [operational.status], eax	
;------------
exit_new_device:
	pop ecx edi esi     ; pop 1
	ret
;==============================================================================
; Set the QH and TD structures for perfom a SET_DEVICE_ADDRESS command
; ebx = address of Queue Head
; edx = address of Transfer Descriptors list
; ecx = device address
EhciSetDeviceAddress_def:
	push esi edi

	mov edi, ebx
	xor ebx, ebx
	inc ebx
	mov eax, EHCI_DEV_ADDRESS0+DEFAULT_ENDPOINT+EPS_HIGH+PCKT_SIZE_64+NAK_COUNT_RELOUD
	mov [edi+ehci_pipe.Token], eax
	mov eax, HBAND_PIPE_MULTI
	mov [edi+ehci_pipe.Flags], eax
	xor eax,eax
	mov [edi+ehci_pipe.CurrentTD], eax
	mov [edi+ehci_pipe.Overlay.Token], eax
	mov [edi+ehci_pipe.Overlay.NextTD], ebx ; address of the first TD

	lea edi,[edx+060h]
; Set the SETUP transaction with SET_DEVICE_ADDRESS request
;--------------------------------------
; this is the only transfer descriptor
	lea eax, [edi+060h]
	mov [edi+transfer_descriptor.NextTD], eax
	mov [edi+transfer_descriptor.AlternateNextTD], ebx
	xor eax,eax
	mov ax, 08h
	shl eax, 16
	mov ax, 0e80h		; Error counter = 4 (11b) + PID code = 2 (10b) SETUP Token + Status Active bit set.
	mov [edi+transfer_descriptor.Token], eax
	mov esi, EhciDriver_setDeviceAddressCmd
	mov [esi+setup_packet.wValue], cx
	mov [edi+transfer_descriptor.BufferPointers], esi
;--------------------------------------
;set the transaction with packet IN type to get device status
	add edi, 060h
	;lea eax, [edi+060h]
	mov [edi+transfer_descriptor.NextTD], edx
	mov [edi+transfer_descriptor.AlternateNextTD], ebx
	mov ax, 08000h	 ; size of transfer + Toggle Data bit (required by IN OU transaction)
	shl eax, 16
	mov ax, 0D80h		; Error counter = 4 (11b) + PID code = 1 (01b) IN Token + Status Active bit set.
	mov [edi+transfer_descriptor.Token], eax
	xor eax,eax
	mov [edi+transfer_descriptor.BufferPointers], eax
;--------------------------------------
;set the dummy transfer descriptor.
	mov edi, edx
	mov [edi+transfer_descriptor.AlternateNextTD], ebx
	mov [edi+transfer_descriptor.NextTD], ebx
	xor eax,eax
	mov [edi+transfer_descriptor.Token], eax
	mov [edi+transfer_descriptor.BufferPointers], eax
;--------------------------------------
	pop edi esi
	ret
;==============================================================================
; Set the QH and TD structures for perfom a GET_DEVICE_DESCRIPTPOR
; command
; ebx = address of Queue Head
; edx = address of Transfer Descriptors list
; ecx = address of the Device Descriptor buffer that receiv data
EhciSetGetDeviceDescriptor_def:
	push esi edi

	mov edi, ebx
	xor ebx, ebx
	inc ebx
;lea eax, [edi+EHCI_TYPE_QH]
;mov [edi+ehci_pipe.NextQH], eax
	mov eax, EHCI_DEV_ADDRESS0+DEFAULT_ENDPOINT+EPS_HIGH+PCKT_SIZE_64+NAK_COUNT_RELOUD;+QUEUE_HEAD_HBIT
	mov [edi+ehci_pipe.Token], eax
	mov eax, HBAND_PIPE_MULTI
	mov [edi+ehci_pipe.Flags], eax
	xor eax,eax
	mov [edi+ehci_pipe.CurrentTD], eax
	mov [edi+ehci_pipe.Overlay.NextTD], ebx ; address of the first TD

	lea edi, [edx+060h]
; Set the SETUP transaction with GET_DEVICE_DESCRITPOR request
;--------------------------------------
	lea eax, [edi+060h]
	mov [edi+transfer_descriptor.NextTD], eax
	mov [edi+transfer_descriptor.AlternateNextTD], ebx
	xor eax,eax
	mov ax, 08h
	shl eax, 16
	mov ax, 0e80h		; Error counter = 4 (11b) + PID code = 2 (10b) SETUP Token + Status Active bit set.
	mov [edi+transfer_descriptor.Token], eax
	mov eax, EhciDriver_getDeviceDescriptorCmd	; at Variable_bootloader
	mov [edi+transfer_descriptor.BufferPointers], eax
;--------------------------------------
;set the transaction with packet IN type to retrive Device Descriptor
	add edi, 060h
	lea eax, [edi+60h]
	mov [edi+transfer_descriptor.NextTD], eax
	mov [edi+transfer_descriptor.AlternateNextTD], ebx
	mov ax, 08012h	 ; size of transfer + Toggle Data bit (required by IN OUT transaction)
	shl eax, 16
	mov ax, 0D80h		; Error counter = 4 (11b) + PID code = 1 (01b) IN Token + Status Active bit set.
	mov [edi+transfer_descriptor.Token], eax
	mov [edi+transfer_descriptor.BufferPointers], ecx
;--------------------------------------
;set the transsaction with OUT type to acknowledge reception of the device descriptor.
	add edi, 60h
	;lea eax, [edx+60h]
	mov [edi+transfer_descriptor.NextTD], edx
	mov [edi+transfer_descriptor.AlternateNextTD], ebx
	xor eax,eax
	mov ax, 08000h
	shl eax, 16
	mov ax, 8c80h		; Error counter = 4 (11b) + PID code = 2 (10b) SETUP Token + Status Active bit set.
	mov [edi+transfer_descriptor.Token], eax
	xor eax,eax
	mov [edi+transfer_descriptor.BufferPointers], eax
;--------------------------------------
;set the dummy transfer descriptor.
	mov edi, edx
	mov [edi+transfer_descriptor.AlternateNextTD], ebx
	mov [edi+transfer_descriptor.NextTD], ebx
	xor eax,eax
	bts eax, 6
	mov [edi+transfer_descriptor.Token], eax
	xor eax,eax
	mov [edi+transfer_descriptor.BufferPointers], eax
;--------------------------------------
	pop edi esi
	ret
;==============================================================================
; Alloc a EHCI descriptor, it's used to allocate an EHCi Descriptor for
; each Enhanced Host Controller found in the system
; Obs.: The Ehci Descriptor Allocator does not need a desallocator because after
; getting and initializing each Host Controller it is not released.
AllocEhciDescriptor_def:
	push esi edi ecx
	mov ecx, 8 ;maximun number of descriptors
	mov esi, gEhciDescriptorBuffer
@@: ;search_empty_ehci_descriptor:
	mov eax, [esi+VEHCI_DESC.pciConfigSpace]
	test eax,eax
	jz @f ;ehci_descriptor_found
	add esi, sizeof.EHCI_DESCRIPTOR
	loop @b;search_empty_ehci_descriptor
	mov esi, -1
@@: ;ehci_descriptor_found:
	mov eax, esi
	pop ecx edi esi
	ret
;==============================================================================
; Alloc a HCD device descriptor
; ebx = EHCI descriptor
AllocDeviceDescriptor_def:
	cli
	push esi edi
	mov esi, ebx
	xor ecx, ecx
	mov eax, [esi+VEHCI_DESC.ehciddBitmap]
	search_dd_empty:
	shr eax, 1
	jnc dd_found
	inc ecx
	cmp ecx, 31
	jz no_device_descriptor
	jmp search_dd_empty
	dd_found:
	mov edi, [esi+VEHCI_DESC.ehciddBuffer]
; Set the descriptor as allocated
	mov eax, [esi+VEHCI_DESC.ehciddBitmap]
	bts eax, ecx
	mov [esi+VEHCI_DESC.ehciddBitmap], eax
	shl ecx, 5		; multiply by 32
	add edi, ecx
	mov eax, edi
	pop edi esi
	sti
	ret
;&&&&&&&&&&&&&&&&&&&&&&&&&&&&
no_device_descriptor:
	xor eax,eax
	pop edi esi
	sti
	ret
;==============================================================================
; ebx = EHCI desctiptor
AllocControlPipe_def:
	cli
	push esi edi

	mov esi, ebx
	xor ecx, ecx
	mov eax, [esi+VEHCI_DESC.ehciCPipeBitmap]
	search_control_pipe_empty:
	shr eax, 1
	jnc control_pipe_found
	inc ecx
	cmp ecx, 31
	jz no_control_pipe
	jmp search_control_pipe_empty
	control_pipe_found:
	mov edi, [esi+VEHCI_DESC.ehciCpBuffer]
; set the pipe as allocated
	mov eax, [esi+VEHCI_DESC.ehciCPipeBitmap]
	bts eax, ecx
	mov [esi+VEHCI_DESC.ehciCPipeBitmap], eax
	shl ecx, 7		; multiply by 128 (size of one QH)
	add edi, ecx
	mov eax, edi
	pop edi esi
	sti
	ret
;&&&&&&&&&&&&&&&&&&&&&&&&&&&&
	no_control_pipe:
	xor eax,eax
	pop edi esi
	sti
	ret
;==============================================================================
; Free a control pipe allocated with AllocControlPipe
; ebx = EHCI desctiptor
; edx = HCD device descriptor
FreeControlPipe_def:

	cli
	push edi esi ecx
	mov esi, ebx
	mov edi, [esi+VEHCI_DESC.ehciCpBuffer]
	mov ebx, [edx+HCD_devicedescriptor.ControlPipe]
	sub ebx, edi
	shr ebx, 7	; divide by 128 (size of a QUEUE HEAD)
	mov eax, [esi+VEHCI_DESC.ehciCPipeBitmap]
	btr eax, ebx
	mov [esi+VEHCI_DESC.ehciCPipeBitmap], eax
	; reinitialize pipe data
	;xor ecx,ecx
	;inc ecx
	;mov edx, EHCI_DEV_ADDRESS0+DEFAULT_ENDPOINT+EPS_HIGH+DEFAULT_PCKT_SIZE+NAK_COUNT_RELOUD
	;mov [edi+ehci_pipe.Token], edx
	;mov eax, HBAND_PIPE_MULTI
	;mov [edi+ehci_pipe.Flags], eax
	;mov [edi+ehci_pipe.Overlay.NextTD], ebx	 ; mark the next Transfer Descriptor as invalid
	;xor eax,eax
	;bts eax, 6
	;mov [edi+ehci_pipe.Overlay.Token], eax

	pop ecx esi edi
	sti
	ret
;==============================================================================
; Free a Device Descriptor allocated with AllocDeviceDescriptor
; ebx = EHCI descriptor
; edx = HCD device descriptor
FreeDeviceDescriptor_def:
	cli
	push edi esi ecx
	mov edi, edx
	mov eax, [ebx+VEHCI_DESC.ehciddBuffer]
	sub edx,eax
	shr	edx, 5		; divide by 32 (size of device descriptor structure)
	mov eax, [ebx+VEHCI_DESC.ehciddBitmap]
	btr eax, edx
	mov [ebx+VEHCI_DESC.ehciddBitmap], eax
	; clear the device descriptor structure
	mov ecx, 32/4
	xor eax,eax
	rep stosd
	; xor eax,eax
	pop ecx esi edi
	sti
	ret
;==================================================================
; convert the MyLo Pci Device Address to Pci device Address.
; ebx =: bxh = bus, bxl = device, bh = func, bl = index
Ehci_MakePciAddress_def:
	push edi esi
	shr ebx, 8
	mov eax, ebx
	shl bh, 3
	and eax, 111b
	or bh, al
	xor bl,bl
	mov eax, ebx
	pop esi edi
	ret
;==============================================================================
ehci_driver_end:
ehci_debug_add_device db 'Ehci AddDevice function ok...',0dh,0