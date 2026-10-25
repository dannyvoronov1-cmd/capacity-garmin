import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Venu Sq buttons: top = START/STOP, bottom = BACK/LAP.
//   Before start:  START starts, BACK leaves.
//   Running:       START pauses (menu), BACK = lap / skip to next step.
//   Touch is ignored while a workout is running, so a sweaty wrist can't pause it.
class TimerView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) {
        var e = gEngine;
        if (e == null) {
            return;
        }
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        var bg = Graphics.COLOR_BLACK;
        var fg = Graphics.COLOR_WHITE;
        var accent = Graphics.COLOR_YELLOW;
        var label = "";
        var sub = "";
        var big = 0;

        if (!e.started) {
            label = "READY";
            sub = e.name;
            big = e.durs[0];
        } else if (e.finished) {
            label = "DONE";
            sub = e.name;
            big = e.totalMs() / 1000;
            accent = Graphics.COLOR_GREEN;
        } else {
            var kind = e.kinds[e.idx];
            label = e.labels[e.idx];
            big = e.displaySeconds();
            if (!e.running) {
                label = "PAUSED";
            } else if (kind.equals("prep")) {
                bg = Graphics.COLOR_ORANGE;
                fg = Graphics.COLOR_BLACK;
                accent = Graphics.COLOR_BLACK;
            } else if (kind.equals("work")) {
                bg = Graphics.COLOR_DK_GREEN;
                accent = Graphics.COLOR_WHITE;
            } else if (kind.equals("rest")) {
                bg = Graphics.COLOR_DK_RED;
                accent = Graphics.COLOR_WHITE;
            } else {
                bg = Graphics.COLOR_DK_BLUE;
                accent = Graphics.COLOR_WHITE;
            }
            sub = roundText(e);
        }

        dc.setColor(fg, bg);
        dc.clear();

        // phase label
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 14 / 100, Graphics.FONT_MEDIUM, label, center);

        // round / name line
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 26 / 100, Graphics.FONT_TINY, sub, center);

        // big clock
        var t = fmtTime(big);
        var fonts = [Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM];
        var font = fonts[fonts.size() - 1];
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(t, fonts[i]) <= w * 92 / 100) {
                font = fonts[i];
                break;
            }
        }
        dc.drawText(cx, h * 50 / 100, font, t, center);

        // bottom lines
        if (!e.started) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 74 / 100, Graphics.FONT_TINY, "START to go", center);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 85 / 100, Graphics.FONT_XTINY, stepCountText(e), center);
            return;
        }
        if (e.finished) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 76 / 100, Graphics.FONT_TINY, "START = save", center);
            return;
        }

        dc.drawText(cx, h * 72 / 100, Graphics.FONT_TINY, "TOTAL " + fmtTime(e.totalMs() / 1000), center);

        var next = nextText(e);
        if (next.length() > 0) {
            dc.drawText(cx, h * 81 / 100, Graphics.FONT_XTINY, next, center);
        }

        var hr = heartRate();
        if (hr != null) {
            dc.drawText(cx, h * 90 / 100, Graphics.FONT_XTINY, "HR " + hr.toString(), center);
        }
    }

    hidden function roundText(e) {
        if (e.loopLast && e.isLastStep()) {
            return "LAP " + e.lapCount.toString();
        }
        var r = e.roundOf[e.idx];
        if (e.roundTotal > 1 && r > 0) {
            return "ROUND " + r.toString() + "/" + e.roundTotal.toString();
        }
        if (e.kinds[e.idx].equals("open")) {
            return "LAP when done";
        }
        if (e.kinds[e.idx].equals("up")) {
            return "CAP " + fmtTime(e.durs[e.idx]);
        }
        return e.name;
    }

    hidden function nextText(e) {
        if (e.isLastStep()) {
            if (e.loopLast) {
                return "LAP " + fmtTime(e.stepMs() / 1000);
            }
            return "LAST ONE";
        }
        var n = e.idx + 1;
        var s = "NEXT " + e.labels[n];
        if (e.durs[n] > 0) {
            s = s + " " + fmtTime(e.durs[n]);
        }
        return s;
    }

    hidden function stepCountText(e) {
        var total = 0;
        for (var i = 0; i < e.durs.size(); i++) {
            total += e.durs[i];
        }
        if (total > 0) {
            return fmtTime(total) + " planned";
        }
        return "";
    }

    hidden function heartRate() {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate;
        }
        return null;
    }
}

class TimerDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // top button
    function onSelect() {
        var e = gEngine;
        if (e == null) {
            return false;
        }
        if (e.finished) {
            openFinishMenu();
        } else if (!e.started) {
            e.start();
        } else if (e.running) {
            e.pause();
            openPauseMenu();
        } else {
            e.resume();
        }
        return true;
    }

    // bottom button / swipe right
    function onBack() {
        var e = gEngine;
        if (e == null) {
            return false;
        }
        if (!e.started) {
            closeWorkout(0);
            return true;
        }
        if (e.finished) {
            openFinishMenu();
            return true;
        }
        if (e.running) {
            e.lap();
            return true;
        }
        openPauseMenu();
        return true;
    }

    function onMenu() {
        return true;
    }

    // ignore touch once the workout has started
    function onTap(evt) {
        return gEngine != null && gEngine.started;
    }

    function onSwipe(evt) {
        return gEngine != null && gEngine.started;
    }
}

// ---------- pause / finish menus ----------

function openPauseMenu() {
    var m = new WatchUi.Menu2({:title => "Paused"});
    m.addItem(new WatchUi.MenuItem("Resume", null, :resume, null));
    m.addItem(new WatchUi.MenuItem("End + Save", null, :save, null));
    m.addItem(new WatchUi.MenuItem("End + Discard", null, :discard, null));
    WatchUi.pushView(m, new EndMenuDelegate(), WatchUi.SLIDE_UP);
}

function openFinishMenu() {
    var m = new WatchUi.Menu2({:title => "Done"});
    m.addItem(new WatchUi.MenuItem("Save", null, :save, null));
    m.addItem(new WatchUi.MenuItem("Discard", null, :discard, null));
    WatchUi.pushView(m, new EndMenuDelegate(), WatchUi.SLIDE_UP);
}

class EndMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        if (gEngine == null) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return;
        }
        if (id == :resume) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            gEngine.resume();
        } else if (id == :save) {
            gEngine.save();
            closeWorkout(1);
        } else if (id == :discard) {
            gEngine.discard();
            closeWorkout(1);
        }
    }
}
