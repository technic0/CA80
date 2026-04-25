# -*- coding: utf-8 -*-
"""
ca80_ports.py
Obsługa portów I/O dla emulatora CA80 (rdzeń Z80_core.py).

8255 PPI (U7) — adresy F0-F3:
  F0 = Port A (PA) — wejście: bity PA4-PA6 = rzędy klawiatury (0=wciśnięty)
  F1 = Port B (PB) — wyjście: segmenty LED (bit0=a ... bit6=g, bit7=DP)
  F2 = Port C (PC) — wyjście: PC0-3=kolumny klawiatury, PC5-7=wybór cyfry
  F3 = CTRL       — słowo sterujące; init monitor zapisuje 0x90

Klawiatura (matryca 4 kolumny × 6 rzędów MIK90):
  Aby wykryć klawisz, monitor wystawia LOW na wybranej kolumnie portu PC
  (bits PC0-PC3; 0 = aktywna), następnie czyta PA (bits PA1-PA6; 0 = klawisz).

  Wystawienie LOW na kolumnę może nastąpić na dwa sposoby:
   1. Procedura CSTS — używa BSR (bit-set/reset) przez port CTRL (F3).
   2. Procedura NMI M-key check — pisze cały bajt bezpośrednio do PC (F2).

  Oba mechanizmy manipulują TEN SAM stan portu PC. Emulator musi więc
  określać aktywną kolumnę na podstawie aktualnego stanu ppi.pc — nie
  na podstawie tego, KTÓRY zapis nastąpił jako ostatni.

Dźwięk — port 0xEC (SYGNAL w monitorze):
  Każdy zapis do portu 0xEC (dowolna wartość) jest dekodowany przez 74LS138
  jako strob wyzwalający monostabilny U15/74123, który generuje pojedynczy
  impuls na głośniku. Monitor wykonuje ten OUT w procedurze NMI (co 2 ms)
  gdy licznik SYG (FFE9) > 0 — daje to ton 500 Hz przez czas SYG × 2 ms.
  Szczegóły w ca80_sound.py.

CTC Z80 (F8-FB):
  Mimo że Z80 CTC jest obecny na płycie CA80, monitor używa go WYŁĄCZNIE
  do pracy krokowej (debugger: CTC wystawia przerwanie po jednej instrukcji
  i zwraca do monitora). Nie ma żadnego powiązania z generowaniem dźwięku.
  Emulator traktuje te porty jako no-op — ignoruje zapisy i zwraca 0xFF
  na odczyt. Jeśli kiedyś będziesz chciał implementować pracę krokową,
  to tutaj trzeba będzie dodać pełną emulację CTC.

Emulator 8255 (MIK94 — E8-EB):
  W konfiguracji MIK90-only (nasza) ten układ nie jest zamontowany.
  Zapisy ignorujemy, odczyty zwracają 0xFF (bus floating).
"""
import sys
import traceback

ca80 = None    # referencja do instancji CA80
_audio = None  # referencja na ca80_sound.AudioSystem (lub None)


def init_ports(emulator_instance, audio_system=None):
    """
    Inicjalizuje moduł portów.

    Parametry:
      emulator_instance — instancja klasy CA80 z polami ppi1, pressed_keys,
                          active_digit, led_segments
      audio_system      — instancja ca80_sound.AudioSystem lub None
                          (gdy None, zapisy do 0xEC nie generują dźwięku)
    """
    global ca80, _audio
    ca80 = emulator_instance
    _audio = audio_system


# ---------------------------------------------------------------------------
# Matryca klawiatury CA80 MIK90 — 4 kolumny (PC3..PC0) × 6 wierszy (PA6..PA1)
#
# KEY_MATRIX[(col_bit, pa_row_bit)] = znak
#   col_bit     = indeks bitu portu PC który jest 0 (aktywna kolumna, 0..3)
#   pa_row_bit  = indeks bitu portu PA który odczytuje się jako 0 (1..6)
#
# Pełna matryca 24 klawiszy zweryfikowana z:
#   1. Procedury CSTSM @ 0130 monitora MIK290
#   2. Tablicy TKLAW @ 0300 monitora MIK290
#   3. Dokumentacji R23 (Tabela programowania portu 8255 w trybie 0)
#
# Dekodowanie: każdy klawisz aktywuje DOKŁADNIE JEDEN bit PA w DOKŁADNIE
# JEDNEJ kolumnie PC. Sprzętowy kod rzeczywisty klawisza ma postać:
#     bit 7,6 = numer kolumny L (3..0)
#     bit 5..0 = wiersze (PA6..PA1, 0=wciśnięty w aktywnej kolumnie)
#
# Kompletna matryca (zgodna z fizycznym układem na maskownicy CA80):
#         L=3 (PC3=0)  L=2 (PC2=0)  L=1 (PC1=0)  L=0 (PC0=0)
#   PA1:    =/CR         ./SPAC       G            M
#   PA2:    2            6            A            E
#   PA3:    0            4            8            C
#   PA4:    F4           F3           F2           F1   ← uwaga: F1 po prawej!
#   PA5:    1            5            9            D
#   PA6:    3            7            B            F
#
# WAŻNE: F1-F4 są ułożone w kolejności ODWROTNEJ względem hex/akcji!
# To wynika z układu fizycznego — F-klawisze są na maskownicy w lewej
# kolumnie, ale ich kody rzeczywiste odpowiadają KOLUMNOM ELEKTRYCZNYM
# liczonym od L=0 (prawa) do L=3 (lewa). Stąd:
#   F1 (lewa-góra na maskownicy) → kod tablicowy 0x17, kolumna L=0
#   F4 (lewa-dół na maskownicy)  → kod tablicowy 0x14, kolumna L=3
#
# Klawisze F1-F4 to (cytując MIK09): "odpowiedniki Z,Y,X,W w starym CA80".
# Kolejność Z,Y,X,W = F1,F2,F3,F4 (kody tablicowe 0x17,0x16,0x15,0x14).
#
# Detekcja klawisza M w NMI (osobna procedura @ 00E4-0100): MIK290 używa
# kodu rzeczywistego 0x3E (CP 3EH @ 0334), zgodnego z tablicą TKLAW.
#
# Nazwy klawiszy w tej matrycy:
#   '0'-'9', 'A'-'F'  — 16 klawiszy hex
#   '=' = klawisz CR (Enter, równa się), kod tablicowy 0x12
#   '.' = klawisz SPAC (kropka, spacja),  kod tablicowy 0x11
#   'G' = klawisz G (Go),                 kod tablicowy 0x10
#   'M' = klawisz M (Monitor return),     kod tablicowy 0x13
#   'F1'-'F4' = klawisze funkcyjne,       kody tablicowe 0x17,0x16,0x15,0x14
# ---------------------------------------------------------------------------
KEY_MATRIX = {
    # col L=3 (PC3 = 0)
    (3, 1): '=',  (3, 2): '2',  (3, 3): '0',
    (3, 4): 'F4', (3, 5): '1',  (3, 6): '3',
    # col L=2 (PC2 = 0)
    (2, 1): '.',  (2, 2): '6',  (2, 3): '4',
    (2, 4): 'F3', (2, 5): '5',  (2, 6): '7',
    # col L=1 (PC1 = 0)
    (1, 1): 'G',  (1, 2): 'A',  (1, 3): '8',
    (1, 4): 'F2', (1, 5): '9',  (1, 6): 'B',
    # col L=0 (PC0 = 0)
    (0, 1): 'M',  (0, 2): 'E',  (0, 3): 'C',
    (0, 4): 'F1', (0, 5): 'D',  (0, 6): 'F',
}
# Odwrotna mapa: nazwa klawisza → (col_bit, pa_row_bit)
CHAR_TO_POS = {v: k for k, v in KEY_MATRIX.items()}


def _pa_state() -> int:
    """
    Zwraca stan portu PA na podstawie:
      - aktualnego stanu portu PC (ca80.ppi1.pc bits 3-0 = maska kolumn)
      - wciśniętych klawiszy (ca80.pressed_keys)

    Aktywne kolumny to te bits 3-0 portu PC, które są 0.
    Dla każdej aktywnej kolumny zbierane są wszystkie wciśnięte klawisze
    z tej kolumny i ich bity PA są zerowane w wyniku.
    """
    # PA0=0: brak MikSID → cold start; PA7=0: brak interfejsu magnetofonu
    # (bity PA1-PA6 to wiersze klawiatury, HIGH = nie wciśnięty)
    result = 0x7E  # 0111_1110: PA7=0, PA6..PA1=1 (nic nie wciśnięte), PA0=0

    if ca80 is None:
        return result

    pc = ca80.ppi1.pc & 0x0F  # tylko bits 3-0 (maska kolumn)

    # Dla każdego klawisza: aktywny jeśli jego kolumna ma bit PC = 0
    for ch in ca80.pressed_keys:
        pos = CHAR_TO_POS.get(ch)
        if pos is None:
            continue
        col, pa_bit = pos
        # Klawisz widoczny tylko jeśli jego kolumna jest aktywna (bit PC = 0)
        if not (pc & (1 << col)):
            result &= ~(1 << pa_bit) & 0xFF

    return result


# ---------------------------------------------------------------------------
# Odczyt portu
# ---------------------------------------------------------------------------
def port_in(port: int) -> int:
    p = port & 0xFF
    value = 0xFF
    try:
        if 0xF0 <= p <= 0xF3:
            # 8255 PPI systemowe (U7)
            idx = p & 3
            if idx == 0:
                value = _pa_state()          # PA — wejście rzędów klawiatury
            elif ca80 is not None:
                ppi = ca80.ppi1
                if idx == 1:
                    value = ppi.pb           # PB — zatrzask segmentów
                elif idx == 2:
                    value = ppi.pc           # PC — stan kolumn / wybór cyfry
                elif idx == 3:
                    value = ppi.ctrl

        elif 0xE8 <= p <= 0xEB:
            # 8255 emulatora (MIK94) — nieobecne w konfiguracji MIK90
            value = 0xFF

        elif p == 0xEC:
            # SYGNAL (generator dźwięku 74123) — tylko strob, brak rejestru
            value = 0xFF

        elif 0xF8 <= p <= 0xFB:
            # Z80 CTC (debugger krokowy) — brak implementacji odczytu
            value = 0xFF

    except Exception as e:
        print(f"[ERROR ports] port_in({port:#04x}): {e}", file=sys.stderr)
    return value


# ---------------------------------------------------------------------------
# Zapis do portu
# ---------------------------------------------------------------------------
def port_out(port: int, value: int):
    if ca80 is None:
        return
    p = port & 0xFF
    val = value & 0xFF
    try:
        if 0xF0 <= p <= 0xF3:
            # 8255 PPI systemowe (U7)
            idx = p & 3
            ppi = ca80.ppi1

            if idx == 3:
                if val & 0x80:
                    # Mode control word — zapis trybu pracy
                    ppi.ctrl = val
                else:
                    # BSR mode — Bit Set/Reset Port C
                    # bit 0 = 1: set, bit 0 = 0: reset
                    # bits 3..1 = numer bitu (0-7)
                    bit_num = (val >> 1) & 0x07
                    if val & 0x01:
                        ppi.pc |= (1 << bit_num)
                    else:
                        ppi.pc &= ~(1 << bit_num) & 0xFF
                    # NMI multiplekser wyświetlacza zmienia bity PC7-PC5
                    # poprzez zapis DIRECT do PC (idx==2), ale BSR może
                    # modyfikować zarówno bits 0-3 (kolumny) jak i 5-7.
                    # Nic dodatkowego tu nie trzeba — stan ppi.pc jest
                    # jedynym źródłem prawdy dla _pa_state().
                return

            if idx == 0:                     # PA — w trybie output (niestandardowe)
                ppi.pa = val

            elif idx == 1:                   # PB — segmenty LED
                ppi.pb = val
                if 0 <= ca80.active_digit < 8:
                    ca80.led_segments[ca80.active_digit] = val

            elif idx == 2:                   # PC — bezpośredni zapis całego portu
                # Używane przez NMI do wyboru cyfry (bits 7-5) i kolumny (bit 0)
                # przy sprawdzaniu klawisza M. Musi aktualizować pełny stan PC.
                ppi.pc = val
                # Bity PC7-PC5 → wybór cyfry przez dekoder 74145
                # (0=cyfra 0 = skrajnie prawa)
                digit = (val >> 5) & 0x07
                ca80.active_digit = digit

        elif p == 0xEC:
            # SYGNAL: każdy zapis (dowolna wartość) = strob /CTF8 = wyzwolenie
            # monostabilnego 74123 = jeden dodatni impuls na głośniku.
            # Źródło: monitor CA80 V3.0, linia 234: OUT (SYGNAL),A w NMI.
            #
            # Przekazujemy frame_tstates (T-stany Z80 od początku ramki),
            # żeby wiele OUT(EC) w jednej ramce emulatora zostało rozłożonych
            # na osi czasu audio — inaczej wszystkie wylądują w tej samej
            # pozycji bufora i zamiast tonu usłyszymy "pierdzenie".
            if _audio is not None:
                frame_tstates = getattr(ca80, 'frame_tstates', 0)
                _audio.trigger_sygnal(frame_tstates)

        elif 0xE8 <= p <= 0xEB:
            # 8255 emulatora (MIK94) — nieobecne w konfiguracji MIK90
            pass

        elif 0xF8 <= p <= 0xFB:
            # Z80 CTC (debugger krokowy) — brak implementacji
            pass

    except Exception as e:
        print(f"[ERROR ports] port_out({port:#04x}, {value:#04x}): {e}", file=sys.stderr)
        traceback.print_exc()
