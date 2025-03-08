		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IMPORT _kfree
IMPORT _kalloc
IMPORT _signal_handler
IMPORT _timer_start

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
_syscall_table_init
		; Save registers
		PUSH    {R4, LR}

		; load system call addresses
		LDR     R0, =SYSTEMCALLTBL

		; SYS_EXIT (0x0)
		LDR     R1, =_sys_exit
		STR     R1, [R0, #SYS_EXIT]

		; SYS_ALARM (0x1)
		LDR     R1, =_timer_start
		STR     R1, [R0, #SYS_ALARM]

		; SYS_SIGNAL (0x2)
		LDR     R1, =_signal_handler
		STR     R1, [R0, #SYS_SIGNAL]

		; SYS_MEMCPY (0x3)
		LDR     R1, =_memcpy
		STR     R1, [R0, #SYS_MEMCPY]

		; SYS_MALLOC (0x4)
		LDR     R1, =_kalloc
		STR     R1, [R0, #SYS_MALLOC]

		; SYS_FREE (0x5)
		LDR     R1, =_kfree
		STR     R1, [R0, #SYS_FREE]

		; Restore registers and return
		POP     {R4, LR}
		MOV     PC, LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table Jump Routine
        EXPORT	_syscall_table_jump
_syscall_table_jump
		; Save registers
		PUSH    {R4, LR}

		; Load the system call number from R0
		LDR     R1, =SYSTEMCALLTBL    ; Load the base address of the system call table
		LSL     R0, R0, #2            ; Multiply the system call number by 4 (each entry is 4 bytes)
		ADD     R1, R1, R0            ; Calculate the address of the system call table entry
		LDR     R1, [R1]              ; Load the address of the function from the system call table

		; Jump to the function
		BLX     R1                    ; Branch with link and exchange (call the function)

		; Restore registers and return
		POP     {R4, LR}
		MOV     PC, LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; idk what's going on with these two lol
_sys_exit
		MOV     PC, LR

_memcpy
		
		MOV     PC, LR

		END		
