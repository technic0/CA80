# CA80 Cassette Tape Interface Architecture (Monitor V3.0)

This document details the mechanics of the cassette tape storage system in the CA80 microcomputer. In the early 1980s, standard audio cassette recorders were the primary mass storage devices for microcomputers. 

The CA80 **does not have a dedicated hardware UART or tape controller IC**. The entire process of modulating and demodulating audio signals is performed purely through software ("bit-banging") by the Z80 CPU, utilizing the Intel 8255 Programmable Peripheral Interface (PPI).

## 1. Hardware Interface

The tape interface connects to the audio input (MIC) and output (EAR/Line Out) of a standard cassette recorder through simple analog conditioning circuits, interfacing directly with the 8255 PPI.

* **Tape Input (Read):** Connected to **Port A (0F0H)**. Specifically, the software polls **Bit 4** (`PA4`) to read the incoming audio waveform.
* **Tape Output (Write):** Connected to **Port C**. To generate the audio signal without disrupting the multiplexed display (which shares the upper bits of Port C), the Z80 uses the 8255's Bit Set/Reset (BSR) feature via the **Control Register (0F3H)** to toggle a specific bit (typically **PC3** in the MIK90 hardware revision).

## 2. Signal Encoding (Software PWM)

The system stores data on tape using a form of software-driven Pulse Width Modulation (PWM) or Frequency Shift Keying (FSK). 
Instead of sending voltage levels (which audio tape cannot reliably store), it sends audio square waves. The difference between a logical `1` and a logical `0` is determined by the **duration (width)** of the audio pulse.

* **`MAGSP` (Tape Speed Parameter):** The timing of these pulses is governed by a software delay constant, typically referred to in the routines as `MAGSP`. This value determines how many times a software loop executes, thus controlling the physical pitch and speed of the recorded data.
* **Generating a '1' (`GJED` Routine):** The CPU toggles the output pin, enters a specific delay loop, and toggles it back. A logical `1` is typically represented by a longer pulse or a specific sequence of pulses.
* **Generating a '0' (`GZER` Routine):** Similar to `GJED`, but utilizes a shorter delay loop, creating a higher-frequency or shorter pulse.

## 3. Writing to Tape (`M4` Command)

When the user executes the `M4` (Save) command, the Monitor initiates the write sequence:

1. **Pilot Tone (Synchronization):** The CPU first outputs a continuous stream of identical pulses (the "pilot tone" or leader) for several seconds. This gives the tape recorder's automatic gain control (AGC) time to stabilize and provides a clear signal for the loading routine to lock onto.
2. **Header Information:** The system writes the starting memory address and the ending memory address of the data block to be saved.
3. **Data Block (`WBYT` Routine):** The CPU reads bytes from the user's RAM. For each byte, the `WBYT` (Write Byte) routine shifts the byte bit-by-bit. Depending on whether the carry flag is `1` or `0`, it calls `GJED` or `GZER` respectively.
4. **Checksum:** After the final data byte, the CPU calculates and writes a checksum byte (a simple arithmetic sum or XOR of all data bytes) to allow for error detection during loading.

## 4. Reading from Tape (`M6` Command)

When the user executes the `M6` (Load) command, the Monitor enters a highly timing-sensitive read state:

1. **Wait for Pilot:** The CPU rapidly polls Port A, Bit 4 (`IN A, (0F0H)` followed by `AND 10H`). It waits until it detects the steady fluctuation of the pilot tone.
2. **Pulse Measurement (`LICZ` Routine):** Once the data block begins, the `LICZ` (Count) routine measures the exact time between voltage transitions (from HIGH to LOW to HIGH). It does this by incrementing a register in a tight polling loop until the pin state changes.
3. **Bit Decoding:** The measured duration is compared against a threshold. 
    * If the count is *below* the threshold, it is interpreted as a `0`.
    * If the count is *above* the threshold, it is interpreted as a `1`.
4. **Byte Assembly (`RBYT` Routine):** The `RBYT` (Read Byte) routine shifts the newly decoded bit into a register. After 8 bits are collected, the full byte is written to the destination RAM address.
5. **Verification:** The system maintains a running checksum of the loaded bytes. At the end of the load, it compares its internal checksum with the checksum read from the tape. If they do not match, an error is typically shown on the display.

## 5. FPGA Implementation Notes (MiSTer)

Implementing the tape interface in an FPGA environment offers a few modern conveniences:

* **Audio Routing:** In the MiSTer framework, you can route a virtual `.cas` or `.wav` file playback directly into your Z80's virtual `Port A (Bit 4)`.
* **Perfect Signal:** Because the virtual audio signal is mathematically perfect (no tape hiss, wow, or flutter), the CA80's software `LICZ` routine will decode the data with 100% reliability, provided your Z80 core's clock cycle timing is accurate.
* **Fast Loading (Optional):** Advanced FPGA implementations sometimes intercept the `M6` ROM call (bypassing the slow audio routines entirely) and instantly inject the requested binary file directly into the virtual RAM via Direct Memory Access (DMA), though this sacrifices historical accuracy for convenience.
