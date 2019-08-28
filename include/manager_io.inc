;##############################################################################
;	    CONSTANTS AND STRUCTURES FOR MYOS EHCI DRIVE
;==============================================================================
; CONSTANTS
; Driver Types
SD_PCI_BUS equ 1
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
	ScanBus			dd ?	; Used only by Bus Drivers
; driver identification
	DeviceType		dw ?	; System constant code describing the device type
	BusType			dw ?	; System constant code defing wich bus type the devices are atached
	DriverName		dd ?	; null terminated string with ascii name used to indentify driver
	Reserved		dd 6 dup(?) ; complete the 64 bytes structure
ends ; 64 bytes

struct KERNEL_DEVICE_OBJECT 
	DeviceType		dw ?	; code defining device type
	BusType			dw ?	; code defining bus type where the device is atached
	DeviceName		dd ?	; string defining the device name
	DriverObject	dd ?	; driver object representing the driver that manage this device
	DeviceParent	dd ?	; device object representing the parante device	
	NextDevice		dd ?	; device object assigned by driver for each divice that it manage.
	Reserved		dd 11 dup(?)
ends ; 64 bytes

