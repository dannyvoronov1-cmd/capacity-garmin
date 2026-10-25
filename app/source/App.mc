import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
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
// Shows the next synced workout with a START pill. START runs it,
// swipe up / tap / hold opens the full menu.

function upNext() {
    var synced = loadList("synced");
    if (synced.size() > 0) {
        return synced[0];
    }
    return null;
}

function homeSummary(w) {
    var rounds = getNum(w, "rounds", 1);
    var steps = w.get("steps");
    var total = 0;
    var open = false;
    if (steps instanceof Lang.Array) {
        for (var i = 0; i < steps.size(); i++) {
            var s = getNum(steps[i], "s", 0);
            if (s == 0) {
                open = true;
            }
            total += s * rounds;
        }
    }
    var r = rounds > 1 ? rounds.toString() + " ROUNDS" : "1 ROUND";
    return r + " · " + (open ? "LAP ENDS RUNS" : fmtTime(total));
}

class HomeView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onShow() {
        useFonts([F_TITLE, F_LABEL, F_SMALL, F_TINY]);
    }

    function onHide() {
        dropFonts();
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var C = Graphics.TEXT_JUSTIFY_CENTER;
        dc.setColor(C_TEXT, C_BG);
        dc.clear();

        txt(dc, cx, h * 15 / 100, F_LABEL, "C A P A C I T Y", C_TEXT3, C);

        var next = upNext();
        var top = "TODAY";
        var name = "";
        var sub = "";
        if (next != null) {
            name = getStr(next, "name", "Workout");
            sub = homeSummary(next);
        } else {
            var last = Storage.getValue("last");
            if (last != null) {
                top = "AGAIN";
                name = getStr(last, "name", "Workout");
                sub = homeSummary(last);
            } else {
                top = "QUICK";
                name = quickName(loadQuick());
                sub = "INTERVALS";
            }
        }
        var status = syncStatus();
        txt(dc, cx, h * 30 / 100, F_SMALL, status.length() > 0 ? top + " · " + status : top, C_GOLD, C);
        var nameFont = txtWidth(dc, F_TITLE, name) <= w * 86 / 100 ? F_TITLE : F_LABEL;
        txt(dc, cx, h * 43 / 100, nameFont, name, C_TEXT, C);
        txt(dc, cx, h * 56 / 100, F_SMALL, sub, C_TEXT2, C);

        // START pill
        var pw = w * 42 / 100;
        var ph = h * 14 / 100;
        var py = h * 73 / 100;
        dc.setColor(C_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - pw / 2, py, pw, ph, ph / 2);
        txt(dc, cx, py + ph / 2, F_LABEL, "START", C_INK, C);

        var more = loadList("synced").size() - 1;
        txt(dc, cx, h * 93 / 100, F_TINY, more > 0 ? "+" + more.toString() + " MORE · SWIPE UP" : "SWIPE UP FOR TIMERS", C_TEXT3, C);
    }
}

// "SYNCED 19:02", "PHONE OFF", or "" before the first sync
function syncStatus() {
    if (SYNC_URL.length() == 0) {
        return "";
    }
    if (gSyncBusy) {
        return "SYNCING";
    }
    if (gSyncOk) {
        var at = Storage.getValue("syncedAt");
        if (at != null) {
            var info = Gregorian.info(new Time.Moment(at), Time.FORMAT_SHORT);
            return "SYNCED " + info.hour.format("%02d") + ":" + info.min.format("%02d");
        }
        return "SYNCED";
    }
    if (gSyncFailed) {
        return gSyncMsg.toUpper();
    }
    return "";
}

class HomeDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // START button: run what's up next
    function onSelect() {
        var next = upNext();
        if (next == null) {
            next = Storage.getValue("last");
        }
        if (next != null) {
            launchWorkout(next);
        } else {
            openQuickMenu();
        }
        return true;
    }

    function onTap(evt) {
        openMainMenu();
        return true;
    }

    function onNextPage() {
        openMainMenu();
        return true;
    }

    function onMenu() {
        openMainMenu();
        return true;
    }
}
