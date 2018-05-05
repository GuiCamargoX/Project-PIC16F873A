; Guilherme Camargo de Oliveira
; RA - 151027137
; Projeto: TCD de Microcontroladores 
; Este programa recebe um byte por Bluetooth e executa as rotinas de opção de acordo com o valor recebido
; Opcao1 : abre a trava eletrica por 10 s aproximadamente
; Opcao2 : o LedRGB começa a piscar
; Opcao3 : o LedRGB para de piscar

;OBSERVAÇÕES
;Clock feito por RC. Uma combinação de um simples resistor com um capacitor
; R = 5.1k e C = 22pF
;OscillatorFrequency(Fosc)= 3.8707MHz
; foi utilizado um LedRGB( Anodo ), obs importante pois o led funciona de forma inversa;  1 == apagado e 0 == acesso , Conectar pino do Common no 5v

list 		p=16F873A
#include <p16F873a.inc>


; --- FUSE Bits
__CONFIG _FOSC_EXTRC & _WDTE_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_OFF & _CP_OFF

; --- Saidas ---
#define 	TurnONLedR		BCF 	PORTB,RB5; Cria "Mneumonico" para acender o Led vermelho que esta ligado ao RB5
#define 	TurnOFFLedR		BSF 	PORTB,RB5; Cria "Mneumonico" para apagar o Led vermelho que esta ligado ao RB5
#define 	TurnONLedG		BCF 	PORTB,RB4; Cria "Mneumonico" para acender o Led verde que esta ligado ao RB4
#define 	TurnOFFLedG		BSF 	PORTB,RB4; Cria "Mneumonico" para apagar o Led verde que esta ligado ao RB4
#define 	TurnONLedB		BCF 	PORTB,RB3; Cria "Mneumonico" para acender o Led azul que esta ligado ao RB3
#define 	TurnOFFLedB		BSF 	PORTB,RB3; Cria "Mneumonico" para apagar o Led azul que esta ligado ao RB3
#define 	OpenLock		BCF		PORTB,RB2; Cria "Mneumonico" para abrir a Trava(solenoide) que esta ligado ao RB2
#define		CloseLock		BSF		PORTB,RB2; Cria "Mneumonico" para fechar a Trava(solenoide) que esta ligado ao RB2
#define 	flagFL			CheckFlashLight,d'0' ; Cria flagFL, nos informa se o LedRGB esta piscando. Caso 1, O LedRgb pisca.
#define 	TrueFlashLight	BSF		CheckFlashLight,d'0' ; Cria "mneumonico" para setar o primeir bit do resgitrador auxiliar CheckFlashLight
#define 	FalseFlashLight BCF		CheckFlashLight,d'0' ; Cria "mneumonico" que coloca em zero o primeir bit do resgitrador auxiliar CheckFlashLight


; --- Registradores de Uso Geral --
	cblock 		0x20						 ; inicio do bloco de dados( acima de 0x20 = memória do usuário) 
	
	cnt_1									 ;count para primeiro loop da rotina DELAY 
	cnt_2									 ;count para segundo loop da rotina DELAY
	cnt_3 									 ;count para terceiro loop da rotina DELAY
	cnt_10s									 ;count para obter 10 seg na rotina de opcao1 
	CheckFlashLight							 ;registrador boolean para saber se o botão Party foi pressionado  
	OPCAO									 ;registrador auxiliar para saber a escolha do appMobile

	endc									 ; Fim do bloco de dados 

; --- Vetor de RESET ---

	ORG	0X0000
	GOTO 	INICIO			;pula para inicio do programa

; --- Vetor de Interrupção
	ORG	0X4
	
	banksel PIR1 			; Seleciona o banco de PIR1
	BTFSS	PIR1,RCIF		; tratando interrupção, é USART? ( RCIF == 1? )
	goto 	jumpIntUsart	; não -> pula a interrupção para o fim
	banksel RCREG			; sim -> segue o código. Seleciona o banco do RCREG
	movf	RCREG,W 		; Move o conteúdo do Registrado de RX para W
	call 	CatchOption		; Rotina que trata o conteúdo recebido do AppMobile
	
jumpIntUsart:
	RETFIE					;Retorna da interrupção

; --- Programa Principal ---

INICIO:	; Rotina de início - Definição de valores

; -- Configura USART (8 bits, sem paridade, 1 stop bit, 9600, assíncrona ) --
; Setar TXSTA -> Registrador de TX
    banksel	TXSTA ; Seleciona banco do registrador TXSTA
    movlw 	b'00000110' ; bit 7: Clock Source = x ,estamos utilizando assíncrono 
						; bit 6: TX9 = 0, transmissao com apenas 8bits
						; bit 5: TXEN = 0, TX desabilitado pois o pic apenas recebe dado da aplicação
						; bit 4: SYNC = 0, configura para modo Assíncrono
						; bit 2: BRGH = 1, seleciona Baud Rate em velocidade alta
						; bit 1: TRMT(Only Read) ,1 == TSR(Buffer) vazio
						; bit 0; TX9D = x, 
    movwf 	TXSTA ; Move w para TXSTA  
    
; Setar RCSTA -> Registrador de RX
    banksel RCSTA ; Seleciona banco do registrador RCSTA
    movlw b'10010000' ; bit 7: SPEN = 1, Porta serial habilitada (configures RC7/RX/DT and RC6/TX/CK pins as serial port pins)
					  ; bit 6: RX9 = 0, Seleciona 8-bit de reception
					  ; bit 5: SREN = x, Modo Assíncrono não interessa
					  ; bit 4: CREN = 1, Habilita recepção contínua
					  ;	bit 3: ADDEN = 0, desabilita a detecção de endereço
					  ; bit 2: FERR(Only Read) , 0 == Start erro Frame com zero. Ele indica se houve erro de frame quando o registrador RCREG é lido  
					  ; bit 1: OERR(Only Read) ,0 == Sem Overrun Error bit
					  ; bit 0: RX9D(Only Read) ,x == nono bit do Received Data, pode ser a paridade
    movwf RCSTA ; Move w para RCSTA

; Setar SPBRG -> Valor para obter BPS
    banksel SPBRG ; Seleciona banco do registrador SPBRG
    movlw d'24' ; Set w = 24 .Foi utilizado a fórmula com Fosc = 3.8707MHz e Baud Rate = 9600 bps
    movwf SPBRG ; Move w para SPBRG

; -- END Configuração USART -- 

; -- Configura Interrupções --
	banksel INTCON          ;seleciona banco do resgitrador INTCON
	bsf 	INTCON,GIE		;Habilita interrupção global
	bsf		INTCON,PEIE		;Habilita interrupção por periféricos
	banksel PIE1			;seleciona banco do registrador PIE1
	bsf		PIE1, RCIE		;Habilita interrupção reception da USART

; -- END Configuração das Interrupções --

; -- Configura PORTS --
	BANKSEL TRISB			; Seleciona banco de TRISB
	MOVLW 	b'11000011'		; configura RB5, RB4, RB3, RB2 como saída, demais pinos como entrada. => W = b'11000011'
	MOVWF 	TRISB			; TRISB = W
; -- END Configuração dos PORTS -- 

	;inicialização 
		CALL  OnlyLedRed 	; Chama sub-rotina OnlyLedRed 
 		CloseLock			; utiliza mneumonico que fecha a trava, bit RB2 = 1.
		FalseFlashLight		; utiliza mneumonico que coloca o bit FlagFL = 0. Mostrando que o Led RGB não esta piscando

loop:	btfss	flagFL		; testa bit FlagFL. FlagFL == 1?
		goto 	loop		; Não -> volta para loop. Ou seja, não deixa a rotina de Piscar led prosseguir
		BANKSEL PORTB		; Sim -> Prossegue com a rotina de piscar Led . Seleciona o banco do PORTB
		TurnOFFLedR			; Utiliza mneumonico que desliga o led Vermelho ; RB5 = 1
		TurnONLedG			; Utiliza mneumonico que liga led Verde ; RB4 = 0
		call DelayS			; Chama sub-rotina DelayS
		TurnOFFLedG			; Utiliza mneumonico que desliga led Verde ; RB4 = 1
		TurnONLedB			; Utiliza mneumonico que liga led Azul  ; RB3 = 0
		call DelayS			; Chama sub-rotina DelayS
		TurnOFFLedB			; Utiliza mneumonico que desliga led Azul  ; RB3 = 1
		TurnONLedR			; Utiliza mneumonico que liga o led Vermelho ; RB5 = 0
		call DelayS			; Chama sub-rotina DelayS

		GOTO loop			;va para inicio do loop

; --- Desenvolvimento das Sub-Rotinas ---

CatchOption:				   	   ; Rotina que trata opcao vinda do disp bluetooth
								   ; Implementação de Switch Case em assembly: 
			XORLW	0x01		   ; W = 0x01 xor W
			btfsc	STATUS, Z  	   ; flagZ == 0?
			goto 	CASE1	   	   ; Não -> Ou seja, flagZ == 1, então vá para o CASE1
			XORLW	0x02^0x01	   ; Sim -> z ainda é 0 continua comp. com CASE2: W = (0x02 xor 0x01) xor W
			btfsc	STATUS, Z  	   ; flagZ == 0?
			goto	CASE2		   ; Não -> Ou seja, flagZ == 1, então vá para o CASE2
			XORLW	0x03^0x02	   ; Sim -> z ainda é 0 continua comp. com CASE3: W = (0x03 xor 0x02) xor W
			btfsc	STATUS, Z  	   ; flagZ == 0?
			goto	CASE3		   ; Não -> Ou seja, flagZ == 1, então vá para o CASE3
			goto	FIM			   ; não é nenhum dos tres
	 
	 CASE1: call 	opcao1		   ; chama subrotina opcao1
			goto 	FIM			   ; pula para o fim , pois não pode executar as intruções abaixo
	 CASE2: call	opcao2		   ; chama subrotina opcao2
			goto	FIM			   ; pula para o fim
	 CASE3: call	opcao3		   ; chama subrotina opcao3
			goto	FIM			   ; pula para o fim

	 	FIM:return				   ;retorna para o vetor de interrupção

opcao1:							   ; Rotina opcao1 : abre a trava eletrica por 10 s aproximadamente
			BANKSEL PORTB		   ; Seleciona banco do PORTB
			TurnOFFLedR			   ; Utiliza mneumonico que desliga o led Vermelho ; RB5 = 1
			TurnOFFLedB			   ; Utiliza mneumonico que desliga led Azul  ; RB3 = 1
			TurnONLedG			   ; Utiliza mneumonico que liga led Verde ; RB4 = 0
			OpenLock			   ; Utiliza mneumonico que abre a trava; RB2 = 0 
			MOVLW	d'10'		   ; W = 10
			MOVWF	cnt_10s		   ; cnt_10s = 10
		lp: CALL	DelayS		   ; LOOP 10 vezes, chama DelayS (delay de 1 segundo)
			DECFSZ	cnt_10s		   ; cnt_10s--;  FlagZ == 1?
			goto 	lp			   ; Não -> volta para lp
			CALL	OnlyLedRed	   ; Sim -> chama subrotina OnlyLedRed . Coloca led para vermelho novamente.
			CloseLock			   ; mneumonico que fecha a trava; RB2 = 1
		
	return 							;retorna 

opcao2:								; Rotina opcao2 : o LedRGB começa a piscar
			TrueFlashLight			; FlagFL = 1 
	return							; retorna


opcao3:								; Rotina opcao3 : o LedRGB para de piscar
			FalseFlashLight			; FlagFL = 0
	return                          ; retorna
 
	
DelayS:							; Rotina de Delay , aproximadamente 1 segundo
			MOVLW 	d'171'		; W = 171
			MOVWF	cnt_1		; cnt_1 = W
			MOVLW 	d'24'		; W = 24
			MOVWF	cnt_2		; cnt_2 = W
			MOVLW 	d'6'		; W = 6
			MOVWF	cnt_3		; cnt_3 = W
	
	lbl:	DECFSZ		cnt_1	; cnt_1-- ;     FlagZ == 1?
			goto 		lbl		; Não -> va para lbl 
			DECFSZ		cnt_2	; Sim -> cnt_2--;   FlagZ == 1?
			goto 		lbl		; Não -> va para lbl
			DECFSZ		cnt_3	; Sim -> cnt_3--;	FlagZ == 1?(cnt_3==0x00)
			goto 		lbl		; Não -> va para lbl
	return 						; Sim -> retorna

OnlyLedRed:					; Rotina utilizada para deixar apenas o Led Vermelho ligado 
			BANKSEL PORTB	; Seleciona o banco do PORTB
			TurnOFFLedG		; Utiliza mneumonico que desliga led Verde ; RB4 = 1
			TurnOFFLedB		; Utiliza mneumonico que desliga led Azul  ; RB3 = 1
			TurnONLedR		; Utiliza mneumonico que liga o led Vermelho ; RB5 = 0
	return					; Retorna da função
	
	END						; Fim do programa



