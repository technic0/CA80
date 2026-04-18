; =============================================================================
; CA80 MONITOR V3.0
; MIK08 Copyright (C)1987 Stanislaw Gardynik 05-590 Raszyn
;
; Reconstructed from the MIK08 printed listing (MACRO-80 3.44, 09-Dec-81)
; Assembles with any standard Z80 assembler (z80asm, pasmo, zmac, etc.)
; =============================================================================

        .Z80

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
; Strob EME8 - zobacz schemat ideowy (rys R8)
PA1     EQU     0E8H
PB1     EQU     0E9H
PC1     EQU     0EAH
CONTR1  EQU     0EBH

; Ustawienie konfiguracji dla portu emulatora
; PA - wejscie /TRYB1/  PB - wyjscie /TRYB1/
KONF1   EQU     0B4H            ; Slowo sterujace

; Adresy kanalow zegara typu Z80A CTC
; Strob CTF8 - zobacz schemat ideowy (rys R8)
CHAN0   EQU     0F8H            ; Kanal 0
CHAN1   EQU     0F9H            ; Kanal 1
CHAN2   EQU     0FAH            ; Kanal 2
CHAN3   EQU     0FBH            ; Kanal 3

; Kanal 0 ukladu Z80A CTC
; Kanal nr. 0 jest zerowany za kazdym razem kiedy przy pomocy
; zlecenia *C (praca krokowa) wykonany zostanie chocby jeden
; rozkaz uzytkownika. Jesli uzytkownik nie korzysta z pracy
; krokowej to moze wykorzystac kanal 0 do wlasnych celow.
; CCR0 - slowo sterujace dla kanalu 0
; TC0  - stala dla timera
CCR0    EQU     87H             ; Tryb timer
TC0     EQU     10              ; Stala dla timera
ZCHAN   EQU     3               ; Stala zerujaca kanal

; Kanal 1 ukladu Z80A CTC
; Kanal 1 pracuje w trybie timer przy zablokowanych przerwaniach.
; Realizuje podzial czestotliwosci zegara (f=4MHz) przez TC1*16=4000.
; Czestotliwosc na wyjsciu ZC/TO1 wynosi zatem f=1kHz.
; Kanal inicjowany jest jednokrotnie natychmiast po wlaczeniu zasilania.
; Jesli wyjscie ZC/TO1 nie jest wykorzystywane do generowania przerwan
; niemaskowalnych NMI to uzytkownik moze wykorzystac kanal 1 do wlasnych
; celow majac swiadomosc, ze jest on inicjowany j/w po wlaczeniu zasilania.
; CCR1 - slowo sterujace dla kanalu 1
; TC1  - stala dla timera
CCR1    EQU     7               ; Tryb timer
TC1     EQU     250             ; Stala dla timera

; *** STALE SYMBOLICZNE ***

; RESI - strob kasujacy zgloszenie przerwania maskowalnego jesli system
;        przerwan mikroprocesora ustawiony jest w tryb 1 (brak Z80A CTC).
; HLUZYT - inicjacja rejestrow HL uzytkownika
; PCUZYT - inicjacja PC uzytkownika
; WMSEK  - wzorzec milisekund
;
; Warunek ktory musi byc spelniony dla potrzeb zegara czasu rzeczywistego:
;     FNMI/WMSEK=100 Hz  gdzie:
; FNMI - czestotliwosc przerwan NMI
; FNMI=500 Hz  - standart dla CA80
; GKLAW - kod tablicowy klawisza "G" (tablica TKLAW)
; MKLA  - kod rzeczywisty klawisza "M"

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

; Stale sterujace pojedyncza cyfra wyswietlacza
; - dla procedury COM
GLIT    EQU     3DH             ; Kod siedmioseg. litery G
ZGAS    EQU     0               ; Zgaszenie cyfry wyswiet.
KRESKA  EQU     40H             ; Zaswiec. srodkow. segment.
ANUL    EQU     8               ; Zaswiec. dolnego segmentu
ROWN    EQU     48H             ; Znak rownosci
KROP    EQU     7               ; Zaswiecenie kropki

; ---------------------------------------------------------------------------
        .PHASE  0
; ---------------------------------------------------------------------------

; ****** P R O G R A M   G L O W N Y ********

CA80:
        LD      A,KONF          ; Ustawienie konfigur.
        OUT     (CONTR),A       ; PA-wejscie, PB,PC- wyj.
        JP      CA80A           ; Ciag dalszy

; -----------------------------------------------------------------------
; TI - procedura systemowa
; Pobranie znaku z jednoczesnym jego wyswietleniem
; w/g PWYS.  [ tzw.ECHO ]
; Wyswietlone zostana wylacznie cyfry szesnastkowe
; - pozostale znaki beda pobrane lecz nie wyslane
; na wyswietlacz.
;
; WEJ: -
; WYJ:  A -    pobrany znak
;       CY=1   znak CR
;       Z=1 i CY=0 znak SPAC
; ZMIENIA: AF                   STOS: 8
;
; Wywolanie:
; RST  TI1  lub  CALL  TI1   lub  CALL  TI
;                                  DB    PWYS
; -----------------------------------------------------------------------
TI:
        RST     USPWYS          ; Ustawienie PWYS
TI1:
        PUSH    BC              ; Ochrona BC
        CALL    CI              ; Pobranie znaku
        PUSH    AF              ; Ochrona AF
        LD      C,A
        JR      TI1cd           ; Ciag dalszy

; -----------------------------------------------------------------------
; CLR - procedura systemowa
; Wygaszenie znakow wyswietlacza w/g parametru PWYS
;
; WEJ: PWYS - okresla ktore znaki maja byc wygaszone
; WYJ: Odpowiednie znaki wygaszone
; ZMIENIA: AF                   STOS: 4
; WYWOLANIE:
; RST CLR   lub  CALL  CLR   lub  CALL CLR1
; DB  PWYS       DB    PWYS
; -----------------------------------------------------------------------
CLR:
        RST     USPWYS          ; Ustawienie PWYS
CLR1:
        PUSH    BC
        LD      C,ZGAS          ; Wygaszenie cyfry
        LD      B,8             ; Max. ilosc cyfr do wygasz
        JR      CLR2            ; Ciag dalszy

; -----------------------------------------------------------------------
; LBYTE - procedura systemowa
; Wyswietlenie rej. A w postaci dwucyfrowej liczby
; szesnastkowej w/g PWYS.
;
; WEJ: A- liczba do wyswietlenia
; WYJ: wyswietlenie liczby w/g PWYS
; ZMIENIA: F,C                  STOS: 8
; WYWOLANIE:
; RST  LBYTE  lub  CALL  LBYTE  lub  CALL  LBYTE1
; DB   PWYS        DB    PWYS
; -----------------------------------------------------------------------
LBYTE:
        LD      C,A             ; Ochrona A
        RST     USPWYS          ; Ustawienie PWYS
        LD      A,C             ; Odtworzenie A
LBYTE1:
        PUSH    HL
        PUSH    DE              ; Ochrona HL i DE
        JP      LBYTcd          ; Ciag dalszy

; -----------------------------------------------------------------------
; LADR - procedura systemowa
; Wyswietlenie HL w postaci czterocyfrowej liczby
; szesnastkowej w/g PWYS.
;
; WEJ: HL - liczba do wyswietlenia
; WYJ: wyswietlenie liczby w/g PWYS
; ZMIENIA: AF,C                 STOS: 10
; WYWOLANIE:
; RST  LADR  lub  CALL  LADR  lub  CALL  LADR1
; DB   PWYS       DB    PWYS
; Bity PWYS30=<7,6...1,0> - nr. pozycji wyswietlacza
; Bity PWYS74 - dowolne
; Jesli PWYS30>=5 to wyswietlone zostana tylko mniej
; znaczace cyfry mieszczace sie w obrebie wyswietl.
; (APWYS+1)(APWYS)=PWYS - inicjowane po wlaczeniu zasilania
; -----------------------------------------------------------------------
LADR:
        RST     USPWYS          ; Ustawienie PWYS
LADR1:
        LD      A,L
        CALL    LBYTE1          ; Wysw. mlodszego bajtu
        LD      A,H
        JR      LADRcd          ; Ciag dalszy

; -----------------------------------------------------------------------
; USPWYS - procedura pomocnicza
; Ustawienie parametru PWYS
;
; WEJ: SP+2 wskazuje mlodszy bajt adresu PCU
;       - zobacz przyklad ponizej.
; ZMIENIA: A                    STOS: 2
; -----------------------------------------------------------------------
USPWYS:
        PUSH    HL
        PUSH    DE              ; Ochrona HL,DE
        ; Na stosie schowane sa kolejno DE,HL,COM1,PCU
        ; SP wskazuje rejestr E
        ; SP+4 wskazuje mlodszy bajt adresu COM1
        ; SP+6 wskazuje mlodszy bajt adresu PCU
        LD      HL,6
        ADD     HL,SP           ; HL- wskazuje PCU
        JR      USPWcd          ; Ciag dalszy

; -----------------------------------------------------------------------
; RESTA - powrot do programu monitora.
; Wykonanie przez program uzytkownika rozkazu
; RST 30H/F7 spowoduje skok do procedury RESTAR
; gdyz:  AREST:  JP  RESTAR
; -----------------------------------------------------------------------
RESTA:
        DI                      ; Maskowanie przerwan
        JP      AREST           ; Skok do RESTAR
KO2:
        DB      79H,50H,50H,0FFH ; Komunikat "Err"

; Skok do procedury obslugajacej przerwanie uzytkownika
; - pod warunkiem ze przerwania mikroprocesora
; ustawione sa w tryb 1 (brak Z80A CTC).
        JP      INTU            ; Obsluga przerwania INT

; -----------------------------------------------------------------------
; Dokonczenie procedur TI, CLR, LADR, USPWYS.
; -----------------------------------------------------------------------

; Dokonczenie procedury TI
TI1cd:
        CALL    CO1             ; Wysw. cyfry szesnastkow.
        POP     AF              ; Odtworzenie AF
        POP     BC              ; Odtworzenie BC
        RET

; Dokonczenie procedury CLR
CLR2:
        CALL    COM1            ; Wygaszenie cyfry
        DJNZ    CLR2
        POP     BC              ; Odtworzenie BC
        RET

; Dokonczenie procedury LADR
LADRcd:
        PUSH    HL              ; Ochrona HL
        LD      HL,(APWYS)      ; HL- adres PWYS
        ; Ustawienie PWYS30 dla potrzeb starszego bajtu
        INC     (HL)
        INC     (HL)
        CALL    LBYTE1          ; Wysw. starszego bajtu
        ; Odtworzenie PWYS30
        DEC     (HL)
        DEC     (HL)
        POP     HL              ; Odtworzenie HL
        RET

; Dokonczenie procedury PWYS
USPWcd:
        ; Pobranie PCU do rejestrow DE
        LD      E,(HL)          ; Mlodszy bajt PCU
        INC     HL
        LD      D,(HL)          ; Starszy bajt PCU
        LD      A,(DE)          ; Pobranie (PCU)
        INC     DE              ; Zwiekszenie adresu PCU
        ; Odtworzenie PCU
        LD      (HL),D          ; Starszy bajt
        DEC     HL
        LD      (HL),E          ; Mlodszy bajt
        LD      HL,(APWYS)      ; Pobranie adresu PWYS
        LD      (HL),A          ; (PWYS):=(PCU)
        POP     DE
        POP     HL              ; Odtworzenie HL,DE
        RET
        DB      85H             ; Rok powstania 1985

; -----------------------------------------------------------------------
; SPEC - procedura systemowa
; Powrot do programu wywolujacego
; WEJ: -
; WYJ: Powrot do programu wywolujacego
; ZMIENIA: -                    STOS: 0
; -----------------------------------------------------------------------
SPEC:
        RET

; -----------------------------------------------------------------------
; NMI - procedura obslugi przerwania niemaskowalnego
; Obsluga klawiatury, zegara, wyswietlacza oraz
; badanie czy klawisz "M" jest wcisniety.
; 1. Jesli M wcisniety to inicjacja komorek pamieci
;    RAM zawartych w obszarze <APWYS,NMIU>
;
; GSTAT - klucz programowy
; GSTAT=0  - wykonywany program uzytkownika
; GSTAT#0  - wykonywany program MONITORA
; 2. Jesli M wcisniety i GSTAT=0 to zapamietanie
;    stanu procesora uzytkownika i powrot do programu
;    MONITORA.
; 3. Jesli M wcisniety i GSTAT#0 to skok do adresu
;    START - oczekiwanie na kolejne zlecenie.
; -----------------------------------------------------------------------
NMI:
        PUSH    AF
        PUSH    HL
        PUSH    DE
        PUSH    BC              ; Ochrona AF,HL,DE,BC

; Obsluga klawiatury - generowanie sygnalu wcisniecia klawisza.
; Liczniki LCI i SYG wspolpracuja z procedura CI.
        LD      HL,LCI          ; Adres licznika klawiat.
        XOR     A               ; Zerowanie A
        CP      (HL)            ; Czy LCI=0
        JR      Z,KCI
        DEC     (HL)            ; Zmniejsz. licznika LCI
KCI:    INC     HL              ; Wskazuje licznik SYG
        CP      (HL)            ; Czy SYG=0?
        JR      Z,KSYG          ; Rowny zeru
        DEC     (HL)            ; Zmniejsz. licznika SYG
        OUT     (SYGNAL),A      ; Generowanie impulsu
KSYG:   INC     HL              ; Wskazuje licznik TIME
        DEC     (HL)            ; Zmniejsz. licznika TIME
        LD      A,(ZESTAT)
        OR      A               ; Czy ZESTAT=0 ?
        JR      Z,ZKON1         ; Zegar wylaczony

; Obsluga zegara czasu rzeczywistego
        INC     HL              ; Wskazuje MSEK
        LD      DE,TABC         ; Adres tablicy TABC
        LD      B,LTABC         ; Ilosc elementow w TABC
PZEG:
        EX      DE,HL
        LD      A,(DE)          ; Pobranie czasu
        INC     A               ; Zwiekszenie
        DAA                     ; W kodzie BCD
        CP      (HL)            ; Porownanie z ograniczeniem
        EX      DE,HL           ; HL - wskazuje czas
        JR      NZ,ZKON
        XOR     A               ; Zerowanie A i CY
        ; CY=0 - wazne dla rozkazu DAA
        LD      (HL),A
        INC     DE
        INC     HL
        DJNZ    PZEG
                                ; DE - wskazuje TABM
        DEC     (HL)            ; Zmniejsz. dni tygodnia
        JR      NZ,PZEG1
        LD      (HL),7          ; Dnityg <7,6,5..1>
PZEG1:
        INC     HL              ; Wskaz. dni miesiaca
        INC     HL              ; Wskazuje MIES
        LD      A,(HL)          ; Pobranie mies
        ; Miesiace odliczane sa w kodzie BCD <1,12>
        ; Zamiana kodu BCD na binarny
        CP      0AH
        JR      C,OKM           ; Gdy MIES=<9
        SUB     6               ; Gdy MIES>9
        ; Wyliczanie adresu w TABM
        ; TABM musi lezec w obrebie strony
OKM:
        DEC     A
        ADD     A,E
        LD      E,A             ; TABM musi byc na stronie
        LD      A,(DE)          ; Pobranie ograniczenia
        LD      D,A
        DEC     HL
        LD      A,(HL)          ; Pobr. dni miesiaca
        INC     A
        DAA
        CP      D               ; Porownanie z ogranicz.
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
ZKON:   LD      (HL),A

; Obsluga wyswietlacza
; Bufor wyswietlacza "BWYS" musi lezec w obrebie strony!
; MIK90 - dla potrzeb plytki MIK90 (U7-8255)
; MIK94 - dla potrzeb plytki MIK94 (uklad zastepczy
; ukladu 8255) - zobacz rys. R27 (MIK05B)
; (SBUF)- bity B7,B6,B5 realizuja licznik binarny
; modulo 8 sterujacy dekoderem cyfr wyswiet.(74145)
ZKON1:
        LD      HL,SBUF         ; MIK94
        LD      A,(HL)
        ADD     A,20H           ; Zwiekszenie licznika
        LD      (HL),A
        INC     HL
        INC     HL              ; Wskazuje BWYS
        AND     0E0H            ; Wyciecie bitow licznika
        LD      B,A             ; Przechowanie stanu licz
        LD      A,0FFH
        OUT     (PB),A          ; Wygaszenie wyswietl.
        IN      A,(PC)
        AND     1FH             ; Zerow. starego licznika
        OR      B               ; Ustaw. nowej wartoscI
        LD      C,A             ; Nowa wart. portu PC
        OUT     (PC),A          ; Wybranie kolejnej cyfry
        LD      A,B             ; Stan licz. modulo 8
        RLCA
        RLCA
        RLCA                    ; Licznik na bitach B2-B0
        AND     0FH             ; Starsza cyfra
        ADD     A,L             ; Wylicz. adresu w BWYS
        LD      L,A             ; BWYS w obrebie strony !
        LD      A,(HL)          ; Pobranie znaku do wysw.
        CPL
        OUT     (PB),A          ; Wysw. znaku

; Badanie czy klawisz "M" jest wcisniety.
; Operacja badania nie moze zmienic aktualnego
; stanu portu wyjsciowego PC (MIK90) oraz portu
; wyjsciowego PA (MIK94 - rys. R27 w MIK05B),
; gdyz spowodowaloby to zaklocenia w procedurze CSTS.

; MIK90
        LD      A,C             ; Aktualny stan port. PC
        AND     0F0H            ; Zer. dekodera klawiat.
        ADD     A,MKLA30
        OUT     (PC),A          ; Bity B30-kod klaw."M"

; MIK94
        LD      A,(KLAW)        ; Bit B4 - magnetofon
        LD      B,A             ; Ochrona bitow B40
        AND     10H             ; Wyciecie bitu B4
        ADD     A,MKLA30
        OUT     (PA),A          ; Bity B30-kod klaw."M"

; MIK90 i MIK94
        IN      A,(PA)          ; Odczyt bitow B74
        AND     70H             ; Wyciecie bitow B6-B4
        CP      MKLA64          ; Czy klawisz "M"?
        LD      A,C             ; MIK90
        OUT     (PC),A          ; Odtworzenie portu PC
        LD      A,B             ; MIK94
        OUT     (PA),A          ; Odtworzenie portu PA
        JP      Z,MWCIS         ; Klaw. "M" jest wcisn.
        POP     BC              ; Odtworzenie BC
        CALL    NMIU            ; Obsluga NMI uzytkow.
        POP     DE
        POP     HL
        POP     AF              ; Odtw. AF,HL,DE
        RETN

; -----------------------------------------------------------------------
; Dokonczenie procedury LBYTE
; -----------------------------------------------------------------------
LBYTcd:
        LD      E,A             ; Ochrona A
        LD      HL,(APWYS)      ; Adres PWYS
        LD      A,(HL)          ; Pobranie PWYS
        LD      D,A             ; Ochrona PWYS
        AND     0FH
        ADD     A,10H           ; PWYS74=1
        LD      (HL),A          ; Wysw. bez przesuwania
        LD      A,E
        AND     0FH             ; Mlodsza cyfra
        LD      C,A
        CALL    CO1             ; Wysw. mlodszej cyfry
        LD      A,E
        RRCA
        RRCA
        RRCA
        RRCA
        AND     0FH             ; Starsza cyfra
        LD      C,A
        INC     (HL)            ; PWYS-nast. pozycja
        CALL    CO1             ; Wysw. starszej cyfry
        LD      (HL),D          ; Odtworzenie PWYS
        LD      A,E             ; Odtworzenie A
        POP     DE
        POP     HL              ; Odtworzenie HL i DE
        RET

; -----------------------------------------------------------------------
; CSTS/FFC3 - procedura systemowa
; Badanie czy klawisz wcisniety ?
;
; WEJ: -
; WYJ:  CY=1 - klawisz wcisniety.
;        A   - kod tablicowy klawisza wcisniet.
;
;        CY=0 - klawisz puszczony
; ZMIENIA: AF                   STOS: 2
; WYWOLANIE: CALL  CSTS         ;CSTS/FFC3
; -----------------------------------------------------------------------

; Realizacja skoku posredniego do CSTSM
; CSTS:  JP  CSTSM  ;Wejscie do CSTSM !!!
; JP  CSTSM -inicjowane po wlaczeniu zasil.
; MIK94 - uklad zastepczy portu we/wy typu 8255
CSTSM:
        PUSH    HL
        PUSH    BC
        LD      L,0AH           ; L-licznik
CST1:
        DEC     L               ; L=9,8...1,0,0FFH
        JP      M,CST2          ; Klaw. nie wcisniety
        LD      A,L             ; A=9,8...1,0
        ; Ustawienie dekodera U1 w MIK94 (rys R27)
        LD      (KLAW),A
        OUT     (PA),A
        ; Ustawienie dekodera U1 w MIK90. Sterowanie
        ; bitami gdyz PC7-PC5 nie moga ulec zmianie.
        ; PC75 - ustawiane w przerwaniu NMI!
        RLCA
        RLCA
        RLCA
        RLCA
        LD      B,A
        LD      C,4             ; Licznik bitow
CST3:   LD      A,B
        RLCA                    ; CY:=A7
        LD      B,A
        DEC     C               ; Nie zmienia CY !
        LD      A,C
        JP      M,CST4          ; Gdy PC30 ustawione
        RLA                     ; A0:=CY-slowo sterujace
        OUT     (CONTR),A
        JR      CST3
        ; Sprawdzenie czy klawisz wcisniety
CST4:
        IN      A,(PA)
        AND     70H             ; Bity B6-B4
        CP      70H             ; Z=1 nie wcisniety
        ; CY=0 - wazne dla rozkazu JP M,CST2
        JR      Z,CST1          ; Nie wcis. (CY=0!)
        OR      L               ; Kod rzeczyw. klaw.
        POP     BC
        POP     HL              ; Odtworzenie HL,BC

; -----------------------------------------------------------------------
; KONW - procedura pomocnicza
; Konwersja kodu rzeczywistego klawisza na kod
; tablicowy (tablica TKLAW).
;
; WEJ: A - rzeczywisty kod klawisza
; WYJ: CY=0 - klawisz nielegalny
;            (nie istnieje w TKLAW)
;      CY=1 - klaw. legalny (istnieje w TKLAW)
;      A    - kod tablicowy klawisza
; ZMIENIA: AF                   STOS: 2
; -----------------------------------------------------------------------
KONW:   PUSH    HL
        PUSH    BC              ; Ochrona HL i BC
        LD      HL,TKLAW        ; Adres tablicy TKLAW
        LD      B,LTKLAW        ; Dlugosc tablicy
CST5:
        CP      (HL)            ; Czy to ten ?
        SCF                     ; CY=1
        JR      Z,CST2          ; Znaleziono !
        INC     HL              ; Na nastepny kod rzeczyw.
        DJNZ    CST5            ; Szukaj dalej
        OR      A               ; Klawisz nielegalny (CY=0)
CST2:   LD      A,L             ; Pobranie kodu tablicowego
        POP     BC
        POP     HL              ; Odtw. HL i BC
        RET

; -----------------------------------------------------------------------
; MA - zlecenie *A
; Obliczanie sumy roznicy dwoch czterocyfrowych
; liczb szesnastkowych.
; *A[LICZBA1][SPAC][LICZBA2][CR]
; -----------------------------------------------------------------------
MA:     CALL    EXPR            ; Pobranie parametrow
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
        ; Wej. do proc. CIM - czekanie na wcis. klaw.

; -----------------------------------------------------------------------
; CI/FFC6 - procedura systemowa
; Pobranie znaku z klawiatury - czekanie dopoki
; klawisz nie zostanie puszczony, a nastepnie wcis-
; niety. Rozpoznanie klawiszy CR,SPAC.
;
; WEJ: -
; WYJ:  A - pobrany znak
;       CY=1       - znak CR
;       Z=1 i CY=0 - znak SPAC
; ZMIENIA: AF                   STOS: 4
; WYWOLANIE: CALL  CI           ;CI/FFC6
; -----------------------------------------------------------------------

; Realizacja skoku posredniego do adresu CIM
; CI:  JP  CIM   ;Wej. do procedury CIM !
; JP  CIM -inicjowane po wlaczeniu zasilania
CIM:
        PUSH    HL              ; Ochrona HL
        LD      HL,LCI          ; Licznik zmniej. w NMI
CI0:    LD      (HL),20         ; 20*2=40 mS
CI1:    LD      A,(HL)
        OR      A
        JR      NZ,CI1          ; Opoznienie 40 mS
        CALL    CSTS            ; Czy klaw. wcisniety ?
        JR      C,CI0           ; Czekaj na puszczenie

; Klawisz puszczony
CI2:
        LD      (HL),20         ; 40 mS
CI3:    LD      A,(HL)
        OR      A
        JR      NZ,CI3          ; Czekaj 40mS
        CALL    CSTS            ; Czy klawisz wcisniety ?
        JR      NC,CI2          ; Czekaj na wcisniecie

; Klawisz wcisniety
        INC     HL              ; Wskazuje licznik SYG
        LD      (HL),50         ; 50*2=100mS
        ; Sygnal dzwiekowy generow. jest przez 100 mS
        ; Realizuje przerwanie NMI
        POP     HL              ; Odtworzenie HL

; -----------------------------------------------------------------------
; CRSPAC - procedura pomocnicza
; Badanie czy znak w rej. A jest CR lub SPAC
;
; WEJ: A - tablicowy kod znaku (tablica TKLAW)
; WYJ: CY=1       - znak CR
;      Z=1 i CY=0 - znak SPAC
;      Z=0         - znak inny niz CR lub SPAC
; ZMIENIA: F                    STOS: 0
; -----------------------------------------------------------------------
CRSPAC:
        CP      SPAC
        RET     Z               ; Z=1 i CY=0 - SPAC
        CP      CR
        SCF
        RET     Z               ; CY=1 - znak CR
        CCF
        RET                     ; Z=0 - inny niz CR,SPAC

; -----------------------------------------------------------------------
; COM - procedura systemowa
; Wyswietlenie znaku ktorego kod siedmiosegmentowy
; umieszczony jest w rejestrze C wedlug PWYS.
;
; WEJ: C - znak do wyswietlenia
; WYJ: wyswietlenie znaku w/g PWYS
; ZMIENIA: AF                   STOS: 3 COM
;                                STOS: 2 COM1
; WYWOLANIE:
; CALL  COM   lub   CALL  COM1
; DB    PWYS
; Jesli PWYS nielegalne to natychmiastowy
; powrot bez wyswietlenia.
; -----------------------------------------------------------------------
COM:
        RST     USPWYS          ; ustawienie PWYS
COM1:
        PUSH    HL
        PUSH    BC              ; Ochrona HL i BC
        LD      HL,(APWYS)      ; Adres PWYS
        LD      C,(HL)          ; Pobranie PWYS
        LD      A,C
        RRCA
        RRCA
        RRCA
        RRCA
        AND     0FH             ; Ilosc znakow angazow.
        LD      B,A
        JR      Z,CO2           ; 0 znakow angazowanych
        LD      A,C
        AND     0FH             ; Nr. pozycji wyswiet.
        ADD     A,B
        CP      9
        JR      NC,CO2          ; Nielegalne PWYS
        ADD     A,L
        LD      L,A
        ; HL - adres najstarszej angazowanej cyfry
        ; Bufor BWYS musi lezec w obrebie strony
COM2:
        DEC     B
        JR      Z,COM3          ; Wszyst. znaki przesun.
        DEC     HL
        LD      A,(HL)
        INC     HL
        LD      (HL),A          ; Przes. znaku w BWYS
        DEC     HL              ; Przes. nastepny znak
        JR      COM2
COM3:
        POP     BC
        LD      (HL),C          ; Wyswietlenie znaku
        POP     HL
        RET

; -----------------------------------------------------------------------
; PRINT - procedura systemowa
; Wyswietlenie komunikatu w/g PWYS
;
; WEJ: HL - adres pierwszego znaku do wyswietlenia.
;      Po ostatnim znaku komunikatu musi byc
;      0FFH - kryterium konca.
; WYJ: wyswietlenie komunikatu w/g PWYS
; ZMIENIA: AF,HL,C              STOS: 3
; WYWOLANIE:
; CALL  PRINT  lub  CALL  PRINT1
; DB    PWYS
; -----------------------------------------------------------------------
PRINT:
        RST     USPWYS
PRINT1:
        LD      A,(HL)          ; Pobranie znaku
        CP      0FFH            ; Czy znak 0FFH ?
        RET     Z               ; Wroc gdy 0FFH
        LD      C,A
        CALL    COM1            ; Wyswietlenie znaku
        INC     HL              ; Nastepny
        JR      PRINT1

; -----------------------------------------------------------------------
; CO - procedura systemowa
; Wyswietlenie cyfry szesnastkowej umieszczonej
; w rej. C w/g PWYS
;
; WEJ: C - cyfra do wyswietlenia
;      C=<0FH - cyfra legalna
; WYJ: wyswietlenie cyfry w/g PWYS
; ZMIENIA: AF                   STOS: 5
; WYWOLANIE:
; CALL  CO   lub   CALL  CO1
; DB    PWYS
; Jesli cyfra nielegalna to natychmiast. powrot
; -----------------------------------------------------------------------
CO:
        RST     USPWYS          ; Ustawienie PWYS
CO1:
        PUSH    HL
        PUSH    BC              ; Ochrona HL i BC
        LD      HL,TSIED        ; Adr. tablicy TSIED
        LD      A,C
        CP      10H
        JR      NC,CO2          ; Cyfra nielegalna
        ADD     A,L             ; TSIED- w obrebie strony !
        LD      L,A
        LD      C,(HL)          ; Pobranie kodu cyfry
        CALL    COM1            ; Wyswietlenie
CO2:    POP     BC
        POP     HL
        RET

; -----------------------------------------------------------------------
; PARAM - procedura systemowa
; Pobieranie do rejestrow HL czterocyfrowej
; liczby szesnastkowej z jednoczesnym jej
; wyswietlaniem w/g PWYS
; -----------------------------------------------------------------------
PARAM:
        RST     USPWYS          ; Ustawienie PWYS
PARAM1:
        RST     TI1             ; Pobranie pierwsz. znaku
        JR      Z,PARAM1        ; Gdy CR lub SPAC

; -----------------------------------------------------------------------
; PARA1 - procedura systemowa
; Dzialanie identyczne jak PARAM1 lecz pierwsza
; cyfra szesnastkowa dostarczona w rej. A.
; Musi byc spelnione A=<0FH
; WYWOLANIE: CALL  PARA1
; -----------------------------------------------------------------------
PARA1:
        LD      HL,0
PAR1:   PUSH    AF              ; Ochrona AF
        CP      10H             ; Czy cyfra szesnast. ?
        JR      NC,PAR2         ; Nie szesnastkowa
        POP     AF              ; Odtw. wskaznikow
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL           ; Przes. w lewo o 4 bity
        OR      L               ; Dopisanie ostat. cyfry
        LD      L,A
PAR3:   RST     TI1             ; Pobr. nast. znaku
        JR      PAR1
PAR2:   POP     AF              ; Odtw. znaku i wskaznik.
        JR      NZ,PAR3         ; Inny niz CR lub SPAC
        PUSH    AF              ; Ochrona AF
        CALL    CLR1            ; Zgasz. angazowanych cyfr
        POP     AF              ; Odtworzenie AF
        RET

; -----------------------------------------------------------------------
; EXPR - procedura systemowa
; Pobranie ciagu czterocyfrowych liczb szesnastkowych
; z jednoczesnym ich wyswietlaniem.
;
; WEJ: C - ilosc parametrow (liczb) do pobrania
; WYJ: pobrany ciag parametrow umieszcz. na stosie
; ZMIENIA: AF,HL,C              STOS: 10
; WYWOLANIE:
; CALL  EXPR   lub  CALL  EXPR1
; DB    PWYS
; [LICZBA1][SPAC][LICZBA2][SPAC]...[LICZBAn][CR]
; -----------------------------------------------------------------------
EXPR:
        RST     USPWYS          ; Ustawienie PWYS
EXPR1:
        CALL    PARAM1          ; Pobranie liczby
        EX      (SP),HL
        ; Liczbe nalezy schowac przed adresem powrotu
        PUSH    HL              ; Chow. adr. powrotu
        DEC     C
        JR      Z,EXP2          ; Koniec pobier. ciagu
        JR      NC,EXPR1        ; Pobierz nast. liczbe
        ; Obsluga bledu lokalnego
EXP1:
        PUSH    BC              ; Ochrona BC
        LD      C,ANUL          ; Znak anulowania
        CALL    COM1            ; Wysw. znaku anulow.
        POP     BC              ; Odtw. BC
        ; Kasowanie ostatnio pobranej liczby
        POP     HL              ; Adr. powrotu
        EX      (SP),HL         ; Kasowanie
        INC     C               ; Przywr. stanu rej. C
        JR      EXPR1           ; Probuj raz jeszcze
EXP2:   RET     C               ; Ostatni musi byc CR
        JR      EXP1            ; Wcisniety SPAC

; -----------------------------------------------------------------------
; CZAS - procedura systemowa
; Wyswietlenie aktualnego czasu lub daty
;
; WEJ: HL=SEK/FFED - wyswietlenie czasu
;      HL=DNITYG/FFF0 - wyswietlenie daty
; WYJ: wyswietlenie aktualnego czasu lub daty
; ZMIENIA: AF,C                 STOS:9
; WYWOLANIE:      CALL  CZAS
; -----------------------------------------------------------------------
CZAS:
        LD      A,(HL)
        RST     LBYTE           ; SEK
        DB      20H
        INC     HL
        LD      A,(HL)
        RST     LBYTE           ; MIN
        DB      23H
        INC     HL
        LD      A,(HL)
        RST     LBYTE           ; GODZ
        DB      26H
        DEC     HL
        DEC     HL              ; Odtworzenie HL
        RET

; -----------------------------------------------------------------------
; HILO - procedura systemowa
; Zmniejszenie rej. HL o 1 a nastepnie testowanie
; czy DE>=HL
; WEJ: HL,DE parametry wejsciowe
; WYJ: HL=HL+1 , DE-HL
;      Jesli CY=0 to DE>=HL
;      Jesli CY=1 to DE< HL
; ZMIENIA: AF,HL                STOS: 0
; WYWOLANIE: CALL  HILO
; -----------------------------------------------------------------------
HILO:
        INC     HL
        LD      A,E             ; DE-HL
        SUB     L
        LD      A,D
        SBC     A,H
        RET

; -----------------------------------------------------------------------
; C. D. - P R O G R A M U  G L O W N E G O
; -----------------------------------------------------------------------

CA80A:
        LD      SP,TOS          ; Ustaw. stosu systemow.
        ; Inicjacja obszaru RAM angazowanego przez
        ; program MONITORA. Tablica TRAM/5C8
        LD      HL,KTRAM
        LD      DE,INTU+2       ; Pkt. 5.0 MIK05
        LD      BC,LTRAM        ; Dlugosc bloku
        LDDR
        LD      A,HIGH TOS      ; Starszy bajt TOS/FF8D
        LD      I,A             ; Inicjacja rej. I
        IM      1               ; Przerwania "TRYB 1"
        ; Inicjacja ukladu zegara Z80A CTC
        ; LOW INTU0 - mlodszy bajt adresu INTU0/FFD0
        LD      A,LOW INTU0     ; Wektor dla Z80A CTC
        OUT     (CHAN0),A        ; Wpisanie wektora
        ; Ustawienie kanalu 1 ukladu Z80A CTC w tryb
        ; "TIMER". Czest. wyjsciowa ZC/TO1=1 kHz
        LD      A,CCR1          ; Slowo sterujace
        OUT     (CHAN1),A        ; Wpisanie CCR1
        LD      A,TC1           ; Stala dla timera
        OUT     (CHAN1),A        ; Wpisanie stalej TC1
        ; Jesli PA0=1 (8255) to ustaw. przerwan w TRYB2
        IN      A,(PA)          ; Odczyt portu PA
        RRCA                    ; CY:=PA0
        JR      NC,SIM1
        IM      2               ; Przerwania w TRYB2
        ; Jesli PA1=1 to skok do RTS
SIM1:   RRCA                    ; CY:=PA1
        JP      C,RTS           ; Pkt. 5.0 MIK05
        ; Jesli PA2=1(8255) to inicjacja emulatora
        RRCA                    ; CY:=PA2
        JP      C,EMINIT

; -----------------------------------------------------------------------
; START - oczekiwanie na wprow. nowego zlecenia
;         Wejscie glowne do programu MONITORA
;
; Wszystkie zlecenia progr. MONITORA koncza sie
; skokiem do etykiety "START". Nacisniecie w do-
; wolnej chwili klaw. "M" rowniez konczy sie
; skokiem do "START"
; -----------------------------------------------------------------------

; Petla glowna programu MONITORA
START:
        LD      SP,TOS          ; Ust. stosu systemowego
        RST     CLR             ; Zerowanie wyswietlacza
        DB      80H             ; Wszystkie cyfry
START1: LD      HL,KO1          ; Poczatek komunikatu
        CALL    PRINT           ; Wyswiet. CA80
        DB      40H
        CALL    EMUL            ; Sprawdz. czy emulat.
        CALL    TI              ; Pobranie zlecenia
        DB      17H             ; Najstarsza cyfra wysw.
        LD      E,A             ; Numer zlecenia
        CP      LCT             ; Czy zlec. legalne ?
        JP      P,ERROR         ; Nielegalne !
        CP      GKLAW           ; Czy zlec. G
        JR      NZ,INNE         ; Inne niz G
        LD      C,GLIT          ; Kod siedmioseg. G
        CALL    COM             ; Wyswietlenie "G"
        DB      17H             ; PWYS
INNE:   RST     CLR             ; Kasuj "rr" z kom. "Err"
        DB      70H
        LD      BC,START        ; Adres powrotu
        PUSH    BC              ; Na stos
        LD      C,2             ; 2 parametry dla EXPR
        ; Wyliczenie adresu pod ktorym przechowywany
        ; jest adres procedury obslugajacej zlecenie.
        LD      HL,CTBL         ; Tablica zlecen
        LD      D,0             ; E- nr. zlecenia !
        ADD     HL,DE
        ADD     HL,DE           ; HL=HL+2*DE
        ; Pobranie adresu procedury
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        JP      (HL)            ; Pseudo CALL do proced.

; Tablica zlecen
; M0 - zlecenie nr. 0 (klawisz nr.0) itd
CTBL:
        DW      M0              ; Wyswietlenie zegara
        DW      M1              ; Ustawienie czasu
        DW      M2              ; Ustawienie daty
        DW      M3              ; Wymiana rej. procesora
        DW      M4              ; Zapis na magnetofon
        DW      M5              ; Zapis rekordu EOF
        DW      M6              ; Odczyt z magnetofonu
        DW      M7              ; Parametry transmisji
                                ; Inicjacja CA80
        DW      M8              ; Zlecenie uzytkownika
        DW      M9              ; Poszuk. slowa 8-16 bit
        DW      MA              ; Suma i roznica hex.
        DW      MB              ; Przesun. obszaru PAM.
        DW      MC              ; Praca krokowa
        DW      MD              ; Przegladanie pamieci
        DW      ME              ; Wpisanie stalej
        DW      MF              ; Przegladanie rejestr.
        DW      MG              ; Skok do progr. uzytkow.
LCT     EQU     ($-CTBL)/2

; -----------------------------------------------------------------------
; * Zlecenia programu MONITORA *
; -----------------------------------------------------------------------

; M0 - wyswietlenie zegara GODZ/MIN/SEK
M0:
        LD      HL,SEK          ; Wysw. czasu
        CALL    CZAS            ; GODZ/MIN/SEK
M01:    CALL    CSTS            ; Czy klawisz wcisnien.?
        JR      NC,M0           ; Nie wcisniety
        LD      HL,DNIM         ; Klawisz wcisniety
        CALL    CZAS            ; ROK/MIES/DZIEN
        JR      M01

; M1 - ustawienie czasu
; *1[GODZ][SPAC][MIN][SPAC][SEK][CR]
; ZMIENIA: AF,BC,HL             STOS: 11
M1:     INC     C               ; 3 parametry
        CALL    EXPR            ; Pobranie parametrow
        DB      20H             ; PWYS
        LD      HL,SEK          ; Adres SEK
DATUST: POP     BC
        LD      (HL),C          ; SEK
        INC     HL
        POP     BC
        LD      (HL),C          ; MIN
        INC     HL
        POP     BC
        LD      (HL),C          ; GODZ
        RET

; M2 - ustawienie ROK/MIES/DZIEN MIESIACA/DZIEN TYG
; *2[ROK][SPAC][MIES][SPAC][DNIM][SPAC][DNITYG][CR]
; ZMIENIA: AF,BC,HL             STOS: 11
M2:     LD      C,4             ; 4 parametry
        CALL    EXPR            ; Pobranie parametrow
        DB      20H
        LD      HL,DNITYG
        POP     BC
        LD      (HL),C          ; DNI TYG.
        INC     HL
        JR      DATUST

; -----------------------------------------------------------------------
ZMD:    CALL    SU1             ; Zlecenie *D
        JR      MC1             ; c.d. zlecenia MC !!

; -----------------------------------------------------------------------
; TKLAW - tablica klawiatury
; Zawiera kod rzeczywisty kazdego klawisza i od-
; powiadajacy mu kod tablicowy.
; Kod tablicowy - to mniej znaczacy bajt adresu
; wskazujacego kod rzeczywisty. Stad:
; TKLAW - musi rozpoczynac sie od poczatku strony !!
; Kod rzeczywisty klawisza pobierany jest przez
; procedure CSTS a nastepnie przetwarzany na kod
; tablicowy w procedurze KONW.
; -----------------------------------------------------------------------
TKLAW:
        DB      32H             ; 0/0
        DB      31H             ; 1/1
        DB      60H             ; 2/2
        DB      50H             ; 3/3
        DB      62H             ; 4/4
        DB      63H             ; 5/5
        DB      53H             ; 6/6
        DB      52H             ; 7/7
        DB      69H             ; 8/8
        DB      65H             ; 9/9
        DB      55H             ; A/0AH
        DB      59H             ; B/0BH
        DB      66H             ; C/0CH
        DB      67H             ; D/0DH
        DB      57H             ; E/0EH
        DB      56H             ; F/0FH
        DB      54H             ; G/10H
        DB      51H             ; SPAC/11H
        DB      30H             ; CR/12H
        DB      58H             ; M/13H
        DB      33H             ; W/14H
        DB      61H             ; X/15H
        DB      64H             ; Y/16H
        DB      68H             ; Z/17H
LTKLAW  EQU     $-TKLAW

; -----------------------------------------------------------------------
; TSIED - tablica zawierajaca kody siedmiosegmentowe
; cyfr szesnastkowych dla potrzeb wyswietl.
; Budowa kodu dla cyfry 0:
; K G F E D C B A
; 0 0 1 1 1 1 1 1 = 3FH
; Segment srodkowy "G" oraz kropka "K" musza byc
; wygaszone. Swieca sie segmenty: A,B,C,D,E,F
; TSIED - musi lezec w obrebie strony !!!
; -----------------------------------------------------------------------
TSIED:
        DB      3FH,06H,5BH,4FH        ; 0,1,2,3
        DB      66H,6DH,7DH,07H        ; 4,5,6,7
        DB      7FH,6FH,77H,7CH        ; 8,9,A,B
        DB      39H,5EH,79H,71H        ; C,D,E,F

; -----------------------------------------------------------------------
; TABC - tablica ograniczen czasowych
; TABM - tablica ograniczen miesiecy
; TABC,TABM - dla potrzeb zegara czasu rzeczywistego
; realizowanego w procedurze MNI.
; TABM - musi lezec w obrebie strony i musi
; byc umieszczona bezposrednio pod TABC.
; -----------------------------------------------------------------------
TABC:
        DB      WMSEK           ; Wzorzec milisekund
        DB      0               ; SETNE SEK
        DB      60H             ; Sekundy
        DB      60H             ; MIN
        DB      24H             ; GODZ
LTABC   EQU     $-TABC

        ; TABM musi byc pod TABC !!!
TABM:
        DB      32H             ; Styczen
        DB      29H             ; Luty
        DB      32H             ; Marzec
        DB      31H             ; Kwiecien
        DB      32H             ; Maj
        DB      31H             ; Czerwiec
        DB      32H             ; Lipiec
        DB      32H             ; Sierpien
        DB      31H             ; Wrzesien
        DB      32H             ; Pazdziernik
        DB      31H             ; Listopad
        DB      32H             ; Grudzien

; Kod siedmiosegmentowy komunikatu powitalnego "CA80"
KO1:    DB      39H,77H,7FH,3FH,0FFH   ; CA80

; -----------------------------------------------------------------------
; MC - realizacja pracy krokowej
; [CR] - nacisniecie klawisz CR spowoduje skok
;        do programu uzytkownika, wykonanie 1 rozkazu
;        i powrot do procedury MC.
; [SPAC] - nacisniecie klawisza SPAC spowoduje
;        przejscie do procedury MD z mozliwoscia bezpo-
;        sred. powrotu do MC (nacisniecie klaw. G).
; Nacisniecie nazwy ktoregokolwiek z rejestrow
; spowoduje przejscie do procedury MF z mozliw.
; bezposredniego powrotu do MC (nacisniecie CR)
;
; *C - wyswietlenie zawartosci PC uzytkownika - roz-
; kaz do wykonania.
; -----------------------------------------------------------------------
MC:     POP     AF              ; Zlikwidow. adr. powr.
MC1:    LD      HL,(PLOC-1)     ; PC- uzytkownika
        RST     CLR             ; Zerow. wyswietlacza
        DB      70H             ; 7 mlodszych cyfr
        RST     LADR            ; Wyswietlenie PC
        DB      43H
        LD      A,(HL)          ; Pobranie (PC)
        RST     LBYTE           ; Wyswietlenie (PC)
        DB      20H
        RST     TI1             ; Czekaj na wcisn. klaw.
        JR      NZ,ZMF          ; Inny niz CR lub SPAC
        JR      NC,ZMD          ; Klawisz SPAC

; Wcisniety klawisz CR
; Wejscie do programu uzytkownika z wymuszeniem
; przerwania po wykonaniu jednego rozkazu. Powrot
; poprzez procedure "RESTAR" do adresu MC1.
; KRP/F4D3 - zostanie umieszcz. w pam. jak nizej
; KROK:  D3F4  ;OUT (0F4H),A
        LD      HL,KRP          ; KRP- OUT (0F4H),A
        LD      (KROK),HL

; -----------------------------------------------------------------------
; RESTAR - powrot z programu uzytkownika do
; programu MONITORA.
; Podpiecie procedury RESTAR do systemu przerwan.
; -----------------------------------------------------------------------
        LD      HL,RESTAR
        LD      (INTU0),HL      ; Inicjacja
        ; Synchronizacja z przerwaniem NMI
        ; TIME - licz. binarny zmniejszany w kazdym NMI
        LD      HL,TIME
        LD      A,(HL)
SYN:    CP      (HL)
        JR      Z,SYN           ; Synchronizacja
        ; Inicjacja kanalu nr. 0 ukladu Z80A CTC
        ; Kanal zglosi przerwanie po TC0*16=160 taktach
        ; zegara. Musi to nastapic w trekcie wykonywania
        ; pierwszego rozkazu uzytkownika.
        LD      A,CCR0          ; Slowo sterujace
        OUT     (CHAN0),A        ; Tryb "TIMER"
        LD      A,TC0           ; Stala TC0
        OUT     (CHAN0),A        ; Przerw. po 160 takt.
        NOP                     ; Dolozenie 4 taktow
        JP      GO5             ; Do zlecenia *G

ZMF:
        CALL    MF              ; Zlecenie *F
        JR      MC1

; -----------------------------------------------------------------------
; MD - przegladanie pamieci z mozliwoscia modyfikacji.
; *D[POCZATEK][CR]...[CR] - przegl. do przodu
;                   [SPAC]...[SPAC] - przegl. do tylu
;    [LICZ. HEX][CR] LUB [SPAC] - modyfikacja pam.
; ZMIENIA: AF,HL,DE,C           STOS: 11
; -----------------------------------------------------------------------
MD:
        CALL    PARAM           ; Pobranie adr. poczat.
        DB      40H
SU0:    RST     LADR            ; Wysw. adresu poczatk.
        DB      43H
        LD      A,(HL)          ; Pobranie komorki pam.
        RST     LBYTE           ; Wyswietlenie (HL)
        DB      20H
        RST     TI1             ; Pobr. pierw. znaku
        JR      C,SU1           ; Wcisniety CR
SU2:    DEC     HL              ; Do tylu
        JR      Z,SU0           ; Wcisniety SPAC
        INC     HL              ; Odtworzenie HL
        CP      10H             ; Czy cyfra szesnast.
        RET     NC              ; Inny niz cyfra
        LD      C,A             ; Ochrona cyfry
        RST     CLR             ; Zerowanie wyswietl.
        DB      20H
        CALL    CO1             ; Wysw. pirwszej cyfry
        LD      A,C             ; Odtw. cyfry
        EX      DE,HL           ; Ochrona HL
        CALL    PARA1           ; Pobranie drugiej cyfry
        EX      DE,HL           ; Odtworzenie HL
        LD      (HL),E          ; Ust. nowej wart.
        JR      NC,SU2          ; Wprow. zakoncz. SPAC
        ; Wprowadzanie zakonczono klawiszem CR
SU1:    INC     HL              ; Do przodu
        JR      SU0

; -----------------------------------------------------------------------
; ME - wpisanie stalej do zadanego obszaru pamieci
; *E[OD][SPAC][DO][SPAC][STALA][CR]
; WEJ: C=2
; ZMIENIA: AF,BC,DE,HL          STOS: 11
; -----------------------------------------------------------------------
ME:     INC     C               ; 3 parametry
        CALL    EXPR            ; Pobranie parametrow
        DB      40H
        POP     BC              ; Stala
        POP     DE              ; Do
        POP     HL              ; Od
ME1:    LD      (HL),C          ; Wpisanie stalej
        CALL    HILO            ; Czy DE>=HL
        JR      NC,ME1          ; DE>=HL
        RET

; -----------------------------------------------------------------------
; MF - przegladanie i modyfikacja rej. procesora
; Procedura MF sklada sie z dwoch czesci
; MF: Wyswietla wskazniki sygn. S,Z,H,P,N,C
;     umozliwiajac latwa modyfikacje Z i CY.
; MF1: Wyswietlanie zawartosci rejestrow A,F,B,C
;      D,E,H,L,PC,SP,IX,IY z mozliw. modyfikacji.
;
; ZMIENIA: AF,HL,BC,DE          STOS: 11
; MF: *F - Wyswietlenie wskaznik. sygnalizacyj.
; Wciskanie klaw. 0-3 powoduje:
; [0] - zerowanie wskaznika Z
; [1] - ustawienie wskaznika Z
; [2] - zerowanie wskaznika CY
; [3] - ustawienie wskaznika CY
; [CR] - wyjscie z procedury
; Wcisniecie nazwy dowolnego rej. spowoduje
; przejscie do MF1:
; MF1: [NAZWA REJ.].... wyswietlanie nazw rej.
;      i ich zawartosci.
;      [CR] - wyjscie z procedury
;      [SPAC][NOWA WART.][CR] - ustaw. nowej zawart.
;                               wybranego rejestru
; -----------------------------------------------------------------------
CAR:    CP      4               ; Czy ustaw. wskaz. CY
        JR      NC,MF1          ; Nie ustawic
        RRA                     ; CY:=BIT0
        LD      A,B
        RLA                     ; Ustawienie CY
ZAP:    LD      (DE),A          ; Zapamietanie wskaznik.

; Wejscie do procedury MF
MF:
        RST     CLR             ; Zerow. wyswietlacza
        DB      70H             ; 7 mlodszych cyfr
        LD      HL,TFLAG        ; Tablica wskaznikow
        LD      DE,FLOC         ; Adr. rej. F uzytkowk.
        LD      B,8             ; Licznik przesuniec
        LD      A,(DE)          ; Pobranie rej. F
        AND     0D7H            ; Maskow. bitow B5,B3
WYSW:   RLA
        JR      NC,ZER          ; Wskaznik=0
        LD      C,(HL)          ; Pobr. symbolu wskaz.
        PUSH    AF              ; Ochrona AF
        CALL    COM1            ; Wysw. symbolu
        POP     AF              ; Odtworz. AF
ZER:    INC     HL              ; Adr. nast. symbolu
        DJNZ    WYSW
        LD      A,(DE)          ; Pobranie rej. F
        RLA
        RLA                     ; Wyizolowanie wsk. Z
        LD      C,A             ; Dla wskaznika Z
        LD      A,(DE)          ; Pobr. rej. F uzytkowk.
        RRA                     ; Wyizolowanie wsk. CY
        LD      B,A             ; Dla wskaznika CY
        RST     TI1             ; Pobierz znak
        CP      2               ; Czy ustaw. wsk. Z ?
        JR      NC,CAR          ; Nie ustawic
        RRA                     ; CY:=bit B0
        LD      A,C
        RRA
        RRA
        RRA                     ; Ustawienie wsk. Z
        JR      ZAP             ; Zapamietaj rej. F

; Czesc II  zlecenia *F
MF1:
        LD      D,A             ; Zapamiet. nazwy rej.
        RST     CLR             ; Zerow. 7 mlodsz. cyfr
        DB      70H
        LD      C,D
        CALL    CO              ; Wysw. nazwy rejestru
        DB      15H
        LD      A,D
        LD      HL,ACT1         ; Adr. tab. ACT1
        LD      BC,LACT1        ; Dlugosc tablicy
        CPIR                    ; Przeszukanie ACT1
        JR      NZ,X4           ; Gdy nie znaleziono
        LD      C,(HL)          ; Nazwa rej. z ACT1
        CALL    COM             ; Wyswietl. nazwy
        DB      15H
        ; Spr. czy ostatnio wcisniety znak jest
        ; rzeczywiscie nazwa rejestru
X4:     LD      A,D             ; Przeszuk. tab. ACTBL
        LD      HL,ACTBL-3
        LD      C,NREGS+1       ; Dlugsc ACTBL+1
X0:     INC     HL
        INC     HL
        INC     HL
        DEC     C
        RET     Z               ; Nazwa falszywa
        CP      (HL)
        JR      NZ,X0
        ; Nazwa legalna
        CALL    DREG            ; Wyswiet. zawart. rej.
        RST     TI1
        RET     C               ; Wroc gdy CR
        JR      NZ,MF1          ; Inny niz SPAC

; Wcisniwto klawisz SPAC - zmiana zawartosci rejestru.
        RST     CLR             ; Ust. PWYS=40H
        DB      40H
        INC     B
        JR      NZ,BIT16        ; Rej. 16 bitowy
        RST     CLR             ; Ust. PWYS=20H
        DB      20H
BIT16:  CALL    PARAM1          ; Pobranie nowej wart.
        RET     NC              ; Wroc gdy nie CR
        LD      A,L
        LD      (DE),A          ; Zapam. mlodsz. bajtu
        DEC     B
        JP      M,X8            ; Rej. 8 bitowy
        INC     DE              ; Rej. 16 bitowy
        LD      A,H             ; Starszy bajt
        LD      (DE),A          ; Zapamietanie
X8:     RST     TI1             ; Pobr. nast. nazwy
        JR      MF1

; -----------------------------------------------------------------------
; DREG - procedura pomocnicza zlecenia *F
; Wylicza adres polozenia rej. uzytkownika
; a nastepnie wyswiela jego zawartosc.
;
; WEJ: HL - adres pod ktorym przechowywana jest
;           nazwa rej. w tablicy ACTBL
; WYJ: B=0FFH to DE - wskazuje adres rej. 8 bit.
;      B=0 to DE - wskazuje adres mniej znacz.
;      bajtu rej. 16 bitowego.
; ZMIENIA: AF,HL,DE,B           STOS: 9
; -----------------------------------------------------------------------
DREG:
        LD      D,MTOP          ; Starszy bajt adr.
        INC     HL
        LD      E,(HL)          ; Mlodszy bajt adr.
        INC     HL
        LD      B,(HL)          ; B=0 - Rej. 8 bitowy
                                ; B=1 - Rej.16 bitowy
        LD      A,(DE)          ; Pobr. mlodsz. bajtu
        RST     LBYTE           ; Wysw. mlodsz. bajtu
        DB      20H
        DEC     B
        RET     M               ; Gdy rej. 8 bitowy
        INC     DE              ; Rej. 16 bitowy
        LD      A,(DE)          ; Pobr. starsz. bajtu
        RST     LBYTE           ; Wysw. starsz. bajtu
        DB      22H
        DEC     DE              ; Wskazuje mlod. bajt
        RET

; -----------------------------------------------------------------------
; TFLAG - tablica wskaznikow sygnalizacyjnych
; zawiera kody siedmiosegmentowe wskaznikow
; sygnal. wysw. na wyswietlaczu.
; -----------------------------------------------------------------------
TFLAG:  DB      6DH,5CH,00H,76H        ; SO-H
        DB      00H,73H,54H,39H        ; -PNC

; -----------------------------------------------------------------------
; ACT1 - tablica zawiera kody tablicowe (TKLAW)
; oraz kody siedmioseg. rej. S,L,H,IX,IY.
; -----------------------------------------------------------------------
ACT1:   DB      05H,6BH                ; IX/5
        DB      06H,72H                ; IY/6
        DB      07H,6DH                ; S/7
        DB      08H,76H                ; H/8
        DB      09H,38H                ; L/9
        DB      GKLAW,73H              ; P/GKLAW
LACT1   EQU     $-ACT1

; -----------------------------------------------------------------------
; ACTBL - tablica zawierajaca nazwe legalnego
; rejestru (kod tablicowy odpow. klaw.),mniej
; znaczacy bajt adr. wskazujacego polozenie
; zawartosci rej. oraz dlugosc rej.(0-8bitow
; 1-16bitow)
; -----------------------------------------------------------------------
ACTBL:  DB      0AH,ALOC AND 0FFH,0    ; A/0A
        DB      0BH,BLOC AND 0FFH,0    ; B/0B
        DB      0CH,CLOC AND 0FFH,0    ; C/0C
        DB      0DH,DLOC AND 0FFH,0    ; D/0D
        DB      0EH,ELOC AND 0FFH,0    ; E/0E
        DB      0FH,FLOC AND 0FFH,0    ; F/0F
        DB      08H,HLOC AND 0FFH,0    ; H/08
        DB      09H,LLOC AND 0FFH,0    ; L/09
        DB      GKLAW,PLOC-1 AND 0FFH,1 ; P/10
        DB      07H,SLOC AND 0FFH,1    ; S/07
        DB      05H,IXLOC-1 AND 0FFH,1 ; IX/5
        DB      06H,IYLOC-1 AND 0FFH,1 ; IY/6
NREGS   EQU     ($-ACTBL)/3

; -----------------------------------------------------------------------
; MG - wejscie do programu uzytkownika
; G[CR] - wejscie w/g aktualnego PC uzytkownika
; G[SPAC][PU1][CR] - wejscie j/w z zastaw. pulapki
; G[SPAC][PU1][SPAC][PU2][CR] - j/w lecz 2 pulapki
; G[ADRW][CR] - skok do adresu wejscia [ADRW]
; G[ADRW][SPAC][PU1][CR] - j/w z zastaw. pulapki
; G[ADRW][SPAC][PU1][SPAC][PU2][CR]-j/w lecz 2 pul.
; Po napotkaniu ktorekolwiek z pulapek nastepuje
; przejscie do programu MONITORA i wykonanie
; procedury RESTAR.
; -----------------------------------------------------------------------
MG:     POP     AF              ; Zlikwidowanie adr. powr.
        CALL    TI              ; Pobr. pierwszego znaku
        DB      40H
        JR      Z,GOA           ; CR lub SPAC
        CALL    PARA1           ; Pobranie ADRW
        LD      (PLOC-1),HL     ; PC := ADRW
GOA:    JR      C,GO4           ; Wcisnieto CR
        ; Pobranie 1 lub 2 pulapek
GO1:    LD      C,KRESKA        ; Symbol pulapki
        CALL    COM             ; Wyswietlenie symbolu
        DB      14H
        LD      B,2             ; Max. 2 pulapki
PU2:    CALL    PARAM           ; Pobranie pulapki
        DB      40H
        PUSH    HL              ; Zapamietanie pulapki
        DEC     B               ; Nie zmienia CY !
        JR      C,TRA1          ; CR -zastaw pobr. pulap.
        JR      NZ,PU2
        ; Obsluga bledu systemowego
ERROR:
        LD      SP,TOS          ; Stos systemowy
        RST     CLR             ; Zerowanie wyswietl.
        DB      80H
        LD      HL,KO2          ; Adr. komunikatu "Err"
        CALL    PRINT           ; Wyswiet. "Err"
        DB      35H
        JP      START1          ; Pobierz kolejne zlec.

; -----------------------------------------------------------------------
; Zastawienie 1 lub 2 pulapek
; -----------------------------------------------------------------------
TRA1:   LD      HL,TLOC         ; Adr. przechowyw. pulap.
TRA2:
        POP     DE              ; Adres pulapki
        LD      (HL),E
        INC     HL
        LD      A,(DE)
        LD      (HL),A          ; Zap. komorki pamieci
        LD      A,RST30         ; Rozkaz RST 30H
        LD      (DE),A          ; Zastawienie pulapki
        INC     HL
        LD      A,B
        INC     B
        OR      A               ; Ustawienie wskaznikow
        JR      Z,TRA2          ; Ustaw 2 pulapke
GO4:    RST     CLR             ; Wygaszenie wyswietlacza
        DB      80H
        ; GSTAT=0 - sygnalizuje wykonywanie progr. uzytkow
GO5:    XOR     A               ; Zerowanie A
        LD      (GSTAT),A       ; Zaznacz. prog. uzytkow.
        OUT     (RESI),A        ; Kasow. zglosz. przerwan.
        JP      EXIT            ; Wejscie do prog. uzytkow.

; -----------------------------------------------------------------------
; M3 - wymiana rejestrow procesora
; Wymiana rejestrow glownych na pomocnicze i odwr.
; ZMIENIA: AF,HL,DE,BC          STOS: 9
; *3[CR]
; -----------------------------------------------------------------------
M3:     RST     TI1             ; Czy CR
        JR      NC,ERROR        ; Nie CR
        ; Pobranie rej. glownych uzytkownika
        LD      SP,ELOC
        POP     DE              ; Pobranie DE
        POP     BC              ; BC
        POP     AF              ; Pobranie AF
        LD      HL,(LLOC)       ; Pobranie HL
        ; Wymiana na rej. pomocnicze
        EX      AF,AF'
        EXX
        ; Odtworzenie rejestrow glownych uzytkownika
        LD      (LLOC),HL       ; Odtworzenie HL
        PUSH    AF
        PUSH    BC
        PUSH    DE              ; Odtworzenie AF,BC,DE
        JP      START           ; Ustaw. SP w START.

; -----------------------------------------------------------------------
; M7 - inicjacja systemu lub ustaw. parametrow
;       transmisji magnetofonowej.
; A. Inicjacja systemu CA80 (skok do adr. 0000H)
; *7[CR]
; B. Ustawienie parametrow transmisji magnetof.
; *7[MAGSP DLUG][CR]
; DLUG - dlugosc bloku danych <1...0FFH>
; MAGSP - szybkosc transmisji magnetofonowej.
; -----------------------------------------------------------------------
M7:     RST     CLR             ; Ustawienie PWYS
        DB      40H
        RST     TI1
        JP      C,CA80          ; Inicjacja systemu
        CP      10H             ; Tylko cyfry szesnastkow.
        JR      NC,ERROR
        CALL    PARA1           ; Pobranie parametrow
        JR      NC,ERROR        ; Gdy SPAC
        LD      (DLUG),HL       ; Zapisanie paramet
        RET

; -----------------------------------------------------------------------
; M9 - poszukiwanie slowa 16-to bitowego
;       lub 8-mio bitowego.
; *9[SLOWO][SPAC][ADRES POCZATKU][CR]
; -----------------------------------------------------------------------
M9:     CALL    EXPR            ; Pobierz dwa paramet.
        DB      40H
        LD      BC,4000H        ; Obszar 16kb
        POP     HL              ; Adres poczatku
M91:    POP     DE              ; Slowo do znalezienia
M90:    LD      A,D
        OR      A               ; Czy slowo 16 bitow ?
        JR      NZ,SLOW16       ; Slowo 16 bitowe
        LD      A,E             ; Slowo 8 bitowe
        CPIR                    ; Poszukiw. pierwsz. bajtu
        RET     PO              ; Nie znaleziono
        LD      A,D
        OR      A               ; Czy slowo 8 bitowe
        JR      Z,SLOW8         ; Slowo 8 bitowe
SLOW16: LD      A,E             ; Slowo 16 bitowe
        CP      (HL)            ; Spraw. 2 bajtu
        JR      NZ,M90          ; Drugi bajt do kitu
SLOW8:  DEC     HL              ; Na pierwszy bajt
        PUSH    DE              ; Ochrona DE
        CALL    SU0             ; Wywolanie zlec. *D
        INC     HL              ; Szuk. dalsze slowa
        JR      M91

; -----------------------------------------------------------------------
; MB - przesuniecie obszaru pamieci
; *B[ADR1][SPAC][ADR2][SPAC][ADR3][CR]
; Zlecenie powoduje przesuniecie obszaru <ADR1,ADR2>
; do obszaru rozpoczynajacego sie od adresu ADR3.
; Przesuwanie jest inteligentne tzn. ADR3 moze
; lezec zarowno wewnatrz <ADR1,ADR2> jak i poza
; tym obszarem.(przesow zawsze poprawny)
; Musi byc spelnione: ADR1=<ADR2 - w przeciwnym
; razie zlecenie sygnalizuje blad.
; -----------------------------------------------------------------------
MB:     INC     C               ; 3 parametry
        CALL    EXPR            ; Pobranie parametrow
        DB      40H
        POP     BC              ; ADR3
        POP     HL              ; ADR2
        POP     DE              ; ADR1
        OR      A               ; CY=0
        PUSH    HL              ; ADR2
        SBC     HL,DE           ; ADR2-ADR1
        JP      C,ERROR         ; Gdy ADR2<ADR1
        EX      (SP),HL         ; (SP) - dlugosc
        PUSH    HL              ; ADR2
        PUSH    DE              ; ADR1
        SBC     HL,BC           ; ADR2-ADR3
        JR      C,PRZOD         ; ADR2<ADR3
        POP     HL
        PUSH    HL              ; ADR1
        SBC     HL,BC           ; ADR1-ADR3
        JR      NC,PRZOD        ; ADR1>=ADR3
        ; ADR1< ADR3< ADR2
        ; Przesuwanie do tylu
        POP     HL              ; ADR1
        POP     DE              ; ADR2
        POP     HL
        PUSH    HL              ; Dlugosc
        ADD     HL,BC           ; Dlugosc+ADR3
        EX      DE,HL           ; DE - Dlugosc+ADR3
                                ; HL - ADR2
        POP     BC              ; Dlugosc
        INC     BC              ; Dlugosc+1
        LDDR
        RET

PRZOD:
        POP     HL              ; ADR1
        LD      E,C
        LD      D,B             ; DE :- ADR3
        POP     BC              ; ADR2
        POP     BC              ; Dlugosc
        INC     BC              ; Dlugosc+1
        LDIR
        RET

; -----------------------------------------------------------------------
; MWCIS - procedura bezwarunkowego przejscia do
; poczatku petli glownej programu MONITORA
; (etykieta START).
; Przejscie z programu uzytkownika do programu
; MONITORA mozna wymusic w dowolnej chwili
; wciskajac klawisz "M". Jesli procedurra obslugi
; przerwania NMI stwierdzi, ze klawisz "M" jest
; wcisniety to nastepuje skok do przedstawionej
; nizej procedury MWCIS.
; -----------------------------------------------------------------------
MWCIS:
        DI                      ; Blokada przerwan
        ; Inicjacja obszaru RAM <APWYS,NMIU>
        LD      HL,TNMIU
        LD      DE,NMIU
        LD      BC,LIOCA
        LDDR
        ; (GSTAT)=0 - wykonywany program uzytkownika
        ; (GSTAT)#0 - wykonywany program MONITORA
        LD      A,(GSTAT)
        OR      A
        JP      NZ,START        ; Wyk. program MONITORA
        ; Wykonywany program uzytkownika
        ; Odtw. rej. angazowanych w procedurze NMI
        POP     BC
        POP     DE
        POP     HL
        POP     AF              ; Odtw. AF,HL,DE,BC

; -----------------------------------------------------------------------
; RESTAR - procedura przejscia z programu uzytkow.
; do programu MONITORA.
; Procedura powoduje:
; 1. Zapamietanie stanu procesora uzytkownika
;    w obszarze pamieci <TOS,PLOC>
; 2. Likwidacje wszystkich (1 lub 2) pulapek.
; -----------------------------------------------------------------------
RESTAR:
        PUSH    HL
        PUSH    DE
        PUSH    BC
        PUSH    AF
        PUSH    IX
        PUSH    IY              ; Schow. IY,IX,AF..HL
        ; <EXIT-1,TOS> - obszar przechowyw. rej. uzytkow.
        LD      DE,EXIT         ; Adr. poczatkowy
        LD      A,D             ; A#0
        LD      (GSTAT),A       ; (GSTAT)#0 - wykonyw. jest program MONITORA

        ; SP - wsk. mlodszy bajt IY uzytkow. (patrz wyzej)
        ; SP+11 - wskazuje rej. H
        ; SP+12 - wsk. mlodszy bajt rej. PC uzytkownika
        ; SP+13 - wsk. starszy bajt rej. PC uzytkownika
        ; SP+14 - stos uzytkownika przed napotkaniem
        ;         pulapki lub rozkazu RST 30H !
        ; Zapamietanie SP,IY,IX,AF,BC,DE uzytkownika
        ; W obszarze <EXIT-1,ELOC>
        LD      B,6             ; Gdyz SP,IY,IX,AF,BC,DE
RST0:   DEC     HL
        LD      (HL),D          ; Starszy bajt
        DEC     HL
        LD      (HL),E          ; Mlodszy bajt
        POP     DE              ; Kolej. IY,IX,AF,BC,DE,HL
        DJNZ    RST0
        ; DE - zawartosc rej. HL uzytkownika
        ; SP - wskazuje PC uzytkownika !
        ; HL - wskazuje komorke pamieci o adr. ELOC-TOS
        POP     BC              ; Rejestr PC uzytkownika
        LD      SP,HL           ; Ustawienie stosu system.
                                ; HL=TOS
        LD      L,LLOC AND 0FFH ; HL=adr. LLOC
        ; Zapamietanie rej. HL uzytkownika
        LD      (HL),E          ; Mlodszy bajt HL
        INC     HL
        LD      (HL),D          ; Starszy bajt HL

        ; BC - zawiera PC uzytkownika
        ; Jesli napotkano pulapke to rej. PC nalezy zmniej.
        ; o 1, gdyz PC wskazuje pierwsza komorke
        ; pamieci po rozkazie RST 30H a powinien wkazywac
        ; rozkaz RST 30H !
        DEC     BC              ; Zalozenie ze pulapka
        LD      L,LOW TLOC      ; HL=TLOC

        ; Kryterium odkrycia pulapki jest nastepujace:
        ; Jesli przyczyna wejscia do RESTAR byla pulapka
        ; to musi byc spelnione:
        ; BC=(TLOC+1)(TLOC) - PULAPKA 1
        ; lub
        ; BC=(TLOC+4)(TLOC+3) - PULAPKA 2
        ; Sprawdzenie powyzszego warunku.
        LD      D,2             ; Sprawdz. 2 pulapek
POWTR:  LD      A,(HL)
        XOR     C               ; Mlodsze bajty rowne ?
        INC     HL
        JR      NZ,NIER         ; Nie rowne
        LD      A,(HL)
        XOR     B               ; Starsze bajty rowne ?
        JR      Z,RST1          ; Przycz. byla pulapka !
NIER:   INC     HL
        INC     HL              ; HL=TLOC+3
        DEC     D
        JR      NZ,POWTR

        ; Przyczyna wejscia do RESTAR bylo wcisniecie
        ; klaw. "M" lub wykonanie rozkazu RST 30H usta-
        ; wionego przez uzytkownika - nie przez zlec.*G !
        INC     BC              ; Odtworzenie PC uzytk.

        ; Schowanie PC uzytkownika
RST1:
        LD      L,LOW PLOC-1
        LD      (HL),C          ; Mlodszy bajt PC
        INC     HL
        LD      (HL),B          ; Starszy bajt PC

        ; Informacja niesiona przez rej. D jest nastep:
        ; D=0 - nie bylo pulapki
        ; D=1 - byla pulapka nr.2
        ; D=2 - byla pulapka nr.1

        ; Kasowanie pulapek
        LD      E,2             ; 2 pulapki
        INC     HL              ; Wskazuje TLOC
TRP:    LD      C,(HL)
        XOR     A               ; Zerowanie A
        LD      (HL),A          ; Zerowanie
        INC     HL
        LD      B,(HL)          ; BC-adr. pulapki
        LD      (HL),A          ; Zerowanie
        INC     HL
        LD      A,(HL)
        LD      (BC),A          ; Odtw. (PULAPKA)
        INC     HL              ; Wskazuje TLOC+3
        DEC     E
        JR      NZ,TRP

        ; Jesli pulapek nie bylo to powyzsza petla spo-
        ; woduje nieszkodliwe, dwukrotne wpisanie informa-
        ; cji do komorki pam. o adr. 0000H. W CA80 jest
        ; to obszar pamieci stalej - EPROM.
        LD      A,D
        CALL    EMUL            ; Spraw. czy emulator
        LD      A,D
        OR      A
        JR      NZ,PUL          ; Byla pulapka
        LD      A,(KROK)
        OR      A
        JP      Z,START         ; Nie praca krokowa

        ; Praca krokowa
        ; ZCHAN/3H - slowo sterujace dla kanalu 0 ukladu
        ; Z80A CTC. Powoduje zerowanie "TIMERA".(MIK04)
        LD      A,ZCHAN
        OUT     (CHAN0),A       ; Zerow. kanalu 0
        ; Likwidacja pracy krokowej
        LD      HL,0
        LD      (KROK),HL       ; Likwidacja
        ; Realizacja skoku do MC1 (zlec. MC) z jednocz.
        ; wykonaniem rozkazu RETI.
        LD      HL,MC1
        PUSH    HL              ; Na stos
        RETI                    ; Dla potrzeb Z80A CTC !

        ; Czekanie na wcisniecie klawisza - byla pulapka
PUL:
        LD      HL,BWYS+7       ; Najstarsza cyfra
        SET     KROP,(HL)       ; Zaswiecenie kropki
        CALL    CIM             ; Czek. na wcis. klaw.
        JP      START           ; Do wejsc. glownego

; -----------------------------------------------------------------------
; EMUL - skok do emulatora pod warunkiem,ze PA2=1.
; Wywolanie EMUL nastepuje z procedury RESTAR
; lub START.
; REJ. A=<0,3> - wywolanie z procedury RESTAR
;       A=0 - nie bylo pulapki
;       A=1 - byla pulapka nr.2
;       A=2 - byla pulapka nr.1
; Rej. A=0FFH - wywolanie z procedury START
; -----------------------------------------------------------------------
EMUL:
        LD      (LCI-1),A      ; Zapamietanie rej A
        IN      A,(PA)          ; Port 8255
        AND     4               ; Czy PA2=1 ?
        RET     Z               ; Gdy PA2=0
        JP      EM              ; Skok do emulatora

; -----------------------------------------------------------------------
; Tablica inicjacji obszaru RAM angazowanego przez CA80.
; -----------------------------------------------------------------------
TRAM:
        DW      TOS-27H         ; Stos uzytkownika
        ; Wejscie do programu uzytkownika  ;EXIT
        POP     DE
        POP     BC
        POP     AF
        POP     IX
        POP     IY
        POP     HL
        LD      SP,HL           ; Odtworzenie SP uzytk.
        NOP                     ; KROK
        NOP
        LD      HL,HLUZYT       ; Odtw. HL uzytkownika
        EI                      ; Odblokowanie przerwan
        JP      PCUZYT          ; Odtw. PC uzytkownika
PLOC    EQU     $-1             ; Wsk. starszy bajt PC
        ; Pulapki programowe - zlecenie *G.
TLOC:   DW      0               ; Pulapka1
        DB      0
        DW      0               ; Pulapka2
        DB      0
        ; Parametry transmisji magnetofonowej
DLUG:   DB      16              ; Dlug. bloku danych
MAGSP:  DB      25H             ; Szybkosc transmisji

; Klucze programowe
; GSTAT=0 - wykonywany program uzytkownika
; GSTAT#0 - wykonywany program monitora
;
; ZESTAT=0 - maskowanie obslugi zegara w NMI
; ZESTAT#0 - zegar obslugiwany
GSTAT:  DB      0FFH
ZESTAT: DB      0FFH

; Skoki posrednie
; M8 - obsluga zlecenia zdefiniowanego przez
;       uzytkownika (klawisz "8")
; ERRMAG - obsluga blednego odczytu rekordu
;       z magnetofonu.
; EM - emulator
; RTS - po wlaczeniu zasilania nastepuje skok
;       do RTS/803 JESLI pa1=1 (uklad U7/8255).
M8:     JP      800H            ; Zobacz pkt 1.11 (MIK05)
ERRMAG: JP      ERROR
EM:     JP      806H
RTS:    JP      803H

; Systemowe skoki posrednie
; Inicjowane wraz z wciscnieciem klawisza "M"
; APWYS - wskazuje polozenie parametru
;         wyswietlacza PWYS.
; CSTS - procedura systemowa
; CI   - procedura systemowa
; AREST - skok do procedury RESTAR wykonywanej
;         po napotkaniu rozkazu RST 30H/F7 w programie
;         uzytkownika - prawidlowe przejscie z programu
;         uzytkownika do programu monitora.
APWYS:  DW      PWYS
CSTS:   JP      CSTSM           ; Procedura systemowa
CI:     JP      CIM             ; Procedura systemowa
AREST:  JP      RESTAR
NMIU:   RET                     ; Proced. NMI uzytkow.
        DW      0               ; NMIU: JP NMIUZYT

; Tablica przerwan uzytkownika
INTU:   JP      ERROR           ; Skok do obslugi bledu
        ; Ponizsze komorki nie sa inicjowane po wlaczeniu zasilania
INTU0   EQU     $-2
INTU1:  DW      0
INTU2:  DW      0
INTU3:  DW      0
INTU4:  DW      0
INTU5:  DW      0
INTU6:  DW      0
INTU7:  DW      0
REZ:    DS      8               ; Rezerwa

; Liczniki programowe
; LCI,SYG - liczniki dla potrzeb procedury CI -
;           obslugiwane w NMI.
; TIME - licznik binarny modulo256 (licz. do tylu)
;        zmniejszany co 2 mS w procedurze NMI
;        /przeznaczony dla potrzeb uzytkownika.
LCI:    DB      0
SYG:    DB      0               ; Sygnal wcis. klaw.
TIME:   DB      0               ; Licznik modulo256

; Zegar czasu rzeczywistego
; Odliczanie czasu w kodzie BCD
MSEK:   DB      0               ; <0,4>
SETSEK: DB      0               ; <0,99> setne sek.
SEK:    DB      0               ; <0,59> sekundy
MIN:    DB      0               ; <0,59> minuty
GODZ:   DB      0               ; <0,23> godziny
DNITYG: DB      0               ; <7,6,5,4,3,2,1>
        ; Dni tygodnia - odliczanie do tylu !!
DNIM:   DB      0               ; <1,...>dni miesiaca
MIES:   DB      0               ; <1,12> miesiace
LATA:   DB      0               ; <0,99> rok

; KLAW - aktualny stan portu wyjsciowego PA/F0
;        na plytce MIK94. Wykorzystuja procedury
;        CSTS oraz NMI.
; SBUF - bity B7,B6,B5 wskazuja aktualnie wyswiet-
;        lana cyfre z bufora BWYS. Wykorzystuje
;        wylacznie procedura NMI.
KLAW:   DB      0
SBUF:   DB      0

; Wyswietlacz siedmiosegmentowy
PWYS:   DB      0               ; Parametr wyswietlacza
        ; Bufor wyswietlacza siedmiosegmentowego
BWYS:
CYF0:   DB      0               ; Cyfra nr.0
CYF1:   DB      0               ; Cyfra nr.1
CYF2:   DB      0               ; Cyfra nr.2
CYF3:   DB      0               ; Cyfra nr.3
CYF4:   DB      0               ; Cyfra nr.4
CYF5:   DB      0               ; Cyfra nr.5
CYF6:   DB      0               ; Cyfra nr.6
CYF7:   DB      0               ; Cyfra nr.7

        .DEPHASE

; -----------------------------------------------------------------------
; Wlasciwa lokalizacja powyzszego bloku RAM - adres FF8DH
; -----------------------------------------------------------------------
        .PHASE  0FF8DH

TOS:                            ; Dno stosu systemowego
MTOP    EQU     HIGH TOS        ; Starszy bajt TOS

; Obszar przechowywania rejestrow uzytkownika
; w czasie gdy wykonywany jest program monitora.
ELOC:   DB      0               ; E
DLOC:   DB      0               ; D
CLOC:   DB      0               ; C
BLOC:   DB      0               ; B
FLOC:   DB      0               ; F
ALOC:   DB      0               ; A
        DW      0               ; IX
IXLOC   EQU     $-1             ; Wskaz. starszy bajt IX
        DW      0               ; IY
IYLOC   EQU     $-1             ; Wskaz. starszy bajt IY
        DW      TOS-27H         ; SP
SLOC    EQU     $-1             ; Wskaz.starszy bajt SP

; EXIT - procedura wejscia do programu uzytkow.
; WEJ: SP=TOS - rej. SP musi wskazywac TOS !
; WYJ: odtworzenie rejestrow uzytkownika a nast-
;      epnie skok do programu uzytkownika.
;      (rozkaz JP PCUZYT).
EXIT:
        POP     DE
        POP     BC
        POP     AF
        POP     IX
        POP     IY              ; Odtw. IY,IX,AF,BC,DE
        POP     HL
        LD      SP,HL           ; Odtworzenie SP uzytk.
        ; Praca krokowa powoduje wstawienie OUT (0F4H),A
        ; w miejsce ponizszych NOP
KROK:   NOP
        NOP
        LD      HL,HLUZYT       ; Odtw. HL uzytkownika
LLOC    EQU     $-2             ; L
HLOC    EQU     $-1             ; Rej. H uzytkownika
        EI                      ; Odblokowanie przerwan
        JP      PCUZYT          ; Odtw. PC uzytkownika
PLOC    EQU     $-1             ; Wsk. starszy bajt PC

; Pulapki programowe - zlecenie *G.
TLOC:   DW      0               ; Pulapka1
        DB      0
        DW      0               ; Pulapka2
        DB      0

; Parametry transmisji magnetofonowej
DLUG:   DB      16              ; Dlug. bloku danych
MAGSP:  DB      25H             ; Szybkosc transmisji

; Klucze programowe
GSTAT:  DB      0FFH
ZESTAT: DB      0FFH

; Skoki posrednie
M8:     JP      800H            ; Zobacz pkt 1.11 (MIK05)
ERRMAG: JP      ERROR
EM:     JP      806H
RTS:    JP      803H

; Systemowe skoki posrednie - inicjowane z wciscnieciem "M"
IOCA:   DW      PWYS            ; APWYS
        JP      CSTSM           ; CSTS
        JP      CIM             ; CI
        JP      RESTAR          ; AREST
LIOCA   EQU     $-IOCA
TNMIU:  RET                    ; NMIU
        DW      0               ; NMIU: JP NMIUZYT

KTRAM   EQU     $-1
LTRAM   EQU     $-TRAM

; -----------------------------------------------------------------------
; EMINIT - inicjacja emulatora
; Procedura laduje program do obszaru <FF00,FF7F>
; i wykonuje skok do adresu 0FF00H.
; -----------------------------------------------------------------------
EMINIT:
        LD      HL,0FF80H
        LD      B,80H           ; Dlugosc bootstrapu
        LD      A,KONF1
        OUT     (CONTR1),A      ; Slowo sterujace
                                ; TRYB1 PA-wej. PB-wyj.
        LD      A,9             ; PC4=INTE A := 1
        OUT     (CONTR1),A
EMI:    IN      A,(PC1)
        AND     8
        JR      Z,EMI           ; Bufor wejsciowy pusty
        ; Bufor pelny - odczytanie danej
        IN      A,(PA1)         ; Pobranie danej
        DEC     HL
        LD      (HL),A          ; Wpisanie do pamieci
        DJNZ    EMI             ; Gdy B#0
        JP      (HL)            ; Skok do 0FF00H

; -----------------------------------------------------------------------
; O B S L U G A   M A G N E T O F O N U
; -----------------------------------------------------------------------

; LSYNCH - ilosc bajtow synchronizacji
; MARK   - wyroznik poczatku rekordu
; ILPR   - ilosc probek dla pol bitu
LSYNCH  EQU     20H
MARK    EQU     0E2FDH
ILPR    EQU     20
LOW1    EQU     ILPR-ILPR/2-1
HIG1    EQU     ILPR+ILPR/2-1
LOW2    EQU     2*ILPR-ILPR/2-1
HIG2    EQU     2*ILPR+ILPR/2-1

; -----------------------------------------------------------------------
; M4 - zapis na magnetofon
; *4[ADR1][SPAC][ADR2][SPAC][NAZWA][CR]
; -----------------------------------------------------------------------
M4:     INC     C               ; 3 Parametry
        CALL    EXPR
        DB      40H
        POP     BC
        LD      B,C             ; B - nazwa
        POP     DE              ; ADR2
        POP     HL              ; ADR1

; -----------------------------------------------------------------------
; ZMAG - procedura systemowa
; Zapisanie obszaru pamieci na magnetofon.
; WEJ:  B - nazwa
;        HL - ADR1
;        DE - ADR2
; WYJ: obszar <ADR1,ADR2> zapisany zostanie na
;      magnetofon pod nazwa [NAZWA].
; ZMIENIA: AF,HL,C              STOS: 13
; -----------------------------------------------------------------------
ZMAG:
        CALL    SYNCH           ; Bajty synchronizacji
        PUSH    BC              ; Nazwa na stosie
WR0:    PUSH    HL              ; Ochrona HL
        LD      A,(DLUG)        ; Dlugosc bloku danych
        LD      C,A
        LD      B,0
        ; Wyliczanie dlugosci bloku danych. Ostatni blok
        ; moze byc krotszy niz "DLUG".
WR1:    INC     B
        DEC     C
        JR      Z,WR2
        CALL    HILO            ; HL:=HL+1 i DE-HL
        JR      NC,WR1          ; DE>=HL
        ; Rej. B - wyliczona dlugosc bloku danych
WR2:    PUSH    DE              ; Ochrona DE
        LD      HL,MARK         ; Wyroznik rekordu
        CALL    PADR            ; Zapisanie MARK na mag.
        POP     DE              ; ADR2
        POP     HL              ; ADR1
        POP     AF              ; A - nazwa
        PUSH    AF              ; Ochrona AF
        PUSH    DE              ; Ochrona DE
        LD      E,A             ; Nazwa
        LD      D,0             ; Zerow. sumy kontrolnej
        CALL    PBYT            ; Zapisanie nazwy
        LD      A,E             ; Nazwa
        RST     LBYTE           ; Wyswietlenie nazwy
        DB      25H
        LD      A,B             ; Dlug. bloku danych
        CALL    PBYT            ; DLUG - na magnetofon
        CALL    PADR            ; Zapis. adresu ladowania
        RST     LADR            ; Wysw. adr. ladowania
        DB      40H
        XOR     A               ; Zerowanie A
        SUB     D               ; -SMUN - sum kontr. nagl.
        CALL    PBYT            ; Zap. -SUMN
        LD      D,0             ; Zerowanie SUMD
        ; Zapisanie bloku danych na magnetofon
WR3:    LD      A,(HL)          ; Pobranie danej
        CALL    PBYT            ; Zapisanie danej
        INC     HL              ; Adr. nastepnej danej
        DJNZ    WR3
        ; SUMD - suma kontrolna bloku danych.
        XOR     A               ; A=0
        SUB     D               ; -SUMD
        CALL    PBYT            ; -SUMD na magnetofon
        POP     DE              ; Adr. konca
        DEC     HL
        CALL    HILO            ; Czy DE>=HL
        JR      NC,WR0          ; DE>=HL
        ; DE<HL - koniec zapisywania
        POP     BC              ; Zdjecie nazwy
        RET

; -----------------------------------------------------------------------
; M5 - zapisanie rekordu EOF na magnetofon
; *5[ADR.WEJ.][SPAC][NAZWA][CR]
; ADR.WEJ. - adres wejscia do programu o nazwie
;                                        [NAZWA]
; -----------------------------------------------------------------------
M5:     CALL    EXPR            ; Pobranie 2 parameteow
        DB      40H
        POP     BC
        LD      B,C             ; Nazwa
        POP     HL              ; Adr. wejscia

; -----------------------------------------------------------------------
; ZEOF - procedura systemowa
; Zapisanie rekordu EOF na magnetofon.
; WEJ: HL - adres wejscia do programu o nazwie
;           podanej w rej. B.
;      B  - nazwa programu
; WYJ: zapisanie rekordu EOF
; ZMIENIA: AF,C,D               STOS: 7
; -----------------------------------------------------------------------
ZEOF:   PUSH    HL              ; Ochrona HL
        CALL    SYNCH           ; Bajty synchronizacji
        LD      HL,MARK         ; Wyroznik pocz. rekordu
        CALL    PADR            ; MARK - na magnet.
        LD      A,B             ; Nazwa
        LD      D,0             ; Zerow. sumy kontrolnej
        CALL    PBYT            ; Zapis. nazwy
        XOR     A               ; A=0
        CALL    PBYT            ; DLUG=0
        POP     HL              ; Odtw. ADR. WEJ.
        CALL    PADR            ; ADR. WEJ. - na magnet.
        XOR     A               ; A=0
        SUB     D               ; -SUMN
        JR      PBYT            ; -SUMN - na magnet.

; -----------------------------------------------------------------------
; SYNCH - procedura pomocnicza
; Zapisuje rekord synchronizacji bedacy ciagiem
; 32 bajtow o wartosci 00H.
; WEJ: -
; WYJ: zapis 32 bajtow 00H na magnetofon.
; ZMIENIA: AF                   STOS: 6
; -----------------------------------------------------------------------
SYNCH:  PUSH    BC              ; Ochrona BC
        LD      B,LSYNCH        ; Ilosc bajtow
PBX:    XOR     A               ; A=0
        CALL    PBYTE
        DJNZ    PBX
        POP     BC
        RET

; -----------------------------------------------------------------------
; PADR - procedura pomocnicza
; Zapis rej. HL na magnetofon.
; WEJ: HL - dana do zapisania
; WYJ: zapisanie stanu rej. HL na magnetofon
;      D - aktualny stan sumy kontrolnej.
; ZMIENIA: AF,C,D               STOS: 6
; -----------------------------------------------------------------------
PADR:   LD      A,L
        CALL    PBYT            ; Zapisanie rej. L
        LD      A,H
        ; Zapisanie rej. H

; -----------------------------------------------------------------------
; PBYT - procedura pomocnicza
; Zapisanie rej. A na magnetofon.
; Obliczanie sumy kontrolnej w rej. D [D:=D+A]
; WEJ: A - dana do zapisania
; WYJ: zapisanie rej. A na magnet.
;      D - aktualny stan sumy kontrolnej
; ZMIENIA: AF,C,D               STOS: 5
; -----------------------------------------------------------------------
PBYT:   LD      C,A             ; Ochrona rej. A
        ADD     A,D             ; Suma modulo256
        LD      D,A             ; Suma kontrolna
        LD      A,C             ; Odtw. rej. A

; -----------------------------------------------------------------------
; PBYTE - procedura pomocnicza
; Dzialanie jak PBYT lecz nie jest obliczana
; suma kontrolna.
; ZMIENIA: AF                   STOS: 5
; -----------------------------------------------------------------------
PBYTE:  PUSH    DE
        PUSH    BC              ; Ochrona DE,BC
        LD      C,A             ; Dana do zapisania
        LD      E,9             ; Ilosc bitow
BIT1:   CALL    GJED            ; Generowanie jedynki
BIT4:   CALL    GZER            ; Generowanie zera
BIT3:   DEC     E
        JR      Z,KBIT          ; Koniec zapisu
        LD      A,C
        RRA                     ; CY:=bit0
        LD      C,A
        JR      C,BIT1          ; Gdy jedynka
        CALL    GZER            ; Generowanie zera
        LD      A,C
        RRA
        CALL    GJED            ; Generowanie jedynki
        LD      A,C
BIT2:   LD      C,A
        CALL    GJEDD           ; Gener. podwojnej jedynki
        DEC     E               ; Na pewno jest E#0
        JR      BIT4
        ; Generowanie 2 bitow stopu
KBIT:   LD      D,4
KBIT1:  CALL    GZER            ; Generowanie zera
        DEC     D
        JR      NZ,KBIT1
        POP     BC
        POP     DE              ; Odtw. BC,DE
        RET

; -----------------------------------------------------------------------
; GZER - generowanie zera
; Na wyjsciu magnetofonowym wymuszony zostanie
; stan 0 trwajacy 20 probek.
; ZMIENIA: AF,B                 STOS: 1
; -----------------------------------------------------------------------
GZER:   LD      B,ILPR          ; Ilosc probek
        CALL    RESMAG          ; Zerowanie wyjscia
GZE1:   CALL    DEL02           ; Opoznienie
        DJNZ    GZE1
        RET

; -----------------------------------------------------------------------
; GJED - generowanie jedynki
; Na wyjsciu magnet. wymuszony zostaje stan 1
; trwajacy 16 probek i stan 0 trwajacy 4 probki.
; Razem: 20 probek
; -----------------------------------------------------------------------
GJED:   LD      B,ILPR-4
GJED1:  LD      A,10H           ; Bit B4 - magnet.(MIK94)
        LD      (KLAW),A
        OUT     (PA),A          ; Dla plytki MIK94
        LD      A,9
        OUT     (CONTR),A       ; Dla plytki MIK90
        CALL    GZE1
        CALL    RESMAG          ; Zerow. wyjscia magnet.
        LD      B,4
        JR      GZE1            ; 4 probki = 0

; -----------------------------------------------------------------------
; GJEDD - generowanie podwojnej jedynki
; na wyjsciu magnet. wymuszony zostanie stan 1
; trwajacy 2*ILPR-4=36 probek i stan 0 trwajacy
; 4 probki.
; ZMIENIA: AF,B                 STOS: 2
; -----------------------------------------------------------------------
GJEDD:  LD      B,2*ILPR-4
        JR      GJED1

; -----------------------------------------------------------------------
; DEL02 - realizacja opoznienia (odleglosc miedzy probkami)
; Czas opoznienia zalezy od komorki MAGSP ustawia-
; nej zleceniem *7.
; -----------------------------------------------------------------------
DEL02:  LD      A,(MAGSP)
DE1:    DEC     A
        JR      NZ,DE1
        RET

; RESMAG - zerowanie wyjscia na magnetofon
RESMAG:
        XOR     A               ; A=0
        LD      (KLAW),A        ; Plytka MIK94
        OUT     (PA),A          ; MIK94
        LD      A,8
        OUT     (CONTR),A       ; Plytka MIK90
        RET

; -----------------------------------------------------------------------
; M6 - odczyt z magnetofonu
; *[NAZWA][CR] - odczyt programu o nazwie [NAZWA]
; -----------------------------------------------------------------------
M6:     DEC     C               ; 1 Parametr
        CALL    EXPR            ; Pobranie nazwy
        DB      20H
        POP     BC
        LD      B,C             ; B - nazwa deklarowana

; -----------------------------------------------------------------------
; OMAG - procedura systemowa
; Odczyt programu o nazwie deklarowanej w rej. B.
; WEJ: B - nazwa deklarowana
; -----------------------------------------------------------------------
OMAG:
        PUSH    BC              ; STOS - nazwa deklarowana
        ; Poszukiwanie wyroznika "MARK"
RED1:   LD      HL,MARK
RED0:   CALL    RBYT            ; Rej. A - odczyt. bajt
REX:    CP      L               ; Porown. mlodszych bajt.
        JR      NZ,RED0
        CALL    RBYT            ; Pobierz nast. bajt
        CP      H               ; Porow. starsz. bajtow
        JR      NZ,REX
        ; Znaleziono wyroznik "MARK"
        ; Odczyt. parametrow: NAZWA,DLUG,ADRES,-SUMN
        LD      D,0             ; Zerowanie sumy kontrol.
        CALL    RBYT            ; Odczyt. nazwy
        LD      E,A             ; E - nazwa z magnetofonu
        RST     LBYTE           ; Wyswietl. nazwy
        DB      25H
        CALL    RBYT            ; Dlug. bloku danych
        LD      B,A             ; B - dlug
        CALL    RBYT
        LD      L,A             ; Mlodsz. bajt adresu
        CALL    RBYT
        LD      H,A             ; Starsz. bajt adresu
        RST     LADR            ; Wysw. adresu
        DB      40H
        CALL    RBYT            ; -SUMN
        JR      NZ,ERRO         ; Blad SUMN (CY=0)
        POP     AF
        PUSH    AF              ; A - nazwa deklarowana
        CP      E               ; Porownanie nazw
        JR      NZ,RED1         ; Nazwy rozne
        ; Odczyt naglowka bezbledny.  rej.D=0
        ; Sprawdzenie czy rekord EOF
        LD      A,B             ; DLUG
        OR      A               ; Czy DLUG=0 ?
        JR      Z,REOF          ; DLUG=0 - rekord EOF
        ; Wyswietlenie symbolu odczytywania "="
        LD      A,ROWN          ; Znak "="
        LD      (BWYS+4),A      ; Wyswietlenie "="
        ; Rekord z blokiem danych.
        ; Odczytanie bloku danych.
RED2:
        CALL    RBYT            ; Pobierz dana
        LD      (HL),A          ; Wpisanie do pamieci
        INC     HL
        DJNZ    RED2
        ; Koniec odczytywania bloku danych.
        ; Sprawdzenie sumy kontrolnej bloku danych.
        CALL    RBYT            ; Pobranie -SUMD
        ; Kasowanie symbolu odczytywania "="
        LD      A,ZGAS
        LD      (BWYS+4),A      ; Wygaszenie symbolu
        SCF                     ; CY=1 - blad SUMD
        JR      NZ,ERRO         ; Blad SUMD (CY=1)
        ; Blok danych odczytany w sposob bezbledny.
        JR      RED1            ; Czytaj nast. rekord

; Obsluga rekordu EOF
REOF:
ERRO:   POP     BC              ; B - nazwa deklarowana
        JP      NZ,ERRMAG       ; Proc. obslug. bledu
        ; GSTAT=0 - wywolanie z programu MONITORA.
        ; GSTAT#0 - wywolanie z programu uzytkownika.
        LD      A,(GSTAT)
        OR      A
        JR      NZ,MONJES       ; Program MONITORA
        ; Wywolanie z programu uzytkownika
        RST     CLR             ; Wygaszenie wyswietlacza
        DB      80H
        JP      (HL)            ; Skok do prog. uzytkow.
        ; Obsluga wywolania z progr. monitora
        ; Wpisanie odczyt. z magnet. adresu wejscia
        ; do licznika rozkazow uzytkownika.
MONJES:
        LD      (PLOC-1),HL     ; adr. PC - uzytkow.
        RET                     ; Powr. do progr. monitora

; -----------------------------------------------------------------------
; RBYT - procedura pomocnicza
; Odczytanie jednego bajtu z magnetofonu.
; Obliczanie sumy kontrolnej w rej. D.
; WEJ: -
; WYJ: A - odczytany bajt
;      D - aktualny stan sumy kontrolnej.
;      D:=D+ODCZYTANY BAJT  (modulo256)
; ZMIENIA: AF,D,C               STOS: 6
; -----------------------------------------------------------------------
RBYT:   PUSH    HL
        PUSH    DE
        PUSH    BC              ; Ochrona BC,DE,HL
RBTX:   CALL    BSTAR
        JR      RBTX
        ; BSTAR - oczekiwanie na 2 bity stopu
BSTAR:  LD      C,HIG2+4
BST1:   DEC     C
        JR      Z,RBY           ; Rozpoznano stop bit
        CALL    DEL02           ; Opoznienie
        IN      A,(PA)
        AND     80H             ; Wyizolow. bitu B7
        JR      Z,BST1          ; Odliczanie
        RET                     ; Nie stop bit
        ; RBY - odczytanie jednego bajtu
RBY:    LD      L,80H
        LD      E,0
        CALL    LICZ            ; Oczek. na start bit
        INC     E               ; E#0
        CALL    LICZ            ; Pobranie jedynki
        CP      HIG1
        RET     NC
        CP      LOW1
        RET     C
        ; LOW1=< A < HIG1 - rozpoznano start bit
        DEC     E               ; E=0
RB1:    CALL    LICZ            ; Pobranie probek
        CP      HIG1
        JR      NC,RB2          ; A>=HIG1
        CP      LOW1
        RET     C
        ; LOW1=< A <HIG1 - pojedyncze zero (1*0) lub
        ;                  pojedyncza jedynka (1*1)
        LD      A,E
        CPL
        LD      E,A
        CALL    LICZ            ; Pobranie probek
        CP      HIG1
        RET     NC
        CP      LOW1
        RET     C
        ; LOW1=< A < HIG1 - pojedyncza jedynka (1*1) lub
        ;                   pojedyncze zero (1*0)
        ; 1*0 i 1*1 to odczytany bit = 1
        ; 1*1 i 1*0 to odczytany bit = 0
RB3:    LD      A,E
        RRA                     ; Ustawienie CY
        LD      A,L
        RRA
        LD      L,A             ; Zapam. pobr. bitu
        JR      C,KBYT          ; Pobr. wszystkie bity
        LD      A,E
        CPL
        LD      E,A
        JR      RB1

RB2:    CP      HIG2
        RET     NC
        CP      LOW2
        RET     C
        ; LOW2=< A <HIG2 - podwojne zero (2*0) lub
        ;                  podwojna jedynka (2*1).
        ; 2*0 to odczytany bit =0
        ; 2*1 to odczytany bit =1
        JR      RB3

        ; Koniec procesu odczytywania pojedynczego bajtu
KBYT:
        POP     HL              ; Kasow. powr. do BSTAR
        POP     BC
        POP     DE
        POP     HL              ; Odtworzenie BC,DE,HL
        ; Obliczanie sumy kontrolnej
        LD      C,A             ; Ochrona odczyt. bajtu
        ADD     A,D             ; modulo256
        LD      D,A             ; D - suma kontrolna
        OR      A               ; CY=0
        LD      A,C             ; Odtw. odczyt. bajtu
        RET

; -----------------------------------------------------------------------
; LICZ - procedura pomocnicza.
; Zbieranie probek dopoty, dopoki nie napotkane
; zostana 3 kolejne probki przeciwne.
; WEJ: E#0 - zliczanie jedynek
;      E=0 - zliczanie zer
;      C -   ilosc probek juz zliczonych
; WYJ: A - probki pobrane
;      C - probki przeciwne
; ZMIENIA: AF,C,D               STOS: 1
; -----------------------------------------------------------------------
LICZ:   LD      B,0
LICZ1:  CALL    DEL02           ; Opoznienie
        INC     C               ; Licznik probek
        LD      A,E
        OR      A
        IN      A,(PA)
LIX:    JR      Z,LI0           ; Probki 0
        CPL                     ; Probki 1
LI0:    AND     80H             ; Wyizolowanie bit7
        JR      Z,LICZ1
        LD      D,3             ; Max. 3 probki przeciwne
LI1:    INC     B               ; Licznik probek przeciw.
        DEC     D
        LD      A,C             ; A - probki pobrane
        LD      C,B             ; C - probki przeciwne
        RET     Z               ; Wroc gdy D=0
        LD      C,A
        CALL    DEL02
        LD      A,E
        OR      A
        IN      A,(PA)
LI2:    JR      Z,LI2X
        CPL                     ; Probki 1
LI2X:   AND     80H
        JR      NZ,LI1          ; Weryfikacja przeklamania
        INC     C
        JR      LICZ

        .DEPHASE

; -----------------------------------------------------------------------
        .PHASE  0FF8DH
; (duplicate labels removed - the TRAM block above contains the
;  initialization image that gets copied into FF8D..FFD1 at startup)
        .DEPHASE

        END     CA80
