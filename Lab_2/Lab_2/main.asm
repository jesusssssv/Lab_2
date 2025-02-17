;***********************************************
; Universidad del Valle de Guatemala
; IE2023: Programación de Microcontroladores
; Lab_2.asm
;
; Autor     : José de Jesus Valenzuela Velásquez
; Proyecto  : Laboratorio No. 2
; Hardware  : ATmega328PB
; Creado    : 10/02/2025
; Modificado: 11/02/2025
; Descripción: Este programa un contador binario de 4 bits en el que cada incremento 
;              se realizará cada 100ms, utilizando el Timer0. Además se agrega un contador
;			   hexadecimal de 4 bits que funciona con dos botones y refleja su valor en un 
;			   display de 7 segmentos.
;***********************************************

.include "m328pbdef.inc"    ; Incluir archivo de definiciones del ATmega328PB.
 
.cseg                       ; Inicia la sección de código.
.org 0x0000                 ; Dirección de inicio del código.
rjmp RESET                  ; Salta a la rutina de inicialización. 

;***********************************************
; DEFINICIÓN DE REGISTROS
;***********************************************
.def temp = r16             ; Registro temporal para operaciones auxiliares.
.def counter = r19			; Contador botones
.def overflow_count = r18   ; Contador de desbordes
.def led_counter = r17      ; Contador binario para los LEDs
.def button_state = r22     ; Almacena el estado actual de los botones (bit 0: incremento, bit 1: decremento)


; ===========================
; Tabla de valores para display 7 segmentos (0-F)
; ===========================
TABLA7SEG:
    .db 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07
    .db 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71

;***********************************************
; CONSTANTES
;***********************************************
.equ STABLE_COUNT = 5       ; Cantidad de verificaciones necesarias para considerar un botón estable.



;***********************************************
; RUTINA DE INICIALIZACIÓN
;***********************************************
RESET:
    ldi temp, high(RAMEND)  ; Cargar la parte alta de la dirección de la RAM en temp.
    out SPH, temp           ; Guardar en el registro de pila alta.
    ldi temp, low(RAMEND)   ; Cargar la parte baja de la dirección de la RAM en temp.
    out SPL, temp           ; Guardar en el registro de pila baja.
    
    ; Desactivar la UART para liberar los pines PD0 y PD1.
    ldi temp, 0x00          ; Cargar 0x00 en temp.
    sts UCSR0B, temp        ; Desactivar la transmisión y recepción de UART.
    sts UCSR0C, temp        ; Dejar la UART en estado inactivo.
    
    ; Configurar PORTD (PD0-PD3) y PORTC (PC0-PC3) como salidas.
    ldi temp, 0xFF          ; Definir los 7 bits bajos como salidas.
    out DDRD, temp          ; Configurar PD0-PD3 como salidas.
    out DDRC, temp          ; Configurar PC0-PC3 como salidas.
    
    ; Activar resistencias pull-up para los botones en PORTB.
    sbi PORTB, 0            ; Activar pull-up para botón incremento contador 1.
    sbi PORTB, 1            ; Activar pull-up para botón decremento contador 1.

	 ; Configurar Timer0 en modo normal, preescaler 1024
    ldi temp, (1<<CS02) | (1<<CS00)  ; Preescaler 1024 (CS02=1, CS01=0, CS00=1)
    out TCCR0B, temp                 

    ldi temp, 128  ; Cargar TCNT0 con 128 para lograr 8.192ms por desbordamiento
    out TCNT0, temp



    ; Inicializar contador
    clr counter
	clr r18  ; Contador de desbordes
    clr r17  ; Contador binario

; ===========================
; Loop principal
; ===========================
MAIN_LOOP:

    ; Mostrar valor actual en display
    ldi ZH, high(TABLA7SEG * 2)
    ldi ZL, low(TABLA7SEG * 2)
    add ZL, counter
    lpm temp, Z
    out PORTD, temp
	
    rcall CHECK_BUTTONS          ; Verifica el estado de los botones

    rcall TIMER_UPDATE                 ; Manejar el timer
	
    rjmp MAIN_LOOP

;;***********************************************
; RUTINA DE VERIFICACIÓN DE BOTONES
;***********************************************
CHECK_BUTTONS:
    sbis PINB, 0                ; Salta si PB0 está en 1 (botón no presionado)
    rjmp CHECK_INC_PRESSED      ; Si está presionado, verifica incremento
    sbis PINB, 1                ; Salta si PB1 está en 1 (botón no presionado)
    rjmp CHECK_DEC_PRESSED      ; Si está presionado, verifica decremento
    clr button_state            ; Si ningún botón está presionado, limpia estados
    ret

CHECK_INC_PRESSED:
    sbrc button_state, 0        ; Salta si el bit 0 está limpio (botón no registrado)
    ret                         ; Si ya estaba registrado, ignora
    ori button_state, 0x01      ; Marca el botón como presionado
    inc counter                 ; Incrementa el contador
    andi counter, 15            ; Mantiene solo 4 bits (0-15)

    ret

CHECK_DEC_PRESSED:
    sbrc button_state, 1        ; Salta si el bit 1 está limpio (botón no registrado)
    ret                         ; Si ya estaba registrado, ignora
    ori button_state, 0x02      ; Marca el botón como presionado
    dec counter                 ; Decrementa el contador
    andi counter, 15            ; Mantiene solo 4 bits (0-15)
    ret


;***********************************************
; RUTINA DE ACTUALIZACIÓN POR TIMER0
;***********************************************
TIMER_UPDATE:
    in temp, TIFR0    ; Leer banderas de interrupción
    sbrs temp, TOV0   ; ¿Timer0 desbordó? (TOV0 = 1)?
    ret  
    
    sbi TIFR0, TOV0  ; Limpiar la bandera de desbordamiento

    inc overflow_count  ; Aumentar contador de desbordes
    cpi overflow_count, 25  ; ¿Ya son 25 desbordes (100ms)?
    brne TIMER_UPDATE_EXIT  

    clr overflow_count  ; Reiniciar contador de desbordes
    inc led_counter     ; Incrementar contador binario (4 bits)
    andi led_counter, 0x0F  ; Limitar a 4 bits (0-15)
    out PORTC, led_counter  ; Actualizar LEDs

    ldi temp, 128  ; Recargar TCNT0 con 128
    out TCNT0, temp

TIMER_UPDATE_EXIT:
    ret

