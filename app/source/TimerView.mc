import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Venu Sq buttons: top = START/STOP, bottom = BACK/LAP.
//   Before start:  START starts, BACK leaves.
//   Running:       START pauses (menu), BACK = lap / skip to next step.
//   Touch is ignored while a workout is running, so a sweaty wrist can't pause it.
// CAPACITY palette (see the "Capacity Clock - Watch" design canvas)
const C_BG = 0x121213;
const C_INK = 0x16151A;
const C_TEXT = 0xF5F5F5;
const C_TEXT2 = 0xB4B4B8;
const C_TEXT3 = 0x85848B;
const C_HAIR = 0x2E2D32;
const C_GOLD = 0xCEA85E;
const C_COPPER = 0xC67832;
const C_REST = 0x3D3C42;

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
        var left = w * 12 / 100;
        var right = w * 88 / 100;
        var bandH = h * 24 / 100;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(C_TEXT, C_BG);
        dc.clear();

        // ---- phase band ----
        var label = "";
        var bandFill = null;     // null = no fill, gold label on a hairline
        var labelColor = C_GOLD;
        var barColor = C_GOLD;
        var kind = "";

        if (!e.started) {
            label = "READY";
        } else if (e.finished) {
            label = "DONE";
        } else if (!e.running) {
            label = "PAUSED";
        } else {
            kind = e.kinds[e.idx];
            label = e.labels[e.idx];
            if (kind.equals("prep")) {
                bandFill = C_COPPER;
                labelColor = C_INK;
                barColor = C_COPPER;
            } else if (kind.equals("work")) {
                bandFill = C_GOLD;
                labelColor = C_INK;
                barColor = C_GOLD;
            } else if (kind.equals("rest")) {
                bandFill = C_REST;
                labelColor = C_TEXT;
                barColor = C_TEXT2;
            } else {
                bandFill = C_TEXT;
                labelColor = C_INK;
                barColor = C_TEXT2;
            }
        }

        if (bandFill != null) {
            dc.setColor(bandFill, bandFill);
            dc.fillRectangle(0, 0, w, bandH);
        } else {
            dc.setColor(C_HAIR, C_HAIR);
            dc.fillRectangle(0, bandH, w, 1);
        }
        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, bandH * 64 / 100, Graphics.FONT_MEDIUM, label, center);

        // ---- second line ----
        var sub = "";
        if (!e.started || e.finished) {
            sub = e.name;
        } else {
            sub = roundText(e);
        }
        dc.setColor(C_TEXT2, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 31 / 100, Graphics.FONT_TINY, sub, center);

        // ---- big clock ----
        var big = 0;
        if (!e.started) {
            big = e.durs[0];
        } else if (e.finished) {
            big = e.totalMs() / 1000;
        } else {
            big = e.displaySeconds();
        }
        var t = fmtTime(big);
        var fonts = [Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM];
        var font = fonts[fonts.size() - 1];
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(t, fonts[i]) <= w * 90 / 100) {
                font = fonts[i];
                break;
            }
        }
        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 53 / 100, font, t, center);

        // ---- ready ----
        if (!e.started) {
            dc.setColor(C_GOLD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 77 / 100, Graphics.FONT_TINY, "START TO GO", center);
            dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 87 / 100, Graphics.FONT_XTINY, planText(e), center);
            return;
        }

        // ---- done ----
        if (e.finished) {
            dc.setColor(C_TEXT2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left, h * 75 / 100, Graphics.FONT_XTINY, e.roundTotal.toString() + (e.roundTotal == 1 ? " ROUND" : " ROUNDS"), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            var avg = avgHeartRate();
            if (avg != null) {
                dc.drawText(right, h * 75 / 100, Graphics.FONT_XTINY, "AVG HR " + avg.toString(), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
            dc.setColor(C_GOLD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 87 / 100, Graphics.FONT_TINY, "START = SAVE", center);
            return;
        }

        // ---- progress bar, or the LAP hint for open intervals ----
        var d = e.durs[e.idx];
        var barY = h * 73 / 100;
        var barH = h / 40;
        if (barH < 4) {
            barH = 4;
        }
        if (d > 0) {
            var frac = e.stepMs() * 100 / (d * 1000);
            if (frac > 100) {
                frac = 100;
            }
            dc.setColor(C_HAIR, C_HAIR);
            dc.fillRectangle(left, barY, right - left, barH);
            dc.setColor(e.running ? barColor : C_TEXT3, C_BG);
            dc.fillRectangle(left, barY, (right - left) * frac / 100, barH);
        } else if (!(e.loopLast && e.isLastStep())) {
            dc.setColor(C_GOLD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, barY + barH / 2, Graphics.FONT_XTINY, "PRESS LAP WHEN DONE", center);
        }

        // ---- next ----
        var next = nextText(e);
        if (next.length() > 0) {
            dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 80 / 100, Graphics.FONT_XTINY, next, center);
        }

        // ---- total + heart rate ----
        dc.setColor(C_TEXT2, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, h * 89 / 100, Graphics.FONT_XTINY, "TOTAL " + fmtTime(e.totalMs() / 1000), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var hr = heartRate();
        if (hr != null) {
            dc.drawText(right, h * 89 / 100, Graphics.FONT_XTINY, "HR " + hr.toString(), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    hidden function roundText(e) {
        if (e.loopLast && e.isLastStep()) {
            return "LAP " + e.lapCount.toString();
        }
        var r = e.roundOf[e.idx];
        if (e.roundTotal > 1 && r > 0) {
            return "ROUND " + r.toString() + " / " + e.roundTotal.toString();
        }
        if (e.kinds[e.idx].equals("up")) {
            return "CAP " + fmtTime(e.durs[e.idx]);
        }
        return e.name;
    }

    hidden function nextText(e) {
        if (e.isLastStep()) {
            if (e.loopLast) {
                return "LAP TIME " + fmtTime(e.stepMs() / 1000);
            }
            return "LAST ONE";
        }
        var n = e.idx + 1;
        var s = "NEXT  " + e.labels[n];
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
        var s = e.roundTotal > 1 ? e.roundTotal.toString() + " rounds" : "";
        if (open) {
            return s.length() > 0 ? s + " - LAP ends open intervals" : "LAP ends open intervals";
        }
        return s.length() > 0 ? s + " - " + fmtTime(total) : fmtTime(total);
    }

    hidden function heartRate() {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate;
        }
        return null;
    }

    hidden function avgHeartRate() {
        var info = Activity.getActivityInfo();
        if (info != null && info.averageHeartRate != null) {
            return info.averageHeartRate;
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
