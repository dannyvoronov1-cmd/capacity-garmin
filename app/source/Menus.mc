import Toybox.Application.Storage;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// ---------- main menu ----------

class MainMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => "Capacity Clock"});
        // synced workouts first: whatever was pushed from Claude is right at the top
        var synced = loadList("synced");
        for (var i = 0; i < synced.size(); i++) {
            addItem(new WatchUi.MenuItem(getStr(synced[i], "name", "Workout"), summary(synced[i]), i, null));
        }
        addItem(new WatchUi.MenuItem("Repeat last", lastName(), :last, null));
        addItem(new WatchUi.MenuItem("Quick Interval", quickName(loadQuick()), :quick, null));
        addItem(new WatchUi.MenuItem("Stopwatch", "Laps, count up", :stopwatch, null));
        addItem(new WatchUi.MenuItem("Countdown", "Pick a time", :countdown, null));
        addItem(new WatchUi.MenuItem("Presets", "EMOM, Tabata, runs...", :presets, null));
        addItem(new WatchUi.MenuItem("My Presets", myCountText(), :mine, null));
        if (SYNC_URL.length() > 0) {
            addItem(new WatchUi.MenuItem("Sync now", gSyncMsg, :sync, null));
        }
    }

    // refresh sub-labels whenever we come back to this menu
    function onShow() {
        Menu2.onShow();
        setSub(:last, lastName());
        setSub(:quick, quickName(loadQuick()));
        setSub(:mine, myCountText());
        setSub(:sync, gSyncMsg);
    }

    function setSub(id, text) {
        var i = findItemById(id);
        if (i >= 0) {
            getItem(i).setSubLabel(text);
        }
    }
}

function openMainMenu() {
    WatchUi.pushView(new MainMenu(), new MainMenuDelegate(), WatchUi.SLIDE_UP);
}

function lastName() {
    var last = Storage.getValue("last");
    return last == null ? "Nothing yet" : getStr(last, "name", "");
}

function myCountText() {
    var n = loadList("custom").size();
    return n == 0 ? "Empty" : n.toString() + " saved";
}

function loadList(key) {
    var v = Storage.getValue(key);
    if (v == null || !(v instanceof Lang.Array)) {
        return [];
    }
    return v;
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        if (id instanceof Lang.Number) {
            var synced = loadList("synced");
            if (id < synced.size()) {
                launchWorkout(synced[id]);
            }
        } else if (id == :last) {
            var last = Storage.getValue("last");
            if (last != null) {
                launchWorkout(last);
            }
        } else if (id == :quick) {
            openQuickMenu();
        } else if (id == :stopwatch) {
            launchWorkout(stopwatchWorkout());
        } else if (id == :countdown) {
            openValuePicker("Countdown", durationValues(false), :dur, 300, new CountdownPicked());
        } else if (id == :presets) {
            openWorkoutList("Presets", builtInPresets(), null);
        } else if (id == :mine) {
            openMyPresets();
        } else if (id == :sync) {
            startSync(item);
        }
    }
}

class CountdownPicked {
    function initialize() {
    }

    function onPicked(value) {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (value > 0) {
            launchWorkout(countdownWorkout(value));
        }
    }
}

// ---------- simple list of workouts ----------

function openWorkoutList(title, workouts, storeKey) {
    var m = new WatchUi.Menu2({:title => title});
    for (var i = 0; i < workouts.size(); i++) {
        m.addItem(new WatchUi.MenuItem(getStr(workouts[i], "name", "Workout"), summary(workouts[i]), i, null));
    }
    WatchUi.pushView(m, new WorkoutListDelegate(workouts, storeKey), WatchUi.SLIDE_LEFT);
}

// "8 rounds - 4:00"
function summary(w) {
    var rounds = getNum(w, "rounds", 1);
    var steps = w.get("steps");
    var total = getNum(w, "prep", 0);
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
    var txt = rounds > 1 ? rounds.toString() + " rounds" : "1 round";
    if (open) {
        return txt + " - open";
    }
    return txt + " - " + fmtTime(total);
}

class WorkoutListDelegate extends WatchUi.Menu2InputDelegate {
    hidden var list;
    hidden var storeKey;   // "custom" when items can be deleted

    function initialize(workouts, key) {
        Menu2InputDelegate.initialize();
        list = workouts;
        storeKey = key;
    }

    function onSelect(item) {
        var i = item.getId();
        if (storeKey == null) {
            launchWorkout(list[i]);
            return;
        }
        var m = new WatchUi.Menu2({:title => getStr(list[i], "name", "")});
        m.addItem(new WatchUi.MenuItem("Start", null, :start, null));
        m.addItem(new WatchUi.MenuItem("Delete", null, :delete, null));
        WatchUi.pushView(m, new PresetActionDelegate(list, storeKey, i), WatchUi.SLIDE_LEFT);
    }
}

class PresetActionDelegate extends WatchUi.Menu2InputDelegate {
    hidden var list;
    hidden var storeKey;
    hidden var index;

    function initialize(l, key, i) {
        Menu2InputDelegate.initialize();
        list = l;
        storeKey = key;
        index = i;
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :start) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            launchWorkout(list[index]);
        } else if (id == :delete) {
            var stored = loadList(storeKey);
            if (index < stored.size()) {
                var kept = [];
                for (var i = 0; i < stored.size(); i++) {
                    if (i != index) {
                        kept.add(stored[i]);
                    }
                }
                Storage.setValue(storeKey, kept);
            }
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
    }
}

function openMyPresets() {
    var custom = loadList("custom");
    if (custom.size() == 0) {
        var m = new WatchUi.Menu2({:title => "My Presets"});
        m.addItem(new WatchUi.MenuItem("Nothing saved", "Use Quick Interval > Save", :none, null));
        WatchUi.pushView(m, new EmptyDelegate(), WatchUi.SLIDE_LEFT);
        return;
    }
    openWorkoutList("My Presets", custom, "custom");
}

class EmptyDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// ---------- quick interval builder ----------

function loadQuick() {
    var q = Storage.getValue("quick");
    if (q == null) {
        q = {"w" => 40, "r" => 20, "n" => 8, "p" => 10};
    }
    return q;
}

function openQuickMenu() {
    var q = loadQuick();
    var m = new WatchUi.Menu2({:title => "Quick Interval"});
    m.addItem(new WatchUi.MenuItem("Start", quickName(q), :go, null));
    m.addItem(new WatchUi.MenuItem("Work", durLabel(getNum(q, "w", 40), true), :qw, null));
    m.addItem(new WatchUi.MenuItem("Rest", durLabel(getNum(q, "r", 20), false), :qr, null));
    m.addItem(new WatchUi.MenuItem("Rounds", getNum(q, "n", 8).toString(), :qn, null));
    m.addItem(new WatchUi.MenuItem("Get ready", prepLabel(getNum(q, "p", 10)), :qp, null));
    m.addItem(new WatchUi.MenuItem("Save to My Presets", null, :save, null));
    WatchUi.pushView(m, new QuickMenuDelegate(m), WatchUi.SLIDE_LEFT);
}

function durLabel(v, isWork) {
    if (v == 0) {
        return isWork ? "Open (LAP to end)" : "No rest";
    }
    return fmtTime(v);
}

function prepLabel(v) {
    return v == 0 ? "Off" : v.toString() + "s";
}

class QuickMenuDelegate extends WatchUi.Menu2InputDelegate {
    hidden var menu;

    function initialize(m) {
        Menu2InputDelegate.initialize();
        menu = m;
    }

    function onSelect(item) {
        var id = item.getId();
        var q = loadQuick();
        if (id == :go) {
            launchWorkout(quickWorkout(q));
        } else if (id == :save) {
            var list = loadList("custom");
            list.add(quickWorkout(q));
            Storage.setValue("custom", list);
            item.setSubLabel("Saved: " + quickName(q));
            WatchUi.requestUpdate();
        } else if (id == :qw) {
            openValuePicker("Work", durationValues(true), :durWork, getNum(q, "w", 40), new QuickPicked(menu, "w", :qw));
        } else if (id == :qr) {
            openValuePicker("Rest", durationValues(true), :durRest, getNum(q, "r", 20), new QuickPicked(menu, "r", :qr));
        } else if (id == :qn) {
            openValuePicker("Rounds", roundValues(), :count, getNum(q, "n", 8), new QuickPicked(menu, "n", :qn));
        } else if (id == :qp) {
            openValuePicker("Get ready", [0, 5, 10, 15, 20, 30], :prep, getNum(q, "p", 10), new QuickPicked(menu, "p", :qp));
        }
    }
}

class QuickPicked {
    hidden var menu;
    hidden var key;
    hidden var itemId;

    function initialize(m, k, itemSym) {
        menu = m;
        key = k;
        itemId = itemSym;
    }

    function onPicked(value) {
        var q = loadQuick();
        q.put(key, value);
        Storage.setValue("quick", q);

        var i = menu.findItemById(itemId);
        if (i >= 0) {
            var txt = value.toString();
            if (key.equals("w")) {
                txt = durLabel(value, true);
            } else if (key.equals("r")) {
                txt = durLabel(value, false);
            } else if (key.equals("p")) {
                txt = prepLabel(value);
            }
            menu.getItem(i).setSubLabel(txt);
        }
        var g = menu.findItemById(:go);
        if (g >= 0) {
            menu.getItem(g).setSubLabel(quickName(q));
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

// ---------- value picker ----------

function durationValues(withZero) {
    var v = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 75, 90, 105, 120, 150, 180, 210, 240, 300,
        360, 420, 480, 540, 600, 720, 900, 1200, 1500, 1800, 2400, 3000, 3600];
    if (!withZero) {
        return v;
    }
    var out = [0];
    for (var i = 0; i < v.size(); i++) {
        out.add(v[i]);
    }
    return out;
}

function roundValues() {
    var v = [];
    for (var i = 1; i <= 50; i++) {
        v.add(i);
    }
    return v;
}

function openValuePicker(title, values, kind, current, owner) {
    var start = 0;
    for (var i = 0; i < values.size(); i++) {
        if (values[i] == current) {
            start = i;
            break;
        }
    }
    var picker = new WatchUi.Picker({
        :title => new WatchUi.Text({
            :text => title,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_BOTTOM,
            :color => Graphics.COLOR_WHITE
        }),
        :pattern => [new ValueFactory(values, kind)],
        :defaults => [start]
    });
    WatchUi.pushView(picker, new ValuePickerDelegate(owner), WatchUi.SLIDE_UP);
}

class ValueFactory extends WatchUi.PickerFactory {
    hidden var values;
    hidden var kind;

    function initialize(v, k) {
        PickerFactory.initialize();
        values = v;
        kind = k;
    }

    function getSize() {
        return values.size();
    }

    function getValue(index) {
        return values[index];
    }

    function getDrawable(index, selected) {
        return new WatchUi.Text({
            :text => label(values[index]),
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_MEDIUM,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }

    hidden function label(v) {
        if (kind == :count) {
            return v.toString();
        }
        if (kind == :prep) {
            return prepLabel(v);
        }
        if (v == 0) {
            return kind == :durWork ? "Open" : "None";
        }
        return fmtTime(v);
    }
}

class ValuePickerDelegate extends WatchUi.PickerDelegate {
    hidden var owner;

    function initialize(o) {
        PickerDelegate.initialize();
        owner = o;
    }

    function onAccept(values) {
        owner.onPicked(values[0]);
        return true;
    }

    function onCancel() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}

// ---------- sync from phone ----------
// Expects JSON: {"presets": [ <workout>, ... ]}  (format in Presets.mc)
// Runs automatically when the app opens, and from "Sync now" in the menu.

var gSyncItem = null;
var gSyncHandler = null;
var gSyncMsg = "Not synced yet";
var gSyncBusy = false;

function startSync(item) {
    gSyncItem = item;
    if (SYNC_URL.length() == 0 || gSyncBusy) {
        return;
    }
    if (!(Toybox has :Communications)) {
        return;
    }
    if (gSyncHandler == null) {
        gSyncHandler = new SyncHandler();
    }
    gSyncBusy = true;
    gSyncMsg = "Syncing...";
    if (item != null) {
        item.setSubLabel(gSyncMsg);
    }
    WatchUi.requestUpdate();
    try {
        Communications.makeWebRequest(
            SYNC_URL,
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            gSyncHandler.method(:onResponse)
        );
    } catch (e) {
        gSyncBusy = false;
        gSyncMsg = "Sync unavailable";
    }
}

class SyncHandler {
    function initialize() {
    }

    function onResponse(code, data) as Void {
        handleSync(code, data);
    }
}

function handleSync(code, data) {
    gSyncBusy = false;
    var msg = "Sync failed (" + code.toString() + ")";
    if (code == 200 && data instanceof Lang.Dictionary) {
        var list = data.get("presets");
        if (list instanceof Lang.Array) {
            var clean = [];
            for (var i = 0; i < list.size(); i++) {
                var w = list[i];
                if (w instanceof Lang.Dictionary && w.get("steps") instanceof Lang.Array) {
                    clean.add(w);
                }
            }
            Storage.setValue("synced", clean);
            msg = "Synced " + clean.size().toString() + " workouts";
        }
    } else if (code == -104 || code == -2) {
        msg = "Phone not connected";
    }
    gSyncMsg = msg;
    if (gSyncItem != null) {
        gSyncItem.setSubLabel(msg);
    }
    WatchUi.requestUpdate();
}
