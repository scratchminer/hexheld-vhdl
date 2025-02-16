# HiveCraft VHDL implementation

By scratchminer

My first time using VHDL and hardware programming in general.

## Simulating

The `sim.sh` script uses [GHDL](https://ghdl.github.io/ghdl/) for simulation.

Note that on Apple Silicon Macs, the GHDL Homebrew package is broken.
More information can be found [here](https://github.com/ghdl/ghdl/issues/2708).

1. Install GHDL from your favorite package manager.
2. Run the `sim.sh` shell script, passing in the name of the testbench you want to run. (Example: `./sim.sh cpu_tb`)

## Synthesizing

Honestly, I'm not sure how you synthesize a VHDL circuit -- I don't have an FPGA to test on either.

---

Tested in GHDL, not on any FPGA chip. Don't blame me if it doesn't work.
