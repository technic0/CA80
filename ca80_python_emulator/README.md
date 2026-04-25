# CA-80 Microcomputer Emulator (Python)

A faithful emulator of the Polish 8-bit microcomputer **CA-80** (extended MIK290 configuration), written in Python. Includes both a terminal-based UI and a web-based UI that mirrors the original hardware front panel.

The CA-80 is a Z80-based educational microcomputer designed in Poland in the mid-1980s, featuring a hex keypad, 8-digit 7-segment LED display, and a built-in machine-code monitor program. This emulator reproduces it cycle-accurately with full audio support.

---

## Table of Contents

- [Features](#features)
- [Hardware Configuration](#hardware-configuration)
- [Requirements](#requirements)
- [Installation](#installation)
- [Required ROM Files](#required-rom-files)
- [Running the Terminal Emulator](#running-the-terminal-emulator)
- [Running the Web Emulator](#running-the-web-emulator)
- [Keyboard Mapping](#keyboard-mapping)
- [Monitor Commands](#monitor-commands)
- [Sound](#sound)
- [Memory Map](#memory-map)
- [Architecture Overview](#architecture-overview)
- [Troubleshooting](#troubleshooting)
- [Acknowledgments](#acknowledgments)

---

## Features

- **Cycle-accurate Z80 emulation** at 4 MHz
- **Full 8-digit 7-segment display** with multiplexed refresh
- **Complete 24-key keyboard matrix** (4×6) including F1-F4 function keys
- **Hardware-accurate sound** — port `0xEC` → 74123 monostable → speaker, with DC blocker
- **Two front-end variants**:
  - **Terminal UI** using `blessed` library — runs entirely in your terminal
  - **Web UI** using `aiohttp` server + React frontend — beautiful pixel-accurate front panel in your browser
- **NMI from independent oscillator** (~500 Hz, matching real hardware)
- **Memory map matching MIK09 documentation** — 16 KB monitor + 16 KB C800 + 16 KB C930 + 16 KB RAM
- **Verified against original CA-80 documentation** (R23, R24, MIK09, MIK11)
- **F1-F4 mapped correctly** to keyboard codes 0x17, 0x16, 0x15, 0x14 (per R23 table)

---

## Hardware Configuration

This emulator implements the **extended MIK290 configuration** as documented in MIK09 Chapter 3.0:

| Socket | Address Range | Size  | Content                       |
|--------|---------------|-------|-------------------------------|
| U9     | 0x0000-0x3FFF | 16 KB | System Monitor (`CA80.BIN`)   |
| U10    | 0x4000-0x7FFF | 16 KB | C800 package (`C800.BIN`)     |
| U11    | 0x8000-0xBFFF | 16 KB | C930 package (`C930.BIN`)     |
| U12    | 0xC000-0xFFFF | 16 KB | RAM (62256 or 6264)           |

ROMs smaller than 16 KB are mirrored to fill the full slot, matching the partial address decoding of the real hardware.

---

## Requirements

- **Python 3.11 or newer** (3.13 tested)
- For terminal version: `blessed`, `numpy`, `sounddevice`
- For web version: `aiohttp` (plus `numpy`, `sounddevice` for audio)

The audio dependencies (`sounddevice`, `numpy`) are optional — without them, the emulator runs silently but everything else works.

---

## Installation

### 1. Clone or download this repository

```bash
git clone https://github.com/technic0/CA80.git
cd CA80/ca80_python_emulator
```

### 2. Create a virtual environment (recommended)

```bash
python3 -m venv .venv
source .venv/bin/activate   # macOS/Linux
# or:
.venv\Scripts\activate      # Windows
```

### 3. Install dependencies

For terminal version:
```bash
pip install blessed numpy sounddevice
```

For web version:
```bash
pip install -r requirements-web.txt
```

You can install both — they don't conflict.

### 4. Place ROM files in the same directory

You need three binary ROM files: `CA80.BIN`, `C800.BIN`, `C930.BIN`. See [Required ROM Files](#required-rom-files) below.

---

## Required ROM Files

The emulator needs three ROM files which are not included in this repository (they are copyrighted firmware of the original CA-80 hardware):

| File       | Size    | Purpose                                              |
|------------|---------|------------------------------------------------------|
| `CA80.BIN` | 8 KB    | System Monitor (mirrored to fill 16 KB U9 slot)      |
| `C800.BIN` | 2 KB    | C800 package — built-in games, dice, MASTER MIND, etc. |
| `C930.BIN` | 16 KB   | C930 package — cassette tape interface and tools     |

These files should be obtained from the original CA-80 documentation/firmware archives. They must be in the same directory as `ca80.py` / `ca80_web.py`, or their paths must be provided via command-line options.

---

## Running the Terminal Emulator

The terminal version (`ca80.py`) uses the [`blessed`](https://pypi.org/project/blessed/) library to render the front panel as ASCII art directly in your terminal.

### Basic usage

```bash
python ca80.py
```

Press `q` or `Ctrl+C` to quit.

### Command-line options

```
python ca80.py [--monitor PLIK] [--c930 PLIK] [--c800 PLIK]
               [--anode] [--step] [--no-audio]
```

| Option       | Description                                                                                       | Default       |
|--------------|---------------------------------------------------------------------------------------------------|---------------|
| `--monitor`  | Path to the system monitor ROM (loaded into U9 @ 0x0000)                                          | `CA80.BIN`    |
| `--c930`     | Path to the C930 ROM (loaded into U11 @ 0x8000)                                                   | `C930.BIN`    |
| `--c800`     | Path to the C800 ROM (loaded into U10 @ 0x4000)                                                   | `C800.BIN`    |
| `--anode`    | Common-anode display mode (inverts segment polarity for displays wired with shared anode)         | (cathode)     |
| `--step`     | Single-step mode — press Enter to execute one instruction at a time. Useful for debugging.        | (run mode)    |
| `--no-audio` | Disable audio output. Use if `sounddevice` is not installed or to run silently.                   | (audio on)    |

### Examples

```bash
# Default configuration
python ca80.py

# Custom ROM file paths
python ca80.py --monitor /path/to/MIK290.BIN --c800 /path/to/games.bin

# Silent mode (no audio)
python ca80.py --no-audio

# Single-step debugging
python ca80.py --step
```

### What you'll see

The terminal UI shows:
- An 8-digit 7-segment display rendered as ASCII art (top)
- A status panel with currently pressed keys and last-key debug info (middle)
- Instructions for keyboard input (bottom)

The display will boot with `    CA80` prompt, indicating the system monitor is ready.

---

## Running the Web Emulator

The web version (`ca80_web.py`) starts a local HTTP server with a WebSocket bridge to the emulator core. The frontend is a React application that renders a pixel-accurate replica of the CA-80 front panel.

### Basic usage

```bash
python ca80_web.py
```

Then open **http://localhost:8000/** in your browser.

Press `Ctrl+C` in the terminal to stop the server.

### Command-line options

```
python ca80_web.py [--port PORT] [--monitor PLIK] [--c930 PLIK] [--c800 PLIK]
                   [--anode] [--no-audio]
```

| Option       | Description                                                                  | Default       |
|--------------|------------------------------------------------------------------------------|---------------|
| `--port`     | TCP port for the HTTP server                                                 | `8000`        |
| `--monitor`  | Path to the system monitor ROM (loaded into U9 @ 0x0000)                     | `CA80.BIN`    |
| `--c930`     | Path to the C930 ROM (loaded into U11 @ 0x8000)                              | `C930.BIN`    |
| `--c800`     | Path to the C800 ROM (loaded into U10 @ 0x4000)                              | `C800.BIN`    |
| `--anode`    | Common-anode display mode (inverts segment polarity)                         | (cathode)     |
| `--no-audio` | Disable audio output                                                         | (audio on)    |

### Examples

```bash
# Default
python ca80_web.py

# Custom port
python ca80_web.py --port 9000

# Silent
python ca80_web.py --no-audio
```

### Web UI features

- **Click or tap keys** with mouse / touchscreen — events are sent as `keydown` / `keyup` to the emulator
- **Physical PC keyboard** also works simultaneously (digits, A-F, G, M, F1-F4, period, Enter, space)
- **Display refreshes at 60 fps** via WebSocket from the emulator
- **Auto-reconnect** if connection drops (e.g., server restart)
- **Status indicator** at the bottom shows connection state and CPU activity
- **Audio** runs server-side via `sounddevice`, identical to terminal version

### Directory layout

```
ca80_python_emulator/
├── ca80_web.py
├── ca80.py
├── ca80_memory.py
├── ca80_ports.py
├── ca80_sound.py
├── Z80_core.py
├── CA80.BIN
├── C800.BIN
├── C930.BIN
├── requirements-web.txt
└── static/
    └── index.html
```

The `static/` subdirectory is required and must contain `index.html`.

---

## Keyboard Mapping

The CA-80 keyboard is a 4-column × 6-row matrix with 24 keys total. The full layout, matching the physical CA-80 faceplate (verified against documentation R23):

```
┌──────┬──────┬──────┬──────┬──────┬──────┐
│  F1  │  C   │  D   │  E   │  F   │  M   │
├──────┼──────┼──────┼──────┼──────┼──────┤
│  F2  │  8   │  9   │  A   │  B   │  G   │
├──────┼──────┼──────┼──────┼──────┼──────┤
│  F3  │  4   │  5   │  6   │  7   │  .   │
├──────┼──────┼──────┼──────┼──────┼──────┤
│  F4  │  0   │  1   │  2   │  3   │  =   │
└──────┴──────┴──────┴──────┴──────┴──────┘
```

### Key codes (R23 table)

| Key | Table Code | Real Code |
|-----|------------|-----------|
| 0-9 | 0x00-0x09  | various   |
| A-F | 0x0A-0x0F  | various   |
| G   | 0x10       | 0x7E      |
| `.` (SPAC) | 0x11 | 0xBE     |
| `=` (CR)   | 0x12 | 0xFE     |
| M   | 0x13       | 0x3E      |
| F1  | 0x17       | 0x37      |
| F2  | 0x16       | 0x77      |
| F3  | 0x15       | 0xB7      |
| F4  | 0x14       | 0xF7      |

Note: F1-F4 codes are in **reverse order** (F1=0x17, F4=0x14) due to the physical column wiring.

### PC keyboard → CA-80 mappings

| PC Key                | CA-80 Key  |
|-----------------------|------------|
| `0`-`9`               | `0`-`9`    |
| `a`-`f` or `A`-`F`    | `A`-`F`    |
| `g` or `G`            | `G`        |
| `m` or `M`            | `M`        |
| `.` (period)          | `.` (SPAC) |
| `=` or `Enter`        | `=` (CR)   |
| Space                 | `.` (SPAC, alternative) |
| `F1` `F2` `F3` `F4`   | `F1`-`F4`  |
| `q`                   | Quit (terminal version only) |

In the **web version**, both physical keyboard and clicking on-screen keys work simultaneously. Pressing F1-F4 in your browser may trigger browser shortcuts on some platforms — click the on-screen buttons instead, or check your browser's shortcut settings.

---

## Monitor Commands

Once the emulator boots and shows the `CA80` prompt on the display, you can issue monitor commands by pressing single keys:

| Command | Description                                         |
|---------|-----------------------------------------------------|
| `0`     | Clock display                                       |
| `1`     | Set time                                            |
| `2`     | Set date                                            |
| `3`     | Sound test                                          |
| `4`     | Tape input (cassette)                               |
| `5`     | Tape output (cassette)                              |
| `6`     | Compare memory blocks                               |
| `7`     | Move/fill memory                                    |
| `8`     | User jump (`JP 0x0800`) — see C800 section below    |
| `9`     | Hex calculator                                      |
| `A`     | Sum and difference (hex)                            |
| `B`     | Block memory operations                             |
| `C`     | Memory dump (continuous)                            |
| `D`     | View/edit memory                                    |
| `E`     | Fill memory with constant                           |
| `F`     | View/edit registers                                 |
| `G`     | Go (jump to user program)                           |

### Common workflows

**Edit memory and run a program:**

```
D C 0 0 0 =        ← Open memory editor at 0xC000
[2 hex digits]     ← Write a byte (auto-saves after 2 digits)
.                  ← Move to next address
... (repeat) ...
=                  ← Exit edit mode
G C 0 0 0 =        ← Jump to and run program at 0xC000
M                  ← Press M to interrupt and return to monitor
```

**Enter the C800 sub-monitor (games and tools):**

```
*80                ← Triggers WEJUZ which checks signature 0x55 at 0x4001
                     and jumps to 0x4020 (C800 entry point)
```

**Enter the C930 sub-monitor (cassette tools):**

```
*89                ← Triggers WEJU11 which checks signature 0xAA at 0x8001
                     and jumps to 0x8002 (C930 entry point)
```

**Direct jump to ROM:**

```
G 4 0 2 0 =        ← Jump directly to C800 entry (no signature check)
G 8 0 0 2 =        ← Jump directly to C930 entry
```

**The "M" key** always returns to the monitor from any user program (handled via NMI in the monitor's interrupt routine).

---

## Sound

The CA-80 has a simple but effective sound system: writing **any value** to I/O port `0xEC` triggers a **74123 monostable multivibrator**, which generates a single positive pulse on the speaker. The system monitor uses this in its NMI handler (called every 2 ms = 500 Hz).

When a key is pressed, the monitor loads the `SYG` (signal counter) variable at address `0xFFE9` with a value, and decrements it on each NMI cycle while issuing `OUT (0xEC), A`. This produces a 500 Hz square-wave-like tone for the duration of the count.

The emulator faithfully reproduces this:

1. **Port writes to 0xEC** are detected in `ca80_ports.py`
2. **Each pulse** is queued with a sub-millisecond timestamp (derived from Z80 T-states)
3. **PortAudio callback** renders 0.7 ms positive pulses at the queued positions
4. **DC blocker** removes the offset (since all pulses are positive) for clean audio

User programs can produce **any frequency** by writing to port `0xEC` at custom intervals — for example, games in C800 can produce melodies and effects beyond 500 Hz.

### Audio parameters (in `ca80_sound.py`)

| Constant         | Value     | Notes                                          |
|------------------|-----------|------------------------------------------------|
| `SAMPLE_RATE`    | 48000 Hz  | Standard audio rate                            |
| `BLOCK_SIZE`     | 256       | ~5.3 ms latency                                |
| `AMPLITUDE`      | 0.20      | Conservative level                             |
| `PULSE_WIDTH_S`  | 0.0007 s  | 74123 R·C value, ~35% duty at 500 Hz           |

---

## Memory Map

```
0x0000 ─┬─────────────────────────────┐
        │                             │
        │  U9 — System Monitor        │
        │  (CA80.BIN, 8 KB mirrored   │
        │   to 16 KB)                 │
        │                             │
0x4000 ─┼─────────────────────────────┤
        │                             │
        │  U10 — C800 Package         │
        │  (C800.BIN, 2 KB mirrored   │
        │   to 16 KB; entry at 0x4020)│
        │                             │
0x8000 ─┼─────────────────────────────┤
        │                             │
        │  U11 — C930 Package         │
        │  (C930.BIN, 16 KB;          │
        │   entry at 0x8002)          │
        │                             │
0xC000 ─┼─────────────────────────────┤
        │                             │
        │  U12 — User RAM             │
        │  (16 KB, no mirroring)      │
        │                             │
0xFF8D ─┤  ─── System RAM area ────   │
        │  Stack, NMI vectors,        │
        │  display buffer (BWYS),     │
        │  RTC variables, SYG, LCI    │
0xFFFF ─┴─────────────────────────────┘
```

### System RAM area (0xFF8D-0xFFFF, 115 bytes used by monitor)

| Range          | Purpose                                          |
|----------------|--------------------------------------------------|
| 0xFFE8         | LCI — auxiliary timer (40 ms unit)               |
| 0xFFE9         | SYG — sound signal counter (2 ms unit)           |
| 0xFFEA-0xFFF3  | TIME — real-time clock (BCD: ms, s, min, h, ...) |
| 0xFFF7-0xFFFE  | BWYS — 8-byte display buffer                     |
|                | (FFFE = leftmost digit, FFF7 = rightmost)        |
| 0xFF8D-0xFFFF  | Stack (grows downward from 0xFFFF)               |

User programs typically have **0xC000 - 0xFF7F (~16 KB)** of free RAM for code and data.

---

## Architecture Overview

```
┌───────────────────────────────────────────────────────────────┐
│  ca80.py / ca80_web.py    — entry point, UI, main loop        │
└──────────────────┬────────────────────────────────────────────┘
                   │
                   ├── Z80_core.py        — Z80 CPU emulation
                   │
                   ├── ca80_memory.py     — 64 KB memory + ROM loading
                   │                        + ROM write protection
                   │                        + Memory class + module API
                   │                          (peekb/pokeb/peekw/pokew)
                   │
                   ├── ca80_ports.py      — I/O port routing:
                   │                        - 0xF0-0xF3: 8255 PPI (display + keyboard)
                   │                        - 0xEC: sound trigger
                   │                        - 0xF8-0xFB: Z80 CTC (debugger only)
                   │                        Includes 4×6 keyboard matrix
                   │
                   └── ca80_sound.py      — Audio synthesis:
                                            - Pulse queue (74123 model)
                                            - Sub-millisecond positioning
                                            - PortAudio callback in audio thread
                                            - DC blocker (1-pole HPF)
```

The emulator runs the Z80 at **4 MHz** with **NMI every 2 ms** (8000 T-states), matching the original hardware's heartbeat oscillator frequency. The monitor's NMI handler handles display multiplexing, keyboard scanning, real-time clock, and sound generation in software.

For the web version, `ca80_web.py` adds:
- **Background thread** for the Z80 emulation loop
- **aiohttp server** with WebSocket endpoint at `/ws`
- **60 Hz broadcast** of the display buffer to all connected clients
- **Keyboard event reception** with thread-safe `pressed_keys` set

Audio runs in a dedicated PortAudio thread regardless of UI variant.

---

## Troubleshooting

### "FileNotFoundError: CA80.BIN" / "C800.BIN" / "C930.BIN"

The emulator expects these three ROM files in the current working directory. Either copy them there, or specify their paths via `--monitor`, `--c800`, `--c930`.

### Web version: "static/index.html does not exist"

The web emulator requires a `static/` subdirectory next to `ca80_web.py`, containing `index.html`. Make sure your directory structure looks like:

```
ca80_python_emulator/
├── ca80_web.py
└── static/
    └── index.html
```

### No sound on macOS / Linux

Check that `sounddevice` is installed and that PortAudio finds an output device:

```bash
python -c "import sounddevice; print(sounddevice.query_devices())"
```

If audio still doesn't work, run with `--no-audio` to confirm the rest of the emulator works, then troubleshoot the audio system separately.

### Keyboard F1-F4 keys don't work in browser

Some browsers reserve F-keys for browser shortcuts (e.g., F1 = Help). On those, click the on-screen F1-F4 buttons instead. Alternatively, check your browser's shortcut settings to free up F1-F4.

### "Err CA80" appears when I press F1-F4 at the main prompt

This is **correct behavior**, not a bug. F1-F4 have key codes 0x14-0x17, which are above the monitor's command range (LCT = 0x11 = 17 commands). They are intended for use by user programs running under the monitor (e.g., C800 games, custom RAM programs), not as monitor commands. Read more in the [Keyboard Mapping](#keyboard-mapping) section.

### Web version: connection drops repeatedly

The browser tries to reconnect every 1 second. Check the server console for errors. If the server keeps crashing, run with `--no-audio` to isolate audio-related issues.

### Terminal version: display looks scrambled

The terminal UI uses ANSI escape codes via `blessed`. Make sure your terminal supports them and is at least 80 columns wide. Try resizing the terminal or running in a different terminal emulator.

### Performance: emulator runs slowly

Python isn't the fastest language for cycle-accurate emulation. On modern hardware (2018+) it should run at full 4 MHz speed, but on older or low-power devices (Raspberry Pi 3, etc.), you may see slower emulation. Try running with `--no-audio` to reduce overhead.

---

## Acknowledgments

- **Original CA-80 hardware and firmware**: developed in Poland in the 1980s. The emulator is based on the **MIK290** revision of the mainboard, with the **MIK11** monitor ROM.
- **Documentation**: MIK04, MIK05, MIK06, MIK08, MIK09, MIK11 — original Polish-language hardware manuals containing schematics (R23, R24, R8, R6) and firmware listings used to verify the emulation.
- **Z80 core**: based on an external Z80 CPU emulation module (`Z80_core.py`).
- **Tools**: NumPy for audio buffer math, sounddevice/PortAudio for audio output, aiohttp for the web server, React for the front-panel UI.

---

## License

This emulator code is provided as-is for educational and historical preservation purposes. The included emulation logic is original work; Original CA-80 ROM files (`CA80.BIN`, `C800.BIN`, `C930.BIN`) are included based on permission from the author.
