;##############################################################################
;	    CONSTANTS AND STRUCTURES FOR MYOS EHCI DRIVE
;==============================================================================
; CONSTANTS
; Driver/Device Types
SD_SYSTEM_ROOT_BUS			= 0ffffh
SD_PCI_HOST_BRIDGE			= 00002h
SD_UNIVERSAL_HOST_CONTROLLER = 0003h
SD_ENHANCED_HOST_CONTROLLER	= 00004h
SD_ADVANCED_HOST_CONTROLLER	= 00005h

;Device Control Code

SD_SYSTEM_DEVICE_CONTROL	= 00h
SD_DEVICE_CONTROL			= 1 shl 31

IO_CONTROL_COMMAND_INIT_DEVICE	= 0001h
IO_CONTROL_COMMAND_SCAN_BUS		= 0002h

; Bus Types
SD_ROOT_BUS					= 00010h
SD_PCI_BUS					= 00012h
SD_USB_BUS					= 00013h


;==============================================================================
; STRUCTURES
struct KERNEL_DEVICE_DRIVER_OBJECT
	ImageAddress	dd ?	; Address where the driver image was loaded
	DeviceObject	dd ?	; first object atached to driver
	ReferenceCount	dd ?	; Numbe of devices atached to driver
; Procedures ---------
	AddDevice		dd ?	; Procedure to atach a new device to driver
	RemoveDevice	dd ?	; Procedure to deatach a device from driver
	IORoutine		dd ?	; Procedure to handle read/write operations
	DeviceControl	dd ?	; Procedure to handle IO control operations
; driver identification
	DeviceType		dw ?	; System constant code describing the device type
	BusType 		dw ?	; System constant code defining wich bus type the devices are atached
	DriverName		dd ?	; Null terminated string with ascii name used to indentify driver
	DeviceClass		dd ?	; Must have format - Class, Subclass, Interface/Protocol
	Reserved		dd 6 dup(?) ; complete the 64 bytes structure
ends ; 64 bytes

struct KERNEL_DEVICE_OBJECT
	DeviceType		dw ?	; Code defining device type
	BusType 		dw ?	; Code defining bus type where the device is atached
	DeviceName		dd ?	; String defining the device name
	DriverObject	dd ?	; Driver object representing the driver that manage this device
	DeviceParent	dd ?	; Device object representing the perante device 
	NextDevice		dd ?	; Device object assigned by driver for each device that it manage.
	Address 		dd ?	; Device Address (Bus/Device/Function)
	Reserved		dd 10 dup(?)
ends ; 64 bytes

