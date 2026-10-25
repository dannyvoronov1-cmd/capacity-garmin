#!/bin/bash
# Capacity Clock - one-time Mac setup + build.
# Double-click this file in Finder. It installs what's missing, waits for you
# to sign in to Garmin's SDK Manager, then builds the app.
cd "$(dirname "$0")"
REPO="$(pwd)"
say_step() { printf "\n\033[1;33m== %s ==\033[0m\n" "$1"; }

# Homebrew lives in different places on Apple Silicon and Intel Macs
for B in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$B" ] && eval "$("$B" shellenv)"
done

if ! command -v brew >/dev/null 2>&1; then
    say_step "Installing Homebrew (asks for your Mac password)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || exit 1
    for B in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [ -x "$B" ] && eval "$("$B" shellenv)"
    done
fi

if ! /usr/libexec/java_home >/dev/null 2>&1; then
    say_step "Installing Java (the Garmin compiler needs it; may ask for your Mac password)"
    brew install --cask temurin || exit 1
fi

if [ ! -d "/Applications/SdkManager.app" ]; then
    say_step "Installing Garmin Connect IQ SDK Manager"
    brew install --cask connectiq-sdk-manager || exit 1
fi

if [ ! -d "/Applications/OpenMTP.app" ]; then
    say_step "Installing OpenMTP (copies files onto the watch)"
    brew install --cask openmtp || exit 1
fi

CFG="$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"
DEV="$HOME/Library/Application Support/Garmin/ConnectIQ/Devices"
if [ ! -f "$CFG" ] || [ ! -d "$DEV/venusqm" ]; then
    say_step "Your turn in the SDK Manager window"
    echo "1. Sign in with your Garmin account."
    echo "2. SDK tab: download the latest SDK and click 'Use as Active SDK'."
    echo "3. Devices tab: search 'Venu Sq' and download 'Venu Sq Music'."
    open -a SdkManager
    echo
    read -r -p "Press Enter here when all three are done... "
fi

say_step "Building Capacity Clock"
cd "$REPO/app" && ./build.sh venusqm
STATUS=$?
if [ $STATUS -ne 0 ]; then
    echo
    echo "Build failed. Copy the errors above into the Claude chat."
    read -r -p "Press Enter to close."
    exit $STATUS
fi

say_step "Done"
echo "App file: $REPO/app/bin/CapacityClock.prg"
open -a OpenMTP
open -R "$REPO/app/bin/CapacityClock.prg"
read -r -p "Press Enter to close."
