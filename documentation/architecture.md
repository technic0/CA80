# CA-80 Microcomputer — System Architecture

**Reference for the expanded MIK290 configuration with the MIK11 monitor**

This document describes the hardware architecture, memory map, I/O subsystems, and firmware behavior of the **CA-80 microcomputer** in its expanded MIK290 mainboard configuration with the MIK11 monitor ROM (8 KB). It is implementation-agnostic — the goal is to capture *what the hardware does*, in enough detail to support both software emulators (e.g., the Python emulator in this repository) and hardware reconstructions (e.g., FPGA implementations).

Verified against:
- `ca80_monitor_new_mik290.asm` — annotated MIK11 monitor source listing
- MIK09 (mainboard documentation)
- MIK11 (monitor documentation)
- R8 / R23 / R24 schematic and table references
- Physical CA-80 hardware testing (ROM signatures, keyboard codes, sound timing)

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [CPU and Bus Architecture](#2-cpu-and-bus-architecture)
3. [Memory Map](#3-memory-map)
4. [I/O Port Architecture](#4-io-port-architecture)
5. [Interrupt Architecture](#5-interrupt-architecture)
6. [Subsystem Interactions](#6-subsystem-interactions)
7. [Boot Sequence](#7-boot-sequence)
8. [Tape I/O](#8-tape-io)
9. [Debugging Support](#9-debugging-support)
10. [Timing Relationships](#10-timing-relationships)
11. [Emulator/Extension Interface](#11-emulatorextension-interface)
12. [Implementation Reference](#12-implementation-reference)
13. [Appendix A — Monitor ROM Image](#appendix-a--monitor-rom-image)
14. [Appendix B — Quick Reference](#appendix-b--quick-reference)

---

## 1. System Overview

The CA-80 is a Polish 8-bit educational microcomputer designed in the mid-1980s by Stanisław Gardynik, based on the Zilog Z80A CPU. The **MIK290 expanded configuration** comprises:

- **Z80A CPU** clocked at 4 MHz
- **8 KB system monitor ROM** (MIK11) in socket U9, mirrored to fill 16 KB
- **C800 ROM package** (typically 2 KB, mirrored to 16 KB) in socket U10 — built-in games and tools
- **C930 ROM package** (16 KB) in socket U11 — cassette tape interface and applications
- **16 KB user RAM** (62256 or equivalent) in socket U12
- **Intel 8255 PPI** for keyboard input and 7-segment display output
- **Z80A CTC** for single-step debugging support (NOT the source of NMI)
- **74123 monostable multivibrator** driving a piezo speaker (port 0xEC)
- **Independent ~500 Hz crystal-driven multivibrator** providing the system NMI
- **8-digit 7-segment LED display** with multiplexed refresh
- **24-key keyboard** (4×6 matrix): hex digits, control keys, and four function keys F1-F4

The system has no graphics, no DRAM, no DMA, and no operating system as such. The monitor ROM contains the entirety of the system software: command interpreter, real-time clock, memory editor, register inspection, tape I/O, and a single-step debugger.

### 1.1 Block Diagram

```
                    +-----------------+
   4 MHz Crystal -->|     Z80A CPU    |<-- /NMI (~500 Hz, from Ux multivibrator)
                    +-----------------+    /INT (from CTC, used for single-step)
                       |       |       |
                  Address Bus  Data Bus  Control
                       |       |       |
        +--------------+-------+-------+--------------+--------+
        |              |       |       |              |        |
   +---------+    +---------+ +-----+ +-----+    +--------+ +--------+
   |  U9 ROM |    | U10 ROM | | U11 | | U12 |    |  8255  | |  CTC   |
   |  16 KB  |    | (C800)  | |C930 | | RAM |    |  PPI   | |        |
   | monitor |    |  16 KB  | |16 KB| |16 KB|    |F0H-F3H | |F8H-FBH |
   | 0000-3FFF|    |4000-7FFF| |8000-| |C000-|   +--------+ +--------+
   +---------+    +---------+ |BFFF | |FFFF |        |
                              +-----+ +-----+        |
                                                +--------+
                                                |Keyboard|--- 24 keys
                                                |Display |--- 8 × 7-seg
                                                +--------+
                                                     |
                                                +-----------+
                                                |  74123    |--- speaker
                                                | monostable|    (port ECH)
                                                +-----------+
```

### 1.2 Key Design Principles

- **No memory-mapped I/O.** All peripherals use Z80 I/O ports (`IN`/`OUT`).
- **Multiplexed display.** The monitor's NMI handler scans through 8 digits one at a time, refreshing each at ~62 Hz.
- **Software keyboard scanning.** The same NMI handler reads keyboard rows for the currently active digit's column.
- **Software-generated sound.** The monitor toggles port 0xEC under NMI control to produce key beeps; user programs can produce arbitrary frequencies.
- **All system state in 115 bytes of RAM** (0xFF8D-0xFFFF), initialized from a ROM template at boot.

---

## 2. CPU and Bus Architecture

### 2.1 CPU

The Z80A runs at 4 MHz with the following configuration after monitor initialization:
- **Interrupt mode:** IM 1 (vectored maskable interrupts via `I` register)
- **I register:** loaded with `0xFF` (high byte of vector table base in RAM)
- **NMI:** enabled (active by hardware, monitor cannot disable)
- **Stack:** initialized to `TOS = 0xFF8D` (top-of-stack, system)

User programs typically receive a fresh stack at `0xFF66` (= `TOS - 0x27`) when launched via the monitor's `*G` command.

### 2.2 Address Decoding

Address decoding is done by simple combinatorial logic on bits A14-A15 (4-way decode for the four 16 KB slots), plus the on-chip selectors of the 8255 and CTC for I/O port assignment. There is no bank-switching or memory paging — the CA-80 is a fully linear-address machine.

| A15 | A14 | Slot | Range          | Device              |
|-----|-----|------|----------------|---------------------|
|  0  |  0  | U9   | 0x0000-0x3FFF  | Monitor ROM (CA80)  |
|  0  |  1  | U10  | 0x4000-0x7FFF  | C800 ROM package    |
|  1  |  0  | U11  | 0x8000-0xBFFF  | C930 ROM package    |
|  1  |  1  | U12  | 0xC000-0xFFFF  | RAM                 |

ROMs smaller than 16 KB are mirrored within their slot via partial address decoding — for example, the 8 KB monitor ROM appears at both 0x0000-0x1FFF and 0x2000-0x3FFF.

### 2.3 NMI Source

**The NMI signal is generated by an independent crystal-driven multivibrator** (`Ux` in the schematic, gates U2 + crystal KW), running at approximately 500 Hz. It is NOT generated by the CTC.

This is a critical architectural fact, often confused in older documentation: while the CTC has interrupt-capable channels, none of them is wired to /NMI. The CTC's only role in interrupt generation is in single-step debugging mode, where Channel 0 produces a maskable INT (see §9.1).

The 500 Hz figure is verified by: WMSEK = 5 ticks per millisecond cycle, with 100 cycles per second yielding 500 NMI/sec, matching the 2 ms NMI period observed in display multiplexing timing.

---

## 3. Memory Map

### 3.1 Top-Level Memory Map

```
0x0000 ┌─────────────────────────────────┐
       │                                 │
       │  U9 — System Monitor (MIK11)    │
       │  CA80.BIN: 8 KB, mirrored to    │
       │  16 KB. Reset vector @ 0x0000.  │
       │                                 │
0x4000 ├─────────────────────────────────┤
       │                                 │
       │  U10 — C800 ROM Package         │
       │  Typically 2 KB, mirrored to    │
       │  16 KB. Signature 0x55 @ 0x4001 │
       │  Entry point @ 0x4020.          │
       │                                 │
0x8000 ├─────────────────────────────────┤
       │                                 │
       │  U11 — C930 ROM Package         │
       │  16 KB linear (cassette tools). │
       │  Signature 0xAA @ 0x8001        │
       │  Entry point @ 0x8002.          │
       │                                 │
0xC000 ├─────────────────────────────────┤
       │                                 │
       │  U12 — User RAM (16 KB)         │
       │                                 │
       │  Free for user code/data:       │
       │  0xC000 - 0xFF7F (~16 KB)       │
       │                                 │
0xFF8D ├─── System RAM Area ─────────────┤
       │  Stack, save area, vectors,     │
       │  display buffer, RTC, sound.    │
0xFFFF └─────────────────────────────────┘
```

### 3.2 Monitor ROM Internal Structure (CA80.BIN, 8 KB)

| Range          | Content                                            |
|----------------|----------------------------------------------------|
| 0x0000         | Reset vector (cold start jump)                     |
| 0x0008         | RST 08H — TI1 (read keyboard with timeout)         |
| 0x0010         | RST 10H — CLR (clear display registers)            |
| 0x0018         | RST 18H — LBYTE (display byte at A as 2 hex digits)|
| 0x0020         | RST 20H — LADR (display HL as 4 hex digits)        |
| 0x0028         | RST 28H — USPWYS (set PWYS via inline parameter)   |
| 0x0030         | RST 30H — PWYS read                                |
| 0x0038         | RST 38H — IM 1 vector (jump to INTU @ 0xFFCF in RAM)|
| 0x0066         | NMI handler entry (display multiplex + keyboard)   |
| 0x0130         | CSTSM — keyboard scan (returns Z if no key)        |
| 0x0184         | CIM — read keyboard with debouncing                |
| 0x01E1         | CO1 — display character output                     |
| 0x0213         | EXPR — parse expression list (used by *D, *E, etc.)|
| 0x0241         | CA80A — main monitor entry point                   |
| 0x02A7         | CTBL — command dispatch table (17 entries × 2 bytes)|
| 0x02C9 - 0x04A0| Command implementations M0-MG                       |
| 0x04A0 - 0x0540| EXPR support, register operations, monitor utilities|
| 0x0546         | RESTAR — return from user program to monitor       |
| 0x05C8 - 0x05FF| TRAM — RAM initialization template (56 bytes)      |
| 0x0603         | EMINIT — emulator/extension initialization         |
| 0x0700 - 0x07FF| TKLAW, TSIED, TABC, TABM tables (page-aligned)    |

The full monitor occupies 8 KB; the upper 8 KB of slot U9 is a mirror of the lower 8 KB.

### 3.3 ROM Page-Alignment Constraints

Several monitor tables are accessed via `LD H,fixed_high` with an index in `L`, requiring them to be page-aligned (i.e., not crossing a 256-byte boundary). These constraints must be preserved if the ROM is rebuilt:

- **TKLAW** @ 0x0300 — keyboard code translation table, 24 bytes
- **TSIED** @ 0x0320 — 7-segment encoding for hex digits 0-F, 16 bytes
- **TABC** @ 0x0340 — sound counter cascade table (RTC tick generator)
- **TABM** @ 0x0360 — multiplexer state table for display refresh

### 3.4 RAM Layout (0xC000 - 0xFFFF)

```
0xC000 ┌─────────────────────────────────┐
       │                                 │
       │  User program area              │
       │  PCUZYT = 0xC000 (default user PC)│
       │  HLUZYT = 0xC100 (default user HL)│
       │                                 │
0xFF66 │  ─── User stack (initial SP)    │
       │                                 │
0xFF8D │  ─── System stack base (TOS)    │
       │                                 │
0xFF8D ├─── Save area (user registers) ──┤
       │  ELOC, DLOC, CLOC, BLOC, FLOC,  │
       │  ALOC, IXLOC, IYLOC, SLOC       │
0xFF99 ├─── EXIT routine (in RAM!) ──────┤
       │  Code: POP DE, POP BC, POP AF,  │
       │  POP IX, POP IY, POP HL, LD     │
       │  SP,HL, NOP NOP (KROK), LD HL,  │
       │  HLUZYT, EI, JP PCUZYT          │
0xFFA2 │  KROK — 2 NOPs (single-step)    │
0xFFAB ├─── Breakpoints (Pulapki) ───────┤
       │  TLOC = 0xFFAB — breakpoint 1   │
       │  Pulapka2 — breakpoint 2        │
0xFFB1 ├─── Tape parameters ─────────────┤
       │  DLUG = 0xFFB1 — data length    │
       │  MAGSP = 0xFFB2 — tape speed    │
0xFFB3 ├─── Status flags ────────────────┤
       │  GSTAT = 0xFFB3 — monitor active│
       │  ZESTAT = 0xFFB4 — RTC enable   │
0xFFB5 ├─── Indirect jump vectors ───────┤
       │  M8     = 0xFFB5 — *8 command   │
       │  ERRMAG = 0xFFB8 — tape error   │
       │  EM     = 0xFFBB — emulator     │
       │  RTS    = 0xFFBE — alternative  │
0xFFC1 ├─── IOCA (I/O indirect calls) ───┤
       │  APWYS  = 0xFFC1 — PWYS pointer │
       │  CSTS   = 0xFFC3 — keyboard scan│
       │  CI     = 0xFFC6 — read key     │
       │  AREST  = 0xFFC9 — return monitor│
0xFFCC │  NMIU   = 0xFFCC — NMI user hook│
0xFFCF │  INTU   = 0xFFCF — INT vector   │
       │  INTU0  = 0xFFD0 — INT0 vector  │
0xFFE8 ├─── RTC and signal counters ─────┤
       │  LCI    = 0xFFE8 — aux timer    │
       │  SYG    = 0xFFE9 — sound counter│
       │  TIME   = 0xFFEA — RTC tick     │
       │  MSEK   = 0xFFEB — milliseconds │
       │  SETSEK = 0xFFEC — hundredths   │
       │  SEK, MIN, GODZ — sec, min, hour│
       │  DNITYG, DNIM, MIES, LATA       │
0xFFF4 ├─── Keyboard and display ────────┤
       │  KLAW = 0xFFF4 — last keycode   │
       │  SBUF = 0xFFF5 — input buffer   │
       │  PWYS = 0xFFF6 — display ctrl   │
       │  BWYS = 0xFFF7 — display buffer │
       │       7 bytes: digits 0-7       │
0xFFFE │  (digit 0 = rightmost, 7 = left)│
0xFFFF └─────────────────────────────────┘
```

### 3.5 Display Buffer (BWYS)

The display buffer occupies 8 bytes at `0xFFF7-0xFFFE`:
- `0xFFFE` corresponds to **digit 0** (rightmost on the display)
- `0xFFF7` corresponds to **digit 7** (leftmost on the display)

Each byte contains the segment pattern for the corresponding digit, with the bit assignment (per R24 documentation):
```
bit 0 = a    bit 4 = e
bit 1 = b    bit 5 = f
bit 2 = c    bit 6 = g
bit 3 = d    bit 7 = K (decimal point)
```

For common-cathode displays, a `1` bit lights the segment; for common-anode displays, the polarity is inverted. The hardware variant determines this; the monitor itself does not invert.

### 3.6 PWYS — Display Format Control

The byte at `0xFFF6` (PWYS) controls how many digits are displayed and the cursor position:

```
bit 7-4: digit count (0-8) — number of digits to actively scan
bit 3-0: cursor position from right (0-7)
```

For example, `PWYS = 0x80` displays all 8 digits with no cursor; `PWYS = 0x43` displays 4 digits starting at position 3.

---

## 4. I/O Port Architecture

### 4.1 Port Map

| Port  | Device          | Direction | Description                          |
|-------|-----------------|-----------|--------------------------------------|
| 0xE8  | Emulator/ext.   | -         | Reserved for emulator interface      |
| 0xEC  | 74123 trigger   | OUT       | Sound: any write triggers pulse      |
| 0xF0  | 8255 PA         | IN        | Keyboard rows + tape input + config  |
| 0xF1  | 8255 PB         | OUT       | Display segment data                 |
| 0xF2  | 8255 PC         | OUT       | Display digit select + keyboard col  |
| 0xF3  | 8255 control    | OUT       | 8255 mode/BSR control                |
| 0xF8  | CTC channel 0   | IN/OUT    | Single-step debugger timer           |
| 0xF9  | CTC channel 1   | IN/OUT    | Internal timer (NOT the NMI source)  |
| 0xFA  | CTC channel 2   | IN/OUT    | Reserved                             |
| 0xFB  | CTC channel 3   | IN/OUT    | Reserved                             |
| 0xFC  | RESI            | OUT       | Clear maskable INT pending           |

**Note on the CTC:** The CTC is used by the monitor for single-step debugging (Channel 0) and as an internal timer (Channel 1). It is NOT involved in NMI generation. User programs may reprogram the CTC, but doing so will break the single-step debugger until the monitor reinitializes it.

### 4.2 8255 PPI Configuration

The 8255 is initialized in **mode 0** (basic input/output) with the control word `0x90`:
- **Port A (PA):** input (keyboard rows + tape + config)
- **Port B (PB):** output (display segments)
- **Port C (PC):** output (display digit select + keyboard column)

#### Port A bit assignments:
```
bit 7 = tape input (cassette signal)
bit 6 = keyboard row 6 (key 'F'/'7'/'B'/'3' depending on column)
bit 5 = keyboard row 5
bit 4 = keyboard row 4 (F1-F4 row)
bit 3 = keyboard row 3
bit 2 = keyboard row 2
bit 1 = keyboard row 1 (key '='/'.'/'G'/'M' depending on column)
bit 0 = configuration / emulator detect
```

#### Port B (display segments):
Direct copy of the BWYS byte for the currently selected digit, with bit 0 = segment a, ..., bit 6 = segment g, bit 7 = decimal point.

#### Port C bit assignments:
```
bit 7   = (unused or tape output)
bit 6-4 = digit select (one-hot, active LOW after decoding)
bit 3   = keyboard column 3 enable (LOW = active)
bit 2   = keyboard column 2 enable
bit 1   = keyboard column 1 enable
bit 0   = keyboard column 0 enable
```

The four lower bits of PC drive the keyboard column enables, while the upper bits select which digit of the display is currently lit. The monitor's NMI handler advances both selectors in lockstep, so each NMI cycle activates one digit *and* reads the four rows × 1 column intersection of the keyboard matrix.

### 4.3 Bit Set/Reset (BSR) Mode of 8255

The keyboard scanning routine `CSTSM` uses the 8255's BSR mode to set/reset individual bits of port C without affecting the others. The control word for BSR has format:
```
bit 7   = 0 (BSR mode, not configuration)
bit 6-4 = (don't care)
bit 3-1 = bit number (0-7)
bit 0   = 0 (reset) or 1 (set)
```

For example, to reset PC2 (activate column 2), the monitor writes `0x04` to the control port; to set PC2 again, it writes `0x05`.

### 4.4 Sound Port (0xEC)

Writing **any value** to port `0xEC` triggers the 74123 monostable, which produces a single positive pulse of approximately 700 µs duration on the speaker output. The pulse width is determined by the 74123's external R·C network and is fixed in hardware.

The monitor's NMI handler issues one `OUT (0xEC), A` per NMI cycle while the SYG counter is non-zero, producing a 500 Hz tone (the NMI rate). User programs can produce arbitrary frequencies by writing to 0xEC at custom intervals from main code or their own interrupt routines.

---

## 5. Interrupt Architecture

### 5.1 NMI (Primary System Interrupt)

- **Source:** independent crystal-driven multivibrator (Ux + crystal KW + U2 gates)
- **Frequency:** ~500 Hz (period 2 ms)
- **Vector:** Z80 hardwired NMI vector at `0x0066`
- **Cannot be disabled** by software (Z80 design)
- **Handler location:** Monitor ROM @ 0x0066, dispatching through `NMIU` vector at `0xFFCC` for user hook

The NMI handler performs, in this order:
1. Save user registers (or simply return if NMIU is set to RET)
2. Decrement `LCI` (auxiliary 40 ms timer used by CIM debouncing)
3. Decrement `SYG` (sound counter); if non-zero, issue `OUT (0xEC), A`
4. Decrement `TIME` (RTC tick); if zero, advance MSEK, SEK, MIN, GODZ chain
5. Detect "M" key press for monitor return (special case: M scanned independently)
6. Refresh one digit of the display:
   a. Load BWYS[active_digit] → PB
   b. Set PC bits to enable next digit and column
7. Read PA for keyboard rows of the currently active column
8. Compose key code from (column, row) and store in SBUF if changed
9. Restore registers and `RETN`

The whole handler completes in well under 2 ms, leaving CPU time for user code.

### 5.2 Maskable INT (Used Only for Single-Step)

- **Source:** Z80A CTC Channel 0 (output ZC/TO0)
- **Mode:** IM 1 (jumps to vector at `I << 8 | LOW(INTU0)` = `0xFFD0`)
- **Used by:** the monitor's MC command (single-step debugger) only
- **Disabled in normal operation:** monitor sets up CTC Ch0 only when entering MC

When MC is invoked:
- `INTU0` (RAM @ 0xFFD0) is set to point to `RESTAR`
- CTC Ch0 is programmed with `CCR0 = 0x87, TC0 = 10`
  - mode = timer, prescaler = 16, time constant = 10
  - bit 7 = 1 → INT enable
  - bit 1 = 1 → time constant follows
- This produces an INT after `16 × 10 = 160` T-states (40 µs at 4 MHz)
- The single user instruction executes (typically 4-23 T-states), then INT fires
- ISR jumps to RESTAR via INTU0 → returns control to monitor

### 5.3 RST Vectors (in ROM)

The Z80 RST instructions act as 1-byte CALL instructions to the eight fixed addresses in low memory. The monitor uses them as service routines:

| Vector | Address | Routine | Purpose                                  |
|--------|---------|---------|------------------------------------------|
| RST 0  | 0x0000  | (cold start)| Reset target                          |
| RST 08 | 0x0008  | TI1     | Read key with timeout                    |
| RST 10 | 0x0010  | CLR     | Clear display (parameter byte follows)   |
| RST 18 | 0x0018  | LBYTE   | Display byte (parameter byte = PWYS)     |
| RST 20 | 0x0020  | LADR    | Display address (parameter byte = PWYS)  |
| RST 28 | 0x0028  | USPWYS  | Set PWYS from inline parameter           |
| RST 30 | 0x0030  | PWYS    | Read current PWYS                        |
| RST 38 | 0x0038  | (INTU)  | IM 1 entry, dispatches via 0xFFCF        |

The "inline parameter" pattern is important: routines like `LBYTE` (RST 18H) consume the byte immediately following the `RST` instruction in user code, and adjust the return address accordingly. For example:

```assembly
RST 18H        ; Display byte in A
DB 0x43        ; PWYS = 0x43 (4 digits, position 3)
; Execution continues here after LBYTE returns
```

Calling these routines via `CALL 0x0018` instead of `RST 18H` is technically possible, but the inline parameter is still required and consumed.

---

## 6. Subsystem Interactions

### 6.1 NMI as System Heartbeat

Every 2 ms, the NMI handler ties together five concurrent subsystems:

```
┌─────────────────────────────────────────────────────────┐
│  NMI tick (every 2 ms, from Ux multivibrator)           │
└──────────────────────┬──────────────────────────────────┘
                       │
       ┌───────────────┼─────────────┬─────────────┐
       ▼               ▼             ▼             ▼
   Display      Keyboard scan    RTC counter   Sound output
   multiplex   (PC col, PA rows) (LCI, TIME,   (SYG counter,
   (BWYS @     → KLAW @ 0xFFF4    MSEK chain)   OUT 0xEC)
   8 digits)
```

This means **the user program never touches the display, keyboard, RTC, or beep counter directly** in normal operation — all of these are driven by the NMI handler reading and writing dedicated RAM locations. The user program just modifies these RAM locations as data.

### 6.2 Display Refresh

Each NMI cycle:
1. The handler advances `active_digit` (0-7, wrapping)
2. Loads BWYS[`active_digit`] into PB
3. Activates the corresponding digit-select line in PC

With 8 digits and 500 Hz NMI, each digit refreshes at 500 / 8 = **62.5 Hz**, well above flicker threshold. The duty cycle per digit is 1/8 = 12.5%, giving moderate brightness on standard 7-segment LEDs.

### 6.3 Keyboard Scanning

The active keyboard column is paired with the active digit (multiplexed together via PC bits). On each NMI:
1. After setting PC bits, the handler reads PA
2. PA bits 1-6 indicate which row(s) are active (LOW = pressed)
3. The (column, row) pair is converted to a "real code" stored as the byte composed from the column number and PA row mask
4. `CSTSM` translates real codes to "table codes" (`0x00`-`0x17`) via the 24-byte TKLAW lookup table

The table codes are 8-bit values in the range 0-23 used throughout the monitor (commands, displays, dispatch tables). See §6.5 for the full mapping.

### 6.4 Sound Generation (Beep)

When the user presses a key, the `CIM` routine loads SYG with a value (typically 50, giving 100 ms beep at 500 Hz). The NMI handler decrements SYG on each tick and writes any value to port 0xEC while SYG > 0:

```
SYG counter: 50, 49, 48, ..., 1, 0  (decremented in NMI, every 2 ms)
                                     ▲
                                     │ while > 0:
                                     │ OUT (0xEC), A
                                     │ → 74123 → 700 µs pulse
```

Each pulse is a single positive 700 µs pulse on the speaker. The repetition rate equals the NMI rate (500 Hz), producing a square-wave-like tone with ~35% duty cycle. The fundamental frequency is **500 Hz**, not 250 Hz — there is no toggling flip-flop, just a one-shot per trigger.

User programs can produce arbitrary frequencies by writing to 0xEC at custom intervals, either polled or from their own ISRs.

### 6.5 Keyboard Layout (R23)

The 24-key layout, verified against R23 documentation, with table codes:

```
Column: L=3       L=2       L=1       L=0
Row PA1: =/0x12   ./0x11    G/0x10    M/0x13
Row PA2: 2/0x02   6/0x06    A/0x0A    E/0x0E
Row PA3: 0/0x00   4/0x04    8/0x08    C/0x0C
Row PA4: F4/0x14  F3/0x15   F2/0x16   F1/0x17
Row PA5: 1/0x01   5/0x05    9/0x09    D/0x0D
Row PA6: 3/0x03   7/0x07    B/0x0B    F/0x0F
```

Note the **F-key reverse ordering**: F1 has the highest table code (0x17) and is in the rightmost column (L=0); F4 has the lowest code (0x14) in column L=3. This is because the column index encodes the upper two bits of the "real code" byte in CSTSM.

The 17 monitor commands occupy table codes `0x00-0x10` (0-9, A-G); codes `0x11-0x13` are control keys (SPAC, CR, M); codes `0x14-0x17` are F1-F4. Pressing a key with code `>= 0x11` at the main monitor prompt yields "Err CA80" — only commands 0-G are dispatched.

### 6.6 RTC (Real-Time Clock)

The monitor maintains a real-time clock entirely in software, driven by the NMI:

```
NMI (500 Hz) → TIME counter (4-bit, decremented from WMSEK=5)
              └→ at zero: increment MSEK
                           └→ at 100: increment SETSEK
                                       └→ etc. through SEK, MIN, GODZ, DNITYG, DNIM, MIES, LATA
```

The chain is: 500 Hz / 5 = 100 Hz tick of MSEK, then standard date/time arithmetic. The RTC can be enabled/disabled via the `ZESTAT` flag at 0xFFB4.

The user can read or set the RTC via monitor commands `*0` (display clock), `*1` (set time), `*2` (set date).

---
## 7. Boot Sequence

### 7.1 Power-On / Reset

When power is applied or the reset line is asserted:

1. **Z80 hardware:** PC = 0x0000, SP = 0xFFFF, IFF1/IFF2 = 0, I = 0, IM 0
2. **Address 0x0000** contains a jump to the cold-start routine (typically `JP CA80A`)
3. **CA80A** (cold-start, @ 0x0241):
   ```
   LD SP, TOS              ; SP = 0xFF8D (system stack)
   LD HL, KTRAM            ; ROM source pointer (end of TRAM template)
   LD DE, INTU+2           ; RAM target pointer (0xFFD1)
   LD BC, LTRAM            ; copy length (56 bytes)
   LDDR                    ; copy TRAM template to RAM
   LD A, HIGH TOS          ; = 0xFF
   LD I, A                 ; I-register for IM 1 vector base
   IM 1
   ```
4. **CTC initialization:**
   ```
   LD A, LOW INTU0         ; CTC vector low byte
   OUT (CHAN0), A
   LD A, CCR1              ; = 0x07
   OUT (CHAN1), A
   LD A, TC1               ; = 250
   OUT (CHAN1), A
   ```
   Note: CTC Channel 1 is given `CCR1 = 0x07` (bit 7 = 0, **no INT enable**), so it counts internally but generates no interrupts. CTC Channel 0 is left in a default state until MC (single-step) is invoked.
5. **8255 initialization:** control word 0x90 → PA in, PB out, PC out
6. **Detect emulator/extension:** Read PA bit 0; if = 1, branch to `EMINIT` (see §11)
7. **Display initial prompt:** clear BWYS, write "CA80" pattern via standard display routines
8. **Enter main loop:** `START1` calls `CIM` to read a key, then dispatches via `CTBL` or returns "Err CA80"

### 7.2 TRAM Template Copy

The TRAM template in ROM is copied to RAM via `LDDR` at boot. The template provides the runtime values for indirect jump vectors and the executable EXIT routine. The copy is **backward** (LDDR direction):
- Source: `KTRAM` (ROM, end of template) decreasing
- Destination: `INTU + 2 = 0xFFD1` decreasing
- Length: `LTRAM = 56 bytes`
- Result: TRAM contents land at RAM[0xFF9A..0xFFD1]

After this copy, RAM contains:
- An executable EXIT routine (for `JP EXIT` from user code via the stack-based register save)
- All indirect jump vectors (M8, ERRMAG, EM, RTS, IOCA group, NMIU, INTU)
- Default tape and status flag values

The RAM copies are what makes the system extensible: user programs can rewrite the indirect jumps to install custom keyboard handlers, error responses, or NMI hooks without modifying ROM.

### 7.3 Sub-monitor Entry Points

After initialization, the user can enter the C800 or C930 sub-monitors:

**C800 entry via `*80`:**
- Monitor command `*8` jumps to the M8 vector (`JP 0x0800`)
- C800 sub-monitor at 0x0800 checks signature `0x55` at 0x4001
- If valid, jumps to 0x4020 (C800 entry point)
- If not valid, returns to monitor with error

**C930 entry via `*89`:**
- Monitor command `*8` followed by `9` invokes EMINIT-style logic
- Checks signature `0xAA` at 0x8001
- If valid, jumps to 0x8002 (C930 entry point)
- If not valid, returns to monitor with error

These signature checks let the system distinguish between empty sockets (typically read as 0xFF) and inserted ROM packages.

---

## 8. Tape I/O

The CA-80 supports cassette tape data exchange via PA bit 7 (input) and a tape output line (driven by PC or a dedicated bit, depending on board revision).

### 8.1 Tape Format

Data is stored on tape as **frequency-shift-keyed (FSK) bits**:
- "0" bit: longer pulse (~2 ms half-period)
- "1" bit: shorter pulse (~1 ms half-period)

The exact timing is controlled by `MAGSP` (tape speed) at 0xFFB2. The default value is `0x25` (37 decimal), giving compatible timing with standard CA-80 tapes.

### 8.2 Tape Input (Command `*4`)

The monitor's `*4` command reads a block of bytes from tape:
1. User specifies start address
2. Monitor waits for the leader signal on PA bit 7
3. Each bit is timed by counting NOPs/loops while sampling PA bit 7
4. Bytes are assembled from 8 bits each + checksum
5. On checksum failure, monitor jumps via ERRMAG vector to display error

### 8.3 Tape Output (Command `*5`)

The monitor's `*5` command writes a block of bytes to tape:
1. User specifies start and end address
2. Monitor outputs leader signal (~2 sec)
3. Each byte is serialized bit-by-bit to the tape output line
4. Final checksum is appended

The DLUG byte at 0xFFB1 is used for variable-length headers in some tape protocols.

---

## 9. Debugging Support

### 9.1 Single-Step Mode (MC)

The MC command (`*MC`) implements per-instruction single-stepping using the CTC:

1. User specifies the address of the next instruction
2. Monitor sets `INTU0` (RAM @ 0xFFD0) to point to RESTAR
3. Monitor programs CTC Channel 0:
   ```
   CCR0 = 0x87  ; bit 7=1 (INT enable), bit 1=1 (TC follows), timer mode, prescaler=16
   TC0 = 10     ; → INT after 16 × 10 = 160 T-states (40 µs)
   ```
4. Monitor restores user registers from save area
5. `EI` and `JP user_PC` — user code begins executing
6. After ~40 µs, CTC fires INT
7. Z80 IM 1 jumps via 0xFFD0 → RESTAR
8. RESTAR saves user state, returns to monitor

The 40 µs timing means single-step works for any user instruction (longest Z80 instruction is 23 T-states, well under 160).

### 9.2 Indirect Jump Vectors

The monitor's RAM-based vector table (TRAM) allows user programs to intercept system events:

| Vector | Address | Default Target | Purpose                          |
|--------|---------|----------------|----------------------------------|
| M8     | 0xFFB5  | JP 0x0800      | `*8` command (C800 entry)        |
| ERRMAG | 0xFFB8  | JP ERROR       | Tape checksum error              |
| EM     | 0xFFBB  | JP 0x0806      | Emulator hook                    |
| RTS    | 0xFFBE  | JP 0x0803      | Alternative boot vector          |
| APWYS  | 0xFFC1  | DW 0xFFF6      | PWYS pointer (data, not code)    |
| CSTS   | 0xFFC3  | JP CSTSM       | Keyboard scan (replaceable)      |
| CI     | 0xFFC6  | JP CIM         | Read key with debounce           |
| AREST  | 0xFFC9  | JP RESTAR      | Return-to-monitor                |
| NMIU   | 0xFFCC  | RET            | User NMI hook (default: noop)    |
| INTU   | 0xFFCF  | JP ERROR       | IM 1 INT vector (RST 38)         |
| INTU0  | 0xFFD0  | (varies)       | CTC channel 0 INT vector         |

A user program can hook NMIU (`0xFFCC`) by writing a `JP myhandler` instruction there, or `RST` to return without effect. The monitor's NMI handler always calls through this vector.

### 9.3 Memory Inspection (`*D`)

The `*D` command (memory dump/edit) is interactive:
1. User enters address: `*D 1 2 3 4 =`
2. Monitor displays address + current byte
3. User can:
   - Press `.` (SPAC) → advance to next address
   - Press 2 hex digits → write byte and stay at current address
   - Press `=` or `M` or `G` → exit edit mode

The same command serves both inspection and modification.

### 9.4 Register Inspection (`*F`)

The `*F` command shows user program register state from the save area at 0xFF8D-0xFF98. The user can inspect and modify A, F, B, C, D, E, H, L, IX, IY, SP — these will be loaded back into the CPU when the user program is restarted via `*G`.

---

## 10. Timing Relationships

### 10.1 Master Timings

| Subsystem            | Source                | Frequency / Period  |
|----------------------|----------------------- |---------------------|
| CPU clock            | 4 MHz crystal         | 4 MHz / 250 ns      |
| NMI                  | Ux multivibrator (KW) | ~500 Hz / 2 ms      |
| Display refresh      | NMI / 8 digits        | 62.5 Hz per digit   |
| RTC tick (MSEK)      | NMI / WMSEK=5         | 100 Hz              |
| CIM debouncing (LCI) | NMI ÷ 20              | 40 ms               |
| Sound beep (SYG=50)  | 50 × 2 ms             | 100 ms duration     |
| Sound frequency      | NMI rate              | 500 Hz fundamental  |
| 74123 pulse width    | RC network            | ~700 µs             |
| Single-step (CTC Ch0)| 16 × 10 T-states      | 40 µs               |
| CTC Channel 1        | 16 × 250 T-states     | 1000 Hz (internal)  |

### 10.2 NMI Handler Timing Budget

With 2 ms between NMI events, the handler must complete in well under that:
- Save registers: ~30 T-states
- LCI/SYG/TIME counters: ~50 T-states
- Display refresh: ~20 T-states
- Keyboard scan: ~30 T-states
- Restore registers + RETN: ~30 T-states
- **Total: ~160 T-states ≈ 40 µs** per NMI

This leaves 99.98% of CPU time for user code — the system is essentially uninterrupted from the user program's perspective.

### 10.3 Boot-Up Time

From reset to "CA80" prompt:
- TRAM copy (LDDR 56 bytes): ~21 × 56 = ~1200 T-states = 300 µs
- CTC + 8255 init: ~50 T-states
- Display setup: ~200 T-states
- **Total: well under 1 ms**

The system is essentially instant-on.

---

## 11. Emulator/Extension Interface

The CA-80 was designed to be extensible via an "emulator" port (separate hardware, not the same as software emulation). The monitor checks for an extension at boot:

1. Read PA bit 0 — if `1`, an extension is signalled
2. Branch to `EMINIT` (@ 0x0603 in MIK11)

In the MIK290 configuration, EMINIT is simplified compared to older variants. It only checks the C930 ROM signature:
```
EMINIT:
    LD A, (0x8001)
    CP 0xAA
    JP NZ, ERROR
    JP 0x8002
```

There is no longer an 8255-based bootstrap protocol (which existed in older MIK08 mainboards with a separate emulator port at I/O `0xE8`). MIK290 systems use the simpler signature check.

---

## 12. Implementation Reference

This section provides guidance for implementations of CA-80 hardware (FPGA, software emulator, or hybrid).

### 12.1 Required Components

A complete CA-80 implementation needs:

1. **Z80 CPU core** at 4 MHz
2. **64 KB linear address space** with 16+16+16+16 KB ROM/RAM split
3. **8255 PPI** functionality:
   - Mode 0 only (no handshaking)
   - BSR mode for individual bit set/reset
   - Proper read/write semantics on each port
4. **Z80 CTC** (or simplified equivalent):
   - At least Channel 0 with timer mode, prescaler /16, TC programmable, INT generation
   - Channel 1 not strictly required (can be stubbed)
5. **NMI generator** at 500 Hz, independent of CTC
6. **74123-equivalent pulse generator** for port 0xEC writes (~700 µs pulse, retriggerable)
7. **24-key keyboard input** with row/column matrix wiring per §6.5
8. **8-digit 7-segment display** with multiplexed refresh

### 12.2 Critical Behaviors to Verify

The following behaviors are essential for software compatibility:

- **TKLAW table at ROM[0x0300]** must contain the exact 24-byte sequence corresponding to R23 keyboard codes. See Appendix A for binary listing.
- **NMI rate must be exactly 500 Hz** ±2%; faster or slower will affect RTC accuracy and beep pitch.
- **CTC Channel 0 must generate a maskable INT** when programmed with CCR0=0x87, TC0=10, with vector composed from I-register and INTU0 (low byte = 0xD0).
- **Reset must NOT clear RAM** (or the EXIT routine and indirect vectors will be lost). Real hardware leaves RAM contents undefined at reset, but the CA80A boot sequence rebuilds them via TRAM copy.
- **PA bit 0 must reflect emulator presence** if extension is desired; otherwise tie LOW.

### 12.3 Common Pitfalls

- **CTC as NMI source.** Older CA-80 variants and some documentation describe NMI coming from CTC. This is **incorrect for MIK290**. The Ux oscillator is independent, and CTC channels are not connected to /NMI.
- **Sound at 250 Hz.** Some sources state the beep is 250 Hz. This is incorrect — 74123 is a one-shot, not a flip-flop. The beep frequency equals the NMI rate (500 Hz), with the 74123 just shaping each NMI tick into a clean speaker pulse.
- **Inverting BWYS bits for common-anode displays.** This is a hardware-side decision; the monitor writes the same patterns regardless. Implementations should choose at build time which polarity to use, or provide a runtime config (e.g., `--anode` flag in software).
- **Keyboard column ordering.** The four columns are L=0..3 from right to left on the physical faceplate. Bit assignments in PC are LOW = active, so the column code in the "real code" byte is `(L << 6)`.
- **F-keys outside command range.** Keys F1-F4 have table codes 0x14-0x17, *above* the 0x11 monitor command limit. Pressing them at the prompt yields "Err CA80" — this is correct behavior, not a bug.

### 12.4 Test Programs

Three small programs for sanity testing:

**1. Display key codes** (8 bytes @ 0xC000):
```
CD 84 01     CALL CIM       ; read key, code in A
DF 20        RST 18H + DB 20H  ; display A as 2 hex digits
C3 00 C0     JP 0xC000      ; loop
```
After `*G C000=`, each key press shows its table code on the display. Verify F1=17, F2=16, F3=15, F4=14, M=13, =/12, ./11, G/10, hex 0-F = 00-0F.

**2. Beep test:**
```
*3              ; built-in command
```
Should produce a brief 500 Hz beep.

**3. Memory editor + run:**
```
*D C000=        ; open editor at 0xC000
3E 55 .         ; LD A, 55H
3C .            ; INC A (becomes 56h)
DF 20 .         ; RST 18H + DB 20H (display A)
18 FB =         ; JR -5 (loop back to INC A) [verify offsets]
*G C000=
```
Should display incrementing values rapidly.

---

## Appendix A — Monitor ROM Image

### A.1 First 16 Bytes of CA80.BIN (MIK11)

```
0000: 00 00 00 00 C3 56 01 EF C5 CD C6 FF F5 4F 18 2B
```

The first 4 bytes are 0x00 (unused, reset effectively jumps via the JP at 0x0004 for compatibility with CALL-from-anywhere). Subsequent bytes are the start of various RST handlers and the cold-start jump vector.

### A.2 TKLAW Keyboard Translation Table (24 bytes @ ROM[0x0300])

This table maps "real codes" (column-encoded byte from PA after CSTSM processing) to "table codes" (0x00-0x17). The monitor scans this table linearly to translate.

| Table Code | Key Label | Real Code | Description                  |
|-----------:|:---------:|:---------:|------------------------------|
| 0x00       | 0         | 0xFB      | digit 0                      |
| 0x01       | 1         | 0xEF      | digit 1                      |
| 0x02       | 2         | 0xFD      | digit 2                      |
| 0x03       | 3         | 0xDF      | digit 3                      |
| 0x04       | 4         | 0xBB      | digit 4                      |
| 0x05       | 5         | 0xAF      | digit 5                      |
| 0x06       | 6         | 0xBD      | digit 6                      |
| 0x07       | 7         | 0x9F      | digit 7                      |
| 0x08       | 8         | 0x7B      | digit 8                      |
| 0x09       | 9         | 0x6F      | digit 9                      |
| 0x0A       | A         | 0x7D      | hex A                        |
| 0x0B       | B         | 0x5F      | hex B                        |
| 0x0C       | C         | 0x3B      | hex C                        |
| 0x0D       | D         | 0x2F      | hex D                        |
| 0x0E       | E         | 0x3D      | hex E                        |
| 0x0F       | F         | 0x1F      | hex F                        |
| 0x10       | G         | 0x7E      | Go (jump to address)         |
| 0x11       | .         | 0xBE      | SPAC (parameter separator)   |
| 0x12       | =         | 0xFE      | CR (execute / confirm)       |
| 0x13       | M         | 0x3E      | Monitor (return)             |
| 0x14       | F4        | 0xF7      | Function key F4 (= W in old CA80) |
| 0x15       | F3        | 0xB7      | Function key F3 (= X in old CA80) |
| 0x16       | F2        | 0x77      | Function key F2 (= Y in old CA80) |
| 0x17       | F1        | 0x37      | Function key F1 (= Z in old CA80) |

### A.3 TRAM Template (56 bytes @ ROM[0x05C8])

```
05C8: 66 FF                         ; DW TOS-27H = 0xFF66 (user SP init)
05CA: D1 C1 F1 DD E1 FD E1 E1 F9    ; EXIT: POP DE/BC/AF/IX/IY/HL, LD SP,HL
05D3: 00 00                         ; KROK: 2 NOPs (single-step patch point)
05D5: 21 00 C1                      ; LD HL, 0xC100  (HLUZYT)
05D8: FB                            ; EI
05D9: C3 00 C0                      ; JP 0xC000 (PCUZYT, default user code)
05DC: 00 00 00                      ; Pulapka1 (breakpoint 1, addr+byte)
05DF: 00 00 00                      ; Pulapka2 (breakpoint 2)
05E2: 10                            ; DLUG = 16 (default tape data length)
05E3: 25                            ; MAGSP = 0x25 (default tape speed)
05E4: FF                            ; GSTAT = 0xFF (monitor active flag)
05E5: FF                            ; ZESTAT = 0xFF (RTC enable)
05E6: C3 00 08                      ; M8: JP 0x0800
05E9: C3 87 04                      ; ERRMAG: JP ERROR (@ 0x0487)
05EC: C3 06 08                      ; EM: JP 0x0806
05EF: C3 03 08                      ; RTS: JP 0x0803
05F2: F6 FF                         ; IOCA APWYS: DW PWYS (= 0xFFF6)
05F4: C3 30 01                      ; CSTS: JP CSTSM (@ 0x0130)
05F7: C3 84 01                      ; CI: JP CIM (@ 0x0184)
05FA: C3 46 05                      ; AREST: JP RESTAR (@ 0x0546)
05FD: C9                            ; TNMIU: RET (default NMI hook = noop)
05FE: 00 00                         ; INTU/padding (DW 0)
```

This template is copied by LDDR to RAM at boot. After copy:
- EXIT code lands at RAM[0xFF99]+ (executable)
- Indirect vectors land at their EQU-declared addresses (FFB5+)
- IOCA group at FFC1+
- Final byte (0x00 from `DW 0`) at RAM[0xFFD1]

---

## Appendix B — Quick Reference

### B.1 I/O Ports

| Port | Name      | Direction | Use                                     |
|------|-----------|-----------|-----------------------------------------|
| 0xEC | SYGNAL    | OUT       | Sound trigger (any value)               |
| 0xF0 | PA        | IN        | Keyboard rows + tape                    |
| 0xF1 | PB        | OUT       | Display segments                        |
| 0xF2 | PC        | OUT       | Digit select + keyboard column          |
| 0xF3 | PPI ctrl  | OUT       | 8255 mode/BSR control                   |
| 0xF8 | CHAN0     | I/O       | CTC Ch0 (single-step debugger)          |
| 0xF9 | CHAN1     | I/O       | CTC Ch1 (internal timer, no INT)        |
| 0xFA | CHAN2     | I/O       | CTC Ch2 (reserved)                      |
| 0xFB | CHAN3     | I/O       | CTC Ch3 (reserved)                      |
| 0xFC | RESI      | OUT       | Clear maskable INT pending              |

### B.2 Key Memory Locations

| Address | Name    | Size | Description                          |
|---------|---------|------|--------------------------------------|
| 0xC000  | PCUZYT  | 0    | Default user program counter         |
| 0xC100  | HLUZYT  | 0    | Default user HL                      |
| 0xFF66  | (USP)   | 0    | Default user SP                      |
| 0xFF8D  | TOS     | 1    | Top of system stack                  |
| 0xFF99  | EXIT    | 18   | RAM-based exit routine (in RAM!)     |
| 0xFFA2  | KROK    | 2    | Single-step patch point              |
| 0xFFAB  | TLOC    | 3    | Breakpoint 1 (Pulapka1)              |
| 0xFFB1  | DLUG    | 1    | Tape data length                     |
| 0xFFB2  | MAGSP   | 1    | Tape speed                           |
| 0xFFB3  | GSTAT   | 1    | Monitor active flag                  |
| 0xFFB4  | ZESTAT  | 1    | RTC enable flag                      |
| 0xFFB5  | M8      | 3    | *8 command vector (JP 0x0800)        |
| 0xFFB8  | ERRMAG  | 3    | Tape error vector                    |
| 0xFFBB  | EM      | 3    | Emulator vector                      |
| 0xFFBE  | RTS     | 3    | Alternative boot vector              |
| 0xFFC1  | APWYS   | 2    | PWYS pointer (data)                  |
| 0xFFC3  | CSTS    | 3    | Keyboard scan vector                 |
| 0xFFC6  | CI      | 3    | Read key vector                      |
| 0xFFC9  | AREST   | 3    | Return-to-monitor vector             |
| 0xFFCC  | NMIU    | 3    | User NMI hook                        |
| 0xFFCF  | INTU    | 1    | IM 1 vector                          |
| 0xFFD0  | INTU0   | 2    | CTC Ch0 INT vector                   |
| 0xFFE8  | LCI     | 1    | Auxiliary timer (40 ms unit)         |
| 0xFFE9  | SYG     | 1    | Sound counter (2 ms unit)            |
| 0xFFEA  | TIME    | 1    | RTC tick                             |
| 0xFFEB  | MSEK    | 1    | Milliseconds (BCD)                   |
| 0xFFEC  | SETSEK  | 1    | Hundredths (BCD)                     |
| 0xFFED  | SEK     | 1    | Seconds (BCD)                        |
| 0xFFEE  | MIN     | 1    | Minutes (BCD)                        |
| 0xFFEF  | GODZ    | 1    | Hours (BCD)                          |
| 0xFFF0  | DNITYG  | 1    | Day of week                          |
| 0xFFF1  | DNIM    | 1    | Day of month                         |
| 0xFFF2  | MIES    | 1    | Month                                |
| 0xFFF3  | LATA    | 1    | Year                                 |
| 0xFFF4  | KLAW    | 1    | Last keyboard table code             |
| 0xFFF5  | SBUF    | 1    | Input buffer                         |
| 0xFFF6  | PWYS    | 1    | Display format control               |
| 0xFFF7  | BWYS    | 8    | Display buffer (8 digits)            |

### B.3 Monitor Commands

| Command | Action                                       |
|---------|----------------------------------------------|
| `*0`    | Display real-time clock                      |
| `*1`    | Set time                                     |
| `*2`    | Set date                                     |
| `*3`    | Sound test                                   |
| `*4`    | Tape input (read from cassette)              |
| `*5`    | Tape output (write to cassette)              |
| `*6`    | Compare two memory blocks                    |
| `*7`    | Move/fill memory block                       |
| `*8`    | Jump to user vector M8 (default: 0x0800)     |
| `*9`    | Hex calculator                               |
| `*A`    | Hex sum and difference                       |
| `*B`    | Block memory operations                      |
| `*C`    | Continuous memory dump                       |
| `*D`    | Memory dump/edit (interactive)               |
| `*E`    | Fill memory block with constant              |
| `*F`    | View/edit registers                          |
| `*G`    | Run user program                             |
| `*MC`   | Single-step debugger                         |
| `*80`   | Enter C800 sub-monitor (signature 0x55)      |
| `*89`   | Enter C930 sub-monitor (signature 0xAA)      |

The `M` key is special — it always returns to the monitor regardless of program state, via the NMI handler's M-detection routine.

### B.4 Useful Calling Conventions

**Display a byte via LBYTE (RST 18H):**
```assembly
LD A, value
RST 18H
DB 0x20         ; PWYS: 2 digits, position 0
; (returns here, parameter consumed)
```

**Display an address via LADR (RST 20H):**
```assembly
LD HL, address
RST 20H
DB 0x40         ; PWYS: 4 digits, position 0
```

**Read a key via CIM (CALL):**
```assembly
CALL 0x0184     ; or CALL CIM symbolically
; A = table code (0x00-0x17)
; debouncing handled internally
```

**Return to monitor:**
```assembly
JP 0xFFC9       ; via AREST vector
; or:
JP 0x0546       ; direct to RESTAR (skip vector indirection)
```

---

*End of architecture reference. This document is verified against MIK11 monitor source listing, MIK09/MIK11 hardware documentation, and physical CA-80 testing as of 2026-04. For implementation examples, see the Python emulator in this repository (`ca80.py`, `ca80_memory.py`, `ca80_ports.py`, `ca80_sound.py`).*
