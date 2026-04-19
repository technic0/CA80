; ========================================================
; CA80 Chess Program (Szachy) - Program #9
; Disassembly of C930.BIN EPROM chess code
; 
; Source: EPROM 0x9F9B-0xBEBB (file offset 0x1F9B-0x3EBB)
; Loaded to RAM: 0xC000-0xDF20
; Entry point: 0xC000
; Size: 0x1F21 (7969 bytes)
; 
; CA80 System:
;   RAM: 0xC000-0xFFFF
;   ROM: 0x0000-0x1FFF (CA80 monitor, RST vectors)
;   EPROM: 0x8000-0xBFFF (C930 monitor)
;   8255 PPI: ports 0xF0-0xF3 (keyboard/display)
;   CTC: ports 0xF8-0xFB
;   RST 10H (0xD7) + inline byte = CA80 API call
; ========================================================
;
; ADDR  BYTES           INSTRUCTION
; ----  --------------  -----------
C000  31 66 FF        LD SP,0xFF66
C003  CD F0 DC        CALL 0xDCF0
C006  21 60 D0        LD HL,0xD060
C009  01 4E 00        LD BC,0x004E
C00C  11 B0 D0        LD DE,0xD0B0
C00F  C5              PUSH BC
C010  E5              PUSH HL
C011  ED B0           LDIR
C013  E1              POP HL
C014  C1              POP BC
C015  11 00 D1        LD DE,0xD100
C018  C5              PUSH BC
C019  E5              PUSH HL
C01A  ED B0           LDIR
C01C  E1              POP HL
C01D  C1              POP BC
C01E  11 50 D1        LD DE,0xD150
C021  ED B0           LDIR
C023  CD D6 C1        CALL 0xC1D6
C026  3E 48           LD A,0x48
C028  32 FA FF        LD (0xFFFA),A
C02B  32 FB FF        LD (0xFFFB),A
C02E  3E 80           LD A,0x80
C030  32 FD FF        LD (0xFFFD),A
C033  32 FC FF        LD (0xFFFC),A
C036  32 F9 FF        LD (0xFFF9),A
C039  32 F8 FF        LD (0xFFF8),A
C03C  3E 63           LD A,0x63
C03E  32 FE FF        LD (0xFFFE),A
C041  32 F7 FF        LD (0xFFF7),A
C044  CD 50 CC        CALL 0xCC50
C047  00              NOP
C048  00              NOP
C049  00              NOP
C04A  00              NOP
C04B  3A 5E D0        LD A,(0xD05E)
C04E  FE 0C           CP 0x0C
C050  CA 73 C0        JP Z,0xC073
C053  00              NOP
C054  00              NOP
C055  00              NOP
C056  00              NOP
C057  00              NOP
C058  00              NOP
C059  00              NOP
C05A  00              NOP
C05B  00              NOP
C05C  00              NOP
C05D  00              NOP
C05E  00              NOP
C05F  3E 80           LD A,0x80
C061  32 FD FF        LD (0xFFFD),A
C064  32 FC FF        LD (0xFFFC),A
C067  32 F9 FF        LD (0xFFF9),A
C06A  32 F8 FF        LD (0xFFF8),A
C06D  CD D0 C0        CALL 0xC0D0
C070  C2 5F C0        JP NZ,0xC05F
C073  CD F0 DA        CALL 0xDAF0
C076  00              NOP
C077  00              NOP
C078  21 00 00        LD HL,0x0000
C07B  22 01 D0        LD (0xD001),HL
C07E  21 00 80        LD HL,0x8000
C081  22 03 D0        LD (0xD003),HL
C084  21 F0 7F        LD HL,0x7FF0
C087  22 0A D0        LD (0xD00A),HL
C08A  00              NOP
C08B  00              NOP
C08C  00              NOP
C08D  00              NOP
C08E  2A 15 D0        LD HL,(0xD015)
C091  11 B0 D0        LD DE,0xD0B0
C094  19              ADD HL,DE
C095  7E              LD A,(HL)
C096  FE 02           CP 0x02
C098  CC 56 C8        CALL Z,0xC856
C09B  FE 7F           CP 0x7F
C09D  CC 36 C4        CALL Z,0xC436
C0A0  FE 14           CP 0x14
C0A2  CC 50 C5        CALL Z,0xC550
C0A5  FE 07           CP 0x07
C0A7  CC 80 C7        CALL Z,0xC780
C0AA  FE 0A           CP 0x0A
C0AC  CC C0 C6        CALL Z,0xC6C0
C0AF  FE 06           CP 0x06
C0B1  CC F0 C3        CALL Z,0xC3F0
C0B4  3A 15 D0        LD A,(0xD015)
C0B7  3C              INC A
C0B8  32 15 D0        LD (0xD015),A
C0BB  FE 4E           CP 0x4E
C0BD  C2 84 C0        JP NZ,0xC084
C0C0  CD 00 C3        CALL 0xC300
C0C3  CD 1D CF        CALL 0xCF1D
C0C6  FE 00           CP 0x00
C0C8  CA 00 C0        JP Z,0xC000
C0CB  C3 5F C0        JP 0xC05F
C0CE  00              NOP
C0CF  00              NOP
C0D0  CD C6 FF        CALL 0xFFC6
C0D3  00              NOP
C0D4  00              NOP
C0D5  FE 08           CP 0x08
C0D7  20 0C           JR NZ,0xC0E5
C0D9  3E 80           LD A,0x80
C0DB  32 2C D0        LD (0xD02C),A
C0DE  3E 76           LD A,0x76
C0E0  32 FD FF        LD (0xFFFD),A
C0E3  18 20           JR,0xC105
C0E5  FE 09           CP 0x09
C0E7  20 0A           JR NZ,0xC0F3
C0E9  32 2C D0        LD (0xD02C),A
C0EC  3E 3D           LD A,0x3D
C0EE  32 FD FF        LD (0xFFFD),A
C0F1  18 12           JR,0xC105
C0F3  4F              LD C,A
C0F4  F5              PUSH AF
C0F5  CD E0 01        CALL 0x01E0
C0F8  16 F1           LD D,0xF1
C0FA  CB 27           SLA A
C0FC  CB 27           SLA A
C0FE  CB 27           SLA A
C100  CB 27           SLA A
C102  32 2C D0        LD (0xD02C),A
C105  CD C6 FF        CALL 0xFFC6
C108  00              NOP
C109  00              NOP
C10A  4F              LD C,A
C10B  F5              PUSH AF
C10C  CD E0 01        CALL 0x01E0
C10F  15              DEC D
C110  F1              POP AF
C111  21 2C D0        LD HL,0xD02C
C114  86              ADD A,(HL)
C115  32 2C D0        LD (0xD02C),A
C118  CD C6 FF        CALL 0xFFC6
C11B  00              NOP
C11C  00              NOP
C11D  FE 08           CP 0x08
C11F  20 0C           JR NZ,0xC12D
C121  3E 80           LD A,0x80
C123  32 2E D0        LD (0xD02E),A
C126  3E 76           LD A,0x76
C128  32 F9 FF        LD (0xFFF9),A
C12B  18 20           JR,0xC14D
C12D  FE 09           CP 0x09
C12F  20 0A           JR NZ,0xC13B
C131  32 2E D0        LD (0xD02E),A
C134  3E 3D           LD A,0x3D
C136  32 F9 FF        LD (0xFFF9),A
C139  18 12           JR,0xC14D
C13B  4F              LD C,A
C13C  F5              PUSH AF
C13D  CD E0 01        CALL 0x01E0
C140  12              LD (DE),A
C141  F1              POP AF
C142  CB 27           SLA A
C144  CB 27           SLA A
C146  CB 27           SLA A
C148  CB 27           SLA A
C14A  32 2E D0        LD (0xD02E),A
C14D  CD C6 FF        CALL 0xFFC6
C150  00              NOP
C151  00              NOP
C152  4F              LD C,A
C153  F5              PUSH AF
C154  CD E0 01        CALL 0x01E0
C157  11 F1 21        LD DE,0x21F1
C15A  2E D0           LD L,0xD0
C15C  86              ADD A,(HL)
C15D  32 2E D0        LD (0xD02E),A
C160  21 00 D3        LD HL,0xD300
C163  01 4F 00        LD BC,0x004F
C166  3A 2C D0        LD A,(0xD02C)
C169  ED B1           CPIR
C16B  C0              RET NZ
C16C  2B              DEC HL
C16D  11 00 2D        LD DE,0x2D00
C170  19              ADD HL,DE
C171  22 28 D0        LD (0xD028),HL
C174  21 00 D3        LD HL,0xD300
C177  01 4F 00        LD BC,0x004F
C17A  3A 2E D0        LD A,(0xD02E)
C17D  ED B1           CPIR
C17F  C0              RET NZ
C180  2B              DEC HL
C181  11 00 2D        LD DE,0x2D00
C184  19              ADD HL,DE
C185  22 2A D0        LD (0xD02A),HL
C188  F5              PUSH AF
C189  CD 9D CF        CALL 0xCF9D
C18C  F1              POP AF
C18D  00              NOP
C18E  00              NOP
C18F  00              NOP
C190  00              NOP
C191  00              NOP
C192  00              NOP
C193  00              NOP
C194  00              NOP
C195  00              NOP
C196  00              NOP
C197  21 B0 D0        LD HL,0xD0B0
C19A  01 4E 00        LD BC,0x004E
C19D  11 00 D1        LD DE,0xD100
C1A0  C5              PUSH BC
C1A1  E5              PUSH HL
C1A2  ED B0           LDIR
C1A4  E1              POP HL
C1A5  C1              POP BC
C1A6  11 50 D1        LD DE,0xD150
C1A9  ED B0           LDIR
C1AB  C9              RET
C1AC  00              NOP
C1AD  00              NOP
C1AE  00              NOP
C1AF  00              NOP
C1B0  00              NOP
C1B1  00              NOP
C1B2  00              NOP
C1B3  00              NOP
C1B4  00              NOP
C1B5  00              NOP
C1B6  00              NOP
C1B7  D3 EC           OUT (0xEC),A
C1B9  00              NOP
C1BA  21 00 F0        LD HL,0xF000
C1BD  11 20 00        LD DE,0x0020
C1C0  19              ADD HL,DE
C1C1  D4 CC C1        CALL NC,0xC1CC
C1C4  30 FA           JR NC,0xC1C0
C1C6  00              NOP
C1C7  D3 EC           OUT (0xEC),A
C1C9  C9              RET
C1CA  00              NOP
C1CB  00              NOP
C1CC  06 01           LD B,0x01
C1CE  3E 00           LD A,0x00
C1D0  80              ADD A,B
C1D1  30 FD           JR NC,0xC1D0
C1D3  37              SCF
C1D4  3F              CCF
C1D5  C9              RET
C1D6  0E 00           LD C,0x00
C1D8  21 00 D0        LD HL,0xD000
C1DB  11 50 D0        LD DE,0xD050
C1DE  71              LD (HL),C
C1DF  CD 3B 02        CALL 0x023B
C1E2  30 FA           JR NC,0xC1DE
C1E4  21 04 D0        LD HL,0xD004
C1E7  36 80           LD (HL),0x80
C1E9  C9              RET
C1EA  00              NOP
C1EB  00              NOP
C1EC  00              NOP
C1ED  00              NOP
C1EE  00              NOP
C1EF  00              NOP
C1F0  21 B0 D0        LD HL,0xD0B0
C1F3  11 00 D1        LD DE,0xD100
C1F6  01 4E 00        LD BC,0x004E
C1F9  C5              PUSH BC
C1FA  E5              PUSH HL
C1FB  ED B0           LDIR
C1FD  E1              POP HL
C1FE  C1              POP BC
C1FF  11 50 D1        LD DE,0xD150
C202  ED B0           LDIR
C204  C9              RET
C205  00              NOP
C206  00              NOP
C207  00              NOP
C208  00              NOP
C209  00              NOP
C20A  00              NOP
C20B  00              NOP
C20C  00              NOP
C20D  00              NOP
C20E  21 35 D0        LD HL,0xD035
C211  36 00           LD (HL),0x00
C213  23              INC HL
C214  36 00           LD (HL),0x00
C216  21 23 D0        LD HL,0xD023
C219  36 00           LD (HL),0x00
C21B  CD B0 C2        CALL 0xC2B0
C21E  21 23 D0        LD HL,0xD023
C221  36 00           LD (HL),0x00
C223  2A 35 D0        LD HL,(0xD035)
C226  ED 5B 35 D0     LD DE,(0xD035)
C22A  19              ADD HL,DE
C22B  19              ADD HL,DE
C22C  19              ADD HL,DE
C22D  19              ADD HL,DE
C22E  19              ADD HL,DE
C22F  22 35 D0        LD (0xD035),HL
C232  3A 23 D0        LD A,(0xD023)
C235  FE 4E           CP 0x4E
C237  20 01           JR NZ,0xC23A
C239  C9              RET
C23A  2A 23 D0        LD HL,(0xD023)
C23D  11 A0 D1        LD DE,0xD1A0
C240  19              ADD HL,DE
C241  7E              LD A,(HL)
C242  FE 01           CP 0x01
C244  DA 95 C2        JP C,0xC295
C247  FE 02           CP 0x02
C249  20 0E           JR NZ,0xC259
C24B  2A 23 D0        LD HL,(0xD023)
C24E  11 A0 D2        LD DE,0xD2A0
C251  19              ADD HL,DE
C252  7E              LD A,(HL)
C253  32 26 D0        LD (0xD026),A
C256  C3 95 C2        JP 0xC295
C259  FE FE           CP 0xFE
C25B  20 13           JR NZ,0xC270
C25D  2A 23 D0        LD HL,(0xD023)
C260  11 A0 D3        LD DE,0xD3A0
C263  19              ADD HL,DE
C264  7E              LD A,(HL)
C265  32 26 D0        LD (0xD026),A
C268  3E FF           LD A,0xFF
C26A  32 27 D0        LD (0xD027),A
C26D  C3 95 C2        JP 0xC295
C270  FE 80           CP 0x80
C272  CA 95 C2        JP Z,0xC295
C275  30 0E           JR NC,0xC285
C277  2A 23 D0        LD HL,(0xD023)
C27A  11 50 D2        LD DE,0xD250
C27D  19              ADD HL,DE
C27E  7E              LD A,(HL)
C27F  32 26 D0        LD (0xD026),A
C282  C3 95 C2        JP 0xC295
C285  2A 23 D0        LD HL,(0xD023)
C288  11 50 D3        LD DE,0xD350
C28B  19              ADD HL,DE
C28C  7E              LD A,(HL)
C28D  32 26 D0        LD (0xD026),A
C290  3E FF           LD A,0xFF
C292  32 27 D0        LD (0xD027),A
C295  2A 35 D0        LD HL,(0xD035)
C298  ED 5B 26 D0     LD DE,(0xD026)
C29C  19              ADD HL,DE
C29D  22 35 D0        LD (0xD035),HL
C2A0  21 00 00        LD HL,0x0000
C2A3  22 26 D0        LD (0xD026),HL
C2A6  3A 23 D0        LD A,(0xD023)
C2A9  3C              INC A
C2AA  32 23 D0        LD (0xD023),A
C2AD  C3 32 C2        JP 0xC232
C2B0  01 00 00        LD BC,0x0000
C2B3  2A 23 D0        LD HL,(0xD023)
C2B6  11 A0 D1        LD DE,0xD1A0
C2B9  19              ADD HL,DE
C2BA  7E              LD A,(HL)
C2BB  FE 80           CP 0x80
C2BD  28 0C           JR Z,0xC2CB
C2BF  38 02           JR C,0xC2C3
C2C1  06 FF           LD B,0xFF
C2C3  4F              LD C,A
C2C4  2A 35 D0        LD HL,(0xD035)
C2C7  09              ADD HL,BC
C2C8  22 35 D0        LD (0xD035),HL
C2CB  3A 23 D0        LD A,(0xD023)
C2CE  FE 4D           CP 0x4D
C2D0  28 06           JR Z,0xC2D8
C2D2  3C              INC A
C2D3  32 23 D0        LD (0xD023),A
C2D6  18 D8           JR,0xC2B0
C2D8  C9              RET
C2D9  00              NOP
C2DA  00              NOP
C2DB  00              NOP
C2DC  00              NOP
C2DD  00              NOP
C2DE  00              NOP
C2DF  21 21 5C        LD HL,0x5C21
C2E2  D0              RET NC
C2E3  7E              LD A,(HL)
C2E4  FE 01           CP 0x01
C2E6  28 04           JR Z,0xC2EC
C2E8  CD 20 CE        CALL 0xCE20
C2EB  C9              RET
C2EC  CD 00 CE        CALL 0xCE00
C2EF  C9              RET
C2F0  00              NOP
C2F1  00              NOP
C2F2  00              NOP
C2F3  00              NOP
C2F4  00              NOP
C2F5  00              NOP
C2F6  00              NOP
C2F7  00              NOP
C2F8  00              NOP
C2F9  00              NOP
C2FA  00              NOP
C2FB  00              NOP
C2FC  00              NOP
C2FD  00              NOP
C2FE  00              NOP
C2FF  00              NOP
C300  CD 56 CF        CALL 0xCF56
C303  00              NOP
C304  00              NOP
C305  00              NOP
C306  00              NOP
C307  00              NOP
C308  00              NOP
C309  00              NOP
C30A  00              NOP
C30B  00              NOP
C30C  00              NOP
C30D  00              NOP
C30E  00              NOP
C30F  00              NOP
C310  00              NOP
C311  00              NOP
C312  00              NOP
C313  3A 01 D0        LD A,(0xD001)
C316  06 00           LD B,0x00
C318  4F              LD C,A
C319  21 00 D3        LD HL,0xD300
C31C  09              ADD HL,BC
C31D  7E              LD A,(HL)
C31E  4F              LD C,A
C31F  CB 7F           BIT 7,A
C321  20 0D           JR NZ,0xC330
C323  3E 3D           LD A,0x3D
C325  32 FD FF        LD (0xFFFD),A
C328  CB A1           RES 4,C
C32A  CD E0 01        CALL 0x01E0
C32D  15              DEC D
C32E  18 19           JR,0xC349
C330  CB 77           BIT 6,A
C332  20 11           JR NZ,0xC345
C334  CB 6F           BIT 5,A
C336  20 0D           JR NZ,0xC345
C338  3E 76           LD A,0x76
C33A  32 FD FF        LD (0xFFFD),A
C33D  CB B9           RES 7,C
C33F  CD E0 01        CALL 0x01E0
C342  15              DEC D
C343  18 04           JR,0xC349
C345  CD 18 00        CALL 0x0018
C348  05              DEC B
C349  3A 02 D0        LD A,(0xD002)
C34C  06 00           LD B,0x00
C34E  4F              LD C,A
C34F  21 00 D3        LD HL,0xD300
C352  09              ADD HL,BC
C353  7E              LD A,(HL)
C354  4F              LD C,A
C355  CB 7F           BIT 7,A
C357  20 0D           JR NZ,0xC366
C359  3E 3D           LD A,0x3D
C35B  32 F9 FF        LD (0xFFF9),A
C35E  CB A1           RES 4,C
C360  CD E0 01        CALL 0x01E0
C363  11 18 19        LD DE,0x1918
C366  CB 77           BIT 6,A
C368  20 11           JR NZ,0xC37B
C36A  CB 6F           BIT 5,A
C36C  20 0D           JR NZ,0xC37B
C36E  3E 76           LD A,0x76
C370  32 F9 FF        LD (0xFFF9),A
C373  CB B9           RES 7,C
C375  CD E0 01        CALL 0x01E0
C378  11 18 04        LD DE,0x0418
C37B  CD 18 00        CALL 0x0018
C37E  01 21 F8        LD BC,0xF821
C381  DB 22           IN A,(0x22)
C383  B1              OR,C
C384  DB 21           IN A,(0x21)
C386  0E DC           LD C,0xDC
C388  22 B4 DB        LD (0xDBB4),HL
C38B  CD B0 DB        CALL 0xDBB0
C38E  C9              RET
C38F  00              NOP
C390  CD FA D9        CALL 0xD9FA
C393  00              NOP
C394  00              NOP
C395  00              NOP
C396  00              NOP
C397  00              NOP
C398  26 00           LD H,0x00
C39A  3E B2           LD A,0xB2
C39C  85              ADD A,L
C39D  D8              RET C
C39E  11 B0 D0        LD DE,0xD0B0
C3A1  19              ADD HL,DE
C3A2  7E              LD A,(HL)
C3A3  C9              RET
C3A4  00              NOP
C3A5  00              NOP
C3A6  00              NOP
C3A7  3A 15 D0        LD A,(0xD015)
C3AA  32 08 D0        LD (0xD008),A
C3AD  21 18 D0        LD HL,0xD018
C3B0  46              LD B,(HL)
C3B1  80              ADD A,B
C3B2  32 09 D0        LD (0xD009),A
C3B5  21 F0 7F        LD HL,0x7FF0
C3B8  22 0A D0        LD (0xD00A),HL
C3BB  C9              RET
C3BC  00              NOP
C3BD  00              NOP
C3BE  00              NOP
C3BF  00              NOP
C3C0  CD FA D9        CALL 0xD9FA
C3C3  00              NOP
C3C4  00              NOP
C3C5  00              NOP
C3C6  00              NOP
C3C7  00              NOP
C3C8  26 00           LD H,0x00
C3CA  3E B2           LD A,0xB2
C3CC  85              ADD A,L
C3CD  D8              RET C
C3CE  11 B0 D0        LD DE,0xD0B0
C3D1  19              ADD HL,DE
C3D2  7E              LD A,(HL)
C3D3  FE 01           CP 0x01
C3D5  38 04           JR C,0xC3DB
C3D7  FE 80           CP 0x80
C3D9  C8              RET Z
C3DA  D8              RET C
C3DB  CD 80 CC        CALL 0xCC80
C3DE  CD 80 C4        CALL 0xC480
C3E1  C9              RET
C3E2  00              NOP
C3E3  00              NOP
C3E4  00              NOP
C3E5  00              NOP
C3E6  00              NOP
C3E7  00              NOP
C3E8  00              NOP
C3E9  00              NOP
C3EA  00              NOP
C3EB  00              NOP
C3EC  00              NOP
C3ED  00              NOP
C3EE  00              NOP
C3EF  00              NOP
C3F0  F5              PUSH AF
C3F1  3E 0C           LD A,0x0C
C3F3  32 18 D0        LD (0xD018),A
C3F6  CD C0 C3        CALL 0xC3C0
C3F9  3E F4           LD A,0xF4
C3FB  32 18 D0        LD (0xD018),A
C3FE  CD C0 C3        CALL 0xC3C0
C401  3E 08           LD A,0x08
C403  32 18 D0        LD (0xD018),A
C406  CD C0 C3        CALL 0xC3C0
C409  3E F8           LD A,0xF8
C40B  32 18 D0        LD (0xD018),A
C40E  CD C0 C3        CALL 0xC3C0
C411  3E 15           LD A,0x15
C413  32 18 D0        LD (0xD018),A
C416  CD C0 C3        CALL 0xC3C0
C419  3E EB           LD A,0xEB
C41B  32 18 D0        LD (0xD018),A
C41E  CD C0 C3        CALL 0xC3C0
C421  3E 13           LD A,0x13
C423  32 18 D0        LD (0xD018),A
C426  CD C0 C3        CALL 0xC3C0
C429  3E ED           LD A,0xED
C42B  32 18 D0        LD (0xD018),A
C42E  CD C0 C3        CALL 0xC3C0
C431  F1              POP AF
C432  C9              RET
C433  00              NOP
C434  00              NOP
C435  00              NOP
C436  F5              PUSH AF
C437  3E 01           LD A,0x01
C439  32 18 D0        LD (0xD018),A
C43C  CD C0 C3        CALL 0xC3C0
C43F  3E 0A           LD A,0x0A
C441  32 18 D0        LD (0xD018),A
C444  CD C0 C3        CALL 0xC3C0
C447  3E FF           LD A,0xFF
C449  32 18 D0        LD (0xD018),A
C44C  CD C0 C3        CALL 0xC3C0
C44F  3E F6           LD A,0xF6
C451  32 18 D0        LD (0xD018),A
C454  CD C0 C3        CALL 0xC3C0
C457  3E 0B           LD A,0x0B
C459  32 18 D0        LD (0xD018),A
C45C  CD C0 C3        CALL 0xC3C0
C45F  3E 09           LD A,0x09
C461  32 18 D0        LD (0xD018),A
C464  CD C0 C3        CALL 0xC3C0
C467  3E F7           LD A,0xF7
C469  32 18 D0        LD (0xD018),A
C46C  CD C0 C3        CALL 0xC3C0
C46F  3E F5           LD A,0xF5
C471  32 18 D0        LD (0xD018),A
C474  CD C0 C3        CALL 0xC3C0
C477  F1              POP AF
C478  C9              RET
C479  00              NOP
C47A  00              NOP
C47B  00              NOP
C47C  00              NOP
C47D  00              NOP
C47E  00              NOP
C47F  00              NOP
C480  2A 08 D0        LD HL,(0xD008)
C483  26 00           LD H,0x00
C485  11 00 D1        LD DE,0xD100
C488  19              ADD HL,DE
C489  7E              LD A,(HL)
C48A  36 00           LD (HL),0x00
C48C  2A 09 D0        LD HL,(0xD009)
C48F  26 00           LD H,0x00
C491  19              ADD HL,DE
C492  77              LD (HL),A
C493  21 20 D0        LD HL,0xD020
C496  36 00           LD (HL),0x00
C498  00              NOP
C499  00              NOP
C49A  21 00 D1        LD HL,0xD100
C49D  01 4E 00        LD BC,0x004E
C4A0  11 50 D1        LD DE,0xD150
C4A3  ED B0           LDIR
C4A5  2A 20 D0        LD HL,(0xD020)
C4A8  11 50 D1        LD DE,0xD150
C4AB  19              ADD HL,DE
C4AC  7E              LD A,(HL)
C4AD  C6 7F           ADD A,0x7F
C4AF  D2 FD C4        JP NC,0xC4FD
C4B2  7E              LD A,(HL)
C4B3  FE FE           CP 0xFE
C4B5  CC E8 CB        CALL Z,0xCBE8
C4B8  FE E2           CP 0xE2
C4BA  CC 90 CB        CALL Z,0xCB90
C4BD  FE EE           CP 0xEE
C4BF  CC A8 C8        CALL Z,0xC8A8
C4C2  FE F9           CP 0xF9
C4C4  CC A0 CA        CALL Z,0xCAA0
C4C7  FE F6           CP 0xF6
C4C9  CC 00 CA        CALL Z,0xCA00
C4CC  FE FA           CP 0xFA
C4CE  CC 40 CB        CALL Z,0xCB40
C4D1  3A 20 D0        LD A,(0xD020)
C4D4  FE 4D           CP 0x4D
C4D6  28 07           JR Z,0xC4DF
C4D8  3C              INC A
C4D9  32 20 D0        LD (0xD020),A
C4DC  C3 9A C4        JP 0xC49A
C4DF  2A 03 D0        LD HL,(0xD003)
C4E2  ED 5B 0A D0     LD DE,(0xD00A)
C4E6  2B              DEC HL
C4E7  CD 30 CC        CALL 0xCC30
C4EA  38 0A           JR C,0xC4F6
C4EC  ED 53 03 D0     LD (0xD003),DE
C4F0  2A 08 D0        LD HL,(0xD008)
C4F3  22 01 D0        LD (0xD001),HL
C4F6  CD F0 C1        CALL 0xC1F0
C4F9  C9              RET
C4FA  00              NOP
C4FB  00              NOP
C4FC  00              NOP
C4FD  3A 20 D0        LD A,(0xD020)
C500  FE 4D           CP 0x4D
C502  20 04           JR NZ,0xC508
C504  C3 D1 C4        JP 0xC4D1
C507  00              NOP
C508  3C              INC A
C509  32 20 D0        LD (0xD020),A
C50C  C3 9A C4        JP 0xC49A
C50F  00              NOP
C510  2A 20 D0        LD HL,(0xD020)
C513  11 50 D1        LD DE,0xD150
C516  19              ADD HL,DE
C517  7E              LD A,(HL)
C518  36 00           LD (HL),0x00
C51A  ED 5B 1A D0     LD DE,(0xD01A)
C51E  4F              LD C,A
C51F  7B              LD A,E
C520  85              ADD A,L
C521  6F              LD L,A
C522  71              LD (HL),C
C523  CD E0 C2        CALL 0xC2E0
C526  C9              RET
C527  00              NOP
C528  2A 20 D0        LD HL,(0xD020)
C52B  ED 5B 1A D0     LD DE,(0xD01A)
C52F  19              ADD HL,DE
C530  26 00           LD H,0x00
C532  3E B2           LD A,0xB2
C534  85              ADD A,L
C535  D8              RET C
C536  11 00 D1        LD DE,0xD100
C539  19              ADD HL,DE
C53A  7E              LD A,(HL)
C53B  FE 01           CP 0x01
C53D  38 04           JR C,0xC543
C53F  FE 80           CP 0x80
C541  C8              RET Z
C542  D0              RET NC
C543  CD 10 C5        CALL 0xC510
C546  C9              RET
C547  00              NOP
C548  00              NOP
C549  00              NOP
C54A  00              NOP
C54B  00              NOP
C54C  00              NOP
C54D  00              NOP
C54E  00              NOP
C54F  00              NOP
C550  F5              PUSH AF
C551  3E 0A           LD A,0x0A
C553  32 18 D0        LD (0xD018),A
C556  CD 90 C3        CALL 0xC390
C559  38 20           JR C,0xC57B
C55B  FE 80           CP 0x80
C55D  28 1C           JR Z,0xC57B
C55F  30 14           JR NC,0xC575
C561  FE 01           CP 0x01
C563  30 16           JR NC,0xC57B
C565  CD A7 C3        CALL 0xC3A7
C568  CD 80 C4        CALL 0xC480
C56B  3A 18 D0        LD A,(0xD018)
C56E  C6 0A           ADD A,0x0A
C570  32 18 D0        LD (0xD018),A
C573  18 E1           JR,0xC556
C575  CD A7 C3        CALL 0xC3A7
C578  CD 80 C4        CALL 0xC480
C57B  3E F6           LD A,0xF6
C57D  32 18 D0        LD (0xD018),A
C580  00              NOP
C581  00              NOP
C582  00              NOP
C583  CD 90 C3        CALL 0xC390
C586  38 20           JR C,0xC5A8
C588  FE 80           CP 0x80
C58A  28 1C           JR Z,0xC5A8
C58C  30 14           JR NC,0xC5A2
C58E  FE 01           CP 0x01
C590  30 16           JR NC,0xC5A8
C592  CD A7 C3        CALL 0xC3A7
C595  CD 80 C4        CALL 0xC480
C598  3A 18 D0        LD A,(0xD018)
C59B  C6 F6           ADD A,0xF6
C59D  32 18 D0        LD (0xD018),A
C5A0  18 E1           JR,0xC583
C5A2  CD A7 C3        CALL 0xC3A7
C5A5  CD 80 C4        CALL 0xC480
C5A8  3E 01           LD A,0x01
C5AA  32 18 D0        LD (0xD018),A
C5AD  00              NOP
C5AE  00              NOP
C5AF  00              NOP
C5B0  CD 90 C3        CALL 0xC390
C5B3  38 20           JR C,0xC5D5
C5B5  FE 80           CP 0x80
C5B7  28 1C           JR Z,0xC5D5
C5B9  30 14           JR NC,0xC5CF
C5BB  FE 01           CP 0x01
C5BD  30 16           JR NC,0xC5D5
C5BF  CD A7 C3        CALL 0xC3A7
C5C2  CD 80 C4        CALL 0xC480
C5C5  3A 18 D0        LD A,(0xD018)
C5C8  C6 01           ADD A,0x01
C5CA  32 18 D0        LD (0xD018),A
C5CD  18 E1           JR,0xC5B0
C5CF  CD A7 C3        CALL 0xC3A7
C5D2  CD 80 C4        CALL 0xC480
C5D5  3E FF           LD A,0xFF
C5D7  32 18 D0        LD (0xD018),A
C5DA  00              NOP
C5DB  00              NOP
C5DC  00              NOP
C5DD  00              NOP
C5DE  00              NOP
C5DF  00              NOP
C5E0  CD 90 C3        CALL 0xC390
C5E3  38 20           JR C,0xC605
C5E5  FE 80           CP 0x80
C5E7  28 1C           JR Z,0xC605
C5E9  30 14           JR NC,0xC5FF
C5EB  FE 01           CP 0x01
C5ED  30 16           JR NC,0xC605
C5EF  CD A7 C3        CALL 0xC3A7
C5F2  CD 80 C4        CALL 0xC480
C5F5  3A 18 D0        LD A,(0xD018)
C5F8  C6 FF           ADD A,0xFF
C5FA  32 18 D0        LD (0xD018),A
C5FD  18 E1           JR,0xC5E0
C5FF  CD A7 C3        CALL 0xC3A7
C602  CD 80 C4        CALL 0xC480
C605  3E 0B           LD A,0x0B
C607  32 18 D0        LD (0xD018),A
C60A  00              NOP
C60B  00              NOP
C60C  00              NOP
C60D  CD 90 C3        CALL 0xC390
C610  38 20           JR C,0xC632
C612  FE 80           CP 0x80
C614  28 1C           JR Z,0xC632
C616  30 14           JR NC,0xC62C
C618  FE 01           CP 0x01
C61A  30 16           JR NC,0xC632
C61C  CD A7 C3        CALL 0xC3A7
C61F  CD 80 C4        CALL 0xC480
C622  3A 18 D0        LD A,(0xD018)
C625  C6 0B           ADD A,0x0B
C627  32 18 D0        LD (0xD018),A
C62A  18 E1           JR,0xC60D
C62C  CD A7 C3        CALL 0xC3A7
C62F  CD 80 C4        CALL 0xC480
C632  3E F5           LD A,0xF5
C634  32 18 D0        LD (0xD018),A
C637  00              NOP
C638  00              NOP
C639  00              NOP
C63A  CD 90 C3        CALL 0xC390
C63D  38 20           JR C,0xC65F
C63F  FE 80           CP 0x80
C641  28 1C           JR Z,0xC65F
C643  30 14           JR NC,0xC659
C645  FE 01           CP 0x01
C647  30 16           JR NC,0xC65F
C649  CD A7 C3        CALL 0xC3A7
C64C  CD 80 C4        CALL 0xC480
C64F  3A 18 D0        LD A,(0xD018)
C652  C6 F5           ADD A,0xF5
C654  32 18 D0        LD (0xD018),A
C657  18 E1           JR,0xC63A
C659  CD A7 C3        CALL 0xC3A7
C65C  CD 80 C4        CALL 0xC480
C65F  3E 09           LD A,0x09
C661  32 18 D0        LD (0xD018),A
C664  00              NOP
C665  00              NOP
C666  00              NOP
C667  CD 90 C3        CALL 0xC390
C66A  38 20           JR C,0xC68C
C66C  FE 80           CP 0x80
C66E  28 1C           JR Z,0xC68C
C670  30 14           JR NC,0xC686
C672  FE 01           CP 0x01
C674  30 16           JR NC,0xC68C
C676  CD A7 C3        CALL 0xC3A7
C679  CD 80 C4        CALL 0xC480
C67C  3A 18 D0        LD A,(0xD018)
C67F  C6 09           ADD A,0x09
C681  32 18 D0        LD (0xD018),A
C684  18 E1           JR,0xC667
C686  CD A7 C3        CALL 0xC3A7
C689  CD 80 C4        CALL 0xC480
C68C  3E F7           LD A,0xF7
C68E  32 18 D0        LD (0xD018),A
C691  00              NOP
C692  00              NOP
C693  00              NOP
C694  CD 90 C3        CALL 0xC390
C697  38 20           JR C,0xC6B9
C699  FE 80           CP 0x80
C69B  28 1C           JR Z,0xC6B9
C69D  30 14           JR NC,0xC6B3
C69F  FE 01           CP 0x01
C6A1  30 16           JR NC,0xC6B9
C6A3  CD A7 C3        CALL 0xC3A7
C6A6  CD 80 C4        CALL 0xC480
C6A9  3A 18 D0        LD A,(0xD018)
C6AC  C6 F7           ADD A,0xF7
C6AE  32 18 D0        LD (0xD018),A
C6B1  18 E1           JR,0xC694
C6B3  CD A7 C3        CALL 0xC3A7
C6B6  CD 80 C4        CALL 0xC480
C6B9  F1              POP AF
C6BA  C9              RET
C6BB  00              NOP
C6BC  00              NOP
C6BD  00              NOP
C6BE  00              NOP
C6BF  00              NOP
C6C0  F5              PUSH AF
C6C1  3E 0A           LD A,0x0A
C6C3  32 18 D0        LD (0xD018),A
C6C6  CD 90 C3        CALL 0xC390
C6C9  38 20           JR C,0xC6EB
C6CB  FE 80           CP 0x80
C6CD  28 1C           JR Z,0xC6EB
C6CF  30 14           JR NC,0xC6E5
C6D1  FE 01           CP 0x01
C6D3  30 16           JR NC,0xC6EB
C6D5  CD A7 C3        CALL 0xC3A7
C6D8  CD 80 C4        CALL 0xC480
C6DB  3A 18 D0        LD A,(0xD018)
C6DE  C6 0A           ADD A,0x0A
C6E0  32 18 D0        LD (0xD018),A
C6E3  18 E1           JR,0xC6C6
C6E5  CD A7 C3        CALL 0xC3A7
C6E8  CD 80 C4        CALL 0xC480
C6EB  3E F6           LD A,0xF6
C6ED  32 18 D0        LD (0xD018),A
C6F0  00              NOP
C6F1  00              NOP
C6F2  00              NOP
C6F3  CD 90 C3        CALL 0xC390
C6F6  38 20           JR C,0xC718
C6F8  FE 80           CP 0x80
C6FA  28 1C           JR Z,0xC718
C6FC  30 14           JR NC,0xC712
C6FE  FE 01           CP 0x01
C700  30 16           JR NC,0xC718
C702  CD A7 C3        CALL 0xC3A7
C705  CD 80 C4        CALL 0xC480
C708  3A 18 D0        LD A,(0xD018)
C70B  C6 F6           ADD A,0xF6
C70D  32 18 D0        LD (0xD018),A
C710  18 E1           JR,0xC6F3
C712  CD A7 C3        CALL 0xC3A7
C715  CD 80 C4        CALL 0xC480
C718  3E 01           LD A,0x01
C71A  32 18 D0        LD (0xD018),A
C71D  00              NOP
C71E  00              NOP
C71F  00              NOP
C720  CD 90 C3        CALL 0xC390
C723  38 20           JR C,0xC745
C725  FE 80           CP 0x80
C727  28 1C           JR Z,0xC745
C729  30 14           JR NC,0xC73F
C72B  FE 01           CP 0x01
C72D  30 16           JR NC,0xC745
C72F  CD A7 C3        CALL 0xC3A7
C732  CD 80 C4        CALL 0xC480
C735  3A 18 D0        LD A,(0xD018)
C738  C6 01           ADD A,0x01
C73A  32 18 D0        LD (0xD018),A
C73D  18 E1           JR,0xC720
C73F  CD A7 C3        CALL 0xC3A7
C742  CD 80 C4        CALL 0xC480
C745  3E FF           LD A,0xFF
C747  32 18 D0        LD (0xD018),A
C74A  00              NOP
C74B  00              NOP
C74C  00              NOP
C74D  CD 90 C3        CALL 0xC390
C750  38 20           JR C,0xC772
C752  FE 80           CP 0x80
C754  28 1C           JR Z,0xC772
C756  30 14           JR NC,0xC76C
C758  FE 01           CP 0x01
C75A  30 16           JR NC,0xC772
C75C  CD A7 C3        CALL 0xC3A7
C75F  CD 80 C4        CALL 0xC480
C762  3A 18 D0        LD A,(0xD018)
C765  C6 FF           ADD A,0xFF
C767  32 18 D0        LD (0xD018),A
C76A  18 E1           JR,0xC74D
C76C  CD A7 C3        CALL 0xC3A7
C76F  CD 80 C4        CALL 0xC480
C772  F1              POP AF
C773  C9              RET
C774  00              NOP
C775  00              NOP
C776  00              NOP
C777  00              NOP
C778  00              NOP
C779  00              NOP
C77A  00              NOP
C77B  00              NOP
C77C  00              NOP
C77D  00              NOP
C77E  00              NOP
C77F  00              NOP
C780  F5              PUSH AF
C781  3E 0B           LD A,0x0B
C783  32 18 D0        LD (0xD018),A
C786  CD 90 C3        CALL 0xC390
C789  38 20           JR C,0xC7AB
C78B  FE 80           CP 0x80
C78D  28 1C           JR Z,0xC7AB
C78F  30 14           JR NC,0xC7A5
C791  FE 01           CP 0x01
C793  30 16           JR NC,0xC7AB
C795  CD A7 C3        CALL 0xC3A7
C798  CD 80 C4        CALL 0xC480
C79B  3A 18 D0        LD A,(0xD018)
C79E  C6 0B           ADD A,0x0B
C7A0  32 18 D0        LD (0xD018),A
C7A3  18 E1           JR,0xC786
C7A5  CD A7 C3        CALL 0xC3A7
C7A8  CD 80 C4        CALL 0xC480
C7AB  3E F5           LD A,0xF5
C7AD  32 18 D0        LD (0xD018),A
C7B0  00              NOP
C7B1  00              NOP
C7B2  00              NOP
C7B3  CD 90 C3        CALL 0xC390
C7B6  38 20           JR C,0xC7D8
C7B8  FE 80           CP 0x80
C7BA  28 1C           JR Z,0xC7D8
C7BC  30 14           JR NC,0xC7D2
C7BE  FE 01           CP 0x01
C7C0  30 16           JR NC,0xC7D8
C7C2  CD A7 C3        CALL 0xC3A7
C7C5  CD 80 C4        CALL 0xC480
C7C8  3A 18 D0        LD A,(0xD018)
C7CB  C6 F5           ADD A,0xF5
C7CD  32 18 D0        LD (0xD018),A
C7D0  18 E1           JR,0xC7B3
C7D2  CD A7 C3        CALL 0xC3A7
C7D5  CD 80 C4        CALL 0xC480
C7D8  3E 09           LD A,0x09
C7DA  32 18 D0        LD (0xD018),A
C7DD  00              NOP
C7DE  00              NOP
C7DF  00              NOP
C7E0  CD 90 C3        CALL 0xC390
C7E3  38 20           JR C,0xC805
C7E5  FE 80           CP 0x80
C7E7  28 1C           JR Z,0xC805
C7E9  30 14           JR NC,0xC7FF
C7EB  FE 01           CP 0x01
C7ED  30 16           JR NC,0xC805
C7EF  CD A7 C3        CALL 0xC3A7
C7F2  CD 80 C4        CALL 0xC480
C7F5  3A 18 D0        LD A,(0xD018)
C7F8  C6 09           ADD A,0x09
C7FA  32 18 D0        LD (0xD018),A
C7FD  18 E1           JR,0xC7E0
C7FF  CD A7 C3        CALL 0xC3A7
C802  CD 80 C4        CALL 0xC480
C805  3E F7           LD A,0xF7
C807  32 18 D0        LD (0xD018),A
C80A  00              NOP
C80B  00              NOP
C80C  00              NOP
C80D  CD 90 C3        CALL 0xC390
C810  38 20           JR C,0xC832
C812  FE 80           CP 0x80
C814  28 1C           JR Z,0xC832
C816  30 14           JR NC,0xC82C
C818  FE 01           CP 0x01
C81A  30 16           JR NC,0xC832
C81C  CD A7 C3        CALL 0xC3A7
C81F  CD 80 C4        CALL 0xC480
C822  3A 18 D0        LD A,(0xD018)
C825  C6 F7           ADD A,0xF7
C827  32 18 D0        LD (0xD018),A
C82A  18 E1           JR,0xC80D
C82C  CD A7 C3        CALL 0xC3A7
C82F  CD 80 C4        CALL 0xC480
C832  F1              POP AF
C833  C9              RET
C834  00              NOP
C835  00              NOP
C836  00              NOP
C837  FE 81           CP 0x81
C839  38 06           JR C,0xC841
C83B  CD A7 C3        CALL 0xC3A7
C83E  CD 80 C4        CALL 0xC480
C841  3E 0B           LD A,0x0B
C843  32 18 D0        LD (0xD018),A
C846  CD 90 C3        CALL 0xC390
C849  FE 81           CP 0x81
C84B  D8              RET C
C84C  CD A7 C3        CALL 0xC3A7
C84F  CD 80 C4        CALL 0xC480
C852  C9              RET
C853  00              NOP
C854  00              NOP
C855  00              NOP
C856  F5              PUSH AF
C857  3E 09           LD A,0x09
C859  32 18 D0        LD (0xD018),A
C85C  CD 90 C3        CALL 0xC390
C85F  CD 37 C8        CALL 0xC837
C862  3E 0A           LD A,0x0A
C864  32 18 D0        LD (0xD018),A
C867  CD 70 DB        CALL 0xDB70
C86A  FE 01           CP 0x01
C86C  30 1F           JR NC,0xC88D
C86E  CD A7 C3        CALL 0xC3A7
C871  CD 80 C4        CALL 0xC480
C874  3A 15 D0        LD A,(0xD015)
C877  FE 14           CP 0x14
C879  30 12           JR NC,0xC88D
C87B  3E 14           LD A,0x14
C87D  32 18 D0        LD (0xD018),A
C880  CD 70 DB        CALL 0xDB70
C883  FE 01           CP 0x01
C885  30 06           JR NC,0xC88D
C887  CD A7 C3        CALL 0xC3A7
C88A  CD 80 C4        CALL 0xC480
C88D  F1              POP AF
C88E  C9              RET
C88F  00              NOP
C890  00              NOP
C891  00              NOP
C892  2A 20 D0        LD HL,(0xD020)
C895  ED 5B 1A D0     LD DE,(0xD01A)
C899  19              ADD HL,DE
C89A  26 00           LD H,0x00
C89C  3E B2           LD A,0xB2
C89E  85              ADD A,L
C89F  D8              RET C
C8A0  11 00 D1        LD DE,0xD100
C8A3  19              ADD HL,DE
C8A4  7E              LD A,(HL)
C8A5  C9              RET
C8A6  00              NOP
C8A7  00              NOP
C8A8  F5              PUSH AF
C8A9  3E 0A           LD A,0x0A
C8AB  32 1A D0        LD (0xD01A),A
C8AE  CD 92 C8        CALL 0xC892
C8B1  38 1A           JR C,0xC8CD
C8B3  FE 01           CP 0x01
C8B5  38 06           JR C,0xC8BD
C8B7  FE 80           CP 0x80
C8B9  38 0F           JR C,0xC8CA
C8BB  18 10           JR,0xC8CD
C8BD  CD 10 C5        CALL 0xC510
C8C0  3A 1A D0        LD A,(0xD01A)
C8C3  C6 0A           ADD A,0x0A
C8C5  32 1A D0        LD (0xD01A),A
C8C8  18 E4           JR,0xC8AE
C8CA  CD 10 C5        CALL 0xC510
C8CD  3E F6           LD A,0xF6
C8CF  32 1A D0        LD (0xD01A),A
C8D2  00              NOP
C8D3  00              NOP
C8D4  00              NOP
C8D5  CD 92 C8        CALL 0xC892
C8D8  38 1A           JR C,0xC8F4
C8DA  FE 01           CP 0x01
C8DC  38 06           JR C,0xC8E4
C8DE  FE 80           CP 0x80
C8E0  38 0F           JR C,0xC8F1
C8E2  18 10           JR,0xC8F4
C8E4  CD 10 C5        CALL 0xC510
C8E7  3A 1A D0        LD A,(0xD01A)
C8EA  C6 F6           ADD A,0xF6
C8EC  32 1A D0        LD (0xD01A),A
C8EF  18 E4           JR,0xC8D5
C8F1  CD 10 C5        CALL 0xC510
C8F4  3E 01           LD A,0x01
C8F6  32 1A D0        LD (0xD01A),A
C8F9  00              NOP
C8FA  00              NOP
C8FB  00              NOP
C8FC  CD 92 C8        CALL 0xC892
C8FF  38 1A           JR C,0xC91B
C901  FE 01           CP 0x01
C903  38 06           JR C,0xC90B
C905  FE 80           CP 0x80
C907  38 0F           JR C,0xC918
C909  18 10           JR,0xC91B
C90B  CD 10 C5        CALL 0xC510
C90E  3A 1A D0        LD A,(0xD01A)
C911  C6 01           ADD A,0x01
C913  32 1A D0        LD (0xD01A),A
C916  18 E4           JR,0xC8FC
C918  CD 10 C5        CALL 0xC510
C91B  3E FF           LD A,0xFF
C91D  32 1A D0        LD (0xD01A),A
C920  00              NOP
C921  00              NOP
C922  00              NOP
C923  CD 92 C8        CALL 0xC892
C926  38 1A           JR C,0xC942
C928  FE 01           CP 0x01
C92A  38 06           JR C,0xC932
C92C  FE 80           CP 0x80
C92E  38 0F           JR C,0xC93F
C930  18 10           JR,0xC942
C932  CD 10 C5        CALL 0xC510
C935  3A 1A D0        LD A,(0xD01A)
C938  C6 FF           ADD A,0xFF
C93A  32 1A D0        LD (0xD01A),A
C93D  18 E4           JR,0xC923
C93F  CD 10 C5        CALL 0xC510
C942  3E 0B           LD A,0x0B
C944  32 1A D0        LD (0xD01A),A
C947  00              NOP
C948  00              NOP
C949  00              NOP
C94A  CD 92 C8        CALL 0xC892
C94D  38 1A           JR C,0xC969
C94F  FE 01           CP 0x01
C951  38 06           JR C,0xC959
C953  FE 80           CP 0x80
C955  38 0F           JR C,0xC966
C957  18 10           JR,0xC969
C959  CD 10 C5        CALL 0xC510
C95C  3A 1A D0        LD A,(0xD01A)
C95F  C6 0B           ADD A,0x0B
C961  32 1A D0        LD (0xD01A),A
C964  18 E4           JR,0xC94A
C966  CD 10 C5        CALL 0xC510
C969  3E F5           LD A,0xF5
C96B  32 1A D0        LD (0xD01A),A
C96E  00              NOP
C96F  00              NOP
C970  00              NOP
C971  CD 92 C8        CALL 0xC892
C974  38 1A           JR C,0xC990
C976  FE 01           CP 0x01
C978  38 06           JR C,0xC980
C97A  FE 80           CP 0x80
C97C  38 0F           JR C,0xC98D
C97E  18 10           JR,0xC990
C980  CD 10 C5        CALL 0xC510
C983  3A 1A D0        LD A,(0xD01A)
C986  C6 F5           ADD A,0xF5
C988  32 1A D0        LD (0xD01A),A
C98B  18 E4           JR,0xC971
C98D  CD 10 C5        CALL 0xC510
C990  3E 09           LD A,0x09
C992  32 1A D0        LD (0xD01A),A
C995  00              NOP
C996  00              NOP
C997  00              NOP
C998  CD 92 C8        CALL 0xC892
C99B  38 1A           JR C,0xC9B7
C99D  FE 01           CP 0x01
C99F  38 06           JR C,0xC9A7
C9A1  FE 80           CP 0x80
C9A3  38 0F           JR C,0xC9B4
C9A5  18 10           JR,0xC9B7
C9A7  CD 10 C5        CALL 0xC510
C9AA  3A 1A D0        LD A,(0xD01A)
C9AD  C6 09           ADD A,0x09
C9AF  32 1A D0        LD (0xD01A),A
C9B2  18 E4           JR,0xC998
C9B4  CD 10 C5        CALL 0xC510
C9B7  3E F7           LD A,0xF7
C9B9  32 1A D0        LD (0xD01A),A
C9BC  00              NOP
C9BD  00              NOP
C9BE  00              NOP
C9BF  00              NOP
C9C0  CD 92 C8        CALL 0xC892
C9C3  38 1A           JR C,0xC9DF
C9C5  FE 01           CP 0x01
C9C7  38 06           JR C,0xC9CF
C9C9  FE 80           CP 0x80
C9CB  38 0F           JR C,0xC9DC
C9CD  18 10           JR,0xC9DF
C9CF  CD 10 C5        CALL 0xC510
C9D2  3A 1A D0        LD A,(0xD01A)
C9D5  C6 F7           ADD A,0xF7
C9D7  32 1A D0        LD (0xD01A),A
C9DA  18 E4           JR,0xC9C0
C9DC  CD 10 C5        CALL 0xC510
C9DF  F1              POP AF
C9E0  C9              RET
C9E1  00              NOP
C9E2  00              NOP
C9E3  00              NOP
C9E4  00              NOP
C9E5  00              NOP
C9E6  00              NOP
C9E7  00              NOP
C9E8  00              NOP
C9E9  00              NOP
C9EA  00              NOP
C9EB  00              NOP
C9EC  00              NOP
C9ED  00              NOP
C9EE  00              NOP
C9EF  00              NOP
C9F0  00              NOP
C9F1  00              NOP
C9F2  00              NOP
C9F3  00              NOP
C9F4  00              NOP
C9F5  00              NOP
C9F6  00              NOP
C9F7  00              NOP
C9F8  00              NOP
C9F9  00              NOP
C9FA  00              NOP
C9FB  00              NOP
C9FC  00              NOP
C9FD  00              NOP
C9FE  00              NOP
C9FF  00              NOP
CA00  F5              PUSH AF
CA01  3E 0A           LD A,0x0A
CA03  32 1A D0        LD (0xD01A),A
CA06  CD 92 C8        CALL 0xC892
CA09  38 1A           JR C,0xCA25
CA0B  FE 01           CP 0x01
CA0D  38 06           JR C,0xCA15
CA0F  FE 80           CP 0x80
CA11  38 0F           JR C,0xCA22
CA13  18 10           JR,0xCA25
CA15  CD 10 C5        CALL 0xC510
CA18  3A 1A D0        LD A,(0xD01A)
CA1B  C6 0A           ADD A,0x0A
CA1D  32 1A D0        LD (0xD01A),A
CA20  18 E4           JR,0xCA06
CA22  CD 10 C5        CALL 0xC510
CA25  3E F6           LD A,0xF6
CA27  32 1A D0        LD (0xD01A),A
CA2A  00              NOP
CA2B  00              NOP
CA2C  00              NOP
CA2D  CD 92 C8        CALL 0xC892
CA30  38 1A           JR C,0xCA4C
CA32  FE 01           CP 0x01
CA34  38 06           JR C,0xCA3C
CA36  FE 80           CP 0x80
CA38  38 0F           JR C,0xCA49
CA3A  18 10           JR,0xCA4C
CA3C  CD 10 C5        CALL 0xC510
CA3F  3A 1A D0        LD A,(0xD01A)
CA42  C6 F6           ADD A,0xF6
CA44  32 1A D0        LD (0xD01A),A
CA47  18 E4           JR,0xCA2D
CA49  CD 10 C5        CALL 0xC510
CA4C  3E 01           LD A,0x01
CA4E  32 1A D0        LD (0xD01A),A
CA51  00              NOP
CA52  00              NOP
CA53  00              NOP
CA54  CD 92 C8        CALL 0xC892
CA57  38 1A           JR C,0xCA73
CA59  FE 01           CP 0x01
CA5B  38 06           JR C,0xCA63
CA5D  FE 80           CP 0x80
CA5F  38 0F           JR C,0xCA70
CA61  18 10           JR,0xCA73
CA63  CD 10 C5        CALL 0xC510
CA66  3A 1A D0        LD A,(0xD01A)
CA69  C6 01           ADD A,0x01
CA6B  32 1A D0        LD (0xD01A),A
CA6E  18 E4           JR,0xCA54
CA70  CD 10 C5        CALL 0xC510
CA73  3E FF           LD A,0xFF
CA75  32 1A D0        LD (0xD01A),A
CA78  00              NOP
CA79  00              NOP
CA7A  00              NOP
CA7B  CD 92 C8        CALL 0xC892
CA7E  38 1A           JR C,0xCA9A
CA80  FE 01           CP 0x01
CA82  38 06           JR C,0xCA8A
CA84  FE 80           CP 0x80
CA86  38 0F           JR C,0xCA97
CA88  18 10           JR,0xCA9A
CA8A  CD 10 C5        CALL 0xC510
CA8D  3A 1A D0        LD A,(0xD01A)
CA90  C6 FF           ADD A,0xFF
CA92  32 1A D0        LD (0xD01A),A
CA95  18 E4           JR,0xCA7B
CA97  CD 10 C5        CALL 0xC510
CA9A  F1              POP AF
CA9B  C9              RET
CA9C  00              NOP
CA9D  00              NOP
CA9E  00              NOP
CA9F  00              NOP
CAA0  F5              PUSH AF
CAA1  3E 0B           LD A,0x0B
CAA3  32 1A D0        LD (0xD01A),A
CAA6  CD 92 C8        CALL 0xC892
CAA9  38 1A           JR C,0xCAC5
CAAB  FE 01           CP 0x01
CAAD  38 06           JR C,0xCAB5
CAAF  FE 80           CP 0x80
CAB1  38 0F           JR C,0xCAC2
CAB3  18 10           JR,0xCAC5
CAB5  CD 10 C5        CALL 0xC510
CAB8  3A 1A D0        LD A,(0xD01A)
CABB  C6 0B           ADD A,0x0B
CABD  32 1A D0        LD (0xD01A),A
CAC0  18 E4           JR,0xCAA6
CAC2  CD 10 C5        CALL 0xC510
CAC5  3E F5           LD A,0xF5
CAC7  32 1A D0        LD (0xD01A),A
CACA  00              NOP
CACB  00              NOP
CACC  00              NOP
CACD  CD 92 C8        CALL 0xC892
CAD0  38 1A           JR C,0xCAEC
CAD2  FE 01           CP 0x01
CAD4  38 06           JR C,0xCADC
CAD6  FE 80           CP 0x80
CAD8  38 0F           JR C,0xCAE9
CADA  18 10           JR,0xCAEC
CADC  CD 10 C5        CALL 0xC510
CADF  3A 1A D0        LD A,(0xD01A)
CAE2  C6 F5           ADD A,0xF5
CAE4  32 1A D0        LD (0xD01A),A
CAE7  18 E4           JR,0xCACD
CAE9  CD 10 C5        CALL 0xC510
CAEC  3E 09           LD A,0x09
CAEE  32 1A D0        LD (0xD01A),A
CAF1  00              NOP
CAF2  00              NOP
CAF3  00              NOP
CAF4  CD 92 C8        CALL 0xC892
CAF7  38 1A           JR C,0xCB13
CAF9  FE 01           CP 0x01
CAFB  38 06           JR C,0xCB03
CAFD  FE 80           CP 0x80
CAFF  38 0F           JR C,0xCB10
CB01  18 10           JR,0xCB13
CB03  CD 10 C5        CALL 0xC510
CB06  3A 1A D0        LD A,(0xD01A)
CB09  C6 09           ADD A,0x09
CB0B  32 1A D0        LD (0xD01A),A
CB0E  18 E4           JR,0xCAF4
CB10  CD 10 C5        CALL 0xC510
CB13  3E F7           LD A,0xF7
CB15  32 1A D0        LD (0xD01A),A
CB18  00              NOP
CB19  00              NOP
CB1A  00              NOP
CB1B  00              NOP
CB1C  CD 92 C8        CALL 0xC892
CB1F  38 1A           JR C,0xCB3B
CB21  FE 01           CP 0x01
CB23  38 06           JR C,0xCB2B
CB25  FE 80           CP 0x80
CB27  38 0F           JR C,0xCB38
CB29  18 10           JR,0xCB3B
CB2B  CD 10 C5        CALL 0xC510
CB2E  3A 1A D0        LD A,(0xD01A)
CB31  C6 F7           ADD A,0xF7
CB33  32 1A D0        LD (0xD01A),A
CB36  18 E4           JR,0xCB1C
CB38  CD 10 C5        CALL 0xC510
CB3B  F1              POP AF
CB3C  C9              RET
CB3D  00              NOP
CB3E  00              NOP
CB3F  00              NOP
CB40  F5              PUSH AF
CB41  3E 0C           LD A,0x0C
CB43  32 1A D0        LD (0xD01A),A
CB46  CD 28 C5        CALL 0xC528
CB49  3E F4           LD A,0xF4
CB4B  32 1A D0        LD (0xD01A),A
CB4E  CD 28 C5        CALL 0xC528
CB51  3E 08           LD A,0x08
CB53  32 1A D0        LD (0xD01A),A
CB56  CD 28 C5        CALL 0xC528
CB59  3E F8           LD A,0xF8
CB5B  32 1A D0        LD (0xD01A),A
CB5E  CD 28 C5        CALL 0xC528
CB61  3E 15           LD A,0x15
CB63  32 1A D0        LD (0xD01A),A
CB66  CD 28 C5        CALL 0xC528
CB69  3E EB           LD A,0xEB
CB6B  32 1A D0        LD (0xD01A),A
CB6E  CD 28 C5        CALL 0xC528
CB71  3E 13           LD A,0x13
CB73  32 1A D0        LD (0xD01A),A
CB76  CD 28 C5        CALL 0xC528
CB79  3E ED           LD A,0xED
CB7B  32 1A D0        LD (0xD01A),A
CB7E  CD 28 C5        CALL 0xC528
CB81  F1              POP AF
CB82  C9              RET
CB83  00              NOP
CB84  00              NOP
CB85  00              NOP
CB86  00              NOP
CB87  00              NOP
CB88  00              NOP
CB89  00              NOP
CB8A  00              NOP
CB8B  00              NOP
CB8C  00              NOP
CB8D  00              NOP
CB8E  00              NOP
CB8F  00              NOP
CB90  F5              PUSH AF
CB91  3E 01           LD A,0x01
CB93  32 1A D0        LD (0xD01A),A
CB96  CD 28 C5        CALL 0xC528
CB99  3E 0A           LD A,0x0A
CB9B  32 1A D0        LD (0xD01A),A
CB9E  CD 28 C5        CALL 0xC528
CBA1  3E FF           LD A,0xFF
CBA3  32 1A D0        LD (0xD01A),A
CBA6  CD 28 C5        CALL 0xC528
CBA9  3E F6           LD A,0xF6
CBAB  32 1A D0        LD (0xD01A),A
CBAE  CD 28 C5        CALL 0xC528
CBB1  3E 0B           LD A,0x0B
CBB3  32 1A D0        LD (0xD01A),A
CBB6  CD 28 C5        CALL 0xC528
CBB9  3E 09           LD A,0x09
CBBB  32 1A D0        LD (0xD01A),A
CBBE  CD 28 C5        CALL 0xC528
CBC1  3E F7           LD A,0xF7
CBC3  32 1A D0        LD (0xD01A),A
CBC6  CD 28 C5        CALL 0xC528
CBC9  3E F5           LD A,0xF5
CBCB  32 1A D0        LD (0xD01A),A
CBCE  CD 28 C5        CALL 0xC528
CBD1  F1              POP AF
CBD2  C9              RET
CBD3  00              NOP
CBD4  00              NOP
CBD5  00              NOP
CBD6  00              NOP
CBD7  00              NOP
CBD8  FE 01           CP 0x01
CBDA  D8              RET C
CBDB  FE 80           CP 0x80
CBDD  C8              RET Z
CBDE  D0              RET NC
CBDF  CD 10 C5        CALL 0xC510
CBE2  C9              RET
CBE3  00              NOP
CBE4  00              NOP
CBE5  00              NOP
CBE6  00              NOP
CBE7  00              NOP
CBE8  F5              PUSH AF
CBE9  3E F7           LD A,0xF7
CBEB  32 1A D0        LD (0xD01A),A
CBEE  CD 92 C8        CALL 0xC892
CBF1  CD D8 CB        CALL 0xCBD8
CBF4  3E F5           LD A,0xF5
CBF6  32 1A D0        LD (0xD01A),A
CBF9  CD 92 C8        CALL 0xC892
CBFC  CD D8 CB        CALL 0xCBD8
CBFF  3E F6           LD A,0xF6
CC01  32 1A D0        LD (0xD01A),A
CC04  CD 92 C8        CALL 0xC892
CC07  FE 01           CP 0x01
CC09  30 19           JR NC,0xCC24
CC0B  CD 10 C5        CALL 0xC510
CC0E  3A 20 D0        LD A,(0xD020)
CC11  FE 3C           CP 0x3C
CC13  38 0F           JR C,0xCC24
CC15  3E EC           LD A,0xEC
CC17  32 1A D0        LD (0xD01A),A
CC1A  CD 92 C8        CALL 0xC892
CC1D  FE 01           CP 0x01
CC1F  30 03           JR NC,0xCC24
CC21  CD 10 C5        CALL 0xC510
CC24  F1              POP AF
CC25  C9              RET
CC26  00              NOP
CC27  00              NOP
CC28  00              NOP
CC29  00              NOP
CC2A  00              NOP
CC2B  00              NOP
CC2C  00              NOP
CC2D  00              NOP
CC2E  00              NOP
CC2F  00              NOP
CC30  D5              PUSH DE
CC31  E5              PUSH HL
CC32  21 00 80        LD HL,0x8000
CC35  19              ADD HL,DE
CC36  EB              EX DE,HL
CC37  E1              POP HL
CC38  01 00 80        LD BC,0x8000
CC3B  09              ADD HL,BC
CC3C  CD 3B 02        CALL 0x023B
CC3F  D1              POP DE
CC40  C9              RET
CC41  00              NOP
CC42  00              NOP
CC43  00              NOP
CC44  00              NOP
CC45  00              NOP
CC46  00              NOP
CC47  00              NOP
CC48  00              NOP
CC49  00              NOP
CC4A  00              NOP
CC4B  00              NOP
CC4C  00              NOP
CC4D  00              NOP
CC4E  00              NOP
CC4F  00              NOP
CC50  D5              PUSH DE
CC51  E5              PUSH HL
CC52  11 01 00        LD DE,0x0001
CC55  21 00 00        LD HL,0x0000
CC58  19              ADD HL,DE
CC59  30 FD           JR NC,0xCC58
CC5B  E1              POP HL
CC5C  D1              POP DE
CC5D  C9              RET
CC5E  00              NOP
CC5F  00              NOP
CC60  2A 03 D0        LD HL,(0xD003)
CC63  ED 5B 0A D0     LD DE,(0xD00A)
CC67  2B              DEC HL
CC68  C9              RET
CC69  00              NOP
CC6A  00              NOP
CC6B  00              NOP
CC6C  00              NOP
CC6D  00              NOP
CC6E  00              NOP
CC6F  00              NOP
CC70  ED 53 03 D0     LD (0xD003),DE
CC74  2A 08 D0        LD HL,(0xD008)
CC77  22 01 D0        LD (0xD001),HL
CC7A  C9              RET
CC7B  00              NOP
CC7C  00              NOP
CC7D  00              NOP
CC7E  00              NOP
CC7F  00              NOP
CC80  3A 15 D0        LD A,(0xD015)
CC83  32 08 D0        LD (0xD008),A
CC86  21 18 D0        LD HL,0xD018
CC89  46              LD B,(HL)
CC8A  80              ADD A,B
CC8B  32 09 D0        LD (0xD009),A
CC8E  21 F0 7F        LD HL,0x7FF0
CC91  22 0A D0        LD (0xD00A),HL
CC94  C9              RET
CC95  00              NOP
CC96  00              NOP
CC97  00              NOP
CC98  00              NOP
CC99  00              NOP
CC9A  00              NOP
CC9B  00              NOP
CC9C  00              NOP
CC9D  00              NOP
CC9E  00              NOP
CC9F  00              NOP
CCA0  2A 03 D0        LD HL,(0xD003)
CCA3  ED 5B 12 D0     LD DE,(0xD012)
CCA7  2B              DEC HL
CCA8  CD 30 CC        CALL 0xCC30
CCAB  38 13           JR C,0xCCC0
CCAD  2A 0A D0        LD HL,(0xD00A)
CCB0  ED 5B 12 D0     LD DE,(0xD012)
CCB4  2B              DEC HL
CCB5  CD 30 CC        CALL 0xCC30
CCB8  30 04           JR NC,0xCCBE
CCBA  ED 53 0A D0     LD (0xD00A),DE
CCBE  C9              RET
CCBF  00              NOP
CCC0  CD F0 C1        CALL 0xC1F0
CCC3  31 60 FF        LD SP,0xFF60
CCC6  C9              RET
CCC7  00              NOP
CCC8  00              NOP
CCC9  00              NOP
CCCA  00              NOP
CCCB  00              NOP
CCCC  00              NOP
CCCD  00              NOP
CCCE  00              NOP
CCCF  00              NOP
CCD0  00              NOP
CCD1  00              NOP
CCD2  00              NOP
CCD3  00              NOP
CCD4  00              NOP
CCD5  00              NOP
CCD6  00              NOP
CCD7  00              NOP
CCD8  00              NOP
CCD9  00              NOP
CCDA  00              NOP
CCDB  00              NOP
CCDC  00              NOP
CCDD  00              NOP
CCDE  00              NOP
CCDF  00              NOP
CCE0  00              NOP
CCE1  00              NOP
CCE2  00              NOP
CCE3  00              NOP
CCE4  00              NOP
CCE5  00              NOP
CCE6  00              NOP
CCE7  00              NOP
CCE8  00              NOP
CCE9  00              NOP
CCEA  00              NOP
CCEB  00              NOP
CCEC  00              NOP
CCED  00              NOP
CCEE  00              NOP
CCEF  00              NOP
CCF0  00              NOP
CCF1  00              NOP
CCF2  00              NOP
CCF3  00              NOP
CCF4  00              NOP
CCF5  00              NOP
CCF6  00              NOP
CCF7  00              NOP
CCF8  00              NOP
CCF9  00              NOP
CCFA  00              NOP
CCFB  00              NOP
CCFC  00              NOP
CCFD  00              NOP
CCFE  00              NOP
CCFF  00              NOP
CD00  2A 38 D0        LD HL,(0xD038)
CD03  ED 5B 48 D0     LD DE,(0xD048)
CD07  19              ADD HL,DE
CD08  26 00           LD H,0x00
CD0A  3E B2           LD A,0xB2
CD0C  85              ADD A,L
CD0D  D8              RET C
CD0E  11 50 D1        LD DE,0xD150
CD11  19              ADD HL,DE
CD12  7E              LD A,(HL)
CD13  C9              RET
CD14  00              NOP
CD15  00              NOP
CD16  00              NOP
CD17  00              NOP
CD18  00              NOP
CD19  00              NOP
CD1A  00              NOP
CD1B  00              NOP
CD1C  00              NOP
CD1D  00              NOP
CD1E  00              NOP
CD1F  00              NOP
CD20  2A 38 D0        LD HL,(0xD038)
CD23  11 A0 D1        LD DE,0xD1A0
CD26  19              ADD HL,DE
CD27  46              LD B,(HL)
CD28  36 00           LD (HL),0x00
CD2A  3A 48 D0        LD A,(0xD048)
CD2D  85              ADD A,L
CD2E  6F              LD L,A
CD2F  70              LD (HL),B
CD30  CD 0E C2        CALL 0xC20E
CD33  2A 0A D0        LD HL,(0xD00A)
CD36  ED 5B 35 D0     LD DE,(0xD035)
CD3A  2B              DEC HL
CD3B  CD 30 CC        CALL 0xCC30
CD3E  30 19           JR NC,0xCD59
CD40  2A 12 D0        LD HL,(0xD012)
CD43  2B              DEC HL
CD44  CD 30 CC        CALL 0xCC30
CD47  38 04           JR C,0xCD4D
CD49  ED 53 12 D0     LD (0xD012),DE
CD4D  21 50 D1        LD HL,0xD150
CD50  11 A0 D1        LD DE,0xD1A0
CD53  01 4E 00        LD BC,0x004E
CD56  ED B0           LDIR
CD58  C9              RET
CD59  CD 0C CE        CALL 0xCE0C
CD5C  31 58 FF        LD SP,0xFF58
CD5F  C9              RET
CD60  2A 38 D0        LD HL,(0xD038)
CD63  ED 5B 48 D0     LD DE,(0xD048)
CD67  19              ADD HL,DE
CD68  26 00           LD H,0x00
CD6A  3E B2           LD A,0xB2
CD6C  85              ADD A,L
CD6D  D8              RET C
CD6E  11 50 D1        LD DE,0xD150
CD71  19              ADD HL,DE
CD72  7E              LD A,(HL)
CD73  FE 01           CP 0x01
CD75  38 04           JR C,0xCD7B
CD77  FE 80           CP 0x80
CD79  C8              RET Z
CD7A  D8              RET C
CD7B  CD 20 CD        CALL 0xCD20
CD7E  C9              RET
CD7F  00              NOP
CD80  21 38 D0        LD HL,0xD038
CD83  36 00           LD (HL),0x00
CD85  21 50 D1        LD HL,0xD150
CD88  11 A0 D1        LD DE,0xD1A0
CD8B  01 4E 00        LD BC,0x004E
CD8E  ED B0           LDIR
CD90  2A 38 D0        LD HL,(0xD038)
CD93  11 A0 D1        LD DE,0xD1A0
CD96  19              ADD HL,DE
CD97  7E              LD A,(HL)
CD98  FE 80           CP 0x80
CD9A  CA E3 CD        JP Z,0xCDE3
CD9D  D2 E3 CD        JP NC,0xCDE3
CDA0  FE 01           CP 0x01
CDA2  DA E3 CD        JP C,0xCDE3
CDA5  FE 02           CP 0x02
CDA7  CC 30 D8        CALL Z,0xD830
CDAA  FE 7F           CP 0x7F
CDAC  CC E0 D7        CALL Z,0xD7E0
CDAF  FE 14           CP 0x14
CDB1  CC 00 D5        CALL Z,0xD500
CDB4  FE 07           CP 0x07
CDB6  CC F0 D6        CALL Z,0xD6F0
CDB9  FE 0A           CP 0x0A
CDBB  CC 4A D6        CALL Z,0xD64A
CDBE  FE 06           CP 0x06
CDC0  CC 95 D7        CALL Z,0xD795
CDC3  3A 38 D0        LD A,(0xD038)
CDC6  FE 4D           CP 0x4D
CDC8  28 07           JR Z,0xCDD1
CDCA  3C              INC A
CDCB  32 38 D0        LD (0xD038),A
CDCE  C3 85 CD        JP 0xCD85
CDD1  2A 12 D0        LD HL,(0xD012)
CDD4  ED 5B 35 D0     LD DE,(0xD035)
CDD8  2B              DEC HL
CDD9  CD 30 CC        CALL 0xCC30
CDDC  38 04           JR C,0xCDE2
CDDE  ED 53 12 D0     LD (0xD012),DE
CDE2  C9              RET
CDE3  3A 38 D0        LD A,(0xD038)
CDE6  FE 4D           CP 0x4D
CDE8  CA D1 CD        JP Z,0xCDD1
CDEB  3C              INC A
CDEC  32 38 D0        LD (0xD038),A
CDEF  C3 90 CD        JP 0xCD90
CDF2  00              NOP
CDF3  00              NOP
CDF4  00              NOP
CDF5  00              NOP
CDF6  00              NOP
CDF7  00              NOP
CDF8  00              NOP
CDF9  00              NOP
CDFA  00              NOP
CDFB  00              NOP
CDFC  00              NOP
CDFD  00              NOP
CDFE  00              NOP
CDFF  00              NOP
CE00  21 00 80        LD HL,0x8000
CE03  22 12 D0        LD (0xD012),HL
CE06  CD 80 CD        CALL 0xCD80
CE09  CD A0 CC        CALL 0xCCA0
CE0C  21 00 D1        LD HL,0xD100
CE0F  01 4E 00        LD BC,0x004E
CE12  11 50 D1        LD DE,0xD150
CE15  ED B0           LDIR
CE17  C9              RET
CE18  00              NOP
CE19  00              NOP
CE1A  00              NOP
CE1B  00              NOP
CE1C  00              NOP
CE1D  00              NOP
CE1E  00              NOP
CE1F  00              NOP
CE20  CD 50 CE        CALL 0xCE50
CE23  CD A0 CC        CALL 0xCCA0
CE26  21 00 D1        LD HL,0xD100
CE29  01 4E 00        LD BC,0x004E
CE2C  11 50 D1        LD DE,0xD150
CE2F  ED B0           LDIR
CE31  C9              RET
CE32  00              NOP
CE33  00              NOP
CE34  00              NOP
CE35  00              NOP
CE36  21 5C D0        LD HL,0xD05C
CE39  7E              LD A,(HL)
CE3A  FE 01           CP 0x01
CE3C  28 04           JR Z,0xCE42
CE3E  CD 20 CE        CALL 0xCE20
CE41  C9              RET
CE42  CD 00 CE        CALL 0xCE00
CE45  C9              RET
CE46  00              NOP
CE47  00              NOP
CE48  00              NOP
CE49  00              NOP
CE4A  00              NOP
CE4B  00              NOP
CE4C  00              NOP
CE4D  00              NOP
CE4E  00              NOP
CE4F  00              NOP
CE50  21 12 D0        LD HL,0xD012
CE53  36 00           LD (HL),0x00
CE55  23              INC HL
CE56  36 00           LD (HL),0x00
CE58  21 23 D0        LD HL,0xD023
CE5B  36 00           LD (HL),0x00
CE5D  CD F2 CE        CALL 0xCEF2
CE60  21 23 D0        LD HL,0xD023
CE63  36 00           LD (HL),0x00
CE65  2A 12 D0        LD HL,(0xD012)
CE68  ED 5B 12 D0     LD DE,(0xD012)
CE6C  19              ADD HL,DE
CE6D  19              ADD HL,DE
CE6E  19              ADD HL,DE
CE6F  19              ADD HL,DE
CE70  19              ADD HL,DE
CE71  22 12 D0        LD (0xD012),HL
CE74  3A 23 D0        LD A,(0xD023)
CE77  FE 4E           CP 0x4E
CE79  20 01           JR NZ,0xCE7C
CE7B  C9              RET
CE7C  2A 23 D0        LD HL,(0xD023)
CE7F  11 50 D1        LD DE,0xD150
CE82  19              ADD HL,DE
CE83  7E              LD A,(HL)
CE84  FE 01           CP 0x01
CE86  DA D7 CE        JP C,0xCED7
CE89  FE 02           CP 0x02
CE8B  20 0E           JR NZ,0xCE9B
CE8D  2A 23 D0        LD HL,(0xD023)
CE90  11 A0 D2        LD DE,0xD2A0
CE93  19              ADD HL,DE
CE94  7E              LD A,(HL)
CE95  32 26 D0        LD (0xD026),A
CE98  C3 D7 CE        JP 0xCED7
CE9B  FE FE           CP 0xFE
CE9D  20 13           JR NZ,0xCEB2
CE9F  2A 23 D0        LD HL,(0xD023)
CEA2  11 A0 D3        LD DE,0xD3A0
CEA5  19              ADD HL,DE
CEA6  7E              LD A,(HL)
CEA7  32 26 D0        LD (0xD026),A
CEAA  3E FF           LD A,0xFF
CEAC  32 27 D0        LD (0xD027),A
CEAF  C3 D7 CE        JP 0xCED7
CEB2  FE 80           CP 0x80
CEB4  CA D7 CE        JP Z,0xCED7
CEB7  30 0E           JR NC,0xCEC7
CEB9  2A 23 D0        LD HL,(0xD023)
CEBC  11 50 D2        LD DE,0xD250
CEBF  19              ADD HL,DE
CEC0  7E              LD A,(HL)
CEC1  32 26 D0        LD (0xD026),A
CEC4  C3 D7 CE        JP 0xCED7
CEC7  2A 23 D0        LD HL,(0xD023)
CECA  11 50 D3        LD DE,0xD350
CECD  19              ADD HL,DE
CECE  7E              LD A,(HL)
CECF  32 26 D0        LD (0xD026),A
CED2  3E FF           LD A,0xFF
CED4  32 27 D0        LD (0xD027),A
CED7  2A 12 D0        LD HL,(0xD012)
CEDA  ED 5B 26 D0     LD DE,(0xD026)
CEDE  19              ADD HL,DE
CEDF  22 12 D0        LD (0xD012),HL
CEE2  21 00 00        LD HL,0x0000
CEE5  22 26 D0        LD (0xD026),HL
CEE8  3A 23 D0        LD A,(0xD023)
CEEB  3C              INC A
CEEC  32 23 D0        LD (0xD023),A
CEEF  C3 74 CE        JP 0xCE74
CEF2  01 00 00        LD BC,0x0000
CEF5  2A 23 D0        LD HL,(0xD023)
CEF8  11 50 D1        LD DE,0xD150
CEFB  19              ADD HL,DE
CEFC  7E              LD A,(HL)
CEFD  FE 80           CP 0x80
CEFF  28 0C           JR Z,0xCF0D
CF01  38 02           JR C,0xCF05
CF03  06 FF           LD B,0xFF
CF05  4F              LD C,A
CF06  2A 12 D0        LD HL,(0xD012)
CF09  09              ADD HL,BC
CF0A  22 12 D0        LD (0xD012),HL
CF0D  3A 23 D0        LD A,(0xD023)
CF10  FE 4D           CP 0x4D
CF12  28 06           JR Z,0xCF1A
CF14  3C              INC A
CF15  32 23 D0        LD (0xD023),A
CF18  18 D8           JR,0xCEF2
CF1A  C9              RET
CF1B  00              NOP
CF1C  00              NOP
CF1D  CD C6 FF        CALL 0xFFC6
CF20  CD 90 D8        CALL 0xD890
CF23  FE 14           CP 0x14
CF25  C8              RET Z
CF26  FE 01           CP 0x01
CF28  C0              RET NZ
CF29  21 5C D0        LD HL,0xD05C
CF2C  CB 46           BIT 0,(HL)
CF2E  20 04           JR NZ,0xCF34
CF30  CD 3B CF        CALL 0xCF3B
CF33  C9              RET
CF34  CD 48 CF        CALL 0xCF48
CF37  C9              RET
CF38  00              NOP
CF39  00              NOP
CF3A  00              NOP
CF3B  3E 48           LD A,0x48
CF3D  32 FA FF        LD (0xFFFA),A
CF40  32 FB FF        LD (0xFFFB),A
CF43  36 01           LD (HL),0x01
CF45  C9              RET
CF46  00              NOP
CF47  00              NOP
CF48  3E 40           LD A,0x40
CF4A  32 FA FF        LD (0xFFFA),A
CF4D  32 FB FF        LD (0xFFFB),A
CF50  36 00           LD (HL),0x00
CF52  C9              RET
CF53  00              NOP
CF54  00              NOP
CF55  00              NOP
CF56  CD 46 DA        CALL 0xDA46
CF59  00              NOP
CF5A  00              NOP
CF5B  11 B0 D0        LD DE,0xD0B0
CF5E  19              ADD HL,DE
CF5F  7E              LD A,(HL)
CF60  36 00           LD (HL),0x00
CF62  2A 02 D0        LD HL,(0xD002)
CF65  26 00           LD H,0x00
CF67  19              ADD HL,DE
CF68  77              LD (HL),A
CF69  FE 02           CP 0x02
CF6B  C0              RET NZ
CF6C  47              LD B,A
CF6D  7D              LD A,L
CF6E  FE F5           CP 0xF5
CF70  D8              RET C
CF71  36 14           LD (HL),0x14
CF73  3E 76           LD A,0x76
CF75  32 FE FF        LD (0xFFFE),A
CF78  21 E9 FF        LD HL,0xFFE9
CF7B  36 20           LD (HL),0x20
CF7D  CD 50 CC        CALL 0xCC50
CF80  36 20           LD (HL),0x20
CF82  CD 50 CC        CALL 0xCC50
CF85  36 20           LD (HL),0x20
CF87  CD 50 CC        CALL 0xCC50
CF8A  36 20           LD (HL),0x20
CF8C  CD B7 C1        CALL 0xC1B7
CF8F  3E 63           LD A,0x63
CF91  32 FE FF        LD (0xFFFE),A
CF94  C9              RET
CF95  00              NOP
CF96  00              NOP
CF97  00              NOP
CF98  00              NOP
CF99  00              NOP
CF9A  00              NOP
CF9B  00              NOP
CF9C  00              NOP
CF9D  CD 90 DB        CALL 0xDB90
CFA0  2A 28 D0        LD HL,(0xD028)
CFA3  11 B0 D0        LD DE,0xD0B0
CFA6  19              ADD HL,DE
CFA7  7E              LD A,(HL)
CFA8  36 00           LD (HL),0x00
CFAA  2A 2A D0        LD HL,(0xD02A)
CFAD  19              ADD HL,DE
CFAE  4F              LD C,A
CFAF  7E              LD A,(HL)
CFB0  32 40 D0        LD (0xD040),A
CFB3  71              LD (HL),C
CFB4  79              LD A,C
CFB5  00              NOP
CFB6  FE FE           CP 0xFE
CFB8  C0              RET NZ
CFB9  47              LD B,A
CFBA  7D              LD A,L
CFBB  FE B8           CP 0xB8
CFBD  D0              RET NC
CFBE  36 EE           LD (HL),0xEE
CFC0  D7              RST 10H  ; CA80 API: param=0x80 (DISPLAY)
CFC1  80              ADD A,B
CFC2  3E 3F           LD A,0x3F
CFC4  32 FB FF        LD (0xFFFB),A
CFC7  3E 76           LD A,0x76
CFC9  32 FA FF        LD (0xFFFA),A
CFCC  3E 82           LD A,0x82
CFCE  32 F9 FF        LD (0xFFF9),A
CFD1  21 E9 FF        LD HL,0xFFE9
CFD4  36 80           LD (HL),0x80
CFD6  CD 50 CC        CALL 0xCC50
CFD9  36 80           LD (HL),0x80
CFDB  CD 50 CC        CALL 0xCC50
CFDE  36 80           LD (HL),0x80
CFE0  3E 80           LD A,0x80
CFE2  32 FD FF        LD (0xFFFD),A
CFE5  32 FC FF        LD (0xFFFC),A
CFE8  32 F9 FF        LD (0xFFF9),A
CFEB  32 F8 FF        LD (0xFFF8),A
CFEE  3E 63           LD A,0x63
CFF0  32 FE FF        LD (0xFFFE),A
CFF3  32 FB FF        LD (0xFFFB),A
CFF6  32 FA FF        LD (0xFFFA),A
CFF9  32 F7 FF        LD (0xFFF7),A
CFFC  C9              RET
CFFD  00              NOP
CFFE  00              NOP
CFFF  00              NOP
D000  00              NOP
D001  0E 22           LD C,0x22
D003  5D              LD E,L
D004  02              LD (BC),A
D005  00              NOP
D006  00              NOP
D007  00              NOP
D008  10 1A           DJNZ,0xD024
D00A  F0              RET P
D00B  7F              LD A,A
D00C  00              NOP
D00D  00              NOP
D00E  00              NOP
D00F  00              NOP
D010  00              NOP
D011  00              NOP
D012  64              LD H,H
D013  02              LD (BC),A
D014  00              NOP
D015  10 00           DJNZ,0xD017
D017  00              NOP
D018  0A              LD A,(BC)
D019  00              NOP
D01A  F6 00           OR 0x00
D01C  00              NOP
D01D  00              NOP
D01E  00              NOP
D01F  00              NOP
D020  3C              INC A
D021  00              NOP
D022  00              NOP
D023  46              LD B,(HL)
D024  00              NOP
D025  00              NOP
D026  00              NOP
D027  00              NOP
D028  08              EX AF,AF'
D029  00              NOP
D02A  08              EX AF,AF'
D02B  00              NOP
D02C  00              NOP
D02D  00              NOP
D02E  00              NOP
D02F  00              NOP
D030  00              NOP
D031  00              NOP
D032  00              NOP
D033  00              NOP
D034  00              NOP
D035  00              NOP
D036  00              NOP
D037  00              NOP
D038  00              NOP
D039  00              NOP
D03A  00              NOP
D03B  00              NOP
D03C  00              NOP
D03D  00              NOP
D03E  00              NOP
D03F  00              NOP
D040  00              NOP
D041  00              NOP
D042  00              NOP
D043  00              NOP
D044  99              SBC A,C
D045  D2 00 00        JP NC,0x0000
D048  00              NOP
D049  00              NOP
D04A  00              NOP
D04B  00              NOP
D04C  00              NOP
D04D  00              NOP
D04E  00              NOP
D04F  00              NOP
D050  00              NOP
D051  00              NOP
D052  00              NOP
D053  00              NOP
D054  00              NOP
D055  00              NOP
D056  00              NOP
D057  00              NOP
D058  00              NOP
D059  00              NOP
D05A  00              NOP
D05B  00              NOP
D05C  00              NOP
D05D  00              NOP
D05E  0B              DEC BC
D05F  00              NOP
D060  0A              LD A,(BC)
D061  06 07           LD B,0x07
D063  7F              LD A,A
D064  14              INC D
D065  07              RLCA
D066  06 0A           LD B,0x0A
D068  80              ADD A,B
D069  80              ADD A,B
D06A  02              LD (BC),A
D06B  02              LD (BC),A
D06C  02              LD (BC),A
D06D  02              LD (BC),A
D06E  02              LD (BC),A
D06F  02              LD (BC),A
D070  02              LD (BC),A
D071  02              LD (BC),A
D072  80              ADD A,B
D073  80              ADD A,B
D074  00              NOP
D075  00              NOP
D076  00              NOP
D077  00              NOP
D078  00              NOP
D079  00              NOP
D07A  00              NOP
D07B  00              NOP
D07C  80              ADD A,B
D07D  80              ADD A,B
D07E  00              NOP
D07F  00              NOP
D080  00              NOP
D081  00              NOP
D082  00              NOP
D083  00              NOP
D084  00              NOP
D085  00              NOP
D086  80              ADD A,B
D087  80              ADD A,B
D088  00              NOP
D089  00              NOP
D08A  00              NOP
D08B  00              NOP
D08C  00              NOP
D08D  00              NOP
D08E  00              NOP
D08F  00              NOP
D090  80              ADD A,B
D091  80              ADD A,B
D092  00              NOP
D093  00              NOP
D094  00              NOP
D095  00              NOP
D096  00              NOP
D097  00              NOP
D098  00              NOP
D099  00              NOP
D09A  80              ADD A,B
D09B  80              ADD A,B
D09C  FE FE           CP 0xFE
D09E  FE FE           CP 0xFE
D0A0  FE FE           CP 0xFE
D0A2  FE FE           CP 0xFE
D0A4  80              ADD A,B
D0A5  80              ADD A,B
D0A6  F6 FA           OR 0xFA
D0A8  F9              LD SP,HL
D0A9  E2 EE F9        JP PO,0xF9EE
D0AC  FA F6 00        JP M,0x00F6
D0AF  00              NOP
D0B0  0A              LD A,(BC)
D0B1  06 07           LD B,0x07
D0B3  7F              LD A,A
D0B4  14              INC D
D0B5  07              RLCA
D0B6  06 0A           LD B,0x0A
D0B8  80              ADD A,B
D0B9  80              ADD A,B
D0BA  02              LD (BC),A
D0BB  02              LD (BC),A
D0BC  02              LD (BC),A
D0BD  02              LD (BC),A
D0BE  02              LD (BC),A
D0BF  02              LD (BC),A
D0C0  02              LD (BC),A
D0C1  02              LD (BC),A
D0C2  80              ADD A,B
D0C3  80              ADD A,B
D0C4  00              NOP
D0C5  00              NOP
D0C6  00              NOP
D0C7  00              NOP
D0C8  00              NOP
D0C9  00              NOP
D0CA  00              NOP
D0CB  00              NOP
D0CC  80              ADD A,B
D0CD  80              ADD A,B
D0CE  00              NOP
D0CF  00              NOP
D0D0  00              NOP
D0D1  00              NOP
D0D2  00              NOP
D0D3  00              NOP
D0D4  00              NOP
D0D5  00              NOP
D0D6  80              ADD A,B
D0D7  80              ADD A,B
D0D8  00              NOP
D0D9  00              NOP
D0DA  00              NOP
D0DB  00              NOP
D0DC  00              NOP
D0DD  00              NOP
D0DE  00              NOP
D0DF  00              NOP
D0E0  80              ADD A,B
D0E1  80              ADD A,B
D0E2  00              NOP
D0E3  00              NOP
D0E4  00              NOP
D0E5  00              NOP
D0E6  00              NOP
D0E7  00              NOP
D0E8  00              NOP
D0E9  00              NOP
D0EA  80              ADD A,B
D0EB  80              ADD A,B
D0EC  FE FE           CP 0xFE
D0EE  FE FE           CP 0xFE
D0F0  FE FE           CP 0xFE
D0F2  FE FE           CP 0xFE
D0F4  80              ADD A,B
D0F5  80              ADD A,B
D0F6  F6 FA           OR 0xFA
D0F8  F9              LD SP,HL
D0F9  E2 EE F9        JP PO,0xF9EE
D0FC  FA F6 00        JP M,0x00F6
D0FF  00              NOP
D100  0A              LD A,(BC)
D101  06 07           LD B,0x07
D103  7F              LD A,A
D104  14              INC D
D105  07              RLCA
D106  06 0A           LD B,0x0A
D108  80              ADD A,B
D109  80              ADD A,B
D10A  02              LD (BC),A
D10B  02              LD (BC),A
D10C  02              LD (BC),A
D10D  02              LD (BC),A
D10E  02              LD (BC),A
D10F  02              LD (BC),A
D110  00              NOP
D111  02              LD (BC),A
D112  80              ADD A,B
D113  80              ADD A,B
D114  00              NOP
D115  00              NOP
D116  00              NOP
D117  00              NOP
D118  00              NOP
D119  00              NOP
D11A  02              LD (BC),A
D11B  00              NOP
D11C  80              ADD A,B
D11D  80              ADD A,B
D11E  00              NOP
D11F  00              NOP
D120  00              NOP
D121  00              NOP
D122  00              NOP
D123  00              NOP
D124  00              NOP
D125  00              NOP
D126  80              ADD A,B
D127  80              ADD A,B
D128  00              NOP
D129  00              NOP
D12A  00              NOP
D12B  00              NOP
D12C  00              NOP
D12D  00              NOP
D12E  00              NOP
D12F  00              NOP
D130  80              ADD A,B
D131  80              ADD A,B
D132  00              NOP
D133  00              NOP
D134  00              NOP
D135  00              NOP
D136  00              NOP
D137  00              NOP
D138  00              NOP
D139  00              NOP
D13A  80              ADD A,B
D13B  80              ADD A,B
D13C  FE FE           CP 0xFE
D13E  FE FE           CP 0xFE
D140  FE FE           CP 0xFE
D142  FE FE           CP 0xFE
D144  80              ADD A,B
D145  80              ADD A,B
D146  F6 FA           OR 0xFA
D148  F9              LD SP,HL
D149  E2 EE F9        JP PO,0xF9EE
D14C  FA F6 00        JP M,0x00F6
D14F  00              NOP
D150  0A              LD A,(BC)
D151  06 07           LD B,0x07
D153  7F              LD A,A
D154  14              INC D
D155  07              RLCA
D156  06 0A           LD B,0x0A
D158  80              ADD A,B
D159  80              ADD A,B
D15A  02              LD (BC),A
D15B  02              LD (BC),A
D15C  02              LD (BC),A
D15D  02              LD (BC),A
D15E  02              LD (BC),A
D15F  02              LD (BC),A
D160  00              NOP
D161  02              LD (BC),A
D162  80              ADD A,B
D163  80              ADD A,B
D164  00              NOP
D165  00              NOP
D166  00              NOP
D167  00              NOP
D168  00              NOP
D169  00              NOP
D16A  02              LD (BC),A
D16B  00              NOP
D16C  80              ADD A,B
D16D  80              ADD A,B
D16E  00              NOP
D16F  00              NOP
D170  00              NOP
D171  00              NOP
D172  00              NOP
D173  00              NOP
D174  00              NOP
D175  00              NOP
D176  80              ADD A,B
D177  80              ADD A,B
D178  00              NOP
D179  00              NOP
D17A  00              NOP
D17B  00              NOP
D17C  00              NOP
D17D  00              NOP
D17E  00              NOP
D17F  00              NOP
D180  80              ADD A,B
D181  80              ADD A,B
D182  FE 00           CP 0x00
D184  00              NOP
D185  00              NOP
D186  00              NOP
D187  00              NOP
D188  00              NOP
D189  00              NOP
D18A  80              ADD A,B
D18B  80              ADD A,B
D18C  00              NOP
D18D  FE FE           CP 0xFE
D18F  FE FE           CP 0xFE
D191  FE FE           CP 0xFE
D193  FE 80           CP 0x80
D195  80              ADD A,B
D196  F6 FA           OR 0xFA
D198  F9              LD SP,HL
D199  E2 EE F9        JP PO,0xF9EE
D19C  FA F6 00        JP M,0x00F6
D19F  00              NOP
D1A0  0A              LD A,(BC)
D1A1  06 07           LD B,0x07
D1A3  7F              LD A,A
D1A4  14              INC D
D1A5  07              RLCA
D1A6  06 0A           LD B,0x0A
D1A8  80              ADD A,B
D1A9  80              ADD A,B
D1AA  02              LD (BC),A
D1AB  02              LD (BC),A
D1AC  02              LD (BC),A
D1AD  00              NOP
D1AE  02              LD (BC),A
D1AF  02              LD (BC),A
D1B0  02              LD (BC),A
D1B1  02              LD (BC),A
D1B2  80              ADD A,B
D1B3  80              ADD A,B
D1B4  00              NOP
D1B5  00              NOP
D1B6  00              NOP
D1B7  00              NOP
D1B8  00              NOP
D1B9  00              NOP
D1BA  00              NOP
D1BB  00              NOP
D1BC  80              ADD A,B
D1BD  80              ADD A,B
D1BE  00              NOP
D1BF  00              NOP
D1C0  00              NOP
D1C1  00              NOP
D1C2  00              NOP
D1C3  00              NOP
D1C4  00              NOP
D1C5  00              NOP
D1C6  80              ADD A,B
D1C7  80              ADD A,B
D1C8  00              NOP
D1C9  00              NOP
D1CA  00              NOP
D1CB  02              LD (BC),A
D1CC  00              NOP
D1CD  00              NOP
D1CE  00              NOP
D1CF  00              NOP
D1D0  80              ADD A,B
D1D1  80              ADD A,B
D1D2  FE 00           CP 0x00
D1D4  00              NOP
D1D5  00              NOP
D1D6  00              NOP
D1D7  00              NOP
D1D8  00              NOP
D1D9  00              NOP
D1DA  80              ADD A,B
D1DB  80              ADD A,B
D1DC  00              NOP
D1DD  FE FE           CP 0xFE
D1DF  FE FE           CP 0xFE
D1E1  FE FE           CP 0xFE
D1E3  FE 80           CP 0x80
D1E5  80              ADD A,B
D1E6  F6 FA           OR 0xFA
D1E8  F9              LD SP,HL
D1E9  E2 EE F9        JP PO,0xF9EE
D1EC  FA F6 00        JP M,0x00F6
D1EF  00              NOP
D1F0  00              NOP
D1F1  00              NOP
D1F2  00              NOP
D1F3  00              NOP
D1F4  00              NOP
D1F5  00              NOP
D1F6  00              NOP
D1F7  00              NOP
D1F8  00              NOP
D1F9  00              NOP
D1FA  00              NOP
D1FB  00              NOP
D1FC  00              NOP
D1FD  00              NOP
D1FE  00              NOP
D1FF  00              NOP
D200  00              NOP
D201  00              NOP
D202  00              NOP
D203  00              NOP
D204  00              NOP
D205  00              NOP
D206  00              NOP
D207  00              NOP
D208  00              NOP
D209  00              NOP
D20A  00              NOP
D20B  00              NOP
D20C  00              NOP
D20D  00              NOP
D20E  00              NOP
D20F  00              NOP
D210  00              NOP
D211  00              NOP
D212  00              NOP
D213  00              NOP
D214  00              NOP
D215  00              NOP
D216  00              NOP
D217  00              NOP
D218  00              NOP
D219  00              NOP
D21A  00              NOP
D21B  00              NOP
D21C  00              NOP
D21D  00              NOP
D21E  00              NOP
D21F  00              NOP
D220  00              NOP
D221  00              NOP
D222  00              NOP
D223  00              NOP
D224  00              NOP
D225  00              NOP
D226  00              NOP
D227  00              NOP
D228  00              NOP
D229  00              NOP
D22A  00              NOP
D22B  00              NOP
D22C  00              NOP
D22D  00              NOP
D22E  00              NOP
D22F  00              NOP
D230  00              NOP
D231  00              NOP
D232  00              NOP
D233  00              NOP
D234  00              NOP
D235  00              NOP
D236  00              NOP
D237  00              NOP
D238  00              NOP
D239  00              NOP
D23A  00              NOP
D23B  00              NOP
D23C  00              NOP
D23D  00              NOP
D23E  00              NOP
D23F  00              NOP
D240  00              NOP
D241  00              NOP
D242  00              NOP
D243  00              NOP
D244  00              NOP
D245  00              NOP
D246  00              NOP
D247  00              NOP
D248  00              NOP
D249  00              NOP
D24A  00              NOP
D24B  00              NOP
D24C  00              NOP
D24D  00              NOP
D24E  00              NOP
D24F  00              NOP
D250  01 01 03        LD BC,0x0301
D253  04              INC B
D254  04              INC B
D255  03              INC BC
D256  01 01 00        LD BC,0x0001
D259  00              NOP
D25A  03              INC BC
D25B  03              INC BC
D25C  04              INC B
D25D  05              DEC B
D25E  05              DEC B
D25F  04              INC B
D260  03              INC BC
D261  03              INC BC
D262  00              NOP
D263  00              NOP
D264  05              DEC B
D265  06 06           LD B,0x06
D267  07              RLCA
D268  07              RLCA
D269  06 06           LD B,0x06
D26B  05              DEC B
D26C  00              NOP
D26D  00              NOP
D26E  06 06           LD B,0x06
D270  08              EX AF,AF'
D271  0C              INC C
D272  0C              INC C
D273  08              EX AF,AF'
D274  06 06           LD B,0x06
D276  00              NOP
D277  00              NOP
D278  08              EX AF,AF'
D279  0C              INC C
D27A  0F              RRCA
D27B  10 10           DJNZ,0xD28D
D27D  10 0F           DJNZ,0xD28E
D27F  08              EX AF,AF'
D280  00              NOP
D281  00              NOP
D282  0A              LD A,(BC)
D283  0E 12           LD C,0x12
D285  14              INC D
D286  14              INC D
D287  12              LD (DE),A
D288  0E 0A           LD C,0x0A
D28A  00              NOP
D28B  00              NOP
D28C  0C              INC C
D28D  10 22           DJNZ,0xD2B1
D28F  24              INC H
D290  24              INC H
D291  12              LD (DE),A
D292  10 0C           DJNZ,0xD2A0
D294  00              NOP
D295  00              NOP
D296  0E 12           LD C,0x12
D298  22 12 22        LD (0x2212),HL
D29B  12              LD (DE),A
D29C  12              LD (DE),A
D29D  0E 00           LD C,0x00
D29F  00              NOP
D2A0  00              NOP
D2A1  00              NOP
D2A2  00              NOP
D2A3  00              NOP
D2A4  00              NOP
D2A5  00              NOP
D2A6  00              NOP
D2A7  00              NOP
D2A8  00              NOP
D2A9  00              NOP
D2AA  01 01 01        LD BC,0x0101
D2AD  01 01 01        LD BC,0x0101
D2B0  01 01 00        LD BC,0x0001
D2B3  00              NOP
D2B4  03              INC BC
D2B5  03              INC BC
D2B6  03              INC BC
D2B7  03              INC BC
D2B8  03              INC BC
D2B9  03              INC BC
D2BA  03              INC BC
D2BB  03              INC BC
D2BC  00              NOP
D2BD  00              NOP
D2BE  05              DEC B
D2BF  05              DEC B
D2C0  05              DEC B
D2C1  07              RLCA
D2C2  07              RLCA
D2C3  05              DEC B
D2C4  05              DEC B
D2C5  05              DEC B
D2C6  00              NOP
D2C7  00              NOP
D2C8  07              RLCA
D2C9  07              RLCA
D2CA  07              RLCA
D2CB  09              ADD HL,BC
D2CC  09              ADD HL,BC
D2CD  07              RLCA
D2CE  07              RLCA
D2CF  07              RLCA
D2D0  00              NOP
D2D1  00              NOP
D2D2  0B              DEC BC
D2D3  0B              DEC BC
D2D4  0B              DEC BC
D2D5  0D              DEC C
D2D6  0D              DEC C
D2D7  0B              DEC BC
D2D8  0B              DEC BC
D2D9  0B              DEC BC
D2DA  00              NOP
D2DB  00              NOP
D2DC  17              RLA
D2DD  17              RLA
D2DE  17              RLA
D2DF  17              RLA
D2E0  17              RLA
D2E1  17              RLA
D2E2  17              RLA
D2E3  17              RLA
D2E4  00              NOP
D2E5  00              NOP
D2E6  48              LD C,B
D2E7  48              LD C,B
D2E8  48              LD C,B
D2E9  48              LD C,B
D2EA  48              LD C,B
D2EB  48              LD C,B
D2EC  48              LD C,B
D2ED  48              LD C,B
D2EE  00              NOP
D2EF  00              NOP
D2F0  00              NOP
D2F1  00              NOP
D2F2  00              NOP
D2F3  00              NOP
D2F4  00              NOP
D2F5  00              NOP
D2F6  00              NOP
D2F7  00              NOP
D2F8  00              NOP
D2F9  00              NOP
D2FA  00              NOP
D2FB  00              NOP
D2FC  00              NOP
D2FD  00              NOP
D2FE  00              NOP
D2FF  00              NOP
D300  88              ADC A,B
D301  18 F8           JR,0xD2FB
D303  E8              RET PE
D304  D8              RET C
D305  C8              RET Z
D306  B8              CP,B
D307  A8              XOR,B
D308  00              NOP
D309  00              NOP
D30A  87              ADD A,A
D30B  17              RLA
D30C  F7              RST 30H
D30D  E7              RST 20H
D30E  D7              RST 10H  ; CA80 API: param=0xC7 (func_C7)
D30F  C7              RST 00H
D310  B7              OR,A
D311  A7              AND,A
D312  00              NOP
D313  00              NOP
D314  86              ADD A,(HL)
D315  16 F6           LD D,0xF6
D317  E6 D6           AND 0xD6
D319  C6 B6           ADD A,0xB6
D31B  A6              AND,(HL)
D31C  00              NOP
D31D  00              NOP
D31E  85              ADD A,L
D31F  15              DEC D
D320  F5              PUSH AF
D321  E5              PUSH HL
D322  D5              PUSH DE
D323  C5              PUSH BC
D324  B5              OR,L
D325  A5              AND,L
D326  00              NOP
D327  00              NOP
D328  84              ADD A,H
D329  14              INC D
D32A  F4 E4 D4        CALL P,0xD4E4
D32D  C4 B4 A4        CALL NZ,0xA4B4
D330  00              NOP
D331  00              NOP
D332  83              ADD A,E
D333  13              INC DE
D334  F3              DI
D335  E3              EX (SP),HL
D336  D3 C3           OUT (0xC3),A
D338  B3              OR,E
D339  A3              AND,E
D33A  00              NOP
D33B  00              NOP
D33C  82              ADD A,D
D33D  12              LD (DE),A
D33E  F2 E2 D2        JP P,0xD2E2
D341  C2 B2 A2        JP NZ,0xA2B2
D344  00              NOP
D345  00              NOP
D346  81              ADD A,C
D347  11 F1 E1        LD DE,0xE1F1
D34A  D1              POP DE
D34B  C1              POP BC
D34C  B1              OR,C
D34D  A1              AND,C
D34E  00              NOP
D34F  00              NOP
D350  F2 EE EE        JP P,0xEEEE
D353  EC EC EE        CALL PE,0xEEEC
D356  EE F2           XOR 0xF2
D358  00              NOP
D359  00              NOP
D35A  F4 F0 EC        CALL P,0xECF0
D35D  EA EA EC        JP PE,0xECEA
D360  F0              RET P
D361  F4 00 00        CALL P,0x0000
D364  F6 F2           OR 0xF2
D366  EE EA           XOR 0xEA
D368  EA EE F2        JP PE,0xF2EE
D36B  F6 00           OR 0x00
D36D  00              NOP
D36E  F8              RET M
D36F  F4 F0 EE        CALL P,0xEEF0
D372  EE F0           XOR 0xF0
D374  F4 F8 00        CALL P,0x00F8
D377  00              NOP
D378  FA FA F8        JP M,0xF8FA
D37B  F4 F4 F8        CALL P,0xF8F4
D37E  FA FA 00        JP M,0x00FA
D381  00              NOP
D382  FB              EI
D383  FA FA F9        JP M,0xF9FA
D386  F9              LD SP,HL
D387  FA FA FB        JP M,0xFBFA
D38A  00              NOP
D38B  00              NOP
D38C  FD FD           DB 0xFD
D38E  FD FD           DB 0xFD
D390  FD FD           DB 0xFD
D392  FD FD           DB 0xFD
D394  00              NOP
D395  00              NOP
D396  FF              RST 38H
D397  FF              RST 38H
D398  FF              RST 38H
D399  FF              RST 38H
D39A  FF              RST 38H
D39B  FF              RST 38H
D39C  FF              RST 38H
D39D  FF              RST 38H
D39E  00              NOP
D39F  00              NOP
D3A0  B8              CP,B
D3A1  B8              CP,B
D3A2  B8              CP,B
D3A3  B8              CP,B
D3A4  B8              CP,B
D3A5  B8              CP,B
D3A6  B8              CP,B
D3A7  B8              CP,B
D3A8  00              NOP
D3A9  00              NOP
D3AA  E9              JP (HL)
D3AB  E9              JP (HL)
D3AC  E9              JP (HL)
D3AD  E9              JP (HL)
D3AE  E9              JP (HL)
D3AF  E9              JP (HL)
D3B0  E9              JP (HL)
D3B1  E9              JP (HL)
D3B2  00              NOP
D3B3  00              NOP
D3B4  F7              RST 30H
D3B5  F7              RST 30H
D3B6  F7              RST 30H
D3B7  F7              RST 30H
D3B8  F7              RST 30H
D3B9  F7              RST 30H
D3BA  F7              RST 30H
D3BB  F7              RST 30H
D3BC  00              NOP
D3BD  00              NOP
D3BE  F9              LD SP,HL
D3BF  F9              LD SP,HL
D3C0  F9              LD SP,HL
D3C1  F9              LD SP,HL
D3C2  F9              LD SP,HL
D3C3  F9              LD SP,HL
D3C4  F9              LD SP,HL
D3C5  F9              LD SP,HL
D3C6  00              NOP
D3C7  00              NOP
D3C8  FB              EI
D3C9  FB              EI
D3CA  FB              EI
D3CB  FB              EI
D3CC  FB              EI
D3CD  FB              EI
D3CE  FB              EI
D3CF  FB              EI
D3D0  00              NOP
D3D1  00              NOP
D3D2  FD FD           DB 0xFD
D3D4  FD FD           DB 0xFD
D3D6  FD FD           DB 0xFD
D3D8  FD FD           DB 0xFD
D3DA  00              NOP
D3DB  00              NOP
D3DC  FF              RST 38H
D3DD  FF              RST 38H
D3DE  FF              RST 38H
D3DF  FF              RST 38H
D3E0  FF              RST 38H
D3E1  FF              RST 38H
D3E2  FF              RST 38H
D3E3  FF              RST 38H
D3E4  00              NOP
D3E5  00              NOP
D3E6  00              NOP
D3E7  00              NOP
D3E8  00              NOP
D3E9  00              NOP
D3EA  00              NOP
D3EB  00              NOP
D3EC  00              NOP
D3ED  00              NOP
D3EE  00              NOP
D3EF  00              NOP
D3F0  00              NOP
D3F1  00              NOP
D3F2  00              NOP
D3F3  00              NOP
D3F4  00              NOP
D3F5  00              NOP
D3F6  00              NOP
D3F7  00              NOP
D3F8  00              NOP
D3F9  00              NOP
D3FA  00              NOP
D3FB  00              NOP
D3FC  00              NOP
D3FD  00              NOP
D3FE  00              NOP
D3FF  00              NOP
D400  88              ADC A,B
D401  18 F8           JR,0xD3FB
D403  E8              RET PE
D404  D8              RET C
D405  C8              RET Z
D406  B8              CP,B
D407  A8              XOR,B
D408  00              NOP
D409  00              NOP
D40A  87              ADD A,A
D40B  17              RLA
D40C  F7              RST 30H
D40D  E7              RST 20H
D40E  D7              RST 10H  ; CA80 API: param=0xC7 (func_C7)
D40F  C7              RST 00H
D410  B7              OR,A
D411  A7              AND,A
D412  00              NOP
D413  00              NOP
D414  86              ADD A,(HL)
D415  16 F6           LD D,0xF6
D417  E6 D6           AND 0xD6
D419  C6 B6           ADD A,0xB6
D41B  A6              AND,(HL)
D41C  00              NOP
D41D  00              NOP
D41E  85              ADD A,L
D41F  15              DEC D
D420  F5              PUSH AF
D421  E5              PUSH HL
D422  D5              PUSH DE
D423  C5              PUSH BC
D424  B5              OR,L
D425  A5              AND,L
D426  00              NOP
D427  00              NOP
D428  84              ADD A,H
D429  14              INC D
D42A  F4 E4 D4        CALL P,0xD4E4
D42D  C4 B4 A4        CALL NZ,0xA4B4
D430  00              NOP
D431  00              NOP
D432  83              ADD A,E
D433  13              INC DE
D434  F3              DI
D435  E3              EX (SP),HL
D436  D3 C3           OUT (0xC3),A
D438  B3              OR,E
D439  A3              AND,E
D43A  00              NOP
D43B  00              NOP
D43C  82              ADD A,D
D43D  12              LD (DE),A
D43E  F2 E2 D2        JP P,0xD2E2
D441  C2 B2 A2        JP NZ,0xA2B2
D444  00              NOP
D445  00              NOP
D446  81              ADD A,C
D447  11 F1 E1        LD DE,0xE1F1
D44A  D1              POP DE
D44B  C1              POP BC
D44C  B1              OR,C
D44D  A1              AND,C
D44E  00              NOP
D44F  00              NOP
D450  01 01 03        LD BC,0x0301
D453  04              INC B
D454  04              INC B
D455  03              INC BC
D456  01 01 00        LD BC,0x0001
D459  00              NOP
D45A  03              INC BC
D45B  03              INC BC
D45C  04              INC B
D45D  05              DEC B
D45E  05              DEC B
D45F  04              INC B
D460  03              INC BC
D461  03              INC BC
D462  00              NOP
D463  00              NOP
D464  05              DEC B
D465  06 06           LD B,0x06
D467  07              RLCA
D468  07              RLCA
D469  06 06           LD B,0x06
D46B  05              DEC B
D46C  00              NOP
D46D  00              NOP
D46E  06 06           LD B,0x06
D470  08              EX AF,AF'
D471  0C              INC C
D472  0C              INC C
D473  08              EX AF,AF'
D474  06 06           LD B,0x06
D476  00              NOP
D477  00              NOP
D478  08              EX AF,AF'
D479  0C              INC C
D47A  0F              RRCA
D47B  10 10           DJNZ,0xD48D
D47D  10 0F           DJNZ,0xD48E
D47F  08              EX AF,AF'
D480  00              NOP
D481  00              NOP
D482  0A              LD A,(BC)
D483  0E 12           LD C,0x12
D485  14              INC D
D486  14              INC D
D487  12              LD (DE),A
D488  0E 0A           LD C,0x0A
D48A  00              NOP
D48B  00              NOP
D48C  0C              INC C
D48D  10 12           DJNZ,0xD4A1
D48F  14              INC D
D490  14              INC D
D491  12              LD (DE),A
D492  10 0C           DJNZ,0xD4A0
D494  00              NOP
D495  00              NOP
D496  0E 12           LD C,0x12
D498  12              LD (DE),A
D499  12              LD (DE),A
D49A  12              LD (DE),A
D49B  12              LD (DE),A
D49C  12              LD (DE),A
D49D  0E 00           LD C,0x00
D49F  00              NOP
D4A0  00              NOP
D4A1  00              NOP
D4A2  00              NOP
D4A3  00              NOP
D4A4  00              NOP
D4A5  00              NOP
D4A6  00              NOP
D4A7  00              NOP
D4A8  00              NOP
D4A9  00              NOP
D4AA  00              NOP
D4AB  00              NOP
D4AC  00              NOP
D4AD  00              NOP
D4AE  00              NOP
D4AF  00              NOP
D4B0  00              NOP
D4B1  00              NOP
D4B2  00              NOP
D4B3  00              NOP
D4B4  00              NOP
D4B5  00              NOP
D4B6  00              NOP
D4B7  00              NOP
D4B8  00              NOP
D4B9  00              NOP
D4BA  00              NOP
D4BB  00              NOP
D4BC  00              NOP
D4BD  00              NOP
D4BE  00              NOP
D4BF  00              NOP
D4C0  00              NOP
D4C1  00              NOP
D4C2  00              NOP
D4C3  00              NOP
D4C4  00              NOP
D4C5  00              NOP
D4C6  00              NOP
D4C7  00              NOP
D4C8  00              NOP
D4C9  00              NOP
D4CA  00              NOP
D4CB  00              NOP
D4CC  00              NOP
D4CD  00              NOP
D4CE  00              NOP
D4CF  00              NOP
D4D0  00              NOP
D4D1  00              NOP
D4D2  00              NOP
D4D3  00              NOP
D4D4  00              NOP
D4D5  00              NOP
D4D6  00              NOP
D4D7  00              NOP
D4D8  00              NOP
D4D9  00              NOP
D4DA  00              NOP
D4DB  00              NOP
D4DC  00              NOP
D4DD  00              NOP
D4DE  00              NOP
D4DF  00              NOP
D4E0  00              NOP
D4E1  00              NOP
D4E2  00              NOP
D4E3  00              NOP
D4E4  00              NOP
D4E5  00              NOP
D4E6  00              NOP
D4E7  00              NOP
D4E8  00              NOP
D4E9  00              NOP
D4EA  00              NOP
D4EB  00              NOP
D4EC  00              NOP
D4ED  00              NOP
D4EE  00              NOP
D4EF  00              NOP
D4F0  00              NOP
D4F1  00              NOP
D4F2  00              NOP
D4F3  00              NOP
D4F4  00              NOP
D4F5  00              NOP
D4F6  00              NOP
D4F7  00              NOP
D4F8  00              NOP
D4F9  00              NOP
D4FA  00              NOP
D4FB  00              NOP
D4FC  00              NOP
D4FD  00              NOP
D4FE  00              NOP
D4FF  00              NOP
D500  F5              PUSH AF
D501  3E 0A           LD A,0x0A
D503  32 48 D0        LD (0xD048),A
D506  CD 00 CD        CALL 0xCD00
D509  38 1A           JR C,0xD525
D50B  FE 80           CP 0x80
D50D  28 16           JR Z,0xD525
D50F  30 11           JR NC,0xD522
D511  FE 01           CP 0x01
D513  30 10           JR NC,0xD525
D515  CD 20 CD        CALL 0xCD20
D518  3A 48 D0        LD A,(0xD048)
D51B  C6 0A           ADD A,0x0A
D51D  32 48 D0        LD (0xD048),A
D520  18 E4           JR,0xD506
D522  CD 20 CD        CALL 0xCD20
D525  3E F6           LD A,0xF6
D527  32 48 D0        LD (0xD048),A
D52A  00              NOP
D52B  00              NOP
D52C  00              NOP
D52D  00              NOP
D52E  00              NOP
D52F  00              NOP
D530  CD 00 CD        CALL 0xCD00
D533  38 1A           JR C,0xD54F
D535  FE 80           CP 0x80
D537  28 16           JR Z,0xD54F
D539  30 11           JR NC,0xD54C
D53B  FE 01           CP 0x01
D53D  30 10           JR NC,0xD54F
D53F  CD 20 CD        CALL 0xCD20
D542  3A 48 D0        LD A,(0xD048)
D545  C6 F6           ADD A,0xF6
D547  32 48 D0        LD (0xD048),A
D54A  18 E4           JR,0xD530
D54C  CD 20 CD        CALL 0xCD20
D54F  3E 01           LD A,0x01
D551  32 48 D0        LD (0xD048),A
D554  00              NOP
D555  00              NOP
D556  00              NOP
D557  CD 00 CD        CALL 0xCD00
D55A  38 1A           JR C,0xD576
D55C  FE 80           CP 0x80
D55E  28 16           JR Z,0xD576
D560  30 11           JR NC,0xD573
D562  FE 01           CP 0x01
D564  30 10           JR NC,0xD576
D566  CD 20 CD        CALL 0xCD20
D569  3A 48 D0        LD A,(0xD048)
D56C  C6 01           ADD A,0x01
D56E  32 48 D0        LD (0xD048),A
D571  18 E4           JR,0xD557
D573  CD 20 CD        CALL 0xCD20
D576  3E FF           LD A,0xFF
D578  32 48 D0        LD (0xD048),A
D57B  00              NOP
D57C  00              NOP
D57D  00              NOP
D57E  00              NOP
D57F  00              NOP
D580  00              NOP
D581  CD 00 CD        CALL 0xCD00
D584  38 1A           JR C,0xD5A0
D586  FE 80           CP 0x80
D588  28 16           JR Z,0xD5A0
D58A  30 11           JR NC,0xD59D
D58C  FE 01           CP 0x01
D58E  30 10           JR NC,0xD5A0
D590  CD 20 CD        CALL 0xCD20
D593  3A 48 D0        LD A,(0xD048)
D596  C6 FF           ADD A,0xFF
D598  32 48 D0        LD (0xD048),A
D59B  18 E4           JR,0xD581
D59D  CD 20 CD        CALL 0xCD20
D5A0  3E 0B           LD A,0x0B
D5A2  32 48 D0        LD (0xD048),A
D5A5  00              NOP
D5A6  00              NOP
D5A7  00              NOP
D5A8  CD 00 CD        CALL 0xCD00
D5AB  38 1A           JR C,0xD5C7
D5AD  FE 80           CP 0x80
D5AF  28 16           JR Z,0xD5C7
D5B1  30 11           JR NC,0xD5C4
D5B3  FE 01           CP 0x01
D5B5  30 10           JR NC,0xD5C7
D5B7  CD 20 CD        CALL 0xCD20
D5BA  3A 48 D0        LD A,(0xD048)
D5BD  C6 0B           ADD A,0x0B
D5BF  32 48 D0        LD (0xD048),A
D5C2  18 E4           JR,0xD5A8
D5C4  CD 20 CD        CALL 0xCD20
D5C7  3E F5           LD A,0xF5
D5C9  32 48 D0        LD (0xD048),A
D5CC  00              NOP
D5CD  00              NOP
D5CE  00              NOP
D5CF  00              NOP
D5D0  00              NOP
D5D1  00              NOP
D5D2  CD 00 CD        CALL 0xCD00
D5D5  38 1A           JR C,0xD5F1
D5D7  FE 80           CP 0x80
D5D9  28 16           JR Z,0xD5F1
D5DB  30 11           JR NC,0xD5EE
D5DD  FE 01           CP 0x01
D5DF  30 10           JR NC,0xD5F1
D5E1  CD 20 CD        CALL 0xCD20
D5E4  3A 48 D0        LD A,(0xD048)
D5E7  C6 F5           ADD A,0xF5
D5E9  32 48 D0        LD (0xD048),A
D5EC  18 E4           JR,0xD5D2
D5EE  CD 20 CD        CALL 0xCD20
D5F1  3E 09           LD A,0x09
D5F3  32 48 D0        LD (0xD048),A
D5F6  00              NOP
D5F7  00              NOP
D5F8  00              NOP
D5F9  CD 00 CD        CALL 0xCD00
D5FC  38 1A           JR C,0xD618
D5FE  FE 80           CP 0x80
D600  28 16           JR Z,0xD618
D602  30 11           JR NC,0xD615
D604  FE 01           CP 0x01
D606  30 10           JR NC,0xD618
D608  CD 20 CD        CALL 0xCD20
D60B  3A 48 D0        LD A,(0xD048)
D60E  C6 09           ADD A,0x09
D610  32 48 D0        LD (0xD048),A
D613  18 E4           JR,0xD5F9
D615  CD 20 CD        CALL 0xCD20
D618  3E F7           LD A,0xF7
D61A  32 48 D0        LD (0xD048),A
D61D  00              NOP
D61E  00              NOP
D61F  00              NOP
D620  00              NOP
D621  00              NOP
D622  00              NOP
D623  CD 00 CD        CALL 0xCD00
D626  38 1A           JR C,0xD642
D628  FE 80           CP 0x80
D62A  28 16           JR Z,0xD642
D62C  30 11           JR NC,0xD63F
D62E  FE 01           CP 0x01
D630  30 10           JR NC,0xD642
D632  CD 20 CD        CALL 0xCD20
D635  3A 48 D0        LD A,(0xD048)
D638  C6 F7           ADD A,0xF7
D63A  32 48 D0        LD (0xD048),A
D63D  18 E4           JR,0xD623
D63F  CD 20 CD        CALL 0xCD20
D642  F1              POP AF
D643  C9              RET
D644  00              NOP
D645  00              NOP
D646  00              NOP
D647  00              NOP
D648  00              NOP
D649  00              NOP
D64A  F5              PUSH AF
D64B  3E 0A           LD A,0x0A
D64D  32 48 D0        LD (0xD048),A
D650  CD 00 CD        CALL 0xCD00
D653  38 1A           JR C,0xD66F
D655  FE 80           CP 0x80
D657  28 16           JR Z,0xD66F
D659  30 11           JR NC,0xD66C
D65B  FE 01           CP 0x01
D65D  30 10           JR NC,0xD66F
D65F  CD 20 CD        CALL 0xCD20
D662  3A 48 D0        LD A,(0xD048)
D665  C6 0A           ADD A,0x0A
D667  32 48 D0        LD (0xD048),A
D66A  18 E4           JR,0xD650
D66C  CD 20 CD        CALL 0xCD20
D66F  3E F6           LD A,0xF6
D671  32 48 D0        LD (0xD048),A
D674  00              NOP
D675  00              NOP
D676  00              NOP
D677  00              NOP
D678  00              NOP
D679  00              NOP
D67A  CD 00 CD        CALL 0xCD00
D67D  38 1A           JR C,0xD699
D67F  FE 80           CP 0x80
D681  28 16           JR Z,0xD699
D683  30 11           JR NC,0xD696
D685  FE 01           CP 0x01
D687  30 10           JR NC,0xD699
D689  CD 20 CD        CALL 0xCD20
D68C  3A 48 D0        LD A,(0xD048)
D68F  C6 F6           ADD A,0xF6
D691  32 48 D0        LD (0xD048),A
D694  18 E4           JR,0xD67A
D696  CD 20 CD        CALL 0xCD20
D699  3E 01           LD A,0x01
D69B  32 48 D0        LD (0xD048),A
D69E  00              NOP
D69F  00              NOP
D6A0  00              NOP
D6A1  CD 00 CD        CALL 0xCD00
D6A4  38 1A           JR C,0xD6C0
D6A6  FE 80           CP 0x80
D6A8  28 16           JR Z,0xD6C0
D6AA  30 11           JR NC,0xD6BD
D6AC  FE 01           CP 0x01
D6AE  30 10           JR NC,0xD6C0
D6B0  CD 20 CD        CALL 0xCD20
D6B3  3A 48 D0        LD A,(0xD048)
D6B6  C6 01           ADD A,0x01
D6B8  32 48 D0        LD (0xD048),A
D6BB  18 E4           JR,0xD6A1
D6BD  CD 20 CD        CALL 0xCD20
D6C0  3E FF           LD A,0xFF
D6C2  32 48 D0        LD (0xD048),A
D6C5  00              NOP
D6C6  00              NOP
D6C7  00              NOP
D6C8  00              NOP
D6C9  00              NOP
D6CA  00              NOP
D6CB  CD 00 CD        CALL 0xCD00
D6CE  38 1A           JR C,0xD6EA
D6D0  FE 80           CP 0x80
D6D2  28 16           JR Z,0xD6EA
D6D4  30 11           JR NC,0xD6E7
D6D6  FE 01           CP 0x01
D6D8  30 10           JR NC,0xD6EA
D6DA  CD 20 CD        CALL 0xCD20
D6DD  3A 48 D0        LD A,(0xD048)
D6E0  C6 FF           ADD A,0xFF
D6E2  32 48 D0        LD (0xD048),A
D6E5  18 E4           JR,0xD6CB
D6E7  CD 20 CD        CALL 0xCD20
D6EA  F1              POP AF
D6EB  C9              RET
D6EC  00              NOP
D6ED  00              NOP
D6EE  00              NOP
D6EF  00              NOP
D6F0  F5              PUSH AF
D6F1  3E 0B           LD A,0x0B
D6F3  32 48 D0        LD (0xD048),A
D6F6  CD 00 CD        CALL 0xCD00
D6F9  38 1A           JR C,0xD715
D6FB  FE 80           CP 0x80
D6FD  28 16           JR Z,0xD715
D6FF  30 11           JR NC,0xD712
D701  FE 01           CP 0x01
D703  30 10           JR NC,0xD715
D705  CD 20 CD        CALL 0xCD20
D708  3A 48 D0        LD A,(0xD048)
D70B  C6 0B           ADD A,0x0B
D70D  32 48 D0        LD (0xD048),A
D710  18 E4           JR,0xD6F6
D712  CD 20 CD        CALL 0xCD20
D715  3E F5           LD A,0xF5
D717  32 48 D0        LD (0xD048),A
D71A  00              NOP
D71B  00              NOP
D71C  00              NOP
D71D  00              NOP
D71E  00              NOP
D71F  00              NOP
D720  CD 00 CD        CALL 0xCD00
D723  38 1A           JR C,0xD73F
D725  FE 80           CP 0x80
D727  28 16           JR Z,0xD73F
D729  30 11           JR NC,0xD73C
D72B  FE 01           CP 0x01
D72D  30 10           JR NC,0xD73F
D72F  CD 20 CD        CALL 0xCD20
D732  3A 48 D0        LD A,(0xD048)
D735  C6 F5           ADD A,0xF5
D737  32 48 D0        LD (0xD048),A
D73A  18 E4           JR,0xD720
D73C  CD 20 CD        CALL 0xCD20
D73F  3E 09           LD A,0x09
D741  32 48 D0        LD (0xD048),A
D744  00              NOP
D745  00              NOP
D746  00              NOP
D747  CD 00 CD        CALL 0xCD00
D74A  38 1A           JR C,0xD766
D74C  FE 80           CP 0x80
D74E  28 16           JR Z,0xD766
D750  30 11           JR NC,0xD763
D752  FE 01           CP 0x01
D754  30 10           JR NC,0xD766
D756  CD 20 CD        CALL 0xCD20
D759  3A 48 D0        LD A,(0xD048)
D75C  C6 09           ADD A,0x09
D75E  32 48 D0        LD (0xD048),A
D761  18 E4           JR,0xD747
D763  CD 20 CD        CALL 0xCD20
D766  3E F7           LD A,0xF7
D768  32 48 D0        LD (0xD048),A
D76B  00              NOP
D76C  00              NOP
D76D  00              NOP
D76E  00              NOP
D76F  00              NOP
D770  00              NOP
D771  CD 00 CD        CALL 0xCD00
D774  38 1A           JR C,0xD790
D776  FE 80           CP 0x80
D778  28 16           JR Z,0xD790
D77A  30 11           JR NC,0xD78D
D77C  FE 01           CP 0x01
D77E  30 10           JR NC,0xD790
D780  CD 20 CD        CALL 0xCD20
D783  3A 48 D0        LD A,(0xD048)
D786  C6 F7           ADD A,0xF7
D788  32 48 D0        LD (0xD048),A
D78B  18 E4           JR,0xD771
D78D  CD 20 CD        CALL 0xCD20
D790  F1              POP AF
D791  C9              RET
D792  00              NOP
D793  00              NOP
D794  00              NOP
D795  F5              PUSH AF
D796  3E 0C           LD A,0x0C
D798  32 48 D0        LD (0xD048),A
D79B  CD 60 CD        CALL 0xCD60
D79E  3E F4           LD A,0xF4
D7A0  32 48 D0        LD (0xD048),A
D7A3  CD 60 CD        CALL 0xCD60
D7A6  3E 08           LD A,0x08
D7A8  32 48 D0        LD (0xD048),A
D7AB  CD 60 CD        CALL 0xCD60
D7AE  3E F8           LD A,0xF8
D7B0  32 48 D0        LD (0xD048),A
D7B3  CD 60 CD        CALL 0xCD60
D7B6  3E 15           LD A,0x15
D7B8  32 48 D0        LD (0xD048),A
D7BB  CD 60 CD        CALL 0xCD60
D7BE  3E EB           LD A,0xEB
D7C0  32 48 D0        LD (0xD048),A
D7C3  CD 60 CD        CALL 0xCD60
D7C6  3E 13           LD A,0x13
D7C8  32 48 D0        LD (0xD048),A
D7CB  CD 60 CD        CALL 0xCD60
D7CE  3E ED           LD A,0xED
D7D0  32 48 D0        LD (0xD048),A
D7D3  CD 60 CD        CALL 0xCD60
D7D6  F1              POP AF
D7D7  C9              RET
D7D8  00              NOP
D7D9  00              NOP
D7DA  00              NOP
D7DB  00              NOP
D7DC  00              NOP
D7DD  00              NOP
D7DE  00              NOP
D7DF  00              NOP
D7E0  F5              PUSH AF
D7E1  3E 01           LD A,0x01
D7E3  32 48 D0        LD (0xD048),A
D7E6  CD 60 CD        CALL 0xCD60
D7E9  3E 0A           LD A,0x0A
D7EB  32 48 D0        LD (0xD048),A
D7EE  CD 60 CD        CALL 0xCD60
D7F1  3E FF           LD A,0xFF
D7F3  32 48 D0        LD (0xD048),A
D7F6  CD 60 CD        CALL 0xCD60
D7F9  3E F6           LD A,0xF6
D7FB  32 48 D0        LD (0xD048),A
D7FE  CD 60 CD        CALL 0xCD60
D801  3E 0B           LD A,0x0B
D803  32 48 D0        LD (0xD048),A
D806  CD 60 CD        CALL 0xCD60
D809  3E 09           LD A,0x09
D80B  32 48 D0        LD (0xD048),A
D80E  CD 60 CD        CALL 0xCD60
D811  3E F7           LD A,0xF7
D813  32 48 D0        LD (0xD048),A
D816  CD 60 CD        CALL 0xCD60
D819  3E F5           LD A,0xF5
D81B  32 48 D0        LD (0xD048),A
D81E  CD 60 CD        CALL 0xCD60
D821  F1              POP AF
D822  C9              RET
D823  00              NOP
D824  00              NOP
D825  00              NOP
D826  00              NOP
D827  00              NOP
D828  00              NOP
D829  00              NOP
D82A  00              NOP
D82B  00              NOP
D82C  00              NOP
D82D  00              NOP
D82E  00              NOP
D82F  00              NOP
D830  F5              PUSH AF
D831  3E 09           LD A,0x09
D833  32 48 D0        LD (0xD048),A
D836  CD 00 CD        CALL 0xCD00
D839  CD 70 D8        CALL 0xD870
D83C  3E 0A           LD A,0x0A
D83E  32 48 D0        LD (0xD048),A
D841  CD 00 CD        CALL 0xCD00
D844  FE 01           CP 0x01
D846  30 1F           JR NC,0xD867
D848  CD 20 CD        CALL 0xCD20
D84B  00              NOP
D84C  00              NOP
D84D  00              NOP
D84E  3A 38 D0        LD A,(0xD038)
D851  FE 14           CP 0x14
D853  30 12           JR NC,0xD867
D855  3E 14           LD A,0x14
D857  32 48 D0        LD (0xD048),A
D85A  CD 00 CD        CALL 0xCD00
D85D  FE 01           CP 0x01
D85F  30 06           JR NC,0xD867
D861  CD 20 CD        CALL 0xCD20
D864  00              NOP
D865  00              NOP
D866  00              NOP
D867  F1              POP AF
D868  C9              RET
D869  00              NOP
D86A  00              NOP
D86B  00              NOP
D86C  00              NOP
D86D  00              NOP
D86E  00              NOP
D86F  00              NOP
D870  FE 81           CP 0x81
D872  38 06           JR C,0xD87A
D874  CD 20 CD        CALL 0xCD20
D877  00              NOP
D878  00              NOP
D879  00              NOP
D87A  3E 0B           LD A,0x0B
D87C  32 48 D0        LD (0xD048),A
D87F  CD 00 CD        CALL 0xCD00
D882  FE 81           CP 0x81
D884  D8              RET C
D885  CD 20 CD        CALL 0xCD20
D888  00              NOP
D889  00              NOP
D88A  00              NOP
D88B  C9              RET
D88C  00              NOP
D88D  00              NOP
D88E  00              NOP
D88F  00              NOP
D890  F5              PUSH AF
D891  F5              PUSH AF
D892  FE 16           CP 0x16
D894  CC 18 D9        CALL Z,0xD918
D897  F1              POP AF
D898  FE 15           CP 0x15
D89A  CC A0 D8        CALL Z,0xD8A0
D89D  F1              POP AF
D89E  C9              RET
D89F  00              NOP
D8A0  3A 00 D3        LD A,(0xD300)
D8A3  FE A1           CP 0xA1
D8A5  CA E0 D8        JP Z,0xD8E0
D8A8  21 F9 D0        LD HL,0xD0F9
D8AB  7E              LD A,(HL)
D8AC  FE E2           CP 0xE2
D8AE  C0              RET NZ
D8AF  3A F8 D0        LD A,(0xD0F8)
D8B2  FE 01           CP 0x01
D8B4  D0              RET NC
D8B5  21 F7 D0        LD HL,0xD0F7
D8B8  7E              LD A,(HL)
D8B9  FE 01           CP 0x01
D8BB  D0              RET NC
D8BC  21 F6 D0        LD HL,0xD0F6
D8BF  7E              LD A,(HL)
D8C0  FE F6           CP 0xF6
D8C2  C0              RET NZ
D8C3  3E E2           LD A,0xE2
D8C5  32 F7 D0        LD (0xD0F7),A
D8C8  3E F6           LD A,0xF6
D8CA  32 F8 D0        LD (0xD0F8),A
D8CD  3E 00           LD A,0x00
D8CF  32 F6 D0        LD (0xD0F6),A
D8D2  32 F9 D0        LD (0xD0F9),A
D8D5  31 66 FF        LD SP,0xFF66
D8D8  C3 73 C0        JP 0xC073
D8DB  00              NOP
D8DC  00              NOP
D8DD  00              NOP
D8DE  00              NOP
D8DF  00              NOP
D8E0  21 FA D0        LD HL,0xD0FA
D8E3  7E              LD A,(HL)
D8E4  FE E2           CP 0xE2
D8E6  C0              RET NZ
D8E7  3A FB D0        LD A,(0xD0FB)
D8EA  FE 01           CP 0x01
D8EC  D0              RET NC
D8ED  21 FC D0        LD HL,0xD0FC
D8F0  7E              LD A,(HL)
D8F1  FE 01           CP 0x01
D8F3  D0              RET NC
D8F4  21 FD D0        LD HL,0xD0FD
D8F7  7E              LD A,(HL)
D8F8  FE F6           CP 0xF6
D8FA  C0              RET NZ
D8FB  3E E2           LD A,0xE2
D8FD  32 FC D0        LD (0xD0FC),A
D900  3E F6           LD A,0xF6
D902  32 FB D0        LD (0xD0FB),A
D905  3E 00           LD A,0x00
D907  32 FA D0        LD (0xD0FA),A
D90A  32 FD D0        LD (0xD0FD),A
D90D  31 66 FF        LD SP,0xFF66
D910  C3 73 C0        JP 0xC073
D913  00              NOP
D914  00              NOP
D915  00              NOP
D916  00              NOP
D917  00              NOP
D918  3A 00 D3        LD A,(0xD300)
D91B  FE A1           CP 0xA1
D91D  CA 56 D9        JP Z,0xD956
D920  21 F9 D0        LD HL,0xD0F9
D923  7E              LD A,(HL)
D924  FE E2           CP 0xE2
D926  C0              RET NZ
D927  23              INC HL
D928  7E              LD A,(HL)
D929  FE 01           CP 0x01
D92B  D0              RET NC
D92C  23              INC HL
D92D  7E              LD A,(HL)
D92E  FE 01           CP 0x01
D930  D0              RET NC
D931  23              INC HL
D932  7E              LD A,(HL)
D933  FE 01           CP 0x01
D935  D0              RET NC
D936  23              INC HL
D937  7E              LD A,(HL)
D938  FE F6           CP 0xF6
D93A  C0              RET NZ
D93B  3E E2           LD A,0xE2
D93D  32 FB D0        LD (0xD0FB),A
D940  3E F6           LD A,0xF6
D942  32 FA D0        LD (0xD0FA),A
D945  3E 00           LD A,0x00
D947  32 F9 D0        LD (0xD0F9),A
D94A  32 FD D0        LD (0xD0FD),A
D94D  31 66 FF        LD SP,0xFF66
D950  C3 73 C0        JP 0xC073
D953  00              NOP
D954  00              NOP
D955  00              NOP
D956  21 FA D0        LD HL,0xD0FA
D959  7E              LD A,(HL)
D95A  FE E2           CP 0xE2
D95C  C0              RET NZ
D95D  2B              DEC HL
D95E  7E              LD A,(HL)
D95F  FE 01           CP 0x01
D961  D0              RET NC
D962  2B              DEC HL
D963  7E              LD A,(HL)
D964  FE 01           CP 0x01
D966  D0              RET NC
D967  2B              DEC HL
D968  7E              LD A,(HL)
D969  FE 01           CP 0x01
D96B  D0              RET NC
D96C  2B              DEC HL
D96D  7E              LD A,(HL)
D96E  FE F6           CP 0xF6
D970  C0              RET NZ
D971  3E E2           LD A,0xE2
D973  32 F8 D0        LD (0xD0F8),A
D976  3E F6           LD A,0xF6
D978  32 F9 D0        LD (0xD0F9),A
D97B  3E 00           LD A,0x00
D97D  32 FA D0        LD (0xD0FA),A
D980  32 F6 D0        LD (0xD0F6),A
D983  31 66 FF        LD SP,0xFF66
D986  C3 73 C0        JP 0xC073
D989  00              NOP
D98A  00              NOP
D98B  00              NOP
D98C  00              NOP
D98D  00              NOP
D98E  00              NOP
D98F  00              NOP
D990  CD C6 FF        CALL 0xFFC6
D993  3E 39           LD A,0x39
D995  32 FE FF        LD (0xFFFE),A
D998  3E 3F           LD A,0x3F
D99A  32 FD FF        LD (0xFFFD),A
D99D  3E 73           LD A,0x73
D99F  32 FC FF        LD (0xFFFC),A
D9A2  3E 66           LD A,0x66
D9A4  32 FB FF        LD (0xFFFB),A
D9A7  3E 83           LD A,0x83
D9A9  32 FA FF        LD (0xFFFA),A
D9AC  3E 40           LD A,0x40
D9AE  32 F8 FF        LD (0xFFF8),A
D9B1  3E 48           LD A,0x48
D9B3  32 F7 FF        LD (0xFFF7),A
D9B6  CD C6 FF        CALL 0xFFC6
D9B9  D0              RET NC
D9BA  D7              RST 10H  ; CA80 API: param=0x80 (DISPLAY)
D9BB  80              ADD A,B
D9BC  CD 50 CC        CALL 0xCC50
D9BF  3E 77           LD A,0x77
D9C1  32 FD FF        LD (0xFFFD),A
D9C4  3E 79           LD A,0x79
D9C6  32 FC FF        LD (0xFFFC),A
D9C9  3E 77           LD A,0x77
D9CB  32 FB FF        LD (0xFFFB),A
D9CE  3E 5E           LD A,0x5E
D9D0  32 FA FF        LD (0xFFFA),A
D9D3  3E 66           LD A,0x66
D9D5  32 F9 FF        LD (0xFFF9),A
D9D8  3E 83           LD A,0x83
D9DA  32 F8 FF        LD (0xFFF8),A
D9DD  CD C6 FF        CALL 0xFFC6
D9E0  D7              RST 10H  ; CA80 API: param=0x80 (DISPLAY)
D9E1  80              ADD A,B
D9E2  21 00 C0        LD HL,0xC000
D9E5  11 20 DF        LD DE,0xDF20
D9E8  06 02           LD B,0x02
D9EA  CD 26 06        CALL 0x0626
D9ED  06 02           LD B,0x02
D9EF  21 00 C0        LD HL,0xC000
D9F2  CD 7B 06        CALL 0x067B
D9F5  C9              RET
D9F6  00              NOP
D9F7  00              NOP
D9F8  00              NOP
D9F9  00              NOP
D9FA  2A 15 D0        LD HL,(0xD015)
D9FD  ED 5B 18 D0     LD DE,(0xD018)
DA01  19              ADD HL,DE
DA02  26 00           LD H,0x00
DA04  3E 4D           LD A,0x4D
DA06  BD              CP,L
DA07  38 0A           JR C,0xDA13
DA09  00              NOP
DA0A  11 B0 D0        LD DE,0xD0B0
DA0D  19              ADD HL,DE
DA0E  7E              LD A,(HL)
DA0F  FE E2           CP 0xE2
DA11  28 09           JR Z,0xDA1C
DA13  2A 15 D0        LD HL,(0xD015)
DA16  ED 5B 18 D0     LD DE,(0xD018)
DA1A  19              ADD HL,DE
DA1B  C9              RET
DA1C  3E 82           LD A,0x82
DA1E  32 FD FF        LD (0xFFFD),A
DA21  32 FC FF        LD (0xFFFC),A
DA24  32 F9 FF        LD (0xFFF9),A
DA27  32 F8 FF        LD (0xFFF8),A
DA2A  2A 2A D0        LD HL,(0xD02A)
DA2D  11 B0 D0        LD DE,0xD0B0
DA30  19              ADD HL,DE
DA31  7E              LD A,(HL)
DA32  4F              LD C,A
DA33  3A 40 D0        LD A,(0xD040)
DA36  77              LD (HL),A
DA37  2A 28 D0        LD HL,(0xD028)
DA3A  19              ADD HL,DE
DA3B  71              LD (HL),C
DA3C  31 66 FF        LD SP,0xFF66
DA3F  C3 C3 C0        JP 0xC0C3
DA42  00              NOP
DA43  00              NOP
DA44  00              NOP
DA45  00              NOP
DA46  2A 03 D0        LD HL,(0xD003)
DA49  11 B0 FC        LD DE,0xFCB0
DA4C  01 00 02        LD BC,0x0200
DA4F  09              ADD HL,BC
DA50  19              ADD HL,DE
DA51  30 06           JR NC,0xDA59
DA53  2A 01 D0        LD HL,(0xD001)
DA56  26 00           LD H,0x00
DA58  C9              RET
DA59  CD 7F C3        CALL 0xC37F
DA5C  D7              RST 10H  ; CA80 API: param=0x80 (DISPLAY)
DA5D  80              ADD A,B
DA5E  CD B7 C1        CALL 0xC1B7
DA61  0E 6E           LD C,0x6E
DA63  CD AB 01        CALL 0x01AB
DA66  80              ADD A,B
DA67  CD 50 CC        CALL 0xCC50
DA6A  0E 3F           LD C,0x3F
DA6C  CD AC 01        CALL 0x01AC
DA6F  CD 50 CC        CALL 0xCC50
DA72  0E 3E           LD C,0x3E
DA74  CD AC 01        CALL 0x01AC
DA77  CD 50 CC        CALL 0xCC50
DA7A  0E 00           LD C,0x00
DA7C  CD AC 01        CALL 0x01AC
DA7F  CD 50 CC        CALL 0xCC50
DA82  0E 77           LD C,0x77
DA84  CD AC 01        CALL 0x01AC
DA87  CD 50 CC        CALL 0xCC50
DA8A  0E 50           LD C,0x50
DA8C  CD AC 01        CALL 0x01AC
DA8F  CD 50 CC        CALL 0xCC50
DA92  0E 79           LD C,0x79
DA94  CD AC 01        CALL 0x01AC
DA97  CD 50 CC        CALL 0xCC50
DA9A  0E 00           LD C,0x00
DA9C  CD AC 01        CALL 0x01AC
DA9F  CD 50 CC        CALL 0xCC50
DAA2  0E 3D           LD C,0x3D
DAA4  CD AC 01        CALL 0x01AC
DAA7  CD 50 CC        CALL 0xCC50
DAAA  0E 3F           LD C,0x3F
DAAC  CD AC 01        CALL 0x01AC
DAAF  CD 50 CC        CALL 0xCC50
DAB2  CD AC 01        CALL 0x01AC
DAB5  CD 50 CC        CALL 0xCC50
DAB8  0E 5E           LD C,0x5E
DABA  CD AC 01        CALL 0x01AC
DABD  CD 50 CC        CALL 0xCC50
DAC0  0E 82           LD C,0x82
DAC2  CD AC 01        CALL 0x01AC
DAC5  CD 50 CC        CALL 0xCC50
DAC8  0E 00           LD C,0x00
DACA  CD AC 01        CALL 0x01AC
DACD  CD 50 CC        CALL 0xCC50
DAD0  CD AC 01        CALL 0x01AC
DAD3  CD B0 DB        CALL 0xDBB0
DAD6  D7              RST 10H  ; CA80 API: param=0x80 (DISPLAY)
DAD7  80              ADD A,B
DAD8  C3 00 C0        JP 0xC000
DADB  00              NOP
DADC  00              NOP
DADD  00              NOP
DADE  00              NOP
DADF  00              NOP
DAE0  FE 01           CP 0x01
DAE2  38 03           JR C,0xDAE7
DAE4  C6 10           ADD A,0x10
DAE6  77              LD (HL),A
DAE7  C9              RET
DAE8  00              NOP
DAE9  00              NOP
DAEA  00              NOP
DAEB  00              NOP
DAEC  00              NOP
DAED  00              NOP
DAEE  00              NOP
DAEF  00              NOP
DAF0  21 15 D0        LD HL,0xD015
DAF3  36 00           LD (HL),0x00
DAF5  21 50 D4        LD HL,0xD450
DAF8  11 50 D2        LD DE,0xD250
DAFB  01 4E 00        LD BC,0x004E
DAFE  ED B0           LDIR
DB00  21 B0 D0        LD HL,0xD0B0
DB03  01 4E 00        LD BC,0x004E
DB06  3E E2           LD A,0xE2
DB08  ED B1           CPIR
DB0A  C2 00 C0        JP NZ,0xC000
DB0D  2B              DEC HL
DB0E  11 A0 01        LD DE,0x01A0
DB11  19              ADD HL,DE
DB12  22 44 D0        LD (0xD044),HL
DB15  11 01 00        LD DE,0x0001
DB18  19              ADD HL,DE
DB19  7E              LD A,(HL)
DB1A  CD E0 DA        CALL 0xDAE0
DB1D  2A 44 D0        LD HL,(0xD044)
DB20  11 0A 00        LD DE,0x000A
DB23  19              ADD HL,DE
DB24  7E              LD A,(HL)
DB25  CD E0 DA        CALL 0xDAE0
DB28  2A 44 D0        LD HL,(0xD044)
DB2B  11 FF FF        LD DE,0xFFFF
DB2E  19              ADD HL,DE
DB2F  7E              LD A,(HL)
DB30  CD E0 DA        CALL 0xDAE0
DB33  2A 44 D0        LD HL,(0xD044)
DB36  11 F6 FF        LD DE,0xFFF6
DB39  19              ADD HL,DE
DB3A  7E              LD A,(HL)
DB3B  CD E0 DA        CALL 0xDAE0
DB3E  2A 44 D0        LD HL,(0xD044)
DB41  11 0B 00        LD DE,0x000B
DB44  19              ADD HL,DE
DB45  7E              LD A,(HL)
DB46  CD E0 DA        CALL 0xDAE0
DB49  2A 44 D0        LD HL,(0xD044)
DB4C  11 09 00        LD DE,0x0009
DB4F  19              ADD HL,DE
DB50  7E              LD A,(HL)
DB51  CD E0 DA        CALL 0xDAE0
DB54  2A 44 D0        LD HL,(0xD044)
DB57  11 F7 FF        LD DE,0xFFF7
DB5A  19              ADD HL,DE
DB5B  7E              LD A,(HL)
DB5C  CD E0 DA        CALL 0xDAE0
DB5F  2A 44 D0        LD HL,(0xD044)
DB62  11 F5 FF        LD DE,0xFFF5
DB65  19              ADD HL,DE
DB66  7E              LD A,(HL)
DB67  CD E0 DA        CALL 0xDAE0
DB6A  C9              RET
DB6B  00              NOP
DB6C  00              NOP
DB6D  00              NOP
DB6E  00              NOP
DB6F  00              NOP
DB70  2A 15 D0        LD HL,(0xD015)
DB73  ED 5B 18 D0     LD DE,(0xD018)
DB77  19              ADD HL,DE
DB78  26 00           LD H,0x00
DB7A  3E B2           LD A,0xB2
DB7C  85              ADD A,L
DB7D  D8              RET C
DB7E  11 B0 D0        LD DE,0xD0B0
DB81  19              ADD HL,DE
DB82  7E              LD A,(HL)
DB83  C9              RET
DB84  00              NOP
DB85  00              NOP
DB86  00              NOP
DB87  00              NOP
DB88  00              NOP
DB89  00              NOP
DB8A  00              NOP
DB8B  00              NOP
DB8C  00              NOP
DB8D  00              NOP
DB8E  00              NOP
DB8F  00              NOP
DB90  2A 28 D0        LD HL,(0xD028)
DB93  11 B0 D0        LD DE,0xD0B0
DB96  19              ADD HL,DE
DB97  7E              LD A,(HL)
DB98  FE 01           CP 0x01
DB9A  D0              RET NC
DB9B  31 66 FF        LD SP,0xFF66
DB9E  C3 5F C0        JP 0xC05F
DBA1  00              NOP
DBA2  00              NOP
DBA3  00              NOP
DBA4  00              NOP
DBA5  00              NOP
DBA6  00              NOP
DBA7  00              NOP
DBA8  00              NOP
DBA9  00              NOP
DBAA  00              NOP
DBAB  00              NOP
DBAC  00              NOP
DBAD  00              NOP
DBAE  00              NOP
DBAF  00              NOP
DBB0  21 0E DC        LD HL,0xDC0E
DBB3  11 5E DC        LD DE,0xDC5E
DBB6  7E              LD A,(HL)
DBB7  32 D4 DB        LD (0xDBD4),A
DBBA  23              INC HL
DBBB  7E              LD A,(HL)
DBBC  32 C7 DB        LD (0xDBC7),A
DBBF  E5              PUSH HL
DBC0  D5              PUSH DE
DBC1  ED 4B EC FF     LD BC,(0xFFEC)
DBC5  79              LD A,C
DBC6  C6 50           ADD A,0x50
DBC8  27              DAA
DBC9  ED 4B EC FF     LD BC,(0xFFEC)
DBCD  B9              CP,C
DBCE  CA E0 DB        JP Z,0xDBE0
DBD1  D3 EC           OUT (0xEC),A
DBD3  11 FF 00        LD DE,0x00FF
DBD6  21 00 00        LD HL,0x0000
DBD9  19              ADD HL,DE
DBDA  D2 D9 DB        JP NC,0xDBD9
DBDD  C3 C9 DB        JP 0xDBC9
DBE0  D1              POP DE
DBE1  E1              POP HL
DBE2  CD 3B 02        CALL 0x023B
DBE5  DA EB DB        JP C,0xDBEB
DBE8  C3 B6 DB        JP 0xDBB6
DBEB  21 0E DC        LD HL,0xDC0E
DBEE  22 B1 DB        LD (0xDBB1),HL
DBF1  21 5E DC        LD HL,0xDC5E
DBF4  22 B4 DB        LD (0xDBB4),HL
DBF7  C9              RET
DBF8  FF              RST 38H
DBF9  40              LD B,B
DBFA  94              SUB,H
DBFB  15              DEC D
DBFC  83              ADD A,E
DBFD  15              DEC D
DBFE  94              SUB,H
DBFF  50              LD D,B
DC00  FF              RST 38H
DC01  50              LD D,B
DC02  94              SUB,H
DC03  20 83           JR NZ,0xDB88
DC05  20 75           JR NZ,0xDC7C
DC07  20 6F           JR NZ,0xDC78
DC09  20 5C           JR NZ,0xDC67
DC0B  50              LD D,B
DC0C  63              LD H,E
DC0D  80              ADD A,B
DC0E  FF              RST 38H
DC0F  50              LD D,B
DC10  63              LD H,E
DC11  10 FF           DJNZ,0xDC12
DC13  05              DEC B
DC14  63              LD H,E
DC15  10 FF           DJNZ,0xDC16
DC17  05              DEC B
DC18  63              LD H,E
DC19  50              LD D,B
DC1A  FF              RST 38H
DC1B  30 7E           JR NC,0xDC9B
DC1D  10 FF           DJNZ,0xDC1E
DC1F  05              DEC B
DC20  7E              LD A,(HL)
DC21  10 FF           DJNZ,0xDC22
DC23  05              DEC B
DC24  7E              LD A,(HL)
DC25  50              LD D,B
DC26  FF              RST 38H
DC27  30 94           JR NC,0xDBBD
DC29  10 FF           DJNZ,0xDC2A
DC2B  05              DEC B
DC2C  94              SUB,H
DC2D  10 FF           DJNZ,0xDC2E
DC2F  05              DEC B
DC30  94              SUB,H
DC31  50              LD D,B
DC32  FF              RST 38H
DC33  40              LD B,B
DC34  C6 99           ADD A,0x99
DC36  FF              RST 38H
DC37  99              SBC A,C
DC38  EA 02 E0        JP PE,0xE002
DC3B  02              LD (BC),A
DC3C  D3 02           OUT (0x02),A
DC3E  C6 02           ADD A,0x02
DC40  BA              CP,D
DC41  02              LD (BC),A
DC42  B2              OR,D
DC43  02              LD (BC),A
DC44  A7              AND,A
DC45  02              LD (BC),A
DC46  9B              SBC A,E
DC47  02              LD (BC),A
DC48  94              SUB,H
DC49  02              LD (BC),A
DC4A  8C              ADC A,H
DC4B  02              LD (BC),A
DC4C  83              ADD A,E
DC4D  02              LD (BC),A
DC4E  7E              LD A,(HL)
DC4F  02              LD (BC),A
DC50  75              LD (HL),L
DC51  02              LD (BC),A
DC52  6F              LD L,A
DC53  02              LD (BC),A
DC54  69              LD L,C
DC55  02              LD (BC),A
DC56  63              LD H,E
DC57  02              LD (BC),A
DC58  5C              LD E,H
DC59  02              LD (BC),A
DC5A  57              LD D,A
DC5B  02              LD (BC),A
DC5C  52              LD D,D
DC5D  02              LD (BC),A
DC5E  4F              LD C,A
DC5F  02              LD (BC),A
DC60  CD 07 00        CALL 0x0007
DC63  10 21           DJNZ,0xDC86
DC65  5E              LD E,(HL)
DC66  D0              RET NC
DC67  77              LD (HL),A
DC68  CD 07 00        CALL 0x0007
DC6B  10 FE           DJNZ,0xDC6B
DC6D  12              LD (DE),A
DC6E  C2 60 DC        JP NZ,0xDC60
DC71  7E              LD A,(HL)
DC72  FE 0B           CP 0x0B
DC74  28 05           JR Z,0xDC7B
DC76  FE 0C           CP 0x0C
DC78  C2 D0 DE        JP NZ,0xDED0
DC7B  00              NOP
DC7C  00              NOP
DC7D  00              NOP
DC7E  00              NOP
DC7F  00              NOP
DC80  3A 5E D0        LD A,(0xD05E)
DC83  FE 0B           CP 0x0B
DC85  CA 94 DC        JP Z,0xDC94
DC88  3A 00 D3        LD A,(0xD300)
DC8B  FE A1           CP 0xA1
DC8D  C8              RET Z
DC8E  CD B0 DC        CALL 0xDCB0
DC91  C9              RET
DC92  00              NOP
DC93  00              NOP
DC94  3A 00 D3        LD A,(0xD300)
DC97  FE 88           CP 0x88
DC99  C8              RET Z
DC9A  CD B0 DC        CALL 0xDCB0
DC9D  C9              RET
DC9E  00              NOP
DC9F  00              NOP
DCA0  00              NOP
DCA1  00              NOP
DCA2  00              NOP
DCA3  00              NOP
DCA4  00              NOP
DCA5  00              NOP
DCA6  00              NOP
DCA7  00              NOP
DCA8  00              NOP
DCA9  00              NOP
DCAA  00              NOP
DCAB  00              NOP
DCAC  00              NOP
DCAD  00              NOP
DCAE  00              NOP
DCAF  00              NOP
DCB0  3E 4E           LD A,0x4E
DCB2  4F              LD C,A
DCB3  21 00 D3        LD HL,0xD300
DCB6  11 4D D4        LD DE,0xD44D
DCB9  46              LD B,(HL)
DCBA  1A              LD A,(DE)
DCBB  77              LD (HL),A
DCBC  78              LD A,B
DCBD  12              LD (DE),A
DCBE  23              INC HL
DCBF  1B              DEC DE
DCC0  0D              DEC C
DCC1  79              LD A,C
DCC2  FE 01           CP 0x01
DCC4  30 F3           JR NC,0xDCB9
DCC6  00              NOP
DCC7  00              NOP
DCC8  00              NOP
DCC9  00              NOP
DCCA  00              NOP
DCCB  00              NOP
DCCC  00              NOP
DCCD  00              NOP
DCCE  00              NOP
DCCF  00              NOP
DCD0  21 63 D0        LD HL,0xD063
DCD3  7E              LD A,(HL)
DCD4  47              LD B,A
DCD5  23              INC HL
DCD6  7E              LD A,(HL)
DCD7  70              LD (HL),B
DCD8  2B              DEC HL
DCD9  77              LD (HL),A
DCDA  21 A9 D0        LD HL,0xD0A9
DCDD  7E              LD A,(HL)
DCDE  47              LD B,A
DCDF  23              INC HL
DCE0  7E              LD A,(HL)
DCE1  70              LD (HL),B
DCE2  2B              DEC HL
DCE3  77              LD (HL),A
DCE4  C9              RET
DCE5  D0              RET NC
DCE6  00              NOP
DCE7  00              NOP
DCE8  00              NOP
DCE9  00              NOP
DCEA  00              NOP
DCEB  00              NOP
DCEC  00              NOP
DCED  00              NOP
DCEE  00              NOP
DCEF  00              NOP
DCF0  3E 83           LD A,0x83
DCF2  32 F7 FF        LD (0xFFF7),A
DCF5  CD C6 FF        CALL 0xFFC6
DCF8  FE 00           CP 0x00
DCFA  C8              RET Z
DCFB  CD B7 C1        CALL 0xC1B7
DCFE  D7              RST 10H  ; CA80 API: param=0x80 (DISPLAY)
DCFF  80              ADD A,B
DD00  CD B7 C1        CALL 0xC1B7
DD03  CD B7 C1        CALL 0xC1B7
DD06  3E 3F           LD A,0x3F
DD08  32 FE FF        LD (0xFFFE),A
DD0B  CD B7 C1        CALL 0xC1B7
DD0E  3E 50           LD A,0x50
DD10  32 FD FF        LD (0xFFFD),A
DD13  CD B7 C1        CALL 0xC1B7
DD16  3E 04           LD A,0x04
DD18  32 FC FF        LD (0xFFFC),A
DD1B  CD B7 C1        CALL 0xC1B7
DD1E  3E 5C           LD A,0x5C
DD20  32 FB FF        LD (0xFFFB),A
DD23  CD B7 C1        CALL 0xC1B7
DD26  3E 54           LD A,0x54
DD28  32 FA FF        LD (0xFFFA),A
DD2B  CD B7 C1        CALL 0xC1B7
DD2E  3E 39           LD A,0x39
DD30  32 F8 FF        LD (0xFFF8),A
DD33  CD B7 C1        CALL 0xC1B7
DD36  3E 5C           LD A,0x5C
DD38  32 F7 FF        LD (0xFFF7),A
DD3B  CD B7 C1        CALL 0xC1B7
DD3E  3E DC           LD A,0xDC
DD40  32 F7 FF        LD (0xFFF7),A
DD43  CD B7 C1        CALL 0xC1B7
DD46  CD B7 C1        CALL 0xC1B7
DD49  CD B7 C1        CALL 0xC1B7
DD4C  3E 6D           LD A,0x6D
DD4E  32 F7 FF        LD (0xFFF7),A
DD51  CD 00 DF        CALL 0xDF00
DD54  3E 31           LD A,0x31
DD56  32 F8 FF        LD (0xFFF8),A
DD59  CD 00 DF        CALL 0xDF00
DD5C  3E 37           LD A,0x37
DD5E  32 F9 FF        LD (0xFFF9),A
DD61  CD 00 DF        CALL 0xDF00
DD64  3E 79           LD A,0x79
DD66  32 FA FF        LD (0xFFFA),A
DD69  CD 00 DF        CALL 0xDF00
DD6C  3E 6D           LD A,0x6D
DD6E  32 FB FF        LD (0xFFFB),A
DD71  CD 00 DF        CALL 0xDF00
DD74  00              NOP
DD75  3E 79           LD A,0x79
DD77  32 FC FF        LD (0xFFFC),A
DD7A  CD 00 DF        CALL 0xDF00
DD7D  3E 77           LD A,0x77
DD7F  32 FD FF        LD (0xFFFD),A
DD82  CD 00 DF        CALL 0xDF00
DD85  3E 73           LD A,0x73
DD87  32 FE FF        LD (0xFFFE),A
DD8A  21 E9 FF        LD HL,0xFFE9
DD8D  36 80           LD (HL),0x80
DD8F  CD B7 C1        CALL 0xC1B7
DD92  CD B7 C1        CALL 0xC1B7
DD95  D7              RST 10H  ; CA80 API: param=0x13 (func_13)
DD96  13              INC DE
DD97  D7              RST 10H  ; CA80 API: param=0x14 (func_14)
DD98  14              INC D
DD99  CD 00 DF        CALL 0xDF00
DD9C  D7              RST 10H  ; CA80 API: param=0x12 (func_12)
DD9D  12              LD (DE),A
DD9E  D7              RST 10H  ; CA80 API: param=0x15 (func_15)
DD9F  15              DEC D
DDA0  CD 00 DF        CALL 0xDF00
DDA3  D7              RST 10H  ; CA80 API: param=0x11 (func_11)
DDA4  11 D7 16        LD DE,0x16D7
DDA7  CD 00 DF        CALL 0xDF00
DDAA  D7              RST 10H  ; CA80 API: param=0x10 (func_10)
DDAB  10 D7           DJNZ,0xDD84
DDAD  17              RLA
DDAE  CD B7 C1        CALL 0xC1B7
DDB1  CD B7 C1        CALL 0xC1B7
DDB4  3E 08           LD A,0x08
DDB6  32 FE FF        LD (0xFFFE),A
DDB9  CD 00 DF        CALL 0xDF00
DDBC  32 FC FF        LD (0xFFFC),A
DDBF  CD 00 DF        CALL 0xDF00
DDC2  32 FB FF        LD (0xFFFB),A
DDC5  CD 00 DF        CALL 0xDF00
DDC8  32 FA FF        LD (0xFFFA),A
DDCB  CD 00 DF        CALL 0xDF00
DDCE  3E 88           LD A,0x88
DDD0  32 F8 FF        LD (0xFFF8),A
DDD3  CD 00 DF        CALL 0xDF00
DDD6  3E 08           LD A,0x08
DDD8  32 F7 FF        LD (0xFFF7),A
DDDB  CD 00 DF        CALL 0xDF00
DDDE  3E 18           LD A,0x18
DDE0  32 FE FF        LD (0xFFFE),A
DDE3  CD 00 DF        CALL 0xDF00
DDE6  3E 14           LD A,0x14
DDE8  32 FD FF        LD (0xFFFD),A
DDEB  CD 00 DF        CALL 0xDF00
DDEE  3E 18           LD A,0x18
DDF0  32 FC FF        LD (0xFFFC),A
DDF3  CD 00 DF        CALL 0xDF00
DDF6  3E 0C           LD A,0x0C
DDF8  32 FB FF        LD (0xFFFB),A
DDFB  32 FA FF        LD (0xFFFA),A
DDFE  CD 00 DF        CALL 0xDF00
DE01  3E 98           LD A,0x98
DE03  32 F8 FF        LD (0xFFF8),A
DE06  CD 00 DF        CALL 0xDF00
DE09  3E 1C           LD A,0x1C
DE0B  32 F7 FF        LD (0xFFF7),A
DE0E  CD 00 DF        CALL 0xDF00
DE11  3E 54           LD A,0x54
DE13  32 FD FF        LD (0xFFFD),A
DE16  CD 00 DF        CALL 0xDF00
DE19  3E 58           LD A,0x58
DE1B  32 FC FF        LD (0xFFFC),A
DE1E  CD 00 DF        CALL 0xDF00
DE21  3E 4C           LD A,0x4C
DE23  32 FB FF        LD (0xFFFB),A
DE26  CD 00 DF        CALL 0xDF00
DE29  32 FA FF        LD (0xFFFA),A
DE2C  CD 00 DF        CALL 0xDF00
DE2F  3E D8           LD A,0xD8
DE31  32 F8 FF        LD (0xFFF8),A
DE34  CD 00 DF        CALL 0xDF00
DE37  CD 00 DF        CALL 0xDF00
DE3A  3E 38           LD A,0x38
DE3C  32 FE FF        LD (0xFFFE),A
DE3F  CD 00 DF        CALL 0xDF00
DE42  3E 76           LD A,0x76
DE44  32 FD FF        LD (0xFFFD),A
DE47  3E 78           LD A,0x78
DE49  32 FC FF        LD (0xFFFC),A
DE4C  CD 00 DF        CALL 0xDF00
DE4F  3E 6C           LD A,0x6C
DE51  32 FB FF        LD (0xFFFB),A
DE54  CD 00 DF        CALL 0xDF00
DE57  32 FA FF        LD (0xFFFA),A
DE5A  CD 00 DF        CALL 0xDF00
DE5D  3E DA           LD A,0xDA
DE5F  32 F8 FF        LD (0xFFF8),A
DE62  CD 00 DF        CALL 0xDF00
DE65  3E 3E           LD A,0x3E
DE67  32 F7 FF        LD (0xFFF7),A
DE6A  CD 00 DF        CALL 0xDF00
DE6D  3E 39           LD A,0x39
DE6F  32 FE FF        LD (0xFFFE),A
DE72  CD 00 DF        CALL 0xDF00
DE75  3E 79           LD A,0x79
DE77  32 FC FF        LD (0xFFFC),A
DE7A  CD 00 DF        CALL 0xDF00
DE7D  3E 6D           LD A,0x6D
DE7F  32 FB FF        LD (0xFFFB),A
DE82  CD 00 DF        CALL 0xDF00
DE85  32 FA FF        LD (0xFFFA),A
DE88  CD 00 DF        CALL 0xDF00
DE8B  3E DB           LD A,0xDB
DE8D  32 F8 FF        LD (0xFFF8),A
DE90  CD 00 DF        CALL 0xDF00
DE93  3E 3F           LD A,0x3F
DE95  32 F7 FF        LD (0xFFF7),A
DE98  21 E9 FF        LD HL,0xFFE9
DE9B  36 80           LD (HL),0x80
DE9D  00              NOP
DE9E  00              NOP
DE9F  00              NOP
DEA0  CD 90 D9        CALL 0xD990
DEA3  D7              RST 10H  ; CA80 API: param=0x80 (DISPLAY)
DEA4  80              ADD A,B
DEA5  CD 00 DF        CALL 0xDF00
DEA8  21 B3 DE        LD HL,0xDEB3
DEAB  CD D4 01        CALL 0x01D4
DEAE  53              LD D,E
DEAF  C3 B9 DE        JP 0xDEB9
DEB2  00              NOP
DEB3  6D              LD L,L
DEB4  06 78           LD B,0x78
DEB6  77              LD (HL),A
DEB7  40              LD B,B
DEB8  FF              RST 38H
DEB9  CD 07 00        CALL 0x0007
DEBC  10 21           DJNZ,0xDEDF
DEBE  5C              LD E,H
DEBF  D0              RET NC
DEC0  77              LD (HL),A
DEC1  CD 07 00        CALL 0x0007
DEC4  10 FE           DJNZ,0xDEC4
DEC6  12              LD (DE),A
DEC7  C2 B9 DE        JP NZ,0xDEB9
DECA  7E              LD A,(HL)
DECB  FE 02           CP 0x02
DECD  D2 A3 DE        JP NC,0xDEA3
DED0  D7              RST 10H  ; CA80 API: param=0x80 (DISPLAY)
DED1  80              ADD A,B
DED2  21 E0 DE        LD HL,0xDEE0
DED5  CD D4 01        CALL 0x01D4
DED8  62              LD H,D
DED9  00              NOP
DEDA  C3 60 DC        JP 0xDC60
DEDD  00              NOP
DEDE  00              NOP
DEDF  00              NOP
DEE0  39              ADD HL,SP
DEE1  5C              LD E,H
DEE2  30 5C           JR NC,0xDF40
DEE4  50              LD D,B
DEE5  40              LD B,B
DEE6  FF              RST 38H
DEE7  00              NOP
DEE8  00              NOP
DEE9  00              NOP
DEEA  00              NOP
DEEB  00              NOP
DEEC  00              NOP
DEED  00              NOP
DEEE  00              NOP
DEEF  00              NOP
DEF0  00              NOP
DEF1  00              NOP
DEF2  00              NOP
DEF3  00              NOP
DEF4  00              NOP
DEF5  00              NOP
DEF6  00              NOP
DEF7  00              NOP
DEF8  00              NOP
DEF9  00              NOP
DEFA  00              NOP
DEFB  00              NOP
DEFC  00              NOP
DEFD  00              NOP
DEFE  00              NOP
DEFF  00              NOP
DF00  11 02 00        LD DE,0x0002
DF03  21 00 00        LD HL,0x0000
DF06  19              ADD HL,DE
DF07  D2 06 DF        JP NC,0xDF06
DF0A  C9              RET
DF0B  00              NOP
DF0C  04              INC B
DF0D  11 40 01        LD DE,0x0140
DF10  20 00           JR NZ,0xDF12
DF12  00              NOP
DF13  00              NOP
DF14  00              NOP
DF15  00              NOP
DF16  00              NOP
DF17  00              NOP
DF18  00              NOP
DF19  00              NOP
DF1A  00              NOP
DF1B  00              NOP
DF1C  00              NOP
DF1D  00              NOP
DF1E  00              NOP
DF1F  00              NOP
DF20  00              NOP
