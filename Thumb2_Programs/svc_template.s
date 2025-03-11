		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table
SYSTEMCALLTBL	EQU		0x20007B00 ; originally 0x20007500
SYS_EXIT		EQU		0x0		; address 20007B00
SYS_ALARM		EQU		0x1		; address 20007B04
SYS_SIGNAL		EQU		0x2		; address 20007B08
SYS_MEMCPY		EQU		0x3		; address 20007B0C
SYS_MALLOC		EQU		0x4		; address 20007B10
SYS_FREE		EQU		0x5		; address 20007B14

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table Initialization
		EXPORT	_syscall_table_init
		IMPORT	_kalloc
		IMPORT	_kfree
		IMPORT	_timer_start
		IMPORT	_signal_handler
_syscall_table_init
		; Save registers
		STMFD   SP!, {R4-R12, LR}

		; load system call addresses
		LDR     R0, =SYSTEMCALLTBL

		; SYS_EXIT (0x0)
		LDR     R1, =_sys_exit
		STR     R1, [R0]		; store in base address

		; SYS_ALARM (0x1)
		LDR     R1, =_timer_start
		LDR     R2, =SYS_ALARM  ; get call table index
		LSL		R2, R2, #2		; offset = index mult by 4
		STR     R1, [R0, R2]	; store function address at base address + offset

		; SYS_SIGNAL (0x2)
		LDR     R1, =_signal_handler
		LDR     R2, =SYS_SIGNAL
		LSL		R2, R2, #2
		STR     R1, [R0, R2]

		; SYS_MEMCPY (0x3)
		LDR     R1, =_memcpy
		LDR     R2, =SYS_MEMCPY
		LSL		R2, R2, #2
		STR     R1, [R0, R2]

		; SYS_MALLOC (0x4)
		LDR     R1, =_kalloc
		LDR     R2, =SYS_MALLOC
		LSL		R2, R2, #2
		STR     R1, [R0, R2]

		; SYS_FREE (0x5)
		LDR     R1, =_kfree
		LDR     R2, =SYS_FREE
		LSL		R2, R2, #2
		STR     R1, [R0, R2]

		; Restore registers and return
		LDMFD	SP!, {R4-R12, LR}
		MOV     PC, LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table Jump Routine
        EXPORT	_syscall_table_jump
_syscall_table_jump
		; Save registers
		STMFD   SP!, {R4-R12, LR}
		
		; check R7 for what system call # we get, could this be why malloc isnt working? it might be because it's just never called
		CMP     R7, #1
		BEQ     alarm_call
				
		CMP     R7, #2
		BEQ     signal_call
				
		CMP     R7, #4
		BEQ     malloc_call
				
		CMP     R7, #5
		BEQ     free_call
		
; No match found or R7=0, just return
		B       exit
		
alarm_call ; R0 gets overwritten here, it's supposed to stay as 0x00000002
		PUSH    {R0}           ; Save R0 (seconds parameter)
		LDR     R1, =0x20007B04
		LDR     R2, [R1]       ; Load function address
		POP     {R0}           ; Restore R0 before call
		BX      R2 

signal_call
		LDR     R12, =0x20007B08
        LDR     R12, [R12]
        BX      R12

malloc_call
		LDR     R1, =0x20007B10
		LDR     R0, [R1]
		BX      R0

free_call
		LDR     R1, =0x20007B14
		LDR     R0, [R1]
		BX     R0

exit
		LDMFD   SP!, {R4-R12, LR}
		BX      LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; idk what's going on with these two lol
_sys_exit
		MOV     PC, LR

_memcpy
		MOV     PC, LR

		END
