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
		BHS		_zero_heap_done		; done if R0 >= R1
		
		STR		R2, [R0], #4		; store 0 at the current address and increment R0 by 4
		
		B		_zero_heap_loop
		
_zero_heap_done
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
		
		; resume registers
		LDMFD	SP!, {R4-R12, LR}
		MOV     PC, LR
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Recursive Memory Allocation
; void* _r_alloc( int size, int left, int right )
_ralloc
		; save registers
		STMFD   SP!, {R4-R12, LR}
		
		; calculate entire, half, midpoint, and heap address
		SUB		R3, R2, R1			; entire = right - left + mcb_ent_size
		ADD		R3, R3, #MCB_ENT_SZ
		LSR		R4, R3, #1			; half = entire / 2
		ADD		R5, R1, R4			; midpoint = left + half
		MOV		R6, #0				; heap_addr = 0 for now
		
		; calculate actual sizes
		LSL		R7, R3, #4			; act_entire_size = entire * 16
		LSL		R8, R4, #4			; act_half_size = half * 16
		
		CMP		R0, R8				; compare size & act_half_size
		BGT		_find_entire_space	; branch if size > act_half_size
		
		; ralloc left
		MOV		R2, R5, #MCB_ENT_SZ ; set right to midpoint - mcb_ent_size
		BL		_ralloc				; ralloc(size, left, (midpoint - mcb_ent_sz) )
		MOV		R6, R0				; update heap_addr with value returned from ralloc
		;; not sure if this is correct lol the returns are throwing me off
		
		CMP		R6, #0				; check if heap_addr uninitialized after ralloc left
		BNE		_split_parent_mcb	; branch if not empty
		
		; ralloc right
		MOV		R1, R5				; set left to midpoint
		BL		_ralloc				; ralloc(size, midpoint, right)
		
_split_parent_mcb
		AND		R9, [R5], #0x01		; check if available
		CMP		R9, #0
		BNE		_find_entire_space	; branch if not available
		
		STRH	R7, [R5]			; store act_half_size in midpoint address
		BL		_return_heap_addr
		
_find_entire_space
		AND		R9, [R1], #0x01		; check if available
		CMP		R9, #0
		BNE		_return_invalid		; branch if not available
		
		LDRH	R9, [R1]			; size_available = half-word from left address
		CMP		R9, R7				; compare size_available and act_entire_size
		BLT		_return_invalid		; branch if not enough size
		
		ORR		R9, R7, #0x01		; mark midpoint as used
		STRH	R9, [R5]
		;; return heap_top + (left - mcb_top) * 16 idk
		
_return_heap_addr

_return_invalid

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory De-allocation
; void _kfree( void *ptr )
		EXPORT	_kfree
_kfree
		; save registers
		STMFD   SP!, {R4-R12, LR}
		
		; validate the address
		LDR		R4, =HEAP_TOP
		LDR		R5, =HEAP_BOT
		CMP		R0,	R4				; check if ptr < HEAP_TOP
		BLT		_kfree_invalid		; if yes, return NULL
		CMP		R0, R5				; check if ptr > HEAP_BOT
		BGT		_kfree_invalid		; if yes return NULL
		
		; compute the MCB address corresponding to the address to be deleted
		LDR		R6, =MCB_TOP
		SUB		R7, R0, R4			; R7 = addr - HEAP_TOP
		LSR		R7, R7, #4			; R7 = (add - HEAP_TOP) / 16
		ADD		R7, R6, R7			; R7 = MCB_TOP + (addr - HEAP_TOP) / 16
		
		; call rfree to deallocate the memory
		MOV		R0, R7				; pass MCB address as argument
		BL		_rfree
		
		; check if _rfree succeeded
		CMP		R0, #0
		BEQ		_kfree_invalid		; if _rfree returned 0, return NULL
		
		; resume registers
		LDMFD	SP!, {R4-R12, LR}
		MOV     PC, LR
		
_kfree_invalid
		; return NULL
		MOV		R0, #0
		LDMFD	SP!, {R4-R12, LR}
		MOV     PC, LR
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Recursive Memory De-allocation
; int _rfree( int mcb_addr )
_rfree
		; save registers
		STMFD   SP!, {R4-R12, LR}
		
		; load MCB contents
		LDRH	R4, [R0]			; R4 =( short* )&array[ m2a( mcb_addr ) ] )
		BIC		R4, R4, #0x01		; clear the used bit
		STRH	R4, [R0]			; update MCB entry
		
		; calculate MCB offset and chunk size
		LDR		R5, =MCB_TOP
		SUB		R6, R0, R5			; R6 = mcb_offset = mcb_addr - MCB_TOP
		LSR		R7, R4, #4			; R7 = mcb_chunk = mcb_contents / 16
		LSL		R8, R7, #4			; R8 = my_size = mcb_chunk * 16
		
		; check if mcb_offset is left (even) or right (odd)
		UDIV	R9, R6, R7			; R9 = mcb_offset / mcb_chunk
		TST		R9, #0x01			; check if R9 is odd
		BNE		_rfree_right		; if odd, handle right case
		
_rfree_left
		; handle left case
		ADD		R10, R0, R7			; R10 = mcb_addr + mcb_chunk (buddy address)
		LDR		R11, =MCB_BOT
		CMP		R10, R11
		BHS		_rfree_done			; if buddy is beyond MCB_BOT, return mcb_addr
		
		; check if buddy is free and has the same size
		LDRH	R12, [R10]			; R12 = mcb_buddy contents
		TST		R12, #0x01			; check if buddy is used
		BNE		_rfree_done			; if used, return mcb_addr
		
		BIC		R12, R12, #0x1F		; clear bits 4-0 (size only)
		CMP		R12, R8				; check if buddy size == my_size
		BNE		_rfree_done			; if not, return mcb_addr
		
		; merge buddy into self
		MOV		R12, #0				; clear buddy
		STRH	R12, [R10]
		LSL		R8, R8, #1			; double size
		STRH	R8, [R0]			; update size
		
		; promote self
		B		_rfree
		
_rfree_right
		; handle right case
		
		;check if buddy is below MCB_TOP
		SUB		R10, R0, R7			; R10 = mcb_addr - mcb_chunk (buddy address)
		LDR		R11, =MCB_TOP
		CMP		R10, R11
		BLO		_rfree_done			; if buddy is below MCB_TOP, return mcb_addr
		
		; check if buddy is free and has the same size
		LDRH	R12, [R10]			; R12 = mcb_buddy contents
		TST		R12, #0x01			; check if buddy is used
		BNE		_rfree_done			; ; if not, return mcb_addr
		
		; merge self into buddy
		MOV		R12, #0				; clear self
		STRH	R12, [R0]
		LSL		R8, R8, #1			; double size
		STRH	R8, [R10]			; update buddy size
		
		; promote buddy
		MOV		R0, R10				; pass buddy address as arg
		B		_rfree
		
_rfree_done
		; return mcb_addr
		LDMFD	SP!, {R4-R12, LR}
		MOV     PC, LR
		
		END
