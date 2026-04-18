# CA80 Microcomputer and Clones

Welcome to the CA80 Microcomputer repository! This repository is dedicated to preserving and sharing information, resources, and projects related to the polish CA80 microcomputer and its various clones.

## Overview

The CA80 is an 8-bit microcomputer developed in Poland by Stanisław Gardynik (05-590 Raszyn) in the early 1980s. The design was published as a series of construction articles ("MIK" booklets) and gained wide popularity in educational and hobbyist circles. The CA80 features a Z80A CPU running at 4 MHz, an 8-digit 7-segment LED display, a hex keyboard, real-time clock, and cassette tape interface — all packed into a 2 KB monitor ROM.

## Features

- **CPU**: Z80A microprocessor at 4 MHz
- **Display**: 8-digit 7-segment LED display (active multiplexing driven by NMI at 500 Hz)
- **Memory**: 2 KB monitor ROM (EPROM 2716 or 2764), typically 2–32 KB RAM, expandable
- **Storage**: Cassette tape interface with configurable baud rate and checksummed records
- **I/O**: System 8255 PPI (PA/PB/PC at F0–F3H), Z80A CTC timer (F8–FBH), optional emulator 8255 (E8–EBH)
- **Keyboard**: 24-key hex keyboard (0–F, G, M, W, X, Y, Z, SPAC, CR)
- **Clock**: Real-time BCD clock (hours/minutes/seconds + date) maintained via NMI interrupt
- **Programming**: Z80 machine code, with 17 built-in monitor commands (\*0–\*G)

## Monitor Commands

| Command | Function |
|---------|----------|
| \*0 | Display real-time clock (hours/min/sec), press any key for date |
| \*1 | Set time: \*1 HH MM SS [CR] |
| \*2 | Set date: \*2 YY MM DD DW [CR] |
| \*3 | Swap main/alternate register set |
| \*4 | Save memory block to tape |
| \*5 | Write EOF record to tape |
| \*6 | Load program from tape |
| \*7 | System init (\*7[CR]) or set tape params (\*7 SPEED LENGTH [CR]) |
| \*8 | User-defined command (jumps to 0800H) |
| \*9 | Search for 8/16-bit word in memory |
| \*A | Hex add and subtract |
| \*B | Block move (intelligent, handles overlapping regions) |
| \*C | Single-step execution with register/memory inspection |
| \*D | Memory dump / edit |
| \*E | Fill memory with constant |
| \*F | View/modify CPU registers and flags (S, Z, H, P, N, C) |
| \*G | Go — execute user program with optional breakpoints (up to 2) |

## Key Components

### CPU

The CA80 is powered by the Z80A CPU at 4 MHz. The monitor uses interrupt mode 1 (IM 1) by default, with optional IM 2 when a Z80A CTC is present. The CTC channel 1 generates a 1 kHz signal (4 MHz ÷ 16 ÷ 250) used as the NMI source for display multiplexing and keyboard scanning.

### Memory Map

| Address | Contents |
|---------|----------|
| 0000–07FF | Monitor ROM (2 KB) |
| 0800–... | User program / extensions (mapped to \*8 command) |
| C000H | Default user PC after reset (PCUZYT) |
| C100H | Default user HL after reset (HLUZYT) |
| FF8D–FFFF | Monitor RAM: register save area, system variables, display buffer |
| FF8D | TOS — top of system stack |
| FFE8–FFEA | LCI, SYG, TIME — keyboard/timing counters |
| FFEB–FFF3 | Real-time clock (BCD): msec, csec, sec, min, hrs, dow, day, month, year |
| FFF4–FFF5 | KLAW, SBUF — keyboard and display state |
| FFF6 | PWYS — display position parameter |
| FFF7–FFFE | BWYS (CYF0–CYF7) — 8-byte display buffer |

### Display

The primary output is an 8-digit 7-segment display. Each digit has segments A–G plus a decimal point (K), encoded as a single byte (bit 0 = segment A, bit 6 = segment G, bit 7 = decimal point). The display buffer at FFF7–FFFE is continuously refreshed by the NMI handler. Character codes for hex digits 0–F are stored in the TSIED table.

### Storage

The cassette tape interface uses a software-defined FSK protocol. Each byte is framed with start/stop bits, using 20-sample periods for bit timing. Records consist of a 32-byte sync preamble (00H), a 2-byte marker (E2FDH), followed by: name (1 byte), block length, load address (2 bytes), header checksum, data block, and data checksum. The tape speed is configurable via the \*7 command (MAGSP parameter at FFB2H).

### I/O Ports

| Port | Chip | Function |
|------|------|----------|
| F0H (PA) | 8255 system | Keyboard column input / tape input (bit 7) |
| F1H (PB) | 8255 system | 7-segment display output |
| F2H (PC) | 8255 system | Display digit select / keyboard row output |
| F3H (CONTR) | 8255 system | Control register (configured as PA=input, PB+PC=output) |
| F8–FBH | Z80A CTC | Timer channels 0–3 |
| E8–EBH | 8255 emulator | Optional emulator port (PA1/PB1/PC1/CONTR1) |
| ECH | — | Buzzer / audio signal (SYGNAL) |
| FCH | — | Interrupt acknowledge (RESI) |

## Monitor ROM Variants

The CA80 monitor exists in at least two hardware variants, both labeled V3.0. The differences are confined to hardware-dependent routines; all core monitor logic, system procedures, and the command interpreter are byte-identical.

### MIK90+MIK94 (dual-board version — from MIK08 listing)

This is the version documented in the published MIK08 booklet (Copyright 1987, assembled with MACRO-80 3.44, dated 09-Dec-81). It supports both the MIK90 main board (U7 — system 8255) and the MIK94 expansion board (substitute 8255 keyboard/display circuit, see schematic R27 in MIK05B).

### MIK290-only (single-board version — from EPROM dump)

This variant, found in the `CA80.BIN` EPROM dump (8 KB, 2764), targets the MIK290 board exclusively. The monitor occupies the first 2 KB; the remaining 6 KB contains user extension code accessible via the \*8 command.

### Detailed Differences

Five regions of the ROM differ between the two variants. All other bytes are identical (verified across 401 bytes in 41 code blocks at 100% match rate).

#### 1. Reset Entry Point (0000–0006)

**MIK90+MIK94:**
```
0000: 3E 90     LD   A,90H        ; Port configuration word
0002: D3 F3     OUT  (CONTR),A    ; PA=input, PB+PC=output
0004: C3 41 02  JP   CA80A        ; Continue initialization
```

**MIK290-only:**
```
0000: 00        NOP               ; 4 reserved bytes
0001: 00        NOP               ; (allows patching without
0002: 00        NOP               ;  re-burning the EPROM)
0003: 00        NOP
0004: C3 56 01  JP   CA80_INIT    ; Relocated init at 0156H
 ...
0156: 3E 90     LD   A,90H       ; Same port configuration
0158: D3 F3     OUT  (CONTR),A
015A: C3 41 02  JP   CA80A
```

The MIK290-only version uses an indirection that reserves the first 4 bytes for potential patching (e.g., a jump to custom initialization code) without modifying the rest of the ROM.

#### 2. NMI M-Key Detection (00E4–0100)

The NMI handler checks whether the "M" key is being held to return control to the monitor. The dual-board version handles both the MIK94 port (PA at F0H with KLAW variable) and the MIK290 port (PC at F2H), requiring 28 bytes of code that carefully preserves both port states to avoid disturbing the CSTS keyboard scan.

**MIK90+MIK94 (28 bytes):**
```
; Set keyboard decoder to M-key row via PC port (MIK90)
00E4: LD   A,C / AND F0H / ADD A,MKLA30 / OUT (PC),A
; Set keyboard decoder via PA port (MIK94)
00EB: LD   A,(KLAW) / LD B,A / AND 10H / ADD A,MKLA30 / OUT (PA),A
; Read and check both
00F5: IN   A,(PA) / AND 70H / CP MKLA64
; Restore both ports, then check result
00FB: LD A,C / OUT (PC),A / LD A,B / OUT (PA),A
0101: JP   Z,MWCIS
```

**MIK290-only (21 bytes + 12 bytes padding):**
```
; Set keyboard decoder to M-key row via PC port only
00E4: LD   A,C / OR 0FH / AND 0FEH / OUT (PC),A
; Read column and check
00EB: IN   A,(PA) / RRCA / AND 3FH / CP 3EH
; Restore PC port, then check result
00F2: LD   A,C / OUT (PC),A
00F5: JP   Z,MWCIS
00F8: POP  BC / CALL NMIU / POP DE / POP HL / POP AF / RETN
0101: DS   12, FFH     ; unused
```

The MIK290-only version is simpler because it only manipulates the PC port via the system 8255. The M-key column code differs (3EH vs MKLA64/50H) reflecting the different keyboard matrix wiring.

#### 3. CSTS Keyboard Scan (0130–015C)

The keyboard scanning procedure is fundamentally different between the two variants because of the hardware differences in how keyboard rows are selected.

**MIK90+MIK94 (45 bytes):**
- Scans 10 keyboard rows (L = 0AH)
- Writes the row number to `KLAW` variable and `PA` port (for MIK94)
- Uses a 4-iteration bit-shift loop through `CONTR` set/reset commands to drive PC port lines (for MIK90), preserving PC7–PC5 which are used by the NMI display multiplexer
- Reads `PA` port, checks bits B6–B4 against 70H (no key = 70H)
- Constructs key code by combining row and column information from both boards

**MIK290-only (34 bytes + 2 bytes padding):**
- Scans 4 keyboard rows (L = 04H)
- Writes directly to `CONTR` using set/reset bit commands (RLCA to position the bit)
- Reads `PA` port, uses RRCA + AND 3FH, compares with 3FH (no key = 3FH)
- After reading, immediately resets the PC bit via another `CONTR` write (INC A produces the reset command)
- Constructs key code from row (shifted) OR'd with column readback
- Falls through to `KONW` for key code translation

```
; MIK290-only CSTS (simplified)
0130: PUSH HL / PUSH BC
0132: LD   L,4             ; Only 4 rows
0134: DEC  L               ; L=3,2,1,0,FFH
0135: JP   M,CST2          ; No key pressed
0138: LD   A,L / RLCA      ; Row bit position
013A: OUT  (CONTR),A        ; Set PC bit (select row)
013C: IN   A,(PA)           ; Read columns
013E: RRCA / AND 3FH        ; Extract column data
0141: LD   H,A              ; Save column
0142: LD   A,L / RLCA / INC A
0145: OUT  (CONTR),A        ; Reset PC bit (deselect row)
0147: LD   A,H / CP 3FH     ; Key pressed? (3FH = none)
014A: JR   Z,CST1           ; No — try next row
014C: LD   A,L / RRCA / RRCA
014F: OR   H                ; Combine row + column = raw key code
0150: POP  BC / POP HL
0152: JR   KONW             ; Convert to table code
```

#### 4. TKLAW Keyboard Table (0300–0317)

The 24-byte keyboard lookup table maps hardware-specific raw key codes to logical key numbers (0–17H). The raw codes are completely different because the keyboard matrices are wired differently:

| Key | Function | MIK90+MIK94 code | MIK290-only code |
|-----|----------|:-----------------:|:---------------:|
| 0 | Digit 0 | 32H | FBH |
| 1 | Digit 1 | 31H | EFH |
| 2 | Digit 2 | 60H | FDH |
| 3 | Digit 3 | 50H | DFH |
| 4 | Digit 4 | 62H | BBH |
| 5 | Digit 5 | 63H | AFH |
| 6 | Digit 6 | 53H | BDH |
| 7 | Digit 7 | 52H | 9FH |
| 8 | Digit 8 | 69H | 7BH |
| 9 | Digit 9 | 65H | 6FH |
| A | Hex A | 55H | 7DH |
| B | Hex B | 59H | 5FH |
| C | Hex C | 66H | 3BH |
| D | Hex D | 67H | 2FH |
| E | Hex E | 57H | 3DH |
| F | Hex F | 56H | 1FH |
| G | Go | 54H | 7EH |
| SPAC | Space (.) | 51H | BEH |
| CR | Enter (=) | 30H | FEH |
| M | Monitor | 58H | 3EH |
| W | — | 33H | F7H |
| X | — | 61H | B7H |
| Y | — | 64H | 77H |
| Z | — | 68H | 37H |

#### 5. EMINIT Emulator Initialization (0603–060D)

**MIK90+MIK94 (full bootstrap, 26 bytes):**
```
0603: LD   HL,0FF80H          ; Target address
0606: LD   B,80H              ; 128 bytes to load
0608: LD   A,KONF1
060A: OUT  (CONTR1),A         ; Configure emulator 8255
060C: LD   A,9
060E: OUT  (CONTR1),A         ; Enable INTE
0610: IN   A,(PC1)            ; Wait for data ready
0612: AND  8
0614: JR   Z,EMI              ; Loop until buffer full
0616: IN   A,(PA1)            ; Read byte from emulator
0618: DEC  HL
0619: LD   (HL),A             ; Store in RAM
061A: DJNZ EMI
061C: JP   (HL)               ; Jump to loaded code at FF00H
```

**MIK290-only (signature check, 11 bytes):**
```
0603: LD   A,(8001H)          ; Check for ROM at 8000H
0606: CP   0AAH               ; Magic signature byte
0608: JP   NZ,ERROR           ; No emulator ROM present
060B: JP   8002H              ; Jump to emulator entry point
```

The MIK290-only version expects emulator code to be pre-loaded in a ROM at 8000H with a signature byte (AAH) at address 8001H, rather than bootstrapping it through the 8255 port. The entry point is at 8002H (skipping the 2-byte signature header).

### EPROM Layout (CA80.BIN — MIK290-only)

```
0000 ┌──────────────────────────────────┐
     │ CA80 Monitor V3.0 (MIK290-only)  │
     │ Core routines, RST vectors,     │
     │ NMI handler, display driver,    │
     │ keyboard scan, system commands  │
     │ *0–*G, cassette tape I/O,       │
     │ emulator check                  │
07FF └──────────────────────────────────┘
0800 ┌──────────────────────────────────┐
     │ User extensions / *8 program    │
     │ (additional software loaded     │
     │  into the same 2764 EPROM)      │
1FFF └──────────────────────────────────┘
```

## System Procedures (callable from user programs)

The monitor exposes system procedures at fixed entry points, usable from user code via RST instructions or CALL through jump vectors in high RAM:

| Entry | Vector | Name | Function |
|-------|--------|------|----------|
| RST 08H | — | TI | Read key with echo (display hex digit) |
| RST 10H | — | CLR | Clear display digits |
| RST 18H | — | LBYTE | Display byte (A) as 2 hex digits |
| RST 20H | — | LADR | Display word (HL) as 4 hex digits |
| RST 28H | — | USPWYS | Set display position parameter |
| RST 30H | — | RESTA | Return to monitor (triggers RESTAR) |
| — | FFC3H | CSTS | Check if key pressed (CY=1 if yes) |
| — | FFC6H | CI | Wait for keypress with debounce |
| — | FFC9H | AREST | Jump to RESTAR procedure |
| — | FFCCH | NMIU | User NMI hook (default: RET) |

All vectors at FFC1–FFCCH are re-initialized when the "M" key is pressed, allowing user programs to redirect them.

## Getting Started

### Assembly Language Programming

To write programs for the CA80, you will need to use Z80 assembly language. Programs are typically loaded at address C000H (the default user PC). Here is a simple example that displays "HELLO" on the 7-segment display using monitor system calls:

```assembly
; Display "HELLO" on CA80 7-segment display
; Load at C000H, run with *G C000 [CR]

        ORG     0C000H

        RST     10H             ; CLR — clear display
        DB      80H             ; all 8 digits

        LD      HL,MSG          ; pointer to message
        CALL    01D4H           ; PRINT — display string
        DB      40H             ; starting at position 0

HALT:   JR      HALT            ; loop (press M to return)

MSG:    DB      76H             ; H
        DB      79H             ; E
        DB      38H             ; L
        DB      38H             ; L
        DB      3FH             ; O
        DB      0FFH            ; end marker

        END
```

### Loading via Cassette

1. Connect tape recorder to the CA80 DIN connector
2. Type `*6 [name] [CR]` to start loading
3. Press play on the recorder — the CA80 searches for the named program
4. The `=` symbol appears during data transfer
5. After loading, the program is automatically placed at its saved address

### Using Breakpoints

The `*G` command supports up to 2 breakpoints using RST 30H instruction injection:

```
*G C000 C010 [CR]     — run from C000H, break at C010H
*G C000 C010 C020 [CR] — run from C000H, break at C010H or C020H
```

When a breakpoint is hit, all registers are saved and the monitor returns to the `*C` (single-step) mode showing the current PC and opcode.

## Repository Contents

- `CA80.BIN` — EPROM dump of the MIK290-only variant (8 KB, 2764)
- `ca80_mik90.asm` — Fully reconstructed and verified assembly source (MIK290-only variant)
- `ca80_monitor.asm` — Assembly source matching the MIK08 listing (MIK90+MIK94 variant)

## References

- **MIK08** — "Pełny Listing Programu Monitora CA80 2kB" by Stanisław Gardynik, Copyright (C) 1987
- **MIK04** — Z80A CPU, 8255, Z80A CTC documentation
- **MIK05/MIK05B** — Hardware schematics (R6: system 8255, R8: CTC/emulator 8255, R27: MIK94 substitute circuit)

## Contributing

We welcome contributions from the community. If you have projects, modifications, or documentation related to the CA80 or its clones, please feel free to submit a pull request or open an issue.

## License

This repository is licensed under the MIT License. See the LICENSE file for more information.

## Contact

For questions, suggestions, or discussions, please open an issue or contact me.
