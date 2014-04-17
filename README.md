# PBasic

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

PBasic interpreter written in MIPS assembly. Runs on the SPIM and MARS simulators.

## Highlights

- PBasic dialect supporting LET, PRINT, IF/THEN, GOTO, GOSUB/RETURN, LIST, NEW, EXIT, REM, INPUT, RUN, END, FREE, RND, and ABS
- Expression evaluator with recursive descent parsing (+, -, *, /, parentheses, unary minus)
- 26 variables (A-Z) stored as 32-bit integers; `*` `/` are 16-bit, `+` `-` and unary minus are 32-bit
- 52 KB program area with tokenized line storage as a linked list
- FREE reports available bytes between the program end and `MEM_PROG_LIMIT` (command or expression)
- `INPUT "prompt"; VAR` (semicolon after the prompt); `RND(x)` returns 1..x
- I/O via SPIM/MARS standard syscalls (`mapped_io` mode for interactive input)

## Overview

PBasic began in 2014 as a passion project during my Computer Science degree.

Originally written in MIPS assembly to run on the MARS simulator, I built it to demonstrate to my classmates that assembly language could be used to build practical, fully functional software—like a complete BASIC interpreter—rather than just toy academic exercises.

## Prerequisites

- **spim** — MIPS simulator; install with `sudo apt install spim`
- **mars** — MIPS Assembler and Runtime Simulator (optional, download from [missouristate.edu/MARS](https://courses.missouristate.edu/KenVollmar/MARS/))

## Installation

### Build from Source

```bash
git clone https://github.com/carlosrabelo/pbasic.git
cd pbasic
make build
```

## Usage

### Build and run

```bash
make run                           # uses spim
make run EMULATOR=mars             # uses java -jar MARS.jar
make run EMULATOR=mars MARS_JAR=/path/MARS.jar
```

### Build only

```bash
make build
```

This concatenates all MIPS assembly modules into a single source file:

```bash
# Run MIPS assembly source on SPIM simulator
spim -mapped_io -file bin/pbasic.s

# Run MIPS assembly source on MARS simulator
java -jar MARS.jar bin/pbasic.s
```

### Example session

```
PBasic

> 10 LET A=42
> 20 PRINT A
> 30 PRINT A*2+10
> RUN
42
94
> PRINT FREE
53196
> LIST
10 LET A=42
20 PRINT A
30 PRINT A*2+10
> NEW
OK
```

## Project Layout

```
src/                # MIPS assembly sources
demos/              # BASIC demonstration programs (`make test` runs 99_test.bas when SPIM is installed)
bin/                # Concatenated source output (git-ignored)
Makefile            # Build orchestrator
.make/              # Build helper scripts
```

## Development

```bash
make help              # Show available targets
make build             # Concatenate MIPS sources
make test              # Build, check labels; run 99_test.bas if SPIM is installed
make run               # Build and run on SPIM/MARS
make clean             # Remove build artifacts
```

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.
