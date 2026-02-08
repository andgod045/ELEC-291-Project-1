; 76E003 ADC test program: Reads channel 7 on P1.1, pin 14, and read channel 5 on P0.4 (20)
; This version uses the LM4040 voltage reference connected to pin 6 (P1.7/AIN0)

$NOLIST
$MODN76E003
$LIST

;  N76E003 pinout:
;                               -------
;       PWM2/IC6/T0/AIN4/P0.5 -|1    20|- P0.4/AIN5/STADC/PWM3/IC3
;               TXD/AIN3/P0.6 -|2    19|- P0.3/PWM5/IC5/AIN6
;               RXD/AIN2/P0.7 -|3    18|- P0.2/ICPCK/OCDCK/RXD_1/[SCL]
;                    RST/P2.0 -|4    17|- P0.1/PWM4/IC4/MISO
;        INT0/OSCIN/AIN1/P3.0 -|5    16|- P0.0/PWM3/IC3/MOSI/T1
;              INT1/AIN0/P1.7 -|6    15|- P1.0/PWM2/IC2/SPCLK
;                         GND -|7    14|- P1.1/PWM1/IC1/AIN7/CLO
;[SDA]/TXD_1/ICPDA/OCDDA/P1.6 -|8    13|- P1.2/PWM0/IC0
;                         VDD -|9    12|- P1.3/SCL/[STADC]
;            PWM5/IC7/SS/P1.5 -|10   11|- P1.4/SDA/FB/PWM1
;                               -------
;

CLK               EQU 16600000 ; Microcontroller system frequency in Hz
BAUD              EQU 115200 ; Baud rate of UART in bps
TIMER1_RELOAD     EQU (0x100-(CLK/(16*BAUD)))
TIMER0_RELOAD_1MS EQU (0x10000-(CLK/1000))

ORG 0x0000
	ljmp main

;                     1234567890123456    <- This helps determine the location of the counter
test_message:     db 'T_H:            ', 0
value_message:    db 'T:              ', 0
cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

; These register definitions needed by 'math32.inc'
DSEG at 30H
x:   ds 4
y:   ds 4
bcd: ds 5
VAL_LM4040: ds 2
VAL_LM335: ds 2
VAL_PIN20:  ds 2 ; added
TH_temp: ds 4 ; change 1: change from 2 to 4

BSEG
mf: dbit 1

$NOLIST
$include(math32.inc)
$LIST

Init_All:
	; Configure all the pins for biderectional I/O
	mov	P3M1, #0x00
	mov	P3M2, #0x00
	mov	P1M1, #0x00
	mov	P1M2, #0x00
	mov	P0M1, #0x00
	mov	P0M2, #0x00
	
	orl	CKCON, #0x10 ; CLK is the input for timer 1
	orl	PCON, #0x80 ; Bit SMOD=1, double baud rate
	mov	SCON, #0x52
	anl	T3CON, #0b11011111
	anl	TMOD, #0x0F ; Clear the configuration bits for timer 1
	orl	TMOD, #0x20 ; Timer 1 Mode 2
	mov	TH1, #TIMER1_RELOAD ; TH1=TIMER1_RELOAD;
	setb TR1
	
	; Using timer 0 for delay functions.  Initialize here:
	clr	TR0 ; Stop timer 0
	orl	CKCON,#0x08 ; CLK is the input for timer 0
	anl	TMOD,#0xF0 ; Clear the configuration bits for timer 0
	orl	TMOD,#0x01 ; Timer 0 in Mode 1: 16-bit timer
	
	; Initialize the pins used by the ADC (P1.1, P1.7,P0.4) as input.
	orl	P1M1, #0b10000010
	anl	P1M2, #0b01111101
	orl P0M1, #0b00010000 ; P0.4 as input
	anl P0M2, #0b11101111
	
	; Initialize and start the ADC:
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x07 ; Select channel 7
	; AINDIDS select if some pins are analog inputs or digital I/O:
	mov AINDIDS, #0x00 ; Disable all analog inputs
	orl AINDIDS, #0b10100001 ; Activate AIN0 and AIN7 analog inputs. Added AIN5
	orl ADCCON1, #0x01 ; Enable ADC
	
	ret
wait_1ms:
	clr	TR0 ; Stop timer 0
	clr	TF0 ; Clear overflow flag
	mov	TH0, #high(TIMER0_RELOAD_1MS)
	mov	TL0,#low(TIMER0_RELOAD_1MS)
	setb TR0
	jnb	TF0, $ ; Wait for overflow
	ret

; Wait the number of miliseconds in R2
waitms:
	lcall wait_1ms
	djnz R2, waitms
	ret

; We can display a number any way we want.  In this case with
; four decimal places.

Display_formated_BCD:
	;Set_Cursor(2, 11)
	Set_Cursor(2, 3)
	Display_BCD(bcd+3)
	Display_BCD(bcd+2)
	Display_char(#'.')
	Display_BCD(bcd+1)
	
	;Display_BCD(bcd+0)
	;Display_BCD(bcd+0)
	Display_char(#'C')
	ret
	
Display_Pin20_BCD:
	Set_Cursor(1, 11)
    Display_BCD(bcd+1)
    Display_char(#'.')
    Display_BCD(bcd+0)
    ;Display_char(#'C')
    ret

Read_ADC:
	clr ADCF
	setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
    
    ; Read the ADC result and store in [R1, R0]
    mov a, ADCRL
    anl a, #0x0f
    mov R0, a
    mov a, ADCRH   
    swap a
    push acc
    anl a, #0x0f
    mov R1, a
    pop acc
    anl a, #0xf0
    orl a, R0
    mov R0, A
	ret

main:
	mov sp, #0x7f
	lcall Init_All
    lcall LCD_4BIT
    
    ; initial messages in LCD
	Set_Cursor(1, 1)
    Send_Constant_String(#test_message)
	Set_Cursor(2, 1)
    Send_Constant_String(#value_message)
    
Forever:
	; reference voltage
	; Read the 2.08V LM4040 voltage connected to AIN0 on pin 6
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x00 ; Select channel 0
	lcall Read_ADC
	; initialize to 0
	mov VAL_LM4040+0, #0
	mov VAL_LM4040+1, #0
	mov R7, #16 ; 16 loops
loop_ref:
	lcall Read_ADC
	; summation of VAL_LM4040+0
	mov a, R0 ; lower 8 bits of ADC
	add a, VAL_LM4040+0 ; add to VAL_LM4040+0
	mov VAL_LM4040+0, a ; update VAL_LM4040+0
	
	; summation of VAL_LM4040+1
	mov a, R1 ; upper 4 bits of ADC
	addc a, VAL_LM4040+1 ; add a to VAL_LM4040+1 including carry from low byte
	mov VAL_LM4040+1, a ; update VAL_LM4040+1
	djnz R7, loop_ref ; repeat R7 times
	
	; read pin 20
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x05 ; Select channel 5
	mov VAL_PIN20+0, #0
	mov VAL_PIN20+1, #0
	mov R7, #16
	
loop_pin20:
	lcall Read_ADC
	mov a, R0
	add a, VAL_PIN20+0
	mov VAL_PIN20+0, a
	mov a, R1
	addc a, VAL_PIN20+1
	mov VAL_PIN20+1, a
	djnz R7, loop_pin20
	
	; sensor
	; Read the signal connected to AIN7
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x07 ; Select channel 7
	
	mov VAL_LM335+0, #0 ; initialize to 0
	mov VAL_LM335+1, #0
	mov R7, #16 ; initialize R7 to 16
loop_sensor:
	lcall Read_ADC
	; summation of VAL_LM335+0
	mov a, R0 ; lower 8 bits of ADC
	add a, VAL_LM335+0 ; add to VAL_LM335+0
	mov VAL_LM335+0, a ; update VAL_LM335+0
	; summation of VAL_LM335+1
	mov a, R1  ; upper 4 bits of ADC
	addc a, VAL_LM335+1 ; add to total high byte plus carry from low byte
	mov VAL_LM335+1, a ; update VAL_LM335+1
	djnz R7, loop_sensor ; repeat R7 times
	
	;-----------------------------
	; calculations for T_H
	; T_H = [4.096/ (41*10^(-6))] * (1 / 100) * ADC_OP07 / ADC_ref
	; VAL_PIN20 contains ADC_OP07, VAL_LM4040 contains ADC_ref
	
;-----------------------------
	; 1. CALCULATE T_H (Thermocouple Difference)
	;-----------------------------
	mov x+0, VAL_PIN20+0
	mov x+1, VAL_PIN20+1
	mov x+2, #0
	mov x+3, #0
	
	Load_y(40960) 
	lcall mul32
	mov y+0, VAL_LM4040+0 
    mov y+1, VAL_LM4040+1
    mov y+2, #0
    mov y+3, #0
	lcall div32
	
	Load_y(100)  
    lcall mul32
    Load_y(12300) 
    lcall div32    ; x = T_H in degrees Celsius (e.g., 2)
	
	Load_y(100)    ; <--- ADD THIS SCALE STEP
	lcall mul32    ; x is now Hundredths (e.g., 200)
	
	Load_y(100)    ; <--- ADD THIS SCALE STEP
	lcall mul32    ; x is now Hundredths (e.g., 200)

	; Store T_H to be added to T_C later
    mov TH_temp+0, x+0
    mov TH_temp+1, x+1
    mov TH_temp+2, x+2
    mov TH_temp+3, x+3
	
	lcall hex2bcd
    lcall Display_Pin20_BCD ; Shows top row correctly (e.g., 02.00)
    
	;-----------------------------
	; 2. CALCULATE T_C (Cold Junction / Room Temp)
	;-----------------------------
	mov x+0, VAL_LM335+0
	mov x+1, VAL_LM335+1
	mov x+2, #0
	mov x+3, #0
	
	Load_y(40960) 
	lcall mul32 
	
	mov y+0, VAL_LM4040+0 
	mov y+1, VAL_LM4040+1
	mov y+2, #0
	mov y+3, #0
	lcall div32 
	
	Load_y(27300) 
	lcall sub32 
	Load_y(100)
	lcall mul32
	
	;-----------------------------
	; 3. TOTAL TEMPERATURE = T_C + T_H
	;-----------------------------
	mov y+0, TH_temp+0
	mov y+1, TH_temp+1
	mov y+2, TH_temp+2
	mov y+3, TH_temp+3
	
	
	
	lcall add32    ; x = 2200 + 200 = 2400 (CORRECT TOTAL)

	lcall hex2bcd
	lcall Display_formated_BCD		
    
	;-----------------------------
; --- Corrected Python Send for XX.XX ---
    
	; send to python
	mov a, bcd+3    ; Load the hundreds digit
    anl a, #0x0F    ; Mask it
    orl a, #0x30    ; Convert to ASCII
    lcall putchar   ; Now it sends the '1' in '145'
	
	; first digit
	mov a, bcd+2 ; load BCD value, e.g. '13'
	swap a ; swap the first two digits, '31'
	anl a, #0x0F ; mask the first digit, '01'
	orl a, #0x30 ; add to 0x30 to convert to ASCII
	lcall putchar ; send to python
	
	; second digit
	mov a, bcd+2 ; load BCD value, e.g. '13'
	anl a, #0x0F ; mask the first digit, '03'
	orl a, #0x30 ; add to 0x30 to convert to ASCII
	lcall putchar
	
	mov a, #0x2E ; HEX for '.'
	lcall putchar
	
	; decimal
	mov a, bcd+1
	swap a
	anl a, #0x0F
	orl a, #0x30 ; convert to ASCII
	lcall putchar
	
	mov a, bcd+1
	anl a, #0x0F
	orl a, #0x30
	lcall putchar
	
	; send '\n' or linefeed to python
	mov a, #0x0A
	lcall putchar
	
	; Wait 500 ms between conversions
	mov R2, #250
	lcall waitms
	mov R2, #250
	lcall waitms
	
	ljmp Forever
	
	putchar:
	jnb TI, putchar
	clr TI
	mov SBUF, a
	ret
	
END	