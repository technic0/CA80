# CA80 Microcomputer — Complete System Architecture

## FPGA Reconstruction Reference (Monitor V3.0 / MIK08)

This document describes the complete hardware and software architecture of the CA80 educational microcomputer, designed by **Stanisław Gardynik** (05-590 Raszyn, Poland) in the early 1980s. It synthesizes the detailed subsystem analyses into a unified architectural view suitable for FPGA reconstruction (MiSTer platform).

All technical details are verified against the original Monitor V3.0 source code (MIK08, assembled with MACRO-80 3.44, dated 09-Dec-81, copyright 1987).

---

## 1. System Overview

The CA80 is a single-board educational microcomputer built around the **Zilog Z80A CPU** running at **4 MHz**. It was designed to teach assembly language programming and microprocessor concepts. The system is intentionally minimal — only three ICs beyond the CPU provide all peripheral functions:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CA80 SYSTEM BLOCK DIAGRAM                    │
│                                                                     │
│  ┌──────────┐     ┌───────────┐     ┌──────────────────────────┐   │
│  │  Z80A    │────▶│  2KB ROM  │     │  System RAM              │   │
│  │  CPU     │────▶│  (EPROM)  │     │  (FF8DH-FFFEH)           │   │
│  │  4 MHz   │     │ 0000-07FF │     │  ~115 bytes              │   │
│  └────┬─────┘     └───────────┘     └──────────────────────────┘   │
│       │                                                             │
│       │  Address/Data/Control Bus                                   │
│       │                                                             │
│  ┌────┴────────────────────────────────────────────────────────┐    │
│  │                                                             │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │    │
│  │  │  8255 PPI    │  │  Z80A CTC    │  │  74145 Decoder   │  │    │
│  │  │  (System)    │  │  (Timer)     │  │  (BCD→Decimal)   │  │    │
│  │  │  F0-F3H      │  │  F8-FBH      │  │                  │  │    │
│  │  └──┬───┬───┬───┘  └──┬───┬──────┘  └────────┬─────────┘  │    │
│  │     │   │   │         │   │                    │            │    │
│  │     │   │   │         │   └── NMI pin          │            │    │
│  │     │   │   │         └── Step interrupt        │            │    │
│  │     │   │   │                                   │            │    │
│  │     PA  PB  PC ─────────────────────────────────┘            │    │
│  │     │   │                                                    │    │
│  │     │   └── 7-Segment LED Data (8 digits)                   │    │
│  │     │                                                        │    │
│  │     ├── Keyboard Matrix Input (bits B6-B4)                  │    │
│  │     ├── Tape Input (bit B7)                                 │    │
│  │     ├── Tape Output (bit B4)                                │    │
│  │     └── Hardware Config (bits B2-B0)                        │    │
│  │                                                             │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  Optional:  ┌──────────────┐                                       │
│             │  8255 PPI    │                                       │
│             │  (Emulator)  │                                       │
│             │  E8-EBH      │                                       │
│             └──────────────┘                                       │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.1 Design Philosophy

The CA80 achieves remarkable functionality from minimal hardware by shifting complexity into software:

- **No display controller** — display multiplexing done in NMI software
- **No keyboard controller** — matrix scanning done in NMI software
- **No UART or tape controller** — cassette I/O done by CPU bit-banging
- **No RTC chip** — clock/calendar maintained by NMI software counter cascade
- **No dedicated interrupt controller** — NMI serves as universal system tick

The entire operating system (Monitor) fits in **2 KB of ROM** and uses only **~115 bytes of RAM**.

---

## 2. CPU and Bus Architecture

### 2.1 Z80A CPU

| Parameter | Value |
|:----------|:------|
| Processor | Zilog Z80A |
| Clock frequency | 4.000 MHz |
| Instruction set | Standard Z80 (no undocumented opcodes used) |
| Interrupt mode | IM 1 (default) or IM 2 (if PA0=1 at boot) |
| NMI | Edge-triggered, connected to CTC Channel 1 output |
| Interrupt vector base | I register = FFH (vector table at FF00H–FFFFH) |

### 2.2 Bus Timing

All I/O operations use standard Z80 timing:
- Memory read/write: 3 T-states (no wait states in standard configuration)
- I/O read/write: 4 T-states (includes automatic IORQ wait state)
- Instruction fetch: 4 T-states (M1 cycle)

### 2.3 Address Decoding

The CA80 uses simple address decoding with active-select strobes:

| Strobe | Device | Address Range | Trigger |
|:-------|:-------|:-------------|:--------|
| PSYS | System 8255 PPI | F0H–F3H | I/O address match |
| CTF8 | Z80A CTC | F8H–FBH | I/O address match |
| EME8 | Emulator 8255 PPI | E8H–EBH | I/O address match (optional) |
| — | SYGNAL (speaker) | ECH | I/O write |
| — | RESI (INT reset) | FCH | I/O write |

Memory address decoding:
- 0000H–07FFH: ROM (active on /MREQ + /RD, A11–A15 = 0)
- RAM at top of address space (exact decoding depends on board variant)
- User RAM typically C000H–FDFFH (depending on expansion)

---

## 3. Memory Map

### 3.1 Complete Address Space

```
0000H ┌──────────────────────────────────┐
      │  Monitor ROM (2 KB)              │
      │  Program code, tables, data      │
      │  RST vectors at 0000–0038H       │
      │  NMI handler at 0066H            │
07FFH └──────────────────────────────────┘
0800H ┌──────────────────────────────────┐
      │  User-accessible space           │
      │  0800H: User command *8 target   │
      │  0803H: Alternate boot (RTS)     │
      │  0806H: Emulator entry point     │
      │                                  │
      │  (Available for user RAM/ROM)    │
      │                                  │
BFFFH └──────────────────────────────────┘
C000H ┌──────────────────────────────────┐
      │  Default user program area       │
      │  C000H: Default PC (PCUZYT)      │
      │  C100H: Default HL (HLUZYT)      │
      │                                  │
      │  (Available for user RAM)        │
      │                                  │
FF8CH └──────────────────────────────────┘
FF8DH ┌──────────────────────────────────┐
      │  System RAM (~115 bytes)         │
      │  FF8DH: TOS (stack bottom)       │
      │  FF8D–FF98: User register store  │
      │  FF99–FFA8: EXIT procedure (code │
      │             executed from RAM!)  │
      │  FFA9–FFAA: User PC              │
      │  FFAB–FFB0: Breakpoint storage   │
      │  FFB1–FFB2: Tape parameters      │
      │  FFB3–FFB4: System flags         │
      │  FFB5–FFD1: Indirect jump vectors│
      │  FFD0–FFDF: Interrupt vectors    │
      │  FFE0–FFE7: Reserved             │
      │  FFE8–FFEA: System counters      │
      │  FFEB–FFF3: RTC registers        │
      │  FFF4–FFF6: Keyboard/display ctrl│
      │  FFF7–FFFE: Display buffer       │
FFFEH └──────────────────────────────────┘
```

### 3.2 ROM Internal Structure (0000H–07FFH)

```
0000H  ┌─ Cold reset entry (LD A,90H; OUT F3H; JP 0241H)
0007H  ├─ RST 08H: TI (text input with echo)
0010H  ├─ RST 10H: CLR (clear display)
0018H  ├─ RST 18H: LBYTE (display byte as hex)
0020H  ├─ RST 20H: LADR (display address as hex)
0028H  ├─ RST 28H: USPWYS (set display parameter)
0030H  ├─ RST 30H: RESTA (software breakpoint)
0034H  ├─ KO2: "Err" message data
0038H  ├─ RST 38H: JP INTU (maskable interrupt)
003BH  ├─ Display routine continuations
0066H  ├─ NMI handler (keyboard, RTC, display, M-key)
0130H  ├─ CSTSM: keyboard matrix scan
015DH  ├─ KONW: key code translation
0170H  ├─ MA: hex arithmetic command
0184H  ├─ CIM: keyboard input with debounce
01A2H  ├─ CRSPAC: CR/SPAC classifier
01ABH  ├─ COM/COM1: character display
01D4H  ├─ PRINT: string display
01E0H  ├─ CO/CO1: hex digit display
01F4H  ├─ PARAM: hex number input
0213H  ├─ EXPR: multi-number input
022DH  ├─ CZAS: time/date display
023BH  ├─ HILO: address comparison utility
0241H  ├─ CA80A: main initialization
0270H  ├─ START: Monitor main loop
02A7H  ├─ CTBL: command dispatch table (18 × 2 bytes)
02C9H  ├─ M0–M2: clock/calendar commands
0300H  ├─ TKLAW: keyboard translation table (24 bytes)
0318H  ├─ TSIED: 7-segment patterns (16 bytes)
0328H  ├─ TABC: time limits table (5 bytes)
032DH  ├─ TABM: month day-count table (12 bytes)
0339H  ├─ KO1: "CA80" boot message (5 bytes)
033EH  ├─ MC: single-step command
0372H  ├─ MD: memory display/modify
0397H  ├─ ME: memory fill
03AEH  ├─ MF: register view/modify
0442H  ├─ ACTBL: register address table
0466H  ├─ MG: go to user program
0487H  ├─ ERROR: error handler
04B4H  ├─ M3: register swap
04CBH  ├─ M7: system init / tape speed
04DEH  ├─ M9: word search
04FFH  ├─ MB: block move
052FH  ├─ MWCIS: forced Monitor return
0546H  ├─ RESTAR: save user state
05BDH  ├─ EMUL: emulator check
05C8H  ├─ TRAM: RAM initialization template
0603H  ├─ EMINIT: emulator bootstrap
061DH  ├─ M4: tape save
0626H  ├─ ZMAG: core tape write
0674H  ├─ M5: tape save EOF
0697H  ├─ SYNCH: tape sync write
06A7H  ├─ PBYT/PBYTE: tape byte write
06DCH  ├─ GZER: tape zero-bit generation
06E7H  ├─ GJED: tape one-bit generation
06FEH  ├─ GJEDD: tape double-one generation
0702H  ├─ DEL02: tape timing delay
0709H  ├─ RESMAG: tape output reset
0714H  ├─ M6: tape load
071BH  ├─ OMAG: core tape read
0779H  ├─ RBYT: tape byte read
07D6H  ├─ LICZ: tape sample counter
07FFH  └─ End of ROM
```

### 3.3 Critical Page-Alignment Constraints

Several data structures must reside within a single 256-byte page for the addressing arithmetic to work:

| Structure | Address Range | Constraint |
|:----------|:-------------|:-----------|
| TKLAW | 0300H–0317H | Must start at page boundary (03xxH). KONW uses low byte as table code. |
| TSIED | 0318H–0327H | Must be within same page. CO1 adds digit value to L byte. |
| TABC + TABM | 0328H–0338H | Must be contiguous and within same page. NMI cascade pointer walks through both. |
| BWYS | FFF7H–FFFEH | Must be within a page. NMI display routine adds digit index to L byte. |

---

## 4. I/O Port Architecture

### 4.1 Complete I/O Map

```
Port   Device          Direction    Function
────   ──────          ─────────    ────────
E8H    8255 PPI #2     Input        Emulator data input (optional)
E9H    8255 PPI #2     Output       Emulator data output (optional)
EAH    8255 PPI #2     Mixed        Emulator handshake (optional)
EBH    8255 PPI #2     Control      Emulator config (optional)
ECH    SYGNAL          Output       Speaker toggle (beep generation)
F0H    8255 PPI #1     Input        PA: Keyboard + Tape input + Config
F1H    8255 PPI #1     Output       PB: 7-segment data (active-low)
F2H    8255 PPI #1     Output       PC: Digit select + Keyboard scan
F3H    8255 PPI #1     Control      8255 config + bit set/reset
F8H    Z80A CTC        Mixed        Channel 0: Single-step timer
F9H    Z80A CTC        Mixed        Channel 1: NMI heartbeat (500 Hz)
FAH    Z80A CTC        Mixed        Channel 2: User available
FBH    Z80A CTC        Mixed        Channel 3: User available
FCH    RESI            Output       Clear maskable interrupt

All other I/O addresses: unassigned (active decoding only on strobes)
```

### 4.2 System 8255 PPI — Detailed Bit Map

**Port A (F0H) — Input:**

```
Bit 7: Tape audio input (playback signal from cassette)
Bit 6: Keyboard column sense line 2
Bit 5: Keyboard column sense line 1
Bit 4: Keyboard column sense line 0 / Tape audio output (MIK94)
Bit 3: (unused by Monitor)
Bit 2: PA2 — Hardware config: Emulator present (1 = jump to EMINIT)
Bit 1: PA1 — Hardware config: Alternate boot (1 = jump to RTS/0803H)
Bit 0: PA0 — Hardware config: Interrupt mode (1 = IM 2 via CTC)
```

**Port B (F1H) — Output (display segments, active-low):**

```
Bit 7: Segment K (decimal point)
Bit 6: Segment G (middle horizontal)
Bit 5: Segment F (upper-left vertical)
Bit 4: Segment E (lower-left vertical)
Bit 3: Segment D (bottom horizontal)
Bit 2: Segment C (lower-right vertical)
Bit 1: Segment B (upper-right vertical)
Bit 0: Segment A (top horizontal)

    AAA
   F   B        Software writes positive logic (1=ON) to BWYS buffer.
   F   B        NMI complements (CPL) before output to Port B.
    GGG         Hardware: 0 = segment ON, 1 = segment OFF.
   E   C
   E   C
    DDD  K
```

**Port C (F2H) — Output (shared: display + keyboard):**

```
Bit 7: Display digit select (to 74145 input C)
Bit 6: Display digit select (to 74145 input B)
Bit 5: Display digit select (to 74145 input A)
Bit 4: (varies by board — keyboard or tape related)
Bit 3: Keyboard row select bit 3
Bit 2: Keyboard row select bit 2
Bit 1: Keyboard row select bit 1
Bit 0: Keyboard row select bit 0
```

---

## 5. Interrupt Architecture

The CA80 uses a hybrid interrupt scheme where the NMI provides the system heartbeat, and maskable interrupts are available for user programs and single-step execution.

### 5.1 NMI (Non-Maskable Interrupt)

```
Source:     Z80A CTC Channel 1 output (ZC/TO1)
Frequency:  ~500 Hz (every 2 ms)
Vector:     Fixed at 0066H (Z80 hardware)
Priority:   Highest (cannot be masked by DI instruction)
```

The NMI handler is the **central nervous system** of the CA80. Every 2 ms, it performs:

```
NMI Entry (0066H)
    │
    ├── 1. Save registers (PUSH AF, HL, DE, BC)
    │
    ├── 2. Keyboard scan timing
    │   ├── Decrement LCI counter (debounce timer)
    │   └── If SYG > 0: toggle SYGNAL port (beep)
    │
    ├── 3. Decrement TIME counter (user-accessible 2ms timer)
    │
    ├── 4. RTC update (if ZESTAT ≠ 0)
    │   └── Cascade: MSEK → SETSEK → SEK → MIN → GODZ
    │       └── On day rollover: DNITYG, DNIM, MIES, LATA
    │
    ├── 5. Display refresh
    │   ├── Advance SBUF digit counter
    │   ├── Blank segments (anti-ghosting)
    │   ├── Select next digit via 74145
    │   └── Output segment pattern from BWYS buffer
    │
    ├── 6. M-key detection (emergency override)
    │   ├── Force-scan M-key column on keyboard matrix
    │   ├── If M pressed AND GSTAT=0 (user program running):
    │   │   └── JP MWCIS → forced return to Monitor
    │   └── If M not pressed or Monitor already active: continue
    │
    ├── 7. Call NMIU (FFCCH) — user NMI hook (default: RET)
    │
    └── 8. Restore registers, RETN
```

**Timing budget**: At 4 MHz, 2 ms = 8,000 T-states. The NMI handler must complete within this budget. Typical execution is ~200–400 T-states (well within budget), except during RTC day/month cascade which adds ~100 T-states.

### 5.2 Maskable Interrupts (INT)

```
Mode:       IM 1 (default) or IM 2 (if PA0=1)
Vector:     RST 38H (IM 1) → JP INTU (FFCFH) → JP ERROR (default)
            IM 2: I=FFH, vector table at FFD0H–FFDFH
```

Maskable interrupts are used for:
- **CTC Channel 0**: Single-step execution. CCR0=87H, TC0=10 → interrupt after 160 T-states. Vector via INTU0 (FFD0H).
- **User programs**: Channels 2–3 and INTU1–INTU7 available.
- **Default handler**: JP ERROR (displays "Err").

### 5.3 Software Interrupts (RST)

The Z80's RST instructions are used as system calls:

| RST | Address | Name | Function |
|:----|:--------|:-----|:---------|
| RST 08H | 0007H | TI | Text input with echo |
| RST 10H | 0010H | CLR | Clear display |
| RST 18H | 0018H | LBYTE | Display byte as hex |
| RST 20H | 0020H | LADR | Display address as hex |
| RST 28H | 0028H | USPWYS | Set display parameter |
| RST 30H | 0030H | RESTA | Software breakpoint |
| RST 38H | 0038H | (INT) | Maskable interrupt entry |

---

## 6. Subsystem Interactions

### 6.1 Resource Sharing on the 8255

The system 8255 PPI is the critical shared resource. Three subsystems — display, keyboard, and tape — all use the same physical ports simultaneously. The Monitor manages this sharing through careful software coordination:

```
                    8255 PPI (F0H-F3H)
                    ┌────────────────┐
    Tape Input ────▶│ PA bit 7       │
    Kbd Return ────▶│ PA bits 6-4    │
    HW Config  ────▶│ PA bits 2-0    │
                    │                │
    Segments   ◀────│ PB bits 7-0    │──▶ LED Display
                    │                │
    Digit Sel  ◀────│ PC bits 7-5    │──▶ 74145 → LED Commons
    Kbd Scan   ◀────│ PC bits 3-0    │──▶ Keyboard Matrix
    Tape Out   ◀────│ (via BSR/KLAW) │──▶ Cassette Recorder
                    └────────────────┘
```

**Conflict resolution:**

| Conflict | Resolution |
|:---------|:-----------|
| Display vs. Keyboard on Port C | NMI display routine writes full PC (digit + keyboard state). Keyboard scanner uses 8255 BSR mode to modify only PC0–3 without touching PC5–7. |
| Tape output vs. Display on Port C | MIK90: Tape uses BSR on a specific PC bit. MIK94: Tape uses PA directly via KLAW shadow. |
| Tape output vs. Keyboard on PA | KLAW shadow register (FFF4H) preserves tape output state across keyboard scans. NMI saves/restores KLAW during M-key detection. |
| Tape input during NMI | No conflict — tape input (PA bit 7) is read-only. NMI does not affect PA bit 7 reads. However, NMI execution adds timing jitter to tape operations. |

### 6.2 NMI as System Tick — Everything Runs Off One Timer

```
Z80A CTC Channel 1
    │
    └── ZC/TO1 → NMI (500 Hz)
         │
         ├── Keyboard debounce timing (LCI counter, 40ms resolution)
         ├── Keyboard beep generation (SYG counter, toggles SYGNAL at 250 Hz)
         ├── General-purpose timer (TIME counter, 2ms resolution)
         ├── RTC clock (MSEK→SETSEK→SEK→MIN→GODZ, 10ms resolution)
         ├── RTC calendar (DNITYG→DNIM→MIES→LATA, 1-day resolution)
         └── Display multiplexing (SBUF counter, 62.5 Hz refresh rate)
```

All system timing derives from the single CTC Channel 1 output. There is no other clock source. This means:
- If NMI stops, **everything** stops: display goes dark, keyboard is dead, clock freezes.
- NMI frequency accuracy directly determines RTC accuracy.
- Tape I/O operates **during** NMI service — the DEL02 timing loop runs on CPU cycles with NMI interruptions included in the effective delay.

---

## 7. Boot Sequence

### 7.1 Power-On Reset Flow

```
RESET pin asserted
    │
    ▼
0000H: LD A,90H              ──── Configure 8255: PA=in, PB+PC=out
0002H: OUT (F3H),A
0004H: JP 0241H              ──── Jump to main initialization
    │
    ▼
0241H: LD SP,FF8DH           ──── Set system stack pointer
    │
    ├── Copy TRAM → RAM       ──── Initialize FF97H–FFD1H from ROM template
    │   (LDDR, 59 bytes)           Sets up: EXIT code, KROK, user PC/HL/SP,
    │                              breakpoints, tape params, flags,
    │                              all indirect jump vectors
    │
    ├── LD I,FFH              ──── Set interrupt vector base
    ├── IM 1                  ──── Default interrupt mode
    │
    ├── Init CTC Channel 0    ──── Write INTU0 vector (D0H) for step execution
    │
    ├── Init CTC Channel 1    ──── CCR1=07H, TC1=FAH → NMI starts at 500 Hz
    │                              *** System is now ALIVE — NMI fires! ***
    │
    ├── IN A,(PA)             ──── Read hardware configuration
    │   ├── PA0=1? → IM 2     ──── Switch to vectored interrupts
    │   ├── PA1=1? → JP RTS   ──── Alternate boot to 0803H
    │   └── PA2=1? → JP EMINIT ── Initialize emulator hardware
    │
    ▼
0270H: START                  ──── Monitor main loop
    ├── LD SP,FF8DH           ──── Reset stack
    ├── RST CLR / DB 80H      ──── Clear all 8 display digits
    ├── Print "CA80"           ──── Display boot message
    ├── CALL EMUL             ──── Check emulator status
    ├── RST TI / DB 17H       ──── Wait for first keypress
    │
    ▼
    Command dispatch loop:
    ├── Read key → validate (0–G, 18 commands)
    ├── Lookup CTBL[key] → get procedure address
    ├── JP (HL) → execute command
    └── All commands return to START
```

### 7.2 M-Key Warm Reset

Pressing M during user program execution triggers a warm reset:

```
NMI detects M key AND GSTAT=0
    │
    ▼
052FH: MWCIS
    ├── DI                    ──── Disable interrupts
    ├── Re-initialize IOCA    ──── Restore APWYS, CSTS, CI, AREST, NMIU
    │   (LDDR from ROM)            to default jump targets
    ├── Set GSTAT ≠ 0         ──── Mark Monitor as active
    ├── OUT (RESI),A          ──── Clear pending interrupts
    └── JP EXIT → START       ──── Return to Monitor loop
```

---

## 8. Monitor Command Set

### 8.1 Command Dispatch

The Monitor accepts single-key commands (hex digits 0–G). Each key maps to a handler address in the CTBL table at 02A7H:

| Key | Command | Address | Function |
|:----|:--------|:--------|:---------|
| 0 | *0 | 02C9H (M0) | Display clock (GODZ/MIN/SEK, then date on keypress) |
| 1 | *1 | 02DCH (M1) | Set time (GODZ SPAC MIN SPAC SEK CR) |
| 2 | *2 | 02EDH (M2) | Set date (ROK SPAC MIES SPAC DNIM SPAC DNITYG CR) |
| 3 | *3 | 04B4H (M3) | Swap main ↔ alternate register sets |
| 4 | *4 | 061DH (M4) | Save to tape (ADR1 SPAC ADR2 SPAC NAZWA CR) |
| 5 | *5 | 0674H (M5) | Save EOF record to tape (ENTRY SPAC NAZWA CR) |
| 6 | *6 | 0714H (M6) | Load from tape (NAZWA CR) |
| 7 | *7 | 04CBH (M7) | System init (CR) or set tape speed (MAGSP DLUG CR) |
| 8 | *8 | FFB5H (M8) | User command (default: JP 0800H, patchable) |
| 9 | *9 | 04DEH (M9) | Search 8/16-bit word in 16KB |
| A | *A | 0170H (MA) | Hex sum and difference |
| B | *B | 04FFH (MB) | Block move (intelligent LDIR/LDDR) |
| C | *C | 033EH (MC) | Single-step execution |
| D | *D | 0372H (MD) | Memory display/modify |
| E | *E | 0397H (ME) | Fill memory with constant |
| F | *F | 03AEH (MF) | Register view/modify (flags + registers) |
| G | *G | 0466H (MG) | Go — run user program (with optional breakpoints) |

### 8.2 Debugging Capabilities

The Monitor provides a complete debugging environment:

**Single-step execution (*C):**
- Uses CTC Channel 0 in timer mode (160 T-state interrupt)
- Patches the EXIT procedure with `OUT (0F4H),A` (triggers CTC)
- After one user instruction executes, CTC interrupt fires and returns to Monitor
- Displays current PC and the opcode at (PC)

**Breakpoints (*G with traps):**
- Up to 2 breakpoints supported
- Original opcode saved in TLOC (FFABH–FFB0H)
- RST 30H (opcode F7H) inserted at breakpoint address
- RESTAR procedure detects trap, restores original opcode, saves user state

**Register inspection (*F):**
- Displays flag indicators (S, Z, H, P, N, C) with toggle capability
- Displays and allows modification of all registers: A, B, C, D, E, H, L, F, PC, SP, IX, IY

---

## 9. Software Architecture — RAM as Execution Space

### 9.1 Code in RAM (EXIT Procedure)

A unique architectural feature: the EXIT procedure (entry to user program) resides in **RAM** at FF99H, not ROM. This allows the single-step mechanism to dynamically patch the instruction stream:

```
FF99H: EXIT    POP DE; POP BC; POP AF; POP IX; POP IY; POP HL; LD SP,HL
FFA2H: KROK    NOP; NOP              ← Patched to OUT (0F4H),A for stepping
FFA4H:         LD HL,HLUZYT; EI; JP PCUZYT
```

Normal execution: KROK = NOP; NOP → user program runs freely.
Step mode: KROK = OUT (0F4H),A → triggers CTC Ch0 interrupt after one instruction.

### 9.2 Patchable Indirect Jumps

System routines are called through **indirect jump vectors in RAM**, allowing user programs to intercept or redirect system services:

| Vector | Default | Purpose | Typical User Patch |
|:-------|:--------|:--------|:-------------------|
| CSTS (FFC3H) | JP CSTSM | Keyboard status | Custom keyboard driver |
| CI (FFC6H) | JP CIM | Keyboard input | Serial terminal input |
| AREST (FFC9H) | JP RESTAR | Breakpoint handler | Custom debugger |
| NMIU (FFCCH) | RET | User NMI hook | Background processing |
| INTU (FFCFH) | JP ERROR | INT handler | User interrupt service |
| M8 (FFB5H) | JP 0800H | User command *8 | Custom command |
| ERRMAG (FFB8H) | JP ERROR | Tape error | Custom error handler |
| EM (FFBBH) | JP 0806H | Emulator | Custom emulator entry |
| RTS (FFBEH) | JP 0803H | Alternate boot | Custom boot sequence |

These vectors are re-initialized from ROM templates:
- **At power-on**: TRAM (05C8H) → FF97H–FFD1H (all vectors)
- **On M-key press**: IOCA (05F2H) → FFC1H–FFCCH (core system vectors only)

---

## 10. Timing Relationships

### 10.1 System Timing Chain

```
4 MHz Crystal
    │
    ├── CPU clock: 250 ns per T-state
    │
    ├── CTC Ch1 ÷4000 → NMI at 500 Hz (2.000 ms period)
    │   │
    │   ├── Display refresh: 1 digit per NMI → 62.5 Hz full refresh
    │   ├── MSEK: 5 NMI ticks → 10 ms per SETSEK increment
    │   ├── SETSEK: 100 ticks → 1.000 second
    │   ├── LCI debounce: 20 ticks → 40 ms
    │   ├── SYG beep: 50 ticks → 100 ms, tone at 250 Hz
    │   └── TIME counter: 1 tick = 2 ms (user timer)
    │
    ├── CTC Ch0: 160 T-states → 40 µs (single-step interrupt)
    │
    └── Tape timing: DEL02 loop × MAGSP
        └── ~150 µs per sample at MAGSP=37
            ├── Zero bit: 20 samples = 3.0 ms
            ├── One bit: 20 samples = 3.0 ms
            └── Byte: ~13 bits × 3 ms ≈ 39 ms → ~25 bytes/sec
```

### 10.2 Critical Timing for FPGA

| Timing Requirement | Tolerance | Effect of Error |
|:-------------------|:----------|:----------------|
| CPU clock = 4.000 MHz | ±0.01% | RTC drift, tape decode failure |
| CTC Ch1 ÷4000 exact | ±0 | Each error = ±21.6 sec/day RTC drift |
| NMI edge detection | Correct edge polarity | Missing NMI = system freeze |
| DAA instruction timing | Exact T-states | Incorrect BCD arithmetic |
| DEL02 loop: DEC A; JR NZ | 4+12=16 T-states/iter | Tape speed mismatch |
| RLCA timing | 4 T-states | Display digit addressing errors |

---

## 11. Emulator Interface (Optional)

The CA80 supports an optional **EME8 emulator board** connected via a second 8255 PPI at E8H–EBH. This was used for in-circuit emulation of target hardware.

### 11.1 Detection and Bootstrap

At boot, the Monitor checks PA2 of the system 8255:
- PA2 = 0: No emulator, normal boot.
- PA2 = 1: Emulator present → jump to EMINIT (0603H).

EMINIT loads a 128-byte bootstrap program from the emulator's 8255 (Mode 1 buffered input) into RAM at FF00H–FF7FH, then jumps to FF00H. This bootstrap presumably initializes the emulator hardware and enters a debug/control loop.

### 11.2 Emulator 8255 Configuration

```
KONF1 = B4H: Mode 1 — PA = buffered input, PB = buffered output
             PC bits used for handshake (INTE, OBF, IBF, ACK, STB)
```

During bootstrap loading, PC4 (INTE A) is set to enable input buffer interrupts, and the code polls PC3 (IBF flag) to detect when new data is available.

---

## 12. FPGA Implementation — Architectural Summary

### 12.1 Required Components

```
┌─────────────────────────────────────────────────────────────────┐
│                     MiSTer FPGA Core                            │
│                                                                 │
│  ┌──────────┐  ┌────────┐  ┌──────────┐  ┌──────────────────┐ │
│  │ T80 CPU  │  │ 2KB    │  │ RAM      │  │ Virtual 8255     │ │
│  │ (Z80A)   │  │ ROM    │  │ (64KB    │  │ PPI              │ │
│  │ 4 MHz    │  │ Image  │  │  total)  │  │ F0-F3H           │ │
│  └────┬─────┘  └────────┘  └──────────┘  └──┬───┬───┬───────┘ │
│       │                                      │   │   │         │
│       │  ┌──────────┐                    PA  PB  PC            │
│       ├──│ Z80 CTC  │                    │   │   │             │
│       │  │ F8-FBH   │──── NMI ──────────▶│   │   │             │
│       │  └──────────┘                    │   │   │             │
│       │                                  │   │   │             │
│  ┌────┴──────────────────────────────────┴───┴───┴─────────┐  │
│  │                    Glue Logic                            │  │
│  │                                                          │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │  │
│  │  │ Keyboard     │  │ Display      │  │ Tape         │  │  │
│  │  │ Mapper       │  │ Capture &    │  │ WAV/CAS      │  │  │
│  │  │ (USB→HW code)│  │ Renderer     │  │ Interface    │  │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │  │
│  │                                                          │  │
│  │  ┌──────────────┐  ┌──────────────┐                     │  │
│  │  │ SYGNAL Port  │  │ RESI Port    │                     │  │
│  │  │ ECH (audio)  │  │ FCH (INT clr)│                     │  │
│  │  └──────────────┘  └──────────────┘                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Output: VGA/HDMI (7-seg rendering) + Audio (beep)             │
│  Input: USB keyboard mapping                                    │
└─────────────────────────────────────────────────────────────────┘
```

### 12.2 Implementation Checklist

| Component | Complexity | Critical Details |
|:----------|:-----------|:----------------|
| Z80 CPU (T80) | Use existing IP | Must have correct DAA, NMI edge latch, RETN behavior |
| 2KB ROM | Trivial | Load MIK08 binary image (pages 52–53 of source listing) |
| RAM | Trivial | 64KB SRAM, initialize top ~115 bytes per TRAM template |
| 8255 PPI | Medium | Must support Mode 0 + BSR. Port A input, PB+PC output. PA bit-level read for keyboard/tape. |
| Z80 CTC | Medium | Must support timer mode with prescaler. Channel 1 output → NMI. Channel 0 interrupt vector. |
| 74145 decode | Trivial | 3-to-8 decoder on PC bits 7-5 (or pass digit index directly to renderer) |
| Address decode | Simple | ROM at 0000–07FF, I/O strobes at E8, EC, F0, F3, F8, FC |
| Keyboard mapper | Simple | USB scancode → CA80 hardware keycode table (24 entries). Present on PA bits 6-4 when matching row scanned on PC. |
| Display renderer | Medium | Capture 8255 PB+PC writes, maintain 8-digit register array, render 7-seg shapes on video output. |
| Audio output | Simple | SYGNAL port (ECH) toggle → square wave → audio DAC. |
| Tape interface | Complex | WAV/CAS file → PA bit 7 (input). PA bit 4 capture → WAV (output). Or intercept OMAG for fast load. |

### 12.3 Verification Strategy

1. **Power-on test**: Core boots, displays "CA80" on virtual 7-segment display.
2. **Keyboard test**: Press keys 0–F, verify echo on display. Press G → command accepted.
3. **Memory test**: `*D 0000 CR` → browse ROM, verify correct hex dump.
4. **Register test**: `*F` → display flag indicators, toggle with 0-3 keys.
5. **RTC test**: `*1 12 00 00 CR` → set clock to 12:00:00. `*0` → verify clock advances correctly.
6. **Tape test**: `*4 C000 C0FF 01 CR` → save block. `*6 01 CR` → load back, verify data integrity.
7. **Step test**: Write simple program at C000H via `*D`, set `*G C000 CR`, use `*C` to single-step.
8. **24-hour soak**: Run RTC for 24 hours, compare to reference clock. ±1 second = pass.

---

## Appendix A: ROM Binary

The complete ROM image is provided on pages 52–53 of the MIK08 source listing as a hex dump. The binary is 2048 bytes (0000H–07FFH). The first bytes are:

```
0000: 3E 90 D3 F3 C3 41 02 EF C5 0E 00 CD FF C6 F5 4F
0010: EF C5 0E 08 06 08 18 29 4F EF 79 E5 d5 C3 0D 01
...
```

This hex dump can be directly converted to a .bin file for loading into the FPGA ROM.
