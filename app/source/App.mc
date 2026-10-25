import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Workouts pushed from Claude live here (GitHub Pages, docs/presets.json in the repo).
// Must be served as application/json. Empty string turns syncing off.
const SYNC_URL = "https://dannyvoronov1-cmd.github.io/capacity-garmin/presets.json";

// The one running clock. Null when no workout is open.
var gEngine = null;

class CapacityClockApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        // pull new workouts through the phone every time the app opens
        startSync(null);
    }

    function onStop(state) {
        if (gEngine != null) {
            gEngine.shutdown();
            gEngine = null;
        }
    }

    function getInitialView() {
        return [new HomeView(), new HomeDelegate()];
    }
}

// ---------- shared helpers ----------

// 75 -> "1:15", 3725 -> "1:02:05"
function fmtTime(sec) {
    if (sec < 0) {
        sec = 0;
    }
    var h = sec / 3600;
    var m = (sec % 3600) / 60;
    var s = sec % 60;
    if (h > 0) {
        return h.toString() + ":" + m.format("%02d") + ":" + s.format("%02d");
    }
    return m.toString() + ":" + s.format("%02d");
}

function getNum(dict, key, def) {
    if (dict == null) {
        return def;
    }
    var v = dict.get(key);
    if (v == null) {
        return def;
    }
    if (v instanceof Lang.Number) {
        return v;
    }
    if (v instanceof Lang.Float || v instanceof Lang.Double || v instanceof Lang.Long || v instanceof Lang.String) {
        var n = v.toNumber();
        return n == null ? def : n;
    }
    return def;
}

function getStr(dict, key, def) {
    if (dict == null) {
        return def;
    }
    var v = dict.get(key);
    if (v == null) {
        return def;
    }
    return v.toString();
}

// Opens the timer screen for a workout definition (see Presets.mc for the format).
function launchWorkout(w) {
    if (gEngine != null) {
        gEngine.shutdown();
        gEngine = null;
    }
    gEngine = new Engine(w);
    Storage.setValue("last", w);
    WatchUi.pushView(new TimerView(), new TimerDelegate(), WatchUi.SLIDE_LEFT);
}

// Closes the timer screen (and an open menu on top of it).
function closeWorkout(menusOnTop) {
    for (var i = 0; i < menusOnTop; i++) {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
    WatchUi.popView(WatchUi.SLIDE_RIGHT);
    if (gEngine != null) {
        gEngine.shutdown();
        gEngine = null;
    }
}

// ---------- home screen ----------

class HomeView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 30 / 100, Graphics.FONT_MEDIUM, "CAPACITY", center);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 42 / 100, Graphics.FONT_MEDIUM, "CLOCK", center);

        var synced = loadList("synced");
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        if (synced.size() > 0) {
            dc.drawText(w / 2, h * 56 / 100, Graphics.FONT_XTINY, "UP NEXT: " + getStr(synced[0], "name", ""), center);
        } else {
            var last = Storage.getValue("last");
            if (last != null) {
                dc.drawText(w / 2, h * 56 / 100, Graphics.FONT_XTINY, "LAST: " + getStr(last, "name", ""), center);
            }
        }
        if (SYNC_URL.length() > 0) {
            dc.drawText(w / 2, h * 64 / 100, Graphics.FONT_XTINY, gSyncMsg, center);
        }
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 76 / 100, Graphics.FONT_TINY, "START = menu", center);
    }
}

class HomeDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() {
        openMainMenu();
        return true;
    }

    function onMenu() {
        openMainMenu();
        return true;
    }
}
