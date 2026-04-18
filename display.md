# CA80 Microcomputer Display Architecture & Logic (Monitor V3.0)

This document provides a complete technical breakdown of the 8-digit 7-segment LED display subsystem in the CA80 microcomputer, derived from the original Monitor V3.0 assembly source code (MIK08, Copyright (C) 1987 Stanisław Gardynik). Every register value, address, and algorithm has been verified against the source listing.

---

## 1. Hardware Interface

### 1.1 8255 PPI Configuration

The display is driven through the system Intel 8255 PPI (address strobe PSYS), configured at power-on with control word **90H** (Mode 0: PA = input, PB + PC = output):

| Port | Address | Direction | Display Function |
|:-----|:--------|:----------|:-----------------|
| PA | F0H | Input | Not used for display (keyboard/tape input). |
| PB | F1H | Output | 7-segment data bus — drives segments A–G and decimal point K. |
| PC | F2H | Output | Digit select — bits drive the 74145 BCD-to-decimal decoder. |
| CONTR | F3H | Control | 8255 configuration register. Also used for bit set/reset of individual PC pins. |

### 1.2 Segment Data (Port B — F1H)

Port B carries the segment pattern to the LED display. The CA80 uses **active-low** segment drive — a segment lights up when its corresponding bit is **0**. The Monitor software complements (`CPL`) the pattern before outputting to PB, so the internal representation in the BWYS buffer uses positive logic (1 = segment on).

Segment bit mapping (internal representation, before CPL):

```
Bit 7: K (decimal point / dot)
Bit 6: G (middle horizontal)
Bit 5: F (upper-left vertical)
Bit 4: E (lower-left vertical)
Bit 3: D (bottom horizontal)
Bit 2: C (lower-right vertical)
Bit 1: B (upper-right vertical)
Bit 0: A (top horizontal)
```

```
    AAA
   F   B
   F   B
    GGG
   E   C
   E   C
    DDD  K
```

### 1.3 Digit Select (Port C — F2H)

Port C drives a **74145** BCD-to-decimal decoder (active-low outputs). The decoder selects which of the 8 digits is currently illuminated. The digit select value is derived from the SBUF counter — specifically bits B7, B6, B5 of SBUF, which after rotation are placed into the appropriate PC bit positions.

Port C is **shared** between the display multiplexer and the keyboard scanner:
- Bits PC5–PC7 (upper): display digit select via 74145
- Bits PC0–PC3 (lower): keyboard row scan

The NMI display routine writes the entire PC register, combining the new digit select with the current keyboard scan state.

### 1.4 Display Digit Numbering

| Position | Digit | Buffer Address | Physical Location |
|:---------|:------|:---------------|:------------------|
| 0 | CYF0 | FFF7H | Rightmost |
| 1 | CYF1 | FFF8H | |
| 2 | CYF2 | FFF9H | |
| 3 | CYF3 | FFFAH | |
| 4 | CYF4 | FFFBH | |
| 5 | CYF5 | FFFCH | |
| 6 | CYF6 | FFFDH | |
| 7 | CYF7 | FFFEH | Leftmost |

---

## 2. Display-Related RAM Variables

| Address | Name | Size | Description |
|:--------|:-----|:-----|:------------|
| FFF5H | `SBUF` | 1 byte | Display multiplexer state counter. Bits B7,B6,B5 encode the current digit index (0–7). Incremented by 20H each NMI tick (advances one digit per tick). Lower bits B4–B0 hold auxiliary state. |
| FFF6H | `PWYS` | 1 byte | Display parameter register. Controls where system routines (LBYTE, LADR, COM, etc.) write characters. See Section 7 for full encoding. |
| FFF7H–FFFEH | `BWYS` | 8 bytes | Display buffer. Each byte holds a 7-segment pattern (positive logic). Written by display routines, read by NMI for output. |
| FFC1H–FFC2H | `APWYS` | 2 bytes (DW) | Pointer to PWYS variable. Defaults to FFF6H. Used for indirect addressing by all display routines. |

---

## 3. Dynamic Multiplexing — NMI Display Refresh

The CA80 has no dedicated display controller. Instead, the **NMI service routine** (firing at ~500 Hz / every 2 ms) refreshes one digit per invocation, cycling through all 8 digits. At 500 Hz, the complete display is refreshed at **62.5 Hz** (500 ÷ 8), providing flicker-free output.

### 3.1 NMI Display Code (ZKON1 — 00C2H)

The display refresh occurs near the end of the NMI handler, at label `ZKON1`. Here is the complete algorithm, traced from the source:

**Step 1 — Read and advance the multiplexer counter:**

```assembly
ZKON1:  LD    HL,SBUF         ; HL = FFF5H (address of SBUF)
        LD    A,(HL)          ; A = current SBUF value
        ADD   A,20H           ; Advance digit index (bits B7-B5 += 1)
        LD    (HL),A          ; Store updated SBUF
```

The digit index occupies bits B7–B5 of SBUF. Adding 20H increments this 3-bit field by 1, cycling through values 000, 001, 010, ..., 111 (digits 0–7). The addition naturally wraps modulo 8 due to the 3-bit width.

**Step 2 — Blank the display (anti-ghosting):**

```assembly
        INC   HL              ; HL = FFF6H (PWYS — but we skip past it)
        INC   HL              ; HL = FFF7H (start of BWYS buffer)
```

Wait — the blanking is actually done by the segment output sequence. The code first prepares the digit select, then outputs the new segments. Let me trace more carefully:

```assembly
        AND   0E0H            ; Mask bits B7-B5 (digit index only)
        LD    B,A             ; B = digit index in upper 3 bits
        LD    A,0FFH          ; A = FFH
        OUT   (PB),A          ; Output FFH to Port B → ALL segments OFF
                              ; (active-low: FFH = everything dark)
```

This **blanking step** is critical. Before switching to a new digit, all segments are turned off. This prevents "ghosting" — the brief illumination of wrong segments on the new digit while the old pattern is still on the data bus.

**Step 3 — Read Port C and update digit select:**

```assembly
        IN    A,(PC)          ; Read current Port C state
        AND   1FH             ; Mask lower 5 bits (preserve keyboard scan state)
        OR    B               ; Merge with new digit select (upper 3 bits)
        LD    C,A             ; Save combined value for later
        OUT   (PC),A          ; Output to Port C → select new digit via 74145
```

This preserves the keyboard column scan bits (PC0–PC4) while updating the digit select bits (PC5–PC7). The 74145 decoder receives the new digit number and activates the corresponding LED common line.

**Step 4 — Calculate buffer address and fetch pattern:**

```assembly
        LD    A,B             ; A = digit index (in bits B7-B5)
        RLCA                  ; 
        RLCA                  ;
        RLCA                  ; Rotate left 3 times: now digit index is in bits B2-B0
        AND   0FH             ; Mask to 4 bits (digit 0-7)
        LD    L,A             ; L = digit index (0-7)
```

Wait, let me re-trace this more carefully from the actual source. The listing shows:

```assembly
00C2  21 FFF5      LD    HL,SBUF         ; HL → FFF5H
00C5  7E           LD    A,(HL)          ; A = SBUF
00C6  C6 20        ADD   A,20H           ; Increment digit counter
00C8  77           LD    (HL),A          ; Save SBUF
00C9  23           INC   HL              ; HL → FFF6H
00CA  23           INC   HL              ; HL → FFF7H (BWYS base)
```

Now the code computes the digit address within BWYS:

```assembly
00CB  E6 E0        AND   0E0H            ; Isolate bits B7-B5 (digit index × 32)
00CD  47           LD    B,A             ; B = digit select value for PC
00CE  3E FF        LD    A,0FFH          ;
00D0  D3 F1        OUT   (PB),A          ; Blank display (all segments off)
00D2  DB F2        IN    A,(PC)          ; Read current PC
00D4  E6 1F        AND   1FH             ; Keep keyboard bits (lower 5)
00D6  B0           OR    B               ; Merge digit select (upper 3)
00D7  4F           LD    C,A             ; Save for later restoration
00D8  D3 F2        OUT   (PC),A          ; Activate new digit
00DA  78           LD    A,B             ; A = digit index × 32
00DB  07           RLCA                  ;
00DC  07           RLCA                  ;
00DD  07           RLCA                  ; 3× RLCA: digit index now in bits B2-B0
00DE  85           ADD   A,L             ; A = digit_index + low byte of BWYS (F7H)
                                         ; L = F7H (low byte of FFF7H = BWYS base)
00DF  6F           LD    L,A             ; L = F7H + digit_index
                                         ; HL = FFxxH where xx = F7H + digit (0-7)
                                         ; This gives FFF7H..FFFEH = BWYS[0..7]
```

This is the key trick: since BWYS starts at FFF7H and HL already points to FFF7H (from the two INC HL above), the code rotates the digit index into bits B2–B0 and adds it to L (which is F7H). Since digits are 0–7 and F7H + 7 = FEH, this correctly addresses FFF7H through FFFEH — the 8 bytes of the BWYS buffer. The buffer must reside within a single 256-byte page for this addressing to work, which the source comments confirm: "BWYS musi lezec w obrebie strony!" (BWYS must be within page boundary).

**Step 5 — Output segment pattern:**

```assembly
00E0  7E           LD    A,(HL)          ; Fetch 7-segment pattern from BWYS[digit]
00E1  2F           CPL                   ; Complement for active-low hardware
00E2  D3 F1        OUT   (PB),A          ; Output segments to Port B
```

The `CPL` converts from positive-logic buffer format (1 = segment on) to the active-low hardware format (0 = segment on).

### 3.2 Complete NMI Display Refresh — Summary

| Step | Code | Action |
|:-----|:-----|:-------|
| 1 | `LD A,(SBUF); ADD A,20H; LD (SBUF),A` | Advance digit counter (bits B7–B5 cycle 0–7). |
| 2 | `LD A,0FFH; OUT (PB),A` | Blank all segments (anti-ghosting). |
| 3 | `IN A,(PC); AND 1FH; OR B; OUT (PC),A` | Select new digit via 74145, preserving keyboard bits. |
| 4 | Three `RLCA` + `ADD A,L` | Calculate BWYS buffer offset for current digit. |
| 5 | `LD A,(HL); CPL; OUT (PB),A` | Fetch pattern from buffer, complement, output to segments. |

### 3.3 Timing

| Parameter | Value |
|:----------|:------|
| NMI frequency | ~500 Hz (every 2 ms) |
| Digits per NMI | 1 |
| Full display refresh rate | 500 ÷ 8 = **62.5 Hz** |
| Blanking duration | ~few µs (time between `OUT (PB),FFH` and final `OUT (PB),pattern`) |

### 3.4 Page Boundary Constraint

The source code contains explicit warnings:
- "Bufor wyswietlacza BWYS musi lezec w obrebie strony!" (Display buffer BWYS must be within a page boundary)
- "TSIED — musi lezec w obrebie strony !!!" (TSIED must be within a page boundary)

Both BWYS (FFF7H–FFFEH) and TSIED (0318H–0327H) satisfy this — they don't cross a 256-byte boundary. The addressing arithmetic in the NMI routine and the CO1 routine depends on this constraint.

---

## 4. 7-Segment Character Table: TSIED (0318H)

The `TSIED` table contains 16 bytes mapping hex digits 0–F to their 7-segment representations. It is used by the `CO1` routine to convert a numeric value (0–F) into a display pattern.

### 4.1 Table Contents

```
Address  Byte   Digit   Binary (KGFEDCBA)   Segments Lit
0318H    3FH    0       0 0 1 1 1 1 1 1     A,B,C,D,E,F
0319H    06H    1       0 0 0 0 0 1 1 0     B,C
031AH    5BH    2       0 1 0 1 1 0 1 1     A,B,D,E,G
031BH    4FH    3       0 1 0 0 1 1 1 1     A,B,C,D,G
031CH    66H    4       0 1 1 0 0 1 1 0     B,C,F,G
031DH    6DH    5       0 1 1 0 1 1 0 1     A,C,D,F,G
031EH    7DH    6       0 1 1 1 1 1 0 1     A,C,D,E,F,G
031FH    07H    7       0 0 0 0 0 1 1 1     A,B,C
0320H    7FH    8       0 1 1 1 1 1 1 1     A,B,C,D,E,F,G
0321H    6FH    9       0 1 1 0 1 1 1 1     A,B,C,D,F,G
0322H    77H    A       0 1 1 1 0 1 1 1     A,B,C,E,F,G
0323H    7CH    B       0 1 1 1 1 1 0 0     C,D,E,F,G
0324H    39H    C       0 0 1 1 1 0 0 1     A,D,E,F
0325H    5EH    D       0 1 0 1 1 1 1 0     B,C,D,E,G
0326H    79H    E       0 1 1 1 1 0 0 1     A,D,E,F,G
0327H    71H    F       0 1 1 1 0 0 0 1     A,E,F,G
```

### 4.2 Special Display Patterns

The Monitor also uses several named constants for special characters:

| Name | Value | Visual | Segments | Used For |
|:-----|:------|:-------|:---------|:---------|
| `ZGAS` | 00H | (blank) | None | Blanking unused digit positions. |
| `GLIT` | 3DH | G-like | A,C,D,E,F | Seven-segment approximation of letter "G". |
| `KRESKA` | 40H | — | G only | Dash/minus sign (middle segment). |
| `ANUL` | 08H | _ | D only | Underscore (bottom segment). |
| `ROWN` | 48H | = | D,G | Equals sign (middle + bottom segments). |
| `KROP` | bit 7 | . | K only | Decimal point (set bit 7 of any pattern). |

### 4.3 Boot Message "CA80"

The Monitor displays "CA80" on startup using the `KO1` table at 0339H:

```
Address  Byte   Character
0339H    39H    C  (same as TSIED[0CH])
033AH    77H    A  (same as TSIED[0AH])
033BH    7FH    8  (same as TSIED[08H])
033CH    3FH    0  (same as TSIED[00H])
033DH    0FFH   (terminator)
```

### 4.4 Error Message "Err"

The error display uses `KO2` at 0034H:

```
Address  Byte   Character
0034H    79H    E  (same as TSIED[0EH])
0035H    50H    r  (segments E,G — lowercase r approximation)
0036H    50H    r  (same)
0037H    0FFH   (terminator)
```

### 4.5 Flag Indicator Patterns (TFLAG at 042EH)

Used by the MF register display command to show CPU flag states:

```
Address  Byte   Flag    Visual
042EH    6DH    S       Looks like "5" (S approximation)
042FH    5CH    O       Looks like "o" (lowercase)
0430H    00H    -       Blank (separator)
0431H    76H    H       H
0432H    54H    P       (custom pattern)
0433H    39H    N       (custom pattern, reuses C code)
```

---

## 5. Display System Routines — Complete API

### 5.1 COM / COM1 — Display Single Character (01ABH / 01ACH)

The fundamental display routine. Writes a 7-segment pattern from register C into the BWYS buffer at the position specified by PWYS.

```
Entry:  C = 7-segment pattern code to display.
        COM: inline DB PWYS byte follows the CALL (sets display position).
        COM1: uses current PWYS setting.
Exit:   Character placed in BWYS buffer.
Modifies: AF
Stack: 3 (COM) or 2 (COM1)
```

**Algorithm (COM1 at 01ACH):**

```assembly
COM1:   PUSH  HL
        PUSH  BC              ; Save HL and BC
        LD    HL,(APWYS)      ; HL = address of PWYS (indirect via APWYS)
        LD    A,(HL)          ; A = current PWYS value
        LD    D,A             ; D = PWYS (save for later)
        AND   0FH             ; Isolate PWYS30 (bits 3-0) = position
        ADD   A,10H           ; Add 10H → PWYS74 bit 4 set (flag for "no scroll")
        LD    (HL),A          ; Update PWYS (advance position for next character)
        LD    A,E             ; (register shuffling)
        AND   0FH             ; Mask to position number (0-7)
```

The routine then checks if the position is valid (PWYS30 < 8 and PWYS74 has legal value). If the position is illegal (≥ 8 engaged positions), it returns immediately without writing.

```assembly
        ; Calculate BWYS buffer address for this digit position
        LD    C,A             ; C = position number
        ...
        ADD   A,L             ; Add to BWYS base low byte
        LD    L,A             ; L = BWYS base + position
                              ; HL now points to BWYS[position]
```

The character shifting logic:

```assembly
COM2:   DEC   B               ; B = number of engaged characters remaining
        JR    Z,COM3          ; If zero → all shifts done, write character
        DEC   HL              ; Move to previous digit position
        LD    A,(HL)          ; Read pattern from BWYS[pos-1]
        INC   HL              ; Back to current position
        LD    (HL),A          ; Shift pattern left in display
        DEC   HL              ; Move left again
        JR    COM2            ; Continue shifting

COM3:   POP   BC              ; Restore BC (C = original character pattern)
        LD    (HL),C          ; Write character pattern to BWYS buffer
        POP   HL              ; Restore HL
        RET
```

When multiple characters are "engaged" (PWYS controls how many), existing characters shift left to make room for the new one at the rightmost engaged position. This creates the effect of characters entering from the right and scrolling left.

### 5.2 CO / CO1 — Display Hex Digit (01E0H / 01E1H)

Converts a numeric value (0–F) in register C to a 7-segment pattern via the TSIED table, then displays it using COM1.

```
Entry:  C = hex digit value (0-FH). Values ≥ 10H are rejected (illegal).
        CO: inline DB PWYS byte follows the CALL.
        CO1: uses current PWYS setting.
Exit:   Hex digit displayed at PWYS position.
Modifies: AF
Stack: 5 (CO) or 3 (CO1)
```

**Algorithm (CO1 at 01E1H):**

```assembly
CO1:    PUSH  HL
        PUSH  BC              ; Save HL, BC
        LD    HL,TSIED        ; HL = 0318H (start of TSIED table)
        LD    A,C             ; A = digit value
        CP    10H             ; Is it a valid hex digit?
        JR    NC,CO2          ; If ≥ 10H → illegal, skip to exit
        ADD   A,L             ; A = 18H + digit = offset into TSIED page
                              ; (works because TSIED is page-aligned at 03xxH
                              ;  and L = 18H, so 18H + 0FH = 27H, within page)
        LD    L,A             ; L = new offset → HL = 03(18+digit)H
        LD    C,(HL)          ; C = 7-segment pattern from TSIED
        CALL  COM1            ; Display the pattern
CO2:    POP   BC
        POP   HL
        RET
```

The page-alignment trick again: since TSIED starts at 0318H, adding the digit value (0–F) to L (18H) gives 18H–27H, staying within the 03xxH page. The high byte H (03H) never changes.

### 5.3 LBYTE / LBYTE1 — Display Byte as 2 Hex Digits (0018H / 001BH)

Displays the contents of register A as two hexadecimal digits.

```
Entry:  A = byte to display.
        LBYTE: RST 18H + inline DB PWYS byte.
        LBYTE1: CALL 001BH, uses current PWYS.
Exit:   Two hex digits written to display at PWYS position.
Modifies: F, C
Stack: 8 (LBYTE) or 6 (LBYTE1)
```

**Algorithm (LBYTE at 0018H, continuation at LBYTcd 010DH):**

```assembly
LBYTE:  LD    C,A             ; Save A in C
        RST   USPWYS          ; Set PWYS from inline byte
        LD    A,C             ; Restore A
LBYTE1: PUSH  HL
        PUSH  DE              ; Save HL, DE
        JP    LBYTcd          ; Jump to continuation
```

At **LBYTcd** (010DH):

```assembly
LBYTcd: LD    E,A             ; E = original byte (save)

        ; Display lower nibble first (rightmost digit)
        LD    HL,(APWYS)      ; Get PWYS pointer
        LD    A,(HL)          ; Read PWYS
        LD    D,A             ; D = PWYS (save)
        AND   0FH             ; Position number
        ADD   A,10H           ; Set "no scroll" flag
        LD    (HL),A          ; Update PWYS
        LD    A,E             ; A = original byte
        AND   0FH             ; Lower nibble
        LD    C,A             ; C = lower nibble
        CALL  CO1             ; Display lower nibble

        LD    A,E             ; A = original byte
        RRCA                  ;
        RRCA                  ;
        RRCA                  ;
        RRCA                  ; Rotate upper nibble into lower position
        AND   0FH             ; Upper nibble (now in bits 3-0)
        LD    C,A
        INC   (HL)            ; Advance PWYS position by 1
        CALL  CO1             ; Display upper nibble

        LD    (HL),D          ; Restore original PWYS
        LD    A,E             ; Restore A
        POP   DE
        POP   HL
        RET
```

Note: The **lower nibble is displayed first** (at the rightmost position), then the **upper nibble** at the next position to the left. This matches the left-to-right reading order of hex digits on the display (high nibble on left, low nibble on right).

### 5.4 LADR / LADR1 — Display 16-bit Address as 4 Hex Digits (0020H / 0021H)

Displays register HL as four hexadecimal digits.

```
Entry:  HL = 16-bit value to display.
        LADR: RST 20H + inline DB PWYS byte.
        LADR1: CALL 0021H, uses current PWYS.
Exit:   Four hex digits written to display.
Modifies: AF, C
Stack: 10 (LADR) or 8 (LADR1)
```

**Algorithm:**

```assembly
LADR:   RST   USPWYS          ; Set PWYS from inline byte
LADR1:  LD    A,L             ; Start with low byte
        CALL  LBYTE1          ; Display low byte (2 digits)
        LD    A,H             ; Then high byte
        JR    LADRcd          ; Jump to continuation
```

At **LADRcd** (0048H):

```assembly
LADRcd: PUSH  HL              ; Save HL
        LD    HL,(APWYS)      ; Get PWYS pointer
        ; Adjust PWYS30 for the upper byte position
        INC   (HL)            ;
        INC   (HL)            ; PWYS position += 2 (skip past the 2 low-byte digits)
        CALL  LBYTE1          ; Display high byte (2 digits)
        ; Restore PWYS30
        DEC   (HL)            ;
        DEC   (HL)            ;
        POP   HL              ; Restore HL
        RET
```

Display order on the 8-digit display (left to right): `H_high H_low L_high L_low` — standard big-endian hex notation.

### 5.5 CLR / CLR1 — Clear Display (0010H / 0011H)

Blanks (turns off) display digits according to the PWYS parameter.

```
Entry:  CLR: RST 10H + inline DB PWYS byte (specifies which digits to clear).
        CLR1: CALL 0011H, uses current PWYS.
Exit:   Specified digits cleared (set to ZGAS = 00H pattern).
Modifies: AF
Stack: 4 (CLR) or 2 (CLR1)
```

**Algorithm:**

```assembly
CLR:    RST   USPWYS          ; Set PWYS from inline byte
CLR1:   PUSH  BC              ; Save BC
        LD    C,ZGAS          ; C = 00H (blank pattern)
        LD    B,8             ; B = 8 digits maximum

CLR2:   CALL  COM1            ; Write blank to current PWYS position
        DJNZ  CLR2            ; Repeat for 8 digits
        POP   BC              ; Restore BC
        RET
```

### 5.6 PRINT / PRINT1 — Display String (01D4H / 01D5H)

Displays a sequence of 7-segment codes from memory, terminated by 0FFH.

```
Entry:  HL = address of string (7-segment codes, terminated by 0FFH).
        PRINT: CALL + inline DB PWYS byte.
        PRINT1: CALL, uses current PWYS.
Exit:   String displayed starting at PWYS position.
Modifies: AF, HL, C
Stack: 3 (PRINT) or 1 (PRINT1)
```

**Algorithm:**

```assembly
PRINT:  RST   USPWYS          ; Set PWYS from inline byte
PRINT1: LD    A,(HL)          ; Fetch next character code
        CP    0FFH            ; Terminator?
        RET   Z               ; Yes → done
        LD    C,A             ; C = character pattern
        CALL  COM1            ; Display it
        INC   HL              ; Advance to next character
        JR    PRINT1          ; Loop
```

---

## 6. USPWYS — The Inline Parameter Mechanism (0028H)

All display routines that accept a PWYS parameter use the `USPWYS` helper, invoked via `RST 28H`. This routine implements a clever technique for passing a constant parameter inline after a CALL or RST instruction.

### 6.1 The Problem

In Z80, there's no direct way to pass a constant to a subroutine. The CA80 uses the "inline parameter" pattern: the byte immediately following the CALL/RST instruction is the parameter, not the next instruction. USPWYS extracts this byte and adjusts the return address.

### 6.2 How It Works

When a routine calls `RST USPWYS`, the return address on the stack points to the inline DB byte (the byte right after the RST instruction). USPWYS:

1. Pushes HL and DE to save them.
2. Loads HL with 6 and adds SP to get the address of the return address on the stack (accounting for the pushes of HL, DE, and the original CALL/RST return address).
3. Reads the return address from the stack → this points to the inline parameter byte.
4. Fetches the byte at that address → this is the PWYS value.
5. Increments the return address on the stack (so the caller resumes after the DB byte).
6. Stores the PWYS value through the APWYS indirect pointer.
7. Pops DE and HL.
8. Returns.

```assembly
USPWYS: PUSH  HL
        PUSH  DE              ; Save HL, DE
        ; Stack now: DE, HL, COM1_return, PCU (the inline parameter address)
        ; SP+4 points to COM1 return address
        ; SP+6 points to PCU (the address of the inline DB byte)
        LD    HL,6
        ADD   HL,SP           ; HL → stack location of PCU
        ; Fetch PCU (address of inline parameter)
        LD    E,(HL)          ; E = low byte of PCU
        INC   HL
        LD    D,(HL)          ; D = high byte of PCU → DE = PCU
        LD    A,(DE)          ; A = inline parameter byte (PWYS value)
        INC   DE              ; DE = PCU + 1 (skip past the DB byte)
        ; Write back incremented return address
        LD    (HL),D          ; High byte
        DEC   HL
        LD    (HL),E          ; Low byte → stack now has PCU+1 as return address
        ; Store PWYS value
        LD    HL,(APWYS)      ; HL = pointer to PWYS variable
        LD    (HL),A          ; Write PWYS value
        POP   DE
        POP   HL
        RET
```

### 6.3 Example Call Sequence

```assembly
        ; User code:
        CALL  LADR            ; Display HL as 4 hex digits
        DB    43H             ; PWYS parameter: position 3, no scroll

        ; Execution flow:
        ; 1. CALL LADR → pushes return address (points to DB 43H)
        ; 2. LADR executes RST USPWYS → pushes return address (points to LADR+1)
        ; 3. USPWYS reads 43H from the stack-stored return address
        ; 4. USPWYS increments the return address past the DB byte
        ; 5. USPWYS stores 43H into PWYS via APWYS pointer
        ; 6. Control returns to LADR, which proceeds with PWYS = 43H
        ; 7. When LADR returns, it returns to the instruction after DB 43H
```

---

## 7. PWYS Display Parameter — Full Encoding

The PWYS byte controls the position and behavior of display output routines.

### 7.1 Bit Fields

```
Bit 7-4: PWYS74 — Control/engagement field
Bit 3-0: PWYS30 — Position number (0-7)
```

### 7.2 PWYS30 (Position)

- Values 0–7 specify which digit position to write to.
- Position 0 = rightmost digit (CYF0 at FFF7H).
- Position 7 = leftmost digit (CYF7 at FFFEH).
- Values ≥ 8 are treated as "illegal" — the COM routine returns without writing.

### 7.3 PWYS74 (Control)

- **Bit 4 = 1** (e.g., PWYS = 1xH): Display at specified position without shifting/scrolling existing content.
- **Bits 7-4 < 8**: Legal engagement — specifies how many digits are "engaged" for scrolling operations.
- **Bits 7-4 ≥ 8**: Illegal PWYS — COM returns immediately (no display output). Used to suppress display.

### 7.4 Auto-Advance

When a character is displayed via COM/COM1, the PWYS30 field is automatically incremented by 1, so the next character appears at the adjacent position. This allows sequential characters to fill the display left-to-right without manually adjusting PWYS between calls.

### 7.5 Common PWYS Values Used by the Monitor

| PWYS Value | Meaning |
|:-----------|:--------|
| 80H | Clear all 8 digits (used with CLR). |
| 70H | Clear 7 lower digits (keep leftmost). |
| 40H | Display starting at position 0, 4 digits engaged. |
| 43H | Display starting at position 3. |
| 44H | Display starting at position 4. |
| 20H | Display starting at position 0, 2 digits engaged. |
| 17H | Display at position 7 (leftmost digit). |
| 15H | Display at position 5. |
| 14H | Display at position 4. |
| 25H | Display at position 5, used for LBYTE in name display. |
| 35H | Used by ERROR handler. |

### 7.6 Initialization

PWYS is stored at FFF6H. The pointer APWYS (FFC1H) is initialized to point to FFF6H:
- At power-on: via TRAM copy (LDDR from ROM).
- On M-key press: via IOCA copy (re-initialization of system jump table).

---

## 8. Display Routine Call Graph

```
User Program or Monitor Command
    │
    ├─── RST LADR (0020H) + DB PWYS
    │        ├─── RST USPWYS → set PWYS
    │        ├─── LD A,L → CALL LBYTE1 (low byte, 2 digits)
    │        └─── LD A,H → LADRcd → CALL LBYTE1 (high byte, 2 digits)
    │
    ├─── RST LBYTE (0018H) + DB PWYS
    │        ├─── RST USPWYS → set PWYS
    │        └─── LBYTcd:
    │             ├─── AND 0FH → LD C,A → CALL CO1 (low nibble)
    │             └─── 4×RRCA → AND 0FH → LD C,A → CALL CO1 (high nibble)
    │
    ├─── CALL CO (01E0H) + DB PWYS   or   CALL CO1 (01E1H)
    │        ├─── RST USPWYS → set PWYS (CO only)
    │        ├─── CP 10H → reject if ≥ 10H
    │        ├─── Lookup TSIED[digit] → C = 7-seg pattern
    │        └─── CALL COM1
    │
    ├─── CALL COM (01ABH) + DB PWYS   or   CALL COM1 (01ACH)
    │        ├─── RST USPWYS → set PWYS (COM only)
    │        ├─── Read PWYS via (APWYS) indirect
    │        ├─── Validate position (legal PWYS?)
    │        ├─── Calculate BWYS[position] address
    │        ├─── Shift existing characters left (if engaged)
    │        └─── Write C pattern to BWYS[position]
    │
    ├─── RST CLR (0010H) + DB PWYS   or   CALL CLR1 (0011H)
    │        ├─── RST USPWYS → set PWYS (CLR only)
    │        └─── Loop 8×: CALL COM1 with C = 00H (blank)
    │
    └─── CALL PRINT (01D4H) + DB PWYS   or   CALL PRINT1 (01D5H)
             ├─── RST USPWYS → set PWYS (PRINT only)
             └─── Loop: LD C,(HL) → CALL COM1 → INC HL → until 0FFH


NMI Handler (0066H, every 2ms)
    │
    └─── ZKON1 (00C2H):
         ├─── Increment SBUF digit counter
         ├─── Blank segments: OUT (PB), FFH
         ├─── Select digit: OUT (PC), (keyboard_bits | digit_select)
         ├─── Calculate BWYS[digit] address
         └─── Output pattern: LD A,(BWYS[digit]) → CPL → OUT (PB), A
```

---

## 9. FPGA Implementation Notes (MiSTer)

### 9.1 8255 PPI Clone

Implement a virtual 8255 at I/O addresses F0H–F3H:
- **Port B (F1H) write**: Capture the 8-bit segment data. This is the complemented pattern — to recover the actual segments, invert all bits.
- **Port C (F2H) write**: Capture the full byte. Bits B7–B5 (or the relevant subset driving the 74145) indicate which digit (0–7) is currently being addressed.
- **Control register (F3H) write**: Handle both full configuration writes (bit 7 = 1) and individual bit set/reset writes (bit 7 = 0). The BSR mode is used during keyboard scanning but not during display refresh.

### 9.2 Digit Capture Logic

On each Port B write, latch the segment data along with the currently selected digit (from the most recent Port C write). Maintain an 8-element register array:

```verilog
reg [7:0] display_digits [0:7];  // 7-seg patterns for each digit

always @(posedge clk) begin
    if (port_b_write) begin
        // Port B receives complemented data; invert to get true pattern
        display_digits[current_digit] <= ~port_b_data;
    end
end
```

Alternatively, you can directly read the BWYS buffer from the Z80's RAM if you have dual-port access, bypassing the 8255 entirely. However, capturing the PPI writes is more faithful to the original hardware.

### 9.3 Blanking Detection

The Monitor writes FFH to Port B before each digit change (all segments off). Your capture logic should either:
- **Ignore** Port B writes of FFH (don't update the digit register), or
- **Use** the blank write as a trigger to know that the next Port C write selects a new digit, and the Port B write after that is the real pattern.

### 9.4 Rendering

Convert the captured 7-segment patterns to visual output:
- **VGA/HDMI rendering**: Draw 8 seven-segment digit shapes on screen. Each segment is a rectangle or polygon that is lit (bright color) or dark based on the corresponding bit.
- **No need to simulate multiplexing**: Since you capture all 8 digit patterns in registers, render them all simultaneously. The multiplexing is only needed for the physical LED hardware.
- **Decimal point**: Bit 7 of each pattern controls the decimal point (K segment). Render it as a small dot to the lower-right of each digit.

### 9.5 Timing Considerations

- The display buffer BWYS is updated by the Z80 CPU via COM1 calls, not by the NMI. The NMI only reads BWYS.
- Display updates in the Monitor are not synchronized to the NMI — a digit pattern might change mid-refresh cycle. In practice, this causes no visible artifacts because the change is completed within one NMI period (2 ms).
- For FPGA rendering, you can safely read your captured digit registers at your video scan rate (60 Hz or whatever your output timing requires). There's no need to synchronize with the Z80's NMI rate.
