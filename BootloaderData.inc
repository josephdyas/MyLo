;#############################################################################
;			SYSTEM SCREEN LAYOUT

systemlogo:
db '                   MyOS 2019 - Copyright - Joseph Dias                          '
db '________________________________________________________________________________'
endsystemlogo:
;==============================================================================
; 16 bits
errorsystem32 db ' 32 Bits Required to Run the OS',0dh,0

BootLoaderOK	db 0dh,'BootLoader OK!',0dh,0
VesaNo		db 'Vesa Not Suported!',0dh,0
Vesaver 	db 'Vesa Version: x.x',0dh,0
GetMemoryMapstr db 'Geting memory map...',0dh,0
ErroEBDA	db 'Erro to Read EBDA.',0dh,0
EBDAOk		db 'EBDA located at: 0x----:0x0000.',0dh,0
DSDTAddress	db 'DSDT found at : 0x----:0x----.',0dh,0
ErrorDSDT	db 'DSDT not found!',0dh,0
floppydrives	db ' xxxx FLOPPY Drives.',0dh,0
kernelloaded	db 'Kernel Loaded: xxxx',0dh,0
mmaperror	db 'Error to get Memory Map!',0dh,0
ErroDiskImage	db 'Error to Load the Disk Image!',0dh,0
error_int3	db 'Int 13h extensions not suported!',0dh,0
ok_int3 	db 'Int 13h extensions suported',0dh,0
;==============================================================================
; 32 bits
boot_cpuid	db   'Reading CPUIDs...',0dh,0
boot_cpuiderror db   'CPUID not suported!',0dh,0
boot_cpuidname	db   'CPU - xxxxxxxxxxxx',0dh,0
boot_cpuidExFunc	db 'CPUID: Highest Value:',0
cpuid_brandString: times 16*3 db ' '
			      db 0dh,0
;------------------------------------------------------------------------------
boot_pcibus	db 'Detecting PCI bus...',0dh,0
boot_nopci	db 'PCI Bus not found!',0dh,0
boot_devices	db 'Detecting devices...',0dh,0
;------------------------------------------------------------------------------
boot_pcidevices2 db 'Index     Bus       Device    Function',0dh,0
boot_deviceindex db '0x00XX    '
boot_deviceBus	 db	      '0x00XX    '
boot_deviceDev	 db			'0x00XX    '
boot_deviceFunc  db				  '0x00XX',0dh,0
;------------------------------------------------------------------------------
boot_pcidevices   db 'DeviceID  VendorID  Revision  ProgIF Class SubClass IntLine',0dh,0
boot_deviceID	  db '0x00XX    '
boot_deviceVendor db	       '0x00XX    '
boot_deviceRev	  db			 '0xXX      '
boot_deviceProgIF db				   '0xXX   '
boot_deviceClass  db					  '0xXX  '
boot_deviceSubClass  db 					'0xXX     '
boot_deviceBar0   db							 '0xXX',0dh,0
;------------------------------------------------------------------------------
boot_searchehci 	db 'Searching EHCI Host Controller...',0dh,0
boot_echidevicenotfound db 'EHCI Host Controller not presente!', 0dh,0
boot_ehci_no_eecp	db 'EHCI EECP not presente!',0dh,0
boot_ehciconfig 	db 'Setting ECHI Host Controller...',0dh,0
boot_ehcideviceiniterror db 'Error to initialize Host Controller!',0dh,0
boot_ehcinolegacysup	db 'No EHCI Legacy Support!',0dh,0
boot_osunebletoownerehci db 'OS Unable to get ehci ownership!',0dh,0
boot_osgotownership	db 'OS got ownership!',0dh,0
boot_stop_hc		db 'stoping host controller...',0dh,0
boot_ehcierrortoinit	db 'Error to initialize EHCI',0dh,0
boot_devicedisconnect	db 'Device disconnected!',0dh,0
boot_ehciporchange	db 'Port change detected!',0dh,0
boot_portenabled	db 'device Reseted and Enabled!',0dh,0
boot_portnotenabled	db 'device Can not be Enabled!',0dh,0

debug_message db 'Memory manager initialized',0dh,0
keyboard dd 0
;------------------------------------------------------------------------------
; INPUT OUTPUT MANAGER DATA
kiom_pci_bus_driver_not_found db 'PCI Bus Driver missing!',0dh,0

;##############################################################################
