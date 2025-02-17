#!/bin/sh

CWD="$PWD"

cd "$(dirname "$0")"

if [ $# -eq 0 ]; then
	echo "Usage: sim.sh [-c / --clean] (testbenches...)"
fi

if [ "$1" = "-c" ] || [ "$1" = "--clean" ]; then
	ghdl --remove
	rm -f ./*.vcd
fi

for arg in "$@"; do
	if ! { [ "$arg" = "-c" ] || [ "$arg" = "--clean" ]; } && [ -f "test/$arg.vhdl" ]; then
		ghdl -a -Wall \
			src/cpu_pfq.vhdl \
			src/cpu.vhdl \
			src/clk.vhdl \
			src/ram.vhdl \
			src/tim.vhdl \
			src/hivecraft.vhdl \
		"test/$arg.vhdl" && \
		ghdl -e "$arg" && \
		ghdl -r "$arg" --vcd="$arg.vcd"
	elif [ "$arg" != "-c" ] && [ "$arg" != "--clean" ]; then
		echo "Warning: ignoring argument '$arg' because no file with that name was found in the testbenches"
	fi
done

cd "$CWD"