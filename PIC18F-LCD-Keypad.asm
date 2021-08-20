#include <p18F4520.inc>
	config wdt = off		; Watchdog off
	config pbaden = off		; Portb E/S numeriques



; LCD Pins
LCD_DATA    EQU	    PORTD   ; LCD data pins RD0-RD7
LCD_CTRL    EQU	    PORTC   ; LCD Control pins
RS	    EQU	    RC0	    ; RS pin of LCD
RW	    EQU	    RC1	    ; R/W pin of LCD
EN	    EQU	    RC2	    ;E pin of LCD

; Keypad Variables

D15mH	    EQU	    D'100'  ; 15 ms delay high byte of value
D15mL	    EQU	    D'255'  ; low byte of value
COL	    EQU	    0x08    ; holds the column found
DR15mH	    EQU	    0x09    ; registers for 15 ms delay
DR15mL	    EQU	    0x0A    ;
	    
;-----------------------------------------------------------

	    ORG 0x00
RESET_ISR   GOTO MAIN	    ;jump over interrupt table
	    
	    ORG 0x08
HI_ISR	
	    BTFSC INTCON,RBIF ; Was it a PORTB change
	    BRA RBIF_ISR    ;yes then go to ISR
	    RETFIE	    ;else return 
	

	    
MAIN
	    CALL    LCD_INIT
	    BCF	    INTCON2,RBPU;enable PORTB pull-up resistors 
	    MOVLW   0xF0	;make PORTB high input ports 
	    MOVWF   TRISB	;make PORTB low output ports 
	    MOVWF   PORTB	;ground all rows
KEYOPEN	
	    CPFSEQ  PORTB	; are	a11   keys   open
	    GOTO    KEYOPEN	;wait until keypad ready
	    MOVLW   upper(KCODE0)
	    MOVWF   TBLPTRU	;load upper byte of TBLPTR
	    MOVLW   high(KCODE0)
	    MOVWF   TBLPTRH	;load high byte of TBLPTR
	    BSF	    INTCON,RBIE ;enable PORTB change interrupt
	    BSF	    INTCON,GIE	;enable all interrupts globally
LOOP	    GOTO    LOOP

;LCD related fcn

COMNWRT	    
	    MOVWF LCD_DATA	; copy WREF to LCD DATA pin
	    BCF LCD_CTRL,RS	; RS=0 for command
	    BCF LCD_CTRL,RW	; R/W=0 for write
	    BSF LCD_CTRL,EN	; E=1 for high pulse
	    CALL DELAY		; make a wide Enable pulse
	    CALL DELAY		;
	    BCF LCD_CTRL,EN	; E=0 for H-to-L pulse
	    RETURN

LCD_INIT    
	    CLRF	TRISD	;PORTD = Output
	    CLRF	TRISC	;PORTC = Output
	    BCF		LCD_CTRL,EN ;enable idle low
	    CALL	DELAY	;wait for initialization
	    MOVLW	0x38  	;init. LCD 2 lines, 5x7 matrix 
	    CALL	COMNWRT	;call command subroutine
	    CALL	DELAY	;initialization hold 
	    MOVLW	0x0E	;display on, cursor on 
	    CALL	COMNWRT	;call command subroutine 
	    CALL	DELAY	;give LCD some time 
	    MOVLW	0x01	    ;clear LCD
	    CALL	COMNWRT	;call command subroutine 
	    CALL	DELAY	;give LCD some time 
	    MOVLW	0x06   	;shift cursor right
	    CALL	COMNWRT	;call command subroutine 
	    CALL	DELAY	;give LCD some time
	    MOVLW	0x84	;cursor at line 1, pos. 4 
	    CALL	COMNWRT	;call command subroutine 
	    CALL	DELAY	;give LCD some time
	    RETURN

; Keyboard related fcn


RBIF_ISR    
	    CALL DELAY	;wait for debounce
	    MOVFF PORTB,COL	;get the column of key press 
	    MOVLW 0xFE
	    MOVWF PORTB ;ground row 0
	    CPFSEQ PORTB ;Did PORTB change?
	    BRA	ROW0 ;yes then row 0
	    MOVLW 0xFC 
	    MOVWF PORTB ;ground row 1
	    CPFSEQ PORTB ;Did PORTB change?
	    BRA	ROW1 ;yes then row l
	    MOVLW 0xFB 
	    MOVWF PORTB ;ground row 2
	    CPFSEQ PORTB ;Did PORTB change?
	    BRA	ROW2 ;yes then row 2
	    MOVLW 0xF7 
	    MOVWF PORTB ;ground row 3
	    CPFSEQ PORTB ;Did PORTB change?
	    BRA	ROW3 ;yes then row 3
	    GOTO BAD_RBIF ;no then key press too short
ROW0	    MOVLW low(KCODE0) ;set TBLPTR =start of row 0
	    BRA FIND ;Find the colunmn
ROW1	    MOVLW low(KCODEl) ;set TBLPTR =start of row 1
	    BRA FIND ;Find the colunmn
ROW2	    MOVLW low(KCODE2) ;set TBLPTR =start of row 2
	    BRA FIND ;Find the colunmn
ROW3	    MOVLW low(KCODE3) ;set TBLPTR =start of row 3
	;BRA FIND ;Find the colunmn

FIND	    
	    MOVWF   TBLPTRL	;load low byte of TBLPTR
	    MOVLW   0xF0	
	    XORWF   COL		;invert high nibble
	    SWAPF   COL,F	;bring to low nibble

AGAIN	
	    RRCF    COL		;rotate to find column
	    BC	    MATCH	;column found, get the ASCII code
	    INCF    TBLPTRL	;else point to next col. address
	    BRA	    AGAIN	;keep searching

MATCH	    TBLRD*+		;get ASCII code from table 
	    MOVFF TABLAT, LCD_DATA
	    BSF LCD_CTRL,RS
	    BCF LCD_CTRL,RW
	    BSF LCD_CTRL,EN
	    CALL DELAY
	    CALL DELAY
	    BCF LCD_CTRL,EN
	    CALL DELAY
                

WAIT1	    MOVLW	0xF0
	    MOVWF	PORTB	;reset PORTB 
	    CPFSEQ	PORTB	;Did PORTB change?
	    BRA	WAIT1		;Yes then wait for key release 
	    BCF	INTCON,RBIF	;clear PORTB, change flag 
	    RETFIE		;return and wait for key press

BAD_RBIF    MOVLW 0x00		;return null
	    GOTO WAIT1		;wait for key release


DELAY	    MOVLW D15mH		;high byte of delay 
	    MOVWF DR15mH	;store in register 
D2	    MOVLW D15mL		;low byte of delay 
	    MOVWF DR15mL	;store in register

D1	    DECF DR15mL,F	;stay until DR15mL becomes 0
	    BNZ	D1
	    DECF DR15mH,F	;loop until all DRl5m = 0x0000
	    BNZ	D2
	    RETURN
	
	
	    ORG 300H
KCODE0	    DB  '0' , '1' , '2' , '3';ROW	0
KCODEl	    DB  '4' , '5' , '6' , '7';ROW	1
KCODE2	    DB  '8' , '9' , 'A' , 'B';ROW	2
KCODE3	    DB  'C' , 'D' , 'E' , 'F';ROW	3
	    END
