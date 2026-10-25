import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// ---------- CAPACITY palette ("Ring" direction) ----------
const C_BG = 0x0A0A0B;
const C_INK = 0x16151A;
const C_TEXT = 0xF5F5F5;
const C_TEXT2 = 0xB4B4B8;
const C_TEXT3 = 0x85848B;
const C_TRACK = 0x2E2D32;
const C_GOLD = 0xCEA85E;
const C_COPPER = 0xC67832;

// ---------- custom fonts (Barlow Condensed, OFL) ----------
// Each entry: font resource, vertical offset from the top of the line to
// the middle of a capital letter, and a stock font to fall back to when a
// string has characters the bitmap font doesn't carry (e.g. Hebrew).
const F_CLOCK_XL = 0;
const F_CLOCK_LG = 1;
const F_TITLE = 2;
const F_STAT = 3;
const F_LABEL = 4;
const F_SMALL = 5;
const F_TINY = 6;

var gFontMid = [65, 46, 26, 14, 11, 9, 7];
const CHARSET = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:/.,-+'&()@#%!?·";

var gFonts = [null, null, null, null, null, null, null];

function fontRes(id) {
    if (id == F_CLOCK_XL) { return Rez.Fonts.ClockXL; }
    if (id == F_CLOCK_LG) { return Rez.Fonts.ClockLG; }
    if (id == F_TITLE) { return Rez.Fonts.Title; }
    if (id == F_STAT) { return Rez.Fonts.Stat; }
    if (id == F_LABEL) { return Rez.Fonts.Label; }
    if (id == F_SMALL) { return Rez.Fonts.Small; }
    return Rez.Fonts.Tiny;
}

function fallbackFont(id) {
    if (id == F_CLOCK_XL) { return Graphics.FONT_NUMBER_THAI_HOT; }
    if (id == F_CLOCK_LG) { return Graphics.FONT_NUMBER_HOT; }
    if (id == F_TITLE) { return Graphics.FONT_MEDIUM; }
    if (id == F_STAT) { return Graphics.FONT_SMALL; }
    if (id == F_LABEL) { return Graphics.FONT_TINY; }
    return Graphics.FONT_XTINY;
}

// Load only the fonts a screen needs; free them when it hides.
function useFonts(ids) {
    for (var i = 0; i < ids.size(); i++) {
        var id = ids[i];
        if (gFonts[id] == null) {
            try {
                gFonts[id] = WatchUi.loadResource(fontRes(id));
            } catch (e) {
                gFonts[id] = null;
            }
        }
    }
}

function dropFonts() {
    for (var i = 0; i < gFonts.size(); i++) {
        gFonts[i] = null;
    }
}

function canRender(str) {
    var chars = str.toCharArray();
    for (var i = 0; i < chars.size(); i++) {
        if (CHARSET.find(chars[i].toString()) == null) {
            return false;
        }
    }
    return true;
}

// Draw text with its capital letters centred on y.
// just: Graphics.TEXT_JUSTIFY_LEFT / CENTER / RIGHT
function txt(dc, x, y, fontId, str, color, just) {
    var s = str.toUpper();
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    var f = gFonts[fontId];
    if (f != null && canRender(s)) {
        dc.drawText(x, y - gFontMid[fontId], f, s, just);
    } else {
        dc.drawText(x, y, fallbackFont(fontId), str, just | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

function txtWidth(dc, fontId, str) {
    var s = str.toUpper();
    var f = gFonts[fontId];
    if (f != null && canRender(s)) {
        return dc.getTextWidthInPixels(s, f);
    }
    return dc.getTextWidthInPixels(str, fallbackFont(fontId));
}

// ---------- the ring ----------
// A rounded-rectangle line around the screen edge that fills clockwise
// from 12 o'clock. frac 0..1.
const RING_INSET = 7;
const RING_R = 21;
const RING_PEN = 5;

function drawRing(dc, frac, color, track) {
    var w = dc.getWidth();
    var h = dc.getHeight();
    var l = RING_INSET;
    var t = RING_INSET;
    var r = w - RING_INSET - 1;
    var b = h - RING_INSET - 1;
    var cr = RING_R;
    var cx = w / 2;

    dc.setPenWidth(RING_PEN);
    if (track != null) {
        dc.setColor(track, Graphics.COLOR_TRANSPARENT);
        ringPath(dc, l, t, r, b, cr, cx, 1.0);
    }
    if (frac > 0) {
        if (frac > 1) {
            frac = 1.0;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        ringPath(dc, l, t, r, b, cr, cx, frac);
    }
    dc.setPenWidth(1);
}

// Walk the perimeter segment by segment, drawing until the length runs out.
function ringPath(dc, l, t, r, b, cr, cx, frac) {
    var straightH = (r - l) - 2 * cr;
    var straightV = (b - t) - 2 * cr;
    var arc = Math.PI * cr / 2.0;
    var total = 2 * straightH + 2 * straightV + 4 * arc;
    var left = total * frac;

    // 1. top edge, centre -> right
    left = seg(dc, cx, t, r - cr, t, left);
    // 2. top-right corner
    left = corner(dc, r - cr, t + cr, cr, 90, left, arc);
    // 3. right edge
    left = seg(dc, r, t + cr, r, b - cr, left);
    // 4. bottom-right corner
    left = corner(dc, r - cr, b - cr, cr, 0, left, arc);
    // 5. bottom edge, right -> left
    left = seg(dc, r - cr, b, l + cr, b, left);
    // 6. bottom-left corner
    left = corner(dc, l + cr, b - cr, cr, 270, left, arc);
    // 7. left edge, bottom -> top
    left = seg(dc, l, b - cr, l, t + cr, left);
    // 8. top-left corner
    left = corner(dc, l + cr, t + cr, cr, 180, left, arc);
    // 9. top edge, left -> centre
    seg(dc, l + cr, t, cx, t, left);
}

function seg(dc, x1, y1, x2, y2, left) {
    if (left <= 0) {
        return 0;
    }
    var dx = x2 - x1;
    var dy = y2 - y1;
    var len = Math.sqrt(dx * dx + dy * dy);
    if (len <= 0) {
        return left;
    }
    if (left >= len) {
        dc.drawLine(x1, y1, x2, y2);
        return left - len;
    }
    var p = left / len;
    dc.drawLine(x1, y1, x1 + (dx * p).toNumber(), y1 + (dy * p).toNumber());
    return 0;
}

// Quarter arc, clockwise from startDeg (0 = 3 o'clock, counter-clockwise positive).
function corner(dc, x, y, rad, startDeg, left, arcLen) {
    if (left <= 0) {
        return 0;
    }
    var sweep = 90;
    var rest = left - arcLen;
    if (left < arcLen) {
        sweep = (90.0 * left / arcLen).toNumber();
        rest = 0;
    }
    if (sweep > 0) {
        var endDeg = startDeg - sweep;
        if (endDeg < 0) {
            endDeg += 360;
        }
        dc.drawArc(x, y, rad, Graphics.ARC_CLOCKWISE, startDeg, endDeg);
    }
    return rest;
}

// Small outlined heart for the HR readout.
function drawHeart(dc, x, y, color) {
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    dc.fillCircle(x - 3, y - 2, 3);
    dc.fillCircle(x + 3, y - 2, 3);
    dc.fillPolygon([[x - 6, y - 1], [x + 6, y - 1], [x, y + 6]]);
}
