#!/usr/bin/env bash
set -euo pipefail

SRC_FILE="blinky.vctx"
BASENAME="blinky"
TOP_MODULE="blinky_Blinky"
CST_FILE="board.cst"

DEVICE="${DEVICE:-GW1NR-LV9QN88PC6/I5}"
FAMILY="${FAMILY:-GW1N-9C}"

BUILD_DIR="build"
SV_FILE="${BUILD_DIR}/${BASENAME}.sv"
JSON_FILE="${BUILD_DIR}/${BASENAME}.json"
PNR_FILE="${BUILD_DIR}/${BASENAME}_pnr.json"
BITSTREAM="${BUILD_DIR}/${BASENAME}.fs"

for f in "$SRC_FILE" "$CST_FILE"; do
    if [ ! -f "$f" ]; then
        echo "Error: $f not found"
        exit 1
    fi
done

echo "1. Compiling VCTX to SystemVerilog"
vctx sv "$SRC_FILE"

if [ ! -f "$SV_FILE" ]; then
    echo "Error: expected $SV_FILE after 'vctx sv'"
    ls -la "$BUILD_DIR" 2>/dev/null || echo "  ${BUILD_DIR} does not exist"
    exit 1
fi

echo "Top module: ${TOP_MODULE}"
echo "Port list:"
sed -n "/^[[:space:]]*module[[:space:]]\+${TOP_MODULE}/,/);/p" "$SV_FILE"

echo "2. Synthesizing with Yosys"
yosys -p "read_verilog -sv ${SV_FILE}; synth_gowin -top ${TOP_MODULE} -json ${JSON_FILE}" \
      -l "${BUILD_DIR}/synthesis.log"

echo "3. Place and route with nextpnr"
nextpnr-himbaechel \
    --device "$DEVICE" \
    --vopt family="$FAMILY" \
    --vopt cst="$CST_FILE" \
    --json "$JSON_FILE" \
    --write "$PNR_FILE"

echo "4. Packing bitstream with gowin_pack"
gowin_pack -d "$FAMILY" -o "$BITSTREAM" "$PNR_FILE"

echo "Success! Bitstream saved to ${BITSTREAM}"
