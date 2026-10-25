import Toybox.Lang;

// Workout format (same shape as the sync JSON):
// {
//   "name"   => "Tabata",
//   "prep"   => 10,            // seconds of GET READY before round 1 (optional)
//   "rounds" => 8,             // how many times "steps" repeats (optional, default 1)
//   "loop"   => true,          // stopwatch only: LAP starts a new lap forever (optional)
//   "steps"  => [
//       {"l" => "WORK", "s" => 20},              // label, seconds (0 = open, ends on LAP)
//       {"l" => "REST", "s" => 10, "k" => "rest"} // kind: work | rest | up (count up to a cap)
//   ]
// }
// The final rest of the final round is dropped automatically.

function builtInPresets() {
    return [
        {"name" => "Tabata 20/10 x8", "prep" => 10, "rounds" => 8,
            "steps" => [{"l" => "WORK", "s" => 20}, {"l" => "REST", "s" => 10, "k" => "rest"}]},
        {"name" => "EMOM 10", "prep" => 10, "rounds" => 10,
            "steps" => [{"l" => "MINUTE", "s" => 60}]},
        {"name" => "EMOM 20", "prep" => 10, "rounds" => 20,
            "steps" => [{"l" => "MINUTE", "s" => 60}]},
        {"name" => "E2MOM x5", "prep" => 10, "rounds" => 5,
            "steps" => [{"l" => "EVERY 2", "s" => 120}]},
        {"name" => "30/30 x10", "prep" => 10, "rounds" => 10,
            "steps" => [{"l" => "WORK", "s" => 30}, {"l" => "REST", "s" => 30, "k" => "rest"}]},
        {"name" => "40/20 x10", "prep" => 10, "rounds" => 10,
            "steps" => [{"l" => "WORK", "s" => 40}, {"l" => "REST", "s" => 20, "k" => "rest"}]},
        {"name" => "1:00 on/off x10", "prep" => 10, "rounds" => 10,
            "steps" => [{"l" => "WORK", "s" => 60}, {"l" => "REST", "s" => 60, "k" => "rest"}]},
        {"name" => "Run reps 6x + 1:30", "prep" => 0, "rounds" => 6,
            "steps" => [{"l" => "RUN", "s" => 0}, {"l" => "REST", "s" => 90, "k" => "rest"}]},
        {"name" => "Run 3:00/1:00 x6", "prep" => 10, "rounds" => 6,
            "steps" => [{"l" => "RUN", "s" => 180}, {"l" => "EASY", "s" => 60, "k" => "rest"}]},
        {"name" => "AMRAP 12", "prep" => 10, "rounds" => 1,
            "steps" => [{"l" => "AMRAP", "s" => 720}]},
        {"name" => "AMRAP 20", "prep" => 10, "rounds" => 1,
            "steps" => [{"l" => "AMRAP", "s" => 1200}]},
        {"name" => "For Time cap 15", "prep" => 10, "rounds" => 1,
            "steps" => [{"l" => "FOR TIME", "s" => 900, "k" => "up"}]}
    ];
}

function stopwatchWorkout() {
    return {"name" => "Stopwatch", "prep" => 0, "rounds" => 1, "loop" => true,
        "steps" => [{"l" => "STOPWATCH", "s" => 0}]};
}

function countdownWorkout(sec) {
    return {"name" => "Countdown " + fmtTime(sec), "prep" => 0, "rounds" => 1,
        "steps" => [{"l" => "TIMER", "s" => sec}]};
}

// Quick Interval config -> workout. cfg keys: w (work), r (rest), n (rounds), p (prep)
function quickWorkout(cfg) {
    var w = getNum(cfg, "w", 40);
    var r = getNum(cfg, "r", 20);
    var n = getNum(cfg, "n", 8);
    var p = getNum(cfg, "p", 10);
    var workLabel = w == 0 ? "GO" : "WORK";
    return {"name" => quickName(cfg), "prep" => p, "rounds" => n,
        "steps" => [{"l" => workLabel, "s" => w}, {"l" => "REST", "s" => r, "k" => "rest"}]};
}

function quickName(cfg) {
    var w = getNum(cfg, "w", 40);
    var r = getNum(cfg, "r", 20);
    var n = getNum(cfg, "n", 8);
    var ws = w == 0 ? "Open" : fmtTime(w);
    var rs = r == 0 ? "no rest" : fmtTime(r);
    return ws + "/" + rs + " x" + n.toString();
}
