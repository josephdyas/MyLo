;##############################################################################
; PCI CONSTANTS AND STRUCTURES

PCI_CONFIG_ADDRESS  equ 0cf8h
PCI_CONFIG_DATA     equ 0cfch
io_CF8              equ 80000000h
PCI_BLOCKINFOSIZE   equ 0x0fc    ;address dd 0|0000000|00000000|00000|000|111111|00b
PCI_FUNCTION_OFFSET equ 8
PCI_DEVICE_OFFSET   equ 11
PCI_BUS_MASK        equ 0x00ff0000

;PCI_DEVICE_CONFIG_SPACE = PCI_SCTRUCT_BLOCK
PCI_CONFIG_SPACE_SIZE = 100h

; =============================================================================
; pci header type 00h
struct PCI_HEADER_TYPE_0
     VendorID              dw ?
     DeviceID              dw ?
     Command               dw ?
     Status                dw ?
     RevisionID            db ?
     ProgIF                db ?    ; programmers interface
     SubClass              db ?
     ClassCode             db ?
     CacheLineSize         db ?
     LatencyTimer          db ?
     HeaderType            db ?
     BIST                  db ?
     BAR0                  dd ?
     BAR1                  dd ?
     BAR2                  dd ?
     BAR3                  dd ?
     BAR4                  dd ?
     BAR5                  dd ?
     CardBusCISPointer     dd ?
     SubSystemVendorID     dw ?
     SubSystemID           dw ?
     ROMBaseAddress        dd ?
     CapabilitiesPointer   db ?
     Reserved              db 3 dup(?)
     Reserved2             dd ?
     InterruptLine         db ?
     InterruptPIN          db ?
     MinGrant              db ?
     MaxLatency            db ?
ends
; pci header type 01h

struct PCI_HEADER_TYPE_1
     VendorID                dw ?
     DeviceID                dw ?
     Command                 dw ?
     Status                  dw ?
     RevisionID              db ?
     ProgIF                  db ?
     SubClass                db ?
     ClassCode               db ?
     CacheLineSize           db ?
     LatencyTimer            db ?
     HeaderType              db ?
     BIST                    db ?
     BAR0                    dd ?
     BAR1                    dd ?
     PrimaryBusNumber        db ?
     SecondaryBusNumber      db ?
     SubodinateBusNumber     db ?
     SecondaryLatencyTimer   db ?
     IOBase                  db ?
     IOLimit                 db ?
     SecondaryStatus         dw ?
     MemoryBase              dw ?
     MemoryLimit             dw ?
     PrefetchableMemBase     dw ?
     PrefetchableMemLimit    dw ?
     PrefetchableBaseUpper   dd ?
     PrefetchableLimitUpper  dd ?
     IOBaseUpper             dw ?
     IOLimitUpper            dw ?
     CapabilitiesPointer     db ?
     Reserved                db 3 dup(?)
     ExpasionRomBaseAddress  dd ?
     InterruptLine           db ?
     InterruptPIN            db ?
     BridgeControl           dw ?
ends
