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
        var cx = w / 2;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(C_TEXT, C_BG);
        dc.clear();

        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 25 / 100, Graphics.FONT_LARGE, "CAPACITY", center);
        dc.setColor(C_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 37 / 100, Graphics.FONT_TINY, "C L O C K", center);
        dc.setColor(C_HAIR, C_HAIR);
        dc.fillRectangle(w * 25 / 100, h * 45 / 100, w / 2, 1);

        var synced = loadList("synced");
        var title = "";
        var line = "";
        if (synced.size() > 0) {
            title = "UP NEXT";
            line = getStr(synced[0], "name", "");
        } else {
            var last = Storage.getValue("last");
            if (last != null) {
                title = "LAST";
                line = getStr(last, "name", "");
            }
        }
        if (line.length() > 0) {
            dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 52 / 100, Graphics.FONT_XTINY, title, center);
            dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 61 / 100, Graphics.FONT_SMALL, line, center);
        }
        if (SYNC_URL.length() > 0) {
            dc.setColor(C_TEXT2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 71 / 100, Graphics.FONT_XTINY, gSyncMsg, center);
        }
        dc.setColor(C_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 84 / 100, Graphics.FONT_TINY, "START = MENU", center);
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
