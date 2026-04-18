# CA80 Microcomputer Keyboard Architecture & Logic (Monitor V3.0)

This document details the complete software and hardware mechanics of the keyboard subsystem in the CA80 microcomputer, derived from the original Monitor V3.0 assembly source code (MIK08). The CA80 uses no dedicated keyboard controller — the Z80 CPU handles matrix scanning, debouncing, code translation, and acoustic feedback entirely in software, driven by the NMI interrupt.

---

## 1. Hardware Interface

### 1.1 Matrix Organization

The keyboard is a 10-row × 3-column switch matrix connected through the Intel 8255 PPI (system port, addresses F0H–F3H). The 8255 is configured with control word **90H** (Mode 0: PA = input, PB + PC = output).

- **Scanning output (columns):** Port C (F2H) — directly drives the keyboard matrix column select lines. The lower bits of PC (PC0–PC3) are used for row scanning. On the MIK94 board variant, Port A (F0H) and the KLAW shadow register (FFF4H) are used instead for column driving.
- **Sensing input (rows):** Port A (F0H) — bits **B6, B5, B4** carry the keyboard return signals.
- **Pull-up logic:** The sensing lines are pulled high by default. When no key is pressed, reading PA with mask 70H yields **70H** (all three bits high). Pressing a key pulls one of the sensing bits low.

### 1.2 Port Sharing

Port C is shared between the keyboard scanner and the 7-segment display multiplexer. The upper bits of PC (PC5–PC7) drive the display digit select via the 74145 BCD-to-decimal decoder. To avoid disturbing the display during keyboard scanning, the CSTSM routine uses the 8255's **bit set/reset** feature — writing individual bits of PC via the control register (F3H) rather than writing the entire port. This allows keyboard column scanning without corrupting the display multiplexing state.

### 1.3 8255 Bit Set/Reset Mechanism

The 8255 control register (F3H) supports a bit-set/reset mode when bit 7 of the written byte is 0. The format is:

```
Bit 7 = 0 (bit set/reset mode)
Bits 3-1 = bit number (0-7) of Port C to modify
Bit 0 = value (0 = reset, 1 = set)
```

The CSTSM routine uses this to manipulate PC0–PC3 individually, cycling through keyboard scan lines without affecting PC5–PC7 (display select).

---

## 2. Keyboard Scan Routine: CSTSM (0130H)

The `CSTSM` routine performs a **non-blocking** check to determine if any key is currently pressed. It is called via the indirect jump at `CSTS` (FFC3H → JP 0130H).

### 2.1 Entry & Exit

```
Entry:  No parameters.
Exit:   CY = 1, A = table code    → key is pressed.
        CY = 0                    → no key pressed.
Modifies: AF
Stack usage: 2 bytes (PUSH HL, PUSH BC internally)
```

### 2.2 Algorithm

```assembly
CSTSM:  PUSH  HL
        PUSH  BC
        LD    L,0AH          ; L = 10 decimal (scan 10 rows)

CST1:   DEC   L              ; L = 9, 8, ..., 1, 0, then 0FFH
        JP    M,CST2         ; If L went negative → no key found
        LD    A,L             ; A = current row number (9..0)
```

**Step 1 — Output scan code to keyboard matrix:**

For the **MIK94** board variant:
```assembly
        LD    (KLAW),A        ; Store in KLAW shadow register (FFF4H)
        OUT   (PA),A          ; Output to Port A (F0H) directly
```

For the **MIK90** board variant (bit-banging via 8255 control register):
```assembly
        ; Rotate row number bits into position for PC0-PC3
        ; Using 8255 bit set/reset commands via CONTR (F3H)
        RLCA                  ; Shift bits into position
        ...                   ; (4 iterations rotating and outputting)
        LD    B,A
        LD    A,B
        RLCA                  ; CY = next bit
        RLA                   ; A0 = CY = bit value for 8255 BSR
        OUT   (CONTR),A       ; Set/reset individual PC bit
```

The routine cycles through 4 bits of PC (PC0–PC3) using 4 iterations of RLCA + RLA + OUT, setting each bit individually via the 8255 BSR mechanism. This preserves PC5–PC7 (display state).

**Step 2 — Check for keypress:**

```assembly
CST4:   IN    A,(PA)          ; Read Port A (F0H)
        AND   70H             ; Mask bits B6-B4 only
        CP    70H             ; All high = no key pressed
        JR    Z,CST1          ; Z=1 → no key on this row, scan next

        ; Key detected!
        OR    L               ; Merge row number (bits 3-0) with
                              ; column data (bits 6-4)
                              ; Result = raw Hardware Keycode
        POP   BC
        POP   HL              ; Restore HL, BC
```

**Step 3 — Translate to table code:**

The routine falls through to `KONW` (not shown here — see Section 4) which converts the hardware keycode to a table code. On return: CY=1 if valid key, A = table code.

**Step 4 — No key found:**

```assembly
CST2:   OR    A               ; Clear carry (CY = 0)
        LD    A,L             ; A = 0FFH (or similar)
        POP   BC
        POP   HL
        RET                   ; Return with CY = 0
```

### 2.3 Hardware Keycode Construction

The hardware keycode is a single byte encoding the physical position of the pressed key:

```
Bit 7:   Always 0 (masked by AND 70H)
Bit 6-4: Column data (inverted sense — one bit low indicates which column)
Bit 3-0: Row number (0-9, from the scan counter L)
```

For example, if row 2 is active and column bit B5 goes low:
- PA reads as x01xxxxx → AND 70H → 20H
- Row = 2 → L = 02H
- OR L → hardware keycode = 22H

---

## 3. Hardware Keycode Map

The complete mapping of all 24 keys, derived from the TKLAW table at 0300H:

| Key | Hardware Code | Decoded As | Row (L) | Column Bits (PA & 70H) |
|:----|:-------------|:-----------|:--------|:-----------------------|
| 0 | 32H | 00H | 2 | 30H |
| 1 | 31H | 01H | 1 | 30H |
| 2 | 60H | 02H | 0 | 60H |
| 3 | 50H | 03H | 0 | 50H |
| 4 | 62H | 04H | 2 | 60H |
| 5 | 63H | 05H | 3 | 60H |
| 6 | 53H | 06H | 3 | 50H |
| 7 | 52H | 07H | 2 | 50H |
| 8 | 69H | 08H | 9 | 60H |
| 9 | 65H | 09H | 5 | 60H |
| A | 55H | 0AH | 5 | 50H |
| B | 59H | 0BH | 9 | 50H |
| C | 66H | 0CH | 6 | 60H |
| D | 67H | 0DH | 7 | 60H |
| E | 57H | 0EH | 7 | 50H |
| F | 56H | 0FH | 6 | 50H |
| G | 54H | 10H | 4 | 50H |
| SPAC (.) | 51H | 11H | 1 | 50H |
| CR (=) | 30H | 12H | 0 | 30H |
| M | 58H | 13H | 8 | 50H |
| W | 33H | 14H | 3 | 30H |
| X | 61H | 15H | 1 | 60H |
| Y | 64H | 16H | 4 | 60H |
| Z | 68H | 17H | 8 | 60H |

---

## 4. Keycode Translation: KONW Routine (015DH) & TKLAW Table (0300H)

### 4.1 The TKLAW Table

The keyboard translation table is strategically placed at address **0300H** — exactly at a 256-byte page boundary. It contains the 24 hardware keycodes in order of their logical (table) codes:

```
Address  Byte   Key    Table Code
0300H    32H    0      00H
0301H    31H    1      01H
0302H    60H    2      02H
0303H    50H    3      03H
0304H    62H    4      04H
0305H    63H    5      05H
0306H    53H    6      06H
0307H    52H    7      07H
0308H    69H    8      08H
0309H    65H    9      09H
030AH    55H    A      0AH
030BH    59H    B      0BH
030CH    66H    C      0CH
030DH    67H    D      0DH
030EH    57H    E      0EH
030FH    56H    F      0FH
0310H    54H    G      10H
0311H    51H    SPAC   11H
0312H    30H    CR     12H
0313H    58H    M      13H
0314H    33H    W      14H
0315H    61H    X      15H
0316H    64H    Y      16H
0317H    68H    Z      17H
```

Table length: `LTKLAW` = 18H (24 entries).

### 4.2 The Page-Alignment Trick

Because TKLAW starts at 0300H, the low byte of any entry's address directly equals the table code. When the KONW routine finds a matching hardware keycode at address 03xxH, it simply takes the low byte (xxH) as the logical key value. This eliminates the need for a separate index counter, saving ROM space and CPU cycles — an elegant optimization for a 2 KB monitor.

### 4.3 KONW Algorithm (015DH)

```
Entry:  A = hardware keycode (from CSTSM scan)
Exit:   CY = 1, A = table code    → valid key (found in TKLAW)
        CY = 0                    → illegal key (not in TKLAW)
Modifies: AF
Stack usage: 2 bytes (PUSH HL, PUSH BC internally)
```

```assembly
KONW:   PUSH  HL
        PUSH  BC              ; Save HL and BC
        LD    HL,TKLAW        ; HL = 0300H (start of table)
        LD    B,LTKLAW        ; B = 18H (24 entries to search)

CST5:   CP    (HL)            ; Compare hardware code with table entry
        SCF                   ; Pre-set carry (CY = 1, optimistic)
        JR    Z,CST2          ; Match found! Jump with CY=1
        INC   HL              ; Next table entry
        DJNZ  CST5            ; Loop until all 24 checked

        ; No match found
        OR    A               ; Clear carry (CY = 0)
CST2:   LD    A,L             ; A = low byte of HL = table code!
        POP   BC
        POP   HL              ; Restore HL and BC
        RET
```

Key points:
- The `SCF` before the `JR Z` is critical — it pre-sets the carry flag so that if the comparison succeeds, CY is already 1 when the routine exits.
- On a failed search, `OR A` clears CY. The value in A (= L) will be some address past the table end, but the caller checks CY first.

---

## 5. Character Input with Debounce: CI / CIM Routine (0184H)

The `CI` system call (via indirect jump at FFC6H → JP CIM at 0184H) provides a complete debounced keyboard input with acoustic feedback. It blocks until a valid key is pressed and released cleanly.

### 5.1 Entry & Exit

```
Entry:  No parameters.
Exit:   A = table code of pressed key.
        CY = 1           → key was CR
        Z = 1, CY = 0    → key was SPAC
        NZ, CY = 0       → other key
Modifies: AF
Stack usage: 4 bytes
```

### 5.2 Debounce Timing

The debounce mechanism uses the `LCI` counter at FFE8H, which is decremented by the NMI routine every 2 ms. The CI routine loads LCI with a value of **20** (decimal), then polls in a loop until LCI reaches zero — providing a **40 ms** debounce window (20 × 2 ms).

### 5.3 Algorithm: Two-Phase Debounce

**Phase 1 — Wait for key release (if any key is held):**

```assembly
CIM:    PUSH  HL              ; Save HL
        LD    HL,LCI          ; HL → FFE8H (debounce counter)

CI0:    LD    (HL),20         ; Load debounce timer: 20 × 2ms = 40ms
CI1:    LD    A,(HL)          ; Read current LCI value
        OR    A               ; Is it zero yet?
        JR    NZ,CI1          ; No — keep waiting (40ms not elapsed)
        CALL  CSTS            ; Check keyboard status
        JR    C,CI0           ; CY=1 → key still pressed, restart 40ms wait
```

This loop ensures that the key must be fully released for a continuous 40 ms period. Any bounce that re-triggers a keypress during the 40 ms window restarts the timer.

**Phase 2 — Wait for new keypress:**

```assembly
CI2:    LD    (HL),20         ; Load debounce timer: 40ms
CI3:    LD    A,(HL)          ; Read LCI
        OR    A
        JR    NZ,CI3          ; Wait 40ms
        CALL  CSTS            ; Check keyboard
        JR    NC,CI2          ; CY=0 → no key pressed, restart wait
```

This loop waits until a key is held down continuously for 40 ms, filtering out any spurious contact bounces.

**Phase 3 — Confirm and generate beep:**

```assembly
        ; Key confirmed — A contains table code from CSTS
        INC   HL              ; HL now points to SYG (FFE9H)
        LD    (HL),50         ; Set beep duration: 50 × 2ms = 100ms
```

The SYG counter triggers acoustic feedback via the NMI routine (see Section 6).

**Phase 4 — Return with key classification:**

```assembly
        POP   HL              ; Restore HL
        ; Fall through to CRSPAC or process key code
        ; Returns with CY/Z flags set per CR/SPAC detection
```

### 5.4 Timing Summary

| Phase | Duration | Condition |
|:------|:---------|:----------|
| Release debounce | 40 ms | Key must be released for full 40 ms |
| Press debounce | 40 ms | Key must be held for full 40 ms |
| Beep feedback | 100 ms | Audible confirmation of keypress |
| **Total minimum latency** | **~80 ms** | From finger press to accepted input |

---

## 6. Acoustic Feedback (Beep Generation)

### 6.1 Mechanism

The beep is generated entirely within the NMI service routine using two variables:

- **SYG** (FFE9H): Beep duration counter. Loaded with 50 (= 100 ms) when a key is confirmed. Decremented by NMI every 2 ms.
- **SYGNAL port** (ECH): Sound output toggle. Each `OUT (SYGNAL),A` toggles the speaker/buzzer line.

### 6.2 NMI Sound Generation Code

Within the NMI handler (0066H), after the keyboard debounce counter update:

```assembly
        ; HL points to SYG (FFE9H) at this point
        CP    (HL)            ; Check if SYG = 0
        JR    Z,KSYG          ; SYG = 0 → no sound, skip
        DEC   (HL)            ; Decrement SYG
        OUT   (SYGNAL),A      ; Toggle speaker output
KSYG:   ...
```

Since NMI fires at 500 Hz, the speaker toggles at 500 Hz, producing a **250 Hz square wave** tone (each toggle is half a cycle). The beep lasts for `SYG × 2 ms` = 100 ms with the default value of 50.

---

## 7. Text Input with Echo: TI / TI1 Routine (0007H / 0008H)

The `TI` routine combines keyboard input with display echo. It is the primary input method used by Monitor commands.

### 7.1 Entry & Exit

```
Entry:  Via RST TI (0007H) with inline DB PWYS byte, or CALL TI1 (0008H).
Exit:   A = table code of pressed key.
        CY = 1           → key was CR
        Z = 1, CY = 0    → key was SPAC
        NZ, CY = 0       → other key (hex digit 0-F echoed to display)
Modifies: AF
Stack usage: 8 bytes (TI) or 6 bytes (TI1)
```

### 7.2 Algorithm

```assembly
TI:     RST   USPWYS          ; Set PWYS from inline byte
TI1:    PUSH  BC              ; Save BC
        CALL  CI              ; Get debounced key → A = table code
        PUSH  AF              ; Save key code and flags
        LD    C,A             ; C = table code
        JR    TI1cd           ; Jump to continuation at 003BH
```

At **TI1cd** (003BH):

```assembly
TI1cd:  CALL  CO1             ; Display the hex digit (if C < 10H)
                              ; CO1 checks if C ≥ 10H and returns
                              ; without displaying if so (non-hex keys
                              ; like CR, SPAC, M are not echoed)
        POP   AF              ; Restore original A and flags
        POP   BC              ; Restore BC
        RET
```

The key insight: only hex digits (table codes 00H–0FH) are echoed to the display. Control keys (G, SPAC, CR, M, W, X, Y, Z — codes 10H–17H) are accepted and returned but produce no display output, because CO1 rejects values ≥ 10H.

---

## 8. The "M" (Monitor) Key — Emergency Override

### 8.1 Purpose

The M key serves as an absolute system override — a "panic button" that returns control to the Monitor OS regardless of what the user program is doing. It works even if the user program has disabled maskable interrupts, entered an infinite loop, or corrupted the stack, because it is processed within the **NMI (Non-Maskable Interrupt)** handler.

### 8.2 Detection (within NMI at 0066H)

The M-key detection occurs at the end of the NMI service routine, after display refresh. The code must scan for the M key without disturbing the current state of Port C (which controls display multiplexing) or Port A (which has other functions).

**For MIK90 board:**

```assembly
;MIK90
        LD    A,C             ; A = current PC state (saved earlier)
        AND   0F0H            ; Zero keyboard scan bits (keep display bits)
        ADD   A,MKLA30        ; Add M-key scan code (08H) to lower nibble
        OUT   (PC),A          ; Output: scan M-key row, preserve display
```

**For MIK94 board:**

```assembly
;MIK94
        LD    A,(KLAW)        ; Get KLAW shadow (bit B4 = magnetophone state)
        LD    B,A             ; Save original KLAW
        AND   10H             ; Preserve only bit B4 (tape state)
        ADD   A,MKLA30        ; Add M-key scan code (08H)
        OUT   (PA),A          ; Output to PA: scan M-key row
```

**Common check:**

```assembly
;MIK90 and MIK94
        IN    A,(PA)          ; Read keyboard matrix
        AND   70H             ; Mask sensing bits B6-B4
        CP    MKLA64          ; Compare with M-key signature (50H)
        LD    A,C              ; Restore PC state (MIK90)
        OUT   (PC),A          ; Restore Port C
        LD    A,B              ; Restore KLAW (MIK94)
        OUT   (PA),A          ; Restore Port A
        JP    Z,MWCIS         ; If M detected → emergency return!
```

### 8.3 M-Key Constants

| Constant | Value | Derivation | Description |
|:---------|:------|:-----------|:------------|
| `MKLA` | 58H | — | Full hardware keycode of M key. |
| `MKLA30` | 08H | MKLA AND 0FH | Lower nibble — row scan value for M key. |
| `MKLA64` | 50H | MKLA AND 70H | Upper nibble — expected column return for M key. |

### 8.4 Emergency Return: MWCIS (052FH)

When the M key is detected and `GSTAT` = 0 (user program is running):

```assembly
MWCIS:  DI                    ; Disable interrupts immediately
        ; Initialize RAM area <APWYS, NMIU>
        LD    HL,TNMIU        ; Source: default values in ROM
        LD    DE,NMIU         ; Destination: FFCCH
        LD    BC,LIOCA        ; Length: 12 bytes
        LDDR                  ; Copy defaults (reset APWYS, CSTS, CI, AREST, NMIU)
```

This reinitializes all the indirect jump vectors (CSTS, CI, AREST, NMIU) to their defaults, ensuring the Monitor regains control even if the user program had patched these vectors.

Then the routine:
1. Loads `GSTAT` with non-zero value (Monitor mode).
2. Clears display.
3. Outputs interrupt reset (`OUT (RESI),A`).
4. Jumps to `EXIT` → `START` — full Monitor restart.

### 8.5 When M Key Is Ignored

The M-key check includes a guard:

```assembly
        JP    Z,MWCIS         ; M key detected
        ; ... (M not pressed, fall through)
        POP   BC              ; Normal NMI exit
        CALL  NMIU            ; User NMI hook
        POP   DE
        POP   HL
        POP   AF
        RETN
```

And within MWCIS context, the `GSTAT` flag is checked:

- If `GSTAT` = 0 → user program was running → save state and return to Monitor.
- If `GSTAT` ≠ 0 → Monitor is already running → M key acts as a simple return to START (command prompt reset).

---

## 9. CR/SPAC Detection: CRSPAC Routine (01A2H)

A small utility used by TI, CI, PARAM, EXPR and other routines to classify the most recently pressed key:

```assembly
CRSPAC: CP    SPAC            ; Compare A with 11H
        RET   Z               ; Z=1, CY=0 → key is SPAC
        CP    CR              ; Compare A with 12H
        SCF                   ; Set carry
        RET   Z               ; Z=1, CY=1 → key is CR
        CCF                   ; Complement carry (CY=0)
        RET                   ; Z=0, CY=0 → other key
```

Return flags summary:

| Key | Z flag | CY flag |
|:----|:-------|:--------|
| SPAC (11H) | 1 | 0 |
| CR (12H) | 1 | 1 |
| Other | 0 | 0 |

This compact routine (9 bytes) provides a three-way classification using only the processor flags, avoiding any branching in the caller.

---

## 10. Keyboard-Related RAM Variables

| Address | Name | Size | Description |
|:--------|:-----|:-----|:------------|
| FFE8H | `LCI` | 1 byte | Debounce countdown timer. Loaded with 20 (40ms) by CI routine. Decremented every NMI tick (2ms). Key accepted when reaches 0. |
| FFE9H | `SYG` | 1 byte | Beep duration counter. Loaded with 50 (100ms) on confirmed keypress. NMI toggles SYGNAL port while SYG > 0. |
| FFF4H | `KLAW` | 1 byte | Shadow register for keyboard/tape output port PA (MIK94) or auxiliary state. Preserves bit B4 (tape output state) during keyboard scans. |

---

## 11. Keyboard-Related I/O Ports

| Port | Name | Role in Keyboard |
|:-----|:-----|:-----------------|
| F0H | PA (input) | Read keyboard matrix return. Bits B6–B4 carry column sense data. Masked with `AND 70H`. |
| F2H | PC (output) | Drive keyboard row select (bits PC0–PC3). Shared with display multiplexer (PC5–PC7). |
| F3H | CONTR | 8255 control register. Used for bit set/reset of individual PC bits during keyboard scan (MIK90 variant). |
| ECH | SYGNAL | Sound output toggle. Written by NMI to generate beep on keypress. |

---

## 12. Keyboard Routine Call Graph

```
User Program
    │
    ├─── CALL CI (FFC6H → JP CIM at 0184H)
    │        │
    │        ├─── Load LCI = 20 (40ms debounce)
    │        ├─── Poll LCI until 0 (via NMI decrement)
    │        ├─── CALL CSTS (FFC3H → JP CSTSM at 0130H)
    │        │        │
    │        │        ├─── Scan 10 rows (L = 9..0)
    │        │        │    ├─── Output row to PC (via BSR or direct)
    │        │        │    ├─── IN A,(PA) → AND 70H
    │        │        │    └─── If ≠ 70H → key found, OR L → hardware code
    │        │        │
    │        │        └─── CALL KONW (015DH)
    │        │                 │
    │        │                 ├─── Search TKLAW (0300H, 24 entries)
    │        │                 ├─── Match → A = low byte of address = table code
    │        │                 └─── CY=1 (valid) or CY=0 (illegal)
    │        │
    │        ├─── Phase 1: Loop until key released for 40ms
    │        ├─── Phase 2: Loop until key held for 40ms
    │        ├─── Set SYG = 50 (100ms beep)
    │        └─── Return: A = table code, CY/Z = CR/SPAC flags
    │
    └─── RST TI (0007H) / CALL TI1 (0008H)
             │
             ├─── RST USPWYS (set display position)
             ├─── CALL CI (get debounced key)
             ├─── CALL CO1 (echo hex digit to display, if 0-F)
             └─── Return: A = table code, CY/Z = CR/SPAC flags


NMI Handler (0066H, fires every 2ms)
    │
    ├─── Decrement LCI (if > 0)
    ├─── If SYG > 0: decrement SYG, OUT (SYGNAL),A → toggle speaker
    ├─── Decrement TIME counter
    ├─── Update RTC
    ├─── Refresh display
    └─── Check M key (hardcoded scan)
         └─── If M pressed AND GSTAT=0 → JP MWCIS (emergency return)
```

---

## 13. FPGA Implementation Notes (MiSTer)

### 13.1 Strategy

When implementing the CA80 core for MiSTer FPGA, you do not need to physically simulate the 10-row × 3-column switch matrix with multiplexed scanning. The original Monitor ROM handles all the scanning logic itself — you only need to present the correct electrical responses on the virtual 8255 port.

### 13.2 Virtual 8255 Approach

Build a virtual 8255 PPI in Verilog/SystemVerilog:

1. **Intercept Port C writes (F2H) and CONTR BSR writes (F3H):** Decode which keyboard row the Z80 is currently scanning.

2. **Map USB/PS2 keyboard to hardware keycodes:** Maintain a lookup table that maps modern keyboard scancodes to CA80 hardware keycodes (e.g., PC keyboard "0" → 32H).

3. **Generate Port A read response (F0H):** When the Z80 executes `IN A,(F0H)`:
   - Check if any mapped key is currently held down.
   - If the held key's row matches the currently scanned row (from the last PC write), return the key's column bits (e.g., 50H for column B5, 60H for column B6, 30H for column B5+B4).
   - If no match, return 70H (no key pressed).

4. **The Monitor ROM does the rest:** CSTSM will find the key, KONW will translate it, CI will debounce it, and TI will echo it — all in the original Z80 code running on the soft CPU.

### 13.3 Suggested Modern Key Mapping

| CA80 Key | Table Code | Suggested PC Key |
|:---------|:-----------|:-----------------|
| 0–9 | 00H–09H | Number keys 0–9 |
| A–F | 0AH–0FH | Keys A–F |
| G | 10H | G |
| SPAC | 11H | Space or Period |
| CR | 12H | Enter |
| M | 13H | M or Escape |
| W | 14H | W |
| X | 15H | X |
| Y | 16H | Y |
| Z | 17H | Z |

### 13.4 Critical Timing Considerations

- The NMI must fire at approximately 500 Hz (every 2 ms at 4 MHz clock). This drives all keyboard timing.
- The LCI debounce counter expects exactly 2 ms per NMI tick. If your clock frequency differs from 4 MHz, adjust the CTC Channel 1 time constant or NMI generation rate accordingly.
- The SYG beep counter and TIME general-purpose timer also depend on the 2 ms NMI rate.
- The M-key detection within NMI depends on being able to scan the keyboard matrix mid-NMI. Your virtual 8255 must respond to the scan-then-read sequence within the NMI handler's execution window.
