# CA80 Software Real-Time Clock (RTC) Architecture

This document details the mechanics of the Real-Time Clock in the CA80 microcomputer. Unlike modern systems or later retrocomputers, the CA80 **does not have a dedicated hardware RTC chip** (like the Dallas DS1307) or battery backup. 

Instead, the entire calendar and clock system is a **purely software-driven state machine**, executed continuously within the Non-Maskable Interrupt (NMI) service routine.

## 1. The Heartbeat: Z80 CTC and NMI

The foundation of the clock is the **Zilog Z80 CTC (Counter/Timer Circuit)**. 

During the system initialization (Cold Reset), the Monitor configures **CTC Channel 1 (I/O Port 0F9H)** to operate in timer mode. It divides the main system clock (typically 4 MHz) to generate a precise pulse at a frequency of **500 Hz**. 

The output of CTC Channel 1 is physically wired to the **NMI (Non-Maskable Interrupt)** pin of the Z80 CPU. This means that exactly every **2 milliseconds**, the CPU suspends whatever user program is running and jumps to the NMI service routine at address `0066H`.

## 2. RTC RAM Registers

The current time and date are stored as standard 8-bit variables in the system RAM block located near the end of the address space.

| Address | Symbol | Function | Description |
| :--- | :--- | :--- | :--- |
| **FFECH** | `MSEK` | Sub-seconds | Counts from 500 down to 0 (representing 2ms intervals). |
| **FFEDH** | `SEK` | Seconds | 0 to 59. |
| **FFEEH** | `MIN` | Minutes | 0 to 59. |
| **FFEFH** | `GODZ` | Hours | 0 to 23. |
| **FFF0H** | `DNTY` | Day of Week| 1 to 7 (1 = Monday, 7 = Sunday). |
| **FFF1H** | `DZIEN`| Day of Month| 1 to 31 (depending on the month). |
| **FFF2H** | `MIES` | Month | 1 to 12. |
| **FFF3H** | `ROK` | Year | 0 to 99 (represents 19xx or 20xx depending on context). |

## 3. The Cascade Logic (NMI Execution)

Every 2 milliseconds, the NMI routine executes the RTC update logic:

1.  **Sub-second Decrement:** The routine decrements the `MSEK` counter. If the result is not zero, the RTC update finishes immediately, and the CPU moves on to refresh the display or scan the keyboard.
2.  **The Ripple Effect:** If `MSEK` hits zero, exactly one second has passed. The routine resets `MSEK` back to 500 and increments the `SEK` (Seconds) register.
3.  **Threshold Checking:** The routine then checks if the newly incremented register has hit its logical limit. If `SEK` reaches 60, it resets to 0 and increments `MIN`. If `MIN` reaches 60, it resets to 0 and increments `GODZ`, and so on.

## 4. ROM Lookup Tables (`TABC` and `TABM`)

To know when a register should overflow and reset, the CA80 Monitor uses two predefined lookup tables stored in ROM. This avoids hardcoding dozens of `CMP` (Compare) instructions.

### 4.1 Time Limits Table (`TABC`)
Located in the ROM, this table contains the rollover thresholds for standard time metrics:
* `60` (Seconds rollover)
* `60` (Minutes rollover)
* `24` (Hours rollover)
* `07` (Day of the Week rollover)

### 4.2 Days in Months Table (`TABM`)
To handle the calendar accurately, the system must know how many days are in the current month. The `TABM` table stores 12 bytes:
`31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31`

**Leap Year Handling:** When the cascade logic reaches the point of incrementing the Month, it reads the current value of `MIES` to index into the `TABM` table. 
If the current month is February (index 2), the software performs a modulo 4 check on the `ROK` (Year) register. If the year is evenly divisible by 4, it temporarily substitutes the limit `28` with `29`, ensuring perfect leap-year accuracy.

## 5. FPGA Implementation Notes (MiSTer)

When rebuilding the CA80 in a modern FPGA environment, the software RTC serves as the ultimate benchmark for your system's timing accuracy:

* **Cycle Accuracy is Critical:** Your Z80 core (e.g., T80) and your Z80 CTC core must be perfectly synchronized to the main clock domain. 
* **Drift:** If your CTC implementation triggers the NMI slightly too fast or too slow (e.g., every 2.05 ms instead of exactly 2.00 ms), the virtual CA80's clock will noticeably drift over a few hours. 
* **Verification:** You can use the `TIME` command in the CA80 Monitor to set the clock, leave the FPGA running for 24 hours, and compare it to a real-world clock to verify the cycle-accuracy of your entire core architecture.
