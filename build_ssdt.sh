#!/usr/bin/env bash

if [[ ! -d build ]]; then
  rm -rf build
  mkdir build
fi
rm -f build/*.aml

chmod +x tools/iasl

tools/iasl -vw 2095 -vw 2146 -vw 2089 -vr -oe -p build/SSDT-XH57.aml ssdt/SSDT-XH57.dsl
tools/iasl -vw 2095 -vw 2146 -vw 2089 -vr -oe -p build/SSDT-Config.aml ssdt/SSDT-Config.dsl

