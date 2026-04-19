# -*- coding: utf-8 -*-
"""
ca80_sound.py
Emulacja dźwięku CA80 — port 0xEC + U15/74123 (monostabilny) + głośnik.

=== ARCHITEKTURA SPRZĘTOWA ===

Na podstawie analizy oryginalnego monitora CA80 V3.0 (MIK290) oraz schematu
MIK290/R8 z dokumentacji MIK05:

    OUT (0ECH), A      — monitor wykonuje dokładnie JEDEN OUT w procedurze NMI
    ↓                    gdy licznik SYG (FFE9) > 0; wartość w A nieistotna
    74LS138 dekoduje
    ↓
    /CTF8 (strob)      — NAZWA na schemacie jest myląca: "CTF8" to nazwa pinu
    ↓                    dekodera U15 wyzwalanego adresem 0xEC, NIE port F8.
                         CTC Z80 (porty F8-FB) jest osobnym układem i służy
                         monitorowi tylko do pracy krokowej (debugger).
    U15/74123          — monostabilny: każdy strob generuje POJEDYNCZY DODATNI
    ↓                    impuls o szerokości τ = R21·C (~0.7 ms w CA80)
    Tranzystor T1
    ↓
    Głośnik 45Ω


=== CZĘSTOTLIWOŚĆ DŹWIĘKU ===

Procedura NMI monitora (adres 0066H):
  - jest wywoływana co 2 ms przez osobny oscylator sprzętowy (kwarc KW + bramki
    U2 + multiwibrator Ux na schemacie R8; niezależny od Z80 CTC)
  - gdy licznik SYG ≠ 0: wykonuje pojedynczy OUT (0ECH),A i dekrementuje SYG
  - efekt: strumień 500 impulsów/s → ton 500 Hz na głośniku przez (SYG × 2) ms

Przykład z dokumentacji (MIK05 rozdz. 1.22):
  LD HL, 0FFE9H       ; adres SYG
  LD (HL), 50         ; 50 impulsów × 2 ms = 100 ms sygnału 500 Hz


=== MODEL EMULATORA ===

- Każdy zapis do portu 0xEC umieszcza w kolejce znacznik próbki, od której
  rozpoczyna się DODATNI impuls o szerokości PULSE_WIDTH_S (~0.7 ms).
- Wątek PortAudio konsumuje kolejkę w callbacku, renderując impulsy dokładnie
  tam, gdzie Z80 wykonał OUT (0ECH).
- Składowa stała (DC offset — wszystkie impulsy są dodatnie) jest usuwana
  przez 1-biegunowy filtr górnoprzepustowy (~40 Hz), symulujący kondensator
  sprzęgający obecny w torze głośnika na prawdziwej płycie.

Callback PortAudio leci w dedykowanym wątku natywnym — GIL jest zwalniany
w trakcie wywołania, więc pętla Z80 w głównym wątku nie jest blokowana.
"""
import sys
from collections import deque

import numpy as np

try:
    import sounddevice as sd
    _SD_AVAILABLE = True
except ImportError:
    _SD_AVAILABLE = False


# ============================================================================
# Parametry audio
# ============================================================================
SAMPLE_RATE = 48_000
BLOCK_SIZE = 256              # ~5.3 ms latencji — OK dla beeperów
AMPLITUDE = 0.20              # łagodny poziom, nie przesterowuje

# Zegar Z80 — używany do mapowania pozycji OUT(EC) w ramce emulatora
# na pozycję próbki audio. Emulator może wykonać wiele NMI (8×) w jednej
# ramce czasu rzeczywistego (~16 ms), ale każde NMI występuje w innym
# momencie emulowanego czasu Z80. Rozkład triggerów na osi audio bierze
# ten fakt pod uwagę: trigger_sygnal(frame_tstates) używa liczby T-stanów
# Z80 wykonanych od początku ramki jako offsetu próbkowego.
CPU_HZ = 4_000_000

# Szerokość pojedynczego impulsu 74123 (τ = R21·C).
# CA80 typowo τ ≈ 0.5–1.0 ms. 0.7 ms daje duty cycle 35% przy NMI 2 ms,
# co odpowiada typowemu brzmieniu oryginalnego sprzętu (ostre, "pikające").
PULSE_WIDTH_S = 0.0007
_PULSE_SAMPLES = max(1, int(PULSE_WIDTH_S * SAMPLE_RATE))

# Po jakim czasie bez nowego triggera uznajemy stare wpisy w kolejce za
# porzucone (ochrona przed niekontrolowanym wzrostem gdyby audio utknęło).
# W normalnej pracy kolejka jest konsumowana co BLOCK_SIZE próbek.
_STALE_SAMPLES = int(0.100 * SAMPLE_RATE)

# DC blocker (1-biegunowy HPF): y[n] = x[n] - x[n-1] + R·y[n-1]
# R = 0.995 przy 48 kHz → fc ≈ 38 Hz; usuwa DC i subbas, nie rusza 500 Hz.
_DC_R = np.float32(0.995)


# ============================================================================
# Kolejka triggerów + oscylator
# ============================================================================
class PulseOscillator:
    """
    Kolejka impulsów 74123 — każdy OUT(0xEC) dodaje znacznik, callback audio
    konsumuje w pozycji próbki.

    Thread safety: collections.deque.append/popleft są atomowe w CPython
    dzięki GIL, lock nie jest potrzebny dla tej kombinacji operacji.
    """
    __slots__ = ('queue',)

    def __init__(self):
        # maxlen chroni przed rozrostem gdyby wątek audio zamarł
        self.queue = deque(maxlen=4096)

    def trigger(self, current_sample: int) -> None:
        """Wywoływane z wątku Z80 przy każdym OUT (0xEC). Nie blokuje."""
        self.queue.append(current_sample)


# ============================================================================
# System audio
# ============================================================================
class AudioSystem:
    """
    Wrapper na sounddevice.OutputStream.

    Brak dźwięku (sounddevice niedostępny / nie udało się otworzyć karty /
    wyłączone flagą) obsługiwany gracefully: emulator działa dalej bez
    dźwięku, trigger_sygnal() staje się no-op.
    """

    def __init__(self, enabled: bool = True):
        self.oscillator = PulseOscillator()
        self._stream = None
        self._samples_generated = 0

        # Mapowanie czasu Z80 → pozycja w buforze audio.
        # Gdy wątek audio nie działa w doskonałej synchronizacji z wątkiem Z80
        # (co jest normalne), używamy relatywnej pozycji w ramce emulatora.
        # _frame_base_sample: indeks próbki audio gdzie zaczyna się bieżąca
        #   ramka Z80 (aktualizowany z ca80.py przez begin_frame())
        # _tstates_per_sample: ile T-stanów Z80 "mieści się" w 1 próbce audio
        self._frame_base_sample = 0
        self._tstates_per_sample = CPU_HZ / SAMPLE_RATE  # 4e6/48000 = 83.33

        # Stan DC blockera — przechowywany między kolejnymi callbackami
        self._dc_prev_in = np.float32(0.0)
        self._dc_prev_out = np.float32(0.0)

        if not enabled:
            print("[INFO ca80_sound] Audio wyłączone przez użytkownika.")
            return

        if not _SD_AVAILABLE:
            print("[WARN ca80_sound] Moduł sounddevice niedostępny — "
                  "dźwięk wyłączony. Instalacja: pip install sounddevice numpy",
                  file=sys.stderr)
            return

        try:
            self._stream = sd.OutputStream(
                samplerate=SAMPLE_RATE,
                blocksize=BLOCK_SIZE,
                channels=1,
                dtype='float32',
                callback=self._callback,
                latency='low',
            )
            self._stream.start()
            latency_ms = BLOCK_SIZE * 1000.0 / SAMPLE_RATE
            print(f"[INFO ca80_sound] Audio uruchomione: "
                  f"{SAMPLE_RATE} Hz, block={BLOCK_SIZE} "
                  f"(latencja ≈ {latency_ms:.1f} ms)")
        except Exception as e:
            print(f"[ERROR ca80_sound] Nie udało się uruchomić audio: {e}",
                  file=sys.stderr)
            self._stream = None

    # ------------------------------------------------------------------
    # API dla ca80.py i ca80_ports.py
    # ------------------------------------------------------------------
    def begin_frame(self) -> None:
        """
        Wywoływane z ca80.py na POCZĄTKU każdej ramki emulacji.
        Ustawia bazę czasową dla kolejnych wywołań trigger_sygnal()
        wykonywanych w tej ramce.

        Baza = aktualny indeks próbki, jaki PortAudio spodziewa się
        wyrenderować najbliższym callbackiem. Triggery w tej ramce
        będą pozycjonowane jako base + (frame_tstates / T_per_sample),
        więc rozkładają się wzdłuż osi czasu zamiast gromadzić w jednym
        punkcie.
        """
        self._frame_base_sample = self._samples_generated

    def trigger_sygnal(self, frame_tstates: int = 0) -> None:
        """
        Wywoływane z port_out() przy zapisie do portu 0xEC.

        frame_tstates: liczba T-stanów Z80 wykonanych od początku bieżącej
          ramki emulacji (od ostatniego begin_frame()). Pozwala rozłożyć
          wiele triggerów w jednej ramce na właściwe pozycje czasowe
          w buforze audio. Gdy =0 (domyślnie), wszystkie triggery w ramce
          wylądują w jednym punkcie (ZŁE dla ciągłego tonu — powoduje
          „pierdzenie" zamiast dźwięku).

        Bezpieczne gdy audio wyłączone (no-op na poziomie renderera).
        """
        offset_samples = int(frame_tstates / self._tstates_per_sample)
        sample_pos = self._frame_base_sample + offset_samples
        self.oscillator.trigger(sample_pos)

    # ------------------------------------------------------------------
    # Callback PortAudio — dedykowany wątek natywny
    # ------------------------------------------------------------------
    def _callback(self, outdata, frames, time_info, status):
        # status != 0 → XRun sterownika audio; nie przerywamy pętli Z80.
        if status:
            pass

        base = self._samples_generated
        end = base + frames
        buf = outdata[:, 0]
        buf.fill(0.0)

        queue = self.oscillator.queue

        # 1. Czyszczenie kolejki z triggerów wyraźnie starszych niż bieżący blok
        #    (zabezpieczenie przed rozrostem gdyby callback był długo nieaktywny)
        while queue:
            try:
                trig = queue[0]
            except IndexError:
                break
            if base - trig > _STALE_SAMPLES:
                queue.popleft()
            else:
                break

        # 2. Renderowanie impulsów w tym bloku.
        #    Przechodzimy po kolejce, impulsy których koniec jeszcze nie minął
        #    zostają; impulsy których początek jest za końcem bloku — zostają
        #    na następny callback.
        idx = 0
        while idx < len(queue):
            try:
                trig = queue[idx]
            except IndexError:
                break

            pulse_end = trig + _PULSE_SAMPLES

            if trig >= end:
                # Impuls zaczyna się po tym bloku — zostaw na następny callback
                break

            if pulse_end <= base:
                # Impuls w całości przed tym blokiem — usuń i idź dalej
                if idx == 0:
                    queue.popleft()
                else:
                    idx += 1
                continue

            # Fragment impulsu widoczny w tym bloku
            start_i = max(0, trig - base)
            stop_i = min(frames, pulse_end - base)
            if start_i < stop_i:
                buf[start_i:stop_i] = np.float32(AMPLITUDE)

            if pulse_end <= end:
                # Impuls w całości wyrenderowany — usuń
                if idx == 0:
                    queue.popleft()
                else:
                    idx += 1
            else:
                # Impuls wystaje poza blok — zostaw, dokończy się w następnym
                idx += 1

        # 3. DC blocker: usuń składową stałą (wszystkie impulsy dodatnie → DC).
        #    Symulacja kondensatora sprzęgającego w realnym torze audio CA80.
        self._dc_prev_in, self._dc_prev_out = _dc_block(
            buf, self._dc_prev_in, self._dc_prev_out, _DC_R)

        self._samples_generated = end

    # ------------------------------------------------------------------
    # Zamknięcie strumienia
    # ------------------------------------------------------------------
    def shutdown(self):
        if self._stream is not None:
            try:
                self._stream.stop()
                self._stream.close()
            except Exception as e:
                print(f"[WARN ca80_sound] shutdown(): {e}", file=sys.stderr)
            self._stream = None


# ============================================================================
# DC blocker (1-bieg. HPF) — działa in-place na buforze float32
# ============================================================================
def _dc_block(buf, prev_in, prev_out, R):
    """
    Filtr HPF: y[n] = x[n] - x[n-1] + R·y[n-1]
    Operuje in-place. Zwraca (prev_in, prev_out) do zachowania ciągłości
    filtra między kolejnymi blokami.

    Pętla w Pythonie przy 256 próbkach = ~0.1 ms, co jest akceptowalne
    w callbacku audio. Wektoryzacja filtra rekurencyjnego jest niebanalna
    i dla tego rozmiaru bufora nieopłacalna.
    """
    x_prev = prev_in
    y_prev = prev_out
    n = len(buf)
    for i in range(n):
        x = buf[i]
        y = x - x_prev + R * y_prev
        buf[i] = y
        x_prev = x
        y_prev = y
    return x_prev, y_prev
