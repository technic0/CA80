# -*- coding: utf-8 -*-
"""
ca80_memory.py
Moduł pamięci emulatora CA80 — konfiguracja rozbudowana (U9/U10/U11/U12).

=== FIZYCZNA MAPA PAMIĘCI (wg dokumentacji MIK09 rozdz. 3.0) ===

  0x0000–0x3FFF  U9  — Monitor systemowy (CA80.BIN)
                      Gniazdo 16 KB. Jeśli plik jest 8 KB, mirrorowany
                      do pełnych 16 KB przez dekoder (niepełne dekodowanie).
  0x4000–0x7FFF  U10 — Pakiet C800 MONITOR (C800.BIN)
                      Gniazdo 16 KB. Plik 2 KB mirroruje się 8 razy
                      w obszarze (tak samo jak na prawdziwym sprzęcie).
                      Wejście poprzez *80 (monitor sprawdza [0x4001]==0x55).
                      Punkt startu programu: 0x4020.
  0x8000–0xBFFF  U11 — Pakiet C930 MONITOR (C930.BIN)
                      Gniazdo 16 KB. Plik 16 KB wypełnia w całości.
                      Wejście poprzez *89 (monitor sprawdza [0x8001]==0xAA).
                      Punkt startu programu: 0x8002.
  0xC000–0xFFFF  U12 — RAM użytkownika (16 KB)
                      Krytyczny systemowy RAM w górnych adresach:
                      FFE8–FFE9  liczniki LCI/SYG (timer + dźwięk),
                      FFCC–FFEC  obszar zmiennych monitora,
                      FFF7–FFFE  bufor BWYS wyświetlacza,
                      FF8D–FFFF  stos monitora (TOS=FFFF).

=== DLACZEGO C800 POD 0x4000, A NIE 0x8000 ===

Nazwa „C800" to artefakt historyczny — w pierwotnej wersji CA80 ten program
faktycznie siedział pod adresem 0x0800. W rozbudowanej konfiguracji (MIK09+)
program przeniesiono do U10, ale nazwy nie zmieniono. Monitor CA80 od wersji
MIK32 zawiera procedury WEJUZ (dla U10) i WEJU11 (dla U11), które używają
magicznych sygnatur 0x55 i 0xAA jako zabezpieczenia przed skokiem do
niezainicjalizowanego EPROM-u.

=== API ===

Moduł udostępnia dwie warstwy:

1. Klasę `Memory` (OOP) — właściwe serce modułu. Ładuje pliki w konstruktorze,
   emuluje ochronę ROM, obsługuje zawijanie adresów. Używaj tej klasy
   bezpośrednio jeśli piszesz własny kod.

2. Funkcje modułowe (`peekb`, `pokeb`, `peekw`, `pokew`, `peeksb`, `init_memory`)
   — cienkie delegaty do globalnej instancji Memory. Zachowane dla kompatybilności
   z rdzeniem Z80 (`Z80_core.py`), który woła `memory.peekb(...)` itd.
"""
from __future__ import annotations
import struct
import sys
from pathlib import Path


# Obiekt do dekodowania bajtu ze znakiem (wspólny dla wszystkich instancji).
_SIGNED_BYTE = struct.Struct('<b')


# ============================================================================
# Klasa Memory — główna implementacja
# ============================================================================
class Memory:
    """
    Płaska pamięć 64 KB z emulacją ochrony ROM.

    Obszar ROM (0x0000–0xBFFF) jest chroniony przed zapisem — próby pisania
    są po cichu ignorowane (tak jak na fizycznym sprzęcie EPROM). Zapis jest
    dozwolony tylko w obszarze RAM (0xC000–0xFFFF).
    """

    # Granica ROM/RAM — poniżej = ROM (read-only), od tego adresu = RAM
    ROM_END = 0xC000

    # Parametry poszczególnych gniazd (wg dokumentacji MIK09 rozdz. 3.0)
    # Wszystkie gniazda ROM mają rozmiar logiczny 16 KB; pliki mniejsze
    # są mirrorowane do pełnych 16 KB (niepełne dekodowanie adresów).
    U9_BASE,  U9_SIZE  = 0x0000, 0x4000   # 16 KB — monitor CA80 (CA80.BIN)
    U10_BASE, U10_SIZE = 0x4000, 0x4000   # 16 KB — gniazdo U10 (C800.BIN)
    U11_BASE, U11_SIZE = 0x8000, 0x4000   # 16 KB — gniazdo U11 (C930.BIN)
    RAM_BASE, RAM_SIZE = 0xC000, 0x4000   # 16 KB — RAM (U12, 62256 lub 6264)

    def __init__(self,
                 monitor_path: str | Path = "CA80.BIN",
                 c930_path:    str | Path = "C930.BIN",
                 c800_path:    str | Path = "C800.BIN",
                 *,
                 strict: bool = False):
        """
        Inicjalizuje pamięć 64 KB i ładuje ROM-y.

        Parametry:
          monitor_path — plik monitora (mapowany do U9 @ 0x0000)
          c930_path    — plik pakietu C930 (mapowany do U11 @ 0x4000)
          c800_path    — plik pakietu C800 (mapowany do U10 @ 0x8000)
          strict       — jeśli True, brak któregokolwiek pliku jest błędem
                         krytycznym (raise FileNotFoundError); jeśli False
                         (domyślnie), brakujący plik jest ostrzeżeniem
                         i odpowiedni obszar pamięci wypełniany jest 0xFF.
        """
        # Płaska struktura 64 KB — cała przestrzeń adresowa Z80.
        # bytearray daje natywną prędkość indeksowania na pojedynczych bajtach
        # i pozwala na zapis in-place (co robi write_byte dla RAMu).
        # Inicjalizacja na 0xFF odpowiada zachowaniu nieobsadzonych gniazd
        # na szynie (floating bus + pull-up).
        self._mem = bytearray(b'\xFF' * 0x10000)

        # Załaduj ROM-y. Każde gniazdo niezależnie — brak jednego nie blokuje
        # pozostałych (przydatne gdy użytkownik testuje konfigurację minimalną).
        # Wszystkie gniazda ROM akceptują pliki mniejsze niż gniazdo —
        # dekoder adresów na prawdziwym sprzęcie mirroruje je do pełnych 16 KB
        # (MIK09 rozdz. 3.0: "niepełne dekodowanie pamięci").
        self.load_bin(monitor_path, self.U9_BASE,
                      slot_size=self.U9_SIZE, label="U9 (monitor)",
                      mirror_if_smaller=True, strict=strict)
        self.load_bin(c800_path, self.U10_BASE,
                      slot_size=self.U10_SIZE, label="U10 (C800)",
                      mirror_if_smaller=True, strict=strict)
        self.load_bin(c930_path, self.U11_BASE,
                      slot_size=self.U11_SIZE, label="U11 (C930)",
                      mirror_if_smaller=True, strict=strict)

        # Wyzeruj obszar RAMu (nadpisze 0xFF z init).
        # Prawdziwy CA80 po włączeniu ma w RAMie losowe wartości, ale
        # monitor i tak inicjalizuje swoje struktury przy starcie —
        # zero jest wygodniejsze do debugowania.
        self._mem[self.RAM_BASE:self.RAM_BASE + self.RAM_SIZE] = bytes(self.RAM_SIZE)

        print(f"[INFO memory] Mapa (zgodna z MIK09 rozdz. 3.0): "
              f"U9 @ 0x0000-0x3FFF (monitor 16 KB), "
              f"U10 @ 0x4000-0x7FFF (C800 16 KB), "
              f"U11 @ 0x8000-0xBFFF (C930 16 KB), "
              f"RAM @ 0xC000-0xFFFF ({self.RAM_SIZE // 1024} KB)")

    # ------------------------------------------------------------------
    # Ładowanie plików binarnych
    # ------------------------------------------------------------------
    def load_bin(self,
                 path: str | Path,
                 start_address: int,
                 *,
                 slot_size: int | None = None,
                 label: str = "",
                 mirror_if_smaller: bool = False,
                 strict: bool = False) -> bool:
        """
        Bezpiecznie ładuje plik binarny pod wskazany adres.

        Parametry:
          path              — ścieżka do pliku BIN
          start_address     — bazowy adres docelowy w pamięci
          slot_size         — logiczna wielkość gniazda (w bajtach). Jeśli
                              podana, plik nie może być większy; jeśli jest
                              mniejszy i mirror_if_smaller=True, reszta
                              gniazda jest wypełniana mirror-kopiami pliku.
          label             — krótka etykieta dla logów (np. "U9 (monitor)")
          mirror_if_smaller — zachowanie dekodera adresów dla plików mniejszych
                              niż gniazdo (np. 8 KB ROM w gnieździe 16 KB).
                              Standardowo dekoder prostego CA80 mirroruje.
          strict            — raise zamiast ostrzeżenia gdy plik nie istnieje

        Zwraca: True jeśli plik został załadowany, False w przeciwnym razie.
        """
        start_address &= 0xFFFF
        path = Path(path)
        tag = f"[{label}] " if label else ""

        try:
            data = path.read_bytes()
        except FileNotFoundError:
            msg = f"{tag}Brak pliku: {path}"
            if strict:
                raise FileNotFoundError(msg)
            print(f"[WARN memory] {msg} — obszar pozostanie wypełniony 0xFF",
                  file=sys.stderr)
            return False
        except OSError as e:
            # Inne błędy IO (np. uprawnienia) — też chcemy obsłużyć miękko
            msg = f"{tag}Błąd odczytu pliku {path}: {e}"
            if strict:
                raise
            print(f"[WARN memory] {msg}", file=sys.stderr)
            return False

        n = len(data)

        # Walidacja rozmiaru względem gniazda
        if slot_size is not None and n > slot_size:
            msg = (f"{tag}Plik {path} ma {n} B, ale gniazdo @ 0x{start_address:04X} "
                   f"mieści tylko {slot_size} B. Nadmiar zostanie obcięty.")
            print(f"[WARN memory] {msg}", file=sys.stderr)
            data = data[:slot_size]
            n = slot_size

        # Sprawdź czy gniazdo nie wystaje poza 64 KB
        if start_address + (slot_size or n) > 0x10000:
            raise ValueError(
                f"{tag}Gniazdo @ 0x{start_address:04X} + "
                f"{slot_size or n} B wystaje poza 64 KB")

        # Zapisz dane do pamięci (bypassuje write_byte, bo ładujemy ROM-y
        # i ochrona write nie powinna nas tu blokować).
        self._mem[start_address:start_address + n] = data

        # Obsługa mirroru (np. 8 KB w 16 KB gnieździe)
        if (slot_size is not None and n < slot_size
                and mirror_if_smaller and n > 0):
            offset = n
            while offset < slot_size:
                chunk = min(n, slot_size - offset)
                self._mem[start_address + offset:
                          start_address + offset + chunk] = data[:chunk]
                offset += n
            print(f"[INFO memory] {tag}Załadowano {n} B z {path.name} @ 0x{start_address:04X} "
                  f"(mirror do pełnych {slot_size} B)")
        else:
            end_addr = start_address + n - 1
            print(f"[INFO memory] {tag}Załadowano {n} B z {path.name} "
                  f"@ 0x{start_address:04X}-0x{end_addr:04X}")

        return True

    # ------------------------------------------------------------------
    # Odczyt i zapis bajtu — główne operacje
    # ------------------------------------------------------------------
    def read_byte(self, addr: int) -> int:
        """
        Odczyt bajtu. Zawija adresy powyżej 0xFFFF (standardowe zachowanie Z80).
        """
        return self._mem[addr & 0xFFFF]

    def write_byte(self, addr: int, value: int) -> None:
        """
        Zapis bajtu z emulacją ochrony ROM.

        Próby zapisu w obszar ROM (0x0000–0x8FFF) są CAŁKOWICIE IGNOROWANE —
        bez wyjątku, bez przerywania emulacji. Tak zachowuje się prawdziwy
        układ EPROM: linia /WR jest ignorowana, stan komórki się nie zmienia.

        Zapis do RAM (0x9000–0xFFFF) przechodzi normalnie.
        """
        addr &= 0xFFFF
        if addr >= self.ROM_END:
            self._mem[addr] = value & 0xFF
        # else: pass — ignorujemy zapis do ROM po cichu (zamierzone)

    # ------------------------------------------------------------------
    # Operacje na słowach (16-bit, little-endian — standard Z80)
    # ------------------------------------------------------------------
    def read_word(self, addr: int) -> int:
        """Odczyt słowa 16-bit little-endian."""
        addr &= 0xFFFF
        lo = self._mem[addr]
        hi = self._mem[(addr + 1) & 0xFFFF]
        return (hi << 8) | lo

    def write_word(self, addr: int, word: int) -> None:
        """Zapis słowa 16-bit little-endian z emulacją ochrony ROM."""
        word &= 0xFFFF
        self.write_byte(addr, word & 0xFF)
        self.write_byte(addr + 1, word >> 8)

    def read_sbyte(self, addr: int) -> int:
        """Odczyt bajtu ze znakiem (-128..127) — używany przez instrukcje JR/DJNZ."""
        return _SIGNED_BYTE.unpack(bytes([self._mem[addr & 0xFFFF]]))[0]

    # ------------------------------------------------------------------
    # Narzędzia pomocnicze
    # ------------------------------------------------------------------
    def dump(self, start: int, length: int = 256) -> bytes:
        """Zwraca kopię fragmentu pamięci (do debugowania)."""
        start &= 0xFFFF
        end = min(start + length, 0x10000)
        return bytes(self._mem[start:end])

    @property
    def raw(self) -> bytearray:
        """
        Bezpośredni dostęp do całej pamięci jako bytearray.

        Używaj ostrożnie — zapis do tego obiektu OMIJA ochronę ROM.
        Przydatne do bulk-operacji (np. ładowanie stanu maszyny).
        """
        return self._mem


# ============================================================================
# Warstwa kompatybilności — globalna instancja + funkcje modułowe
# ============================================================================
# Używane przez Z80_core.py, który oczekuje funkcji memory.peekb(addr) itd.
# Po wywołaniu init_memory(...) instancja jest ustawiana, a funkcje poniżej
# delegują do niej.

_INSTANCE: Memory | None = None


def init_memory(monitor_path: str | Path = "CA80.BIN",
                c930_path:    str | Path = "C930.BIN",
                c800_path:    str | Path = "C800.BIN",
                *,
                strict: bool = False) -> Memory:
    """
    Inicjalizuje globalną instancję Memory i zwraca ją.

    Wywoływane przez ca80.py przy starcie emulatora. Po tym wywołaniu
    funkcje peekb/pokeb/peekw/pokew/peeksb działają na załadowanej pamięci.
    """
    global _INSTANCE
    _INSTANCE = Memory(monitor_path, c930_path, c800_path, strict=strict)
    return _INSTANCE


def get_instance() -> Memory:
    """Zwraca aktualną instancję Memory. Rzuca RuntimeError jeśli nieinitem."""
    if _INSTANCE is None:
        raise RuntimeError("Pamięć nie została zainicjalizowana — "
                           "wywołaj init_memory() przed użyciem.")
    return _INSTANCE


def peekb(addr: int) -> int:
    """Odczyt bajtu (kompat z Z80_core)."""
    return _INSTANCE._mem[addr & 0xFFFF]


def pokeb(addr: int, byte: int) -> None:
    """Zapis bajtu z ochroną ROM (kompat z Z80_core)."""
    addr &= 0xFFFF
    if addr >= Memory.ROM_END:
        _INSTANCE._mem[addr] = byte & 0xFF


def peekw(addr: int) -> int:
    """Odczyt słowa 16-bit LE (kompat z Z80_core)."""
    addr &= 0xFFFF
    mem = _INSTANCE._mem
    return (mem[(addr + 1) & 0xFFFF] << 8) | mem[addr]


def pokew(addr: int, word: int) -> None:
    """Zapis słowa 16-bit LE z ochroną ROM (kompat z Z80_core)."""
    word &= 0xFFFF
    pokeb(addr, word & 0xFF)
    pokeb((addr + 1) & 0xFFFF, word >> 8)


def peeksb(addr: int) -> int:
    """Odczyt bajtu ze znakiem (kompat z Z80_core)."""
    return _SIGNED_BYTE.unpack(bytes([_INSTANCE._mem[addr & 0xFFFF]]))[0]
