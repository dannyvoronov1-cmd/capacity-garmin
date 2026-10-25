#!/bin/bash
# Builds Capacity Clock for your watch and copies it over if the watch is mounted.
# Usage: ./build.sh            (Venu Sq Music)
#        ./build.sh venusq2m   (Venu Sq 2 Music; also: venusq, venusq2)
set -e
cd "$(dirname "$0")"
DEVICE="${1:-venusqm}"

# 1. Find the Connect IQ SDK installed by the SDK Manager
CFG="$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"
if [ -f "$CFG" ]; then
    SDK="$(cat "$CFG" | tr -d '\n')"
fi
if [ -z "$SDK" ] || [ ! -x "$SDK/bin/monkeyc" ]; then
    echo "Connect IQ SDK not found. Open the SDK Manager, sign in, install the latest SDK and the device, then run again."
    exit 1
fi
echo "SDK: $SDK"

# 2. Developer key (one time, stays in this folder)
if [ ! -f developer_key.der ]; then
    echo "Creating developer key..."
    openssl genrsa -out developer_key.pem 4096 2>/dev/null
    openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
fi

# 3. Build
mkdir -p bin
"$SDK/bin/monkeyc" -d "$DEVICE" -f monkey.jungle -o bin/CapacityClock.prg -y developer_key.der -l 0 -w
echo "Built bin/CapacityClock.prg for $DEVICE"

# 4. Copy to the watch if it shows up as a drive
for VOL in /Volumes/GARMIN /Volumes/Garmin*; do
    if [ -d "$VOL/GARMIN/APPS" ]; then
        cp bin/CapacityClock.prg "$VOL/GARMIN/APPS/"
        echo "Copied to $VOL/GARMIN/APPS - eject the watch and unplug."
        exit 0
    fi
done
echo "Watch not mounted as a drive. Copy bin/CapacityClock.prg into GARMIN/APPS with OpenMTP (see README)."
