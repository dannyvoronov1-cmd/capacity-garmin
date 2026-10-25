import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// "Ring" design: black screen, one progress line around the edge,
// big condensed digits, almost nothing else.
//
// Venu Sq buttons: top = START/STOP, bottom = BACK/LAP.
//   Before start:  START starts, BACK leaves.
//   Running:       START pauses (menu), BACK = lap / skip to next step.
//   Touch is ignored while a workout is running, so a sweaty wrist can't pause it.
class TimerView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onShow() {
        useFonts([F_CLOCK_XL, F_CLOCK_LG, F_STAT, F_LABEL, F_SMALL, F_TINY]);
    }

    function onHide() {
        dropFonts();
    }

    function onUpdate(dc) {
        var e = gEngine;
        if (e == null) {
            return;
        }
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var C = Graphics.TEXT_JUSTIFY_CENTER;

        dc.setColor(C_TEXT, C_BG);
        dc.clear();

        if (!e.started) {
            drawReady(dc, e, w, h, cx);
            return;
        }
        if (e.finished) {
            drawDone(dc, e, w, h, cx);
            return;
        }

        var kind = e.kinds[e.idx];
        var label = e.labels[e.idx];
        var accent = C_GOLD;
        var digits = C_TEXT;
        if (kind.equals("rest")) {
            accent = C_TEXT2;
            digits = C_TEXT2;
        } else if (kind.equals("prep")) {
            accent = C_COPPER;
        } else if (kind.equals("open")) {
            accent = C_TEXT;
        }
        if (!e.running) {
            label = "PAUSED";
            digits = C_TEXT3;
        }

        // ring: fills with the interval; open intervals show the track only
        var frac = e.stepFrac();
        drawRing(dc, frac == null ? 0 : frac, e.running ? accent : C_TEXT3, C_TRACK);

        // phase label + round line
        txt(dc, cx, h * 20 / 100, F_LABEL, label, e.running ? accent : C_GOLD, C);
        txt(dc, cx, h * 28 / 100, F_SMALL, roundText(e), C_TEXT3, C);

        // the clock
        var t = fmtTime(e.displaySeconds());
        txt(dc, cx, h * 52 / 100, t.length() > 4 ? F_CLOCK_LG : F_CLOCK_XL, t, digits, C);

        // open interval hint / next + heart rate
        if (kind.equals("open") && !(e.loopLast && e.isLastStep())) {
            txt(dc, cx, h * 71 / 100, F_TINY, "LAP WHEN DONE", C_GOLD, C);
        }
        drawFooter(dc, e, w, h, cx);
    }

    hidden function drawReady(dc, e, w, h, cx) {
        var C = Graphics.TEXT_JUSTIFY_CENTER;
        drawRing(dc, 0, C_GOLD, C_TRACK);
        txt(dc, cx, h * 20 / 100, F_LABEL, "READY", C_GOLD, C);
        txt(dc, cx, h * 28 / 100, F_SMALL, e.name, C_TEXT3, C);
        var t = fmtTime(e.durs[0]);
        txt(dc, cx, h * 52 / 100, t.length() > 4 ? F_CLOCK_LG : F_CLOCK_XL, t, C_TEXT, C);
        txt(dc, cx, h * 74 / 100, F_SMALL, planText(e), C_TEXT3, C);
        txt(dc, cx, h * 84 / 100, F_LABEL, "START TO GO", C_GOLD, C);
    }

    hidden function drawDone(dc, e, w, h, cx) {
        var C = Graphics.TEXT_JUSTIFY_CENTER;
        drawRing(dc, 1.0, C_GOLD, null);
        txt(dc, cx, h * 20 / 100, F_LABEL, "DONE", C_GOLD, C);
        txt(dc, cx, h * 28 / 100, F_SMALL, e.name, C_TEXT3, C);
        txt(dc, cx, h * 46 / 100, F_CLOCK_LG, fmtTime(e.totalMs() / 1000), C_TEXT, C);

        // three stats: best open interval (or rounds), avg HR, max HR
        var best = e.bestOpenMs();
        var s1 = best != null ? fmtTime((best + 500) / 1000) : e.roundsDone().toString();
        var l1 = best != null ? "BEST" : "ROUNDS";
        var info = Activity.getActivityInfo();
        var avg = (info != null && info.averageHeartRate != null) ? info.averageHeartRate.toString() : "--";
        var mx = (info != null && info.maxHeartRate != null) ? info.maxHeartRate.toString() : "--";

        var colW = w * 26 / 100;
        var xs = [cx - colW, cx, cx + colW];
        var vals = [s1, avg, mx];
        var labels = [l1, "AVG HR", "MAX HR"];
        for (var i = 0; i < 3; i++) {
            txt(dc, xs[i], h * 67 / 100, F_STAT, vals[i], C_TEXT, C);
            txt(dc, xs[i], h * 75 / 100, F_TINY, labels[i], C_TEXT3, C);
        }
        txt(dc, cx, h * 86 / 100, F_LABEL, "START TO SAVE", C_GOLD, C);
    }

    // "NEXT  REST 0:20   [heart] 158" centred as one line
    hidden function drawFooter(dc, e, w, h, cx) {
        var y = h * 78 / 100;
        var next = nextText(e);
        var hr = heartRate();
        var hrStr = hr != null ? hr.toString() : "";
        var gap = 14;
        var wNext = next.length() > 0 ? txtWidth(dc, F_SMALL, next) : 0;
        var wHr = hrStr.length() > 0 ? 14 + txtWidth(dc, F_SMALL, hrStr) : 0;
        var total = wNext + wHr + (wNext > 0 && wHr > 0 ? gap : 0);
        var x = cx - total / 2;
        if (wNext > 0) {
            txt(dc, x, y, F_SMALL, next, C_TEXT2, Graphics.TEXT_JUSTIFY_LEFT);
            x += wNext + gap;
        }
        if (wHr > 0) {
            drawHeart(dc, x + 5, y - 1, C_COPPER);
            txt(dc, x + 14, y, F_SMALL, hrStr, C_TEXT2, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    hidden function roundText(e) {
        if (e.loopLast && e.isLastStep()) {
            return "LAP " + e.lapCount.toString();
        }
        var r = e.roundOf[e.idx];
        if (e.roundTotal > 1 && r > 0) {
            return "ROUND " + r.toString() + " OF " + e.roundTotal.toString();
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

    hidden function planText(e) {
        var total = 0;
        var open = false;
        for (var i = 0; i < e.durs.size(); i++) {
            if (e.durs[i] == 0) {
                open = true;
            }
            total += e.durs[i];
        }
        var s = e.roundTotal > 1 ? e.roundTotal.toString() + " ROUNDS" : "";
        var tail = open ? "LAP ENDS RUNS" : fmtTime(total);
        return s.length() > 0 ? s + " · " + tail : tail;
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
