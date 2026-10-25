# capacity-garmin

**Capacity Clock** - a custom interval and running-clock app for the Garmin Venu Sq Music (also builds for Venu Sq, Sq 2, Sq 2 Music).
Workouts are written from Claude into `docs/presets.json` and reach the watch wirelessly through the phone.

```
app/      Connect IQ watch app (Monkey C) + build.sh
docs/     GitHub Pages site - presets.json is what the watch syncs
```

## How new workouts get to the watch

1. Tell Claude the workout.
2. Claude updates `docs/presets.json` and pushes it here.
3. Open Capacity Clock on the watch. It syncs on launch (phone nearby with Bluetooth on and the Garmin Connect app running in the background), and the new workouts sit at the top of the menu. "Sync now" in the menu forces it.

Sync URL: `https://dannyvoronov1-cmd.github.io/capacity-garmin/presets.json`

## On the watch

- **Synced workouts** - at the top of the menu, newest first
- **Repeat last**, **Quick Interval** (work / rest / rounds / get-ready pickers, Open work ends on LAP, save to My Presets)
- **Stopwatch** with laps, **Countdown**, built-in **Presets** (Tabata, EMOMs, 30/30, 40/20, run reps, AMRAP, For Time)
- Every session is saved to Garmin Connect with heart rate, one lap per interval

| | Top button (START) | Bottom button (BACK) |
|---|---|---|
| Ready | Start | Leave |
| Running | Pause -> Resume / End + Save / End + Discard | Next interval, end an Open interval, or stopwatch lap |
| Done | Save / Discard | Save / Discard |

Touch is ignored once a workout starts. Screen color: orange get ready, green work, red rest, blue open / count-up.
Double buzz = go, long buzz = rest, short ticks on the last 3 seconds.

## Installing the app (only when the app itself changes)

1. `brew install --cask connectiq` - open the SDK Manager, sign in with your Garmin account, install the latest SDK and the **Venu Sq Music** device.
2. `cd app && ./build.sh` (Sq 2 Music: `./build.sh venusq2m`). The first run creates `developer_key.der` - keep it, it's ignored by git.
3. Plug the watch in. If it mounts as GARMIN the script copies the app; otherwise drag `app/bin/CapacityClock.prg` into `GARMIN/APPS` with OpenMTP (`brew install --cask openmtp`).

If the build says a device id is unknown, remove that `<iq:product>` line from `app/manifest.xml`.

## presets.json format

```json
{"presets": [
  {"name": "6x400 / 1:30", "prep": 0, "rounds": 6,
   "steps": [{"l": "RUN 400", "s": 0}, {"l": "REST", "s": 90, "k": "rest"}]}
]}
```

- `l` label shown on the watch, `s` seconds (0 = open, ends when you press LAP)
- `k` kind: `work` (default), `rest`, or `up` (counts up to a cap, e.g. For Time)
- `prep` get-ready seconds, `rounds` repeats of `steps`. The final rest of the last round is dropped.
