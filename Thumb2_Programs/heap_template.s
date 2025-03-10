		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table
HEAP_TOP	EQU		0x20001000
HEAP_BOT	EQU		0x20004FE0
MAX_SIZE	EQU		0x00004000		; 16KB = 2^14
MIN_SIZE	EQU		0x00000020		; 32B  = 2^5
	
MCB_TOP		EQU		0x20006800      	; 2^10B = 1K Space
MCB_BOT		EQU		0x20006BFE
MCB_ENT_SZ	EQU		0x00000002		; 2B per entry
MCB_TOTAL	EQU		512			; 2^9 = 512 entries
	
INVALID		EQU		-1			; an invalid id
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Memory Control Block Initialization
		EXPORT	_heap_init
_heap_init
		; set mcb[0] to 0x4000
		LDR     R0, =MCB_TOP
		LDR     R1, =MAX_SIZE
		STRH    R1, [R0]
		
		; zero-initialize the remaining MCB entries
		LDR		R2, =MCB_TOTAL
		MOVS	R3, #0
		ADDS	R0, #2

_zero_loop
		STRH	R3, [R0]
		ADDS	R0, #2
		SUBS	R2, #1
		BNE		_zero_loop

		MOV		PC, LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory Allocation
; void* _k_alloc( int size )
		EXPORT	_kalloc
_kalloc
		; save return address and input size
		STMFD   SP!, {R4-R12, LR}
		PUSH	{R0}
		
		; call _ralloc with the full range of the heap
		LDR		R0, =MCB_TOP
		LDR		R1, =MCB_BOT
		BL		_ralloc
		
		; restore the return address and return
		POP		{R0}
		LDMFD	SP!, {R4-R12, LR}		
		MOV		PC, LR
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Helper function for kernel memory allocation
; void _ralloc
		EXPORT _ralloc
_ralloc
		; save registers
		STMFD   SP!, {R4-R12, LR}

		; load the requested size from the stack
		LDR     R2, [SP, #20]

		; check if the current block is free
		LDRH    R3, [R0]
		CMP     R3, #0
		BEQ     _ralloc_fail

		; check if the current block is large enough
		CMP     R3, R2
		BLT     _ralloc_fail

		; check if the block can be split further
		LSR     R4, R3, #1
		CMP     R4, R2
		BLT     _ralloc_allocate

		; split the block into two halves
		STRH    R4, [R0]
		ADD     R5, R0, R4, LSL #1
		STRH    R4, [R5]

		; recursively call _ralloc on the left half
		BL      _ralloc

		; if the left half allocation failed, try the right half
		CMP     R0, #INVALID
		BNE     _ralloc_success

		; recursively call _ralloc on the right half
		ADD     R0, R0, R4, LSL #1
		BL      _ralloc

		; if the right half allocation failed, return failure
		CMP     R0, #INVALID
		BEQ     _ralloc_fail

_ralloc_success
		; return the address of the allocated block
		LDMFD	SP!, {R4-R12, LR}
		BX      LR

_ralloc_allocate
		; allocate the current block
		MOV     R6, #1
		ORR     R3, R3, R6
		STRH    R3, [R0]
		MOV     R0, R0
		POP     {R4-R7, LR}
		BX      LR

_ralloc_fail
		; return failure
		MOV     R0, #INVALID
		POP     {R4-R7, LR}
		BX      LR
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory De-allocation
; void free( void *ptr )
		EXPORT	_kfree
_kfree
		; save return address and input pointer
		PUSH	{LR}
		PUSH	{R0}
		
		; calculate the MCB entry for the pointer
		LDR		R1, =HEAP_TOP
		SUBS	R0, R0, R1
		LSRS	R0, R0, #5
		LSLS	R0, R0, #1
		LDR		R1, =MCB_TOP
		ADDS	R0, R0, R1
		
		; call _rfree to recursively free and merge the block
		BL		_rfree
		
		; restore the return address and return
		POP		{R0}
		POP		{LR}		
		MOV		PC, LR
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Helper function for kernel memory de-allocation
; void _rfree
		EXPORT _rfree
_rfree
		; save registers
		PUSH	{R4, R7, LR}
		
		; mark the block as free by clearing the allocated bit
		LDRH	R1, [R0]
		BIC		R1, R1, #1
		STRH	R1, [R0]
		
		; calculate the buddy's MCB entry address
		LDR		R2, =MCB_TOP
		SUBS	R3, R0, R2
		LSRS	R3, R3, #1
		EORS	R3, R3, #1
		LSLS	R3, R3, #1
		ADDS	R3, R3, R2
		
		; check if the buddy is free
		LDRH	R4, [R3]
		TST		R4, #1
		BNE		_rfree_done
		
		; merge the current block with its buddy
		LSLS	R5, R1, #1
		STRH	R5, [R0]
		MOVS	R6, #0
		STRH	R6, [R3]
		
		; recursively check the higher-level buddy
		BL		_rfree
		
_rfree_done
		; restore registers and return
		POP		{R4-R7, LR}
		BX		LR
		
		END
