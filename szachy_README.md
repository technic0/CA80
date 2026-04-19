# Szachy CA80 — Analiza programu #9 z C930 MONITOR

**Autor**: Robert Repucha
**Platforma**: Mikrokomputer CA80 (Z80 @ 4MHz)
**Rozmiar**: 7969 bajtow (0x1F21), ladowany do RAM C000-DF20
**Wymagania**: 8KB RAM (uklad 6264 w U12)

## Uruchomienie

```
python ca80.py --c800 C930.BIN --ram 8
```
Nastepnie: `G` `8` `0` `0` `2` `=` (uruchomienie C930 MONITOR), potem klawisz `9` (program Szachy).

## Obsluga gry

Po uruchomieniu programu wyswietla sie animacja powitalna (credits autora).
Nacisniecie dowolnego klawisza uruchamia gre.

**Wybor strony:**
- Klawisz `8` = gracz gra bialymi (wyswietla "H" = Human)
- Klawisz `9` = gracz gra czarnymi (wyswietla "G" = Gracz komputerowy)

**Wprowadzanie ruchu:**
Ruch podaje sie jako 4 cyfry szesnastkowe: 2 cyfry pola zrodlowego + 2 cyfry pola docelowego.
Pola sa indeksami w 78-elementowej tablicy planszy (patrz: Mapa planszy).

**Wyswietlacz LED:**
- Cyfry 0 (FFFE) i 4 (FFFA): wskazniki figur ("H" lub "G" + typ)
- Cyfry srodkowe: aktualna pozycja / ruch komputera
- Symbol "=" (0x48): separator

## Architektura programu

### Reprezentacja planszy — Mailbox 10-kolumnowy

Plansza szachowa jest przechowywana jako tablica 78 elementow (0x4E bajtow)
w formacie "mailbox" o szerokosci 10 kolumn:

```
Indeks  h    g    f    e    d    c    b    a   [sentinel x2]
 0- 9:  wR   wN   wB   wK   wQ   wB   wN   wR   --   --    Rz.1
10-19:  wP   wP   wP   wP   wP   wP   wP   wP   --   --    Rz.2
20-29:  ..   ..   ..   ..   ..   ..   ..   ..   --   --    Rz.3
30-39:  ..   ..   ..   ..   ..   ..   ..   ..   --   --    Rz.4
40-49:  ..   ..   ..   ..   ..   ..   ..   ..   --   --    Rz.5
50-59:  ..   ..   ..   ..   ..   ..   ..   ..   --   --    Rz.6
60-69:  bP   bP   bP   bP   bP   bP   bP   bP   --   --    Rz.7
70-77:  bR   bN   bB   bQ   bK   bB   bN   bR               Rz.8
```

Kolumny numerowane h->a (indeks 0 = kolumna h, indeks 7 = kolumna a).
Pozycje 8-9 kazdego rzedu (oprocz ostatniego) to wartownicy (sentinel=0x80),
ktore upraszczaja wykrywanie wyjscia poza plansze.

**Kierunki ruchu na planszy 10-kolumnowej:**
| Kierunek | Offset | Uzycie |
|----------|--------|--------|
| Polnoc/Poludnie | +/-10 | Wieza, Hetman, Pionek |
| Wschod/Zachod | +/-1 | Wieza, Hetman |
| Diagonale | +/-9, +/-11 | Goniec, Hetman, Pionek (bicie) |
| Skok skoczka | +/-8, +/-12, +/-19, +/-21 | Skoczek (ruch "L") |

### Kodowanie figur

| Kod | Figura | Procedura (biale) | Procedura (czarne) |
|-----|--------|-------------------|-------------------|
| 0x02 / 0xFE | Pionek (Pawn) | C856 | CBE8 |
| 0x06 / 0xFA | Skoczek (Knight) | C3F0 | CB40 |
| 0x07 / 0xF9 | Goniec (Bishop) | C780 | CAA0 |
| 0x0A / 0xF6 | Wieza (Rook) | C6C0 | CA00 |
| 0x14 / 0xE2 | Hetman (Queen) | C550 | CB90 |
| 0x7F / 0xEE | Krol (King) | C436 | C8A8 |
| 0x80 | Puste pole | — | — |
| 0x00 | Wartownik (border) | — | — |

Figury biale maja kody < 0x80, czarne > 0x80.
Dla wiekszosci figur: kod_czarny = 256 - kod_bialy (negacja w U2).

### Mapa pamieci RAM

```
D000-D003  Zmienne stanu gry (D001-D002 = najlepszy ruch, D003 = alpha)
D008-D009  Indeksy pol: zrodlowe i docelowe biezacego ruchu
D00A-D00B  Wartosc beta dla przeszukiwania alfa-beta
D015       Iterator pozycji na planszy (skanowanie figur)
D018       Offset kierunku dla generatora ruchow
D020       Pozycja skanowania planszy (walidacja)
D023       Iterator ewaluacji
D026-D027  Akumulator oceny pozycji
D028-D02A  Wspolrzedne ruchu gracza
D02C       Kod pola zrodlowego (wpisany przez gracza)
D02E       Kod pola docelowego (wpisany przez gracza)
D035-D036  Akumulator wyniku pozycyjnego
D040       Figura biezona/bita
D05E       Flaga stanu gry (0x0C = szach-mat/koniec)
D060-D0AF  Szablon poczatkowej planszy (78 bajtow, stala)
D0B0-D0FE  Biezacy stan planszy (kopia robocza)
D100-D14E  Kopia planszy 1 (do testowania ruchow AI)
D150-D19E  Kopia planszy 2 (do cofania ruchow)
D1A0-D1EF  Tablica typow/mobilnosci figur (do ewaluacji)
D250-D29F  Tablica wartosci pozycyjnych bialych (piece-square table)
D300-D34F  Tablica mapowania plansza->wspolrzedne
D350-D39F  Tablica wartosci pozycyjnych czarnych
```

### Glowna petla programu

```
C000: Inicjalizacja stosu (SP=FF66)
C003: CALL DCF0 — animacja powitalna + wybor opcji
C006-C022: Kopiowanie szablonu planszy do 3 buforow (LDIR)
C023: CALL C1D6 — czyszczenie zmiennych gry
C026-C041: Wyswietlenie poczatkowego stanu na LED
C044: CALL CC50 — wyswietlenie pozycji
  |
  v
C04B-C050: Sprawdzenie szach-matu (D05E == 0x0C?)
  |   tak -> C073 (ruch komputera / koniec)
  v
C05F-C070: --- TURA GRACZA ---
  CALL C0D0 — odczyt ruchu z klawiatury
  Walidacja ruchu
  |
  v
C073: --- TURA KOMPUTERA ---
  CALL DAF0 — silnik AI oblicza ruch
C078-C08D: Inicjalizacja okna alfa-beta
  alpha = 0x8000 (-32768), beta = 0x7FF0 (+32752)
C08E-C0BD: Petla po wszystkich 78 polach planszy:
  - Wczytaj figure z D0B0[i]
  - Porownaj z kodem kazdego typu figury
  - CALL Z do odpowiedniej procedury generowania ruchow
C0C0: CALL C300 — wykonaj najlepszy ruch, wyswietl
C0C3: CALL CF1D — sprawdz koniec gry
C0C8: Jezeli koniec -> restart (JP C000)
C0CB: W przeciwnym razie -> C05F (tura gracza)
```

### Silnik AI — przeszukiwanie alfa-beta

Program implementuje algorytm **alfa-beta pruning** (przycinanie):

1. **Generowanie ruchow** (C08E-C0BD): Iteracja po calej planszy, dla kazdej figury
   komputera wywolanie odpowiedniego generatora ruchow.

2. **Generatory ruchow** — kazda figura ma dedykowana procedure:
   - **Skoczek** (C3F0): 8 skokow "L", kazdy testowany raz
   - **Krol** (C436): 8 kierunkow, 1 pole w kazdym
   - **Hetman** (C550): 8 kierunkow, slizganie do przeszkody
   - **Wieza** (C6C0): 4 kierunki (pion/poziom), slizganie
   - **Goniec** (C780): 4 diagonale, slizganie
   - **Pionek** (C856): ruch do przodu (+10, podwojny +20), bicia (+9, +11)

3. **Walidacja ruchu** (C3C0): Sprawdza czy pole docelowe:
   - Jest w granicach planszy (< 0x4E)
   - Jest puste (0x80) lub zajete przez przeciwnika
   - Nie jest figur wlasna lub wartownikiem

4. **Ewaluacja pozycji** (C20E-C2D8): Sumuje wartosci pozycyjne figur
   z tablic piece-square (D250 dla bialych, D350 dla czarnych).
   Centralne pola maja wyzsze wartosci — zacheca do kontroli centrum.

5. **Przycinanie** (C4DF-C4F6): Porownanie biezacej oceny z granicami
   alfa-beta. Jezeli znaleziony ruch lepszy od beta — odciecie.

### Tablice wartosci pozycyjnych (Piece-Square Tables)

Tablica dla bialych (D250), czytana rzedami planszy:
```
Rz.1: 01 01 03 04 04 03 01 01   (narozniki=1, centrum=4)
Rz.2: 03 03 04 05 05 04 03 03
Rz.3: 05 06 06 07 07 06 06 05   (rosnie ku srodkowi)
Rz.4: 06 06 08 0C 0C 08 06 06
Rz.5: 08 0C 0F 10 10 0F 0C 08   (srodek planszy = 16!)
Rz.6: 0A 0E 12 14 14 12 0E 0A
Rz.7: 0C 10 22 24 24 12 10 0C   (bonus za zblizone do promocji)
```
To klasyczna technika programowania szachowego — figury na centralnych
polach sa wyceniane wyzej, co zacheca AI do kontrolowania centrum.

### Procedury wyswietlacza

| Adres | Opis |
|-------|------|
| CC50 | Wyswietlenie biezacej pozycji na LED |
| CC80 | Zarejestrowanie prawidlowego ruchu |
| CC30 | Porownanie oceny pozycji z granicami alfa-beta |
| CF1D | Sprawdzenie zakonczenia gry (mat, pat) |
| CF56 | Przygotowanie wyswietlacza |
| CF9D | Walidacja ruchu gracza |
| C300 | Wyswietlenie ruchu komputera na LED |

### Symbole na wyswietlaczu 7-segmentowym

| Wzorzec | Wyglad | Znaczenie |
|---------|--------|-----------|
| 0x3D | G | Gracz komputerowy / strona komputera |
| 0x76 | H | Human / strona gracza ludzkiego |
| 0x63 | ° | Wskaznik figury (gorny kwadrat) |
| 0x48 | = | Separator pol na wyswietlaczu |
| 0x82 | " | Wskaznik szacha / bicia |
| 0x80 | . | Puste pole / kropka dziesietna |

### Obsluga zapisu na tasme magnetofonowej

Program zawiera procedury zapisu i odczytu stanu gry na tasme:
- D990: Wyswietla "COP4" (operacja kopiowania)
- D9BF: Wyswietla "AEAd4" (odczyt/zapis)
- CALL 0626: Zapis na tasme (procedura ROM CA80)
- CALL 067B: Odczyt z tasmy (procedura ROM CA80)

### Animacja powitalna (DCF0)

Procedura wyswietla przewijajacy sie tekst z informacjami o autorze
(Robert Repucha) na 8-cyfrowym wyswietlaczu LED, korzystajac z niestandardowych
wzorow segmentowych do tworzenia efektu animacji. Wymaga nacisniecia
dowolnego klawisza, aby uruchomic gre (klawisz '0' = pomin intro).

## Podsumowanie techniczne

Program "Szachy" Roberta Repuchy to imponujace osiagniecie programistyczne
na platforme z 8-cyfrowym wyswietlaczem LED i klawiatura heksadecymalna.
Na niespelna 8KB kodu maszynowego Z80 miesci sie:

- Pelna reprezentacja planszy szachowej (mailbox 10-kolumnowy)
- Generatory ruchow dla wszystkich 6 typow figur (z osobnymi procedurami
  dla bialych i czarnych)
- Silnik AI oparty na przeszukiwaniu alfa-beta z ewaluacja pozycyjna
- Tablice wartosci pozycyjnych (piece-square tables) zachecajace do
  kontroli centrum
- System wprowadzania ruchow przez klawiature heksadecymalna
- Obsluga zapisu/odczytu stanu gry na tasme magnetofonowej
- Animacja powitalna z creditami autora

Jest to kompletny program szachowy dzialajacy w ekstremalnie ograniczonym
srodowisku sprzetowym — bez monitora graficznego, bez pelnej klawiatury,
z zaledwie 8KB RAM.

## Pliki

| Plik | Opis |
|------|------|
| szachy.bin | Wyekstrahowany binarny kod gry (7969 B) |
| szachy_disasm.asm | Surowy listing disasemblacji Z80 |
| szachy_annotated.asm | Okomentowana disasemblacja z analiza |
| szachy_README.md | Ten plik |
