		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void _bzero( void *s, int n )
; Parameters
;	s 		- pointer to the memory location to zero-initialize
;	n		- a number of bytes to zero-initialize
; Return value
;   none
		EXPORT	_bzero
_bzero
		STMFD   SP!, {R1-R12,LR}
        MOV     R3, R0            ; Save original pointer
        MOV     R2, #0            ; Value to store (zero)
bzero_loop
        SUBS    R1, R1, #1        ; Decrement counter
        BMI     bzero_return      ; Branch if negative (done)
        STRB    R2, [R0], #1      ; Store byte and increment pointer
        B       bzero_loop        ; Continue loop
bzero_return
        MOV     R0, R3            ; Restore original pointer
        LDMFD   SP!, {R1-R12,LR}  ; Restore registers
        BX		LR           ; Return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; char* _strncpy( char* dest, char* src, int size )
; Parameters
;   	dest 	- pointer to the buffer to copy to
;	src	- pointer to the zero-terminated string to copy from
;	size	- a total of n bytes
; Return value
;   dest
		EXPORT	_strncpy
_strncpy
		STMFD   SP!, {R1-R12,LR}  ; Save registers
        MOV     R3, R0            ; Save original destination pointer
_strncpy_loop
        SUBS    R2, R2, #1        ; Decrement size counter
        BMI     _strncpy_return   ; Branch if negative (done)
        LDRB    R4, [R1], #1      ; Load byte from src and increment
        STRB    R4, [R0], #1      ; Store byte to dest and increment
        CMP     R4, #0            ; Check if null terminator
        BEQ     _strncpy_return   ; If null, we're done
        B       _strncpy_loop     ; Continue loop
_strncpy_return
        MOV     R0, R3            ; Return original destination pointer
        LDMFD   SP!, {R1-R12,LR}  ; Restore registers
        BX		LR
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void* _malloc( int size )
; Parameters
;	size	- #bytes to allocate
; Return value
;   	void*	a pointer to the allocated space
		EXPORT	_malloc
_malloc
		; save registers
		STMFD   SP!, {R4-R12, LR}
		
		; set the system call # to R7
		MOV		R7, #4
		SVC     #0x4
		
		; resume registers
		LDMFD	SP!, {R4-R12, LR}
		BX		LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void _free( void* addr )
; Parameters
;	size	- the address of a space to deallocate
; Return value
;   	none
		EXPORT	_free
_free
		; save registers
		STMFD   SP!, {R4-R12, LR}
		
		; set the system call # to R7
		MOV		R7, #5
		SVC     #0x5
		
		; resume registers
		LDMFD	SP!, {R4-R12, LR}
		BX		LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; unsigned int _alarm( unsigned int seconds )
; Parameters
;   seconds - seconds when a SIGALRM signal should be delivered to the calling program	
; Return value
;   unsigned int - the number of seconds remaining until any previously scheduled alarm
;                  was due to be delivered, or zero if there was no previously schedul-
;                  ed alarm. 
		EXPORT	_alarm
_alarm
		; Save registers
        PUSH    {R1-R12, LR}

        ; Set system call number for alarm
        MOV        R7, #1
        SVC        #0x1

        ; Restore registers
        POP        {R1-R12, LR}
        BX			LR		
			
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void* _signal( int signum, void *handler )
; Parameters
;   signum - a signal number (assumed to be 14 = SIGALRM)
;   handler - a pointer to a user-level signal handling function
; Return value
;   void*   - a pointer to the user-level signal handling function previously handled
;             (the same as the 2nd parameter in this project)
		EXPORT	_signal
_signal
		; Save registers
        PUSH    {R2-R12, LR}

        ; Set system call number for signal
        MOV        R7, #2
        SVC        #0x2

        ; Restore registers
        POP        {R2-R12, LR}
        BX			LR  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		END			
