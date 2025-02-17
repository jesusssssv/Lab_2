;***********************************************
; Universidad del Valle de Guatemala
; IE2023: Programación de Microcontroladores
; Post_Lab_2.asm
;
; Autor     : José de Jesus Valenzuela Velásquez
; Proyecto  : Laboratorio No. 2
; Hardware  : ATmega328PB
; Creado    : 10/02/2025
; Modificado: 11/02/2025
; Descripción: Este programa un contador binario de 4 bits en el que cada incremento 
;              se realizará cada 1 s, utilizando el Timer0. Además se agrega un contador
;			   hexadecimal de 4 bits que funciona con dos botones y refleja su valor en un 
;			   display de 7 segmentos. Además cuenta con una función que reinicia el contador
;			   automatico, cada vez que adquiere el valor establecido en el display y enciende 
;			   led indicador para que esto se refleje. 
;***********************************************c

.include "m328pbdef.inc"    ; Incluye definiciones específicas del ATmega328PB

.cseg                       ; Indica el inicio del segmento de código
.org 0x0000                 ; Establece el origen del código en la dirección 0x0000
rjmp RESET                  ; Salta a la rutina de inicialización al encender/resetear

;***********************************************
; DEFINICIÓN DE REGISTROS - Asigna nombres descriptivos a registros específicos
;***********************************************
.def temp = r16             ; Registro temporal para operaciones generales
.def counter = r19          ; Almacena el valor actual del contador manual (0-15)
.def overflow_count = r18   ; Cuenta los desbordes del Timer0 para medir 100ms
.def contador_4bit = r17    ; Almacena el valor del contador automático de 4 bits
.def contador_100ms = r21   ; Cuenta períodos de 100ms hasta llegar a 1 segundo
.def button_state = r22     ; Almacena el estado actual de los botones (bit 0: incremento, bit 1: decremento)
.def target_value = r23     ; Nuevo registro para almacenar el valor objetivo
.def led_indicador = r24
.def contador_final = r25

; ===========================
; Tabla de valores para display 7 segmentos (0-F)
; Cada byte representa los segmentos a encender para mostrar cada número hexadecimal
; ===========================
TABLA7SEG:
    .db 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07  ; Valores para 0-7
    .db 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71  ; Valores para 8-F

;***********************************************
; RUTINA DE INICIALIZACIÓN
;***********************************************
RESET:
    ; Configuración del Stack Pointer
    ldi temp, high(RAMEND)  ; Carga el byte alto de la última dirección de RAM
    out SPH, temp           ; Configura el Stack Pointer High
    ldi temp, low(RAMEND)   ; Carga el byte bajo de la última dirección de RAM
    out SPL, temp           ; Configura el Stack Pointer Low
    
    ; Desactivación de UART
    ldi temp, 0x00          ; Carga 0 en el registro temporal
    sts UCSR0B, temp        ; Desactiva la transmisión/recepción UART
    sts UCSR0C, temp        ; Limpia la configuración UART
    
    ; Configuración de puertos
    ldi temp, 0xFF          ; Carga 1 en todos los bits
    out DDRD, temp          ; Configura PORTD como salida (display 7 segmentos)
    out DDRC, temp          ; Configura PORTC como salida (LEDs del contador automático)
    
    ; Configuración de pull-ups para botones
    sbi PORTB, 0            ; Activa pull-up en PB0 (botón de incremento)
    sbi PORTB, 1            ; Activa pull-up en PB1 (botón de decremento)

    ; Configuración del Timer0
    ldi temp, (1<<CS02) | (1<<CS00)  ; Configura preescaler a 1024
    out TCCR0B, temp                  ; (16MHz/1024 = 15.625kHz)

    ; Inicialización de registros
    clr counter             ; Limpia el contador manual
    clr overflow_count      ; Limpia el contador de desbordes
    clr contador_4bit       ; Limpia el contador automático
    clr contador_100ms      ; Limpia el contador de 100ms
    clr button_state        ; Limpia el estado de los botones
	ldi led_indicador, 0x00

;***********************************************
; LOOP PRINCIPAL
;***********************************************
MAIN_LOOP:
    ; Actualización del display 7 segmentos
    ldi ZH, high(TABLA7SEG * 2)  ; Carga byte alto de la dirección de la tabla
    ldi ZL, low(TABLA7SEG * 2)   ; Carga byte bajo de la dirección de la tabla
    add ZL, counter              ; Suma el valor del contador para obtener el patrón correcto
    lpm temp, Z                  ; Carga el patrón de segmentos en temp
    out PORTD, temp              ; Muestra el patrón en el display
    
    rcall CHECK_BUTTONS          ; Verifica el estado de los botones

    rcall TIMER                  ; Manejar el timer
    rcall CHECK_MATCH           ; Verificar coincidencia
    
    rjmp MAIN_LOOP

;***********************************************
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
; RUTINA DE COMPARACIÓN 
;***********************************************
CHECK_MATCH:
    mov temp, counter        ; Obtener valor del display (contador manual)
    cp contador_4bit, temp   ; Comparar con el contador automático
    breq MATCH_FOUND         ; Si son iguales, saltar a MATCH_FOUND
    rjmp CHECK_MATCH_EXIT    ; Si no son iguales, salir

MATCH_FOUND:
	clr contador_final
	ldi temp, 0x10
	eor led_indicador, temp
	or contador_final, led_indicador
	or contador_final, contador_4bit
	out PORTC, contador_final
	ldi contador_4bit, 0x01
	neg contador_4bit
    ret

CHECK_MATCH_EXIT:
    ret


;***********************************************
; RUTINA DEL TIMER
;***********************************************
TIMER:
	clr contador_final
    sbis TIFR0, TOV0           ; Salta si la bandera de desborde está activa
    ret                        ; Si no hay desborde, retorna
    sbi TIFR0, TOV0           ; Limpia la bandera de desborde

    inc overflow_count         ; Incrementa contador de desbordes
    cpi overflow_count, 6      ; Compara con 6 (aprox. 100ms)
    brne TIMER_EXIT            ; Si no es 6, sale

    clr overflow_count         ; Limpia contador de desbordes
    inc contador_100ms         ; Incrementa contador de períodos de 100ms
    cpi contador_100ms, 10     ; Compara con 10 (1 segundo)
    brne TIMER_EXIT            ; Si no es 10, sale

    clr contador_100ms         ; Limpia contador de 100ms
    inc contador_4bit          ; Incrementa contador automático
    andi contador_4bit, 0x0F   ; Mantiene solo 4 bits
	or contador_final, led_indicador
	or contador_final, contador_4bit
	out PORTC, contador_final


TIMER_EXIT:
    ret