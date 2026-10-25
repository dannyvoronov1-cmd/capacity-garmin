import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// The clock itself. A workout is expanded into a flat list of steps:
//   label, seconds (0 = open, ends on LAP), kind ("prep" | "work" | "rest" | "open" | "up"), round number.
// "up" steps count up toward a cap (For Time). Everything else with seconds > 0 counts down.
class Engine {

    var name = "";
    var labels = [];
    var durs = [];
    var kinds = [];
    var roundOf = [];
    var roundTotal = 1;
    var loopLast = false;   // stopwatch: LAP starts a new lap instead of finishing

    var idx = 0;
    var started = false;
    var running = false;
    var finished = false;
    var lapCount = 1;
    var actualMs = [];      // how long each finished step really took

    hidden var stepAccum = 0;
    hidden var stepMark = 0;
    hidden var totalAccum = 0;
    hidden var totalMark = 0;
    hidden var lastCue = -1;
    hidden var session = null;
    hidden var saved = false;
    hidden var timer = null;

    function initialize(w) {
        name = getStr(w, "name", "Workout");
        loopLast = w.get("loop") == true;
        var prep = getNum(w, "prep", 0);
        roundTotal = getNum(w, "rounds", 1);
        if (roundTotal < 1) {
            roundTotal = 1;
        }
        var steps = w.get("steps");
        if (steps == null || !(steps instanceof Lang.Array) || steps.size() == 0) {
            steps = [{"l" => "TIME", "s" => 0, "k" => "open"}];
        }

        if (prep > 0) {
            addStep("GET READY", prep, "prep", 0);
        }
        for (var r = 1; r <= roundTotal; r++) {
            for (var i = 0; i < steps.size(); i++) {
                var st = steps[i];
                var label = getStr(st, "l", "WORK");
                var sec = getNum(st, "s", 0);
                var kind = st.get("k");
                if (kind == null) {
                    if (label.toUpper().find("REST") != null) {
                        kind = "rest";
                    } else {
                        kind = "work";
                    }
                }
                if (kind.equals("rest") && sec <= 0) {
                    continue;   // a zero rest means no rest
                }
                if (sec <= 0 && !kind.equals("rest")) {
                    kind = "open";
                }
                // no trailing rest after the final round
                if (r == roundTotal && i == steps.size() - 1 && kind.equals("rest") && labels.size() > 0) {
                    continue;
                }
                addStep(label, sec, kind, r);
            }
        }
        if (labels.size() == 0) {
            addStep("TIME", 0, "open", 1);
        }

        timer = new Timer.Timer();
        timer.start(method(:onTick), 200, true);
    }

    hidden function addStep(label, sec, kind, round) {
        labels.add(label);
        durs.add(sec);
        kinds.add(kind);
        roundOf.add(round);
    }

    // ---------- time ----------

    function stepMs() {
        if (running) {
            return stepAccum + (System.getTimer() - stepMark);
        }
        return stepAccum;
    }

    function totalMs() {
        if (running) {
            return totalAccum + (System.getTimer() - totalMark);
        }
        return totalAccum;
    }

    // Seconds to show big on screen for the current step.
    function displaySeconds() {
        var d = durs[idx];
        var ms = stepMs();
        if (d > 0 && !kinds[idx].equals("up")) {
            var rem = d * 1000 - ms;
            if (rem < 0) {
                rem = 0;
            }
            return (rem + 999) / 1000;
        }
        return ms / 1000;
    }

    function isLastStep() {
        return idx >= labels.size() - 1;
    }

    // ---------- controls ----------

    function start() {
        if (finished) {
            return;
        }
        if (!started) {
            started = true;
            startSession();
            buzzStart(kinds[0]);
        }
        resume();
    }

    function pause() {
        if (!running) {
            return;
        }
        stepAccum = stepMs();
        totalAccum = totalMs();
        running = false;
        if (session != null && session.isRecording()) {
            session.stop();
        }
        WatchUi.requestUpdate();
    }

    function resume() {
        if (finished || running) {
            return;
        }
        var now = System.getTimer();
        stepMark = now;
        totalMark = now;
        running = true;
        if (session != null && !session.isRecording()) {
            session.start();
        }
        WatchUi.requestUpdate();
    }

    // LAP / bottom button while running.
    function lap() {
        if (!running) {
            return;
        }
        if (loopLast && isLastStep()) {
            lapCount++;
            stepAccum = 0;
            stepMark = System.getTimer();
            addSessionLap();
            vibe([new Attention.VibeProfile(80, 200)]);
            WatchUi.requestUpdate();
            return;
        }
        advance(0);
    }

    function onTick() as Void {
        if (running) {
            var guard = 0;
            while (running && !finished && durs[idx] > 0 && guard < 50) {
                var over = stepMs() - durs[idx] * 1000;
                if (over >= 0) {
                    advance(over);
                    guard++;
                } else {
                    var remSec = (-over + 999) / 1000;
                    if (remSec <= 3 && remSec != lastCue) {
                        lastCue = remSec;
                        cue();
                    }
                    break;
                }
            }
        }
        WatchUi.requestUpdate();
    }

    hidden function advance(carryMs) {
        if (isLastStep()) {
            finish();
            return;
        }
        recordStep();
        addSessionLap();
        idx++;
        stepAccum = carryMs;
        stepMark = System.getTimer();
        lastCue = -1;
        buzzStart(kinds[idx]);
        WatchUi.requestUpdate();
    }

    hidden function finish() {
        recordStep();
        totalAccum = totalMs();
        stepAccum = stepMs();
        running = false;
        finished = true;
        if (session != null && session.isRecording()) {
            session.stop();
        }
        vibe([
            new Attention.VibeProfile(100, 600),
            new Attention.VibeProfile(0, 200),
            new Attention.VibeProfile(100, 600),
            new Attention.VibeProfile(0, 200),
            new Attention.VibeProfile(100, 900)
        ]);
        tone(:finish);
        light();
        WatchUi.requestUpdate();
    }

    hidden function recordStep() {
        var d = durs[idx];
        if (d > 0 && !kinds[idx].equals("up")) {
            actualMs.add(d * 1000);
        } else {
            actualMs.add(stepMs());
        }
    }

    // Fastest open (LAP-ended) work step, in ms. Null when there were none.
    function bestOpenMs() {
        var best = null;
        for (var i = 0; i < actualMs.size() && i < kinds.size(); i++) {
            if (kinds[i].equals("open")) {
                if (best == null || actualMs[i] < best) {
                    best = actualMs[i];
                }
            }
        }
        return best;
    }

    // How many rounds were started.
    function roundsDone() {
        if (finished) {
            return roundTotal;
        }
        var r = roundOf[idx];
        return r > 0 ? r : 0;
    }

    // Progress of the current step, 0..1. Null for open steps.
    function stepFrac() {
        var d = durs[idx];
        if (d <= 0) {
            return null;
        }
        var f = stepMs().toFloat() / (d * 1000);
        return f > 1 ? 1.0 : f;
    }

    // ---------- recording ----------

    hidden function startSession() {
        if (!(Toybox has :ActivityRecording)) {
            return;
        }
        try {
            if (Sensor has :setEnabledSensors) {
                Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
            }
            var n = name;
            if (n.length() > 15) {
                n = n.substring(0, 15);
            }
            session = ActivityRecording.createSession({
                :name => n,
                :sport => ActivityRecording.SPORT_TRAINING,
                :subSport => ActivityRecording.SUB_SPORT_CARDIO_TRAINING
            });
        } catch (e) {
            session = null;
        }
    }

    hidden function addSessionLap() {
        if (session != null && session.isRecording()) {
            session.addLap();
        }
    }

    function save() {
        if (session != null && !saved) {
            if (session.isRecording()) {
                session.stop();
            }
            session.save();
            saved = true;
            session = null;
        }
    }

    function discard() {
        if (session != null && !saved) {
            if (session.isRecording()) {
                session.stop();
            }
            session.discard();
            session = null;
        }
    }

    function hasSession() {
        return session != null;
    }

    // Called when the timer screen closes or the app exits.
    function shutdown() {
        if (timer != null) {
            timer.stop();
            timer = null;
        }
        if (session != null && !saved) {
            // app closed without a choice: keep anything longer than a minute
            if (totalMs() > 60000) {
                save();
            } else {
                discard();
            }
        }
        running = false;
    }

    // ---------- alerts ----------

    hidden function cue() {
        vibe([new Attention.VibeProfile(60, 120)]);
        tone(:cue);
    }

    hidden function buzzStart(kind) {
        if (kind.equals("rest")) {
            vibe([new Attention.VibeProfile(100, 700)]);
        } else {
            vibe([
                new Attention.VibeProfile(100, 350),
                new Attention.VibeProfile(0, 150),
                new Attention.VibeProfile(100, 350)
            ]);
        }
        tone(:go);
        light();
    }

    hidden function vibe(pattern) {
        if (Attention has :vibrate) {
            Attention.vibrate(pattern);
        }
    }

    hidden function tone(which) {
        if (!(Attention has :playTone)) {
            return;
        }
        try {
            if (which == :cue) {
                Attention.playTone(Attention.TONE_KEY);
            } else if (which == :finish) {
                Attention.playTone(Attention.TONE_SUCCESS);
            } else {
                Attention.playTone(Attention.TONE_INTERVAL_ALERT);
            }
        } catch (e) {
        }
    }

    hidden function light() {
        if (Attention has :backlight) {
            try {
                Attention.backlight(true);
            } catch (e) {
            }
        }
    }
}
