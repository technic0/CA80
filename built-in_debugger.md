# CA80 Hardware/Software Debugger Architecture (Monitor V3.0)

This document details the mechanics of the CA80 microcomputer's built-in debugger. In an era without modern IDEs, Stanisław Gardynik implemented a highly sophisticated, hybrid hardware-software debugging system that allowed users to set breakpoints and step through their code instruction by instruction.

The debugger relies on two distinct mechanisms: **Software Traps** (Breakpoints) and **Hardware-Assisted Single-Stepping**.

## 1. Software Breakpoints (Traps via `*G` Command)

When a user wants to execute their program but pause it at a specific address, they use the `*G` (Go) command followed by a target address. The Monitor handles this using a classic "opcode substitution" technique.

### How Traps Work:
1. **Opcode Substitution:** Before jumping to the user's program, the Monitor secretly reads the original instruction byte at the target breakpoint address and saves it in a safe RAM location (`TLOC` at `FFACH`).
2. **Planting the Trap:** It replaces that byte with the opcode `0F7H`. This is the Z80 instruction for `RST 30H` (Restart 30 Hex).
3. **Execution:** The Monitor hands control over to the user's program. The CPU runs at full speed.
4. **Triggering the Trap:** When the CPU reaches the breakpoint address, it fetches `0F7H` instead of the user's code. `RST 30H` forces the CPU to immediately push its current Program Counter (PC) to the stack and jump to address `0030H` in the Monitor ROM.
5. **Recovery (`RESTAR` Routine):** * At `0030H`, a jump vector redirects the CPU to the `RESTAR` routine.
   * The Monitor captures all CPU registers (AF, BC, DE, HL, IX, IY, SP) and saves them to the System RAM storage block (`FF8DH` - `FF97H`).
   * It restores the original opcode from `TLOC` back into the user's program so it isn't permanently corrupted.
   * It sets the system status flag `GSTAT` (`FFB3H`) to indicate the Monitor is back in control, and displays the current CPU state to the user.

## 2. Hardware Single-Stepping (`*C` Command)

Setting breakpoints is useful, but sometimes a programmer needs to execute code exactly one instruction at a time. Because Z80 instructions vary in length and execution time, doing this purely in software is nearly impossible. 

The CA80 solves this brilliantly by using the **Z80 CTC (Counter/Timer Circuit)** to generate a highly precise hardware interrupt.

### The Single-Step Mechanism:
1. **Hardware Allocation:** While CTC Channel 1 is used for the RTC/NMI heartbeat, the Monitor reserves **CTC Channel 0 (I/O Port 0F8H)** specifically for the debugger.
2. **Setting the Timer:** When the user issues the `*C` (Step) command, the Monitor programs CTC Channel 0 to operate in timer mode. 
3. **The Magic Number (160 T-States):** The Monitor loads a specific time constant into the CTC. The goal is to delay the interrupt for exactly **160 CPU clock cycles (T-states)**. 
4. **The Race:** * The Monitor enables maskable interrupts (`EI`) and executes a `RET` (Return) instruction to jump back into the user's code.
   * *Simultaneously*, the CTC starts counting down those 160 clock cycles.
5. **The Capture:** 160 T-states is perfectly calculated to be long enough for the CPU to finish the Monitor's jump routine and execute **exactly one** instruction of the user's program. Just as the user's first instruction finishes, the CTC counter hits zero and fires a hardware interrupt (`INT`).
6. **Return to Monitor:** The CPU is yanked out of the user program back into the Monitor's interrupt vector table, the registers are saved to RAM, and the next instruction's address is displayed on the LED screen.

## 3. Context Switching & State Management

To allow seamless transitions between the user program and the Monitor OS without corrupting the user's data, the CA80 maintains strict boundaries in the RAM:

* **`TOS` (Top of System Stack - FF8DH):** The Monitor uses its own stack area. Before jumping to user code, it saves the system stack pointer. When an interrupt or trap occurs, it safely switches back to this stack.
* **`GSTAT` (System Status - FFB3H):** This byte acts as a mutex lock. If `GSTAT` is `0`, the system assumes a user program is running. If it is non-zero, the Monitor is active. This prevents nested interrupts from crashing the OS.

## 4. FPGA Implementation Notes (MiSTer)

For an FPGA engineer, the CA80 debugger is the ultimate stress test for your Z80 and CTC cores.

* **Cycle-Accuracy is Mandatory:** The `*C` single-step function relies absolutely on **Cycle-Accurate (Cycle-Exact)** timing. If your virtual Z80 core (like T80) takes 11 clock cycles to execute an instruction that historically took 10, or if your virtual CTC starts counting 1 clock cycle too late, the 160 T-state window will drift. 
* **The Failure Mode:** If timing is inaccurate, the hardware interrupt will fire *while* the user instruction is halfway through executing, or it will wait too long and allow *two* user instructions to execute. If your FPGA core can successfully run the `*C` command without crashing, you have mathematically proven that your CPU and Timer cores are perfectly cycle-accurate to the original 1980s silicon.
