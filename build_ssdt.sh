#!/usr/bin/env bash

function realpath {
    local path=$(python -c "import os; print os.path.realpath(\"$1\")")
    echo "$path"
}

function build_ssdt {
	local name=$(basename "$1" .dsl)
    "$SCRIPT_DIR/tools/iasl" -vw 2095 -vw 2146 -vw 2089 -vr -oe -p "$SCRIPT_DIR/build/$name.aml" "$SCRIPT_DIR/ssdt/$name.dsl"
}

SCRIPT_DIR=`dirname $(realpath "$0")`

echo " --- Script directory : $SCRIPT_DIR"

if [[ ! -d "$SCRIPT_DIR/build" ]]; then
  rm -rf "$SCRIPT_DIR/build"
  mkdir "$SCRIPT_DIR/build"
fi

rm -f "$SCRIPT_DIR/build/*.aml"
chmod +x "$SCRIPT_DIR/tools/iasl"

# https://stackoverflow.com/a/26349346
find "$SCRIPT_DIR/ssdt" -name "*.dsl" -print0 | while IFS= read -r -d '' file; do build_ssdt "$file"; done