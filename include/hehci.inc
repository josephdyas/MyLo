;##############################################################################
; EHCI CONSTANTS AND STRUCTURES

;==============================================================================
; CONSTANTS
FRAME_LIST_BASE                 = 010000h
QUEUEHEAD_LIST                  = 011000h
ELEMENT_QUEUEHEAD_LIST          = 012000h

DEVICE_DESCRIPTOR_LIST          = FRAME_LIST_BASE+3000h

GET_DEVICE_DESCRIPTOR_QH        = QUEUEHEAD_LIST
GET_DEVICE_DESCRIPTOR_TD_LIST   = ELEMENT_QUEUEHEAD_LIST

FLAG_INT_ASYNCAD        = 32
FLAG_INT_HSYS_ERROR     = 16
FLAT_INT_FLIST_ROLLOVER = 8
FLAG_INT_PORT_CHANGE    = 4
FLAG_INT_USB_ERROR_INT  = 2
FLAG_INT_USB            = 1

; Possible values of ehci_pipe.NextQH.Type bitfield.
EHCI_TYPE_ITD  = 0 ; isochronous transfer descriptor
EHCI_TYPE_QH   = 2 ; queue head
EHCI_TYPE_SITD = 4 ; split-transaction isochronous TD
EHCI_TYPE_FSTN = 6 ; frame span traversal node

QUEUE_HEAD_HBIT         = 1 shl 15
NAK_COUNT_RELOUD        = 1 shl 28
HBAND_PIPE_MULTI        = 1 shl 30
TOGGLE_DATA_INOUT       = 1 shl 31


EPS_HIGH        = 2 shl 12
EPS_LOW         = 01000h
EPS_FULL        = 0

DEFAULT_ENDPOINT        = 0
DEFAULT_PCKT_SIZE       = 8 shl 16
PCKT_SIZE_64            = 64 shl 16
EHCI_DEV_ADDRESS0       = 0
MAX_PACKET_LENGTH       = 64

; =============================================================================
; STRUCTURES
struct EHCI_OPERACIONAL_REGISTER
        command         dd ?
        status          dd ?
        interrupt       dd ?
        frameindex      dd ?
        segment         dd ?
        framelistbase   dd ?
        asynclistadd    dd ?
        reserved        db 36 dup(?)
        configflag      dd ?
        portsc          dd ?
ends
; EHCI_DESCRIPTOR
; contain information for a Enhaced Host Controller. Each controller is
; initialized with your own descriptor because one system can have many
; controllers
struct EHCI_DESCRIPTOR
        DescSize        dd sizeof.EHCI_DESCRIPTOR
        pciConfigSpace  dd ?            ; pci config space with pci address format
        configSpaceMMIO dd ?            ; pci config space im memory maped IO (this config space is into buffer retrived by PciScan())
        ehciMMIO        dd ?
        ehciSParams     dd ?
        ehciCParams     dd ?
        ehciExCParamOffset   dd ?       ; Offest of EHCI extended Capabilities Param into PCI config space
        ehciOpReg       dd ?
        ehciframebuffer dd ?
        ehciDefaultPipe dd ?
        ehciDefaultTD   dd ?
        ehciCpBuffer    dd ?    ; Control Pipe buffer
        ehciCtdBuffer   dd ?    ; Control Transfer Descriptor buffer
        ehciddBuffer    dd ?
        ehciCPipeBitmap dd ?
        ehciddBitmap    dd ?    ; Device Descriptor Bitmap
ends ; 64 bytes

; 92 bytes
struct EHCI_TD
        NextTD                  dd ?
        AlternateNextTD         dd ?
        Token                   dd ?
        BufferPointers          dd 5 dup(?)
        BufferPointersHigh      dd 5 dup(?)
ends

; 108
struct EHCI_PIPE
        NextQH          dd ?
        Token           dd ?
        Flags           dd ?
        CurrentTD       dd ?
        Overlay         EHCI_TD
ends

struct SETUP_PACKET
 bmRequest              db ?
 bRequest               db ?
 wValue                 dw ?
 wIndex                 dw ?
 wLength                dw ?
ends

struct USB_DEVICE_DESCRIPTOR
 bLength                db ?
 bDescriptorType        db ?
 bcdUSB                 dw ?
 bDeviceClass           db ?
 bDeviceSubClass        db ?
 bDeviceProtocol        db ?
 bMaxPacketSize         db ?
 idVendor               dw ?
 idProduct              dw ?
 bcdDevice              dw ?
 iManufacturer          db ?
 iProduct               db ?
 iSerialNumber          db ?
 bNumConfigurations     db ?
ends

struct USB_CONFIGURATION_DESCRIPTOR
 bLength                db ?
 bDescriptorType        db ?
 wTotalLength           dw ?
 bNumInterfaces         db ?
 bConfigurationValue    db ?
 iConfiguration         db ?
 bmAttributes           db ?
 MaxPower               db ?
ends

struct USB_ENDPOINT_DESCRIPTOR
 bLength                db ?
 bDescriptorType        db ?
 bEndpointAddress       db ?
 bmAttributes           db ?
 wMaxPacketSize         dw ?
 bInterval              db ?
ends

struct HCD_DEVICE_DESCRIPTOR
        DeviceAddress           db ?    ; Usb device address (1 to 128)
        PortNumber              db ?    ; Device port number on Root Hub
        Reserved1               dw ?
        ControlPipe             dd ?    ; address of the Control Pipe
        Reserved2               dw ?
        Reserved3               dd ?
        UsbDeviceDescriptor     USB_DEVICE_DESCRIPTOR       ; 18 bytes
ends ; 32 bytes
