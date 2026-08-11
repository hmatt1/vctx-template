#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <source_file.vctx> [top_module] [cst_file]"
    echo "Example: $0 counter.vctx Counter board.cst"
    exit 1
fi

SRC_FILE="$1"
BASENAME=$(basename "$SRC_FILE" .vctx)
TOP_MODULE="${2:-$BASENAME}"
CST_FILE="${3:-board.cst}"

# Default to Tang Nano 9K if not specified by environment variables
DEVICE="${DEVICE:-GW1NR-LV9QN88PC6/I5}"
FAMILY="${FAMILY:-GW1N-9C}"

echo "========================================"
echo "1. Compiling VCTX to SystemVerilog"
echo "========================================"
vctx sv "$SRC_FILE"

echo "========================================"
echo "2. Synthesizing with Yosys"
echo "========================================"
yosys -p "read_verilog -sv ./build/${BASENAME}.sv; synth_gowin -top ${TOP_MODULE} -json ${BASENAME}.json"

echo "========================================"
echo "3. Place and Route with nextpnr"
echo "========================================"
nextpnr-himbaechel --device "$DEVICE" --vopt family="$FAMILY" --vopt cst="$CST_FILE" --json "${BASENAME}.json" --write "${BASENAME}_pnr.json"

echo "========================================"
echo "4. Generating Bitstream with gowin_pack"
echo "========================================"
gowin_pack -d "$FAMILY" -o "${BASENAME}.fs" "${BASENAME}_pnr.json"

echo "========================================"
echo "Success! Bitstream saved to ${BASENAME}.fs"
echo "========================================"
