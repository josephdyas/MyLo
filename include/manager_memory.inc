;##############################################################################
;	    CONSTANTS AND STRUCTURES FOR MYLO MEMORY MANAGER
;==============================================================================
; CONSTANTS
BLOCK_CHAIN_ADDRESS	= 0C000h
BLOCKLIST_ENTRY_SIZE	= 8
_KB = 1024
PF_SIZE = 4096

;==============================================================================
; STRUCTURES
struct BLOCK_DESCRIPTOR
	Address dd ?
	Size	dd ?
ends

struct BLOCK_LIST
	_4KB	dd 2 dup(?)
	_8KB	dd 2 dup(?)
	_16KB	dd 2 dup(?)
	_32KB	dd 2 dup(?)
	_64KB	dd 2 dup(?)
	_128KB	dd 2 dup(?)
	_256KB	dd 2 dup(?)
	_512KB	dd 2 dup(?)
ends

struct BLOCK_CHAIN
	_4KB	dd 256 dup(?)
	_8KB	dd 128 dup(?)
	_16KB	dd 64 dup(?)
	_32KB	dd 32 dup(?)
	_64KB	dd 16 dup(?)
	_128KB	dd 8 dup(?)
	_256KB	dd 4 dup(?)
	_512KB	dd 2 dup(?)
ends