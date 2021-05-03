# Kronos

[![Build Status](https://github.com/nmoroze/kronos/workflows/CI/badge.svg)](https://github.com/nmoroze/kronos/actions?query=workflow%3ACI)

This repository contains code for my MEng thesis, "Kronos: Verifying leak-free
reset for a system-on-chip with multiple clock domains". Kronos consists of a
SoC based on a subset of [OpenTitan][opentitan], with a security property
called "output determinism" verified using Racket/[Rosette][rosette].

For more information, see the [thesis](doc/thesis.pdf)!

## Getting Started
### Dependencies
- [sv2v](https://github.com/zachjs/sv2v) (tested on commit 8e1f2bb, newer
  versions may break)
- [Yosys (custom fork)][yosys-fork]
- [rtl (custom fork)][rtl-fork]
- [Racket](https://racket-lang.org/)
- [Rosette][rosette]
- [RISC-V toolchain][riscv-gcc]
- [bin2coe][bin2coe]

### Running
Once dependencies are installed, run `make verify` in the top-level to run the
build flow and all top-level verification scripts.

## Project Structure
#### `fw/`
Contains verified boot code for resetting SoC's state.

#### `soc/`
Contains all of our HDL code. This directory contains a [fork of
OpenTitan][ot-kronos] as a Git submodule, and the top level and crossbar
implementations for our subset. The OpenTitan fork contains two types of
modifications: some to let it work nicely with our toolchain, and some to fix
violations of our output determinism property. The fork's commit messages
provide a bit of detail about each change.

#### `verify/`
Contains Racket verification code. The following files are top-level entry points:
- `verify/core/main.rkt` - proof of core output determinism
- `verify/peripheral/spi-in.rkt` - proof of peripheral output determinism for SPI-in clock domain
- `verify/peripheral/spi-out.rkt` - proof of peripheral output determinism for SPI-out clock domain
- `verify/peripheral/usb.rkt` - proof of peripheral output determinism for USB clock domain
- `verify/fifo/main.rkt` - FIFO auxiliary proof for all verified sizes of sync and async FIFO

## Related Projects
This project is based on [Notary][notary], which also uses Racket/Rosette to
verify a security property for an open-source RISC-V SoC (based on the
[PicoRV32][picorv32]).

[bin2coe]: https://github.com/anishathalye/bin2coe
[opentitan]: https://opentitan.org/
[ot-kronos]: https://github.com/nmoroze/opentitan-kronos
[riscv-gcc]: https://github.com/riscv/riscv-gnu-toolchain
[rosette]: https://docs.racket-lang.org/rosette-guide/index.html
[mit]: https://opensource.org/licenses/MIT
[rtl-fork]: https://github.com/nmoroze/rtl
[yosys-fork]: https://github.com/nmoroze/yosys
[notary]: https://github.com/anishathalye/notary
[picorv32]: https://github.com/cliffordwolf/picorv32
