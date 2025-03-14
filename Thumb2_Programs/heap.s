		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table
HEAP_TOP	EQU		0x20001000
HEAP_BOT	EQU		0x20004FE0
MAX_SIZE	EQU		0x00004000		; 16KB = 2^14
MIN_SIZE	EQU		0x00000020		; 32B  = 2^5

MCB_TOP		EQU		0x20006800 		; 2^10B = 1K Space
MCB_BOT		EQU		0x20006BFE
MCB_ENT_SZ	EQU		0x00000002		; 2B per entry
MCB_TOTAL	EQU		512				; 2^9 = 512 entries

INVALID		EQU		-1				; an invalid id

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Memory Control Block Initialization
		EXPORT	_heap_init
_heap_init
		; zero out the heap space
		LDR		R0, =HEAP_TOP
		LDR		R1,	=HEAP_BOT
		MOV		R2, #0
		
_zero_heap_loop
		CMP		R0, R1
		BHS		_initialize_mcb		; done if R0 >= R1
		
		STR		R2, [R0], #4		; store 0 at the current address and increment R0 by 4
		
		B		_zero_heap_loop
		
_initialize_mcb
		; initialize the MCB
		LDR		R0, =MCB_TOP
		LDR		R1, =MAX_SIZE
		BIC		R1, R1, #0x01		; clear the least significant bit
		STRH	R1, [R0]			; store the max size in the first entry of the MCB
		
		LDR		R0, =MCB_TOP + 2	; load the address of the second entry in the MCB
		LDR		R1, =MCB_BOT		; load the end address of the MCB
		MOV		R2, #0
		
_zero_mcb_loop
		CMP		R0, R1
		BHS		_zero_mcb_done		; done if R0 >= R1
		
		STRH	R2, [R0], #2		; store 0 at the current address and increment R0 by 2
		
		B		_zero_mcb_loop
		
_zero_mcb_done
		MOV		PC, LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory Allocation
; void* _k_alloc( int size )
		EXPORT	_kalloc
_kalloc
		; save registers
		STMFD   SP!, {R4-R12, LR}
		
		; ensure min size of 32 bytes
		CMP     R0, #MIN_SIZE
		MOVLO   R0, #MIN_SIZE
		
		; call _ralloc with initial parameters
		LDR     R1, =MCB_TOP        ; left
		LDR     R2, =MCB_BOT        ; right
		BL      _ralloc
		
		MOV		R0, R8
		
		; resume registers
		LDMFD	SP!, {R4-R12, LR}
		MOV     PC, LR
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Recursive Memory Allocation
; void* _ralloc( int size, int left, int right )
_ralloc
		; calculate sizes
		SUB		R3, R2, R1			; entire = right - left + mcb_ent_size
		ADD		R3, R3, #MCB_ENT_SZ
		LSR		R4, R3, #1			; half = entire / 2
		ADD		R5, R1, R4			; midpoint = left + half
		LSL		R6, R3, #4			; act_entire_size = entire * 16
		LSL		R7, R4, #4			; act_half_size = half * 16
		MOV		R8, #0				; heap_addr = 0 to start
		
		CMP		R0, R7				; compare size & act_half_size
		BGT		_ralloc_full		; branch if size > act_half_size
		
		
		
		; if size can fit inside act_half_size
_ralloc_left
		PUSH	{R0-R7, LR}			; store sizes for current invocation

		SUB		R2, R5, #MCB_ENT_SZ ; right = midpoint - mcb_ent_size
		BL		_ralloc				; heap_addr = ralloc(size, left, (midpoint - mcb_ent_sz) )
		
		POP		{R0-R7, LR}			; restore sizes
	
		CMP		R8, #INVALID		; branch if ralloc left succeeded
		BNE		_split_parent_mcb
		
		; if ralloc left failed, try ralloc right
_ralloc_right
		PUSH	{R0-R7, LR}			; store sizes for current invocation
		MOV		R1, R5				; left = midpoint
		BL		_ralloc				; ralloc(size, midpoint, right)
		POP		{R0-R7, LR}			; restore sizes
		CMP		R8, #INVALID		; branch if ralloc right failed
		BEQ		_return_invalid
		
_split_parent_mcb
		LDRH	R9, [R5]			; check if midpoint is marked as used
		TST		R9, #0x01			; 1 == used 0 == free
		BNE		_return_heap_addr	; branch if used
		
		STRH	R7, [R5]			; store act_half_size in midpoint address
		B		_return_heap_addr
		
_ralloc_full
		LDR		R9, [R1]			; check if left is marked as used
		TST		R9, #0x01			; 1 == used 0 == free
		BNE		_return_invalid		; branch if used
		
		LDR		R9, [R1]			; compare size_available and act_entire_size
		CMP		R9, R6
		BLT		_return_invalid		; branch if not enough space
		
		ORR		R9, R6, #0x01		; mark left as used with act_entire_size | 0x01
		STRH	R9, [R1]
		
		; calculate heap_addr = heap_top + (left - mcb_top) * 16
		LDR		R9, =MCB_TOP
		SUB		R8, R1, R9			; R8 = left - mcb_top
		LSL		R8, R8, #4			; R8 = (left - mcb_top) * 16
		LDR		R9, =HEAP_TOP
		ADD		R8, R8, R9			; R8 = heap_top + (left - mcb_top) * 16
		B		_return_heap_addr

_return_invalid
		MOV		R8, #INVALID

_return_heap_addr
		MOV		PC, LR
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory De-allocation
; void _kfree( void *ptr )
		EXPORT	_kfree
_kfree
		; save registers
		STMFD   SP!, {R4-R12, LR}
		
		; validate the address
		LDR		R1, =HEAP_TOP
		LDR		R2, =HEAP_BOT
		CMP		R0,	R1				; return INVALID if ptr < HEAP_TOP
		BLT		_kfree_invalid
		CMP		R0, R2				; return INVALID if ptr > HEAP_BOT
		BGT		_kfree_invalid
		
		; compute the MCB address corresponding to the address to be deleted
		; mcb_addr = MCB_TOP + (addr - HEAP_TOP) / 16
		LDR		R3, =MCB_TOP
		SUB		R0, R0, R1			; mcb_addr = addr - HEAP_TOP
		LSR		R0, R0, #4			; mcb_addr = mcb_addr / 16
		ADD		R0, R0, R3			; mcb_addr = mcb_addr + MCB_TOP
		
		; call rfree to deallocate the memory
		BL		_rfree
		
		; return #0 if _rfree failed
		CMP		R0, #INVALID
		BNE		_kfree_done
		
_kfree_invalid
		; return NULL
		MOV		R0, #0
		
_kfree_done
		; resume registers & return
		LDMFD	SP!, {R4-R12, LR}
		MOV     PC, LR
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Recursive Memory De-allocation
; int _rfree( int mcb_addr )
_rfree
		; save registers
		STMFD   SP!, {R4-R12, LR}

		LDR		R9, =MCB_TOP
		LDRH	R1, [R0]			; load mcb_contents
		SUB		R2, R0, R9			; mcb_offset = mcb_addr - mcb_top
		LSR		R1, R1, #4			; div mcb_contents by 16
		MOV		R3, R1				; mcb_chunk = mcb_contents
		LSL		R1, R1, #4			; mult mcb_contents by 16, this clears the used bit
		MOV		R4, R1				; my_size = mcb_contents
		STRH	R1, [R0]			; store mcb_contents with used bit cleared

		UDIV	R9, R2, R3			; left_or_right = mcb_offset / mcb_chunk
		TST		R9, #0x01			; left == 0 right == 1
		BNE		_rfree_right
		
_rfree_left
		ADD		R5, R0, R3			; buddy_address = mcb_addr + mcb_chunk, buddy = [R5]
		
		LDR		R9, =MCB_BOT		; return INVALID if buddy_address >= HEAP_BOT
		CMP		R5, R9
		BGE		_rfree_invalid
		
		LDRH	R9, [R5]			; return mcb_addr if buddy is marked as used
		TST		R9, #0x01			; 1 == used 0 == free
		BNE		_rfree_done
		
		; mcb_buddy = ( mcb_buddy / 32 ) * 32 to clear bits 4-0
		LSR		R5, R5, #5			; div by 32
		LSL		R5, R5, #5			; mult by 32
		
		LDR		R9, [R5]			; return mcb_addr if buddy != my_size
		CMP		R9, R4
		BNE		_rfree_done
		
		MOV		R9, #0
		STRH	R9, [R5]			; clear buddy
		LSL		R4, R4, #1			; double my size
		STRH	R4, [R0]			; merge buddy
		BL		_rfree				; promote myself
		
_rfree_right
		SUB		R5, R0, R3			; buddy_address = mcb_addr - mcb_chunk, buddy = [R5]
		
		LDR		R9, =MCB_TOP		; return INVALID if buddy_address < MCB_TOP
		CMP		R5, R9
		BLT		_rfree_invalid
		
		LDRH	R9, [R5]			; return mcb_addr if buddy is marked as used
		TST		R9, #0x01			; 1 == used 0 == free
		BNE		_rfree_done
		
		; mcb_buddy = ( mcb_buddy / 32 ) * 32 to clear bits 4-0
		LSR		R5, R5, #5			; div by 32
		LSL		R5, R5, #5			; mult by 32
		
		LDR		R9, [R5]			; return mcb_addr if buddy != my_size
		CMP		R9, R4
		BNE		_rfree_done
		
		MOV		R9, #0
		STRH	R9, [R0]			; clear myself
		LSL		R4, R4, #1			; double my size
		STRH	R4, [R5]			; merge me to buddy
		MOV		R0, R5				; promote buddy
		BL		_rfree

_rfree_invalid
		MOV		R0, #INVALID
		
_rfree_done
		LDMFD	SP!, {R4-R12, LR}
		MOV		PC, LR
		END