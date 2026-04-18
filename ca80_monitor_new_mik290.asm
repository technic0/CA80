; =============================================================================
; CA80 MONITOR V3.0 - wersja MIK90-only
; MIK08 Copyright (C)1987 Stanislaw Gardynik 05-590 Raszyn
;
; Zrekonstruowano z EPROM-u CA80.BIN (8KB, 2764)
; Zweryfikowano z listingiem MIK08 (MACRO-80 3.44, 09-Dec-81)
;
; Wariant: plytka MIK90 (U7-8255) - bez obslugi MIK94
; Roznice wzgledem listingu MIK08 (wersja MIK90+MIK94):
;   1. Punkt wejscia 0000-0006: NOP*4 + JP do relokowanego kodu
;   2. Detekcja klawisza M w NMI (00E4-0100): uproszczona, MIK90-only
;   3. CSTS skanowanie klawiatury (0130-015C): MIK90-only
;   4. TKLAW tablica kodow klawiatury (0300-0317): inne kody rzeczywiste
;   5. EMINIT (0603-060D): sprawdzanie sygnatury ROM zamiast bootstrapu
;
; Assembler: z80asm, pasmo, zmac lub kompatybilny
; =============================================================================

; ---------------------------------------------------------------------------
; Uklady Z80A CPU, 8255, Z80A CTC opisano w MIK04
; Adresy portu systemowego typu 8255
; Strob PSYS - zobacz schemat ideowy (rys R6)
; ---------------------------------------------------------------------------
PA      EQU     0F0H
PB      EQU     0F1H
PC      EQU     0F2H
CONTR   EQU     0F3H

; Ustawienie konfiguracji dla portu systemowego
; KONF/90 - slowo sterujace
; PA - wejscie,  PB,PC - wyjscie
KONF    EQU     90H

; Adresy portu emulatora typu 8255
PA1     EQU     0E8H
PB1     EQU     0E9H
PC1     EQU     0EAH
CONTR1  EQU     0EBH
KONF1   EQU     0B4H            ; Slowo sterujace

; Adresy kanalow zegara typu Z80A CTC
CHAN0   EQU     0F8H            ; Kanal 0
CHAN1   EQU     0F9H            ; Kanal 1
CHAN2   EQU     0FAH            ; Kanal 2
CHAN3   EQU     0FBH            ; Kanal 3

; Stale kanalow CTC
CCR0    EQU     87H             ; Tryb timer, kanal 0
TC0     EQU     10              ; Stala dla timera, kanal 0
ZCHAN   EQU     3               ; Stala zerujaca kanal
CCR1    EQU     7               ; Tryb timer, kanal 1
TC1     EQU     250             ; Stala dla timera, kanal 1

; *** STALE SYMBOLICZNE ***
RESI    EQU     0FCH            ; Kasowanie INT
SYGNAL  EQU     0ECH            ; Sygnal dzwiekowy
HLUZYT  EQU     0C100H          ; HL- uzytkownika
PCUZYT  EQU     0C000H          ; PC- uzytkownika
WMSEK   EQU     5               ; Wzorzec WMSEK
GKLAW   EQU     10H             ; Kod tab. klaw. "G"
SPAC    EQU     11H             ; Kod tab. klaw. "."
CR      EQU     12H             ; Kod tab. klaw. "="
MKLA    EQU     58H             ; Kod rzecz. klaw. "M"
MKLA30  EQU     MKLA AND 0FH    ; Bity B3-B0
MKLA64  EQU     MKLA AND 70H    ; Bity B6-B4
KRP     EQU     0F4D3H          ; Kod rozkazu OUT (0F4H),A
RST30   EQU     0F7H            ; Kod rozkaz. RST 30H

; Stale sterujace wyswietlaczem
GLIT    EQU     3DH             ; Kod siedmioseg. litery G
ZGAS    EQU     0               ; Zgaszenie cyfry
KRESKA  EQU     40H             ; Zaswiec. srodkow. segment
ANUL    EQU     8               ; Zaswiec. dolnego segmentu
ROWN    EQU     48H             ; Znak rownosci
KROP    EQU     7               ; Zaswiecenie kropki

; Stale magnetofonu
LSYNCH  EQU     20H
MARK    EQU     0E2FDH
ILPR    EQU     20
LOW1    EQU     ILPR-ILPR/2-1
HIG1    EQU     ILPR+ILPR/2-1
LOW2    EQU     2*ILPR-ILPR/2-1
HIG2    EQU     2*ILPR+ILPR/2-1

; =============================================================================
        ORG     0
; =============================================================================

; ****** P R O G R A M   G L O W N Y ********

; --- Punkt wejscia (MIK90-only: NOP + JP do relokowanego kodu) ---
CA80:
        NOP                     ; 4 bajty zarezerwowane
        NOP                     ; (mozliwosc patchowania)
        NOP
        NOP
        JP      CA80_INIT       ; Skok do inicjalizacji portu (0156H)

; --- TI - procedura systemowa (ECHO) ---
; Pobranie znaku z jednoczesnym wyswietleniem w/g PWYS.
; WYJ: A-pobrany znak, CY=1 znak CR, Z=1 i CY=0 znak SPAC
; ZMIENIA: AF, STOS: 8
TI:                             ; 0007
        RST     28H             ; USPWYS - Ustawienie PWYS
TI1:                            ; 0008
        PUSH    BC              ; Ochrona BC
        CALL    CI              ; Pobranie znaku
        PUSH    AF              ; Ochrona AF
        LD      C,A
        JR      TI1cd           ; Ciag dalszy

; --- CLR - procedura systemowa ---
; Wygaszenie znakow wyswietlacza w/g parametru PWYS
; ZMIENIA: AF, STOS: 4
CLR:                            ; 0010
        RST     28H             ; USPWYS
CLR1:                           ; 0011
        PUSH    BC
        LD      C,ZGAS          ; Wygaszenie cyfry
        LD      B,8             ; Max. ilosc cyfr
        JR      CLR2            ; Ciag dalszy

; --- LBYTE - procedura systemowa ---
; Wyswietlenie rej. A jako 2-cyfrowej hex w/g PWYS
; ZMIENIA: F,C, STOS: 8
LBYTE:                          ; 0018
        LD      C,A             ; Ochrona A
        RST     28H             ; USPWYS
        LD      A,C             ; Odtworzenie A
LBYTE1:                         ; 001B
        PUSH    HL
        PUSH    DE              ; Ochrona HL i DE
        JP      LBYTcd          ; Ciag dalszy

; --- LADR - procedura systemowa ---
; Wyswietlenie HL jako 4-cyfrowej hex w/g PWYS
; ZMIENIA: AF,C, STOS: 10
LADR:                           ; 0020
        RST     28H             ; USPWYS
LADR1:                          ; 0021
        LD      A,L
        CALL    LBYTE1          ; Wysw. mlodszego bajtu
        LD      A,H
        JR      LADRcd          ; Ciag dalszy

; --- USPWYS - procedura pomocnicza ---
; Ustawienie parametru PWYS
; ZMIENIA: A, STOS: 2
USPWYS:                         ; 0028
        PUSH    HL
        PUSH    DE              ; Ochrona HL,DE
        LD      HL,6
        ADD     HL,SP           ; HL- wskazuje PCU
        JR      USPWcd          ; Ciag dalszy

; --- RESTA - powrot do programu monitora ---
RESTA:                          ; 0030
        DI                      ; Maskowanie przerwan
        JP      AREST           ; Skok do RESTAR
KO2:                            ; 0034
        DB      79H,50H,50H,0FFH ; Komunikat "Err"

; Skok do obslugi przerwania uzytkownika
        JP      INTU            ; 0038: Obsluga przerwania INT

; -----------------------------------------------------------------------
; Dokonczenie procedur TI, CLR, LADR, USPWYS
; -----------------------------------------------------------------------

TI1cd:                          ; 003B
        CALL    CO1             ; Wysw. cyfry szesnastkow.
        POP     AF              ; Odtworzenie AF
        POP     BC              ; Odtworzenie BC
        RET

CLR2:                           ; 0041
        CALL    COM1            ; Wygaszenie cyfry
        DJNZ    CLR2
        POP     BC              ; Odtworzenie BC
        RET

LADRcd:                         ; 0048
        PUSH    HL              ; Ochrona HL
        LD      HL,(APWYS)      ; HL- adres PWYS
        INC     (HL)
        INC     (HL)
        CALL    LBYTE1          ; Wysw. starszego bajtu
        DEC     (HL)
        DEC     (HL)
        POP     HL              ; Odtworzenie HL
        RET

USPWcd:                         ; 0055
        LD      E,(HL)          ; Mlodszy bajt PCU
        INC     HL
        LD      D,(HL)          ; Starszy bajt PCU
        LD      A,(DE)          ; Pobranie (PCU)
        INC     DE              ; Zwiekszenie adresu PCU
        LD      (HL),D          ; Starszy bajt
        DEC     HL
        LD      (HL),E          ; Mlodszy bajt
        LD      HL,(APWYS)      ; Pobranie adresu PWYS
        LD      (HL),A          ; (PWYS):=(PCU)
        POP     DE
        POP     HL              ; Odtworzenie HL,DE
        RET
        DB      85H             ; 0064: Rok powstania 1985

SPEC:                           ; 0065
        RET                     ; Powrot do prog. wywolujacego

; -----------------------------------------------------------------------
; NMI - procedura obslugi przerwania niemaskowalnego
; Obsluga klawiatury, zegara, wyswietlacza oraz
; badanie czy klawisz "M" jest wcisniety.
; -----------------------------------------------------------------------
NMI:                            ; 0066
        PUSH    AF
        PUSH    HL
        PUSH    DE
        PUSH    BC              ; Ochrona AF,HL,DE,BC

; Obsluga klawiatury
        LD      HL,LCI          ; 006A: Adres licznika klawiat.
        XOR     A               ; Zerowanie A
        CP      (HL)            ; Czy LCI=0
        JR      Z,KCI
        DEC     (HL)            ; Zmniejsz. licznika LCI
KCI:    INC     HL              ; 0072: Wskazuje licznik SYG
        CP      (HL)            ; Czy SYG=0?
        JR      Z,KSYG
        DEC     (HL)            ; Zmniejsz. licznika SYG
        OUT     (SYGNAL),A      ; Generowanie impulsu
KSYG:   INC     HL              ; 0079: Wskazuje licznik TIME
        DEC     (HL)            ; Zmniejsz. licznika TIME
        LD      A,(ZESTAT)
        OR      A               ; Czy ZESTAT=0 ?
        JR      Z,ZKON1         ; Zegar wylaczony

; Obsluga zegara czasu rzeczywistego
        INC     HL              ; Wskazuje MSEK
        LD      DE,TABC
        LD      B,LTABC
PZEG:
        EX      DE,HL
        LD      A,(DE)
        INC     A
        DAA
        CP      (HL)
        EX      DE,HL
        JR      NZ,ZKON
        XOR     A
        LD      (HL),A
        INC     DE
        INC     HL
        DJNZ    PZEG
        DEC     (HL)            ; Zmniejsz. dni tygodnia
        JR      NZ,PZEG1
        LD      (HL),7          ; Dnityg <7,6,5..1>
PZEG1:
        INC     HL
        INC     HL              ; Wskazuje MIES
        LD      A,(HL)
        CP      0AH
        JR      C,OKM
        SUB     6
OKM:
        DEC     A
        ADD     A,E
        LD      E,A
        LD      A,(DE)
        LD      D,A
        DEC     HL
        LD      A,(HL)          ; Pobr. dni miesiaca
        INC     A
        DAA
        CP      D
        JR      C,ZKON
        LD      A,1
        LD      (HL),A          ; Inicjacja dni mies.
        INC     HL
        LD      A,(HL)          ; Pobranie miesiecy
        INC     A
        DAA
        CP      13H
        JR      C,ZKON
        LD      A,1
        LD      (HL),A          ; Inicjacja miesiecy
        INC     HL
        LD      A,(HL)          ; Lata
        INC     A
        DAA
ZKON:   LD      (HL),A          ; 00C1

; Obsluga wyswietlacza
ZKON1:                          ; 00C2
        LD      HL,SBUF
        LD      A,(HL)
        ADD     A,20H
        LD      (HL),A
        INC     HL
        INC     HL              ; Wskazuje BWYS
        AND     0E0H
        LD      B,A
        LD      A,0FFH
        OUT     (PB),A          ; Wygaszenie wyswietl.
        IN      A,(PC)
        AND     1FH
        OR      B
        LD      C,A
        OUT     (PC),A          ; Wybranie kolejnej cyfry
        LD      A,B
        RLCA
        RLCA
        RLCA
        AND     0FH
        ADD     A,L
        LD      L,A             ; BWYS w obrebie strony !
        LD      A,(HL)
        CPL
        OUT     (PB),A          ; Wysw. znaku

; -----------------------------------------------------------------------
; Badanie czy klawisz "M" jest wcisniety (wersja MIK90-only)
; -----------------------------------------------------------------------
        LD      A,C             ; 00E4: Aktualny stan port. PC
        OR      0FH             ; Ustawienie bitow B3-B0
        AND     0FEH            ; Kasowanie bitu B0 (kod klawisza M)
        OUT     (PC),A          ; Wybranie wiersza klawisza M
        IN      A,(PA)          ; Odczyt portu PA
        RRCA
        AND     3FH             ; Wyciecie bitow kolumnowych
        CP      3EH             ; Czy klawisz "M" wcisniety?
        LD      A,C             ; Odtworzenie stanu portu PC
        OUT     (PC),A          ; Odtworzenie portu PC
        JP      Z,MWCIS         ; Klaw. "M" jest wcisniety
        POP     BC              ; Odtworzenie BC
        CALL    NMIU            ; Obsluga NMI uzytkow.
        POP     DE
        POP     HL
        POP     AF              ; Odtw. AF,HL,DE
        RETN
; 0101-010C: niewykorzystane (FF)
        DS      12, 0FFH

; -----------------------------------------------------------------------
; Dokonczenie procedury LBYTE
; -----------------------------------------------------------------------
LBYTcd:                         ; 010D
        LD      E,A             ; Ochrona A
        LD      HL,(APWYS)
        LD      A,(HL)          ; Pobranie PWYS
        LD      D,A             ; Ochrona PWYS
        AND     0FH
        ADD     A,10H           ; PWYS74=1
        LD      (HL),A
        LD      A,E
        AND     0FH             ; Mlodsza cyfra
        LD      C,A
        CALL    CO1
        LD      A,E
        RRCA
        RRCA
        RRCA
        RRCA
        AND     0FH             ; Starsza cyfra
        LD      C,A
        INC     (HL)
        CALL    CO1
        LD      (HL),D          ; Odtworzenie PWYS
        LD      A,E             ; Odtworzenie A
        POP     DE
        POP     HL
        RET

; -----------------------------------------------------------------------
; CSTS/FFC3 - procedura systemowa (wersja MIK90-only)
; Badanie czy klawisz wcisniety
; WYJ: CY=1 klawisz wcisniety, A=kod tablicowy
;      CY=0 klawisz puszczony
; ZMIENIA: AF, STOS: 2
; -----------------------------------------------------------------------
CSTSM:                          ; 0130
        PUSH    HL
        PUSH    BC
        LD      L,4             ; L-licznik (4 wiersze klawiatury)
CST1:                           ; 0134
        DEC     L               ; L=3,2,1,0,FFH
        JP      M,CST2          ; Klaw. nie wcisniety
        LD      A,L             ; Numer wiersza
        RLCA                    ; Na pozycje bitu PC
        OUT     (CONTR),A       ; Ustawienie dekodera U1
        IN      A,(PA)          ; Odczyt portu PA
        RRCA
        AND     3FH             ; Wyciecie bitow kolumnowych
        LD      H,A             ; Zachowanie odczytu
        LD      A,L             ; Numer wiersza
        RLCA
        INC     A               ; Slowo sterujace: reset bitu PC
        OUT     (CONTR),A       ; Odtworzenie portu C
        LD      A,H             ; Odczyt klawiatury
        CP      3FH             ; Czy klawisz wcisniety?
        JR      Z,CST1          ; Nie wcisniety (CY=0)
        LD      A,L             ; Numer wiersza
        RRCA
        RRCA
        OR      H               ; Kod rzeczywisty klawisza
        POP     BC
        POP     HL
        JR      KONW            ; Skok do konwersji kodu

; 0154-0155: niewykorzystane
        DB      0FFH, 0FFH

; -----------------------------------------------------------------------
; Relokowany punkt wejscia (CA80_INIT)
; Inicjalizacja portu systemowego i skok do CA80A
; -----------------------------------------------------------------------
CA80_INIT:                      ; 0156
        LD      A,KONF          ; Ustawienie konfiguracji
        OUT     (CONTR),A       ; PA-wejscie, PB,PC- wyjscie
        JP      CA80A           ; Ciag dalszy w programie glownym

; -----------------------------------------------------------------------
; KONW - procedura pomocnicza
; Konwersja kodu rzeczywistego klawisza na tablicowy
; WEJ: A - rzeczywisty kod klawisza
; WYJ: CY=0 nielegalny, CY=1 legalny, A=kod tablicowy
; ZMIENIA: AF, STOS: 2
; -----------------------------------------------------------------------
KONW:                           ; 015D
        PUSH    HL
        PUSH    BC
        LD      HL,TKLAW
        LD      B,LTKLAW
CST5:                           ; 0164
        CP      (HL)            ; Czy to ten ?
        SCF                     ; CY=1
        JR      Z,CST2          ; Znaleziono !
        INC     HL
        DJNZ    CST5
        OR      A               ; Klawisz nielegalny (CY=0)
CST2:   LD      A,L             ; 016C: Pobranie kodu tablicowego
        POP     BC
        POP     HL
        RET

; -----------------------------------------------------------------------
; MA - zlecenie *A: suma i roznica hex
; *A[LICZBA1][SPAC][LICZBA2][CR]
; -----------------------------------------------------------------------
MA:                             ; 0170
        CALL    EXPR
        DB      40H
        POP     DE              ; LICZBA2
        POP     HL              ; LICZBA1
        PUSH    HL
        ADD     HL,DE           ; LICZBA1 + LICZBA2
        CALL    LADR            ; Wyswietlenie sumy
        DB      44H
        POP     HL
        OR      A               ; CY=0
        SBC     HL,DE           ; LICZBA1 - LICZBA2
        CALL    LADR            ; Wyswietlenie roznicy
        DB      40H
        ; Wej. do proc. CIM

; -----------------------------------------------------------------------
; CI/FFC6 - procedura systemowa
; Pobranie znaku z klawiatury
; WYJ: A-pobrany znak, CY=1 CR, Z=1 i CY=0 SPAC
; ZMIENIA: AF, STOS: 4
; -----------------------------------------------------------------------
CIM:                            ; 0184
        PUSH    HL
        LD      HL,LCI
CI0:    LD      (HL),20         ; 20*2=40 mS
CI1:    LD      A,(HL)
        OR      A
        JR      NZ,CI1
        CALL    CSTS
        JR      C,CI0           ; Czekaj na puszczenie
CI2:
        LD      (HL),20
CI3:    LD      A,(HL)
        OR      A
        JR      NZ,CI3
        CALL    CSTS
        JR      NC,CI2          ; Czekaj na wcisniecie
        INC     HL              ; Wskazuje licznik SYG
        LD      (HL),50         ; 50*2=100mS
        POP     HL

; -----------------------------------------------------------------------
; CRSPAC - badanie czy CR lub SPAC
; -----------------------------------------------------------------------
CRSPAC:                         ; 01A2
        CP      SPAC
        RET     Z               ; Z=1 i CY=0 - SPAC
        CP      CR
        SCF
        RET     Z               ; CY=1 - znak CR
        CCF
        RET                     ; Z=0 - inny

; -----------------------------------------------------------------------
; COM - wyswietlenie znaku siedmiosegmentowego
; WEJ: C-znak, PWYS
; ZMIENIA: AF, STOS: 3/2
; -----------------------------------------------------------------------
COM:                            ; 01AB
        RST     28H             ; USPWYS
COM1:                           ; 01AC
        PUSH    HL
        PUSH    BC
        LD      HL,(APWYS)
        LD      C,(HL)          ; Pobranie PWYS
        LD      A,C
        RRCA
        RRCA
        RRCA
        RRCA
        AND     0FH             ; Ilosc znakow angazow.
        LD      B,A
        JR      Z,CO2           ; 0 znakow
        LD      A,C
        AND     0FH
        ADD     A,B
        CP      9
        JR      NC,CO2          ; Nielegalne PWYS
        ADD     A,L
        LD      L,A
COM2:
        DEC     B
        JR      Z,COM3
        DEC     HL
        LD      A,(HL)
        INC     HL
        LD      (HL),A          ; Przes. znaku w BWYS
        DEC     HL
        JR      COM2
COM3:
        POP     BC
        LD      (HL),C          ; Wyswietlenie znaku
        POP     HL
        RET

; -----------------------------------------------------------------------
; PRINT - wyswietlenie komunikatu
; WEJ: HL-adres, 0FFH-koniec
; ZMIENIA: AF,HL,C, STOS: 3
; -----------------------------------------------------------------------
PRINT:                          ; 01D4
        RST     28H             ; USPWYS
PRINT1:                         ; 01D5
        LD      A,(HL)
        CP      0FFH
        RET     Z
        LD      C,A
        CALL    COM1
        INC     HL
        JR      PRINT1

; -----------------------------------------------------------------------
; CO - wyswietlenie cyfry hex
; WEJ: C-cyfra (0-F)
; ZMIENIA: AF, STOS: 5
; -----------------------------------------------------------------------
CO:                             ; 01E0
        RST     28H             ; USPWYS
CO1:                            ; 01E1
        PUSH    HL
        PUSH    BC
        LD      HL,TSIED
        LD      A,C
        CP      10H
        JR      NC,CO2
        ADD     A,L
        LD      L,A
        LD      C,(HL)
        CALL    COM1
CO2:    POP     BC              ; 01F1
        POP     HL
        RET

; -----------------------------------------------------------------------
; PARAM - pobranie liczby hex z wyswietlaniem
; WYJ: HL-pobrana liczba
; ZMIENIA: AF,HL, STOS: 9
; -----------------------------------------------------------------------
PARAM:                          ; 01F4
        RST     28H             ; USPWYS
PARAM1:                         ; 01F5
        RST     08H             ; TI1
        JR      Z,PARAM1

; -----------------------------------------------------------------------
; PARA1 - jak PARAM1 ale pierwsza cyfra w A
; -----------------------------------------------------------------------
PARA1:                          ; 01F8
        LD      HL,0
PAR1:   PUSH    AF              ; 01FB
        CP      10H
        JR      NC,PAR2
        POP     AF
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        OR      L
        LD      L,A
PAR3:   RST     08H             ; TI1
        JR      PAR1
PAR2:   POP     AF              ; 020A
        JR      NZ,PAR3
        PUSH    AF
        CALL    CLR1
        POP     AF
        RET

; -----------------------------------------------------------------------
; EXPR - pobranie ciagu liczb hex
; WEJ: C-ilosc parametrow
; WYJ: parametry na stosie
; ZMIENIA: AF,HL,C, STOS: 10
; -----------------------------------------------------------------------
EXPR:                           ; 0213
        RST     28H             ; USPWYS
EXPR1:                          ; 0214
        CALL    PARAM1
        EX      (SP),HL
        PUSH    HL
        DEC     C
        JR      Z,EXP2
        JR      NC,EXPR1
EXP1:                           ; 021E
        PUSH    BC
        LD      C,ANUL
        CALL    COM1
        POP     BC
        POP     HL
        EX      (SP),HL
        INC     C
        JR      EXPR1
EXP2:   RET     C               ; 022A
        JR      EXP1

; -----------------------------------------------------------------------
; CZAS - wyswietlenie czasu lub daty
; -----------------------------------------------------------------------
CZAS:                           ; 022D
        LD      A,(HL)
        RST     18H             ; LBYTE
        DB      20H
        INC     HL
        LD      A,(HL)
        RST     18H             ; LBYTE
        DB      23H
        INC     HL
        LD      A,(HL)
        RST     18H             ; LBYTE
        DB      26H
        DEC     HL
        DEC     HL
        RET

; -----------------------------------------------------------------------
; HILO - HL:=HL+1, test DE>=HL
; -----------------------------------------------------------------------
HILO:                           ; 023B
        INC     HL
        LD      A,E
        SUB     L
        LD      A,D
        SBC     A,H
        RET

; -----------------------------------------------------------------------
; C.D. PROGRAMU GLOWNEGO
; -----------------------------------------------------------------------
CA80A:                          ; 0241
        LD      SP,TOS
        LD      HL,KTRAM
        LD      DE,INTU+2
        LD      BC,LTRAM
        LDDR
        LD      A,HIGH TOS      ; =0FFH
        LD      I,A
        IM      1
        ; Inicjacja Z80A CTC
        LD      A,LOW INTU0     ; Wektor dla Z80A CTC
        OUT     (CHAN0),A
        LD      A,CCR1
        OUT     (CHAN1),A
        LD      A,TC1
        OUT     (CHAN1),A
        ; Jesli PA0=1 to TRYB2
        IN      A,(PA)
        RRCA                    ; CY:=PA0
        JR      NC,SIM1
        IM      2
SIM1:   RRCA                    ; CY:=PA1
        JP      C,RTS
        RRCA                    ; CY:=PA2
        JP      C,EMINIT

; --- Petla glowna MONITORA ---
START:                          ; 0270
        LD      SP,TOS
        RST     10H             ; CLR
        DB      80H
START1: LD      HL,KO1          ; 0275
        CALL    PRINT
        DB      40H
        CALL    EMUL
        CALL    TI
        DB      17H
        LD      E,A
        CP      LCT
        JP      P,ERROR
        CP      GKLAW
        JR      NZ,INNE
        LD      C,GLIT
        CALL    COM
        DB      17H
INNE:   RST     10H             ; CLR
        DB      70H
        LD      BC,START
        PUSH    BC
        LD      C,2
        LD      HL,CTBL
        LD      D,0
        ADD     HL,DE
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        JP      (HL)

; Tablica zlecen
CTBL:                           ; 02A7
        DW      M0              ; *0 Zegar
        DW      M1              ; *1 Ustawienie czasu
        DW      M2              ; *2 Ustawienie daty
        DW      M3              ; *3 Wymiana rejestrow
        DW      M4              ; *4 Zapis na magnetofon
        DW      M5              ; *5 Zapis rekordu EOF
        DW      M6              ; *6 Odczyt z magnetofonu
        DW      M7              ; *7 Parametry / inicjacja
        DW      M8              ; *8 Zlecenie uzytkownika
        DW      M9              ; *9 Poszukiwanie slowa
        DW      MA              ; *A Suma i roznica hex
        DW      MB              ; *B Przesun. obszaru
        DW      MC              ; *C Praca krokowa
        DW      MD              ; *D Przegladanie pamieci
        DW      ME              ; *E Wpisanie stalej
        DW      MF              ; *F Przegladanie rejestr.
        DW      MG              ; *G Skok do progr. uzytk.
LCT     EQU     ($-CTBL)/2

; --- M0 - wyswietlenie zegara ---
M0:                             ; 02C9
        LD      HL,SEK
        CALL    CZAS
M01:    CALL    CSTS
        JR      NC,M0
        LD      HL,DNIM
        CALL    CZAS
        JR      M01

; --- M1 - ustawienie czasu ---
M1:     INC     C               ; 02DC
        CALL    EXPR
        DB      20H
        LD      HL,SEK
DATUST: POP     BC              ; 02E4
        LD      (HL),C
        INC     HL
        POP     BC
        LD      (HL),C
        INC     HL
        POP     BC
        LD      (HL),C
        RET

; --- M2 - ustawienie daty ---
M2:     LD      C,4             ; 02ED
        CALL    EXPR
        DB      20H
        LD      HL,DNITYG
        POP     BC
        LD      (HL),C
        INC     HL
        JR      DATUST

; --- ZMD / MC crossref ---
ZMD:    CALL    SU1             ; 02FB
        JR      MC1

; -----------------------------------------------------------------------
; TKLAW - tablica klawiatury (MIK90-only: inne kody rzeczywiste)
; -----------------------------------------------------------------------
TKLAW:                          ; 0300 (w EPROM: zaczyna sie od 02FE)
; Uwaga: w wersji MIK90-only tablica TKLAW zaczyna sie 2 bajty wczesniej
; na skutek krotszego kodu ZMD. Ponizej sa wartosci z EPROM:
        DB      0FBH            ; 0/0
        DB      0EFH            ; 1/1
        DB      0FDH            ; 2/2
        DB      0DFH            ; 3/3
        DB      0BBH            ; 4/4
        DB      0AFH            ; 5/5
        DB      0BDH            ; 6/6
        DB      09FH            ; 7/7
        DB      07BH            ; 8/8
        DB      06FH            ; 9/9
        DB      07DH            ; A/0AH
        DB      05FH            ; B/0BH
        DB      03BH            ; C/0CH
        DB      02FH            ; D/0DH
        DB      03DH            ; E/0EH
        DB      01FH            ; F/0FH
        DB      07EH            ; G/10H
        DB      0BEH            ; SPAC/11H
        DB      0FEH            ; CR/12H
        DB      03EH            ; M/13H
        DB      0F7H            ; W/14H
        DB      0B7H            ; X/15H
        DB      077H            ; Y/16H
        DB      037H            ; Z/17H
LTKLAW  EQU     $-TKLAW

; -----------------------------------------------------------------------
; TSIED - kody siedmiosegmentowe cyfr 0-F
; -----------------------------------------------------------------------
TSIED:                          ; 0318
        DB      3FH,06H,5BH,4FH        ; 0,1,2,3
        DB      66H,6DH,7DH,07H        ; 4,5,6,7
        DB      7FH,6FH,77H,7CH        ; 8,9,A,B
        DB      39H,5EH,79H,71H        ; C,D,E,F

; -----------------------------------------------------------------------
; TABC - tablica ograniczen czasowych
; -----------------------------------------------------------------------
TABC:                           ; 0328
        DB      WMSEK           ; Wzorzec milisekund
        DB      0               ; SETNE SEK
        DB      60H             ; Sekundy
        DB      60H             ; MIN
        DB      24H             ; GODZ
LTABC   EQU     $-TABC

; TABM - tablica ograniczen miesiecy (musi byc pod TABC!)
TABM:                           ; 032D
        DB      32H,29H,32H,31H        ; Sty,Lut,Mar,Kwi
        DB      32H,31H,32H,32H        ; Maj,Cze,Lip,Sie
        DB      31H,32H,31H,32H        ; Wrz,Paz,Lis,Gru

; Komunikat powitalny "CA80"
KO1:    DB      39H,77H,7FH,3FH,0FFH   ; 0339

; -----------------------------------------------------------------------
; MC - praca krokowa
; -----------------------------------------------------------------------
MC:     POP     AF              ; 033E
MC1:    LD      HL,(PLOC-1)     ; 033F
        RST     10H             ; CLR
        DB      70H
        RST     20H             ; LADR
        DB      43H
        LD      A,(HL)
        RST     18H             ; LBYTE
        DB      20H
        RST     08H             ; TI1
        JR      NZ,ZMF
        JR      NC,ZMD

        ; Wcisniety CR - praca krokowa
        LD      HL,KRP
        LD      (KROK),HL
        LD      HL,RESTAR
        LD      (INTU0),HL
        LD      HL,TIME
        LD      A,(HL)
SYN:    CP      (HL)
        JR      Z,SYN
        LD      A,CCR0
        OUT     (CHAN0),A
        LD      A,TC0
        OUT     (CHAN0),A
        NOP
        JP      GO5

ZMF:    CALL    MF              ; 036D
        JR      MC1

; -----------------------------------------------------------------------
; MD - przegladanie pamieci
; -----------------------------------------------------------------------
MD:                             ; 0372
        CALL    PARAM
        DB      40H
SU0:    RST     20H             ; LADR
        DB      43H
        LD      A,(HL)
        RST     18H             ; LBYTE
        DB      20H
        RST     08H             ; TI1
        JR      C,SU1
SU2:    DEC     HL
        JR      Z,SU0
        INC     HL
        CP      10H
        RET     NC
        LD      C,A
        RST     10H             ; CLR
        DB      20H
        CALL    CO1
        LD      A,C
        EX      DE,HL
        CALL    PARA1
        EX      DE,HL
        LD      (HL),E
        JR      NC,SU2
SU1:    INC     HL              ; 0394
        JR      SU0

; -----------------------------------------------------------------------
; ME - wpisanie stalej
; -----------------------------------------------------------------------
ME:     INC     C               ; 0397
        CALL    EXPR
        DB      40H
        POP     BC
        POP     DE
        POP     HL
ME1:    LD      (HL),C          ; 039F
        CALL    HILO
        JR      NC,ME1
        RET

; -----------------------------------------------------------------------
; MF - przegladanie i modyfikacja rejestrow
; -----------------------------------------------------------------------
CAR:    CP      4               ; 03A6
        JR      NC,MF1
        RRA
        LD      A,B
        RLA
ZAP:    LD      (DE),A          ; 03AD

MF:                             ; 03AE
        RST     10H             ; CLR
        DB      70H
        LD      HL,TFLAG
        LD      DE,FLOC
        LD      B,8
        LD      A,(DE)
        AND     0D7H
WYSW:   RLA                     ; 03BB
        JR      NC,ZER
        LD      C,(HL)
        PUSH    AF
        CALL    COM1
        POP     AF
ZER:    INC     HL              ; 03C4
        DJNZ    WYSW
        LD      A,(DE)
        RLA
        RLA
        LD      C,A
        LD      A,(DE)
        RRA
        LD      B,A
        RST     08H             ; TI1
        CP      2
        JR      NC,CAR
        RRA
        LD      A,C
        RRA
        RRA
        RRA
        JR      ZAP

; Czesc II: MF1
MF1:    LD      D,A             ; 03D9
        RST     10H             ; CLR
        DB      70H
        LD      C,D
        CALL    CO
        DB      15H
        LD      A,D
        LD      HL,ACT1
        LD      BC,LACT1
        CPIR
        JR      NZ,X4
        LD      C,(HL)
        CALL    COM
        DB      15H
X4:     LD      A,D             ; 03F1
        LD      HL,ACTBL-3
        LD      C,NREGS+1
X0:     INC     HL              ; 03F7
        INC     HL
        INC     HL
        DEC     C
        RET     Z
        CP      (HL)
        JR      NZ,X0
        CALL    DREG
        RST     08H             ; TI1
        RET     C
        JR      NZ,MF1

        ; SPAC - zmiana zawartosci
        RST     10H             ; CLR
        DB      40H
        INC     B
        JR      NZ,BIT16
        RST     10H             ; CLR
        DB      20H
BIT16:  CALL    PARAM1          ; 040D
        RET     NC
        LD      A,L
        LD      (DE),A
        DEC     B
        JP      M,X8
        INC     DE
        LD      A,H
        LD      (DE),A
X8:     RST     08H             ; 041A: TI1
        JR      MF1

; -----------------------------------------------------------------------
; DREG - wyliczenie adresu rejestru i wyswietlenie
; -----------------------------------------------------------------------
DREG:                           ; 041D
        LD      D,MTOP
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      B,(HL)
        LD      A,(DE)
        RST     18H             ; LBYTE
        DB      20H
        DEC     B
        RET     M
        INC     DE
        LD      A,(DE)
        RST     18H             ; LBYTE
        DB      22H
        DEC     DE
        RET

; -----------------------------------------------------------------------
; Tablice wskaznikow i rejestrow
; -----------------------------------------------------------------------
TFLAG:  DB      6DH,5CH,00H,76H        ; 042E: SO-H
        DB      00H,73H,54H,39H        ; -PNC

ACT1:   DB      05H,6BH                ; 0436: IX/5
        DB      06H,72H                ; IY/6
        DB      07H,6DH                ; S/7
        DB      08H,76H                ; H/8
        DB      09H,38H                ; L/9
        DB      GKLAW,73H              ; P/GKLAW
LACT1   EQU     $-ACT1

ACTBL:  DB      0AH,ALOC AND 0FFH,0    ; 0442
        DB      0BH,BLOC AND 0FFH,0
        DB      0CH,CLOC AND 0FFH,0
        DB      0DH,DLOC AND 0FFH,0
        DB      0EH,ELOC AND 0FFH,0
        DB      0FH,FLOC AND 0FFH,0
        DB      08H,HLOC AND 0FFH,0
        DB      09H,LLOC AND 0FFH,0
        DB      GKLAW,PLOC-1 AND 0FFH,1
        DB      07H,SLOC AND 0FFH,1
        DB      05H,IXLOC-1 AND 0FFH,1
        DB      06H,IYLOC-1 AND 0FFH,1
NREGS   EQU     ($-ACTBL)/3

; -----------------------------------------------------------------------
; MG - wejscie do programu uzytkownika
; -----------------------------------------------------------------------
MG:     POP     AF              ; 0466
        CALL    TI
        DB      40H
        JR      Z,GOA
        CALL    PARA1
        LD      (PLOC-1),HL
GOA:    JR      C,GO4           ; 0473
GO1:    LD      C,KRESKA        ; 0475
        CALL    COM
        DB      14H
        LD      B,2
PU2:    CALL    PARAM           ; 047D
        DB      40H
        PUSH    HL
        DEC     B
        JR      C,TRA1
        JR      NZ,PU2

; --- ERROR - obsluga bledu ---
ERROR:                          ; 0487
        LD      SP,TOS
        RST     10H             ; CLR
        DB      80H
        LD      HL,KO2
        CALL    PRINT
        DB      35H
        JP      START1

; --- Zastawienie pulapek ---
TRA1:   LD      HL,TLOC         ; 0496
TRA2:   POP     DE              ; 0499
        LD      (HL),E
        INC     HL
        LD      A,(DE)
        LD      (HL),A
        LD      A,RST30
        LD      (DE),A
        INC     HL
        LD      A,B
        INC     B
        OR      A
        JR      Z,TRA2
GO4:    RST     10H             ; 04A9: CLR
        DB      80H
GO5:    XOR     A               ; 04AB
        LD      (GSTAT),A
        OUT     (RESI),A
        JP      EXIT

; --- M3 - wymiana rejestrow ---
M3:     RST     08H             ; 04B4: TI1
        JR      NC,ERROR
        LD      SP,ELOC
        POP     DE
        POP     BC
        POP     AF
        LD      HL,(LLOC)
        EX      AF,AF'
        EXX
        LD      (LLOC),HL
        PUSH    AF
        PUSH    BC
        PUSH    DE
        JP      START

; --- M7 - inicjacja / parametry transmisji ---
M7:     RST     10H             ; 04CB: CLR
        DB      40H
        RST     08H             ; TI1
        JP      C,CA80
        CP      10H
        JR      NC,ERROR
        CALL    PARA1
        JR      NC,ERROR
        LD      (DLUG),HL
        RET

; --- M9 - poszukiwanie slowa ---
M9:     CALL    EXPR            ; 04DE
        DB      40H
        LD      BC,4000H
        POP     HL
M91:    POP     DE              ; 04E6
M90:    LD      A,D             ; 04E7
        OR      A
        JR      NZ,SLOW16
        LD      A,E
        CPIR
        RET     PO
        LD      A,D
        OR      A
        JR      Z,SLOW8
SLOW16: LD      A,E             ; 04F3
        CP      (HL)
        JR      NZ,M90
SLOW8:  DEC     HL              ; 04F7
        PUSH    DE
        CALL    SU0
        INC     HL
        JR      M91

; --- MB - przesuniecie obszaru pamieci ---
MB:     INC     C               ; 04FF
        CALL    EXPR
        DB      40H
        POP     BC              ; ADR3
        POP     HL              ; ADR2
        POP     DE              ; ADR1
        OR      A
        PUSH    HL
        SBC     HL,DE
        JP      C,ERROR
        EX      (SP),HL
        PUSH    HL
        PUSH    DE
        SBC     HL,BC
        JR      C,PRZOD
        POP     HL
        PUSH    HL
        SBC     HL,BC
        JR      NC,PRZOD
        ; Przesuwanie do tylu
        POP     HL
        POP     DE
        POP     HL
        PUSH    HL
        ADD     HL,BC
        EX      DE,HL
        POP     BC
        INC     BC
        LDDR
        RET

PRZOD:                          ; 0526
        POP     HL
        LD      E,C
        LD      D,B
        POP     BC
        POP     BC
        INC     BC
        LDIR
        RET

; -----------------------------------------------------------------------
; MWCIS - przejscie do MONITORA po wcisnieciu M
; -----------------------------------------------------------------------
MWCIS:                          ; 052F
        DI
        LD      HL,TNMIU
        LD      DE,NMIU
        LD      BC,LIOCA
        LDDR
        LD      A,(GSTAT)
        OR      A
        JP      NZ,START
        ; Wykonywany program uzytkownika
        POP     BC
        POP     DE
        POP     HL
        POP     AF

; -----------------------------------------------------------------------
; RESTAR - powrot z programu uzytkownika do MONITORA
; -----------------------------------------------------------------------
RESTAR:                         ; 0546
        PUSH    HL
        PUSH    DE
        PUSH    BC
        PUSH    AF
        PUSH    IX
        PUSH    IY
        LD      DE,EXIT
        LD      A,D
        LD      (GSTAT),A

        LD      HL,14
        ADD     HL,SP
        EX      DE,HL
        LD      B,6
RST0:   DEC     HL              ; 055C
        LD      (HL),D
        DEC     HL
        LD      (HL),E
        POP     DE
        DJNZ    RST0

        POP     BC              ; PC uzytkownika
        LD      SP,HL
        LD      L,LLOC AND 0FFH
        LD      (HL),E
        INC     HL
        LD      (HL),D

        DEC     BC              ; Zalozenie pulapki
        LD      L,LOW TLOC

        LD      D,2
POWTR:  LD      A,(HL)          ; 056F
        XOR     C
        INC     HL
        JR      NZ,NIER
        LD      A,(HL)
        XOR     B
        JR      Z,RST1
NIER:   INC     HL              ; 0578
        INC     HL
        DEC     D
        JR      NZ,POWTR
        INC     BC              ; Odtworzenie PC

RST1:                           ; 057E
        LD      L,LOW PLOC-1
        LD      (HL),C
        INC     HL
        LD      (HL),B

        ; Kasowanie pulapek
        LD      E,2
        INC     HL
TRP:    LD      C,(HL)          ; 0586
        XOR     A
        LD      (HL),A
        INC     HL
        LD      B,(HL)
        LD      (HL),A
        INC     HL
        LD      A,(HL)
        LD      (BC),A
        INC     HL
        DEC     E
        JR      NZ,TRP

        LD      A,D
        CALL    EMUL
        LD      A,D
        OR      A
        JR      NZ,PUL
        LD      A,(KROK)
        OR      A
        JP      Z,START

        ; Praca krokowa
        LD      A,ZCHAN
        OUT     (CHAN0),A
        LD      HL,0
        LD      (KROK),HL
        LD      HL,MC1
        PUSH    HL
        RETI

PUL:                            ; 05B2
        LD      HL,BWYS+7
        SET     KROP,(HL)
        CALL    CIM
        JP      START

; -----------------------------------------------------------------------
; EMUL - skok do emulatora pod warunkiem PA2=1
; -----------------------------------------------------------------------
EMUL:                           ; 05BD
        LD      (LCI-1),A
        IN      A,(PA)
        AND     4
        RET     Z
        JP      EM

; -----------------------------------------------------------------------
; Tablica inicjacji RAM (TRAM)
; -----------------------------------------------------------------------
TRAM:
        DW      TOS-27H         ; Stos uzytkownika
        ; EXIT
        POP     DE
        POP     BC
        POP     AF
        POP     IX
        POP     IY
        POP     HL
        LD      SP,HL
        NOP                     ; KROK
        NOP
        LD      HL,HLUZYT
        EI
        JP      PCUZYT
        ; Pulapki
        DW      0               ; Pulapka1
        DB      0
        DW      0               ; Pulapka2
        DB      0
        ; Parametry magnetofonu
        DB      16              ; DLUG
        DB      25H             ; MAGSP
        ; Klucze programowe
        DB      0FFH            ; GSTAT
        DB      0FFH            ; ZESTAT
        ; Skoki posrednie
M8:     JP      800H
ERRMAG: JP      ERROR
EM:     JP      806H
RTS:    JP      803H
        ; Systemowe skoki posrednie (IOCA)
IOCA:   DW      PWYS            ; APWYS
        JP      CSTSM           ; CSTS
        JP      CIM             ; CI
        JP      RESTAR          ; AREST
LIOCA   EQU     $-IOCA
TNMIU:  RET                     ; NMIU
        DW      0

KTRAM   EQU     $-1
LTRAM   EQU     $-TRAM

; -----------------------------------------------------------------------
; INTU / JP ERROR (skok posredni dla bledow)
; Ten bajt w EPROM sluzy za skok posredni
; -----------------------------------------------------------------------
        JP      ERROR           ; INTU: skok do obslugi bledu

; -----------------------------------------------------------------------
; EMINIT - inicjacja emulatora (MIK90-only: sprawdzenie sygnatury ROM)
; W wersji MIK90-only zamiast pelnego bootstrapu przez 8255
; sprawdzana jest sygnatura 0AAH pod adresem 8001H.
; -----------------------------------------------------------------------
EMINIT:                         ; 0603
        LD      A,(8001H)       ; Sprawdzenie sygnatury ROM
        CP      0AAH            ; Magic byte
        JP      NZ,ERROR        ; Brak emulatora
        JP      8002H           ; Skok do emulatora

; 060E-061C: niewykorzystane (FF)
        DS      15, 0FFH

; -----------------------------------------------------------------------
; O B S L U G A   M A G N E T O F O N U
; -----------------------------------------------------------------------

; --- M4 - zapis na magnetofon ---
M4:     INC     C               ; 061D
        CALL    EXPR
        DB      40H
        POP     BC
        LD      B,C
        POP     DE
        POP     HL

; --- ZMAG - zapis obszaru pamieci na magnetofon ---
ZMAG:                           ; 0626
        CALL    SYNCH
        PUSH    BC
WR0:    PUSH    HL              ; 062A
        LD      A,(DLUG)
        LD      C,A
        LD      B,0
WR1:    INC     B               ; 0631
        DEC     C
        JR      Z,WR2
        CALL    HILO
        JR      NC,WR1
WR2:    PUSH    DE              ; 063A
        LD      HL,MARK
        CALL    PADR
        POP     DE
        POP     HL
        POP     AF
        PUSH    AF
        PUSH    DE
        LD      E,A
        LD      D,0
        CALL    PBYT
        LD      A,E
        RST     18H             ; LBYTE
        DB      25H
        LD      A,B
        CALL    PBYT
        CALL    PADR
        RST     20H             ; LADR
        DB      40H
        XOR     A
        SUB     D
        CALL    PBYT
        LD      D,0
WR3:    LD      A,(HL)          ; 065F
        CALL    PBYT
        INC     HL
        DJNZ    WR3
        XOR     A
        SUB     D
        CALL    PBYT
        POP     DE
        DEC     HL
        CALL    HILO
        JR      NC,WR0
        POP     BC
        RET

; --- M5 - zapis rekordu EOF ---
M5:     CALL    EXPR            ; 0674
        DB      40H
        POP     BC
        LD      B,C
        POP     HL

; --- ZEOF - zapis rekordu EOF ---
ZEOF:   PUSH    HL              ; 067B
        CALL    SYNCH
        LD      HL,MARK
        CALL    PADR
        LD      A,B
        LD      D,0
        CALL    PBYT
        XOR     A
        CALL    PBYT
        POP     HL
        CALL    PADR
        XOR     A
        SUB     D
        JR      PBYT

; --- SYNCH - synchronizacja ---
SYNCH:  PUSH    BC              ; 0697
        LD      B,LSYNCH
PBX:    XOR     A               ; 069A
        CALL    PBYTE
        DJNZ    PBX
        POP     BC
        RET

; --- PADR - zapis HL na magnetofon ---
PADR:   LD      A,L             ; 06A2
        CALL    PBYT
        LD      A,H

; --- PBYT - zapis bajtu z suma kontrolna ---
PBYT:   LD      C,A             ; 06A7
        ADD     A,D
        LD      D,A
        LD      A,C

; --- PBYTE - zapis bajtu bez sumy ---
PBYTE:  PUSH    DE              ; 06AB
        PUSH    BC
        LD      C,A
        LD      E,9
BIT1:   CALL    GJED            ; 06B0
BIT4:   CALL    GZER            ; 06B3
BIT3:   DEC     E               ; 06B6
        JR      Z,KBIT
        LD      A,C
        RRA
        LD      C,A
        JR      C,BIT1
        CALL    GZER
        LD      A,C
        RRA
        CALL    GJED
        LD      A,C
BIT2:   LD      C,A             ; 06CA
        CALL    GJEDD
        DEC     E
        JR      BIT4
KBIT:   LD      D,4             ; 06D1
KBIT1:  CALL    GZER            ; 06D3
        DEC     D
        JR      NZ,KBIT1
        POP     BC
        POP     DE
        RET

; --- GZER - generowanie zera ---
GZER:   LD      B,ILPR          ; 06DC
        CALL    RESMAG
GZE1:   CALL    DEL02           ; 06E1
        DJNZ    GZE1
        RET

; --- GJED - generowanie jedynki ---
GJED:   LD      B,ILPR-4        ; 06E7
GJED1:  LD      A,10H           ; 06E9
        LD      (KLAW),A
        OUT     (PA),A
        LD      A,9
        OUT     (CONTR),A
        CALL    GZE1
        CALL    RESMAG
        LD      B,4
        JR      GZE1

; --- GJEDD - generowanie podwojnej jedynki ---
GJEDD:  LD      B,2*ILPR-4      ; 06FE
        JR      GJED1

; --- DEL02 - opoznienie ---
DEL02:  LD      A,(MAGSP)       ; 0702
DE1:    DEC     A               ; 0705
        JR      NZ,DE1
        RET

; --- RESMAG - zerowanie wyjscia magnetofonowego ---
RESMAG:                         ; 0709
        XOR     A
        LD      (KLAW),A
        OUT     (PA),A
        LD      A,8
        OUT     (CONTR),A
        RET

; -----------------------------------------------------------------------
; M6 - odczyt z magnetofonu
; -----------------------------------------------------------------------
M6:     DEC     C               ; 0714
        CALL    EXPR
        DB      20H
        POP     BC
        LD      B,C

; --- OMAG - odczyt programu z magnetofonu ---
OMAG:                           ; 071B
        PUSH    BC
RED1:   LD      HL,MARK         ; 071C
RED0:   CALL    RBYT            ; 071F
REX:    CP      L               ; 0722
        JR      NZ,RED0
        CALL    RBYT
        CP      H
        JR      NZ,REX
        ; Znaleziono MARK
        LD      D,0
        CALL    RBYT            ; Nazwa
        LD      E,A
        RST     18H             ; LBYTE
        DB      25H
        CALL    RBYT            ; DLUG
        LD      B,A
        CALL    RBYT
        LD      L,A
        CALL    RBYT
        LD      H,A
        RST     20H             ; LADR
        DB      40H
        CALL    RBYT            ; -SUMN
        JR      NZ,ERRO
        POP     AF
        PUSH    AF
        CP      E
        JR      NZ,RED1
        LD      A,B
        OR      A
        JR      Z,REOF
        LD      A,ROWN
        LD      (BWYS+4),A
RED2:   CALL    RBYT            ; 0754
        LD      (HL),A
        INC     HL
        DJNZ    RED2
        CALL    RBYT            ; -SUMD
        LD      A,ZGAS
        LD      (BWYS+4),A
        SCF
        JR      NZ,ERRO
        JR      RED1

REOF:                           ; 0768
ERRO:   POP     BC
        JP      NZ,ERRMAG
        LD      A,(GSTAT)
        OR      A
        JR      NZ,MONJES
        RST     10H             ; CLR
        DB      80H
        JP      (HL)
MONJES:                         ; 0775
        LD      (PLOC-1),HL
        RET

; -----------------------------------------------------------------------
; RBYT - odczyt bajtu z magnetofonu z suma kontrolna
; -----------------------------------------------------------------------
RBYT:   PUSH    HL              ; 0779
        PUSH    DE
        PUSH    BC
RBTX:   CALL    BSTAR           ; 077C
        JR      RBTX
BSTAR:  LD      C,HIG2+4        ; 0781
BST1:   DEC     C               ; 0783
        JR      Z,RBY
        CALL    DEL02
        IN      A,(PA)
        AND     80H
        JR      Z,BST1
        RET
RBY:    LD      L,80H           ; 0790
        LD      E,0
        CALL    LICZ
        INC     E
        CALL    LICZ
        CP      HIG1
        RET     NC
        CP      LOW1
        RET     C
        DEC     E
RB1:    CALL    LICZ            ; 07A2
        CP      HIG1
        JR      NC,RB2
        CP      LOW1
        RET     C
        LD      A,E
        CPL
        LD      E,A
        CALL    LICZ
        CP      HIG1
        RET     NC
        CP      LOW1
        RET     C
RB3:    LD      A,E             ; 07B8
        RRA
        LD      A,L
        RRA
        LD      L,A
        JR      C,KBYT
        LD      A,E
        CPL
        LD      E,A
        JR      RB1
RB2:    CP      HIG2            ; 07C4
        RET     NC
        CP      LOW2
        RET     C
        JR      RB3
KBYT:                           ; 07CC
        POP     HL              ; Kasow. powr. do BSTAR
        POP     BC
        POP     DE
        POP     HL
        LD      C,A
        ADD     A,D
        LD      D,A
        OR      A               ; CY=0
        LD      A,C
        RET

; -----------------------------------------------------------------------
; LICZ - zbieranie probek
; -----------------------------------------------------------------------
LICZ:   LD      B,0             ; 07D6
LICZ1:  CALL    DEL02           ; 07D8
        INC     C
        LD      A,E
        OR      A
        IN      A,(PA)
LIX:    JR      Z,LI0
        CPL
LI0:    AND     80H             ; 07E3
        JR      Z,LICZ1
        LD      D,3
LI1:    INC     B               ; 07E9
        DEC     D
        LD      A,C
        LD      C,B
        RET     Z
        LD      C,A
        CALL    DEL02
        LD      A,E
        OR      A
        IN      A,(PA)
LI2:    JR      Z,LI2X         ; 07F6
        CPL
LI2X:   AND     80H             ; 07F9
        JR      NZ,LI1
        INC     C
        JR      LICZ

; =======================================================================
; Obszar RAM: FF8D - FFFF
; Inicjalizowany z tablicy TRAM przy starcie.
; Definicje EQU dla odwolan z kodu.
; =======================================================================

; --- Referencje do obszaru RAM (adresy bezwzgledne) ---
TOS     EQU     0FF8DH          ; Dno stosu systemowego
MTOP    EQU     HIGH TOS        ; =0FFH

ELOC    EQU     0FF8DH          ; E
DLOC    EQU     0FF8EH          ; D
CLOC    EQU     0FF8FH          ; C
BLOC    EQU     0FF90H          ; B
FLOC    EQU     0FF91H          ; F
ALOC    EQU     0FF92H          ; A
IXLOC   EQU     0FF94H          ; Wsk. starszy bajt IX
IYLOC   EQU     0FF96H          ; Wsk. starszy bajt IY
SLOC    EQU     0FF98H          ; Wsk. starszy bajt SP

EXIT    EQU     0FF99H
KROK    EQU     0FFA2H
LLOC    EQU     0FFA5H          ; L
HLOC    EQU     0FFA6H          ; H
PLOC    EQU     0FFAAH          ; Wsk. starszy bajt PC
TLOC    EQU     0FFABH
DLUG    EQU     0FFB1H
MAGSP   EQU     0FFB2H
GSTAT   EQU     0FFB3H
ZESTAT  EQU     0FFB4H

APWYS   EQU     0FFC1H
CSTS    EQU     0FFC3H
CI      EQU     0FFC6H
AREST   EQU     0FFC9H
NMIU    EQU     0FFCCH
INTU    EQU     0FFCFH
INTU0   EQU     0FFD0H

LCI     EQU     0FFE8H
SYG     EQU     0FFE9H
TIME    EQU     0FFEAH
MSEK    EQU     0FFEBH
SETSEK  EQU     0FFECH
SEK     EQU     0FFEDH
MIN     EQU     0FFEEH
GODZ    EQU     0FFEFH
DNITYG  EQU     0FFF0H
DNIM    EQU     0FFF1H
MIES    EQU     0FFF2H
LATA    EQU     0FFF3H
KLAW    EQU     0FFF4H
SBUF    EQU     0FFF5H
PWYS    EQU     0FFF6H
BWYS    EQU     0FFF7H

        END     CA80
