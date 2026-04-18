# CA80 Microcomputer Memory & I/O Map (Monitor V3.0)

This document provides a technical breakdown of the memory layout and I/O port mapping for the CA80 microcomputer, based on the analysis of the original Monitor V3.0 source code (MIK08).

## 1. Memory Address Space (Z80)

The CA80 uses a standard 64 KB address space. The system logic is divided into the Monitor ROM at the bottom and the System RAM at the very top.

### 1.1 ROM Space (0000H - 07FFH)
* [cite_start]**0000H - 07FFH**: Monitor ROM (2 KB)[cite: 34].
    * [cite_start]**0000H**: Cold reset entry point (Initialization of 8255 and jump to main loop)[cite: 43].
    * [cite_start]**0008H - 0028H**: Restart vectors (RST 08H to RST 28H) used as system calls for display, keyboard, and address printing[cite: 44, 46].
    * [cite_start]**0030H**: RESTA (RST 30H) - Software breakpoint/trap entry point[cite: 276, 281].
    * [cite_start]**0066H**: NMI Service Routine - Heartbeat of the system (Clock, Display refresh, Keyboard scan)[cite: 66, 311].
    * [cite_start]**0300H**: Keyboard Translation Table (TKLAW)[cite: 525, 1220].
    * [cite_start]**0318H**: 7-Segment Character Map (TSIED)[cite: 857, 1315].

### 1.2 User Space
* [cite_start]**C000H**: Default User Program Counter (PCUZYT)[cite: 43, 2054].
* [cite_start]**C100H**: Default User HL Register (HLUZYT)[cite: 43, 2054].

### 1.3 System RAM (FF8DH - FFFEH)
[cite_start]The Monitor uses a small block of RAM at the end of the memory space for stacks, variables, and buffers[cite: 2337].

| Address | Name | Description |
| :--- | :--- | :--- |
| **FF8DH** | `TOS` | [cite_start]Top of System Stack / Start of register storage[cite: 1086, 2353]. |
| **FF8DH-FF92H** | `ELOC-ALOC`| [cite_start]Storage for registers E, D, C, B, F, A during Monitor execution [cite: 2353-2383]. |
| **FF93H-FF96H** | `IXLOC, IYLOC`| [cite_start]Storage for Index registers IX and IY [cite: 2384-2396]. |
| **FF97H** | `SLOC` | [cite_start]User Stack Pointer storage[cite: 2408]. |
| **FFA2H** | `KROK` | [cite_start]Step execution flag (used for `*C` command)[cite: 2449]. |
| **FFA9H** | `PLOC` | [cite_start]User Program Counter storage[cite: 1752, 2454]. |
| **FFACH-FFB0H** | `TLOC` | [cite_start]Trap/Breakpoint addresses and instructions[cite: 1781, 2454]. |
| **FFB3H** | `GSTAT` | [cite_start]System Status (0 = User Program, ≠0 = Monitor)[cite: 311, 2454]. |
| **FFC1H** | `APWYS` | [cite_start]Pointer to the current Display Parameter (PWYS)[cite: 246, 2454]. |
| **FFCFH-FFDEH** | `INTU` | [cite_start]Interrupt Vector Table for user routines [cite: 2456-2457]. |
| **FFE8H** | `LCI` | [cite_start]Keyboard scan delay counter[cite: 2457]. |
| **FFEAH** | `TIME` | [cite_start]User-accessible 2ms countdown timer[cite: 2457]. |
| **FFEDH-FFF3H** | `RTC` | [cite_start]Real-Time Clock (Seconds, Minutes, Hours, Date, Year)[cite: 2457]. |
| **FFF7H-FFFEH** | `BWYS` | [cite_start]Display Buffer (Digits 0-7, 7-segment patterns)[cite: 315, 2457]. |

## 2. I/O Port Map

[cite_start]The system interacts with hardware via specific I/O addresses defined in the system equates[cite: 40, 43].

| Port | Device | Function |
| :--- | :--- | :--- |
| **F0H** | 8255 PPI Port A | [cite_start]Keyboard Row Input / Tape Input (Bit 4)[cite: 40, 436]. |
| **F1H** | 8255 PPI Port B | [cite_start]7-Segment Data (Segments A-G + DP)[cite: 40, 318]. |
| **F2H** | 8255 PPI Port C | [cite_start]Digit Select / Keyboard Column Drive[cite: 40, 318]. |
| **F3H** | 8255 PPI Control | [cite_start]Configuration register for the 8255 PPI[cite: 40, 485]. |
| **F8H** | Z80 CTC Ch 0 | [cite_start]Timer for Single Step execution[cite: 40, 2038]. |
| **F9H** | Z80 CTC Ch 1 | [cite_start]Heartbeat timer (Generates NMI at ~500Hz)[cite: 40, 1127]. |
| **ECH** | Sound | [cite_start]Toggle speaker/buzzer output[cite: 43]. |
| **FCH** | Interrupt Reset | [cite_start]Clear pending maskable interrupts[cite: 43]. |
