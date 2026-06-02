#!/usr/bin/env node
// Unit tests for the replay / stats-chart math in index.html.
//
// The functions here mirror the ones inline in index.html. They intentionally
// duplicate the logic so tests catch drift the moment source and test diverge.
// Keep them small, pure, and no-DOM.
//
// Run: node tests/replay.test.js
// Exit code 0 on success, 1 on failure.

'use strict';

// ─────────────────────────────────────────────
// Helpers (mirror of index.html pure logic)
// ─────────────────────────────────────────────

// Trim each phase's recording to the first entry whose typed value equals the
// phrase target. Matches the hydration-time cleanup in index.html — guards
// against older recordings that captured keystrokes typed during the
// post-completion reaction window.
function trimRecordingToCompletion(recordings, phrases) {
    if (!Array.isArray(recordings)) return recordings;
    recordings.forEach(function (rec, i) {
        if (!Array.isArray(rec)) return;
        var target = phrases[i];
        if (!target) return;
        for (var k = 0; k < rec.length; k++) {
            if (rec[k] && rec[k].v === target) {
                rec.length = k + 1;
                break;
            }
        }
    });
    return recordings;
}

// Cap long dead-air gaps in the recording so replay doesn't stall.
function normalizeRecording(recording, MAX_GAP_MS) {
    var norm = [];
    var prevT = 0, cumOffset = 0;
    for (var k = 0; k < recording.length; k++) {
        var s = recording[k] || {};
        var rawT = Number(s.t) || 0;
        var gap = Math.max(0, rawT - prevT);
        if (gap > MAX_GAP_MS) cumOffset += (gap - MAX_GAP_MS);
        prevT = rawT;
        norm.push({ t: rawT - cumOffset, v: String(s.v || '') });
    }
    return norm;
}

// Walk all phases as replay would, scaling snap.t by the authoritative
// phaseDurationMs so the displayed meta is bounded by the real test time.
// Returns the final displayed meta (ms) and the array of per-phase ends.
function simulateCumulativeReplay(recordings, phaseTimesMs, MAX_GAP_MS) {
    var meta = 0;
    var perPhaseEnds = [];
    recordings.forEach(function (rec, i) {
        var norm = normalizeRecording(rec || [], MAX_GAP_MS);
        var endNormT = norm.length ? norm[norm.length - 1].t : 0;
        var phaseDurationMs = (phaseTimesMs || [])[i] || 0;
        var displayScale = (phaseDurationMs > 0 && endNormT > 0)
            ? (phaseDurationMs / endNormT) : 1;
        var baseMs = meta;
        var lastDisplayed = baseMs;
        for (var j = 0; j < norm.length; j++) {
            lastDisplayed = baseMs + norm[j].t * displayScale;
        }
        meta = lastDisplayed;
        perPhaseEnds.push(meta);
    });
    return { meta: meta, perPhaseEnds: perPhaseEnds };
}

// Assign each deduped entry its true rank in the raw entries list.
function annotateTrueRanks(entries, collapsed) {
    collapsed.forEach(function (row) {
        var idx = entries.findIndex(function (e) { return e.handle === row.handle; });
        row._trueRank = idx >= 0 ? idx + 1 : 0;
    });
    return collapsed;
}

function isBlockedHandle(handle) {
    var patterns = [
        /n+[\W_]*[i1!|]+[\W_]*[gq9]+[\W_]*[gq9]+[\W_]*(?:[e3]+[\W_]*r+|[a4]+)?/i,
        /n+[\W_]*[i1!|]+[\W_]*[gq9]+[\W_]*[a4]+/i,
        /f+[\W_]*(?:a|4)+[\W_]*(?:g|9)+(?:[\W_]*(?:g|9|o|0|e|3|t|7)+)*/i,
        /r+[\W_]*(?:e|3)+[\W_]*(?:t|7)+[\W_]*(?:a|4)+[\W_]*r+[\W_]*d+/i,
        /c+[\W_]*(?:u|v)+[\W_]*n+[\W_]*(?:t|7)+/i,
        /f+[\W_]*(?:u|v)+[\W_]*c+[\W_]*k+/i,
        /s+[\W_]*h+[\W_]*(?:i|1|!|\|)+[\W_]*(?:t|7)+/i,
        /b+[\W_]*(?:i|1|!|\|)+[\W_]*(?:t|7)+[\W_]*c+[\W_]*h+/i,
        /w+[\W_]*h+[\W_]*(?:o|0)+[\W_]*r+[\W_]*(?:e|3)+/i,
        /s+[\W_]*l+[\W_]*(?:u|v)+[\W_]*(?:t|7)+/i
    ];
    var compact = String(handle || '')
        .normalize('NFKD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase();
    return patterns.some(function (pattern) { return pattern.test(compact); });
}

// ─────────────────────────────────────────────
// Tiny test harness
// ─────────────────────────────────────────────

var passed = 0, failed = 0;
function t(name, fn) {
    try {
        fn();
        console.log('  PASS: ' + name);
        passed++;
    } catch (e) {
        console.log('  FAIL: ' + name + ' — ' + (e.message || e));
        failed++;
    }
}
function assert(cond, msg) { if (!cond) throw new Error(msg || 'assertion failed'); }
function assertEq(a, b, msg) { if (a !== b) throw new Error((msg || 'eq') + ' expected ' + JSON.stringify(b) + ' got ' + JSON.stringify(a)); }
function assertClose(a, b, eps, msg) {
    eps = eps || 0.001;
    if (Math.abs(a - b) > eps) throw new Error((msg || 'close') + ' expected ' + b + ' ± ' + eps + ' got ' + a);
}

var PHRASES = [
    'claude --dangerously-skip-permissions',
    'claude --yolo',
    'ccy'
];
var MAX_GAP = 400;

// ─────────────────────────────────────────────
// trimRecordingToCompletion
// ─────────────────────────────────────────────
console.log('\n=== trimRecordingToCompletion ===');

t('trims at first completion entry', function () {
    var rec = [
        [
            { t: 100, v: 'c' },
            { t: 5000, v: PHRASES[0] },
            { t: 9000, v: PHRASES[0] + 'extra' },
            { t: 12000, v: 'garbage' }
        ]
    ];
    trimRecordingToCompletion(rec, PHRASES);
    assertEq(rec[0].length, 2, 'should trim to two entries');
    assertEq(rec[0][1].v, PHRASES[0], 'last entry is the target');
});

t('leaves untouched if target never appears (no-op safety)', function () {
    var rec = [[{ t: 100, v: 'c' }, { t: 200, v: 'cl' }]];
    trimRecordingToCompletion(rec, PHRASES);
    assertEq(rec[0].length, 2);
});

t('handles empty / missing phases', function () {
    var rec = [null, undefined, []];
    trimRecordingToCompletion(rec, PHRASES);
    assertEq(rec.length, 3);
});

// ─────────────────────────────────────────────
// normalizeRecording
// ─────────────────────────────────────────────
console.log('\n=== normalizeRecording ===');

t('monotonic + bounded', function () {
    var rec = [
        { t: 0, v: 'c' },
        { t: 100, v: 'cl' },
        { t: 200, v: 'cla' },
        { t: 10000, v: 'clau' },   // 9800ms gap → capped
        { t: 10100, v: 'claud' },
        { t: 10200, v: 'claude' }
    ];
    var norm = normalizeRecording(rec, MAX_GAP);
    assertEq(norm.length, rec.length);
    // Monotonic
    for (var i = 1; i < norm.length; i++) assert(norm[i].t >= norm[i - 1].t, 'monotonic at ' + i);
    // The big 9800ms gap is capped to MAX_GAP (400ms), so final t = 200 + 400 + 100 + 100 = 800
    assertEq(norm[norm.length - 1].t, 800, 'big gap capped to MAX_GAP');
});

t('no gap capping when all gaps under limit', function () {
    var rec = [
        { t: 0, v: 'a' },
        { t: 100, v: 'ab' },
        { t: 200, v: 'abc' },
        { t: 300, v: 'abcd' }
    ];
    var norm = normalizeRecording(rec, MAX_GAP);
    assertEq(norm[norm.length - 1].t, 300, 'no capping');
});

t('handles empty recording', function () {
    var norm = normalizeRecording([], MAX_GAP);
    assertEq(norm.length, 0);
});

// ─────────────────────────────────────────────
// simulateCumulativeReplay — the regression the user keeps hitting
// ─────────────────────────────────────────────
console.log('\n=== simulateCumulativeReplay ===');

t('final meta equals sum of phaseTimesMs (authoritative)', function () {
    // Recordings with realistic entries
    var recs = [
        [{ t: 0, v: 'c' }, { t: 500, v: 'cl' }, { t: 6000, v: PHRASES[0] }],
        [{ t: 0, v: 'c' }, { t: 1200, v: PHRASES[1] }],
        [{ t: 0, v: 'c' }, { t: 200, v: PHRASES[2] }]
    ];
    var phaseTimes = [6000, 1200, 200];
    var { meta, perPhaseEnds } = simulateCumulativeReplay(recs, phaseTimes, MAX_GAP);
    assertClose(meta / 1000, 7.4, 0.001, 'final meta ≈ 7.4s');
    assertClose(perPhaseEnds[0] / 1000, 6.0, 0.001, 'end of phase 1');
    assertClose(perPhaseEnds[1] / 1000, 7.2, 0.001, 'end of phase 2');
    assertClose(perPhaseEnds[2] / 1000, 7.4, 0.001, 'end of phase 3');
});

t('BLOATED recording — meta STILL bounded to phaseTimesMs (regression)', function () {
    // Phase 1 recording includes 100 entries of backspace-rework going out to 20s raw.
    // Actual phase duration during live test was 6s.
    var bloated = [];
    for (var i = 0; i < 100; i++) bloated.push({ t: i * 200, v: 'filler' + i });
    bloated.push({ t: 20000, v: PHRASES[0] }); // completion, but raw time is 20s
    var recs = [bloated, [{ t: 0, v: 'c' }, { t: 1200, v: PHRASES[1] }], [{ t: 0, v: 'c' }, { t: 200, v: PHRASES[2] }]];
    var phaseTimes = [6000, 1200, 200];
    var { meta } = simulateCumulativeReplay(recs, phaseTimes, MAX_GAP);
    // Final meta must equal the SUM of authoritative phase times, not the raw recording ends.
    assertClose(meta / 1000, 7.4, 0.01, 'bloated recording scaled down to real test time');
    assert(meta <= (6000 + 1200 + 200) + 1, 'meta never exceeds sum of phaseTimesMs');
});

t('falls back to recording endT if phaseTimesMs missing', function () {
    var recs = [
        [{ t: 0, v: 'c' }, { t: 100, v: 'cl' }, { t: 200, v: PHRASES[0] }],
        [{ t: 0, v: 'c' }, { t: 150, v: PHRASES[1] }]
    ];
    var { meta } = simulateCumulativeReplay(recs, [], MAX_GAP);
    assertClose(meta, 350, 0.001, 'fallback to raw last.t sum');
});

t('empty recordings array gives meta 0', function () {
    var { meta } = simulateCumulativeReplay([], [], MAX_GAP);
    assertEq(meta, 0);
});

// ─────────────────────────────────────────────
// annotateTrueRanks
// ─────────────────────────────────────────────
console.log('\n=== annotateTrueRanks ===');

t('true rank is position in RAW entries, not collapsed index', function () {
    var entries = [
        { handle: 'mochi',   wpm: 118 },
        { handle: 'naty_uwu', wpm: 101 },
        { handle: 'naty_uwu', wpm: 95 },
        { handle: 'naty_uwu', wpm: 91 },
        { handle: 'sleepy',   wpm: 87 },
        { handle: 'naty',     wpm: 78 },
        { handle: 'Bob',      wpm: 70 },
        { handle: 'Alice',    wpm: 65 },
        { handle: 'Carol',    wpm: 60 },
        { handle: 'Dave',     wpm: 55 },
        { handle: 'snail',    wpm: 52 }
    ];
    // dedupe: first entry per handle wins
    var seen = {}, collapsed = [];
    entries.forEach(function (e) {
        if (!seen[e.handle]) { seen[e.handle] = true; collapsed.push({ handle: e.handle, wpm: e.wpm }); }
    });
    annotateTrueRanks(entries, collapsed);

    // snail is 11th in raw but 9th in collapsed. True rank should be 11.
    var snailRow = collapsed.find(function (r) { return r.handle === 'snail'; });
    assertEq(snailRow._trueRank, 11, 'snail gets true rank 11');

    // mochi is 1st everywhere.
    var mochiRow = collapsed.find(function (r) { return r.handle === 'mochi'; });
    assertEq(mochiRow._trueRank, 1);
});


// ─────────────────────────────────────────────
// handle moderation
// ─────────────────────────────────────────────
console.log('\n=== handle moderation ===');

t('blocks common obfuscated slur and profanity handles', function () {
    assert(isBlockedHandle('n1gg4'), 'leet spelling');
    assert(isBlockedHandle('n.i.g.g.e.r'), 'punctuation-separated spelling');
    assert(isBlockedHandle('f.u.c.k'), 'punctuation-separated profanity');
    assert(isBlockedHandle('b1tch'), 'leet profanity');
    assert(isBlockedHandle('r3tard'), 'ableist slur');
    assert(isBlockedHandle('wh0re'), 'leet profanity');
});

t('allows ordinary handles with nearby letters', function () {
    assert(!isBlockedHandle('nightbot'), 'ordinary handle');
    assert(!isBlockedHandle('nina'), 'short ordinary name');
    assert(!isBlockedHandle('classification'), 'does not block tame substrings');
    assert(!isBlockedHandle('passionfruit'), 'does not block partial tame words');
});

// ─────────────────────────────────────────────
// Results
// ─────────────────────────────────────────────
console.log('\n================================');
console.log('  ' + passed + ' passed, ' + failed + ' failed');
console.log('================================\n');
process.exit(failed === 0 ? 0 : 1);
