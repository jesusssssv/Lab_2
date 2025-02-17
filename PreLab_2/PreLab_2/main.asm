;***********************************************
; Universidad del Valle de Guatemala
; IE2023: Programación de Microcontroladores
; PreLab_2.asm
;
; Autor     : José de Jesus Valenzuela Velásquez
; Proyecto  : Laboratorio No. 1
; Hardware  : ATmega328PB
; Creado    : 10/02/2025
; Modificado: 11/02/2025
; Descripción: Este programa un contador binario de 4 bits en el que cada incremento 
;              se realizará cada 100ms, utilizando el Timer0. No se utilizan interrupciones.
;***********************************************

.include "m328pbdef.inc"    ; Incluir archivo de definiciones del ATmega328PB.
   
.cseg                       ; Inicia la sección de código.
.org 0x0000                 ; Dirección de inicio del código.
rjmp RESET                  ; Salta a la rutina de inicialización.

;***********************************************
; DEFINICIÓN DE REGISTROS
;***********************************************
.def temp = r16             ; Registro temporal para operaciones auxiliares.


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

    ; Configurar PORTC como salida (bits 0-3)
    ldi temp, 0x0F    
    out DDRC, temp
	
	cbi DDRD, 0   ; Forzar PD0 como entrada


    ; Configurar Timer0 en modo normal, preescaler 1024
    ldi temp, (1<<CS02) | (1<<CS00)  ; Preescaler 1024 (CS02=1, CS01=0, CS00=1)
    out TCCR0B, temp                 

    ldi temp, 128  ; Cargar TCNT0 con 128 para lograr 8.192ms por desbordamiento
    out TCNT0, temp

    clr r18  ; Contador de desbordes
    clr r17  ; Contador binario

loop:
    in r16, TIFR0    ; Leer banderas de interrupción
    sbrs r16, TOV0   ; ¿Timer0 desbordó? (TOV0 = 1)
    rjmp loop        

    sbi TIFR0, TOV0  ; Limpiar la bandera de desbordamiento

    inc r18          ; Aumentar contador de desbordes
    cpi r18, 25      ; ¿Ya son 25 desbordes (100ms)?
    brne loop        

    clr r18          ; Reiniciar contador de desbordes

    inc r17          ; Incrementar contador binario (4 bits)
    andi r17, 0x0F   ; Limitar a 4 bits (0-15)
    
    out PORTC, r17   ; Mostrar en LEDs

    ldi r16, 128     ; Recargar TCNT0 con 128
    out TCNT0, r16

    rjmp loop        ; Repetir