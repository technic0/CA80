# CA80 Microcomputer Display Operation Logic

This document describes the software and hardware mechanism used by the **CA80 microcomputer** (designed by Stanisław Gardynik) to drive its 8-digit 7-segment LED display. The analysis is based on the official **Monitor CA80 V3.0** source code (MIK08).

## 1. Hardware Interface
The CA80 uses the **Intel 8255 (PPI - Programmable Peripheral Interface)**, referred to in the code as the "System Port" (Port Systemowy), located at the following I/O addresses:
* **Port A (0F0H):** Configured as Input (used for keyboard sensing).
* **Port B (0F1H):** Configured as Output (Segment Data).
* **Port C (0F2H):** Configured as Output (Digit Selection/Multiplexing).
* [cite_start]**Control Register (0F3H):** Initialized with `90H` at startup to set the directions[cite: 40, 43].

## 2. Dynamic Multiplexing (Scanning)
The CA80 does not have a dedicated display controller chip. Instead, it uses **software-driven dynamic multiplexing**. Each of the 8 digits is illuminated one at a time at a very high frequency, creating the illusion of a continuous display to the human eye.

[cite_start]This process is handled within the **NMI (Non-Maskable Interrupt)** routine, which occurs periodically (triggered by the Z80 CTC timer)[cite: 40, 309].

## 3. The NMI Display Routine Step-by-Step
[cite_start]The logic for refreshing a single digit starts at address `00C2H` in the Monitor code[cite: 315, 318]:

1.  **Blanking:**
    The system first sends `0FFH` to Port B. This effectively turns off all segments, preventing "ghosting" while switching digits[cite: 318].
    ```assembly
    LD A, 0FFH
    OUT (PB), A
    ```

2.  **Digit Selection:**
    The system maintains a counter in memory called `SBUF` (address `FFF5H`). This counter determines which of the 8 digits is currently being processed. The 3 most significant bits of this byte represent the digit index (0-7)[cite: 315].
    The code reads `SBUF`, increments the index, and outputs it to **Port C**. Port C is connected to a hardware decoder (e.g., 74145) that pulls the common anode/cathode of the selected digit[cite: 318].

3.  **Data Retrieval:**
    The pattern to be displayed is stored in a RAM buffer called `BWYS` (starting at `FFF7H`). Each byte in this buffer corresponds to one digit.
    The index from `SBUF` is used to calculate the offset in `BWYS`[cite: 318].

4.  **Pattern Output:**
    The 7-segment pattern is fetched from the buffer. Because the display hardware typically uses negative logic (0 = Segment ON, 1 = Segment OFF), the code performs a bitwise NOT operation (`CPL`) before sending the data to **Port B**[cite: 318].
    ```assembly
    LD A, (HL)  ; Fetch pattern from BWYS buffer
    CPL         ; Invert bits for negative logic
    OUT (PB), A ; Light up the segments
    ```

## 4. Character Mapping (TSIED Table)
[cite_start]To display hexadecimal values (0-F), the system uses a lookup table called `TSIED` located at address `0318H`[cite: 1315, 1316]. 

Each byte in the table represents the physical segments (A through G and the Decimal Point). For example:
* [cite_start]`0` is represented by `3FH` (Segments A, B, C, D, E, F are ON)[cite: 1316, 1318].
* [cite_start]`A` is represented by `77H`[cite: 1326].

## 5. Memory Buffers
* **BWYS (FFF7H - FFFEH):** The 8-byte display buffer. [cite_start]Writing a segment bitmask to these addresses will change what appears on the display during the next NMI cycle[cite: 2457].
* [cite_start]**SBUF (FFF5H):** Stores the current scan state (which digit is currently active)[cite: 2457].
* [cite_start]**PWYS (FFF6H):** A parameter used by system subroutines (like `LBYTE` or `LADR`) to determine where on the display a value should be printed[cite: 2457].

## Summary for FPGA Implementation
To recreate this in FPGA (MiSTer):
1.  Implement an **8255 PPI** clone at I/O `F0h-F3h`.
2.  Port B should be mapped to an internal register representing the segment bus.
3.  Port C (bits 0-2) should be mapped to a digit selector.
4.  Write a small Verilog/VHDL module that reads these two virtual ports and renders a 7-segment shape on the HDMI/VGA output based on the multiplexing state.
