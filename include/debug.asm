macro DebugMessage string
{
	push eax
	local label
	local nome
	mov ebx, label
	call PrintK_def
	pop eax
	jmp nome
	label db string
	db 13,0
	nome:
}