#!/usr/bin/env bash

function realpath {
    local path=$(python -c "import os; print os.path.realpath(\"$1\")")
    echo "$path"
}

function build_ssdt {
	local name=$(basename "$1" .dsl)
    local ret=`"$SCRIPT_DIR/tools/iasl" -vw 2095 -vw 2146 -vw 2089 -vr -oe -p "$SCRIPT_DIR/build/$name.aml" "$SCRIPT_DIR/ssdt/$name.dsl" | grep "Compilation complete"`
    echo " - $name.aml : $ret"
}

SCRIPT_DIR=`dirname $(realpath "$0")`

echo " -- Script directory : $SCRIPT_DIR"

chmod +x $SCRIPT_DIR/tools/*

EFI=`sudo $SCRIPT_DIR/tools/mount_efi.sh`
RET=$?
if [[ $RET != 0 ]]; then
    echo "Error mounting efi"
    exit $RET
fi

CLOVER="$EFI/EFI/CLOVER"
if [[ -d $CLOVER ]]; then
    echo " -- CLOVER : [$CLOVER]"
else
    echo " -- $CLOVER doesn't exist"
    exit 1
fi

rm -rf "$SCRIPT_DIR/build"
mkdir "$SCRIPT_DIR/build"

# https://stackoverflow.com/a/26349346
find "$SCRIPT_DIR/ssdt" -name "*.dsl" -print0 | while IFS= read -r -d '' file; do build_ssdt "$file"; done

rm -rf $CLOVER/ACPI/patched/*
rm -rf $CLOVER/kexts/Other $CLOVER/kexts/10.13

cp -f $SCRIPT_DIR/build/*.aml $CLOVER/ACPI/patched/
cp -f $SCRIPT_DIR/clover/drivers64UEFI/* $CLOVER/drivers64UEFI/
cp -rf $SCRIPT_DIR/clover/kexts/* $CLOVER/kexts/
TS=`date +%Y%m%d%H%M%S`
cp -f $CLOVER/config.plist $CLOVER/config.plist_$TS.bak >/dev/null 2>&1
cp -f $CLOVER/smbios.plist $CLOVER/smbios.plist_$TS.bak >/dev/null 2>&1
cp -f $SCRIPT_DIR/clover/config.plist $CLOVER/
cp -f $SCRIPT_DIR/clover/smbios.plist $CLOVER/

sudo diskutil umount $EFI
rm -rf $SCRIPT_DIR/build/*

exit 0
