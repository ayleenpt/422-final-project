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
			LDR     R1, =STCTRL
			MOV     R0, #STCTRL_STOP  ; Disable timer
			STR     R0, [R1]

			LDR     R1, =STRELOAD
			LDR     R0, =STRELOAD_MX  ; Load max value
			STR     R0, [R1]

			LDR     R1, =STCURRENT
			MOV     R0, #STCURR_CLR   ; Clear counter
			STR     R0, [R1]
			
			MOV		pc, lr		; return to Reset_Handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer start
; int timer_start( int seconds )
		EXPORT		_timer_start
_timer_start
	; Implement by yourself
			PUSH    {R4, LR}       ; Save registers

			LDR     R1, =SECOND_LEFT
			STR     R0, [R1]       ; Store seconds to SECOND_LEFT

			LDR     R1, =STCTRL
			MOV     R0, #STCTRL_GO ; Enable SysTick timer with interrupts
			STR     R0, [R1]

			POP     {R4, LR} 
			MOV		pc, lr		; return to SVC_Handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer update
; void timer_update( )
		EXPORT		_timer_update
_timer_update
	;; Implement by yourself
		PUSH    {R4, LR}        ; Save registers

		LDR     R1, =SECOND_LEFT
		LDR     R0, [R1]        ; Load current seconds left
		SUBS    R0, R0, #1      ; Decrement counter
		STR     R0, [R1]        ; Store updated counter

		BNE     _timer_update_done  ; If not zero, return

		; If counter reached zero, stop timer
		LDR     R1, =STCTRL
		MOV     R0, #STCTRL_STOP
		STR     R0, [R1]

		; Load user-defined handler from USR_HANDLER
		LDR     R1, =USR_HANDLER
		LDR     R1, [R1]
		CMP     R1, #0
		BEQ     _timer_update_done  ; Skip if no handler is set

		BLX     R1                 ; Call the user-defined handler

_timer_update_done
		POP     {R4, LR}
		MOV		pc, lr		; return to SysTick_Handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer update
; void* signal_handler( int signum, void* handler )
	    EXPORT	_signal_handler
_signal_handler
	; Implement by yourself
		PUSH    {R4, LR}

		LDR     R1, =USR_HANDLER
		LDR     R0, [R1]    ; Load previous function pointer

		STR     R1, [R1]    ; Store new function pointer

		POP     {R4, LR}
		MOV		pc, lr		; return to Reset_Handler
		
		END