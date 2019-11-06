;##############################################################################
;				MEMORY MANAGER
; Contain procedures for memory management on Mylo
; joseph dias, 2016@03.2019
;##############################################################################
; Exported functions
; InitializeBlockList	- Fill BlockList structure with the free memory to be
;			- used by system
; InitializeMemoryManger - Used to initialize memory management
; AllocBlockDescriptor	- Allocate a block descriptor to be used with AllocMemory
; AllocMemory		- Allocate a block of memory
; AllocPages		- Allocate a block of memory from Buddy Allocator
;==============================================================================
virtual at 0
	VBD	BLOCK_DESCRIPTOR
end virtual

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
G_BlockDescriptor BLOCK_DESCRIPTOR

InitializeMemoryManager:

	mov [G_BlockDescriptor.Size], 1000h
	mov edx, G_BlockList
	mov ebx, G_BlockDescriptor
	call AllocPages
	mov edi, [G_BlockDescriptor.Address]
	xor eax,eax
	mov ecx, 1000h/4
	rep stosd
	ret
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
AllocBlockDescriptor:
	mov ecx, [G_BlockDescriptor.Size]
	shr ecx, 3
	mov esi, [G_BlockDescriptor.Address]
;<<**************************
repeat_search_blockdescriptor:
	cmp dword [esi], 0
	je block_descriptor_found
	add esi, 8
	dec ecx
	test ecx,ecx
	jnz repeat_search_blockdescriptor
;**************************>>
	mov eax, -1
	ret
block_descriptor_found:
	mov eax, esi
	ret	
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
; ebx = Size in bytes
AllocMemory:
	push esi edi
	push ebx
	call AllocBlockDescriptor
	cmp eax, -1
	je alloc_memory_error
	pop ebx
	mov [eax+VBD.Size], ebx
	mov edx, G_BlockList
	mov ebx, eax
	mov esi, eax
	call AllocPages
	mov eax, [esi+VBD.Address]
	jmp alloc_memory_exit
alloc_memory_error:
	pop ebx
alloc_memory_exit:
	pop edi esi
	ret
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
; ebx = Block list Address
; edx = number of page frames
; ecx = Physical Address of block memory
Lblocklist dd 0
Lpfn_count dd 0
align 32
InitializeBlockList:	 
;===========================================================================
; initialize physical memory block list

	push edi esi ebp
; ebp = address of the memory space
	mov ebp, ecx
; clear the BlockChain
	xor eax,eax
	mov edi, BLOCK_CHAIN_ADDRESS
	mov ecx,  sizeof.BLOCK_CHAIN/4
	rep stosd

	mov [Lpfn_count],edx
	mov [Lblocklist],ebx
	mov eax,edx
	mov ecx,7*8
	mov ebx,(512*_KB)/PF_SIZE
	mov esi,[Lblocklist]

;<< 1 *********************************
_repeat_set_free_blocks:
; eax = number of page frames
; ebx = number of page frames for high block size (512KB), result is eax = number of blocks with 512KB
    xor edx,edx
    div ebx
    test eax,eax
    jnz set_entry_set_free_blocks
    ; if the result is 0, set the blocklist stack as empty with the -1 value
    mov dword [esi+ecx+4],-1
    test edx,edx
    jz set_entry_set_free_blocks
    mov eax,edx
    shr ebx, 1
    jz exit_set_free_blocks
    sub ecx,8
    jnz _repeat_set_free_blocks

set_entry_set_free_blocks:
    push edx	 ; save the division reminder ( rest of pages)
    push ebx	 ; save the block size
    xchg eax,ecx
; ecx = number of blocks with this size free
; eax = block chain index into block list
    shl ebx, 12 			; the size of the block in bytes
    xor edx,edx ;[BLOCK_LIST+eax+4]	; stack point of the block chain
    mov edi,[esi+eax]			; get the address of the block chain
;<<************************************
; edi = block chain base
; edx = block chain stack pointer
repeat_set_free_blocks:
    mov dword [edi+edx], ebp ; save the beging of the block (Effective address)
    add ebp,ebx
    add edx, 4
    loop repeat_set_free_blocks
;************************************>>
    mov dword [esi+eax+4],edx	  ; save the stack pointer of the chain
    pop ebx
    pop edx
;------------------------------------------------
    mov ecx,eax
    test edx,edx
    jz exit_set_free_blocks
    mov eax,edx
    shr ebx,1
    jz exit_set_free_blocks
    sub ecx,8
    jnz _repeat_set_free_blocks
;********************************* 1 >>
exit_set_free_blocks:
    pop ebp esi edi
    ret
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
; alloc a number of pyhical pages from	block allocator
; ebx = Address of a block descriptor
; edx = Address of the blocklist
AllocPages: ; Block_descriptor, address of the blocklist
	push esi edi

	xor eax,eax
	mov esi,ebx
	mov edi,edx
	mov eax,[esi+VBD.Size]
	test eax,eax
	jz exit_KMM_alp
	shr eax,12				; divide by the size
	xor ecx,ecx				; of the page frame
; Search the index of the block
; that match with the request.
; One block in block allocator
; is represented by just one
; bit of 32
;<<************************************
reapeat_KMM_alp:
	shr eax,1				; shift and set cf flag with
	jc reapeat_KMM_alp_exit ; the lower bit before it appear
	jz  exit_KMM_alp		; on left of register
	inc ecx
	jmp reapeat_KMM_alp
;************************************>>
reapeat_KMM_alp_exit:
; ecx contain block index
	shl ecx,3				; multiply by 8
	mov ebx,[edi+ecx+BLOCKLIST_ENTRY_SIZE/2]
	cmp ebx,0
; jump if exist a block free
	jnl get_free_block
;--------------------------------------
	add ecx,8
	xor ebx,ebx
	mov ebx,[esi+VBD.Size]
; shr ebx,12  size in pages
; shl ebx,1   multiply by 2
; = shr ebx,11
; edx count the number of index
; until reach the next free block
	shr ebx,11
	xor edx,edx
	inc edx
;--------------------------------------
; search the next block free
;<<************************************
repeat_getnextblock_KMM_alp:
	mov eax,[edi+ecx+BLOCKLIST_ENTRY_SIZE/2]
	cmp eax,0
	jge split_block ; jump if reach an available block
	cmp ecx, 8 * BLOCKLIST_ENTRY_SIZE
	jz  no_block_free_KMM_alp
	add ecx,BLOCKLIST_ENTRY_SIZE
	shl ebx,1 ; multiply the size by 2
	inc edx
	jmp repeat_getnextblock_KMM_alp
;************************************>>
;--------------------------------------
;split the next block
; after get the next block free.
; split it and fill the blocks bellow
; until reach the size of the block
; requested
split_block:
	push ebp
	push esi
	;mov eax,ebx
	shr ebx,1		; size of the block splited
; edi = blocklist
; esi = BlockChain array
	mov eax,[edi+ecx+4]	 ; stack pointer of the block chain
	mov esi,[edi+ecx]	 ; address of the block chain
	sub eax,4
	mov ebp, dword [esi+eax]	; address of the block on memory map
	mov dword [esi+eax], 0 ; clear the blockchain entry
	test eax,eax
	jnz  get_one_block_split_block
	mov eax,-1     ; set block chain as empty if exist
get_one_block_split_block:
	mov dword [edi+ecx+4], eax
continue_split_block:
	sub ecx,BLOCKLIST_ENTRY_SIZE
; ecx is used to count the number of times needed to
; reach the block level requested
	xchg ecx,edx
; ebx = size of the block in bytes
	shl ebx,12
;<<************************************
_repeat_set_free_blocks_KMM_alp:
; get the block chain and stack pointer
; esi = blockchain base, eax = stackpointer
	mov eax,[edi+edx+4]
	mov esi,[edi+edx]		 ; get the address of the block chain
	cmp eax,0
	jl  fixentry_repeat_set_free_blocks_KMM_alp
	mov dword [esi+eax],ebp 	  ; save the beging of the block
	add ebp,ebx			  ; now ebp cotain the upper half of the block
	add eax, 4
	jmp continue_repeat_set_free_blocks_KMM_alp
fixentry_repeat_set_free_blocks_KMM_alp:
; if the block chain is empty, set the
; stack pointer to 0, because it is
; -1 to represent a empty block.
	xor eax,eax
	mov dword [esi+eax],ebp ; save the beging of the block
	add ebp,ebx
	add eax, 4
continue_repeat_set_free_blocks_KMM_alp:
	mov dword [edi+edx+4],eax
	shr ebx,1
	sub edx, BLOCKLIST_ENTRY_SIZE
;------------------------------------------------
	loop _repeat_set_free_blocks_KMM_alp
;************************************>>
;return the address of the block requested
	pop esi
	mov [esi+VBD.Address],ebp
	pop ebp edi esi
	ret
;%%%%%%%%%%%%%%%%%%
;======================================
; the the block is free and match with
; the request
get_free_block:
	mov edx,[edi+ecx]	; address of the block chain
	sub ebx,4
	mov dword eax,[edx+ebx]
	test ebx,ebx
	jz set_block_empty
	mov [edi+ecx+BLOCKLIST_ENTRY_SIZE/2], ebx
	mov [esi+VBD.Address],eax
	pop edi esi
	ret
set_block_empty:
	mov dword [edi+ecx+BLOCKLIST_ENTRY_SIZE/2],-1
	mov [esi+VBD.Address],eax
	pop edi esi
	ret
 ;%%%%%%%%%%%%%%%%%%
exit_KMM_alp:
no_block_free_KMM_alp:
	mov eax,-1
	pop edi esi
	ret
;%%%%%%%%%%%%%%%%%%
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
