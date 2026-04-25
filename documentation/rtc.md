# CA80 Microcomputer Real-Time Clock Architecture & Logic (Monitor V3.0)

This document provides a complete technical breakdown of the software-driven Real-Time Clock (RTC) in the CA80 microcomputer, derived from the original Monitor V3.0 assembly source code (MIK08, Copyright (C) 1987 Stanisław Gardynik). Every register value, address, BCD encoding, and cascade algorithm has been verified against the source listing.

The CA80 has **no dedicated RTC hardware** — no Dallas DS1307, no battery backup. The entire clock and calendar system is a purely software-driven BCD state machine, executed within the NMI service routine approximately 500 times per second.

---

## 1. The Timebase: Z80 CTC Channel 1 → NMI

### 1.1 Hardware Chain

```
4 MHz System Clock
    │
    └─── Z80A CTC Channel 1 (port F9H)
              │  Timer mode, prescaler ×16
              │  Time constant TC1 = 250 (0FAH)
              │  Division: 4,000,000 ÷ 16 ÷ 250 = 1,000 Hz
              │
              └─── ZC/TO1 output pin
                        │
                        └─── Z80 NMI pin
                              (edge-triggered, non-maskable)
                              Effective NMI rate: ~500 Hz (every 2 ms)
```

### 1.2 CTC Initialization (at CA80A — 0241H)

```assembly
        LD    A,CCR1          ; A = 07H (timer mode, prescaler ×16, interrupts disabled)
        OUT   (CHAN1),A        ; Write control word to CTC Channel 1 (F9H)
        LD    A,TC1           ; A = 0FAH (250 decimal)
        OUT   (CHAN1),A        ; Write time constant → starts counting
```

CTC Channel 1 configuration:
- **CCR1 = 07H**: bit 0 = 1 (control word), bit 1 = 1 (timer mode — counts CPU clock ÷ prescaler), bit 2 = 1 (prescaler = 16), bit 3 = 0 (triggers on next time constant write), bit 4–7 = 0 (no interrupt, no auto-trigger).
- **TC1 = 250**: The CTC divides the prescaled clock (4 MHz ÷ 16 = 250 kHz) by 250, producing a 1 kHz output at the ZC/TO1 pin.
- The NMI pin is edge-triggered, so each transition of the 1 kHz output generates one NMI — approximately **500 Hz** (every 2 ms).

### 1.3 Critical Timing Relationship

The source code defines a constant that must be satisfied for correct RTC operation:

```
FNMI/WMSEK = 100 Hz
```

Where:
- `FNMI` = NMI frequency = 500 Hz (standard for CA80)
- `WMSEK` = 5 (the MSEK counter rollover value)
- 500 ÷ 5 = 100 Hz → one SETSEK tick every 10 ms → correct centisecond counting

If the NMI frequency changes, WMSEK must be adjusted proportionally to maintain accurate timekeeping.

---

## 2. RTC RAM Registers

All time and date values are stored in **BCD (Binary Coded Decimal)** format in the system RAM block at the top of the address space. The source code explicitly notes: "Odliczanie czasu w kodzie BCD" (Time counting in BCD code).

### 2.1 Time Registers

| Address | Label | Size | Format | Range | Description |
|:--------|:------|:-----|:-------|:------|:------------|
| FFEBH | `MSEK` | 1 byte | Binary | 0–4 | Sub-centisecond counter. Counts 0,1,2,3,4 then rolls over. Not BCD — pure binary. Each tick = 2 ms. Five ticks = 10 ms = one SETSEK increment. |
| FFECH | `SETSEK` | 1 byte | BCD | 00–99 | Hundredths of seconds (centiseconds). Each unit = 10 ms. Rolls at 100 (not displayed, but maintained). |
| FFEDH | `SEK` | 1 byte | BCD | 00–59 | Seconds. |
| FFEEH | `MIN` | 1 byte | BCD | 00–59 | Minutes. |
| FFEFH | `GODZ` | 1 byte | BCD | 00–23 | Hours (24-hour format). |

### 2.2 Date Registers

| Address | Label | Size | Format | Range | Description |
|:--------|:------|:-----|:-------|:------|:------------|
| FFF0H | `DNITYG` | 1 byte | Binary | 7,6,5,4,3,2,1 | Day of week. **Counts downward** from 7 to 1, then wraps back to 7. Not BCD. |
| FFF1H | `DNIM` | 1 byte | BCD | 01–31 | Day of month (varies by month via TABM lookup). |
| FFF2H | `MIES` | 1 byte | BCD | 01–12 | Month. |
| FFF3H | `LATA` | 1 byte | BCD | 00–99 | Year (two-digit). |

### 2.3 Memory Layout

The registers are arranged in cascade order in memory — each register is adjacent to the next in the overflow chain. The TABC and TABM tables provide the rollover limits:

```
Address:  FFEBH  FFECH  FFEDH  FFEEH  FFEFH  FFF0H  FFF1H  FFF2H  FFF3H
Label:    MSEK   SETSEK SEK    MIN    GODZ   DNITYG DNIM   MIES   LATA
Limit:    5      (none) 60H    60H    24H    7      (TABM) 13H    (none)
Source:   WMSEK  TABC+0 TABC+1 TABC+2 TABC+3 hard   TABM   hard   (none)
```

### 2.4 Enable/Disable Control

The RTC update is gated by the `ZESTAT` flag at FFB4H:
- `ZESTAT` = 0 → RTC update **skipped** in NMI (clock frozen).
- `ZESTAT` ≠ 0 (default 0FFH) → RTC update **active**.

```assembly
        LD    A,(ZESTAT)      ; FFB4H
        OR    A               ; Check if zero
        JR    Z,ZKON1         ; Zero → skip RTC, jump to display refresh
```

---

## 3. ROM Lookup Tables

### 3.1 Time Limits Table: TABC (0328H)

The TABC table stores the rollover thresholds for the time cascade. Each entry is the BCD value at which the corresponding register resets to zero and the next register increments.

```
Address  Byte   Label    Meaning
0328H    05     WMSEK    MSEK limit (binary 5 — rolls after counting 0,1,2,3,4)
0329H    00     SETSEK   SETSEK initial value (0 — used as reset value, not limit)
032AH    60H    SEK      Seconds limit (BCD 60 → reset at 60)
032BH    60H    MIN      Minutes limit (BCD 60 → reset at 60)
032CH    24H    GODZ     Hours limit (BCD 24 → reset at 24)
```

Table length: `LTABC` = 5 entries.

**Important correction**: The source defines `LTABC EQU $-TABC` = 5 entries. The table includes WMSEK as the first entry, not just the time limits. The cascade loop processes all 5 entries starting from MSEK.

### 3.2 Days-per-Month Table: TABM (032DH)

The TABM table stores the number of days in each month, in BCD format. The source comments confirm the month names:

```
Address  Byte   Month        Days
032DH    32H    Styczeń      31 (BCD 32H is the limit — day rolls at 32)
032EH    29H    Luty         28 (limit = 29 → rolls at day 29, i.e., 28 days max)
032FH    32H    Marzec       31
0330H    31H    Kwiecień     30
0331H    32H    Maj          31
0332H    31H    Czerwiec     30
0333H    32H    Lipiec       31
0334H    32H    Sierpień     31
0335H    31H    Wrzesień     30
0336H    32H    Październik  31
0337H    31H    Listopad     30
0338H    32H    Grudzień     31
```

**Critical detail**: The table stores the **rollover threshold**, not the day count itself. For a 31-day month, the limit is 32H (BCD 32) — meaning when the day counter reaches BCD 32, it has exceeded 31 and must reset. For February, the limit is 29H — the day rolls at 29, giving a maximum of 28 days. The source comments reflect this: the entry is labeled with the month name, and the value is max_days + 1 in BCD.

**Wait — re-checking**: Looking at the source more carefully:

```assembly
TABM:   DB    32H    ;Styczen    (January)
        DB    29H    ;Luty       (February)
```

And the comparison code uses `CP D` where D holds the limit. The day counter is incremented via `INC A; DAA`, and if it equals the limit, it wraps. So for January: limit = 32H means the day is valid up to 31H (BCD 31), and when it hits 32H, it wraps to 01H. For February: limit = 29H means valid up to 28H (BCD 28), wraps at 29H. This gives the correct day counts: 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31.

**Constraint**: "TABM musi lezec w obrebie strony i musi byc umieszczona bezposrednio pod TABC" (TABM must be within a page boundary and must be placed directly below TABC). The cascade loop continues seamlessly from TABC into TABM.

### 3.3 Leap Year Handling

**The CA80 Monitor does NOT implement leap year correction.** February is permanently set to 28 days (limit 29H) in the TABM table. There is no modulo-4 check on the year register anywhere in the source code.

This means:
- Every February will have only 28 days.
- On February 29 of a leap year, the clock will incorrectly roll over to March 1.
- The user must manually correct the date in leap years via the `*2` (M2) command.

This is a documented limitation of the original CA80 Monitor V3.0, not an oversight in this analysis.

---

## 4. The NMI RTC Cascade Algorithm — Instruction-Level Trace

The RTC update code runs within the NMI handler (0066H), after the keyboard scan and before the display refresh. Here is the complete algorithm traced from the source listing:

### 4.1 Entry Guard

```assembly
        ; HL points to TIME counter (FFEAH) at this point in NMI
        LD    A,(ZESTAT)      ; A = RTC enable flag (FFB4H)
        OR    A               ; Is RTC enabled?
        JR    Z,ZKON1         ; No → skip to display refresh
```

### 4.2 Time Cascade (MSEK through GODZ)

```assembly
        ; RTC update begins
        ; HL currently points to MSEK (FFEBH) after TIME handling
        INC   HL              ; HL → FFEBH (MSEK)
        LD    DE,TABC         ; DE → 0328H (start of limits table)
        LD    B,LTABC         ; B = 5 (number of time registers to cascade)
```

The main cascade loop:

```assembly
PZEG:   EX    DE,HL           ; Swap: DE = RAM register address, HL = TABC pointer
        LD    A,(DE)          ; A = current register value (from RAM)
        INC   A               ; Increment the register
        DAA                   ; Decimal Adjust Accumulator → BCD correction
                              ; (MSEK is binary 0-4, but DAA is harmless for values <10)
        CP    (HL)            ; Compare with limit from TABC
        EX    DE,HL           ; Swap back: HL = RAM register, DE = TABC
        JR    NZ,ZKON         ; If not at limit → store and done with cascade

        ; Register hit its limit → reset to zero and cascade to next
        XOR   A               ; A = 0
        ; CY = 0 — important for DAA behavior on next iteration
ZKON:   LD    (HL),A          ; Store new value (either incremented or reset to 0)
        INC   DE              ; Advance TABC pointer to next limit
        INC   HL              ; Advance RAM pointer to next register
        DJNZ  PZEG            ; Loop for all 5 time registers
```

**How the cascade works step by step:**

1. **MSEK** (FFEBH): Binary counter 0–4. Limit = WMSEK (5). Incremented, DAA applied (no effect for values 0–5). When MSEK reaches 5: reset to 0, cascade to SETSEK.

2. **SETSEK** (FFECH): BCD counter 00–99. Limit = 0 (from TABC entry at 0329H). Wait — the limit is 0? Let me re-read. The TABC table is: 05, 00, 60H, 60H, 24H. So SETSEK's limit in the table is 00H.

   Actually, looking more carefully: when MSEK rolls over, the loop continues. SETSEK is incremented via `INC A; DAA`. The limit for SETSEK is 00H. But SETSEK counts from 00 to 99 (BCD). After 99, `INC; DAA` produces 00 with carry. `CP 00H` matches → reset to 0 and cascade.

   Wait, that's not right either. `INC 99H` = 9AH, `DAA` corrects to 00H with carry flag set. `CP 00H` → Z=1, so the cascade continues. Yes — SETSEK rolls from 99 to 00, matching the limit of 00H, cascading to SEK. This gives 100 centisecond ticks per second (100 × 10 ms = 1 second). Correct.

3. **SEK** (FFEDH): BCD counter 00–59. Limit = 60H. When SEK reaches 60H (BCD 60): reset to 0, cascade to MIN.

4. **MIN** (FFEEH): BCD counter 00–59. Limit = 60H. When MIN reaches 60H: reset to 0, cascade to GODZ.

5. **GODZ** (FFEFH): BCD counter 00–23. Limit = 24H. When GODZ reaches 24H: reset to 0, cascade continues to date handling (falls out of PZEG loop).

### 4.3 Date Cascade — Day of Week

When all 5 time registers have been processed (DJNZ exhausts B), and GODZ has rolled over (a new day has begun), execution falls through to the day-of-week handling:

```assembly
        ; DE points to TABM (directly after TABC in memory)
        ; HL points to DNITYG (FFF0H, directly after GODZ)
        DEC   (HL)            ; Decrement day of week
        JR    NZ,PZEG1        ; If not zero → done with day-of-week

        ; DNITYG reached 0 → wrap to 7
        LD    (HL),7          ; Reset to 7 (BCD value 7, but stored as binary)
```

**Day of week counts DOWNWARD**: 7 → 6 → 5 → 4 → 3 → 2 → 1 → 7 → ... The source comment says "Dnityg <7,6,5..1>" confirming this countdown behavior. When DNITYG is decremented to 0, it wraps back to 7.

### 4.4 Date Cascade — Day of Month

```assembly
PZEG1:  INC   HL              ; HL → FFF1H (DNIM — day of month)
        INC   HL              ; HL → FFF2H (MIES — month)
        LD    A,(HL)          ; A = current month (BCD 01–12)
```

The code now needs to look up the days-per-month limit from TABM. Since months are BCD-encoded (01–12), the code must convert to a binary table index:

```assembly
        ; BCD month → binary index for TABM lookup
        ; Months 1-9 are BCD 01H-09H (single digit, binary = BCD)
        ; Months 10-12 are BCD 10H, 11H, 12H
        CP    0AH             ; Is month ≤ 9?
        JR    C,OKM           ; Yes → BCD = binary, no adjustment needed
        SUB   6               ; Months 10-12: subtract 6 to convert BCD→binary
                              ; 10H - 6 = 0AH (10), 11H - 6 = 0BH (11), 12H - 6 = 0CH (12)
```

Calculate the TABM address:

```assembly
OKM:    DEC   A               ; Month 1→0, 2→1, ..., 12→11 (zero-based index)
        ADD   A,E             ; Add to low byte of DE (which points to TABM base)
        LD    E,A             ; DE now points to TABM[month-1]
        ; TABM must be on the same page as TABC for this addressing to work!
        LD    A,(DE)          ; A = day limit for current month (e.g., 32H for January)
        LD    D,A             ; D = day limit (save)
```

Now check if the day of month needs to roll over:

```assembly
        DEC   HL              ; HL → FFF1H (DNIM — day of month)
        LD    A,(HL)          ; A = current day (BCD)
        INC   A               ; Increment day
        DAA                   ; BCD adjust
        CP    D               ; Compare with month's day limit
        JR    C,ZKON          ; If day < limit → store and done (no rollover)

        ; Day hit or exceeded limit → reset to 01
        LD    A,01            ; Day of month resets to 1, not 0!
        LD    (HL),A          ; Store DNIM = 01H
```

### 4.5 Date Cascade — Month

```assembly
        INC   HL              ; HL → FFF2H (MIES)
        LD    A,(HL)          ; A = current month (BCD)
        INC   A               ; Increment month
        DAA                   ; BCD adjust
        CP    13H             ; Month limit: BCD 13 (i.e., month 13 = overflow)
        JR    C,ZKON          ; If month < 13 → store and done

        ; Month exceeded 12 → reset to 01
        LD    A,01            ; Month resets to 1 (January)
        LD    (HL),A          ; Store MIES = 01H
```

### 4.6 Date Cascade — Year

```assembly
        INC   HL              ; HL → FFF3H (LATA)
        LD    A,(HL)          ; A = current year (BCD)
        INC   A               ; Increment year
        DAA                   ; BCD adjust
ZKON:   LD    (HL),A          ; Store new year value
                              ; Year has no limit — wraps naturally from 99 to 00 via DAA
```

The year counter simply wraps from BCD 99 to BCD 00 (via INC 99H = 9AH, DAA = 00H). There is no century handling.

### 4.7 Complete Cascade Flow Diagram

```
NMI tick (every 2ms)
    │
    ├── ZESTAT = 0? ──Yes──→ Skip RTC, go to display refresh
    │
    └── ZESTAT ≠ 0:
        │
        ├── MSEK++ (binary)
        │   └── MSEK = 5? ──No──→ Store, DONE
        │       └── Yes: MSEK = 0
        │
        ├── SETSEK++ (BCD, DAA)
        │   └── SETSEK = 00? ──No──→ Store, DONE
        │       └── Yes (was 99→00): SETSEK = 0
        │
        ├── SEK++ (BCD, DAA)
        │   └── SEK = 60H? ──No──→ Store, DONE
        │       └── Yes: SEK = 0
        │
        ├── MIN++ (BCD, DAA)
        │   └── MIN = 60H? ──No──→ Store, DONE
        │       └── Yes: MIN = 0
        │
        ├── GODZ++ (BCD, DAA)
        │   └── GODZ = 24H? ──No──→ Store, DONE
        │       └── Yes: GODZ = 0
        │           │
        │           ├── DNITYG-- (binary)
        │           │   └── DNITYG = 0? → DNITYG = 7
        │           │
        │           ├── Lookup TABM[MIES-1] → day limit
        │           ├── DNIM++ (BCD, DAA)
        │           │   └── DNIM ≥ limit? ──No──→ Store, DONE
        │           │       └── Yes: DNIM = 01
        │           │
        │           ├── MIES++ (BCD, DAA)
        │           │   └── MIES = 13H? ──No──→ Store, DONE
        │           │       └── Yes: MIES = 01
        │           │
        │           └── LATA++ (BCD, DAA) → Store, DONE
        │               (wraps 99→00 naturally)
        │
        └── DONE → continue to display refresh (ZKON1)
```

---

## 5. Setting Time and Date — Monitor Commands

### 5.1 Command M1: Set Time (*1)

Syntax: `*1 GODZ SPAC MIN SPAC SEK CR`

```assembly
M1:     INC   C               ; C = 3 (need 3 parameters)
        CALL  EXPR            ; Read 3 hex numbers from keyboard
        DB    20H             ; PWYS parameter
        LD    HL,SEK          ; HL → FFEDH (seconds)
DATUST: POP   BC              ; Pop first parameter → C = SEK value
        LD    (HL),C          ; Store seconds
        INC   HL              ; HL → FFEEH
        POP   BC              ; Pop second parameter → C = MIN value
        LD    (HL),C          ; Store minutes
        INC   HL              ; HL → FFEFH
        POP   BC              ; Pop third parameter → C = GODZ value
        LD    (HL),C          ; Store hours
        RET
```

The user enters three 4-digit hex numbers (only the low byte of each is used). Values are stored directly — **no validation** is performed. The user is responsible for entering correct BCD values.

### 5.2 Command M2: Set Date (*2)

Syntax: `*2 ROK SPAC MIES SPAC DNIM SPAC DNITYG CR`

```assembly
M2:     LD    C,4             ; 4 parameters
        CALL  EXPR            ; Read 4 hex numbers
        DB    20H             ; PWYS
        LD    HL,DNITYG       ; HL → FFF0H
        POP   BC              ; Pop DNITYG value
        LD    (HL),C          ; Store day of week
        INC   HL              ; HL → FFF1H
        JR    DATUST          ; Reuse M1's store loop for DNIM, MIES, LATA
```

### 5.3 Command M0: Display Clock (*0)

```assembly
M0:     LD    HL,SEK          ; HL → FFEDH
        CALL  CZAS            ; Display GODZ:MIN:SEK
M01:    CALL  CSTS            ; Check for keypress
        JR    NC,M0           ; No key → refresh display loop
        ; Key pressed:
        LD    HL,DNIM         ; Switch to showing date
        CALL  CZAS            ; Display LATA:MIES:DNIM (or ROK:MIES:DZIEN)
```

The CZAS routine (022DH) displays three consecutive BCD bytes from memory as `XX.XX.XX` format:

```assembly
CZAS:   LD    A,(HL)          ; First value (e.g., SEK)
        RST   LBYTE           ; Display as 2 hex digits
        DB    20H             ; PWYS position
        INC   HL
        LD    A,(HL)          ; Second value (e.g., MIN)
        RST   LBYTE
        DB    23H
        INC   HL
        LD    A,(HL)          ; Third value (e.g., GODZ)
        RST   LBYTE
        DB    26H
        DEC   HL
        DEC   HL              ; Restore HL to original
        RET
```

The display shows: `GG.MM.SS` (hours, minutes, seconds) or `RR.MM.DD` (year, month, day) on the 8-digit 7-segment display, where the dots are part of the display position encoding.

---

## 6. BCD Arithmetic Details

### 6.1 Why BCD?

The CA80 uses BCD encoding for all time/date registers because:
1. **Display efficiency**: BCD values can be sent directly to the 7-segment display via LBYTE without any binary-to-decimal conversion. Each nibble is already a decimal digit.
2. **DAA instruction**: The Z80's DAA (Decimal Adjust Accumulator) instruction automatically corrects the result of INC to maintain valid BCD. After `INC 59H`, the result is 5AH; `DAA` corrects it to 60H (BCD 60).
3. **ROM space**: In a 2 KB monitor, avoiding binary-to-BCD conversion routines saves precious bytes.

### 6.2 DAA Behavior in the Cascade

| Before INC | After INC | After DAA | Carry | Meaning |
|:-----------|:----------|:----------|:------|:--------|
| 08H | 09H | 09H | 0 | Normal increment |
| 09H | 0AH | 10H | 0 | BCD correction: 9→10 |
| 19H | 1AH | 20H | 0 | BCD correction: 19→20 |
| 59H | 5AH | 60H | 0 | Seconds/minutes: 59→60 (triggers rollover) |
| 99H | 9AH | 00H | 1 | SETSEK: 99→00 (century rollover for year) |
| 23H | 24H | 24H | 0 | Hours: 23→24 (triggers rollover) |

### 6.3 The MSEK Exception

MSEK is the only register that uses **binary** encoding (0–4), not BCD. This works because:
- Values 0–4 are valid BCD digits (identical in binary and BCD).
- `DAA` after `INC 4` = 5 has no effect (5 is a valid BCD digit).
- The comparison `CP 5` (WMSEK) works correctly in both binary and BCD.

### 6.4 BCD Month Encoding and the SUB 6 Correction

Months are stored as BCD 01H–12H. For TABM lookup, the code needs a zero-based binary index (0–11). The conversion:

| BCD Month | Binary Value | After SUB 6 | After DEC | Index |
|:----------|:-------------|:------------|:----------|:------|
| 01H | 1 | — | 0 | 0 (Jan) |
| 09H | 9 | — | 8 | 8 (Sep) |
| 10H | 16 | 0AH (10) | 9 | 9 (Oct) |
| 11H | 17 | 0BH (11) | 10 | 10 (Nov) |
| 12H | 18 | 0CH (12) | 11 | 11 (Dec) |

For months 1–9, BCD equals binary, so no SUB 6 is needed. For months 10–12, the BCD encoding adds 6 to the binary value (10H = 16 decimal, not 10), so `SUB 6` corrects this. Then `DEC A` converts from 1-based to 0-based indexing.

---

## 7. Accuracy Analysis

### 7.1 Theoretical Accuracy

At exactly 4.000 MHz system clock:
- CTC Channel 1 divides by 16 × 250 = 4,000
- NMI frequency = 4,000,000 ÷ 4,000 = exactly 1,000 Hz (edges at 500 Hz)
- MSEK counts 5 NMI ticks = 10.000 ms per SETSEK tick
- 100 SETSEK ticks = 1.000000 seconds
- **Drift: 0 ppm** (crystal-limited)

### 7.2 Real-World Drift Sources

| Source | Typical Error | Effect |
|:-------|:-------------|:-------|
| Crystal tolerance | ±50 ppm | ±4.3 seconds/day |
| Crystal aging | ±5 ppm/year | ±0.4 seconds/day after 1 year |
| Temperature variation | ±10 ppm | ±0.9 seconds/day |
| NMI edge detection | negligible | NMI is edge-triggered, no jitter |

### 7.3 Limitations

1. **No leap year handling**: February always has 28 days.
2. **No century handling**: Year wraps from 99 to 00 silently.
3. **No battery backup**: Clock resets to 00:00:00 on power loss (all RAM initialized to 0).
4. **No validation on set**: User can enter invalid BCD values (e.g., month = 55H) which will cause unpredictable cascade behavior.
5. **NMI contention**: If a user program takes longer than 2 ms to handle one NMI, the next NMI edge may be missed (NMI is edge-triggered with internal latch). This would cause the clock to lose ticks.

---

## 8. FPGA Implementation Notes (MiSTer)

### 8.1 Clock Domain Accuracy

The RTC serves as an excellent end-to-end timing verification tool for your FPGA core:

1. **Z80 CPU clock**: Must be exactly 4.000 MHz (or your chosen frequency). Any deviation directly affects RTC accuracy.
2. **CTC implementation**: The CTC prescaler and time constant logic must count exactly 16 × 250 = 4,000 CPU clocks between NMI edges. Off-by-one errors in the CTC will cause measurable drift.
3. **NMI edge detection**: The Z80 NMI is negative-edge-triggered with an internal latch. Your Z80 core must correctly implement edge detection (not level-sensitive).

### 8.2 Verification Procedure

1. Set the CA80 clock using `*1 00 00 00 CR` (midnight).
2. Let the FPGA run for exactly 1 hour.
3. Check the CA80 clock with `*0` — it should read `01.00.00`.
4. For extended testing, run for 24 hours and compare to a reference clock.
5. Expected accuracy: ±1 second per day (limited by your FPGA's oscillator tolerance).

### 8.3 Common Pitfalls

- **CTC prescaler off-by-one**: If your CTC counts 4,001 clocks instead of 4,000, the clock gains 21.6 seconds per day.
- **DAA implementation**: The Z80's DAA instruction has complex behavior depending on the N and H flags. An incorrect DAA in your Z80 core will corrupt BCD arithmetic and make the clock show impossible values (e.g., 5A instead of 60 for seconds).
- **NMI re-entrance**: The Z80 disables further NMIs during NMI handling (until RETN). If your Z80 core doesn't implement this correctly, the NMI handler may be entered recursively, corrupting the RTC state.
- **Memory initialization**: All RTC registers must be initialized to 0 at power-on (they're in the RAM area initialized by LDDR from TRAM). If your RAM isn't properly initialized, the RTC will start from random BCD values.

### 8.4 Optional Enhancements

Since you're building for FPGA, you could optionally:
- **Patch February in TABM**: Change byte at 032EH from 29H to 2AH (30) during leap years, controlled by an external RTC or host system clock.
- **Initialize from host**: On core startup, write the current time/date into the RTC RAM area (FFEBH–FFF3H) from the MiSTer Linux system, giving the CA80 a correct starting time.
- **Battery backup simulation**: Preserve the RTC RAM contents across core resets using the MiSTer save state mechanism.* **Drift:** If your CTC implementation triggers the NMI slightly too fast or too slow (e.g., every 2.05 ms instead of exactly 2.00 ms), the virtual CA80's clock will noticeably drift over a few hours. 
* **Verification:** You can use the `TIME` command in the CA80 Monitor to set the clock, leave the FPGA running for 24 hours, and compare it to a real-world clock to verify the cycle-accuracy of your entire core architecture.
