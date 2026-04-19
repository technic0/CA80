# -*- coding: utf-8 -*-
# Zmieniono nazwę z Z80.py na Z80_core.py, aby uniknąć konfliktu importu
import struct
import sys
import ca80_memory as memory
import ca80_ports as ports

show_debug_info = False
tstates = 0 # Zmieniono nazwę z local_tstates
tstatesPerInterrupt = 0

# --- Początek oryginalnego kodu Z80.py ---
# (Cały kod z Twojego pliku Z80.py, z wyjątkiem zakomentowanego import video
#  i video.update() w funkcji interrupt())

def Z80(clockFrequencyInMHz):
    global tstatesPerInterrupt
    # NMI at 500 Hz (every 2ms) for CA80 display/keyboard service
    tstatesPerInterrupt = int((clockFrequencyInMHz * 1e6) / 500)
    print(f"[DEBUG Z80_core] tstatesPerInterrupt (NMI 500Hz) = {tstatesPerInterrupt}")


IM0 = 0
IM1 = 1
IM2 = 2

F_C = 0x01
F_N = 0x02
F_PV = 0x04
F_3 = 0x08
F_H = 0x10
F_5 = 0x20
F_Z = 0x40
F_S = 0x80
F_3_16 = F_3 << 8
F_5_16 = F_5 << 8

PF = F_PV
p_ = 0


parity = [False] * 256
for i in range(256):
    p = True
    int_type = i
    while (int_type):
        p = not p
        int_type = int_type & (int_type - 1)
    parity[i] = p


# **Main registers
_AF_b = bytearray(2)
_A_F = memoryview(_AF_b)
_F = _A_F[0:1]
_A = _A_F[1:2]
_AF = _A_F.cast('H')
_fS = False
_fZ = False
_f5 = False
_fH = False
_f3 = False
_fPV = False
_fN = False
_fC = False


def setflags():
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    _fS = (_F[0] & F_S) != 0
    _fZ = (_F[0] & F_Z) != 0
    _f5 = (_F[0] & F_5) != 0
    _fH = (_F[0] & F_H) != 0
    _f3 = (_F[0] & F_3) != 0
    _fPV = (_F[0] & F_PV) != 0
    _fN = (_F[0] & F_N) != 0
    _fC = (_F[0] & F_C) != 0

def getflags():
    global _F
    f = 0
    if _fS: f |= F_S
    if _fZ: f |= F_Z
    if _f5: f |= F_5
    if _fH: f |= F_H
    if _f3: f |= F_3
    if _fPV: f |= F_PV
    if _fN: f |= F_N
    if _fC: f |= F_C
    _F[0] = f

_HL_b = bytearray(2)
_H_L = memoryview(_HL_b)
_L = _H_L[0:1]
_H = _H_L[1:2]
_HL = _H_L.cast('H')

_BC_b = bytearray(2)
_B_C = memoryview(_BC_b)
_C = _B_C[0:1]
_B = _B_C[1:2]
_BC = _B_C.cast('H')

_DE_b = bytearray(2)
_D_E = memoryview(_DE_b)
_E = _D_E[0:1]
_D = _D_E[1:2]
_DE = _D_E.cast('H')


# ** Alternate registers
_AF_b_ = bytearray(2)
_A_F_ = memoryview(_AF_b_)
_F_ = _A_F_[0:1]
_A_ = _A_F_[1:2]
_AF_ = _A_F_.cast('H')

_HL_b_ = bytearray(2)
_H_L_ = memoryview(_HL_b_)
_L_ = _H_L_[0:1]
_H_ = _H_L_[1:2]
_HL_ = _H_L_.cast('H')

_BC_b_ = bytearray(2)
_B_C_ = memoryview(_BC_b_)
_C_ = _B_C_[0:1]
_B_ = _B_C_[1:2]
_BC_ = _B_C_.cast('H')

_DE_b_ = bytearray(2)
_D_E_ = memoryview(_DE_b_)
_E_ = _D_E_[0:1]
_D_ = _D_E_[1:2]
_DE_ = _D_E_.cast('H')


# ** Index registers - ID used as temporary for ix/iy
_IX_b = bytearray(2)
_IXH_IXL = memoryview(_IX_b)
_IXL = _IXH_IXL[0:1]
_IXH = _IXH_IXL[1:2]
_IX = _IXH_IXL.cast('H')

_IY_b = bytearray(2)
_IYH_IYL = memoryview(_IY_b)
_IYL = _IYH_IYL[0:1]
_IYH = _IYH_IYL[1:2]
_IY = _IYH_IYL.cast('H')

_IDH = _H # Początkowo ID wskazuje na HL
_IDL = _L
_ID = _HL


# ** Stack Pointer and Program Counter
_SP_b = bytearray(2)
_SP = memoryview(_SP_b).cast('H')

_PC_b = bytearray(2)
_PC = memoryview(_PC_b).cast('H')


# ** Interrupt and Refresh registers
_I_b = bytearray(2)
_IH_IL = memoryview(_I_b)
_I = _IH_IL[1:2]
#_Ifull = _IH_IL.cast('H') # Nie używane w tym rdzeniu?


# Memory refresh register
_R_b = _IH_IL[0:1]
_R7_b = 0


def _Rget():
    global _R7_b
    return _R_b[0]


def _Rset(r):
    global _R7_b
    _R_b[0] = r & 0xFF # Upewnijmy się, że jest 8-bitowe
    _R7_b = r & 0x80 # Przechowaj bit 7
_R = property(_Rget, _Rset)


def inc_r(r = 1):
    global _R7_b
    _R_b[0] = ((_R_b[0] + r) & 0x7F) | _R7_b # Inkrementuj tylko dolne 7 bitów


# ** Interrupt flip-flops
_IFF1 = False # Domyślnie wyłączone przerwania
_IFF2 = False
_IM = IM0     # Domyślnie tryb 0


# Stack access
def pushw(word):
    global _SP
    _SP[0] = (_SP[0] - 2) & 0xFFFF # Używamy maski zamiast modulo
    memory.pokew(_SP[0], word)


def popw():
    global _SP
    t = memory.peekw(_SP[0])
    _SP[0] = (_SP[0] + 2) & 0xFFFF
    return t


# Call stack
def pushpc():
    pushw(_PC[0])


def poppc():
    _PC[0] = popw()


def nxtpcb():
    global _PC
    t = memory.peekb(_PC[0])
    _PC[0] = (_PC[0] + 1) & 0xFFFF
    return t


def nxtpcsb():
    global _PC, show_debug_info
    t = memory.peeksb(_PC[0])
    _PC[0] = (_PC[0] + 1) & 0xFFFF
    if show_debug_info:
        print(f'signedbyte: {t}, PC: 0x{_PC[0]:4x}')
    return t

# Pomocnicza funkcja do skoków względnych
def addrRel():
    global _PC
    offset = nxtpcsb()
    # Obliczanie adresu docelowego dla JR
    # Adres jest względny do adresu *po* odczytaniu offsetu
    # W Z80.py nxtpcsb() już inkrementuje PC, więc PC wskazuje na następną instrukcję
    return (_PC[0] + offset) & 0xFFFF


def incpcsb(): # JR d
    global _PC
    _PC[0] = addrRel()


def nxtpcw():
    global _PC
    t = memory.peekw(_PC[0])
    _PC[0] = (_PC[0] + 2) & 0xFFFF
    return t


# Reset all registers to power on state
def reset():
    global _R, _IFF1, _IFF2, _IM
    global _fS, _fZ, _f5, _fH, _f3, _fPV, _fN, _fC
    global _A, _F, _B, _C, _D, _E, _H, _L, _I, _R_b, _R7_b
    global _A_, _F_, _B_, _C_, _D_, _E_, _H_, _L_
    global _IX, _IY, _SP, _PC
    global tstates

    _PC[0] = 0x0000
    _SP[0] = 0xFFFF # Tradycyjna wartość startowa, ROM może zmienić
    _AF[0] = 0xFFFF
    _BC[0] = 0xFFFF
    _DE[0] = 0xFFFF
    _HL[0] = 0xFFFF
    _AF_[0] = 0xFFFF
    _BC_[0] = 0xFFFF
    _DE_[0] = 0xFFFF
    _HL_[0] = 0xFFFF
    _IX[0] = 0xFFFF
    _IY[0] = 0xFFFF
    _I[0] = 0x00
    _R = 0x00 # Ustawia _R_b[0] i _R7_b przez property

    _IFF1 = False
    _IFF2 = False
    _IM = IM0
    setflags() # Ustawia flagi pythonowe na podstawie _F[0]
    tstates = 0


def show_registers():
    global show_debug_info
    if show_debug_info:
        print(f'PC: {Z80._PC[0]:04X} SP:{Z80._SP[0]:04X} AF:{Z80._AF[0]:04X} BC:{Z80._BC[0]:04X} DE:{Z80._DE[0]:04X} HL:{Z80._HL[0]:04X} IX:{Z80._IX[0]:04X} IY:{Z80._IY[0]:04X}')
        flag_str = (("S" if Z80._fS else ".") +
                    ("Z" if Z80._fZ else ".") +
                    ("5" if Z80._f5 else ".") +
                    ("H" if Z80._fH else ".") +
                    ("3" if Z80._f3 else ".") +
                    ("P" if Z80._fPV else ".") + # P/V
                    ("N" if Z80._fN else ".") +
                    ("C" if Z80._fC else "."))
        print(f"Flags: {flag_str}  I:{Z80._I[0]:02X} R:{Z80._R:02X} IM:{Z80._IM} IFF1:{int(Z80._IFF1)} IFF2:{int(Z80._IFF2)}")

# Interrupt handlers
def check_interrupt():
    """Sprawdza czy należy wywołać przerwanie 50Hz."""
    global tstates, tstatesPerInterrupt
    if tstates >= tstatesPerInterrupt:
        # print(f'LTS: {tstates} _PC: {_PC[0]:4x}') # DEBUG
        cycles_taken = interruptCPU() # Wywołaj logikę przerwania CPU
        tstates = tstates - tstatesPerInterrupt + cycles_taken # Skoryguj licznik T-States
        return True # Zasygnalizuj, że przerwanie wystąpiło
    return False

def interrupt():
    """Symuluje przerwanie (wywoływane z zewnątrz lub przez check_interrupt)."""
    # Ta wersja jest uproszczona - oryginalna miała obsługę video i klawiatury Spectrum
    # W naszym przypadku tylko wywołujemy logikę CPU
    global local_tstates # Zmienna nieużywana, pozostałość?
    # Hz = 25
    # video_update_time += 1
    # ports.keyboard.do_keys() # Logika klawiatury Spectrum
    # if not (video_update_time % int(50 / Hz)):
    #     video.update() # Zakomentowane wywołanie video
    return interruptCPU()

def interruptCPU():
    global _IM, _IFF1, _IFF2, show_debug_info
    # Jeśli przerwania są wyłączone przez DI lub w trakcie obsługi NMI/INT
    if not _IFF1:
        # if show_debug_info: print('NO interrupt - IFF1 is False')
        return 0 # Nie wykonano cykli przerwania

    # TODO: Dodać obsługę sygnału NMI (jeśli zaimplementowany)

    # Standardowe przerwanie maskowalne (INT)
    # Wymagałoby logiki sprawdzania linii INT i odczytu wektora z magistrali danych
    # Dla uproszczenia zakładamy, że przerwanie (jeśli aktywne) jest typu IM1/IM2
    halted = (_A[0] == 118) # Sprawdź czy CPU było w HALT (118 to kod HALT)

    if _IM == IM0:
        # Tryb IM0 wymaga odczytu instrukcji (np. RST) z magistrali danych
        # TODO: Implementacja odczytu instrukcji dla IM0
        print("[WARN] Z80_core: IM0 interrupt not fully implemented!", file=sys.stderr)
        # Symulujemy RST 38h jak w Spectrum dla uproszczenia
        pushpc()
        _PC[0] = 0x0038
        _IFF1 = False
        _IFF2 = False
        return 13 # Przybliżona liczba cykli dla RST + obsługa

    elif _IM == IM1:
        # Zawsze wykonuje RST 38h
        pushpc()
        _PC[0] = 0x0038
        _IFF1 = False
        _IFF2 = False
        return 13 # Tyle samo cykli co RST

    elif _IM == IM2:
        # I<<8 | 0xFF wskazuje na wpis w tablicy wektorów (FFD0-FFD6 w CA80)
        vector_addr = (_I[0] << 8) | 0xFF
        jump_addr = memory.peekw(vector_addr)
        pushpc()           # najpierw adres powrotu na stos
        _PC[0] = jump_addr # potem skok
        _IFF1 = False
        _IFF2 = False
        return 19

    return 0 # Jeśli żaden tryb nie pasuje


# --- Reszta kodu Z80.py (funkcje pomocnicze, instrukcje, słowniki opcode) ---
# ... (cały długi kod implementacji instrukcji i arytmetyki)...
# ... (ldbc, addhlbc, ..., add_a, sbc_a, inc8, dec8, adc16, add16, sbc16, ...) ...
# ... (cp_a, and_a, or_a, xor_a, bit, rlc, rl, rrc, rr, sla, sra, srl, sls, ...) ...
# ... (res, set, słowniki _cbdict, _eddict, _ixiydict, _idcbdict) ...

# WAŻNE: Skopiuj tutaj CAŁĄ resztę kodu z Twojego oryginalnego pliku Z80.py
# od linii zaraz po implementacji `in_bc()` aż do samego końca pliku.
# Poniżej wklejam tylko fragmenty jako przykład, gdzie szukać.

# Przykładowe funkcje pomocnicze (muszą być w kodzie)
def qdec8(a):
    return (a - 1) & 0xFF

def inc16(a):
    return (a + 1) & 0xFFFF

def dec16(a):
    return (a - 1) & 0xFFFF

def add16(a, b):
    global _f3, _f5, _fC, _fH, _fN # Zaktualizuj flagi H, N, C, 3, 5
    ans = (a + b)
    _fN = False
    _fH = ((a & 0xFFF) + (b & 0xFFF)) > 0xFFF
    _fC = ans > 0xFFFF
    ans &= 0xFFFF
    _f3 = (ans & F_3_16) != 0
    _f5 = (ans & F_5_16) != 0
    return ans

def adc16(a, b):
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    ans = a + b + _fC
    _fH = ((a & 0xFFF) + (b & 0xFFF) + _fC) > 0xFFF
    _fS = (ans & 0x8000) != 0
    _fZ = (ans & 0xFFFF) == 0
    _fPV = (((a ^ b) ^ 0x8000) & ((a ^ ans) & 0x8000)) != 0
    _fC = ans > 0xFFFF
    ans &= 0xFFFF
    _f3 = (ans & F_3_16) != 0
    _f5 = (ans & F_5_16) != 0
    _fN = False
    return ans

def sbc16(a, b):
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    ans = a - b - _fC
    _fH = ((a & 0xFFF) - (b & 0xFFF) - _fC) < 0
    _fS = (ans & 0x8000) != 0
    _fZ = (ans & 0xFFFF) == 0
    _fPV = (((a ^ b) & 0x8000) & ((a ^ ans) & 0x8000)) != 0
    _fC = ans < 0
    ans &= 0xFFFF
    _f3 = (ans & F_3_16) != 0
    _f5 = (ans & F_5_16) != 0
    _fN = True
    return ans

def add_a(val):
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    ans = _A[0] + val
    _fH = ((_A[0] & 0xF) + (val & 0xF)) > 0xF
    _fPV = (((_A[0] ^ val) ^ 0x80) & ((_A[0] ^ ans) & 0x80)) != 0
    _fC = ans > 0xFF
    _A[0] = ans & 0xFF
    _fS = (_A[0] & F_S) != 0
    _fZ = _A[0] == 0
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    _fN = False

def adc_a(val):
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    ans = _A[0] + val + _fC
    _fH = ((_A[0] & 0xF) + (val & 0xF) + _fC) > 0xF
    _fPV = (((_A[0] ^ val) ^ 0x80) & ((_A[0] ^ ans) & 0x80)) != 0
    _fC = ans > 0xFF
    _A[0] = ans & 0xFF
    _fS = (_A[0] & F_S) != 0
    _fZ = _A[0] == 0
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    _fN = False

def sub_a(val):
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    ans = _A[0] - val
    _fH = ((_A[0] & 0xF) - (val & 0xF)) < 0
    _fPV = (((_A[0] ^ val) & 0x80) & ((_A[0] ^ ans) & 0x80)) != 0
    _fC = ans < 0
    _A[0] = ans & 0xFF
    _fS = (_A[0] & F_S) != 0
    _fZ = _A[0] == 0
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    _fN = True

def sbc_a(val):
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    ans = _A[0] - val - _fC
    _fH = ((_A[0] & 0xF) - (val & 0xF) - _fC) < 0
    _fPV = (((_A[0] ^ val) & 0x80) & ((_A[0] ^ ans) & 0x80)) != 0
    _fC = ans < 0
    _A[0] = ans & 0xFF
    _fS = (_A[0] & F_S) != 0
    _fZ = _A[0] == 0
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    _fN = True

def cp_a(val):
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    ans = _A[0] - val
    _fH = ((_A[0] & 0xF) - (val & 0xF)) < 0
    _fC = ans < 0
    ans &= 0xFF
    _fS = (ans & F_S) != 0
    _fZ = ans == 0
    _f3 = (val & F_3) != 0
    _f5 = (val & F_5) != 0
    _fN = True

def and_a(val):
    global _fC, _fH, _fN, _fPV, _fS, _fZ
    _A[0] &= val
    _fS = (_A[0] & F_S) != 0
    _fZ = _A[0] == 0
    _fH = True
    _fPV = parity[_A[0]]
    _fN = False
    _fC = False

def or_a(val):
    global _fC, _fH, _fN, _fPV, _fS, _fZ
    _A[0] |= val
    _fS = (_A[0] & F_S) != 0
    _fZ = _A[0] == 0
    _fH = False
    _fPV = parity[_A[0]]
    _fN = False
    _fC = False

def xor_a(val):
    global _fC, _fH, _fN, _fPV, _fS, _fZ
    _A[0] ^= val
    _fS = (_A[0] & F_S) != 0
    _fZ = _A[0] == 0
    _fH = False
    _fPV = parity[_A[0]]
    _fN = False
    _fC = False

def inc8(val):
    global _f3, _f5, _fH, _fN, _fPV, _fS, _fZ
    ans = (val + 1) & 0xFF
    _fH = (val & 0xF) == 0xF
    _fPV = val == 0x7F
    _fS = (ans & F_S) != 0
    _fZ = ans == 0
    _f3 = (ans & F_3) != 0
    _f5 = (ans & F_5) != 0
    _fN = False
    return ans

def dec8(val):
    global _f3, _f5, _fH, _fN, _fPV, _fS, _fZ
    ans = (val - 1) & 0xFF
    _fH = (val & 0xF) == 0
    _fPV = val == 0x80
    _fS = (ans & F_S) != 0
    _fZ = ans == 0
    _f3 = (ans & F_3) != 0
    _f5 = (ans & F_5) != 0
    _fN = True
    return ans

def rlc(val):
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    _fC = (val & 0x80) != 0
    val = ((val << 1) | (1 if _fC else 0)) & 0xFF
    _fS = (val & F_S) != 0
    _fZ = val == 0
    _fH = False
    _fPV = parity[val]
    _f3 = (val & F_3) != 0
    _f5 = (val & F_5) != 0
    _fN = False
    return val

def rl(val):
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    c = _fC
    _fC = (val & 0x80) != 0
    val = ((val << 1) | (1 if c else 0)) & 0xFF
    _fS = (val & F_S) != 0
    _fZ = val == 0
    _fH = False
    _fPV = parity[val]
    _f3 = (val & F_3) != 0
    _f5 = (val & F_5) != 0
    _fN = False
    return val

def rrc(val):
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    _fC = (val & 1) != 0
    val = ((val >> 1) | (0x80 if _fC else 0)) & 0xFF
    _fS = (val & F_S) != 0
    _fZ = val == 0
    _fH = False
    _fPV = parity[val]
    _f3 = (val & F_3) != 0
    _f5 = (val & F_5) != 0
    _fN = False
    return val

def rr(val):
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    c = _fC
    _fC = (val & 1) != 0
    val = ((val >> 1) | (0x80 if c else 0)) & 0xFF
    _fS = (val & F_S) != 0
    _fZ = val == 0
    _fH = False
    _fPV = parity[val]
    _f3 = (val & F_3) != 0
    _f5 = (val & F_5) != 0
    _fN = False
    return val

def sla(val):
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    _fC = (val & 0x80) != 0
    val = (val << 1) & 0xFF
    _fS = (val & F_S) != 0
    _fZ = val == 0
    _fH = False
    _fPV = parity[val]
    _f3 = (val & F_3) != 0
    _f5 = (val & F_5) != 0
    _fN = False
    return val

def sra(val):
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    _fC = (val & 1) != 0
    val = ((val >> 1) | (val & 0x80)) & 0xFF
    _fS = (val & F_S) != 0
    _fZ = val == 0
    _fH = False
    _fPV = parity[val]
    _f3 = (val & F_3) != 0
    _f5 = (val & F_5) != 0
    _fN = False
    return val

def sls(val):
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    _fC = (val & 0x80) != 0
    val = ((val << 1) | 1) & 0xFF
    _fS = (val & F_S) != 0
    _fZ = val == 0
    _fH = False
    _fPV = parity[val]
    _f3 = (val & F_3) != 0
    _f5 = (val & F_5) != 0
    _fN = False
    return val

def srl(val):
    global _f3, _f5, _fC, _fH, _fN, _fPV, _fS, _fZ
    _fC = (val & 1) != 0
    val >>= 1
    _fS = False
    _fZ = val == 0
    _fH = False
    _fPV = parity[val]
    _f3 = (val & F_3) != 0
    _f5 = (val & F_5) != 0
    _fN = False
    return val

def bit(b, val):
    global _f3, _f5, _fH, _fN, _fPV, _fS, _fZ
    _fZ = (val & (1 << b)) == 0
    _fS = (b == 7) and not _fZ
    _fH = True
    _fN = False
    _fPV = _fZ
    _f3 = (val & F_3) != 0
    _f5 = (val & F_5) != 0

def res(b, val):
    return val & ~(1 << b)

def set(b, val):
    return val | (1 << b)

# --- CB prefix wrappers ---
# Rotate/shift (8 T-states for registers, 15 for (HL))
def rlcb():    global _B; _B[0] = rlc(_B[0]); return 8
def rlcc():    global _C; _C[0] = rlc(_C[0]); return 8
def rlcd():    global _D; _D[0] = rlc(_D[0]); return 8
def rlce():    global _E; _E[0] = rlc(_E[0]); return 8
def rlch():    global _H; _H[0] = rlc(_H[0]); return 8
def rlcl():    global _L; _L[0] = rlc(_L[0]); return 8
def rlc_hl_(): memory.pokeb(_HL[0], rlc(memory.peekb(_HL[0]))); return 15
def rlc_a():   global _A; _A[0] = rlc(_A[0]); return 8

def rrcb():    global _B; _B[0] = rrc(_B[0]); return 8
def rrcc():    global _C; _C[0] = rrc(_C[0]); return 8
def rrcd():    global _D; _D[0] = rrc(_D[0]); return 8
def rrce():    global _E; _E[0] = rrc(_E[0]); return 8
def rrch():    global _H; _H[0] = rrc(_H[0]); return 8
def rrcl():    global _L; _L[0] = rrc(_L[0]); return 8
def rrc_hl_(): memory.pokeb(_HL[0], rrc(memory.peekb(_HL[0]))); return 15
def rrc_a():   global _A; _A[0] = rrc(_A[0]); return 8

def rlb():     global _B; _B[0] = rl(_B[0]); return 8
def rlc_():    global _C; _C[0] = rl(_C[0]); return 8
def rld():     global _D; _D[0] = rl(_D[0]); return 8
def rle():     global _E; _E[0] = rl(_E[0]); return 8
def rlh():     global _H; _H[0] = rl(_H[0]); return 8
def rll():     global _L; _L[0] = rl(_L[0]); return 8
def rl_hl_():  memory.pokeb(_HL[0], rl(memory.peekb(_HL[0]))); return 15
def rl_a():    global _A; _A[0] = rl(_A[0]); return 8

def rrb():     global _B; _B[0] = rr(_B[0]); return 8
def rrc_():    global _C; _C[0] = rr(_C[0]); return 8
def rrd():     global _D; _D[0] = rr(_D[0]); return 8
def rre():     global _E; _E[0] = rr(_E[0]); return 8
def rrh():     global _H; _H[0] = rr(_H[0]); return 8
def rrl():     global _L; _L[0] = rr(_L[0]); return 8
def rr_hl_():  memory.pokeb(_HL[0], rr(memory.peekb(_HL[0]))); return 15
def rr_a():    global _A; _A[0] = rr(_A[0]); return 8

def slab():    global _B; _B[0] = sla(_B[0]); return 8
def slac():    global _C; _C[0] = sla(_C[0]); return 8
def slad():    global _D; _D[0] = sla(_D[0]); return 8
def slae():    global _E; _E[0] = sla(_E[0]); return 8
def slah():    global _H; _H[0] = sla(_H[0]); return 8
def slal():    global _L; _L[0] = sla(_L[0]); return 8
def sla_hl_(): memory.pokeb(_HL[0], sla(memory.peekb(_HL[0]))); return 15
def sla_a():   global _A; _A[0] = sla(_A[0]); return 8

def srab():    global _B; _B[0] = sra(_B[0]); return 8
def srac():    global _C; _C[0] = sra(_C[0]); return 8
def srad():    global _D; _D[0] = sra(_D[0]); return 8
def srae():    global _E; _E[0] = sra(_E[0]); return 8
def srah():    global _H; _H[0] = sra(_H[0]); return 8
def sral():    global _L; _L[0] = sra(_L[0]); return 8
def sra_hl_(): memory.pokeb(_HL[0], sra(memory.peekb(_HL[0]))); return 15
def sra_a():   global _A; _A[0] = sra(_A[0]); return 8

def slsb():    global _B; _B[0] = sls(_B[0]); return 8
def slsc():    global _C; _C[0] = sls(_C[0]); return 8
def slsd():    global _D; _D[0] = sls(_D[0]); return 8
def slse():    global _E; _E[0] = sls(_E[0]); return 8
def slsh():    global _H; _H[0] = sls(_H[0]); return 8
def slsl():    global _L; _L[0] = sls(_L[0]); return 8
def sls_hl_(): memory.pokeb(_HL[0], sls(memory.peekb(_HL[0]))); return 15
def sls_a():   global _A; _A[0] = sls(_A[0]); return 8

def srlb():    global _B; _B[0] = srl(_B[0]); return 8
def srlc():    global _C; _C[0] = srl(_C[0]); return 8
def srld():    global _D; _D[0] = srl(_D[0]); return 8
def srle():    global _E; _E[0] = srl(_E[0]); return 8
def srlh():    global _H; _H[0] = srl(_H[0]); return 8
def srll():    global _L; _L[0] = srl(_L[0]); return 8
def srl_hl_(): memory.pokeb(_HL[0], srl(memory.peekb(_HL[0]))); return 15
def srl_a():   global _A; _A[0] = srl(_A[0]); return 8

# BIT (8 T-states for regs, 12 for (HL))
def bit0b(): bit(0,_B[0]); return 8
def bit0c(): bit(0,_C[0]); return 8
def bit0d(): bit(0,_D[0]); return 8
def bit0e(): bit(0,_E[0]); return 8
def bit0h(): bit(0,_H[0]); return 8
def bit0l(): bit(0,_L[0]); return 8
def bit0_hl_(): bit(0,memory.peekb(_HL[0])); return 12
def bit0a(): bit(0,_A[0]); return 8

def bit1b(): bit(1,_B[0]); return 8
def bit1c(): bit(1,_C[0]); return 8
def bit1d(): bit(1,_D[0]); return 8
def bit1e(): bit(1,_E[0]); return 8
def bit1h(): bit(1,_H[0]); return 8
def bit1l(): bit(1,_L[0]); return 8
def bit1_hl_(): bit(1,memory.peekb(_HL[0])); return 12
def bit1a(): bit(1,_A[0]); return 8

def bit2b(): bit(2,_B[0]); return 8
def bit2c(): bit(2,_C[0]); return 8
def bit2d(): bit(2,_D[0]); return 8
def bit2e(): bit(2,_E[0]); return 8
def bit2h(): bit(2,_H[0]); return 8
def bit2l(): bit(2,_L[0]); return 8
def bit2_hl_(): bit(2,memory.peekb(_HL[0])); return 12
def bit2a(): bit(2,_A[0]); return 8

def bit3b(): bit(3,_B[0]); return 8
def bit3c(): bit(3,_C[0]); return 8
def bit3d(): bit(3,_D[0]); return 8
def bit3e(): bit(3,_E[0]); return 8
def bit3h(): bit(3,_H[0]); return 8
def bit3l(): bit(3,_L[0]); return 8
def bit3_hl_(): bit(3,memory.peekb(_HL[0])); return 12
def bit3a(): bit(3,_A[0]); return 8

def bit4b(): bit(4,_B[0]); return 8
def bit4c(): bit(4,_C[0]); return 8
def bit4d(): bit(4,_D[0]); return 8
def bit4e(): bit(4,_E[0]); return 8
def bit4h(): bit(4,_H[0]); return 8
def bit4l(): bit(4,_L[0]); return 8
def bit4_hl_(): bit(4,memory.peekb(_HL[0])); return 12
def bit4a(): bit(4,_A[0]); return 8

def bit5b(): bit(5,_B[0]); return 8
def bit5c(): bit(5,_C[0]); return 8
def bit5d(): bit(5,_D[0]); return 8
def bit5e(): bit(5,_E[0]); return 8
def bit5h(): bit(5,_H[0]); return 8
def bit5l(): bit(5,_L[0]); return 8
def bit5_hl_(): bit(5,memory.peekb(_HL[0])); return 12
def bit5a(): bit(5,_A[0]); return 8

def bit6b(): bit(6,_B[0]); return 8
def bit6c(): bit(6,_C[0]); return 8
def bit6d(): bit(6,_D[0]); return 8
def bit6e(): bit(6,_E[0]); return 8
def bit6h(): bit(6,_H[0]); return 8
def bit6l(): bit(6,_L[0]); return 8
def bit6_hl_(): bit(6,memory.peekb(_HL[0])); return 12
def bit6a(): bit(6,_A[0]); return 8

def bit7b(): bit(7,_B[0]); return 8
def bit7c(): bit(7,_C[0]); return 8
def bit7d(): bit(7,_D[0]); return 8
def bit7e(): bit(7,_E[0]); return 8
def bit7h(): bit(7,_H[0]); return 8
def bit7l(): bit(7,_L[0]); return 8
def bit7_hl_(): bit(7,memory.peekb(_HL[0])); return 12
def bit7a(): bit(7,_A[0]); return 8

# RES (8 T-states for regs, 15 for (HL))
def res0b():    global _B; _B[0]=res(0,_B[0]); return 8
def res0c():    global _C; _C[0]=res(0,_C[0]); return 8
def res0d():    global _D; _D[0]=res(0,_D[0]); return 8
def res0e():    global _E; _E[0]=res(0,_E[0]); return 8
def res0h():    global _H; _H[0]=res(0,_H[0]); return 8
def res0l():    global _L; _L[0]=res(0,_L[0]); return 8
def res0_hl_(): memory.pokeb(_HL[0],res(0,memory.peekb(_HL[0]))); return 15
def res0a():    global _A; _A[0]=res(0,_A[0]); return 8

def res1b():    global _B; _B[0]=res(1,_B[0]); return 8
def res1c():    global _C; _C[0]=res(1,_C[0]); return 8
def res1d():    global _D; _D[0]=res(1,_D[0]); return 8
def res1e():    global _E; _E[0]=res(1,_E[0]); return 8
def res1h():    global _H; _H[0]=res(1,_H[0]); return 8
def res1l():    global _L; _L[0]=res(1,_L[0]); return 8
def res1_hl_(): memory.pokeb(_HL[0],res(1,memory.peekb(_HL[0]))); return 15
def res1a():    global _A; _A[0]=res(1,_A[0]); return 8

def res2b():    global _B; _B[0]=res(2,_B[0]); return 8
def res2c():    global _C; _C[0]=res(2,_C[0]); return 8
def res2d():    global _D; _D[0]=res(2,_D[0]); return 8
def res2e():    global _E; _E[0]=res(2,_E[0]); return 8
def res2h():    global _H; _H[0]=res(2,_H[0]); return 8
def res2l():    global _L; _L[0]=res(2,_L[0]); return 8
def res2_hl_(): memory.pokeb(_HL[0],res(2,memory.peekb(_HL[0]))); return 15
def res2a():    global _A; _A[0]=res(2,_A[0]); return 8

def res3b():    global _B; _B[0]=res(3,_B[0]); return 8
def res3c():    global _C; _C[0]=res(3,_C[0]); return 8
def res3d():    global _D; _D[0]=res(3,_D[0]); return 8
def res3e():    global _E; _E[0]=res(3,_E[0]); return 8
def res3h():    global _H; _H[0]=res(3,_H[0]); return 8
def res3l():    global _L; _L[0]=res(3,_L[0]); return 8
def res3_hl_(): memory.pokeb(_HL[0],res(3,memory.peekb(_HL[0]))); return 15
def res3a():    global _A; _A[0]=res(3,_A[0]); return 8

def res4b():    global _B; _B[0]=res(4,_B[0]); return 8
def res4c():    global _C; _C[0]=res(4,_C[0]); return 8
def res4d():    global _D; _D[0]=res(4,_D[0]); return 8
def res4e():    global _E; _E[0]=res(4,_E[0]); return 8
def res4h():    global _H; _H[0]=res(4,_H[0]); return 8
def res4l():    global _L; _L[0]=res(4,_L[0]); return 8
def res4_hl_(): memory.pokeb(_HL[0],res(4,memory.peekb(_HL[0]))); return 15
def res4a():    global _A; _A[0]=res(4,_A[0]); return 8

def res5b():    global _B; _B[0]=res(5,_B[0]); return 8
def res5c():    global _C; _C[0]=res(5,_C[0]); return 8
def res5d():    global _D; _D[0]=res(5,_D[0]); return 8
def res5e():    global _E; _E[0]=res(5,_E[0]); return 8
def res5h():    global _H; _H[0]=res(5,_H[0]); return 8
def res5l():    global _L; _L[0]=res(5,_L[0]); return 8
def res5_hl_(): memory.pokeb(_HL[0],res(5,memory.peekb(_HL[0]))); return 15
def res5a():    global _A; _A[0]=res(5,_A[0]); return 8

def res6b():    global _B; _B[0]=res(6,_B[0]); return 8
def res6c():    global _C; _C[0]=res(6,_C[0]); return 8
def res6d():    global _D; _D[0]=res(6,_D[0]); return 8
def res6e():    global _E; _E[0]=res(6,_E[0]); return 8
def res6h():    global _H; _H[0]=res(6,_H[0]); return 8
def res6l():    global _L; _L[0]=res(6,_L[0]); return 8
def res6_hl_(): memory.pokeb(_HL[0],res(6,memory.peekb(_HL[0]))); return 15
def res6a():    global _A; _A[0]=res(6,_A[0]); return 8

def res7b():    global _B; _B[0]=res(7,_B[0]); return 8
def res7c():    global _C; _C[0]=res(7,_C[0]); return 8
def res7d():    global _D; _D[0]=res(7,_D[0]); return 8
def res7e():    global _E; _E[0]=res(7,_E[0]); return 8
def res7h():    global _H; _H[0]=res(7,_H[0]); return 8
def res7l():    global _L; _L[0]=res(7,_L[0]); return 8
def res7_hl_(): memory.pokeb(_HL[0],res(7,memory.peekb(_HL[0]))); return 15
def res7a():    global _A; _A[0]=res(7,_A[0]); return 8

# SET (8 T-states for regs, 15 for (HL))
def set0b():    global _B; _B[0]=set(0,_B[0]); return 8
def set0c():    global _C; _C[0]=set(0,_C[0]); return 8
def set0d():    global _D; _D[0]=set(0,_D[0]); return 8
def set0e():    global _E; _E[0]=set(0,_E[0]); return 8
def set0h():    global _H; _H[0]=set(0,_H[0]); return 8
def set0l():    global _L; _L[0]=set(0,_L[0]); return 8
def set0_hl_(): memory.pokeb(_HL[0],set(0,memory.peekb(_HL[0]))); return 15
def set0a():    global _A; _A[0]=set(0,_A[0]); return 8

def set1b():    global _B; _B[0]=set(1,_B[0]); return 8
def set1c():    global _C; _C[0]=set(1,_C[0]); return 8
def set1d():    global _D; _D[0]=set(1,_D[0]); return 8
def set1e():    global _E; _E[0]=set(1,_E[0]); return 8
def set1h():    global _H; _H[0]=set(1,_H[0]); return 8
def set1l():    global _L; _L[0]=set(1,_L[0]); return 8
def set1_hl_(): memory.pokeb(_HL[0],set(1,memory.peekb(_HL[0]))); return 15
def set1a():    global _A; _A[0]=set(1,_A[0]); return 8

def set2b():    global _B; _B[0]=set(2,_B[0]); return 8
def set2c():    global _C; _C[0]=set(2,_C[0]); return 8
def set2d():    global _D; _D[0]=set(2,_D[0]); return 8
def set2e():    global _E; _E[0]=set(2,_E[0]); return 8
def set2h():    global _H; _H[0]=set(2,_H[0]); return 8
def set2l():    global _L; _L[0]=set(2,_L[0]); return 8
def set2_hl_(): memory.pokeb(_HL[0],set(2,memory.peekb(_HL[0]))); return 15
def set2a():    global _A; _A[0]=set(2,_A[0]); return 8

def set3b():    global _B; _B[0]=set(3,_B[0]); return 8
def set3c():    global _C; _C[0]=set(3,_C[0]); return 8
def set3d():    global _D; _D[0]=set(3,_D[0]); return 8
def set3e():    global _E; _E[0]=set(3,_E[0]); return 8
def set3h():    global _H; _H[0]=set(3,_H[0]); return 8
def set3l():    global _L; _L[0]=set(3,_L[0]); return 8
def set3_hl_(): memory.pokeb(_HL[0],set(3,memory.peekb(_HL[0]))); return 15
def set3a():    global _A; _A[0]=set(3,_A[0]); return 8

def set4b():    global _B; _B[0]=set(4,_B[0]); return 8
def set4c():    global _C; _C[0]=set(4,_C[0]); return 8
def set4d():    global _D; _D[0]=set(4,_D[0]); return 8
def set4e():    global _E; _E[0]=set(4,_E[0]); return 8
def set4h():    global _H; _H[0]=set(4,_H[0]); return 8
def set4l():    global _L; _L[0]=set(4,_L[0]); return 8
def set4_hl_(): memory.pokeb(_HL[0],set(4,memory.peekb(_HL[0]))); return 15
def set4a():    global _A; _A[0]=set(4,_A[0]); return 8

def set5b():    global _B; _B[0]=set(5,_B[0]); return 8
def set5c():    global _C; _C[0]=set(5,_C[0]); return 8
def set5d():    global _D; _D[0]=set(5,_D[0]); return 8
def set5e():    global _E; _E[0]=set(5,_E[0]); return 8
def set5h():    global _H; _H[0]=set(5,_H[0]); return 8
def set5l():    global _L; _L[0]=set(5,_L[0]); return 8
def set5_hl_(): memory.pokeb(_HL[0],set(5,memory.peekb(_HL[0]))); return 15
def set5a():    global _A; _A[0]=set(5,_A[0]); return 8

def set6b():    global _B; _B[0]=set(6,_B[0]); return 8
def set6c():    global _C; _C[0]=set(6,_C[0]); return 8
def set6d():    global _D; _D[0]=set(6,_D[0]); return 8
def set6e():    global _E; _E[0]=set(6,_E[0]); return 8
def set6h():    global _H; _H[0]=set(6,_H[0]); return 8
def set6l():    global _L; _L[0]=set(6,_L[0]); return 8
def set6_hl_(): memory.pokeb(_HL[0],set(6,memory.peekb(_HL[0]))); return 15
def set6a():    global _A; _A[0]=set(6,_A[0]); return 8

def set7b():    global _B; _B[0]=set(7,_B[0]); return 8
def set7c():    global _C; _C[0]=set(7,_C[0]); return 8
def set7d():    global _D; _D[0]=set(7,_D[0]); return 8
def set7e():    global _E; _E[0]=set(7,_E[0]); return 8
def set7h():    global _H; _H[0]=set(7,_H[0]); return 8
def set7l():    global _L; _L[0]=set(7,_L[0]); return 8
def set7_hl_(): memory.pokeb(_HL[0],set(7,memory.peekb(_HL[0]))); return 15
def set7a():    global _A; _A[0]=set(7,_A[0]); return 8

_cbdict = {
    0x00: rlcb, 0x01: rlcc, 0x02: rlcd, 0x03: rlce, 0x04: rlch, 0x05: rlcl, 0x06: rlc_hl_, 0x07: rlc_a,
    0x08: rrcb, 0x09: rrcc, 0x0A: rrcd, 0x0B: rrce, 0x0C: rrch, 0x0D: rrcl, 0x0E: rrc_hl_, 0x0F: rrc_a,
    0x10: rlb, 0x11: rlc_, 0x12: rld, 0x13: rle, 0x14: rlh, 0x15: rll, 0x16: rl_hl_, 0x17: rl_a,
    0x18: rrb, 0x19: rrc_, 0x1A: rrd, 0x1B: rre, 0x1C: rrh, 0x1D: rrl, 0x1E: rr_hl_, 0x1F: rr_a,
    0x20: slab, 0x21: slac, 0x22: slad, 0x23: slae, 0x24: slah, 0x25: slal, 0x26: sla_hl_, 0x27: sla_a,
    0x28: srab, 0x29: srac, 0x2A: srad, 0x2B: srae, 0x2C: srah, 0x2D: sral, 0x2E: sra_hl_, 0x2F: sra_a,
    0x30: slsb, 0x31: slsc, 0x32: slsd, 0x33: slse, 0x34: slsh, 0x35: slsl, 0x36: sls_hl_, 0x37: sls_a,
    0x38: srlb, 0x39: srlc, 0x3A: srld, 0x3B: srle, 0x3C: srlh, 0x3D: srll, 0x3E: srl_hl_, 0x3F: srl_a,
    0x40: bit0b, 0x41: bit0c, 0x42: bit0d, 0x43: bit0e, 0x44: bit0h, 0x45: bit0l, 0x46: bit0_hl_, 0x47: bit0a,
    0x48: bit1b, 0x49: bit1c, 0x4A: bit1d, 0x4B: bit1e, 0x4C: bit1h, 0x4D: bit1l, 0x4E: bit1_hl_, 0x4F: bit1a,
    0x50: bit2b, 0x51: bit2c, 0x52: bit2d, 0x53: bit2e, 0x54: bit2h, 0x55: bit2l, 0x56: bit2_hl_, 0x57: bit2a,
    0x58: bit3b, 0x59: bit3c, 0x5A: bit3d, 0x5B: bit3e, 0x5C: bit3h, 0x5D: bit3l, 0x5E: bit3_hl_, 0x5F: bit3a,
    0x60: bit4b, 0x61: bit4c, 0x62: bit4d, 0x63: bit4e, 0x64: bit4h, 0x65: bit4l, 0x66: bit4_hl_, 0x67: bit4a,
    0x68: bit5b, 0x69: bit5c, 0x6A: bit5d, 0x6B: bit5e, 0x6C: bit5h, 0x6D: bit5l, 0x6E: bit5_hl_, 0x6F: bit5a,
    0x70: bit6b, 0x71: bit6c, 0x72: bit6d, 0x73: bit6e, 0x74: bit6h, 0x75: bit6l, 0x76: bit6_hl_, 0x77: bit6a,
    0x78: bit7b, 0x79: bit7c, 0x7A: bit7d, 0x7B: bit7e, 0x7C: bit7h, 0x7D: bit7l, 0x7E: bit7_hl_, 0x7F: bit7a,
    0x80: res0b, 0x81: res0c, 0x82: res0d, 0x83: res0e, 0x84: res0h, 0x85: res0l, 0x86: res0_hl_, 0x87: res0a,
    0x88: res1b, 0x89: res1c, 0x8A: res1d, 0x8B: res1e, 0x8C: res1h, 0x8D: res1l, 0x8E: res1_hl_, 0x8F: res1a,
    0x90: res2b, 0x91: res2c, 0x92: res2d, 0x93: res2e, 0x94: res2h, 0x95: res2l, 0x96: res2_hl_, 0x97: res2a,
    0x98: res3b, 0x99: res3c, 0x9A: res3d, 0x9B: res3e, 0x9C: res3h, 0x9D: res3l, 0x9E: res3_hl_, 0x9F: res3a,
    0xA0: res4b, 0xA1: res4c, 0xA2: res4d, 0xA3: res4e, 0xA4: res4h, 0xA5: res4l, 0xA6: res4_hl_, 0xA7: res4a,
    0xA8: res5b, 0xA9: res5c, 0xAA: res5d, 0xAB: res5e, 0xAC: res5h, 0xAD: res5l, 0xAE: res5_hl_, 0xAF: res5a,
    0xB0: res6b, 0xB1: res6c, 0xB2: res6d, 0xB3: res6e, 0xB4: res6h, 0xB5: res6l, 0xB6: res6_hl_, 0xB7: res6a,
    0xB8: res7b, 0xB9: res7c, 0xBA: res7d, 0xBB: res7e, 0xBC: res7h, 0xBD: res7l, 0xBE: res7_hl_, 0xBF: res7a,
    0xC0: set0b, 0xC1: set0c, 0xC2: set0d, 0xC3: set0e, 0xC4: set0h, 0xC5: set0l, 0xC6: set0_hl_, 0xC7: set0a,
    0xC8: set1b, 0xC9: set1c, 0xCA: set1d, 0xCB: set1e, 0xCC: set1h, 0xCD: set1l, 0xCE: set1_hl_, 0xCF: set1a,
    0xD0: set2b, 0xD1: set2c, 0xD2: set2d, 0xD3: set2e, 0xD4: set2h, 0xD5: set2l, 0xD6: set2_hl_, 0xD7: set2a,
    0xD8: set3b, 0xD9: set3c, 0xDA: set3d, 0xDB: set3e, 0xDC: set3h, 0xDD: set3l, 0xDE: set3_hl_, 0xDF: set3a,
    0xE0: set4b, 0xE1: set4c, 0xE2: set4d, 0xE3: set4e, 0xE4: set4h, 0xE5: set4l, 0xE6: set4_hl_, 0xE7: set4a,
    0xE8: set5b, 0xE9: set5c, 0xEA: set5d, 0xEB: set5e, 0xEC: set5h, 0xED: set5l, 0xEE: set5_hl_, 0xEF: set5a,
    0xF0: set6b, 0xF1: set6c, 0xF2: set6d, 0xF3: set6e, 0xF4: set6h, 0xF5: set6l, 0xF6: set6_hl_, 0xF7: set6a,
    0xF8: set7b, 0xF9: set7c, 0xFA: set7d, 0xFB: set7e, 0xFC: set7h, 0xFD: set7l, 0xFE: set7_hl_, 0xFF: set7a,
}

# ED opcodes
def inb_c(): # 0x40
    global _f3, _f5, _fH, _fN, _fPV, _fS, _fZ
    _B[0] = ports.port_in(_C[0])
    _fS = (_B[0] & F_S) != 0
    _fZ = _B[0] == 0
    _fH = False
    _fPV = parity[_B[0]]
    _fN = False
    _f3 = (_B[0] & F_3) != 0
    _f5 = (_B[0] & F_5) != 0
    return 12

def outc_b(): # 0x41
    ports.port_out(_C[0], _B[0])
    return 12

def sbc_hl_bc(): # 0x42
    global _HL
    _HL[0] = sbc16(_HL[0], _BC[0])
    return 15

def ld_nn_bc(): # 0x43
    memory.pokew(nxtpcw(), _BC[0])
    return 20

def neg(): # 0x44
    global _A
    t = _A[0]
    _A[0] = 0
    sub_a(t)
    return 8

def retn(): # 0x45
    global _IFF1, _IFF2
    _IFF1 = _IFF2
    poppc()
    return 14

def im0(): # 0x46
    global _IM
    _IM = IM0
    return 8

def ld_i_a(): # 0x47
    _I[0] = _A[0]
    return 9

def inc_c(): # 0x48
    global _f3, _f5, _fH, _fN, _fPV, _fS, _fZ
    _C[0] = ports.port_in(_C[0])
    _fS = (_C[0] & F_S) != 0
    _fZ = _C[0] == 0
    _fH = False
    _fPV = parity[_C[0]]
    _fN = False
    _f3 = (_C[0] & F_3) != 0
    _f5 = (_C[0] & F_5) != 0
    return 12

def outc_c(): # 0x49
    ports.port_out(_C[0], _C[0])
    return 12

def adc_hl_bc(): # 0x4A
    global _HL
    _HL[0] = adc16(_HL[0], _BC[0])
    return 15

def ld_bc_nn(): # 0x4B
    _BC[0] = memory.peekw(nxtpcw())
    return 20

def reti(): # 0x4D
    poppc()
    return 14

def ld_r_a(): # 0x4F
    global _R
    _R = _A[0]
    return 9

def ind_c(): # 0x50
    global _f3, _f5, _fH, _fN, _fPV, _fS, _fZ
    _D[0] = ports.port_in(_C[0])
    _fS = (_D[0] & F_S) != 0
    _fZ = _D[0] == 0
    _fH = False
    _fPV = parity[_D[0]]
    _fN = False
    _f3 = (_D[0] & F_3) != 0
    _f5 = (_D[0] & F_5) != 0
    return 12

def outc_d(): # 0x51
    ports.port_out(_C[0], _D[0])
    return 12

def sbc_hl_de(): # 0x52
    global _HL
    _HL[0] = sbc16(_HL[0], _DE[0])
    return 15

def ld_nn_de(): # 0x53
    memory.pokew(nxtpcw(), _DE[0])
    return 20

def im1(): # 0x56
    global _IM
    _IM = IM1
    return 8

def ld_a_i(): # 0x57
    global _f3, _f5, _fH, _fN, _fPV, _fS, _fZ
    _A[0] = _I[0]
    _fS = (_A[0] & F_S) != 0
    _fZ = _A[0] == 0
    _fH = False
    _fPV = _IFF2
    _fN = False
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    return 9

def ine_c(): # 0x58
    global _f3, _f5, _fH, _fN, _fPV, _fS, _fZ
    _E[0] = ports.port_in(_C[0])
    _fS = (_E[0] & F_S) != 0
    _fZ = _E[0] == 0
    _fH = False
    _fPV = parity[_E[0]]
    _fN = False
    _f3 = (_E[0] & F_3) != 0
    _f5 = (_E[0] & F_5) != 0
    return 12

def outc_e(): # 0x59
    ports.port_out(_C[0], _E[0])
    return 12

def adc_hl_de(): # 0x5A
    global _HL
    _HL[0] = adc16(_HL[0], _DE[0])
    return 15

def ld_de_nn(): # 0x5B
    _DE[0] = memory.peekw(nxtpcw())
    return 20

def im2(): # 0x5E
    global _IM
    _IM = IM2
    return 8

def ld_a_r(): # 0x5F
    global _f3, _f5, _fH, _fN, _fPV, _fS, _fZ
    _A[0] = _R
    _fS = (_A[0] & F_S) != 0
    _fZ = _A[0] == 0
    _fH = False
    _fPV = _IFF2
    _fN = False
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    return 9

def inh_c(): # 0x60
    global _f3, _f5, _fH, _fN, _fPV, _fS, _fZ
    _H[0] = ports.port_in(_C[0])
    _fS = (_H[0] & F_S) != 0
    _fZ = _H[0] == 0
    _fH = False
    _fPV = parity[_H[0]]
    _fN = False
    _f3 = (_H[0] & F_3) != 0
    _f5 = (_H[0] & F_5) != 0
    return 12

def outc_h(): # 0x61
    ports.port_out(_C[0], _H[0])
    return 12

def sbc_hl_hl(): # 0x62
    global _HL
    _HL[0] = sbc16(_HL[0], _HL[0])
    return 15

def rrd_(): # 0x67
    global _f3, _f5, _fH, _fN, _fPV, _fS, _fZ
    t = memory.peekb(_HL[0])
    memory.pokeb(_HL[0], ((t >> 4) | (_A[0] << 4)) & 0xFF)
    _A[0] = (_A[0] & 0xF0) | (t & 0xF)
    _fS = (_A[0] & F_S) != 0
    _fZ = _A[0] == 0
    _fH = False
    _fPV = parity[_A[0]]
    _fN = False
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    return 18

def inl_c(): # 0x68
    global _f3, _f5, _fH, _fN, _fPV, _fS, _fZ
    _L[0] = ports.port_in(_C[0])
    _fS = (_L[0] & F_S) != 0
    _fZ = _L[0] == 0
    _fH = False
    _fPV = parity[_L[0]]
    _fN = False
    _f3 = (_L[0] & F_3) != 0
    _f5 = (_L[0] & F_5) != 0
    return 12

def outc_l(): # 0x69
    ports.port_out(_C[0], _L[0])
    return 12

def adc_hl_hl(): # 0x6A
    global _HL
    _HL[0] = adc16(_HL[0], _HL[0])
    return 15

def rld_(): # 0x6F
    global _f3, _f5, _fH, _fN, _fPV, _fS, _fZ
    t = memory.peekb(_HL[0])
    memory.pokeb(_HL[0], ((t << 4) | (_A[0] & 0xF)) & 0xFF)
    _A[0] = (_A[0] & 0xF0) | (t >> 4)
    _fS = (_A[0] & F_S) != 0
    _fZ = _A[0] == 0
    _fH = False
    _fPV = parity[_A[0]]
    _fN = False
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    return 18

def inf_c(): # 0x70
    global _f3, _f5, _fH, _fN, _fPV, _fS, _fZ
    t = ports.port_in(_C[0])
    _fS = (t & F_S) != 0
    _fZ = t == 0
    _fH = False
    _fPV = parity[t]
    _fN = False
    _f3 = (t & F_3) != 0
    _f5 = (t & F_5) != 0
    return 12

def outc_0(): # 0x71
    ports.port_out(_C[0], 0)
    return 12

def sbc_hl_sp(): # 0x72
    global _HL
    _HL[0] = sbc16(_HL[0], _SP[0])
    return 15

def ld_nn_sp(): # 0x73
    memory.pokew(nxtpcw(), _SP[0])
    return 20

def ina_c(): # 0x78
    global _f3, _f5, _fH, _fN, _fPV, _fS, _fZ
    _A[0] = ports.port_in(_C[0])
    _fS = (_A[0] & F_S) != 0
    _fZ = _A[0] == 0
    _fH = False
    _fPV = parity[_A[0]]
    _fN = False
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    return 12

def outc_a(): # 0x79
    ports.port_out(_C[0], _A[0])
    return 12

def adc_hl_sp(): # 0x7A
    global _HL
    _HL[0] = adc16(_HL[0], _SP[0])
    return 15

def ld_sp_nn(): # 0x7B
    _SP[0] = memory.peekw(nxtpcw())
    return 20

def ldi(): # 0xA0
    global _f3, _f5, _fH, _fN, _fPV
    t = memory.peekb(_HL[0])
    memory.pokeb(_DE[0], t)
    _fH = False
    _BC[0] = dec16(_BC[0])
    _fPV = _BC[0] != 0
    _DE[0] = inc16(_DE[0])
    _HL[0] = inc16(_HL[0])
    t += _A[0]
    _f5 = (t & F_5) != 0
    _f3 = (t & F_3) != 0
    _fN = False
    return 16

def cpi(): # 0xA1
    global _f3, _f5, _fH, _fN, _fPV, _fZ
    t = memory.peekb(_HL[0])
    _fZ = _A[0] == t
    _fH = ((_A[0] & 0xF) - (t & 0xF)) < 0
    _BC[0] = dec16(_BC[0])
    _fPV = _BC[0] != 0
    _HL[0] = inc16(_HL[0])
    t2 = _A[0] - t - (1 if _fH else 0)
    _f5 = (t2 & F_5) != 0
    _f3 = (t2 & F_3) != 0
    _fN = True
    return 16

def ini(): # 0xA2
    global _fN
    _B[0] = qdec8(_B[0])
    memory.pokeb(_HL[0], ports.port_in(_C[0]))
    _HL[0] = inc16(_HL[0])
    _fN = True
    return 16

def outi(): # 0xA3
    global _fN
    ports.port_out(_C[0], memory.peekb(_HL[0]))
    _B[0] = qdec8(_B[0])
    _HL[0] = inc16(_HL[0])
    _fN = True
    return 16

def ldd_(): # 0xA8
    global _f3, _f5, _fH, _fN, _fPV
    t = memory.peekb(_HL[0])
    memory.pokeb(_DE[0], t)
    _fH = False
    _BC[0] = dec16(_BC[0])
    _fPV = _BC[0] != 0
    _DE[0] = dec16(_DE[0])
    _HL[0] = dec16(_HL[0])
    t += _A[0]
    _f5 = (t & F_5) != 0
    _f3 = (t & F_3) != 0
    _fN = False
    return 16

def cpd(): # 0xA9
    global _f3, _f5, _fH, _fN, _fPV, _fZ
    t = memory.peekb(_HL[0])
    _fZ = _A[0] == t
    _fH = ((_A[0] & 0xF) - (t & 0xF)) < 0
    _BC[0] = dec16(_BC[0])
    _fPV = _BC[0] != 0
    _HL[0] = dec16(_HL[0])
    t2 = _A[0] - t - (1 if _fH else 0)
    _f5 = (t2 & F_5) != 0
    _f3 = (t2 & F_3) != 0
    _fN = True
    return 16

def ind(): # 0xAA
    global _fN
    _B[0] = qdec8(_B[0])
    memory.pokeb(_HL[0], ports.port_in(_C[0]))
    _HL[0] = dec16(_HL[0])
    _fN = True
    return 16

def outd(): # 0xAB
    global _fN
    ports.port_out(_C[0], memory.peekb(_HL[0]))
    _B[0] = qdec8(_B[0])
    _HL[0] = dec16(_HL[0])
    _fN = True
    return 16

def ldir(): # 0xB0
    ldi()
    if _BC[0] != 0:
        _PC[0] -= 2
        return 21
    else:
        return 16

def cpir(): # 0xB1
    cpi()
    if _BC[0] != 0 and not _fZ:
        _PC[0] -= 2
        return 21
    else:
        return 16

def inir(): # 0xB2
    ini()
    if _B[0] != 0:
        _PC[0] -= 2
        return 21
    else:
        return 16

def otir(): # 0xB3
    outi()
    if _B[0] != 0:
        _PC[0] -= 2
        return 21
    else:
        return 16

def lddr(): # 0xB8
    ldd_()
    if _BC[0] != 0:
        _PC[0] -= 2
        return 21
    else:
        return 16

def cpdr(): # 0xB9
    cpd()
    if _BC[0] != 0 and not _fZ:
        _PC[0] -= 2
        return 21
    else:
        return 16

def indr(): # 0xBA
    ind()
    if _B[0] != 0:
        _PC[0] -= 2
        return 21
    else:
        return 16

def otdr(): # 0xBB
    otdr()
    if _B[0] != 0:
        _PC[0] -= 2
        return 21
    else:
        return 16

_eddict = {
    0x40: inb_c, 0x41: outc_b, 0x42: sbc_hl_bc, 0x43: ld_nn_bc, 0x44: neg, 0x45: retn, 0x46: im0, 0x47: ld_i_a,
    0x48: inc_c, 0x49: outc_c, 0x4A: adc_hl_bc, 0x4B: ld_bc_nn, 0x4D: reti, 0x4F: ld_r_a,
    0x50: ind_c, 0x51: outc_d, 0x52: sbc_hl_de, 0x53: ld_nn_de, 0x56: im1, 0x57: ld_a_i,
    0x58: ine_c, 0x59: outc_e, 0x5A: adc_hl_de, 0x5B: ld_de_nn, 0x5E: im2, 0x5F: ld_a_r,
    0x60: inh_c, 0x61: outc_h, 0x62: sbc_hl_hl, 0x67: rrd_,
    0x68: inl_c, 0x69: outc_l, 0x6A: adc_hl_hl, 0x6F: rld_,
    0x70: inf_c, 0x71: outc_0, 0x72: sbc_hl_sp, 0x73: ld_nn_sp,
    0x78: ina_c, 0x79: outc_a, 0x7A: adc_hl_sp, 0x7B: ld_sp_nn,
    0xA0: ldi, 0xA1: cpi, 0xA2: ini, 0xA3: outi,
    0xA8: ldd_, 0xA9: cpd, 0xAA: ind, 0xAB: outd,
    0xB0: ldir, 0xB1: cpir, 0xB2: inir, 0xB3: otir,
    0xB8: lddr, 0xB9: cpdr, 0xBA: indr, 0xBB: otdr,
}

# IX/IY opcodes
def addid_bc(): # 0x09
    global _ID
    _ID[0] = add16(_ID[0], _BC[0])
    return 15

def addid_de(): # 0x19
    global _ID
    _ID[0] = add16(_ID[0], _DE[0])
    return 15

def ldid_nn(): # 0x21
    _ID[0] = nxtpcw()
    return 14

def ld_nn_id(): # 0x22
    memory.pokew(nxtpcw(), _ID[0])
    return 20

def incid(): # 0x23
    _ID[0] = inc16(_ID[0])
    return 10

def incidh(): # 0x24
    _IDH[0] = inc8(_IDH[0])
    return 8

def decidh(): # 0x25
    _IDH[0] = dec8(_IDH[0])
    return 8

def ldidh_n(): # 0x26
    _IDH[0] = nxtpcb()
    return 11

def addid_id(): # 0x29
    global _ID
    _ID[0] = add16(_ID[0], _ID[0])
    return 15

def ld_id_nn(): # 0x2A
    _ID[0] = memory.peekw(nxtpcw())
    return 20

def decid(): # 0x2B
    _ID[0] = dec16(_ID[0])
    return 10

def incidl(): # 0x2C
    _IDL[0] = inc8(_IDL[0])
    return 8

def decidl(): # 0x2D
    _IDL[0] = dec8(_IDL[0])
    return 8

def ldidl_n(): # 0x2E
    _IDL[0] = nxtpcb()
    return 11

def addid_sp(): # 0x39
    global _ID
    _ID[0] = add16(_ID[0], _SP[0])
    return 15

def inc_id_d_(): # 0x34
    addr = _ID[0] + nxtpcsb()
    memory.pokeb(addr, inc8(memory.peekb(addr)))
    return 23

def dec_id_d_(): # 0x35
    addr = _ID[0] + nxtpcsb()
    memory.pokeb(addr, dec8(memory.peekb(addr)))
    return 23

def ld_id_d_n(): # 0x36
    addr = _ID[0] + nxtpcsb()
    memory.pokeb(addr, nxtpcb())
    return 19

def ldb_idh(): # 0x44
    _B[0] = _IDH[0]
    return 8

def ldb_idl(): # 0x45
    _B[0] = _IDL[0]
    return 8

def ldb_id_d_(): # 0x46
    _B[0] = memory.peekb(_ID[0] + nxtpcsb())
    return 19

def ldc_idh(): # 0x4C
    _C[0] = _IDH[0]
    return 8

def ldc_idl(): # 0x4D
    _C[0] = _IDL[0]
    return 8

def ldc_id_d_(): # 0x4E
    _C[0] = memory.peekb(_ID[0] + nxtpcsb())
    return 19

def ldd_idh(): # 0x54
    _D[0] = _IDH[0]
    return 8

def ldd_idl(): # 0x55
    _D[0] = _IDL[0]
    return 8

def ldd_id_d_(): # 0x56
    _D[0] = memory.peekb(_ID[0] + nxtpcsb())
    return 19

def lde_idh(): # 0x5C
    _E[0] = _IDH[0]
    return 8

def lde_idl(): # 0x5D
    _E[0] = _IDL[0]
    return 8

def lde_id_d_(): # 0x5E
    _E[0] = memory.peekb(_ID[0] + nxtpcsb())
    return 19

def ldidh_b(): # 0x60
    _IDH[0] = _B[0]
    return 8

def ldidh_c(): # 0x61
    _IDH[0] = _C[0]
    return 8

def ldidh_d(): # 0x62
    _IDH[0] = _D[0]
    return 8

def ldidh_e(): # 0x63
    _IDH[0] = _E[0]
    return 8

def ldidh_idh(): # 0x64
    return 8

def ldidh_idl(): # 0x65
    _IDH[0] = _IDL[0]
    return 8

def ldh_id_d_(): # 0x66
    _H[0] = memory.peekb(_ID[0] + nxtpcsb())
    return 19

def ldidh_a(): # 0x67
    _IDH[0] = _A[0]
    return 8

def ldidl_b(): # 0x68
    _IDL[0] = _B[0]
    return 8

def ldidl_c(): # 0x69
    _IDL[0] = _C[0]
    return 8

def ldidl_d(): # 0x6A
    _IDL[0] = _D[0]
    return 8

def ldidl_e(): # 0x6B
    _IDL[0] = _E[0]
    return 8

def ldidl_idh(): # 0x6C
    _IDL[0] = _IDH[0]
    return 8

def ldidl_idl(): # 0x6D
    return 8

def ldl_id_d_(): # 0x6E
    _L[0] = memory.peekb(_ID[0] + nxtpcsb())
    return 19

def ldidl_a(): # 0x6F
    _IDL[0] = _A[0]
    return 8

def ld_id_d_b(): # 0x70
    memory.pokeb(_ID[0] + nxtpcsb(), _B[0])
    return 19

def ld_id_d_c(): # 0x71
    memory.pokeb(_ID[0] + nxtpcsb(), _C[0])
    return 19

def ld_id_d_d(): # 0x72
    memory.pokeb(_ID[0] + nxtpcsb(), _D[0])
    return 19

def ld_id_d_e(): # 0x73
    memory.pokeb(_ID[0] + nxtpcsb(), _E[0])
    return 19

def ld_id_d_h(): # 0x74
    memory.pokeb(_ID[0] + nxtpcsb(), _H[0])
    return 19

def ld_id_d_l(): # 0x75
    memory.pokeb(_ID[0] + nxtpcsb(), _L[0])
    return 19

def ld_id_d_a(): # 0x77
    memory.pokeb(_ID[0] + nxtpcsb(), _A[0])
    return 19

def lda_idh(): # 0x7C
    _A[0] = _IDH[0]
    return 8

def lda_idl(): # 0x7D
    _A[0] = _IDL[0]
    return 8

def lda_id_d_(): # 0x7E
    _A[0] = memory.peekb(_ID[0] + nxtpcsb())
    return 19

def adda_idh(): # 0x84
    add_a(_IDH[0])
    return 8

def adda_idl(): # 0x85
    add_a(_IDL[0])
    return 8

def adda_id_d_(): # 0x86
    add_a(memory.peekb(_ID[0] + nxtpcsb()))
    return 19

def adca_idh(): # 0x8C
    adc_a(_IDH[0])
    return 8

def adca_idl(): # 0x8D
    adc_a(_IDL[0])
    return 8

def adca_id_d_(): # 0x8E
    adc_a(memory.peekb(_ID[0] + nxtpcsb()))
    return 19

def suba_idh(): # 0x94
    sub_a(_IDH[0])
    return 8

def suba_idl(): # 0x95
    sub_a(_IDL[0])
    return 8

def suba_id_d_(): # 0x96
    sub_a(memory.peekb(_ID[0] + nxtpcsb()))
    return 19

def sbca_idh(): # 0x9C
    sbc_a(_IDH[0])
    return 8

def sbca_idl(): # 0x9D
    sbc_a(_IDL[0])
    return 8

def sbca_id_d_(): # 0x9E
    sbc_a(memory.peekb(_ID[0] + nxtpcsb()))
    return 19

def anda_idh(): # 0xA4
    and_a(_IDH[0])
    return 8

def anda_idl(): # 0xA5
    and_a(_IDL[0])
    return 8

def anda_id_d_(): # 0xA6
    and_a(memory.peekb(_ID[0] + nxtpcsb()))
    return 19

def xora_idh(): # 0xAC
    xor_a(_IDH[0])
    return 8

def xora_idl(): # 0xAD
    xor_a(_IDL[0])
    return 8

def xora_id_d_(): # 0xAE
    xor_a(memory.peekb(_ID[0] + nxtpcsb()))
    return 19

def ora_idh(): # 0xB4
    or_a(_IDH[0])
    return 8

def ora_idl(): # 0xB5
    or_a(_IDL[0])
    return 8

def ora_id_d_(): # 0xB6
    or_a(memory.peekb(_ID[0] + nxtpcsb()))
    return 19

def cpa_idh(): # 0xBC
    cp_a(_IDH[0])
    return 8

def cpa_idl(): # 0xBD
    cp_a(_IDL[0])
    return 8

def cpa_id_d_(): # 0xBE
    cp_a(memory.peekb(_ID[0] + nxtpcsb()))
    return 19

def popid(): # 0xE1
    _ID[0] = popw()
    return 14

def ex_sp_id_(): # 0xE3
    t = memory.peekw(_SP[0])
    memory.pokew(_SP[0], _ID[0])
    _ID[0] = t
    return 23

def pushid(): # 0xE5
    pushw(_ID[0])
    return 15

def jpid(): # 0xE9
    _PC[0] = _ID[0]
    return 8

def ldspid(): # 0xF9
    _SP[0] = _ID[0]
    return 10

_ixiydict = {
    0x09: addid_bc, 0x19: addid_de, 0x21: ldid_nn, 0x22: ld_nn_id, 0x23: incid, 0x24: incidh, 0x25: decidh, 0x26: ldidh_n,
    0x29: addid_id, 0x2A: ld_id_nn, 0x2B: decid, 0x2C: incidl, 0x2D: decidl, 0x2E: ldidl_n,
    0x34: inc_id_d_, 0x35: dec_id_d_, 0x36: ld_id_d_n, 0x39: addid_sp,
    0x44: ldb_idh, 0x45: ldb_idl, 0x46: ldb_id_d_, 0x4C: ldc_idh, 0x4D: ldc_idl, 0x4E: ldc_id_d_,
    0x54: ldd_idh, 0x55: ldd_idl, 0x56: ldd_id_d_, 0x5C: lde_idh, 0x5D: lde_idl, 0x5E: lde_id_d_,
    0x60: ldidh_b, 0x61: ldidh_c, 0x62: ldidh_d, 0x63: ldidh_e, 0x64: ldidh_idh, 0x65: ldidh_idl, 0x66: ldh_id_d_, 0x67: ldidh_a,
    0x68: ldidl_b, 0x69: ldidl_c, 0x6A: ldidl_d, 0x6B: ldidl_e, 0x6C: ldidl_idh, 0x6D: ldidl_idl, 0x6E: ldl_id_d_, 0x6F: ldidl_a,
    0x70: ld_id_d_b, 0x71: ld_id_d_c, 0x72: ld_id_d_d, 0x73: ld_id_d_e, 0x74: ld_id_d_h, 0x75: ld_id_d_l, 0x77: ld_id_d_a,
    0x7C: lda_idh, 0x7D: lda_idl, 0x7E: lda_id_d_,
    0x84: adda_idh, 0x85: adda_idl, 0x86: adda_id_d_, 0x8C: adca_idh, 0x8D: adca_idl, 0x8E: adca_id_d_,
    0x94: suba_idh, 0x95: suba_idl, 0x96: suba_id_d_, 0x9C: sbca_idh, 0x9D: sbca_idl, 0x9E: sbca_id_d_,
    0xA4: anda_idh, 0xA5: anda_idl, 0xA6: anda_id_d_, 0xAC: xora_idh, 0xAD: xora_idl, 0xAE: xora_id_d_,
    0xB4: ora_idh, 0xB5: ora_idl, 0xB6: ora_id_d_, 0xBC: cpa_idh, 0xBD: cpa_idl, 0xBE: cpa_id_d_,
    0xE1: popid, 0xE3: ex_sp_id_, 0xE5: pushid, 0xE9: jpid, 0xF9: ldspid,
}

# IX/IY CB opcodes
def idcb():
    addr = _ID[0] + nxtpcsb()
    op = nxtpcb()
    if op & 0xC0 == 0x40: # bit
        bit((op >> 3) & 7, memory.peekb(addr))
        return 20
    elif op & 0xC0 == 0x80: # res
        memory.pokeb(addr, res((op >> 3) & 7, memory.peekb(addr)))
        return 23
    elif op & 0xC0 == 0xC0: # set
        memory.pokeb(addr, set((op >> 3) & 7, memory.peekb(addr)))
        return 23
    else: # shift
        memory.pokeb(addr, _idcbdict[op](memory.peekb(addr)))
        return 23

def rlc_id_d_():
    return rlc(p_)

def rrc_id_d_():
    return rrc(p_)

def rl_id_d_():
    return rl(p_)

def rr_id_d_():
    return rr(p_)

def sla_id_d_():
    return sla(p_)

def sra_id_d_():
    return sra(p_)

def sls_id_d_():
    return sls(p_)

def srl_id_d_():
    return srl(p_)

_idcbdict = {
    0x06: rlc_id_d_, 0x0E: rrc_id_d_, 0x16: rl_id_d_, 0x1E: rr_id_d_,
    0x26: sla_id_d_, 0x2E: sra_id_d_, 0x36: sls_id_d_, 0x3E: srl_id_d_,
}

def nop(): # 0x00
    return 4

def ldbc_nn(): # 0x01
    _BC[0] = nxtpcw()
    return 10

def ldbc_a(): # 0x02
    memory.pokeb(_BC[0], _A[0])
    return 7

def incbc(): # 0x03
    _BC[0] = inc16(_BC[0])
    return 6

def incb(): # 0x04
    _B[0] = inc8(_B[0])
    return 4

def decb(): # 0x05
    _B[0] = dec8(_B[0])
    return 4

def ldb_n(): # 0x06
    _B[0] = nxtpcb()
    return 7

def rlca(): # 0x07
    global _f3, _f5, _fC, _fH, _fN
    _fC = (_A[0] & 0x80) != 0
    _A[0] = ((_A[0] << 1) | (1 if _fC else 0)) & 0xFF
    _fH = False
    _fN = False
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    return 4

def exafaf_(): # 0x08
    global _AF, _AF_
    getflags()
    _AF[0], _AF_[0] = _AF_[0], _AF[0]
    setflags()
    return 4

def addhlbc(): # 0x09
    global _HL
    _HL[0] = add16(_HL[0], _BC[0])
    return 11

def ldab_c(): # 0x0A
    _A[0] = memory.peekb(_BC[0])
    return 7

def decbc(): # 0x0B
    _BC[0] = dec16(_BC[0])
    return 6

def incc(): # 0x0C
    _C[0] = inc8(_C[0])
    return 4

def decc(): # 0x0D
    _C[0] = dec8(_C[0])
    return 4

def ldc_n(): # 0x0E
    _C[0] = nxtpcb()
    return 7

def rrca(): # 0x0F
    global _f3, _f5, _fC, _fH, _fN
    _fC = (_A[0] & 1) != 0
    _A[0] = ((_A[0] >> 1) | (0x80 if _fC else 0)) & 0xFF
    _fH = False
    _fN = False
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    return 4

def djnz(): # 0x10
    _B[0] = qdec8(_B[0])
    if _B[0] != 0:
        incpcsb()
        return 13
    else:
        _PC[0] += 1
        return 8

def ldde_nn(): # 0x11
    _DE[0] = nxtpcw()
    return 10

def ldde_a(): # 0x12
    memory.pokeb(_DE[0], _A[0])
    return 7

def incde(): # 0x13
    _DE[0] = inc16(_DE[0])
    return 6

def incd(): # 0x14
    _D[0] = inc8(_D[0])
    return 4

def decd(): # 0x15
    _D[0] = dec8(_D[0])
    return 4

def ldd_n(): # 0x16
    _D[0] = nxtpcb()
    return 7

def rla(): # 0x17
    global _f3, _f5, _fC, _fH, _fN
    c = _fC
    _fC = (_A[0] & 0x80) != 0
    _A[0] = ((_A[0] << 1) | (1 if c else 0)) & 0xFF
    _fH = False
    _fN = False
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    return 4

def jr(): # 0x18
    incpcsb()
    return 12

def addhlde(): # 0x19
    global _HL
    _HL[0] = add16(_HL[0], _DE[0])
    return 11

def ldade_(): # 0x1A
    _A[0] = memory.peekb(_DE[0])
    return 7

def decde(): # 0x1B
    _DE[0] = dec16(_DE[0])
    return 6

def ince(): # 0x1C
    _E[0] = inc8(_E[0])
    return 4

def dece(): # 0x1D
    _E[0] = dec8(_E[0])
    return 4

def lde_n(): # 0x1E
    _E[0] = nxtpcb()
    return 7

def rra(): # 0x1F
    global _f3, _f5, _fC, _fH, _fN
    c = _fC
    _fC = (_A[0] & 1) != 0
    _A[0] = ((_A[0] >> 1) | (0x80 if c else 0)) & 0xFF
    _fH = False
    _fN = False
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    return 4

def jrnz(): # 0x20
    if not _fZ:
        incpcsb()
        return 12
    else:
        _PC[0] += 1
        return 7

def ldhl_nn(): # 0x21
    _HL[0] = nxtpcw()
    return 10

def ld_nn_hl(): # 0x22
    memory.pokew(nxtpcw(), _HL[0])
    return 16

def inchl(): # 0x23
    _HL[0] = inc16(_HL[0])
    return 6

def inch(): # 0x24
    _H[0] = inc8(_H[0])
    return 4

def dech(): # 0x25
    _H[0] = dec8(_H[0])
    return 4

def ldh_n(): # 0x26
    _H[0] = nxtpcb()
    return 7

def daa(): # 0x27
    global _f3, _f5, _fC, _fH, _fPV, _fS, _fZ
    a = _A[0]
    c_in = _fC
    if _fN:
        if _fH or (a & 0xF) > 9:
            a -= 6
        if c_in or _A[0] > 0x99:
            a -= 0x60
    else:
        if _fH or (a & 0xF) > 9:
            a += 6
        if c_in or _A[0] > 0x99:
            a += 0x60
    _fC = c_in or (_A[0] > 0x99)
    _fH = ((_A[0] ^ a) & 0x10) != 0
    _A[0] = a & 0xFF
    _fS = (_A[0] & F_S) != 0
    _fZ = _A[0] == 0
    _fPV = parity[_A[0]]
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    # _fN jest zachowany (DAA nie zmienia flagi N)
    return 4

def jrz(): # 0x28
    if _fZ:
        incpcsb()
        return 12
    else:
        _PC[0] += 1
        return 7

def addhlhl(): # 0x29
    global _HL
    _HL[0] = add16(_HL[0], _HL[0])
    return 11

def ldhl_nn_(): # 0x2A
    _HL[0] = memory.peekw(nxtpcw())
    return 16

def dechl(): # 0x2B
    _HL[0] = dec16(_HL[0])
    return 6

def incl(): # 0x2C
    _L[0] = inc8(_L[0])
    return 4

def decl(): # 0x2D
    _L[0] = dec8(_L[0])
    return 4

def ldl_n(): # 0x2E
    _L[0] = nxtpcb()
    return 7

def cpl(): # 0x2F
    global _f3, _f5, _fH, _fN
    _A[0] ^= 0xFF
    _fH = True
    _fN = True
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    return 4

def jrnc(): # 0x30
    if not _fC:
        incpcsb()
        return 12
    else:
        _PC[0] += 1
        return 7

def ldsp_nn(): # 0x31
    _SP[0] = nxtpcw()
    return 10

def ld_nn_a(): # 0x32
    memory.pokeb(nxtpcw(), _A[0])
    return 13

def incsp(): # 0x33
    _SP[0] = inc16(_SP[0])
    return 6

def inc_hl_(): # 0x34
    memory.pokeb(_HL[0], inc8(memory.peekb(_HL[0])))
    return 11

def dec_hl_(): # 0x35
    memory.pokeb(_HL[0], dec8(memory.peekb(_HL[0])))
    return 11

def ld_hl_n(): # 0x36
    memory.pokeb(_HL[0], nxtpcb())
    return 10

def scf(): # 0x37
    global _f3, _f5, _fC, _fH, _fN
    _fC = True
    _fH = False
    _fN = False
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    return 4

def jrc(): # 0x38
    if _fC:
        incpcsb()
        return 12
    else:
        _PC[0] += 1
        return 7

def addhlsp(): # 0x39
    global _HL
    _HL[0] = add16(_HL[0], _SP[0])
    return 11

def lda_nn_(): # 0x3A
    _A[0] = memory.peekb(nxtpcw())
    return 13

def decsp(): # 0x3B
    _SP[0] = dec16(_SP[0])
    return 6

def inca(): # 0x3C
    _A[0] = inc8(_A[0])
    return 4

def deca(): # 0x3D
    _A[0] = dec8(_A[0])
    return 4

def lda_n(): # 0x3E
    _A[0] = nxtpcb()
    return 7

def ccf(): # 0x3F
    global _f3, _f5, _fC, _fH, _fN
    _fH = _fC
    _fC = not _fC
    _fN = False
    _f3 = (_A[0] & F_3) != 0
    _f5 = (_A[0] & F_5) != 0
    return 4

def ldb_b(): # 0x40
    return 4

def ldb_c(): # 0x41
    _B[0] = _C[0]
    return 4

def ldb_d(): # 0x42
    _B[0] = _D[0]
    return 4

def ldb_e(): # 0x43
    _B[0] = _E[0]
    return 4

def ldb_h(): # 0x44
    _B[0] = _H[0]
    return 4

def ldb_l(): # 0x45
    _B[0] = _L[0]
    return 4

def ldb_hl_(): # 0x46
    _B[0] = memory.peekb(_HL[0])
    return 7

def ldb_a(): # 0x47
    _B[0] = _A[0]
    return 4

def ldc_b(): # 0x48
    _C[0] = _B[0]
    return 4

def ldc_c(): # 0x49
    return 4

def ldc_d(): # 0x4A
    _C[0] = _D[0]
    return 4

def ldc_e(): # 0x4B
    _C[0] = _E[0]
    return 4

def ldc_h(): # 0x4C
    _C[0] = _H[0]
    return 4

def ldc_l(): # 0x4D
    _C[0] = _L[0]
    return 4

def ldc_hl_(): # 0x4E
    _C[0] = memory.peekb(_HL[0])
    return 7

def ldc_a(): # 0x4F
    _C[0] = _A[0]
    return 4

def ldd_b(): # 0x50
    _D[0] = _B[0]
    return 4

def ldd_c(): # 0x51
    _D[0] = _C[0]
    return 4

def ldd_d(): # 0x52
    return 4

def ldd_e(): # 0x53
    _D[0] = _E[0]
    return 4

def ldd_h(): # 0x54
    _D[0] = _H[0]
    return 4

def ldd_l(): # 0x55
    _D[0] = _L[0]
    return 4

def ldd_hl_(): # 0x56
    _D[0] = memory.peekb(_HL[0])
    return 7

def ldd_a(): # 0x57
    _D[0] = _A[0]
    return 4

def lde_b(): # 0x58
    _E[0] = _B[0]
    return 4

def lde_c(): # 0x59
    _E[0] = _C[0]
    return 4

def lde_d(): # 0x5A
    _E[0] = _D[0]
    return 4

def lde_e(): # 0x5B
    return 4

def lde_h(): # 0x5C
    _E[0] = _H[0]
    return 4

def lde_l(): # 0x5D
    _E[0] = _L[0]
    return 4

def lde_hl_(): # 0x5E
    _E[0] = memory.peekb(_HL[0])
    return 7

def lde_a(): # 0x5F
    _E[0] = _A[0]
    return 4

def ldh_b(): # 0x60
    _H[0] = _B[0]
    return 4

def ldh_c(): # 0x61
    _H[0] = _C[0]
    return 4

def ldh_d(): # 0x62
    _H[0] = _D[0]
    return 4

def ldh_e(): # 0x63
    _H[0] = _E[0]
    return 4

def ldh_h(): # 0x64
    return 4

def ldh_l(): # 0x65
    _H[0] = _L[0]
    return 4

def ldh_hl_(): # 0x66
    _H[0] = memory.peekb(_HL[0])
    return 7

def ldh_a(): # 0x67
    _H[0] = _A[0]
    return 4

def ldl_b(): # 0x68
    _L[0] = _B[0]
    return 4

def ldl_c(): # 0x69
    _L[0] = _C[0]
    return 4

def ldl_d(): # 0x6A
    _L[0] = _D[0]
    return 4

def ldl_e(): # 0x6B
    _L[0] = _E[0]
    return 4

def ldl_h(): # 0x6C
    _L[0] = _H[0]
    return 4

def ldl_l(): # 0x6D
    return 4

def ldl_hl_(): # 0x6E
    _L[0] = memory.peekb(_HL[0])
    return 7

def ldl_a(): # 0x6F
    _L[0] = _A[0]
    return 4

def ldhl_b(): # 0x70
    memory.pokeb(_HL[0], _B[0])
    return 7

def ldhl_c(): # 0x71
    memory.pokeb(_HL[0], _C[0])
    return 7

def ldhl_d(): # 0x72
    memory.pokeb(_HL[0], _D[0])
    return 7

def ldhl_e(): # 0x73
    memory.pokeb(_HL[0], _E[0])
    return 7

def ldhl_h(): # 0x74
    memory.pokeb(_HL[0], _H[0])
    return 7

def ldhl_l(): # 0x75
    memory.pokeb(_HL[0], _L[0])
    return 7

def halt(): # 0x76
    # TODO: HALT
    return 4

def ldhl_a(): # 0x77
    memory.pokeb(_HL[0], _A[0])
    return 7

def lda_b(): # 0x78
    _A[0] = _B[0]
    return 4

def lda_c(): # 0x79
    _A[0] = _C[0]
    return 4

def lda_d(): # 0x7A
    _A[0] = _D[0]
    return 4

def lda_e(): # 0x7B
    _A[0] = _E[0]
    return 4

def lda_h(): # 0x7C
    _A[0] = _H[0]
    return 4

def lda_l(): # 0x7D
    _A[0] = _L[0]
    return 4

def lda_hl_(): # 0x7E
    _A[0] = memory.peekb(_HL[0])
    return 7

def lda_a(): # 0x7F
    return 4

def adda_b(): # 0x80
    add_a(_B[0])
    return 4

def adda_c(): # 0x81
    add_a(_C[0])
    return 4

def adda_d(): # 0x82
    add_a(_D[0])
    return 4

def adda_e(): # 0x83
    add_a(_E[0])
    return 4

def adda_h(): # 0x84
    add_a(_H[0])
    return 4

def adda_l(): # 0x85
    add_a(_L[0])
    return 4

def adda_hl_(): # 0x86
    add_a(memory.peekb(_HL[0]))
    return 7

def adda_a(): # 0x87
    add_a(_A[0])
    return 4

def adca_b(): # 0x88
    adc_a(_B[0])
    return 4

def adca_c(): # 0x89
    adc_a(_C[0])
    return 4

def adca_d(): # 0x8A
    adc_a(_D[0])
    return 4

def adca_e(): # 0x8B
    adc_a(_E[0])
    return 4

def adca_h(): # 0x8C
    adc_a(_H[0])
    return 4

def adca_l(): # 0x8D
    adc_a(_L[0])
    return 4

def adca_hl_(): # 0x8E
    adc_a(memory.peekb(_HL[0]))
    return 7

def adca_a(): # 0x8F
    adc_a(_A[0])
    return 4

def suba_b(): # 0x90
    sub_a(_B[0])
    return 4

def suba_c(): # 0x91
    sub_a(_C[0])
    return 4

def suba_d(): # 0x92
    sub_a(_D[0])
    return 4

def suba_e(): # 0x93
    sub_a(_E[0])
    return 4

def suba_h(): # 0x94
    sub_a(_H[0])
    return 4

def suba_l(): # 0x95
    sub_a(_L[0])
    return 4

def suba_hl_(): # 0x96
    sub_a(memory.peekb(_HL[0]))
    return 7

def suba_a(): # 0x97
    sub_a(_A[0])
    return 4

def sbca_b(): # 0x98
    sbc_a(_B[0])
    return 4

def sbca_c(): # 0x99
    sbc_a(_C[0])
    return 4

def sbca_d(): # 0x9A
    sbc_a(_D[0])
    return 4

def sbca_e(): # 0x9B
    sbc_a(_E[0])
    return 4

def sbca_h(): # 0x9C
    sbc_a(_H[0])
    return 4

def sbca_l(): # 0x9D
    sbc_a(_L[0])
    return 4

def sbca_hl_(): # 0x9E
    sbc_a(memory.peekb(_HL[0]))
    return 7

def sbca_a(): # 0x9F
    sbc_a(_A[0])
    return 4

def anda_b(): # 0xA0
    and_a(_B[0])
    return 4

def anda_c(): # 0xA1
    and_a(_C[0])
    return 4

def anda_d(): # 0xA2
    and_a(_D[0])
    return 4

def anda_e(): # 0xA3
    and_a(_E[0])
    return 4

def anda_h(): # 0xA4
    and_a(_H[0])
    return 4

def anda_l(): # 0xA5
    and_a(_L[0])
    return 4

def anda_hl_(): # 0xA6
    and_a(memory.peekb(_HL[0]))
    return 7

def anda_a(): # 0xA7
    and_a(_A[0])
    return 4

def xora_b(): # 0xA8
    xor_a(_B[0])
    return 4

def xora_c(): # 0xA9
    xor_a(_C[0])
    return 4

def xora_d(): # 0xAA
    xor_a(_D[0])
    return 4

def xora_e(): # 0xAB
    xor_a(_E[0])
    return 4

def xora_h(): # 0xAC
    xor_a(_H[0])
    return 4

def xora_l(): # 0xAD
    xor_a(_L[0])
    return 4

def xora_hl_(): # 0xAE
    xor_a(memory.peekb(_HL[0]))
    return 7

def xora_a(): # 0xAF
    xor_a(_A[0])
    return 4

def ora_b(): # 0xB0
    or_a(_B[0])
    return 4

def ora_c(): # 0xB1
    or_a(_C[0])
    return 4

def ora_d(): # 0xB2
    or_a(_D[0])
    return 4

def ora_e(): # 0xB3
    or_a(_E[0])
    return 4

def ora_h(): # 0xB4
    or_a(_H[0])
    return 4

def ora_l(): # 0xB5
    or_a(_L[0])
    return 4

def ora_hl_(): # 0xB6
    or_a(memory.peekb(_HL[0]))
    return 7

def ora_a(): # 0xB7
    or_a(_A[0])
    return 4

def cpa_b(): # 0xB8
    cp_a(_B[0])
    return 4

def cpa_c(): # 0xB9
    cp_a(_C[0])
    return 4

def cpa_d(): # 0xBA
    cp_a(_D[0])
    return 4

def cpa_e(): # 0xBB
    cp_a(_E[0])
    return 4

def cpa_h(): # 0xBC
    cp_a(_H[0])
    return 4

def cpa_l(): # 0xBD
    cp_a(_L[0])
    return 4

def cpa_hl_(): # 0xBE
    cp_a(memory.peekb(_HL[0]))
    return 7

def cpa_a(): # 0xBF
    cp_a(_A[0])
    return 4

def retnz(): # 0xC0
    if not _fZ:
        poppc()
        return 11
    else:
        return 5

def popbc(): # 0xC1
    _BC[0] = popw()
    return 10

def jpnz_nn(): # 0xC2
    if not _fZ:
        _PC[0] = nxtpcw()
        return 10
    else:
        _PC[0] += 2
        return 10

def jp_nn(): # 0xC3
    _PC[0] = nxtpcw()
    return 10

def callnz_nn(): # 0xC4
    if not _fZ:
        addr = nxtpcw()
        pushpc()
        _PC[0] = addr
        return 17
    else:
        _PC[0] += 2
        return 10

def pushbc(): # 0xC5
    pushw(_BC[0])
    return 11

def adda_n(): # 0xC6
    add_a(nxtpcb())
    return 7

def rst00(): # 0xC7
    pushpc()
    _PC[0] = 0x00
    return 11

def retz(): # 0xC8
    if _fZ:
        poppc()
        return 11
    else:
        return 5

def ret(): # 0xC9
    poppc()
    return 10

def jpz_nn(): # 0xCA
    if _fZ:
        _PC[0] = nxtpcw()
        return 10
    else:
        _PC[0] += 2
        return 10

def cb(): # 0xCB
    global tstates
    inc_r()
    op = nxtpcb()
    tstates += _cbdict[op]()
    return 0

def callz_nn(): # 0xCC
    if _fZ:
        addr = nxtpcw()
        pushpc()
        _PC[0] = addr
        return 17
    else:
        _PC[0] += 2
        return 10

def call_nn(): # 0xCD
    addr = nxtpcw()
    pushpc()
    _PC[0] = addr
    return 17

def adca_n(): # 0xCE
    adc_a(nxtpcb())
    return 7

def rst08(): # 0xCF
    pushpc()
    _PC[0] = 0x08
    return 11

def retnc(): # 0xD0
    if not _fC:
        poppc()
        return 11
    else:
        return 5

def popde(): # 0xD1
    _DE[0] = popw()
    return 10

def jpnc_nn(): # 0xD2
    if not _fC:
        _PC[0] = nxtpcw()
        return 10
    else:
        _PC[0] += 2
        return 10

def out_n_a(): # 0xD3
    ports.port_out(nxtpcb(), _A[0])
    return 11

def callnc_nn(): # 0xD4
    if not _fC:
        addr = nxtpcw()
        pushpc()
        _PC[0] = addr
        return 17
    else:
        _PC[0] += 2
        return 10

def pushde(): # 0xD5
    pushw(_DE[0])
    return 11

def suba_n(): # 0xD6
    sub_a(nxtpcb())
    return 7

def rst10(): # 0xD7
    pushpc()
    _PC[0] = 0x10
    return 11

def retc(): # 0xD8
    if _fC:
        poppc()
        return 11
    else:
        return 5

def exx(): # 0xD9
    global _BC, _DE, _HL, _BC_, _DE_, _HL_
    _BC[0], _BC_[0] = _BC_[0], _BC[0]
    _DE[0], _DE_[0] = _DE_[0], _DE[0]
    _HL[0], _HL_[0] = _HL_[0], _HL[0]
    return 4

def jpc_nn(): # 0xDA
    if _fC:
        _PC[0] = nxtpcw()
        return 10
    else:
        _PC[0] += 2
        return 10

def in_a_n(): # 0xDB
    _A[0] = ports.port_in(nxtpcb())
    return 11

def callc_nn(): # 0xDC
    if _fC:
        addr = nxtpcw()
        pushpc()
        _PC[0] = addr
        return 17
    else:
        _PC[0] += 2
        return 10

def dd(): # 0xDD
    global tstates, _ID, _IDL, _IDH, _IX, _IXL, _IXH
    inc_r()
    _ID = _IX
    _IDL = _IXL
    _IDH = _IXH
    op = nxtpcb()
    if op == 0xDD: # NOP
        return 4
    if op == 0xFD: # NOP
        return 4
    if op == 0xCB:
        tstates += idcb()
    else:
        tstates += _ixiydict[op]()
    return 0

def sbca_n(): # 0xDE
    sbc_a(nxtpcb())
    return 7

def rst18(): # 0xDF
    pushpc()
    _PC[0] = 0x18
    return 11

def retpo(): # 0xE0
    if not _fPV:
        poppc()
        return 11
    else:
        return 5

def pophl(): # 0xE1
    _HL[0] = popw()
    return 10

def jppo_nn(): # 0xE2
    if not _fPV:
        _PC[0] = nxtpcw()
        return 10
    else:
        _PC[0] += 2
        return 10

def ex_sp_hl(): # 0xE3
    t = memory.peekw(_SP[0])
    memory.pokew(_SP[0], _HL[0])
    _HL[0] = t
    return 19

def callpo_nn(): # 0xE4
    if not _fPV:
        addr = nxtpcw()
        pushpc()
        _PC[0] = addr
        return 17
    else:
        _PC[0] += 2
        return 10

def pushhl(): # 0xE5
    pushw(_HL[0])
    return 11

def anda_n(): # 0xE6
    and_a(nxtpcb())
    return 7

def rst20(): # 0xE7
    pushpc()
    _PC[0] = 0x20
    return 11

def retpe(): # 0xE8
    if _fPV:
        poppc()
        return 11
    else:
        return 5

def jphl(): # 0xE9
    _PC[0] = _HL[0]
    return 4

def jppe_nn(): # 0xEA
    if _fPV:
        _PC[0] = nxtpcw()
        return 10
    else:
        _PC[0] += 2
        return 10

def exdehl(): # 0xEB
    global _DE, _HL
    _DE[0], _HL[0] = _HL[0], _DE[0]
    return 4

def callpe_nn(): # 0xEC
    if _fPV:
        addr = nxtpcw()
        pushpc()
        _PC[0] = addr
        return 17
    else:
        _PC[0] += 2
        return 10

def ed(): # 0xED
    global tstates
    inc_r()
    op = nxtpcb()
    if op in _eddict:
        tstates += _eddict[op]()
    else:
        # NOP
        pass
    return 0

def xora_n(): # 0xEE
    xor_a(nxtpcb())
    return 7

def rst28(): # 0xEF
    pushpc()
    _PC[0] = 0x28
    return 11

def retp(): # 0xF0
    if not _fS:
        poppc()
        return 11
    else:
        return 5

def popaf(): # 0xF1
    _AF[0] = popw()
    setflags()
    return 10

def jpp_nn(): # 0xF2
    if not _fS:
        _PC[0] = nxtpcw()
        return 10
    else:
        _PC[0] += 2
        return 10

def di(): # 0xF3
    global _IFF1, _IFF2
    _IFF1 = False
    _IFF2 = False
    return 4

def callp_nn(): # 0xF4
    if not _fS:
        addr = nxtpcw()
        pushpc()
        _PC[0] = addr
        return 17
    else:
        _PC[0] += 2
        return 10

def pushaf(): # 0xF5
    getflags()
    pushw(_AF[0])
    return 11

def ora_n(): # 0xF6
    or_a(nxtpcb())
    return 7

def rst30(): # 0xF7
    pushpc()
    _PC[0] = 0x30
    return 11

def retm(): # 0xF8
    if _fS:
        poppc()
        return 11
    else:
        return 5

def ldsphl(): # 0xF9
    _SP[0] = _HL[0]
    return 6

def jpm_nn(): # 0xFA
    if _fS:
        _PC[0] = nxtpcw()
        return 10
    else:
        _PC[0] += 2
        return 10

def ei(): # 0xFB
    global _IFF1, _IFF2
    _IFF1 = True
    _IFF2 = True
    return 4

def callm_nn(): # 0xFC
    if _fS:
        addr = nxtpcw()
        pushpc()
        _PC[0] = addr
        return 17
    else:
        _PC[0] += 2
        return 10

def fd(): # 0xFD
    global tstates, _ID, _IDL, _IDH, _IY, _IYL, _IYH
    inc_r()
    _ID = _IY
    _IDL = _IYL
    _IDH = _IYH
    op = nxtpcb()
    if op == 0xDD: # NOP
        return 4
    if op == 0xFD: # NOP
        return 4
    if op == 0xCB:
        tstates += idcb()
    else:
        tstates += _ixiydict[op]()
    return 0

def cpa_n(): # 0xFE
    cp_a(nxtpcb())
    return 7

def rst38(): # 0xFF
    pushpc()
    _PC[0] = 0x38
    return 11



_halted = False


def nmi_cpu():
    """Obsługa NMI (niemaskowalne): skok do 0x0066, zachowanie IFF1 w IFF2."""
    global _IFF1, _IFF2, _halted
    _halted = False
    _IFF2 = _IFF1
    _IFF1 = False
    pushpc()
    _PC[0] = 0x0066
    return 11


main_cmds = {
    0x00: nop,        0x01: ldbc_nn,   0x02: ldbc_a,    0x03: incbc,
    0x04: incb,       0x05: decb,      0x06: ldb_n,     0x07: rlca,
    0x08: exafaf_,    0x09: addhlbc,   0x0A: ldab_c,    0x0B: decbc,
    0x0C: incc,       0x0D: decc,      0x0E: ldc_n,     0x0F: rrca,
    0x10: djnz,       0x11: ldde_nn,   0x12: ldde_a,    0x13: incde,
    0x14: incd,       0x15: decd,      0x16: ldd_n,     0x17: rla,
    0x18: jr,         0x19: addhlde,   0x1A: ldade_,    0x1B: decde,
    0x1C: ince,       0x1D: dece,      0x1E: lde_n,     0x1F: rra,
    0x20: jrnz,       0x21: ldhl_nn,   0x22: ld_nn_hl,  0x23: inchl,
    0x24: inch,       0x25: dech,      0x26: ldh_n,     0x27: daa,
    0x28: jrz,        0x29: addhlhl,   0x2A: ldhl_nn_,  0x2B: dechl,
    0x2C: incl,       0x2D: decl,      0x2E: ldl_n,     0x2F: cpl,
    0x30: jrnc,       0x31: ldsp_nn,   0x32: ld_nn_a,   0x33: incsp,
    0x34: inc_hl_,    0x35: dec_hl_,   0x36: ld_hl_n,   0x37: scf,
    0x38: jrc,        0x39: addhlsp,   0x3A: lda_nn_,   0x3B: decsp,
    0x3C: inca,       0x3D: deca,      0x3E: lda_n,     0x3F: ccf,
    0x40: ldb_b,      0x41: ldb_c,     0x42: ldb_d,     0x43: ldb_e,
    0x44: ldb_h,      0x45: ldb_l,     0x46: ldb_hl_,   0x47: ldb_a,
    0x48: ldc_b,      0x49: ldc_c,     0x4A: ldc_d,     0x4B: ldc_e,
    0x4C: ldc_h,      0x4D: ldc_l,     0x4E: ldc_hl_,   0x4F: ldc_a,
    0x50: ldd_b,      0x51: ldd_c,     0x52: ldd_d,     0x53: ldd_e,
    0x54: ldd_h,      0x55: ldd_l,     0x56: ldd_hl_,   0x57: ldd_a,
    0x58: lde_b,      0x59: lde_c,     0x5A: lde_d,     0x5B: lde_e,
    0x5C: lde_h,      0x5D: lde_l,     0x5E: lde_hl_,   0x5F: lde_a,
    0x60: ldh_b,      0x61: ldh_c,     0x62: ldh_d,     0x63: ldh_e,
    0x64: ldh_h,      0x65: ldh_l,     0x66: ldh_hl_,   0x67: ldh_a,
    0x68: ldl_b,      0x69: ldl_c,     0x6A: ldl_d,     0x6B: ldl_e,
    0x6C: ldl_h,      0x6D: ldl_l,     0x6E: ldl_hl_,   0x6F: ldl_a,
    0x70: ldhl_b,     0x71: ldhl_c,    0x72: ldhl_d,    0x73: ldhl_e,
    0x74: ldhl_h,     0x75: ldhl_l,    0x76: halt,      0x77: ldhl_a,
    0x78: lda_b,      0x79: lda_c,     0x7A: lda_d,     0x7B: lda_e,
    0x7C: lda_h,      0x7D: lda_l,     0x7E: lda_hl_,   0x7F: lda_a,
    0x80: adda_b,     0x81: adda_c,    0x82: adda_d,    0x83: adda_e,
    0x84: adda_h,     0x85: adda_l,    0x86: adda_hl_,  0x87: adda_a,
    0x88: adca_b,     0x89: adca_c,    0x8A: adca_d,    0x8B: adca_e,
    0x8C: adca_h,     0x8D: adca_l,    0x8E: adca_hl_,  0x8F: adca_a,
    0x90: suba_b,     0x91: suba_c,    0x92: suba_d,    0x93: suba_e,
    0x94: suba_h,     0x95: suba_l,    0x96: suba_hl_,  0x97: suba_a,
    0x98: sbca_b,     0x99: sbca_c,    0x9A: sbca_d,    0x9B: sbca_e,
    0x9C: sbca_h,     0x9D: sbca_l,    0x9E: sbca_hl_,  0x9F: sbca_a,
    0xA0: anda_b,     0xA1: anda_c,    0xA2: anda_d,    0xA3: anda_e,
    0xA4: anda_h,     0xA5: anda_l,    0xA6: anda_hl_,  0xA7: anda_a,
    0xA8: xora_b,     0xA9: xora_c,    0xAA: xora_d,    0xAB: xora_e,
    0xAC: xora_h,     0xAD: xora_l,    0xAE: xora_hl_,  0xAF: xora_a,
    0xB0: ora_b,      0xB1: ora_c,     0xB2: ora_d,     0xB3: ora_e,
    0xB4: ora_h,      0xB5: ora_l,     0xB6: ora_hl_,   0xB7: ora_a,
    0xB8: cpa_b,      0xB9: cpa_c,     0xBA: cpa_d,     0xBB: cpa_e,
    0xBC: cpa_h,      0xBD: cpa_l,     0xBE: cpa_hl_,   0xBF: cpa_a,
    0xC0: retnz,      0xC1: popbc,     0xC2: jpnz_nn,   0xC3: jp_nn,
    0xC4: callnz_nn,  0xC5: pushbc,    0xC6: adda_n,    0xC7: rst00,
    0xC8: retz,       0xC9: ret,       0xCA: jpz_nn,    0xCB: cb,
    0xCC: callz_nn,   0xCD: call_nn,   0xCE: adca_n,    0xCF: rst08,
    0xD0: retnc,      0xD1: popde,     0xD2: jpnc_nn,   0xD3: out_n_a,
    0xD4: callnc_nn,  0xD5: pushde,    0xD6: suba_n,    0xD7: rst10,
    0xD8: retc,       0xD9: exx,       0xDA: jpc_nn,    0xDB: in_a_n,
    0xDC: callc_nn,   0xDD: dd,        0xDE: sbca_n,    0xDF: rst18,
    0xE0: retpo,      0xE1: pophl,     0xE2: jppo_nn,   0xE3: ex_sp_hl,
    0xE4: callpo_nn,  0xE5: pushhl,    0xE6: anda_n,    0xE7: rst20,
    0xE8: retpe,      0xE9: jphl,      0xEA: jppe_nn,   0xEB: exdehl,
    0xEC: callpe_nn,  0xED: ed,        0xEE: xora_n,    0xEF: rst28,
    0xF0: retp,       0xF1: popaf,     0xF2: jpp_nn,    0xF3: di,
    0xF4: callp_nn,   0xF5: pushaf,    0xF6: ora_n,     0xF7: rst30,
    0xF8: retm,       0xF9: ldsphl,    0xFA: jpm_nn,    0xFB: ei,
    0xFC: callm_nn,   0xFD: fd,        0xFE: cpa_n,     0xFF: rst38,
}


def execute_one_step() -> int:
    """Pobiera i wykonuje jedną instrukcję Z80. Zwraca liczbę T-states."""
    global tstates, _halted
    if _halted:
        inc_r()
        tstates += 4
        return 4
    inc_r()
    op = nxtpcb()
    cycles = main_cmds[op]()
    tstates += cycles
    return cycles
