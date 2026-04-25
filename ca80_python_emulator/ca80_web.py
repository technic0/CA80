# -*- coding: utf-8 -*-
"""
ca80_web.py
Webowy emulator CA-80 — serwer HTTP + WebSocket + bridge do emulatora.

ARCHITEKTURA:

  ┌─────────────────────────────────────────────────────────────┐
  │  Wątek główny: aiohttp event loop                          │
  │  ├── HTTP serwuje statyczne pliki (HTML, CSS w HTML)       │
  │  └── WebSocket /ws (60 fps): broadcast stanu wyświetlacza  │
  │                              + odbiór keydown/keyup         │
  └─────────────────────────────────────────────────────────────┘
                              ↕ (pressed_keys, BWYS)
  ┌─────────────────────────────────────────────────────────────┐
  │  Wątek tła: pętla emulacyjna Z80                           │
  │  - Z80_core.execute_one_step()                             │
  │  - NMI co 8000 T-stanów (=500 Hz)                          │
  │  - audio.begin_frame() na każdej iteracji                  │
  │  - czyta z self.pressed_keys (zarządzane przez WS handler) │
  └─────────────────────────────────────────────────────────────┘

WĄTKI I SYNCHRONIZACJA:
- pressed_keys to set[str], modyfikowany przez WS handler i czytany przez
  ca80_ports._pa_state(). W CPython operacje set.add/discard są atomowe
  dzięki GIL — lock nie jest potrzebny.
- BWYS (bufor wyświetlacza w RAMie 0xFFF7-0xFFFE) czytany jest przez memory.peekb()
  w wątku WS broadcastera. Jednoczesny zapis w wątku Z80 jest bezpieczny —
  pojedynczy bajt RAM jest atomowy.
- frame_tstates: ustawiany przez wątek Z80, czytany przez ca80_ports.port_out
  przy OUT(EC). Też atomowy (int).

URUCHOMIENIE:
  python ca80_web.py [--port 8000] [--no-audio] [--anode]
                     [--monitor PLIK] [--c930 PLIK] [--c800 PLIK]

  Po starcie otwórz w przeglądarce: http://localhost:8000/
"""
import argparse
import asyncio
import json
import pathlib
import sys
import threading
import time
import traceback

from aiohttp import web, WSMsgType

import Z80_core as Z80
import ca80_memory as memory
import ca80_ports as ports
from ca80_sound import AudioSystem


# ============================================================================
# Stałe taktowania
# ============================================================================
CLK_CPU_HZ = 4_000_000          # 4 MHz Z80
NMI_TSTATES = 8000              # NMI co 2 ms (500 Hz)
WS_BROADCAST_HZ = 60            # częstotliwość wysyłania stanu wyświetlacza


# ============================================================================
# Bufor wyświetlacza CA80
# ============================================================================
# BWYS w RAM monitora: 0xFFF7..0xFFFE (8 bajtów segmentów)
# Cyfra 0 (skrajnie prawa) = 0xFFFE, cyfra 7 (skrajnie lewa) = 0xFFF7
BWYS_LOW = 0xFFF7
BWYS_HIGH = 0xFFFE


def read_display_segments(anode_mode: bool = False) -> list[int]:
    """
    Czyta 8 bajtów BWYS i zwraca listę 8 bajtów w kolejności:
    indeks 0 = skrajnie LEWA cyfra na wyświetlaczu
    indeks 7 = skrajnie PRAWA cyfra

    Mapowanie BWYS w pamięci CA80:
        0xFFF7 = sprzętowa cyfra 0 = skrajnie PRAWA
        0xFFFE = sprzętowa cyfra 7 = skrajnie LEWA
    Więc dla UI rysującego od lewej do prawej:
        idx 0 (lewa) ← cyfra 7 ← 0xFFFE = BWYS_HIGH - 0
        idx 7 (prawa) ← cyfra 0 ← 0xFFF7 = BWYS_HIGH - 7

    Bity segmentów (zgodnie z R24 dokumentacji):
        bit 7 = K (kropka, DP), bit 6 = G, ..., bit 0 = A

    Anode mode: jeśli True, segmenty są inwertowane (HIGH=świeci dla
    wspólnej anody; LOW=świeci dla wspólnej katody).
    """
    segments = [memory.peekb(BWYS_HIGH - i) for i in range(8)]
    if anode_mode:
        segments = [(~s) & 0xFF for s in segments]
    return segments


# ============================================================================
# Klasa CA80Web — analog CA80 ale bez UI terminalowego
# ============================================================================
class PPI8255State:
    """Identyczna jak w ca80.py - prosty kontener stanu PPI."""
    __slots__ = ('pa', 'pb', 'pc', 'ctrl')
    def __init__(self):
        self.pa = 0xFF
        self.pb = 0
        self.pc = 0xFF
        self.ctrl = 0x90


class CA80Web:
    """
    Emulator CA-80 dla wersji webowej. Bez logiki UI.
    """
    def __init__(self,
                 monitor_path: str = "CA80.BIN",
                 c930_path: str = "C930.BIN",
                 c800_path: str = "C800.BIN",
                 *,
                 anode: bool = False,
                 audio_enabled: bool = True):
        # Pamięć — sztywna konfiguracja MIK09
        memory.init_memory(monitor_path, c930_path, c800_path, strict=True)

        # 8255 PPI (U7) — ctrl init 0x90: PA=in, PB=out, PC=out
        self.ppi1 = PPI8255State()
        self.ppi1.ctrl = 0x90

        # Stan klawiatury — zarządzany przez WS handler, czytany przez ports
        self.pressed_keys: set[str] = set()

        # Audio (port 0xEC → 74123 → głośnik)
        self.audio = AudioSystem(enabled=audio_enabled)

        # Licznik T-stanów Z80 od początku ramki — używany przez port_out(EC)
        self.frame_tstates: int = 0

        # Tryb anody (kosmetyczny — odwracanie segmentów)
        self.anode = anode

        # Stan dla UI (LED-y) - wątek Z80 ustawia, WS broadcast czyta
        self.cpu_running: bool = False
        self.fault: bool = False
        self.fault_message: str = ""

        # Aktywna cyfra dla NMI multiplexera (kompat z ca80_ports)
        self.active_digit: int = 0
        self.led_segments: list[int] = [0] * 8

        # Wpięcie portów
        ports.init_ports(self, audio_system=self.audio)

        # Inicjalizacja Z80
        Z80.Z80(CLK_CPU_HZ / 1_000_000)
        Z80.reset()
        Z80.tstatesPerInterrupt = NMI_TSTATES

        # Zdarzenie zatrzymania (do graceful shutdown)
        self._stop_event = threading.Event()

    # -------------------------------------------------------------------
    # Pętla emulacyjna - wątek tła
    # -------------------------------------------------------------------
    def run_emulation_loop(self):
        """
        Pętla CPU - taka sama logika jak ca80.run() ale bez UI.
        Działa do wywołania self._stop_event.set().
        """
        self.cpu_running = True
        last_cpu_time = time.monotonic()
        try:
            while not self._stop_event.is_set():
                now_cpu = time.monotonic()
                dt = min(now_cpu - last_cpu_time, 0.05)  # cap 50 ms
                last_cpu_time = now_cpu
                tstates_per_frame = int(dt * CLK_CPU_HZ)
                limit = tstates_per_frame
                frame_tstates = 0

                # Reset frame baseline + audio frame begin
                self.frame_tstates = 0
                self.audio.begin_frame()

                while frame_tstates < limit:
                    cycles = Z80.execute_one_step()
                    frame_tstates += cycles
                    self.frame_tstates = frame_tstates
                    # NMI co 8000 T-stanów (500 Hz)
                    if Z80.tstates >= Z80.tstatesPerInterrupt:
                        Z80.tstates -= Z80.tstatesPerInterrupt
                        Z80.nmi_cpu()

                # Małe sleep żeby nie zużywać 100% CPU jeśli wsad był krótki
                # (Python time.monotonic() ma rozdzielczość zwykle 1ms)
                time.sleep(0.001)

        except Exception as e:
            self.cpu_running = False
            self.fault = True
            self.fault_message = str(e)
            print(f"[FATAL emul] {e}", file=sys.stderr)
            traceback.print_exc()
        finally:
            self.cpu_running = False
            try:
                self.audio.shutdown()
            except Exception:
                pass

    def stop(self):
        """Zatrzymuje pętlę emulacji."""
        self._stop_event.set()

    # -------------------------------------------------------------------
    # Stan dla UI
    # -------------------------------------------------------------------
    def get_display_state(self) -> dict:
        """Zwraca stan dla broadcastu WebSocket."""
        return {
            'segments': read_display_segments(self.anode),
            'cpu_running': self.cpu_running,
            'fault': self.fault,
            'fault_message': self.fault_message,
        }


# ============================================================================
# Lista znanych klawiszy CA80 (walidacja keydown/keyup z UI)
# ============================================================================
VALID_KEYS = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F',
    'G', 'M', '.', '=',
    'F1', 'F2', 'F3', 'F4',
}


# ============================================================================
# Globalna instancja emulatora (set w main)
# ============================================================================
_CA80: CA80Web | None = None


# ============================================================================
# HTTP handlers
# ============================================================================
async def handle_index(request):
    """Serwuje index.html."""
    static_dir = pathlib.Path(__file__).parent / "static"
    html_path = static_dir / "index.html"
    if not html_path.is_file():
        return web.Response(text="static/index.html nie znaleziony",
                           status=500)
    return web.FileResponse(html_path)


async def handle_websocket(request):
    """
    Obsługa WebSocket: równoległe broadcast (60 fps) i odbiór klawiszy.
    """
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    print(f"[WS] Klient połączony: {request.remote}")

    # Zadanie broadcastu - co 1/60 s wysyła stan wyświetlacza
    async def broadcaster():
        try:
            interval = 1.0 / WS_BROADCAST_HZ
            while not ws.closed:
                state = _CA80.get_display_state()
                await ws.send_json({'type': 'display', **state})
                await asyncio.sleep(interval)
        except (asyncio.CancelledError, ConnectionResetError):
            pass
        except Exception as e:
            print(f"[WS broadcaster] {e}", file=sys.stderr)

    broadcast_task = asyncio.create_task(broadcaster())

    try:
        async for msg in ws:
            if msg.type == WSMsgType.TEXT:
                try:
                    data = json.loads(msg.data)
                except json.JSONDecodeError:
                    continue

                msg_type = data.get('type')
                key = data.get('key')

                if msg_type == 'keydown' and key in VALID_KEYS:
                    _CA80.pressed_keys.add(key)
                elif msg_type == 'keyup' and key in VALID_KEYS:
                    _CA80.pressed_keys.discard(key)
                elif msg_type == 'keyclear':
                    # Awaryjne czyszczenie - np. gdy okno traci fokus
                    _CA80.pressed_keys.clear()

            elif msg.type == WSMsgType.ERROR:
                print(f"[WS] błąd: {ws.exception()}", file=sys.stderr)
                break
    finally:
        broadcast_task.cancel()
        try:
            await broadcast_task
        except asyncio.CancelledError:
            pass
        print(f"[WS] Klient rozłączony: {request.remote}")

    return ws


# ============================================================================
# Główna funkcja
# ============================================================================
def main():
    parser = argparse.ArgumentParser(
        description="Webowy emulator CA-80 (rozbudowana konfiguracja MIK290)",
        formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--port", type=int, default=8000,
                        help="Port serwera HTTP (domyślnie 8000)")
    parser.add_argument("--monitor", default="CA80.BIN", metavar="PLIK",
                        help="Monitor U9 @ 0x0000 (domyślnie CA80.BIN)")
    parser.add_argument("--c930", default="C930.BIN", metavar="PLIK",
                        help="Pakiet U11 @ 0x8000 (domyślnie C930.BIN)")
    parser.add_argument("--c800", default="C800.BIN", metavar="PLIK",
                        help="Pakiet U10 @ 0x4000 (domyślnie C800.BIN)")
    parser.add_argument("--anode", action="store_true",
                        help="Tryb wspólnej anody (odwraca segmenty)")
    parser.add_argument("--no-audio", action="store_true",
                        help="Wyłącz dźwięk (port 0xEC)")
    args = parser.parse_args()

    # Weryfikacja plików ROM
    missing = [p for p in (args.monitor, args.c930, args.c800)
               if not pathlib.Path(p).is_file()]
    if missing:
        print(f"[BŁĄD] Brak plików ROM: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)

    print(f"[INFO] Start CA-80 Web (Python {sys.version_info.major}."
          f"{sys.version_info.minor})")

    # Utwórz emulator
    global _CA80
    _CA80 = CA80Web(monitor_path=args.monitor,
                    c930_path=args.c930,
                    c800_path=args.c800,
                    anode=args.anode,
                    audio_enabled=not args.no_audio)

    # Wątek emulatora (daemon = umiera z procesem)
    emul_thread = threading.Thread(target=_CA80.run_emulation_loop,
                                    daemon=True, name="Z80-emul")
    emul_thread.start()

    # Skonfiguruj serwer aiohttp
    app = web.Application()
    app.router.add_get('/', handle_index)
    app.router.add_get('/ws', handle_websocket)

    # Statyczne pliki (jeśli kiedyś dodam dodatkowe CSS/JS)
    static_dir = pathlib.Path(__file__).parent / "static"
    app.router.add_static('/static', static_dir, show_index=False)

    print(f"\n{'='*60}")
    print(f"  Serwer uruchomiony.")
    print(f"  Otwórz w przeglądarce: http://localhost:{args.port}/")
    print(f"  Ctrl+C aby zakończyć.")
    print(f"{'='*60}\n")

    try:
        web.run_app(app, host='localhost', port=args.port,
                    print=lambda *a, **k: None)  # ucisz domyślny banner
    except KeyboardInterrupt:
        print("\n[INFO] Zatrzymywanie...")
    finally:
        _CA80.stop()
        emul_thread.join(timeout=2.0)
        print("[INFO] Zakończono.")


if __name__ == "__main__":
    main()
