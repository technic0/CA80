# CA80 Microcomputer Memory & I/O Map (Monitor V3.0)

This document provides a complete technical breakdown of the memory layout, I/O port mapping, system calls, and initialization sequence for the CA80 microcomputer, based on the original Monitor V3.0 assembly source code (MIK08, Copyright (C) 1987 Stanisław Gardynik, 05-590 Raszyn). Assembled with MACRO-80 3.44, dated 09-Dec-81.

---

## 1. Memory Address Space (Z80)

The CA80 uses a standard 64 KB address space. The Monitor ROM occupies the bottom 2 KB, and System RAM occupies the top ~115 bytes.

### 1.1 ROM Space (0000H – 07FFH)

Monitor ROM — 2 KB. The code uses `.PHASE 0` so logical addresses match physical ROM addresses.

#### Reset & Restart Vectors

| Address | Bytes | Label | Description |
|:--------|:------|:------|:------------|
| 0000H | 3E 90 | `CA80:` | Cold reset entry. `LD A,KONF` — load 8255 config word (90H). |
| 0002H | D3 F3 | | `OUT (CONTR),A` — configure system 8255 PPI. |
| 0004H | C3 0241 | | `JP CA80A` — jump to main initialization. |
| 0007H | EF | `TI:` | RST 08H → Text Input. Fetch key with echo to display. |
| 0008H | | `TI1:` | TI entry without PWYS setup. |
| 0010H | EF | `CLR:` | RST 10H → Clear display digits per PWYS parameter. |
| 0011H | | `CLR1:` | CLR entry without PWYS setup. |
| 0018H | | `LBYTE:` | RST 18H → Display register A as 2 hex digits. |
| 001BH | | `LBYTE1:` | LBYTE entry without PWYS setup. |
| 0020H | EF | `LADR:` | RST 20H → Display register HL as 4 hex digits. |
| 0021H | | `LADR1:` | LADR entry without PWYS setup. |
| 0028H | | `USPWYS:` | RST 28H → Set PWYS display parameter from inline byte. |
| 0030H | F3 | `RESTA:` | RST 30H → Software breakpoint. `DI; JP AREST`. |
| 0034H | 79 50 50 FF | `KO2:` | Error message string "Err" (7-seg codes + 0FFH terminator). |
| 0038H | C3 FFCF | | RST 38H → `JP INTU` — maskable interrupt dispatch (via RAM vector). |

#### Core Procedures (in ROM)

| Address | Label | Description |
|:--------|:------|:------------|
| 003BH | `TI1cd` | Continuation of TI procedure (display hex digit, check for CR/SPAC). |
| 0041H | `CLR2` | CLR inner loop (call COM1 to blank each digit). |
| 0048H | `LADRcd` | LADR continuation (display high byte). |
| 0055H | `USPWcd` | USPWYS continuation (fetch PCU, transfer PWYS value). |
| 0065H | `SPEC` | Simple `RET` instruction. Followed by `DB 85H` (year marker = 1985). |
| 0066H | `NMI:` | NMI Service Routine entry (keyboard, RTC, display, M-key check). |
| 00C2H | `ZKON1` | Display refresh subroutine within NMI. |
| 010DH | `LBYTcd` | LBYTE continuation (split byte into nibbles, display each). |
| 0130H | `CSTSM` | Core keyboard matrix scan routine. |
| 015DH | `KONW` | Key code conversion (real → table code via TKLAW lookup). |
| 0170H | `MA` | Command `*A` — hex addition and subtraction of two 16-bit numbers. |
| 0184H | `CIM` | Core keyboard input with debounce (wait release, wait press). |
| 01A2H | `CRSPAC` | Check if table key code in A is CR (12H) or SPAC (11H). |
| 01ABH | `COM` | Display 7-segment character code in C at PWYS position. |
| 01ACH | `COM1` | COM entry without PWYS setup. |
| 01D4H | `PRINT` | Print string from (HL), terminated by 0FFH. |
| 01D5H | `PRINT1` | PRINT entry without PWYS setup. |
| 01E0H | `CO` | Display hex digit (value in C, 0–FH) using TSIED lookup. |
| 01E1H | `CO1` | CO entry without PWYS setup. |
| 01F4H | `PARAM` | Input 4-digit hex number from keyboard into HL. |
| 01F5H | `PARAM1` | PARAM entry without PWYS setup. |
| 01F8H | `PARA1` | Like PARAM1 but first digit pre-loaded in A. |
| 0213H | `EXPR` | Input sequence of C hex numbers (SPAC-separated, CR-terminated). |
| 0214H | `EXPR1` | EXPR entry without PWYS setup. |
| 022DH | `CZAS` | Display time (HL=SEK) or date (HL=DNITYG). |
| 023BH | `HILO` | HL := HL+1, compute DE−HL. CY=0 if DE≥HL, CY=1 if DE<HL. |

#### Main Monitor Loop & Command Dispatch

| Address | Label | Description |
|:--------|:------|:------------|
| 0241H | `CA80A` | Main initialization (RAM init, CTC setup, IM configuration). |
| 0270H | `START` | Main loop: set SP=TOS, clear display, print "CA80", dispatch commands. |
| 0275H | `START1` | Command input loop (print prompt, read key, dispatch). |
| 02A7H | `CTBL` | Command dispatch table (18 entries × 2 bytes = 36 bytes). |

#### Monitor Commands (in ROM)

| Address | Label | Key | Description |
|:--------|:------|:----|:------------|
| 02C9H | `M0` | 0 | Display clock (GODZ/MIN/SEK, then ROK/MIES/DZIEN on keypress). |
| 02DCH | `M1` | 1 | Set time (*1 GODZ SPAC MIN SPAC SEK CR). |
| 02EDH | `M2` | 2 | Set date (*2 ROK SPAC MIES SPAC DNIM SPAC DNITYG CR). |
| 04B4H | `M3` | 3 | Swap main ↔ alternate register sets. |
| 061DH | `M4` | 4 | Save memory block to tape (*4 ADR1 SPAC ADR2 SPAC NAME CR). |
| 0674H | `M5` | 5 | Save EOF record to tape (*5 ENTRY_ADDR SPAC NAME CR). |
| 0714H | `M6` | 6 | Load program from tape (*6 NAME CR). |
| 04CBH | `M7` | 7 | System init (*7 CR) or set tape params (*7 MAGSP DLUG CR). |
| FFB5H | `M8` | 8 | User command (JP 0800H, patchable in RAM). |
| 04DEH | `M9` | 9 | Search for 8/16-bit word in 16KB memory. |
| 0170H | `MA` | A | Hex sum and difference of two 16-bit numbers. |
| 04FFH | `MB` | B | Block move (intelligent — uses LDIR or LDDR as appropriate). |
| 033EH | `MC` | C | Single-step execution (execute one user instruction, return). |
| 0372H | `MD` | D | Memory display/modify (browse, edit bytes). |
| 0397H | `ME` | E | Fill memory with constant (*E OD SPAC DO SPAC STALA CR). |
| 03AEH | `MF` | F | Register view/modify (flags S,Z,H,P,N,C + all registers). |
| 0466H | `MG` | G | Go — jump to user program (with optional 1 or 2 breakpoints). |

#### Data Tables (in ROM)

| Address | Label | Size | Description |
|:--------|:------|:-----|:------------|
| 0300H | `TKLAW` | 24 bytes | Keyboard translation table (real key code → table code). |
| 0318H | `TSIED` | 16 bytes | 7-segment digit patterns for hex digits 0–F. |
| 0328H | `TABC` | 5 bytes | RTC time limit table (WMSEK=5, SETSEK=0, SEK=60H, MIN=60H, GODZ=24H). |
| 032DH | `TABM` | 12 bytes | Days-per-month table (BCD: 32,29,32,31,32,31,32,32,31,32,31,32). |
| 0339H | `KO1` | 5 bytes | Boot message "CA80" (7-seg: 39H,77H,7FH,3FH,0FFH). |
| 042EH | `TFLAG` | 8 bytes | Flag indicator 7-seg patterns (S,O,-,H,P,N,C). |
| 0436H | `ACT1` | 12 bytes | Register name table (IX,IY,S,H,L,P — table code + 7-seg code pairs). |
| 0442H | `ACTBL` | 36 bytes | Register address/size table (12 registers × 3 bytes: name, address LSB, size). |

#### Tape Routines (in ROM)

| Address | Label | Description |
|:--------|:------|:------------|
| 0626H | `ZMAG` | Core tape write: sync + header + data blocks with checksums. |
| 067BH | `ZEOF` | Write EOF record to tape. |
| 0697H | `SYNCH` | Write 32-byte synchronization pattern (all zeros). |
| 06A2H | `PADR` | Write HL (2 bytes) to tape with checksum. |
| 06A7H | `PBYT` | Write byte in A to tape with checksum (D := D + A). |
| 06ABH | `PBYTE` | Write byte in A to tape without checksum. |
| 06DCH | `GZER` | Generate zero bit on tape (20 samples low). |
| 06E7H | `GJED` | Generate one bit on tape (16 samples high + 4 samples low). |
| 06FEH | `GJEDD` | Generate double-one bit (36 samples high + 4 samples low). |
| 0702H | `DEL02` | Tape timing delay (loop count from MAGSP variable). |
| 0709H | `RESMAG` | Reset tape output to zero state. |
| 071BH | `OMAG` | Core tape read: search for MARK, read header, verify checksums, load data. |
| 0779H | `RBYT` | Read one byte from tape with checksum. |
| 07D6H | `LICZ` | Tape bit sampling — count consecutive same-polarity samples. |

#### Breakpoint & Step Execution (in ROM)

| Address | Label | Description |
|:--------|:------|:------------|
| 0487H | `ERROR` | System error handler — display "Err", return to START1. |
| 0496H | `TRA1` | Set breakpoint(s) — save original opcode, insert RST 30H (F7H). |
| 052FH | `MWCIS` | Forced return to Monitor (M-key detected during user program). |
| 0546H | `RESTAR` | Save user CPU state, detect and remove breakpoints, return to Monitor. |
| 05BDH | `EMUL` | Check for emulator hardware (test PA2 bit of port A). |
| 05C8H | `TRAM` | RAM initialization template (copied to FF97H–FFD1H at power-on). |
| 05F2H | `IOCA` | System indirect jump table template (copied to FFC1H–FFCCH on M-key). |
| 0603H | `EMINIT` | Emulator bootstrap loader (loads 128 bytes via EME8, jumps to 0FF00H). |

---

### 1.2 User Space (Defaults)

| Address | Label | Description |
|:--------|:------|:------------|
| C000H | `PCUZYT` | Default User Program Counter. |
| C100H | `HLUZYT` | Default User HL Register value. |
| 0800H | — | User command `*8` jump target (via M8 indirect jump at FFB5H). |
| 0803H | — | RTS alternate boot entry (jumped to if PA1=1 at power-on). |
| 0806H | — | Emulator entry point (jumped to if PA2=1 at power-on). |

---

### 1.3 System RAM (FF8DH – FFFEH)

The Monitor uses a block of RAM at the top of the address space. There are two initialization domains:

- **FF97H–FFD1H**: Initialized at power-on from the `TRAM` table in ROM (via LDDR).
- **FFC1H–FFCCH**: Re-initialized on every M-key press (from `IOCA` table in ROM).

#### User Register Storage (FF8DH – FF98H)

| Address | Size | Label | Description |
|:--------|:-----|:------|:------------|
| FF8DH | 1 | `ELOC` | User register E. |
| FF8EH | 1 | `DLOC` | User register D. |
| FF8FH | 1 | `CLOC` | User register C. |
| FF90H | 1 | `BLOC` | User register B. |
| FF91H | 1 | `FLOC` | User register F (flags). |
| FF92H | 1 | `ALOC` | User register A (accumulator). |
| FF93H | 2 | — | User register IX (16-bit). |
| FF94H | — | `IXLOC` | EQU — points to high byte of IX storage. |
| FF95H | 2 | — | User register IY (16-bit). |
| FF96H | — | `IYLOC` | EQU — points to high byte of IY storage. |
| FF97H | 2 | — | User Stack Pointer (SP), low byte first. |
| FF98H | — | `SLOC` | EQU — points to high byte of SP storage. |

Note: `TOS` (FF8DH) is also the bottom of the system stack. The stack grows downward from here. `MTOP` = 0FFH (high byte of TOS address).

#### EXIT Procedure & Step Execution Area (FF99H – FFAAH)

This area contains executable Z80 code in RAM, copied from `TRAM` at power-on:

| Address | Size | Label | Default Content | Description |
|:--------|:-----|:------|:----------------|:------------|
| FF99H | 9 | `EXIT` | `POP DE; POP BC; POP AF; POP IX; POP IY; POP HL; LD SP,HL` | Restore user registers from stack. |
| FFA2H | 2 | `KROK` | `NOP; NOP` | Single-step slot. Patched to `OUT (0F4H),A` for step execution. |
| FFA4H | 5 | — | `LD HL,HLUZYT; EI; JP PCUZYT` | Load user HL, enable interrupts, jump to user PC. |
| FFA9H | 2 | — | Low, high bytes of user PC. |
| FFAAH | — | `PLOC` | EQU — points to high byte of user PC. |

#### Breakpoint Storage (FFABH – FFB0H)

| Address | Size | Label | Description |
|:--------|:-----|:------|:------------|
| FFABH | 2 | `TLOC` | Breakpoint 1 address (16-bit). |
| FFADH | 1 | — | Breakpoint 1 saved opcode. |
| FFAEH | 2 | — | Breakpoint 2 address (16-bit). |
| FFB0H | 1 | — | Breakpoint 2 saved opcode. |

#### Tape Parameters (FFB1H – FFB2H)

| Address | Size | Label | Default | Description |
|:--------|:-----|:------|:--------|:------------|
| FFB1H | 1 | `DLUG` | 10H (16) | Tape data block length (1–FFH bytes per block). |
| FFB2H | 1 | `MAGSP` | 25H (37) | Tape speed parameter (delay loop count). |

#### System Status Flags (FFB3H – FFB4H)

| Address | Size | Label | Default | Description |
|:--------|:-----|:------|:--------|:------------|
| FFB3H | 1 | `GSTAT` | 0FFH | System status: 0 = user program running, ≠0 = Monitor running. |
| FFB4H | 1 | `ZESTAT` | 0FFH | RTC enable: 0 = RTC disabled in NMI, ≠0 = RTC active. |

#### Indirect Jump Vectors (FFB5H – FFD1H)

These are 3-byte `JP xxxx` instructions in RAM, patchable by the user:

| Address | Size | Label | Default Code | Default Target | Description |
|:--------|:-----|:------|:-------------|:---------------|:------------|
| FFB5H | 3 | `M8` | `C3 00 08` | JP 0800H | User command `*8`. |
| FFB8H | 3 | `ERRMAG` | `C3 87 04` | JP ERROR | Tape read error handler. |
| FFBBH | 3 | `EM` | `C3 06 08` | JP 0806H | Emulator entry. |
| FFBEH | 3 | `RTS` | `C3 03 08` | JP 0803H | Power-on alternate boot. |
| FFC1H | 2 | `APWYS` | `F6 FF` | DW FFF6H | Pointer to PWYS variable (not a JP). |
| FFC3H | 3 | `CSTS` | `C3 30 01` | JP CSTSM | Keyboard status check. |
| FFC6H | 3 | `CI` | `C3 84 01` | JP CIM | Keyboard character input. |
| FFC9H | 3 | `AREST` | `C3 46 05` | JP RESTAR | Breakpoint/RST 30H handler. |
| FFCCH | 1 | `NMIU` | `C9` | RET | User NMI hook (called every NMI tick). |
| FFCDH | 2 | — | `00 00` | DW 0000H | NMIU extended: JP target for user NMI handler. |
| FFCFH | 3 | `INTU` | `C3 87 04` | JP ERROR | Default maskable INT handler. |

#### Interrupt Vector Table (FFD0H – FFDFH)

| Address | Size | Label | Default | Description |
|:--------|:-----|:------|:--------|:------------|
| FFD0H | — | `INTU0` | (= INTU−2) | Z80 CTC Channel 0 interrupt vector address. |
| FFD2H | 2 | `INTU1` | 0000H | User interrupt vector 1. |
| FFD4H | 2 | `INTU2` | 0000H | User interrupt vector 2. |
| FFD6H | 2 | `INTU3` | 0000H | User interrupt vector 3. |
| FFD8H | 2 | `INTU4` | 0000H | User interrupt vector 4. |
| FFDAH | 2 | `INTU5` | 0000H | User interrupt vector 5. |
| FFDCH | 2 | `INTU6` | 0000H | User interrupt vector 6. |
| FFDEH | 2 | `INTU7` | 0000H | User interrupt vector 7. |

#### Reserved Area (FFE0H – FFE7H)

| Address | Size | Label | Description |
|:--------|:-----|:------|:------------|
| FFE0H | 8 | `REZ` | Reserved (DS 8). |

#### System Counters (FFE8H – FFEAH)

| Address | Size | Label | Default | Description |
|:--------|:-----|:------|:--------|:------------|
| FFE8H | 1 | `LCI` | 0 | Keyboard debounce counter (decremented in NMI, key accepted when reaches 0). |
| FFE9H | 1 | `SYG` | 0 | Keyboard beep duration counter (loaded with 50 = 100ms of beep). |
| FFEAH | 1 | `TIME` | 0 | General-purpose 2ms countdown timer (decremented in NMI, user-accessible). |

#### Real-Time Clock (FFEBH – FFF3H)

All time values stored in BCD format:

| Address | Size | Label | Range | Description |
|:--------|:-----|:------|:------|:------------|
| FFEBH | 1 | `MSEK` | 0–4 | Millisecond sub-counter (increments at 500Hz NMI rate, rolls over at WMSEK=5). |
| FFECH | 1 | `SETSEK` | 00–99 (BCD) | Hundredths of seconds. |
| FFEDH | 1 | `SEK` | 00–59 (BCD) | Seconds. |
| FFEEH | 1 | `MIN` | 00–59 (BCD) | Minutes. |
| FFEFH | 1 | `GODZ` | 00–23 (BCD) | Hours. |
| FFF0H | 1 | `DNITYG` | 7–1 | Day of week (counts down: 7,6,5,4,3,2,1). |
| FFF1H | 1 | `DNIM` | 01–31 (BCD) | Day of month. |
| FFF2H | 1 | `MIES` | 01–12 (BCD) | Month. |
| FFF3H | 1 | `LATA` | 00–99 (BCD) | Year. |

#### Keyboard & Display Variables (FFF4H – FFFEH)

| Address | Size | Label | Default | Description |
|:--------|:-----|:------|:--------|:------------|
| FFF4H | 1 | `KLAW` | 0 | Keyboard/tape output port shadow register (current state of PA for MIK94 board). |
| FFF5H | 1 | `SBUF` | 0 | Display multiplexer counter. Bits B7,B6,B5 select current digit (modulo 8). Incremented by NMI. |
| FFF6H | 1 | `PWYS` | 0 | Display parameter register (controls position and digit count). |
| FFF7H | 8 | `BWYS` | all 0 | Display buffer — 8 bytes of 7-segment patterns. |

**Display buffer detail:**

| Address | Label | Description |
|:--------|:------|:------------|
| FFF7H | `CYF0` | Display digit 0 (rightmost). |
| FFF8H | `CYF1` | Display digit 1. |
| FFF9H | `CYF2` | Display digit 2. |
| FFFAH | `CYF3` | Display digit 3. |
| FFFBH | `CYF4` | Display digit 4. |
| FFFCH | `CYF5` | Display digit 5. |
| FFFDH | `CYF6` | Display digit 6. |
| FFFEH | `CYF7` | Display digit 7 (leftmost). |

---

## 2. I/O Port Map

### 2.1 System 8255 PPI (on CA80 mainboard)

Active on every CA80 board. Address strobe: PSYS.

| Port | Name | Direction | Description |
|:-----|:-----|:----------|:------------|
| F0H | `PA` | Input | Keyboard row input, tape input, hardware configuration. |
| F1H | `PB` | Output | 7-segment display data (active-low — complemented before output). |
| F2H | `PC` | Output | Digit select (multiplexing via 74145 decoder) + keyboard column drive. |
| F3H | `CONTR` | Control | 8255 mode control. Initialized with **90H** (Mode 0: PA=input, PB+PC=output). |

**Port PA (F0H) — bit assignments:**

| Bit | Function |
|:----|:---------|
| B7 | Tape data input (magnetophone playback signal). |
| B6–B4 | Keyboard row readback (3 bits identifying the active key row). |
| B3 | Not used by Monitor. |
| B2 | PA2 — Emulator present flag. 1 = emulator board attached → boot jumps to `EMINIT`. |
| B1 | PA1 — Alternate boot flag. 1 = jump to `RTS` (0803H) instead of normal Monitor start. |
| B0 | PA0 — Interrupt mode select. 0 = stay in IM 1. 1 = switch to IM 2 (vectored interrupts via Z80 CTC). |

**Port PB (F1H) — display segments:**

Data written to PB is the **complement** of the 7-segment pattern (segments active-low). The Monitor executes `CPL` before `OUT (PB),A`.

**Port PC (F2H) — multiplexing:**

Bits of PC select which display digit is currently active and which keyboard column is being driven. The digit select lines drive a 74145 BCD-to-decimal decoder.

### 2.2 Z80A CTC (Counter/Timer Circuit)

Address strobe: CTF8. Four channels, directly addressed.

| Port | Name | Description |
|:-----|:-----|:------------|
| F8H | `CHAN0` | Channel 0 — Single-step execution timer. |
| F9H | `CHAN1` | Channel 1 — NMI heartbeat timer (system tick). |
| FAH | `CHAN2` | Channel 2 — Available for user. |
| FBH | `CHAN3` | Channel 3 — Available for user. |

**Channel 0 details:**
- Control word: `CCR0` = 87H (timer mode, prescaler ×16, trigger on loading time constant).
- Time constant: `TC0` = 10.
- Interrupt after 10 × 16 = **160 CPU clock cycles** (40 µs at 4 MHz).
- Zeroing word: `ZCHAN` = 3 (written to CHAN0 to cancel step mode).
- Used by the `*C` (MC) command for single-step execution.

**Channel 1 details:**
- Control word: `CCR1` = 07H (timer mode, prescaler ×16, interrupts disabled).
- Time constant: `TC1` = 250 (0FAH).
- Output frequency: 4 MHz ÷ 16 ÷ 250 = **1 kHz** at ZC/TO1 pin.
- ZC/TO1 is connected to Z80 NMI pin, producing **~500 Hz** NMI interrupts (every 2 ms).
- Initialized once at power-on and runs continuously.

### 2.3 Emulator 8255 PPI (on EME8 expansion board)

Address strobe: EME8. Only active when emulator hardware is attached (PA2=1).

| Port | Name | Direction | Description |
|:-----|:-----|:----------|:------------|
| E8H | `PA1` | Input (Mode 1) | Emulator data input (active-low strobe, hardware-buffered). |
| E9H | `PB1` | Output (Mode 1) | Emulator data output. |
| EAH | `PC1` | Mixed | Handshake/status signals. Bit 3 (INTE A) checked for buffer full status. |
| EBH | `CONTR1` | Control | Emulator 8255 control. Init: **B4H** (Mode 1: PA=input, PB=output). Changed to **09H** to set PC4=INTE A=1 during bootstrap. |

### 2.4 Special I/O Ports

| Port | Name | Description |
|:-----|:-----|:------------|
| ECH | `SYGNAL` | Sound output. `OUT (SYGNAL),A` toggles speaker/buzzer. Used by NMI to generate key-press beep. |
| FCH | `RESI` | Interrupt acknowledge/reset. `OUT (RESI),A` clears pending maskable interrupt. Used when system is in IM 1 (no Z80 CTC present). |

### 2.5 Tape Interface

The tape interface uses **no dedicated I/O ports**. It operates through the system 8255 PPI:

**Recording (write):**
- Bit B4 of KLAW shadow register (FFF4H) is set/cleared to control the tape output level.
- The KLAW value is output to both PA (F0H) and CONTR (F3H) depending on board variant:
  - MIK90 board: uses ports PC (F2H) and PA via bit manipulation.
  - MIK94 board: uses KLAW (FFF4H) shadow with direct PA (F0H) output.
- Bit encoding: Zero = 20 samples at state 0 (ILPR=20). One = 16 samples at state 1 + 4 at state 0. Double-one = 36 samples at state 1 + 4 at state 0.

**Playback (read):**
- Bit B7 of port PA (F0H) is sampled repeatedly.
- The `LICZ` routine counts consecutive same-polarity samples using thresholds:
  - `LOW1` = 9, `HIG1` = 29 (single bit boundaries).
  - `LOW2` = 29, `HIG2` = 49 (double bit boundaries).

**Timing:**
- Inter-sample delay controlled by `MAGSP` (FFB2H) via `DEL02` loop. Default: 25H (37 iterations).

**Record format:**
```
SYNCH(32×00H) | MARK(E2FDH) | NAZWA(1) | DLUG(1) | ADRES(2) | -SUMN(1) | DATA(DLUG bytes) | -SUMD(1)
```
- `SUMN` = checksum of header (NAZWA + DLUG + ADRES), stored as negation.
- `SUMD` = checksum of data block, stored as negation.
- EOF record: same format with DLUG=0, ADRES=entry point address.

---

## 3. Core System Calls (API)

These routines can be called from user programs. Most support two calling conventions:

1. **With PWYS parameter** (via RST or CALL + inline `DB` byte):
   ```
   RST <vector>    ; or CALL <routine>
   DB  <PWYS_value> ; inline parameter — sets display position
   ```
   The `USPWYS` helper reads the byte after the CALL/RST instruction from the return address on the stack, stores it via the APWYS pointer, and increments the return address.

2. **Without PWYS** (direct CALL to the "1" variant):
   ```
   CALL <routine1>  ; uses current PWYS setting
   ```

### 3.1 Display Routines

| Address | Name | Convention | Description | Modifies | Stack |
|:--------|:-----|:-----------|:------------|:---------|:------|
| 0020H | `LADR` | RST + DB PWYS | Display HL as 4 hex digits. | AF, C | 10 |
| 0021H | `LADR1` | CALL | Same, without setting PWYS. | AF, C | 8 |
| 0018H | `LBYTE` | RST + DB PWYS | Display A as 2 hex digits. | F, C | 8 |
| 001BH | `LBYTE1` | CALL | Same, without setting PWYS. | F, C | 6 |
| 01E0H | `CO` | CALL + DB PWYS | Display hex digit in C (C < 10H) via TSIED lookup. | AF | 5 |
| 01E1H | `CO1` | CALL | Same, without setting PWYS. | AF | 3 |
| 01ABH | `COM` | CALL + DB PWYS | Display 7-segment code in C at PWYS position. | AF | 3 |
| 01ACH | `COM1` | CALL | Same, without setting PWYS. | AF | 2 |
| 01D4H | `PRINT` | CALL + DB PWYS | Print string from (HL), terminated by 0FFH. | AF, HL, C | 3 |
| 01D5H | `PRINT1` | CALL | Same, without setting PWYS. | AF, HL, C | 1 |
| 0010H | `CLR` | RST + DB PWYS | Clear (blank) display digits per PWYS. | AF | 4 |
| 0011H | `CLR1` | CALL | Same, without setting PWYS. | — | 2 |

### 3.2 Keyboard Routines

| Address | Name | Convention | Description | Modifies | Stack |
|:--------|:-----|:-----------|:------------|:---------|:------|
| 0007H | `TI` | RST + DB PWYS | Fetch key with echo. Hex digits (0–F) displayed; CR/SPAC accepted but not displayed. Returns: A = table code. CY=1 → CR. Z=1 & CY=0 → SPAC. | AF | 8 |
| 0008H | `TI1` | CALL | Same, without setting PWYS. | AF | 6 |
| FFC6H | `CI` | CALL CI | Fetch key with debounce — waits for key release, then waits for key press (~40ms debounce). Same return convention as TI. | AF | 4 |
| FFC3H | `CSTS` | CALL CSTS | Check if any key is currently pressed. Returns: CY=1 & A = table code if pressed. CY=0 if no key pressed. | AF | 2 |

Note: `CI` and `CSTS` are indirect jumps in RAM (patchable). They default to `CIM` (0184H) and `CSTSM` (0130H) respectively.

### 3.3 Parameter Input Routines

| Address | Name | Convention | Description | Modifies | Stack |
|:--------|:-----|:-----------|:------------|:---------|:------|
| 01F4H | `PARAM` | CALL + DB PWYS | Input 4-digit hex number into HL. If more than 4 digits entered, last 4 count. Returns: CY=1 if last key was CR, CY=0 if SPAC. Display cleared per PWYS. | AF, HL | 9 |
| 01F5H | `PARAM1` | CALL | Same, without setting PWYS. | AF, HL | 7 |
| 01F8H | `PARA1` | CALL | Like PARAM1 but first hex digit pre-loaded in A (A < 0FH). | AF, HL | 7 |
| 0213H | `EXPR` | CALL + DB PWYS | Input C numbers (SPAC-separated, CR-terminated). Numbers are pushed onto the stack in order. | AF, HL, C | 10 |
| 0214H | `EXPR1` | CALL | Same, without setting PWYS. | AF, HL, C | 8 |

### 3.4 Utility Routines

| Address | Name | Description | Modifies | Stack |
|:--------|:-----|:------------|:---------|:------|
| 022DH | `CZAS` | Display time (if HL=SEK/FFEDH → HH.MM.SS) or date (if HL=DNITYG/FFF0H → YY.MM.DD). | AF, C | 9 |
| 023BH | `HILO` | HL := HL+1, then compute DE−HL. Returns: CY=0 if DE ≥ HL, CY=1 if DE < HL. | AF, HL | 0 |
| 01A2H | `CRSPAC` | Check if table key code in A is CR (12H) or SPAC (11H). Returns: CY=1 & Z=1 → CR. Z=1 & CY=0 → SPAC. NZ → other. | F | 0 |
| 015DH | `KONW` | Convert real key code → table code via TKLAW lookup. Returns: CY=1 & A = table code if valid key. CY=0 if key code not in TKLAW. | AF | 2 |
| 0065H | `SPEC` | Simple RET — return to calling program. | — | 0 |
| 0030H | `RESTA` | Software breakpoint entry. Disables interrupts and jumps to AREST (RESTAR). Insert RST 30H (opcode F7H) into user code to trigger. | — | — |

### 3.5 Tape Routines (callable from user programs)

| Address | Name | Description | Modifies | Stack |
|:--------|:-----|:------------|:---------|:------|
| 0626H | `ZMAG` | Write memory block <ADR1,ADR2> to tape under name B. | AF, HL, C | 13 |
| 067BH | `ZEOF` | Write EOF record. Entry: HL = entry address, B = program name. | AF, C, D | 7 |
| 071BH | `OMAG` | Read program from tape. Entry: B = declared name to match. Loads data to the address embedded in the tape record. | AF, DE, HL, C | 11 |

---

## 4. PWYS Display Parameter Encoding

The PWYS byte controls where and how characters appear on the 8-position display:

- **Bits 3–0** (`PWYS30`, value 0–7): Display position number. Position 0 = rightmost digit, position 7 = leftmost.
  - If PWYS30 ≥ 5, only the less-significant digits that fit within the display are shown.
  - If PWYS30 = 7, displaying a 4-digit address shows only the most significant digit at position 7.
- **Bits 7–4** (`PWYS74`): Control field.
  - Bit 4 set (e.g., PWYS = 1xH): Display without scrolling/shifting existing content.
  - Values of PWYS74 < 8 are considered "legal" for display engagement.
  - PWYS74 ≥ 8 causes the COM routine to return immediately without displaying (display position "illegal").

The PWYS value is stored at the address pointed to by `APWYS` (FFC1H/FFC2H), which defaults to FFF6H. The system uses indirect addressing: procedures read the pointer at `(APWYS)` to locate the PWYS byte.

After power-on or M-key press, `(APWYS)` = `PWYS` (i.e., APWYS points to FFF6H).

---

## 5. Keyboard Layout (TKLAW Table at 0300H)

The TKLAW table maps 24 physical (real) key codes to logical (table) codes. The table code equals the least-significant byte of the entry's address within TKLAW. The real key code is obtained by the CSTS procedure from the keyboard matrix hardware.

| Table Code | Key | Real Code | | Table Code | Key | Real Code |
|:-----------|:----|:----------|:---|:-----------|:----|:----------|
| 00H | 0 | 32H | | 0CH | C | 66H |
| 01H | 1 | 31H | | 0DH | D | 67H |
| 02H | 2 | 60H | | 0EH | E | 57H |
| 03H | 3 | 50H | | 0FH | F | 56H |
| 04H | 4 | 62H | | 10H | G | 54H |
| 05H | 5 | 63H | | 11H | SPAC | 51H |
| 06H | 6 | 53H | | 12H | CR | 30H |
| 07H | 7 | 52H | | 13H | M | 58H |
| 08H | 8 | 69H | | 14H | W | 33H |
| 09H | 9 | 65H | | 15H | X | 61H |
| 0AH | A | 55H | | 16H | Y | 64H |
| 0BH | B | 59H | | 17H | Z | 68H |

- Table length: `LTKLAW` = 18H (24 entries).
- The `KONW` procedure at 015DH performs a linear search through TKLAW, comparing the real key code in A against each entry.
- Special key constants: `GKLAW` = 10H (G key), `SPAC` = 11H, `CR` = 12H, `MKLA` = 58H (M key real code).

---

## 6. 7-Segment Character Map (TSIED Table at 0318H)

16 entries for hex digits 0–F. Segment encoding: bit 0 = segment A (top), bit 6 = segment G (middle), bit 7 = decimal point (active-low, active separately). The patterns stored in TSIED are the **non-complemented** values; the `COM1` procedure complements them before output to PB.

| Digit | Code | K | G | F | E | D | C | B | A | Segments lit |
|:------|:-----|:--|:--|:--|:--|:--|:--|:--|:--|:-------------|
| 0 | 3FH | 0 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | A,B,C,D,E,F |
| 1 | 06H | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 0 | B,C |
| 2 | 5BH | 0 | 1 | 0 | 1 | 1 | 0 | 1 | 1 | A,B,D,E,G |
| 3 | 4FH | 0 | 1 | 0 | 0 | 1 | 1 | 1 | 1 | A,B,C,D,G |
| 4 | 66H | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | B,C,F,G |
| 5 | 6DH | 0 | 1 | 1 | 0 | 1 | 1 | 0 | 1 | A,C,D,F,G |
| 6 | 7DH | 0 | 1 | 1 | 1 | 1 | 1 | 0 | 1 | A,C,D,E,F,G |
| 7 | 07H | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 | A,B,C |
| 8 | 7FH | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | A,B,C,D,E,F,G |
| 9 | 6FH | 0 | 1 | 1 | 0 | 1 | 1 | 1 | 1 | A,B,C,D,F,G |
| A | 77H | 0 | 1 | 1 | 1 | 0 | 1 | 1 | 1 | A,B,C,E,F,G |
| B | 7CH | 0 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | C,D,E,F,G |
| C | 39H | 0 | 0 | 1 | 1 | 1 | 0 | 0 | 1 | A,D,E,F |
| D | 5EH | 0 | 1 | 0 | 1 | 1 | 1 | 1 | 0 | B,C,D,E,G |
| E | 79H | 0 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | A,D,E,F,G |
| F | 71H | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 1 | A,E,F,G |

Additional special patterns used by the Monitor:

| Name | Code | Value | Displayed as |
|:-----|:-----|:------|:-------------|
| `GLIT` | 3DH | — | Letter "G" (seven-segment approximation). |
| `ZGAS` | 00H | — | Blank (all segments off). |
| `KRESKA` | 40H | — | Middle segment only (dash "−"). |
| `ANUL` | 08H | — | Bottom segment only (underscore). |
| `ROWN` | 48H | — | Equals sign "=" (middle + bottom segments). |
| `KROP` | bit 7 | — | Decimal point (bit 7 = segment K). |

---

## 7. Initialization Sequence (Power-On)

### Step 1: Cold Reset (0000H)

```
CA80:   LD   A,KONF     ; A = 90H
        OUT  (CONTR),A  ; Configure system 8255: PA=input, PB+PC=output
        JP   CA80A      ; Jump to main initialization
```

### Step 2: Main Initialization (0241H – CA80A)

1. **Set system stack**: `LD SP,TOS` (SP = FF8DH).

2. **Initialize RAM**: Copy `TRAM` template (59 bytes from ROM at 05C8H+) to RAM area FF97H–FFD1H using `LDDR`. This sets up:
   - User SP default (FF66H = TOS − 27H, leaving room for user stack).
   - EXIT procedure code in RAM.
   - KROK area (NOP NOP — no single-stepping).
   - Default user HL (C100H), user PC (C000H).
   - Breakpoint slots (all zeros).
   - Tape parameters (DLUG=16, MAGSP=25H).
   - Status flags (GSTAT=FFH, ZESTAT=FFH).
   - All indirect jump vectors (M8, ERRMAG, EM, RTS, CSTS, CI, AREST, NMIU, INTU).

3. **Set interrupt vector base**: `LD A,HIGH TOS` (A = 0FFH), `LD I,A` → I register = FFH. This makes the IM 2 vector table start at FF00H (relevant only if IM 2 is selected).

4. **Set default interrupt mode**: `IM 1`.

5. **Initialize Z80 CTC Channel 0**:
   - Write low byte of INTU0 vector (D0H) to CHAN0 (F8H) — sets CTC interrupt vector.

6. **Initialize Z80 CTC Channel 1** (NMI heartbeat):
   - `OUT (CHAN1), CCR1` — control word 07H (timer mode, prescaler ×16, no interrupts).
   - `OUT (CHAN1), TC1` — time constant 0FAH (250). Output: 4MHz ÷ 16 ÷ 250 = 1 kHz.

7. **Check hardware configuration** (read PA):
   - `IN A,(PA)` → read port A.
   - `RRCA` → CY = PA0. If PA0=1: `IM 2` (vectored interrupts through CTC).
   - `RRCA` → CY = PA1. If PA1=1: `JP C,RTS` (jump to 0803H via FFBEH).
   - `RRCA` → CY = PA2. If PA2=1: `JP C,EMINIT` (initialize emulator at 0603H).

### Step 3: Enter Monitor Main Loop (0270H – START)

1. `LD SP,TOS` — reset system stack.
2. `RST CLR` / `DB 80H` — clear all 8 display digits.
3. `LD HL,KO1` / `CALL PRINT` / `DB 40H` — display "CA80" boot message at position 0, engaged 4 digits.
4. `CALL EMUL` — check emulator status.
5. `CALL TI` / `DB 17H` — wait for first key press (display position: most significant digit).
6. Validate key as command (table code 0–11H = LCT), dispatch via CTBL, or display error.

---

## 8. NMI Service Routine (0066H) — Execution Flow

The NMI fires at approximately 500 Hz (every 2 ms) and performs all real-time housekeeping:

### Phase 1: Register Save
```
NMI:    PUSH AF
        PUSH HL
        PUSH DE
        PUSH BC         ; Save AF, HL, DE, BC
```

### Phase 2: Keyboard Scan
1. `LD HL,LCI` — point to keyboard debounce counter.
2. `XOR A; CP (HL)` — check if LCI = 0.
3. If LCI ≠ 0: decrement LCI. Then check SYG (beep counter): if SYG ≠ 0, decrement SYG and output pulse to `SYGNAL` (ECH).
4. If LCI = 0: key scan cycle is inactive (will be reloaded by CI procedure when key is pressed).

### Phase 3: TIME Counter
- Decrement `TIME` counter (FFEAH). User programs can load TIME and poll for zero to create delays (each tick = 2ms).

### Phase 4: Real-Time Clock (if ZESTAT ≠ 0)
- Check `ZESTAT` (FFB4H). If zero, skip entire RTC update.
- Otherwise, cascade-increment the RTC chain:

```
MSEK (0-4) → SETSEK (BCD 0-99) → SEK (BCD 0-59) → MIN (BCD 0-59) → GODZ (BCD 0-23)
```

- When GODZ rolls over: decrement `DNITYG` (day of week, 7→1, wraps from 1 to 7).
- Increment `DNIM` (day of month, BCD), compare against `TABM[MIES]` for month length.
- When DNIM exceeds month limit: reset DNIM to 01, increment `MIES`.
- When MIES exceeds 12H (BCD): reset MIES to 01, increment `LATA`.

### Phase 5: Display Refresh
1. Load `SBUF` (FFF5H) — current display multiplexer state.
2. Extract bits B7–B5 to get digit number (0–7).
3. Add digit offset to BWYS base address to get the 7-segment pattern.
4. Read the pattern, complement it (`CPL`), output to PB (F1H) — activates segments.
5. Compute new digit-select value for PC (F2H), output it — activates the LED digit.
6. Increment SBUF by 20H (advance to next digit, modulo 8 on bits B7–B5).

### Phase 6: M-Key Detection
1. Save and restore port states carefully (must not disturb PC output or PA output).
2. For MIK90 board: Set keyboard column to scan M-key row via PC manipulation.
3. For MIK94 board: Set KLAW to M-key scan code via PA.
4. Read PA (F0H), extract bits B6–B4, compare against `MKLA64` (50H).
5. Restore original port states (PC and PA).
6. If M-key is pressed (`CP MKLA64` matches) AND `GSTAT` = 0 (user program running):
   - Jump to `MWCIS` (052FH) — forced return to Monitor.
7. If M-key not pressed or Monitor already running:
   - `POP BC` — restore BC.
   - `CALL NMIU` (FFCCH) — user NMI hook (default: RET).
   - `POP DE; POP HL; POP AF` — restore remaining registers.
   - `RETN` — return from NMI.

---

## 9. Symbolic Constants

Key constants defined in the source code:

| Name | Value | Description |
|:-----|:------|:------------|
| `KONF` | 90H | System 8255 control word (PA=in, PB+PC=out, Mode 0). |
| `KONF1` | 0B4H | Emulator 8255 control word (PA=in Mode 1, PB=out Mode 1). |
| `PCUZYT` | 0C000H | Default user Program Counter. |
| `HLUZYT` | 0C100H | Default user HL register value. |
| `WMSEK` | 5 | Millisecond counter limit (MSEK counts 0–4, giving 5×2ms = 10ms per SETSEK tick). |
| `GKLAW` | 10H | Table code of G key. |
| `SPAC` | 11H | Table code of SPAC (space/dot) key. |
| `CR` | 12H | Table code of CR (equals/enter) key. |
| `MKLA` | 58H | Real key code of M key. |
| `MKLA30` | 08H | MKLA AND 0FH — lower nibble of M key code. |
| `MKLA64` | 50H | MKLA AND 70H — bits B6–B4 of M key code (for NMI comparison). |
| `KRP` | 0F4D3H | Single-step opcode: `OUT (0F4H),A` — triggers CTC channel 0 interrupt. |
| `RST30` | 0F7H | Breakpoint opcode: `RST 30H`. |
| `LCT` | 11H | Number of legal commands (17 = (CTBL_end − CTBL) / 2). |
| `LSYNCH` | 20H | Tape sync block length (32 bytes of 00H). |
| `MARK` | 0E2FDH | Tape record start marker (2 bytes). |
| `ILPR` | 14H (20) | Tape samples per half-bit period. |
| `LOW1` | 09H | Tape threshold: single-bit low boundary (ILPR/2 − 1). |
| `HIG1` | 1DH (29) | Tape threshold: single-bit high boundary (ILPR + ILPR/2 − 1). |
| `LOW2` | 1DH (29) | Tape threshold: double-bit low boundary (2×ILPR/2 − 1). |
| `HIG2` | 31H (49) | Tape threshold: double-bit high boundary (2×ILPR + ILPR/2 − 1). |
