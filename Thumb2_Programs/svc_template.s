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
		STMFD   SP!, {R4-R12, LR}   ; Save registers

        CMP     R7, #2              ; Check if syscall is _signal (SYS_SIGNAL)
        BNE     normal_syscall      ; If not, handle normally

        ; Special case: _signal syscall
        LDR     R1, =SYSTEMCALLTBL  
        LSL     R0, R4, #2          ; Calculate offset
        ADD     R1, R1, R0  
        LDR     R1, [R1]            ; Load function pointer

        CMP     R1, #0              ; Ensure function pointer is valid
        BEQ     syscall_done

        ; Call the function, preserving R0 (SIGALRM value)
        BLX     R1                  
        B       syscall_done

normal_syscall
        LDR     R1, =SYSTEMCALLTBL  
        LSL     R0, R4, #2  
        ADD     R1, R1, R0  
        LDR     R1, [R1]            

        CMP     R1, #0              
        BEQ     syscall_done

        MOV     R0, R4              
        BLX     R1                  

syscall_done
        LDMFD   SP!, {R4-R12, LR}  
        BX      LR

;		; Save registers
;		STMFD   SP!, {R4-R12, LR}

;		; Load the system call number from R0
;		LDR     R1, =SYSTEMCALLTBL    ; Load the base address of the system call table
;		LSL     R0, R0, #2            ; Multiply the system call number by 4 (each entry is 4 bytes)
;		ADD     R1, R1, R0            ; Calculate the address of the system call table entry
;		LDR     R1, [R1]              ; Load the address of the function from the system call table

;		; Jump to the function
;		BLX     R1                    ; Branch with link and exchange (call the function)

;		; Restore registers and return
;		LDMFD	SP!, {R4-R12, LR}
;		BX		LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; idk what's going on with these two lol
_sys_exit
		MOV     PC, LR

_memcpy
		MOV     PC, LR

		END
