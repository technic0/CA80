# -*- coding: utf-8 -*-
"""
memory.py (zmodyfikowany dla CA80)
Moduł obsługi pamięci dla Z80.py, dostosowany do mapy CA80.
"""
import struct
import sys

# Zmienne globalne ustawiane przez główny moduł emulatora
RAM = None        # bytearray fizycznego RAMu (2KB lub 8KB)
RAM_MASK = 0x07FF # Maska adresowa dla mirrorowania RAMu (domyślnie 2KB-1)
ROM_LOW = None    # bytes ROMu podstawowego (8KB)
ROM_U10 = None    # bytes ROMu rozszerzenia U10 (do 16KB) @ 4000-7FFF lub None
ROM_HI = None     # bytes ROMu rozszerzonego U11 (16KB) @ 8000-BFFF lub None

# Tablica uprawnień zapisu dla bloków 16KB (0000, 4000, 8000, C000)
# 0x0000 - ROM LOW -> False
# 0x4000 - Puste -> False (brak zapisu)
# 0x8000 - ROM HI -> False (jeśli istnieje)
# 0xC000 - RAM -> True
MEM_RW = [False, False, False, True]

# Obiekty struct do szybkiego pakowania/rozpakowywania słów
wstruct = struct.Struct('<H')
signedbyte = struct.Struct('<b')

def init_memory(low_rom_data: bytes, ram_bytearray: bytearray,
                 hi_rom_data: bytes | None, u10_rom_data: bytes | None = None):
    """Inicjalizuje moduł pamięci danymi emulatora."""
    global ROM_LOW, RAM, RAM_MASK, ROM_U10, ROM_HI, MEM_RW
    if len(low_rom_data) != 0x2000: raise ValueError("Low ROM musi mieć 8KB")
    ram_len = len(ram_bytearray)
    if ram_len not in (0x800, 0x2000):
        raise ValueError("Physical RAM musi mieć 2KB (6116) lub 8KB (6264)")

    ROM_LOW = low_rom_data
    RAM = ram_bytearray
    RAM_MASK = ram_len - 1  # 0x07FF dla 2KB, 0x1FFF dla 8KB

    # Gniazdo U10: EPROM rozszerzenia @ 4000-7FFF (Read-Only)
    if u10_rom_data:
        if len(u10_rom_data) > 0x4000:
            raise ValueError("U10 ROM nie może przekraczać 16KB")
        ROM_U10 = u10_rom_data
        MEM_RW[1] = False  # Blok 0x4000 jest ROMem (tylko do odczytu)
        print(f"[INFO memory.py] U10 ROM załadowany: {len(u10_rom_data)} bajtów @ 0x4000-0x{0x4000+len(u10_rom_data)-1:04X}")
    else:
        ROM_U10 = None
        MEM_RW[1] = False  # Blok 0x4000 pusty (brak zapisu)

    # Gniazdo U11: HiROM @ 8000-BFFF (Read-Only)
    if hi_rom_data:
        if len(hi_rom_data) != 0x4000: raise ValueError("Hi ROM musi mieć 16KB")
        ROM_HI = hi_rom_data
        MEM_RW[2] = False
    else:
        ROM_HI = None
        MEM_RW[2] = False

    print(f"[DEBUG memory.py] Pamięć zainicjalizowana. MEM_RW={MEM_RW}")

def pokeb(addr: int, byte: int):
    """Zapisuje bajt pod podanym adresem."""
    global RAM, RAM_MASK
    addr &= 0xFFFF
    byte &= 0xFF

    if addr >= 0xC000: # Zapis do RAM (obszar C000-FFFF)
        physical_addr = addr & RAM_MASK
        if RAM and physical_addr < len(RAM):
            RAM[physical_addr] = byte
        # else: print(f"[WARN memory.py] Próba zapisu do RAM poza zakresem: 0x{addr:04X}", file=sys.stderr)
    # else: print(f"[WARN memory.py] Próba zapisu do ROM/pustego obszaru: 0x{addr:04X}", file=sys.stderr)

def peekb(addr: int) -> int:
    """Odczytuje bajt spod podanego adresu."""
    global ROM_LOW, RAM, ROM_U10, ROM_HI
    addr &= 0xFFFF

    if addr < 0x2000:
        # ROM 8KB bezpośrednio (0000-1FFF)
        return ROM_LOW[addr] if ROM_LOW else 0xFF
    elif addr < 0x4000:
        # 0x2000-0x3FFF: mirror ROM podstawowego
        return ROM_LOW[addr & 0x1FFF] if ROM_LOW else 0xFF
    elif addr < 0x8000:
        # 0x4000-0x7FFF: Gniazdo U10 (EPROM rozszerzenia, np. C800 MONITOR)
        if ROM_U10:
            offset = addr - 0x4000
            if offset < len(ROM_U10):
                return ROM_U10[offset]
        return 0xFF  # Brak ROM U10 lub poza zakresem
    elif addr < 0xC000:
        # 0x8000-0xBFFF: Gniazdo U11 (HiROM opcjonalny)
        if ROM_HI:
            return ROM_HI[addr - 0x8000]
        return 0xFF
    else:
        # 0xC000-0xFFFF: RAM (mirrorowane z fizycznego RAMu)
        physical_addr = addr & RAM_MASK
        if RAM and physical_addr < len(RAM):
            return RAM[physical_addr]
        return 0xFF

def pokew(addr: int, word: int):
    """Zapisuje słowo (16-bit) Little Endian."""
    addr &= 0xFFFF
    word &= 0xFFFF
    pokeb(addr, word & 0xFF)
    pokeb((addr + 1) & 0xFFFF, word >> 8)

def peekw(addr: int) -> int:
    """Odczytuje słowo (16-bit) Little Endian."""
    addr &= 0xFFFF
    low_byte = peekb(addr)
    high_byte = peekb((addr + 1) & 0xFFFF)
    return (high_byte << 8) | low_byte

def peeksb(addr: int) -> int:
    """Odczytuje bajt ze znakiem."""
    addr &= 0xFFFF
    value = peekb(addr)
    return signedbyte.unpack(bytes([value]))[0]