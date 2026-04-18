# CA80 Microcomputer Memory & I/O Map (Monitor V3.0)

This document provides a technical breakdown of the memory layout and I/O port mapping for the CA80 microcomputer, based on the original Monitor V3.0 assembly source code.

## 1. Memory Address Space (Z80)

The CA80 uses a standard 64 KB address space. The system logic is divided into the Monitor ROM at the bottom and the System RAM at the very top.

### 1.1 ROM Space (0000H - 07FFH)
* **0000H - 07FFH**: Monitor ROM (2 KB).
    * **0000H**: Cold reset entry point (Initialization of 8255 PPI and jump to main loop).
    * **0008H - 0028H**: Restart vectors (RST 08H to RST 28H) used as system calls for display, keyboard, and value printing.
    * **0030H**: RESTA (RST 30H) - Software breakpoint/trap entry point.
    * **0066H**: NMI Service Routine - Heartbeat of the system (RTC, Display refresh, Keyboard scan).
    * **0300H**: Keyboard Translation Table (TKLAW).
    * **0318H**: 7-Segment Character Map (TSIED).

### 1.2 User Space
* **C000H**: Default User Program Counter (PCUZYT).
* **C100H**: Default User HL Register (HLUZYT).

### 1.3 System RAM (FF8DH - FFFEH)
The Monitor uses a small block of RAM at the end of the memory space for stacks, variables, and buffers.

| Address | Name | Description |
| :--- | :--- | :--- |
| **FF8DH** | `TOS` | Top of System Stack / Start of user register storage. |
| **FF8DH-FF92H** | `REG_STOR`| Storage for registers E, D, C, B, F, A during Monitor execution. |
| **FF93H-FF96H** | `IX_IY` | Storage for Index registers IX and IY. |
| **FF97H** | `SLOC` | User Stack Pointer (SP) storage. |
| **FFA2H** | `KROK` | Step execution flag (used for `*C` step-by-step command). |
| **FFA9H** | `PLOC` | User Program Counter (PC) storage. |
| **FFACH-FFB0H** | `TLOC` | Trap/Breakpoint addresses and instructions storage. |
| **FFB3H** | `GSTAT` | System Status (0 = User Program executing, ≠0 = Monitor executing). |
| **FFC1H** | `APWYS` | Pointer to the current Display Parameter (PWYS). |
| **FFE8H** | `LCI` | Keyboard scan delay counter. |
| **FFEAH** | `TIME` | User-accessible 2ms countdown timer. |
| **FFEDH-FFF3H** | `RTC` | Real-Time Clock (Seconds, Minutes, Hours, Date, Month, Year). |
| **FFF4H** | `KLAW` | Current output state of the keyboard port. |
| **FFF7H-FFFEH** | `BWYS` | Display Buffer (8 bytes storing 7-segment patterns for digits 0-7). |

## 2. I/O Port Map

The system interacts with hardware via specific I/O addresses using Z80 `IN` and `OUT` instructions.

| Port | Device | Function |
| :--- | :--- | :--- |
| **F0H** | 8255 PPI Port A | Keyboard Row Input / Tape Input (Bit 4). |
| **F1H** | 8255 PPI Port B | 7-Segment Data Output (Segments A-G + Decimal Point). |
| **F2H** | 8255 PPI Port C | Digit Select (Multiplexing) / Keyboard Column Drive Output. |
| **F3H** | 8255 PPI Control | Configuration register for the 8255 PPI (initialized with `90H`). |
| **F8H** | Z80 CTC Ch 0 | Timer used for Single Step execution (counts 160 cycles). |
| **F9H** | Z80 CTC Ch 1 | Heartbeat timer (Generates NMI at ~500Hz). |
| **ECH** | Sound | Toggle speaker/buzzer output (Generates beep). |
| **FCH** | INT Reset | Clear pending maskable interrupts. |

## 3. Core System Calls (API)

These can be called in user programs via `CALL` or `RST` instructions:

* **LADR (0020H)**: Prints the contents of the HL register as 4 HEX digits.
* **LBYTE (0018H)**: Prints the contents of the A register as 2 HEX digits.
* **TI (0007H)**: Fetches a key from the keyboard and echoes it to the display.
* **PRINT (01D4H)**: Prints a text string from memory (terminated by `0FFH`).
* **CLR (0010H)**: Clears the display according to the `PWYS` parameter.
