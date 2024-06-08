# CA80 Microcomputer and Clones

Welcome to the CA80 Microcomputer repository! This repository is dedicated to preserving and sharing information, resources, and projects related to the CA80 microcomputer and its various clones.

## Overview

The CA80 is an 8-bit microcomputer developed in the late 1970s and early 1980s. It was widely used in educational and hobbyist circles due to its simplicity and ease of use. The CA80 features a Z80 CPU, a 7-segment display, and a range of I/O options, including tape recorder interfacing.

## Features

- **CPU**: Z80 microprocessor
- **Display**: 6-digit 7-segment display
- **Memory**: Typically 2KB RAM, expandable
- **Storage**: Interface for cassette tape storage
- **I/O**: Multiple ports for expansion and peripheral connections
- **Programming**: Machine code and assembly language

## Key Components

### CPU

The CA80 is powered by the Z80 CPU, a popular 8-bit microprocessor known for its rich instruction set and efficient performance.

### Memory

The standard configuration includes 2KB of RAM, which can be expanded using additional memory modules.

### Display

The primary output device is a 6-digit 7-segment display, used for displaying hexadecimal values and simple messages.

### Storage

Programs and data can be stored and retrieved using a cassette tape recorder interface. This involves connecting a tape recorder to the CA80 via a DIN connector.

### I/O Ports

The CA80 includes various I/O ports that allow for the connection of peripherals and expansion modules, making it a versatile platform for experimentation and development.

## Getting Started

### Assembly Language Programming

To write programs for the CA80, you will need to use Z80 assembly language. Here is a simple "Hello World" example that lights up specific segments on the display:

```assembly
; Simple program to display "HELLO" on 7-segment display
org 0000h

start:
    ld a, 0x76 ; H
    out (0), a
    ld a, 0x79 ; E
    out (1), a
    ld a, 0x38 ; L
    out (2), a
    ld a, 0x38 ; L
    out (3), a
    ld a, 0x3F ; O
    out (4), a

    jp start   ; Loop indefinitely

end:
```
### Contributing

We welcome contributions from the community. If you have projects, modifications, or documentation related to the CA80 or its clones, please feel free to submit a pull request or open an issue.

### License

This repository is licensed under the MIT License. See the LICENSE file for more information.

### Contact

For questions, suggestions, or discussions, please open an issue or contact me.
