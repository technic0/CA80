# CA80 Microcomputer Keyboard Architecture & Logic (Monitor V3.0)

This document details the software and hardware mechanics of the keyboard in the CA80 microcomputer. The CA80 does not use a dedicated keyboard controller; instead, the Z80 CPU handles matrix scanning, debouncing, and decoding entirely in software.

## 1. Hardware Interface (The Matrix)

The keyboard is organized as a hardware matrix connected to the Intel 8255 Programmable Peripheral Interface (PPI):
* **Output / Scanning Lines:** The CPU sends a scan code (from 0 to 9) to **Port C (0F2H)** (or Port A in the MIK94 hardware revision).
* **Input / Sensing Lines:** The CPU reads the state of the matrix on **Port A (0F0H)**.
* **Active-Low Logic:** The sensing lines are pulled high. The software masks the input using `70H` to read bits **PA4, PA5, and PA6**. If no key is pressed, these bits read as `1` (yielding `70H`). Pressing a key shorts the line, bringing one of the bits to `0`.

## 2. The Scanning Algorithm (`CSTS` Routine - 0130H)

The `CSTS` (Check Status) routine performs a non-blocking check to see if any key is currently pressed.

1.  **The Loop:** A counter (register `L`) is initialized to `0AH` (10 decimal). The loop decrements this counter to scan 10 lines of the matrix.
2.  **Outputting the Scan Code:** In the MIK90 hardware, the CPU manipulates individual bits of Port C (PC0-PC3) via the 8255 Control Register (`0F3H`). This clever bit-banging prevents interference with the 7-segment display multiplexing, which shares the upper bits of Port C.
3.  **Reading the Matrix:** The CPU reads Port A (`IN A, (F0H)`) and applies the bitmask `AND 70H`.
4.  **Evaluation:** * If the result equals `70H` (Zero Flag set), no key is pressed on this row. The loop continues.
    * If the result differs from `70H`, a key is detected. The CPU merges the row counter (`L`) with the masked input bits (`OR L`). The resulting byte is the raw **Hardware Keycode** (representing the physical coordinates of the button).

## 3. Keycode Translation (`KONW` Routine & `TKLAW` Table)

The raw Hardware Keycode is not useful for programming (e.g., the "0" key yields `32H`, not `00H`). Stanisław Gardynik implemented an elegant lookup table to translate these codes.

* **The TKLAW Table (0300H):** A translation table is placed exactly at the beginning of a memory page (`0300H`). It contains the physical Hardware Keycodes.
    ```assembly
    0300H: 32H  ; Hardware code for key "0"
    0301H: 31H  ; Hardware code for key "1"
    ...
    030AH: 55H  ; Hardware code for key "A"
    ```
* **The Trick:** The `KONW` routine (`015DH`) scans this table for a match to the pressed hardware keycode. Because the table is page-aligned (`03xx`), once a match is found, **the lower byte of the memory address inherently represents the logical keycode**. For example, if `32H` is found at address `0300H`, the logical value is `00H`. This saves valuable ROM space and CPU cycles.

## 4. Debouncing and Acoustic Feedback (`CI` Routine - 0184H)

Mechanical switches suffer from "contact bounce," which can register as multiple rapid keystrokes. The `CI` (Character Input) routine ensures clean, single inputs:

1.  **Release Debounce:** Sets the `LCI` software counter (in RAM at `FFE8H`) to 40 milliseconds. The CPU waits in a loop until the key is completely released and the contacts settle.
2.  **Press Debounce:** Once released, it waits for the next keypress, again enforcing a 40ms debounce delay.
3.  **Buzzer Activation:** Upon a confirmed keystroke, the routine sets the `SYG` variable (`FFE9H`) to 100 milliseconds. 
4.  **Sound Generation:** The NMI routine checks the `SYG` counter. As long as it is greater than zero, the NMI routine toggles the audio port (`0ECH`) 500 times per second, generating a distinct beep.

## 5. The "M" (Monitor) Panic Button

The "M" key is the system's absolute override button, used to break out of frozen user programs and return to the Monitor OS. 

Because it must work even if the system is hung, it is **not** scanned by the standard `CSTS` routine. Instead, it is hardcoded into the hardware **NMI (Non-Maskable Interrupt)** routine (`0066H`), which fires 500 times per second:

1.  The NMI routine forces the specific scan code `08H` out to the matrix.
2.  It immediately reads the input. If the return value is `50H`, the "M" key is being held down.
3.  **Emergency Escape:** If detected, the Z80 pushes all current registers to the system stack, changes the `GSTAT` flag (`FFB3H`) to Monitor mode, and executes a jump to the `START` routine (`0270H`), regaining complete control of the machine.

---

## FPGA Implementation Notes (MiSTer)
When implementing this core in an FPGA, you do not need to simulate the physical matrix scanning row-by-row if you are using a modern USB keyboard. 
You can build a virtual 8255 port in Verilog. When the Z80 core executes an `IN A, (0F0H)` instruction, your logic can intercept this and directly provide the corresponding raw Hardware Keycode (e.g., `32H` for the '0' key). The original CA80 ROM's `KONW` routine will seamlessly translate your injected hardware code into the correct logical character.
