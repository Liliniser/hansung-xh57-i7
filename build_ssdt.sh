#!/usr/bin/env bash

function realpath {
    local path=$(python -c "import os; print os.path.realpath(\"$1\")")
    echo "$path"
}

function build_ssdt {
    "$SCRIPT_DIR/tools/iasl" -vw 2095 -vw 2146 -vw 2089 -vr -oe -p "$SCRIPT_DIR/build/$1.aml" "$SCRIPT_DIR/ssdt/$1.dsl"
}

SCRIPT_DIR=`dirname $(realpath "$0")`

echo " --- Script directory : $SCRIPT_DIR"

if [[ ! -d "$SCRIPT_DIR/build" ]]; then
  rm -rf "$SCRIPT_DIR/build"
  mkdir "$SCRIPT_DIR/build"
fi

rm -f "$SCRIPT_DIR/build/*.aml"
chmod +x "$SCRIPT_DIR/tools/iasl"

build_ssdt SSDT-XH57
build_ssdt SSDT-Config
build_ssdt SSDT-DGPU_PTSWAK

