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
		BHS		zero_heap_done		; done if R0 >= R1
		
		STR		R2, [R0], #4		; store 0 at the current address and increment R0 by 4
		
		B		zero_heap_loop
		
_zero_heap_done
		; initialize the MCB
		LDR		R0, =MCB_TOP
		LDR		R1, =MAX_SIZE
		STRH	R1, [R0]			; store the max size in the first entry of the MCB
		
		LDR		R0, =MCB_TOP + 2	; load the address of the second entry in the MCB
		LDR		R1, =MCB_BOT		; load the end address of the MCB
		MOV		R2, #0
		
_zero_mcb_loop
		CMP		R0, R1
		BHS		_zero_mcb_done		; done if R0 >= R1
		
		STRH	R2, [R0], #2		; store 0 at the current address and increment R0 by 2
		
		B		zero_mcb_loop
		
_zero_mcb_done
		MOV		PC, LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory Allocation
; void* _k_alloc( int size )
		EXPORT	_kalloc
_kalloc
	;; Implement by yourself
		MOV		pc, lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory De-allocation
; void free( void *ptr )
		EXPORT	_kfree
_kfree
	;; Implement by yourself
		MOV		pc, lr					; return from rfree( )

		END
