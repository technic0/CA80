# -*- coding: utf-8 -*-
"""
ca80.py
Główny plik emulatora CA‑80 w Pythonie. Wersja z UI (blessed) + audio.

Konfiguracja sprzętowa (rozbudowana MIK290, wg dokumentacji MIK09 rozdz. 3.0):
  U9  @ 0x0000-0x3FFF — ROM 16 KB (monitor systemowy, CA80.BIN)
  U10 @ 0x4000-0x7FFF — ROM 16 KB (pakiet C800, C800.BIN)
  U11 @ 0x8000-0xBFFF — ROM 16 KB (pakiet transmisyjny, C930.BIN)
  U12 @ 0xC000-0xFFFF — RAM 16 KB (62256 lub 6264)

Używa rdzenia Z80 z pliku Z80_core.py oraz modułów ca80_memory.py,
ca80_ports.py i ca80_sound.py.

Wymagania:
  Python 3.11 (zalecany)
  pip install blessed sounddevice numpy
  Pliki Z80_core.py, ca80_memory.py, ca80_ports.py, ca80_sound.py,
  CA80.BIN, C930.BIN, C800.BIN w tym samym katalogu.

Uruchomienie:
  python ca80.py [--step] [--anode] [--no-audio]
                 [--monitor PLIK] [--c930 PLIK] [--c800 PLIK]

  Wejście do C800 MONITOR:  *80       (sprawdza [0x4001]==0x55, skok do 0x4020)
  Wejście do C930 MONITOR:  *89       (sprawdza [0x8001]==0xAA, skok do 0x8002)
  Bezpośredni skok użytkownika:  *G <adres> =   (np. *G C 0 0 0 = → 0xC000)
"""
from __future__ import annotations
import sys
import pathlib
import time
import argparse
from collections import deque
import traceback
from ca80_sound import AudioSystem

# --- Zależności UI ---
try:
    from blessed import Terminal
except ImportError:
    sys.exit("Błąd: Brak biblioteki 'blessed'. Zainstaluj: pip install blessed")

# --- Import modułów emulatora ---
try:
    # Zmieniono nazwę importu, aby uniknąć konfliktu z klasą Z80Machine z innych bibliotek
    import Z80_core as Z80
    import ca80_memory as memory
    import ca80_ports as ports
except ImportError as e:
    sys.exit(f"Błąd: Brak jednego z modułów: Z80_core.py, ca80_memory.py, ca80_ports.py. Błąd: {e}")


# ----------------------------------------------------------------------------
# Stałe sprzętowe i UI
# ----------------------------------------------------------------------------
CLK_CPU_HZ = 4_000_000

# Segmenty 7‑segment (gfedcba), bit 7 (0x80) to kropka
SEG_MAP = {
    " ": 0x00, "0": 0x3F, "1": 0x06, "2": 0x5B, "3": 0x4F,
    "4": 0x66, "5": 0x6D, "6": 0x7D, "7": 0x07, "8": 0x7F,
    "9": 0x6F, "A": 0x77, "B": 0x7C, "C": 0x39, "D": 0x5E,
    "E": 0x79, "F": 0x71, "G": 0x3D, "H": 0x76, "J": 0x1E,
    "L": 0x38, "P": 0x73,
    "U": 0x3E, "Y": 0x6E,
    "h": 0x74, "i": 0x10,
    "n": 0x54, "o": 0x5C, "r": 0x50, "t": 0x78, "u": 0x1C,
    "-": 0x40, "_": 0x08,
    " .": 0x80, "0.": 0xBF, "1.": 0x86, "2.": 0xDB, "3.": 0xCF,
    "4.": 0xE6, "5.": 0xED, "6.": 0xFD, "7.": 0x87, "8.": 0xFF,
    "9.": 0xEF, "A.": 0xF7, "B.": 0xFC, "C.": 0xB9, "D.": 0xDE,
    "E.": 0xF9, "F.": 0xF1, "G.": 0xBD, "-.": 0xC0, "_.": 0x88,
}
CHAR_MAP = {v: k for k, v in SEG_MAP.items()}

# ----------------------------------------------------------------------------
# Prosta emulacja 8255 (Mode 0) - tylko przechowuje stan
# ----------------------------------------------------------------------------
class PPI8255State:
    def __init__(self):
        self.pa: int = 0x00
        self.pb: int = 0x00
        self.pc: int = 0x00
        self.ctrl: int = 0x9B # Reset state: Mode 0, all ports INPUT

    def is_output(self, port_char: str) -> bool:
        """Sprawdza, czy dany port (A, B, C) jest skonfigurowany jako wyjście w Mode 0."""
        # Sprawdź, czy w ogóle ustawiono tryb (bit 7 = 1)
        if not (self.ctrl & 0x80): return False
        # Sprawdź tryb grupy A (bity 6,5) i B (bit 2) - zakładamy Mode 0
        if ((self.ctrl >> 5) & 0x03) != 0 or ((self.ctrl >> 2) & 0x01) != 0: return False

        if port_char == 'A': return not (self.ctrl & 0x10) # Bit 4 = 0 dla wyjścia
        if port_char == 'B': return not (self.ctrl & 0x02) # Bit 1 = 0 dla wyjścia
        if port_char == 'C':
             output_c_lower = not (self.ctrl & 0x01) # Bit 0 = 0 dla wyjścia
             output_c_upper = not (self.ctrl & 0x08) # Bit 3 = 0 dla wyjścia
             return output_c_lower or output_c_upper
        return False

    def is_c_upper_output(self) -> bool:
        """Sprawdza, czy Port C Górny (bity 7-4) jest wyjściem w Mode 0."""
        if not (self.ctrl & 0x80) or ((self.ctrl >> 5) & 0x03) != 0: return False
        return not (self.ctrl & 0x08) # Bit 3 = 0 dla wyjścia

# ----------------------------------------------------------------------------
# Główna klasa emulatora CA‑80 (kontener stanu i menedżer UI)
# ----------------------------------------------------------------------------
class CA80:
    def __init__(self,
                 monitor_path: str = "CA80.BIN",
                 c930_path: str = "C930.BIN",
                 c800_path: str = "C800.BIN",
                 *,
                 anode: bool = False,
                 step: bool = False,
                 audio_enabled: bool = True):
        # Inicjalizacja pamięci — konfiguracja sprzętowa rozbudowana MIK290.
        # Mapa 16K/16K/4K ROM + 28K RAM; szczegóły w ca80_memory.py.
        # strict=True: brak któregokolwiek pliku = błąd krytyczny.
        memory.init_memory(monitor_path, c930_path, c800_path, strict=True)

        # Jeden PPI 8255 (U7) — ctrl init 0x90: PA=in, PB=out, PC=out
        self.ppi1 = PPI8255State()
        self.ppi1.ctrl = 0x90

        # Stan klawiatury: zbiór wciśniętych znaków
        self.pressed_keys: set[str] = set()

        # Uruchom system audio (port 0xEC → 74123 → głośnik).
        self.audio = AudioSystem(enabled=audio_enabled)

        # Licznik T-stanów Z80 od początku bieżącej ramki emulacji.
        # Aktualizowany w pętli run() po każdym execute_one_step().
        # Używany przez port 0xEC do pozycjonowania triggerów audio.
        self.frame_tstates: int = 0

        ports.init_ports(self, audio_system=self.audio)

        # Stan UI
        self.common_anode = anode
        self.step_mode = step
        self.led_segments = [0x00] * 8
        self.active_digit = 0
        self.term = Terminal()

        # Mapowanie klawiszy PC → znaki CA80
        # '.' = SPAC (parametr/następny adres), '=' = CR (zatwierdź/wykonaj)
        self.KEYMAP_PC = {
            '0': '0', '1': '1', '2': '2', '3': '3', '4': '4',
            '5': '5', '6': '6', '7': '7', '8': '8', '9': '9',
            'a': 'A', 'b': 'B', 'c': 'C', 'd': 'D', 'e': 'E', 'f': 'F',
            'A': 'A', 'B': 'B', 'C': 'C', 'D': 'D', 'E': 'E', 'F': 'F',
            'g': 'G', 'G': 'G',
            'm': 'M', 'M': 'M',
            '.': '.',            # SPAC
            '=': '=',            # CR
            ' ': '.',            # Spacja jako SPAC (alternatywa)
            '\n': '=',           # Enter jako CR (alternatywa)
        }

        Z80.Z80(CLK_CPU_HZ / 1_000_000)
        Z80.reset()
        Z80._SP[0] = 0xFF8D  # SP startowy monitora CA80
        self._quit_requested = False
        self._last_key_repr = ""
        self._key_queue: deque = deque()   # kolejka oczekujących klawiszy CA80
        self._key_hold_frames = 0          # ramki pozostałe w fazie WCIŚNIĘCIA
        self._key_release_frames = 0       # ramki przerwy po zwolnieniu

    # --- Metody UI ---
    def _seg_to_char(self, pattern_raw: int) -> str:
        """Dekodowanie wzorca segmentowego na znak (do wiersza tekstowego)."""
        pattern_segments = (pattern_raw & 0x7F) ^ (0x7F if self.common_anode else 0x00)
        pattern_final = pattern_segments | (pattern_raw & 0x80)
        return CHAR_MAP.get(pattern_final, '?')

    def _draw_ui(self):
        term = self.term
        with term.location(0, 0):
            # Czytaj bufor BWYS: FFF7=cyfra0(prawa), FFFE=cyfra7(lewa)
            segs_raw = [memory.peekb(0xFFFE - i) for i in range(8)]

            # Dekoduj segmenty (obsługa common anode)
            segs = []
            for sr in segs_raw:
                s = ((sr & 0x7F) ^ 0x7F | (sr & 0x80)) if self.common_anode else sr
                segs.append(s)

            # --- Graficzny wyświetlacz 7-segmentowy (3 wiersze) ---
            # Kodowanie bitów: 0=a(góra) 1=b(prawy-góra) 2=c(prawy-dół)
            #   3=d(dół) 4=e(lewy-dół) 5=f(lewy-góra) 6=g(środek) 7=dp(kropka)
            r0 = ''  # wiersz górny:   segment a
            r1 = ''  # wiersz środkowy: segmenty f, g, b
            r2 = ''  # wiersz dolny:    segmenty e, d, c  (+dp)
            for seg in segs:
                a  = seg & 0x01; b  = seg & 0x02; c  = seg & 0x04
                d  = seg & 0x08; e  = seg & 0x10; f  = seg & 0x20
                g  = seg & 0x40; dp = seg & 0x80
                r0 += ' ' + ('_' if a else ' ') + '  '
                r1 += ('|' if f else ' ') + ('_' if g else ' ') + ('|' if b else ' ') + ' '
                r2 += ('|' if e else ' ') + ('_' if d else ' ') + ('|' if c else ' ') + ('.' if dp else ' ')

            # Ramka wyświetlacza
            inner_w = len(r0) + 2  # +2 na marginesy
            border = '─' * inner_w
            print(term.normal + term.move_xy(2, 1) + '╭' + border + '╮' + term.clear_eol, end='')
            print(term.move_xy(2, 2) + '│ ' + term.bold(r0) + ' │' + term.clear_eol, end='')
            print(term.move_xy(2, 3) + '│ ' + term.bold(r1) + ' │' + term.clear_eol, end='')
            print(term.move_xy(2, 4) + '│ ' + term.bold(r2) + ' │' + term.clear_eol, end='')
            print(term.move_xy(2, 5) + '╰' + border + '╯' + term.clear_eol, end='')

            # Wiersz tekstowy (interpretacja znaków, kompaktowa)
            text_str = ''.join(self._seg_to_char(p) for p in segs_raw)
            print(term.move_xy(2, 6) + f'  TXT: [{text_str}]' + term.clear_eol, end='')

            # Rejestry Z80
            try:
                regs_str = f"PC:{Z80._PC[0]:04X} SP:{Z80._SP[0]:04X} AF:{Z80._AF[0]:04X} BC:{Z80._BC[0]:04X} DE:{Z80._DE[0]:04X} HL:{Z80._HL[0]:04X} IX:{Z80._IX[0]:04X} IY:{Z80._IY[0]:04X}"
                print(term.move_xy(2, 8) + regs_str + term.clear_eol, end='')
                flag_str = (("S" if Z80._fS else ".") + ("Z" if Z80._fZ else ".") +
                            ("5" if Z80._f5 else ".") + ("H" if Z80._fH else ".") +
                            ("3" if Z80._f3 else ".") + ("P" if Z80._fPV else ".") +
                            ("N" if Z80._fN else ".") + ("C" if Z80._fC else "."))
                state_str = f"I:{Z80._I[0]:02X} R:{Z80._R:02X} IM:{Z80._IM} IFF1:{int(Z80._IFF1)}"
                print(term.move_xy(2, 9) + f"F:'{flag_str}' {state_str}" + term.clear_eol, end='')
                print(term.move_xy(2, 10) + term.clear_eol, end='')
            except Exception as e:
                 print(term.move_xy(2, 8) + f"Błąd odczytu rejestrów Z80_core: {e}" + term.clear_eol, end='')

            pressed_str = ",".join(sorted(self.pressed_keys)) if self.pressed_keys else "-"
            print(term.move_xy(2, 11) + f"CA80:[{pressed_str}]  lastkey:[{self._last_key_repr}]" + term.clear_eol, end='')
            if self.step_mode:
                print(term.move_xy(2, 12) + "Tryb krokowy - naciśnij Enter..." + term.clear_eol, end='')
            else:
                 print(term.move_xy(2, 12) + term.clear_eol, end='')

        sys.stdout.flush()

    def run(self):
        term = self.term
        try:
            with term.fullscreen(), term.cbreak(), term.hidden_cursor(), term.keypad():
                print(term.home + term.clear, end='')
                self._draw_ui()

                step_wait_key = self.step_mode
                last_draw_time = time.monotonic()
                last_cpu_time = time.monotonic()
                min_frame_time = 1.0 / 60.0

                while not self._quit_requested:
                    start_loop_time = time.monotonic()
                    # W trybie krokowym wykonaj 1 krok, w ciągłym — tstates_per_frame

                    # --- Obsługa wejścia ---
                    key = term.inkey(timeout=0) # Nie blokuj

                    if key:
                        self._last_key_repr = f"str={repr(str(key))} seq={key.is_sequence} code={key.code}"
                        if key == 'q' or (key.is_sequence and key.code == term.KEY_ESCAPE):
                            self._quit_requested = True; continue

                        is_enter = key.is_sequence and key.code == term.KEY_ENTER

                        if self.step_mode:
                            if is_enter:
                                step_wait_key = False
                        else:
                            if is_enter:
                                ca80_key = '='
                            else:
                                ca80_key = self.KEYMAP_PC.get(str(key))
                            if ca80_key:
                                self._key_queue.append(ca80_key)

                    # --- Automat kolejki klawiszy: PRESS → GAP → następny ---
                    if self._key_release_frames > 0:
                        self.pressed_keys.clear()
                        self._key_release_frames -= 1
                    elif self._key_hold_frames > 0:
                        self._key_hold_frames -= 1
                        if self._key_hold_frames == 0:
                            self.pressed_keys.clear()
                            self._key_release_frames = 2  # przerwa po zwolnieniu
                    elif self._key_queue:
                        self.pressed_keys = {self._key_queue.popleft()}
                        self._key_hold_frames = 5   # ~83ms przy 60FPS
                    else:
                        self.pressed_keys.clear()

                    # --- Wykonanie CPU ---
                    if not step_wait_key:
                        try:
                            # T-stany proporcjonalne do rzeczywistego czasu → poprawna prędkość zegara
                            now_cpu = time.monotonic()
                            dt = min(now_cpu - last_cpu_time, 0.05)  # cap 50ms
                            last_cpu_time = now_cpu
                            tstates_per_frame = 1 if self.step_mode else int(dt * CLK_CPU_HZ)
                            limit = tstates_per_frame
                            frame_tstates = 0
                            # Zresetuj licznik ramki i ustaw bazę czasową audio:
                            # wszystkie OUT(EC) wykonane w tym wsadzie zostaną
                            # pozycjonowane względem tej bazy z offsetem
                            # równym frame_tstates w momencie triggera.
                            self.frame_tstates = 0
                            self.audio.begin_frame()
                            while frame_tstates < limit:
                                cycles = Z80.execute_one_step()
                                frame_tstates += cycles
                                self.frame_tstates = frame_tstates
                                # Wyzwolenie NMI co 8000 T-states (500Hz przy 4MHz)
                                if Z80.tstates >= Z80.tstatesPerInterrupt:
                                    Z80.tstates -= Z80.tstatesPerInterrupt
                                    Z80.nmi_cpu()

                        except Exception as e:
                           self._quit_requested = True
                           print(f"\n[FATAL] Błąd wykonania CPU: {e}", file=sys.stderr); traceback.print_exc(); continue

                        if self.step_mode:
                            step_wait_key = True # Po wykonaniu kroku, czekaj na Enter

                    # --- Aktualizacja UI ---
                    current_time = time.monotonic()
                    # Rysuj w trybie krokowym po wykonaniu kroku lub co ~1/60s w trybie ciągłym
                    if (self.step_mode and not step_wait_key) or (not self.step_mode and (current_time - last_draw_time) >= min_frame_time):
                        self._draw_ui()
                        last_draw_time = current_time

                    # --- Zwolnienie CPU hosta do ~60 FPS ---
                    if not self.step_mode:
                        elapsed_loop_time = time.monotonic() - start_loop_time
                        sleep_time = min_frame_time - elapsed_loop_time
                        if sleep_time > 0:
                            time.sleep(sleep_time)

        finally:
            # Zamknij strumień audio przed przywróceniem terminala
            try:
                self.audio.shutdown()
            except Exception:
                pass
            try:
                 if self.term.is_a_tty: print(self.term.normal_cursor + self.term.exit_fullscreen, end=''); sys.stdout.flush()
            except Exception: pass

# ----------------------------------------------------------------------------
# Główna część programu (CLI)
# ----------------------------------------------------------------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Emulator mikrokomputera CA‑80 (konfiguracja rozbudowana MIK290)",
        formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--monitor", default="CA80.BIN", metavar="PLIK",
                        help="Monitor systemowy (U9 @ 0x0000, domyślnie CA80.BIN)")
    parser.add_argument("--c930", default="C930.BIN", metavar="PLIK",
                        help="Pakiet C930 (U11 @ 0x4000, domyślnie C930.BIN)")
    parser.add_argument("--c800", default="C800.BIN", metavar="PLIK",
                        help="Pakiet C800 (U10 @ 0x8000, domyślnie C800.BIN)")
    parser.add_argument("--anode", action="store_true",
                        help="Wyświetlacze ze wspólną anodą (odwraca logikę segmentów)")
    parser.add_argument("--step", action="store_true",
                        help="Tryb krokowy (naciśnij Enter, aby wykonać krok)")
    parser.add_argument("--no-audio", action="store_true",
                        help="Wyłącz generowanie dźwięku (port 0xEC)")
    args = parser.parse_args()

    # Szybka weryfikacja istnienia plików przed uruchomieniem UI.
    # Memory.load_bin obsłużyłoby brak pliku gracefully, ale strict=True
    # w CA80.__init__ spowoduje wyjątek — więc lepiej od razu dać
    # czytelny komunikat tutaj, z listą wszystkich brakujących plików.
    missing = [p for p in (args.monitor, args.c930, args.c800)
               if not pathlib.Path(p).is_file()]
    if missing:
        print(f"[BŁĄD] Brak plików ROM: {', '.join(missing)}", file=sys.stderr)
        print("[INFO] Umieść je w bieżącym katalogu lub podaj ścieżki przez "
              "--monitor, --c930, --c800.", file=sys.stderr)
        sys.exit(1)

    print(f"[INFO] Start CA‑80 (Python {sys.version_info.major}."
          f"{sys.version_info.minor}, rdzeń Z80_core.py, "
          f"konfiguracja rozbudowana 16K+16K+4K ROM / 28K RAM)")
    print("[INFO] Naciśnij 'q' aby zakończyć…")
    time.sleep(0.5)

    machine = None
    term = Terminal()
    exit_code = 0
    try:
        machine = CA80(monitor_path=args.monitor,
                       c930_path=args.c930,
                       c800_path=args.c800,
                       anode=args.anode,
                       step=args.step,
                       audio_enabled=not args.no_audio)
        machine.run()
        print("\n[INFO] Zakończono emulację.")
    except Exception as e:
         exit_code = 1
         try:
             if term.is_a_tty: print(term.normal_cursor + term.exit_fullscreen + term.clear + term.home, end=''); sys.stdout.flush()
         except Exception: pass
         print(f"\n[FATAL] Wystąpił nieoczekiwany błąd w trakcie działania: {e}", file=sys.stderr)
         traceback.print_exc()
    except KeyboardInterrupt:
         print("\n[INFO] Przerwano przez użytkownika (Ctrl+C).")
         exit_code = 0
    finally:
        try:
            if term.is_a_tty and hasattr(term, '_normal'):
                print(term.normal, end=''); sys.stdout.flush()
        except Exception: pass
        sys.exit(exit_code)