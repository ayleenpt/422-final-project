		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Timer Definition
STCTRL		EQU		0xE000E010		; SysTick Control and Status Register
STRELOAD	EQU		0xE000E014		; SysTick Reload Value Register
STCURRENT	EQU		0xE000E018		; SysTick Current Value Register
	
STCTRL_STOP	EQU		0x00000004		; Bit 2 (CLK_SRC) = 1, Bit 1 (INT_EN) = 0, Bit 0 (ENABLE) = 0
STCTRL_GO	EQU		0x00000007		; Bit 2 (CLK_SRC) = 1, Bit 1 (INT_EN) = 1, Bit 0 (ENABLE) = 1
STRELOAD_MX	EQU		0x00FFFFFF		; MAX Value = 1/16MHz * 16M = 1 second
STCURR_CLR	EQU		0x00000000		; Clear STCURRENT and STCTRL.COUNT	
SIGALRM		EQU		14				; sig alarm

; System Variables
SECOND_LEFT		EQU		0x20007B80		; Secounds left for alarm( )
USR_HANDLER     EQU		0x20007B84		; Address of a user-given signal handler function	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer initialization
; void timer_init( )
		EXPORT		_timer_init
_timer_init
	; Implement by yourself
			STMFD   SP!, {R4-R12, LR}
			LDR     R1, =STCTRL
			MOV     R0, #STCTRL_STOP  ; Disable timer
			STR     R0, [R1]

			LDR     R1, =STRELOAD
			LDR     R0, =STRELOAD_MX  ; Load max value
			STR     R0, [R1]

;			LDR     R1, =STCURRENT
;			MOV     R0, #STCURR_CLR   ; Clear counter
;			STR     R0, [R1]
			
			LDMFD	SP!, {R4-R12, LR}
			BX		LR		; return to Reset_Handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer start
; int timer_start( int seconds )
		EXPORT		_timer_start
_timer_start ;;;;;;;;;;;; work on this, i think its section 5.3 
	; Implement by yourself (from claude)
			STMFD   SP!, {R4-R12, LR}
    
			; 1. Retrieve previous value from SECOND_LEFT
			LDR     R1, =SECOND_LEFT
			LDR     R4, [R1]        ; Store previous value in R4
			
			; 2. Save new seconds value from R0
			STR     R0, [R1]
			
			; 3. Clear STCURRENT
			LDR     R1, =STCURRENT
			MOV     R0, #STCURR_CLR
			STR     R0, [R1]
			
			; 4. Enable SysTick
			LDR     R1, =STCTRL
			MOV     R0, #STCTRL_GO
			STR     R0, [R1]
			
			; Return previous value
			LDMFD	SP!, {R4-R12, LR}
			BX      lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer update
; void timer_update( )

; System Variables
		EXPORT		_timer_update
_timer_update
		;; Implement by yourself
		
		STMFD   SP!, {R4-R12, LR}
		
		; read value at SECOND_LEFT
		LDR		R0, =SECOND_LEFT
		
		; decrement
		SUB		R0, R0, #1
		
		; if value hasn't reached 0, branch to timer update done
		CMP		R0, #0
		BNE		_timer_update_done
		
		; value has reached 0, stop timer
		BEQ		_timer_stop

_timer_update_done ; return to wherever it was called here
		POP     {R4, LR}
		LDMFD	SP!, {R4-R12, LR}
		BLX		LR		; return to SysTick_Handler

_timer_stop
		; load user function into R1
		LDR		R1, =USR_HANDLER
		
		; stop timer by writing STCTRL_STOP to STCTRL register
		; load both values into register or otherwise the thing complains
		LDR		R2, =STCTRL_STOP
		LDR		R3, =STCTRL
		STR		R2, [R3]
		
		; branch and link
		; stores where program is currently at in LR, then it calls function. so when we return to the callee, we know where to go.
		BLX		R1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer update
; void* signal_handler( int signum, void* handler )
; System Timer Definition
;STCTRL		EQU		0xE000E010		; SysTick Control and Status Register
;STRELOAD	EQU		0xE000E014		; SysTick Reload Value Register
;STCURRENT	EQU		0xE000E018		; SysTick Current Value Register
;	
;STCTRL_STOP	EQU		0x00000004		; Bit 2 (CLK_SRC) = 1, Bit 1 (INT_EN) = 0, Bit 0 (ENABLE) = 0
;STCTRL_GO	EQU		0x00000007		; Bit 2 (CLK_SRC) = 1, Bit 1 (INT_EN) = 1, Bit 0 (ENABLE) = 1
;STRELOAD_MX	EQU		0x00FFFFFF		; MAX Value = 1/16MHz * 16M = 1 second
;STCURR_CLR	EQU		0x00000000		; Clear STCURRENT and STCTRL.COUNT	
;SIGALRM		EQU		14				; sig alarm

;; System Variables
;SECOND_LEFT		EQU		0x20007B80		; Secounds left for alarm( )
;USR_HANDLER     EQU		0x20007B84		; Address of a user-given signal handler function	
	
	    EXPORT	_signal_handler
_signal_handler
	; Implement by yourself
		STMFD   SP!, {R4-R12, LR}
		
		CMP     R0, #SIGALRM       ; Check if it's SIGALRM (14)
		BNE     not_sigalrm
		
		LDR     R2, =USR_HANDLER
		MOV		R3, R2
		STR     R1, [R2]           
		MOV     R0, R3          
		
not_sigalrm
		LDMFD	SP!, {R4-R12, LR}
		BX      LR                ; Use BX instead of MOV pc, lr
		
		END