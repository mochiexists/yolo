const MAX_WPM = 400;
const MIN_KEYSTROKES = 50;
// Shared secret for client HMAC. This is shipped in the static site — it
// cannot stop a determined attacker who reads the source. It raises the
// floor from "curl in five seconds" to "read the JS first".
const HMAC_SECRET = 'ccy-v1-k9nR2pXqW7tLmZ4sVbE8';
const MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;
// pi types `pi` three times (6 chars) — well below the 50-keystroke floor
// that catches paste-cheating in claude/codex. Override per mode.
const MIN_KEYSTROKES_BY_MODE = { pi: 6 };
const RATE_LIMIT_SEC = 20;
const CACHE_TTL_SEC = 30;
const CACHE_KEY_PREFIX = 'lb_top100_v2_';
const REC_SUMMARY_ONLY = true;
const VALID_MODES = ['claude', 'codex', 'claudex', 'pi'];
const DEFAULT_MODE = 'claude';
const SHEET_HEADERS = [
  'timestamp', 'handle', 'wpm', 'saved_s',
  'keystrokes', 'errors', 'breakdown',
  'recording', 'flag', 'owner_hash', 'mode'
];
const MODE_COL = 11; // 1-indexed sheet column for `mode`
const SHAMES = [
  "don't be a dick",
  "no.",
  "nice try, touch grass",
  "we're watching you",
  "even vim users can't do that",
  "suspiciously fast, suspiciously rejected"
];

// Whimsical, Toontown-style names minted server-side. The client never sends a
// name, so profanity / impersonation simply cannot enter the sheet — it's a
// closed vocabulary, not a filter to outrun. Multiple word seeds keep it fun.
const NAME_TITLES = [
  'Captain', 'Sir', 'Lady', 'Doctor', 'Professor', 'Baron', 'Madame', 'Lord',
  'Chief', 'Major', 'Sergeant', 'Duchess', 'Count', 'Admiral', 'Sir Reginald',
  'Mister', 'Princess', 'King', 'Queen', 'Colonel'
];
const NAME_ADJECTIVES = [
  'Loopy', 'Wacky', 'Zippy', 'Reckless', 'Feral', 'Unhinged', 'Dizzy', 'Cranky',
  'Sneaky', 'Goofy', 'Jittery', 'Rowdy', 'Bonkers', 'Frantic', 'Scrappy',
  'Twitchy', 'Turbo', 'Sleepy', 'Grumpy', 'Spicy', 'Sparkly', 'Wobbly', 'Zesty',
  'Cosmic', 'Sassy', 'Nimble', 'Rusty', 'Mighty', 'Cheeky', 'Snazzy', 'Dapper',
  'Fuzzy', 'Giddy', 'Plucky', 'Bumbling'
];
const NAME_NOUNS = [
  'Segfault', 'Daemon', 'Kernel', 'Otter', 'Goose', 'Mongoose', 'Pickle',
  'Noodle', 'Waffle', 'Bumblequack', 'Snickerdoodle', 'Doodlebug', 'Wingnut',
  'Bandit', 'Gizmo', 'Muffin', 'Pancake', 'Wombat', 'Narwhal', 'Pretzel',
  'Gremlin', 'Biscuit', 'Walrus', 'Sprocket', 'Marmot', 'Pumpernickel',
  'Flapjack', 'Quokka', 'Bonbon', 'Tugboat', 'Flibberty', 'Mcsnoot',
  'Wobblesworth', 'Higgleflop', 'Bamboozle'
];

// One-time migration: replace every stored handle with a server-minted name,
// seeded off the row's owner_hash so a returning player keeps one identity.
// Originals are backed up to column `orig_handle` (12) before overwrite, so it's
// reversible and re-running is idempotent (legacy rows re-seed from the backup).
// Run from the Apps Script editor (like backfillClaudeMode). Already executed
// once on 2026-06-06; safe to re-run.
function reseedAllHandles() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  ensureHeaders(sheet);
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return json({ ok: true, updated: 0, total: 0 });

  const ORIG_COL = 12;
  if (String(sheet.getRange(1, ORIG_COL).getValue() || '') !== 'orig_handle') {
    sheet.getRange(1, ORIG_COL).setValue('orig_handle');
  }

  const n = lastRow - 1;
  const tsCol = sheet.getRange(2, 1, n, 1).getValues();
  const handleCol = sheet.getRange(2, 2, n, 1).getValues();
  const wpmCol = sheet.getRange(2, 3, n, 1).getValues();
  const ownerCol = sheet.getRange(2, 10, n, 1).getValues();
  const origCol = sheet.getRange(2, ORIG_COL, n, 1).getValues();

  const ownerToName = {};
  const taken = {};
  const newHandles = [];
  const newOrigs = [];
  let updated = 0;

  for (let i = 0; i < n; i++) {
    const owner = String(ownerCol[i][0] || '');
    // Keep the first-run original; on re-runs the backup is already populated.
    const orig = String(origCol[i][0] || '') || String(handleCol[i][0] || '');
    newOrigs.push([orig]);

    let name;
    if (owner && ownerToName[owner]) {
      name = ownerToName[owner]; // same player → same name across their rows
    } else {
      const seed = owner
        ? owner // owner_hash is already the doPost seed; matches future submits
        : sha256Hex('legacy|' + tsCol[i][0] + '|' + wpmCol[i][0] + '|' + orig);
      name = generateHandle(seed, taken);
      if (owner) ownerToName[owner] = name;
    }
    taken[name] = true;
    newHandles.push([name]);
    if (name !== String(handleCol[i][0] || '')) updated++;
  }

  sheet.getRange(2, 2, n, 1).setValues(newHandles);
  sheet.getRange(2, ORIG_COL, n, 1).setValues(newOrigs);
  clearCache();
  return json({ ok: true, updated: updated, total: n });
}

function doGet(e) {
  try {
    const params = (e && e.parameter) || {};
    if (params.restore) return handleRestore(String(params.restore));

    const mode = normalizeMode(params.mode);
    const cacheKey = CACHE_KEY_PREFIX + mode;
    const cache = CacheService.getScriptCache();
    const cached = cache.get(cacheKey);
    if (cached) return jsonRaw(cached);

    const entries = readTopEntries(100, mode);
    const payload = JSON.stringify({ ok: true, entries, mode: mode });
    cache.put(cacheKey, payload, CACHE_TTL_SEC);
    return jsonRaw(payload);
  } catch (err) {
    return json({ ok: false, error: 'server error' });
  }
}

function handleRestore(hashHex) {
  const hex = (hashHex || '').toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(hex)) {
    return json({ ok: false, error: 'bad key format' });
  }
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return json({ ok: false, error: 'no match' });
  // owner_hash is column J (10). Read handle, wpm, timestamp, owner_hash, flag.
  const values = sheet.getRange(2, 1, lastRow - 1, 10).getValues();
  let best = null;
  for (let i = 0; i < values.length; i++) {
    const r = values[i];
    if (r[8]) continue; // flagged
    const owner = String(r[9] || '').toLowerCase();
    if (!owner || owner !== hex) continue;
    const wpm = Number(r[2]);
    if (isNaN(wpm)) continue;
    if (!best || wpm > best.wpm) {
      best = { handle: String(r[1]), wpm: wpm, timestamp: r[0] };
    }
  }
  if (!best) return json({ ok: false, error: 'no match' });
  return json({ ok: true, handle: best.handle, wpm: best.wpm, timestamp: best.timestamp });
}

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents);
    const wpm = Number(body.wpm);
    const keystrokes = Number(body.keystrokes);
    const errors = Number(body.errors) || 0;
    const breakdown = body.breakdown || [];
    const recording = body.recording || [];
    const userToken = (body.userToken || '').toString();
    const mode = normalizeMode(body.mode);
    const submittedAt = Number(body.submittedAt) || 0;
    const sig = String(body.sig || '').toLowerCase();

    // Field guards. The name is minted by the server (below), so there is no
    // client-supplied handle to sanitize — profanity / impersonation can't
    // enter the sheet by construction, not by filtering. Any `body.handle` the
    // client (or a direct API caller) sends is ignored outright.
    if (!wpm || wpm < 1 || isNaN(wpm)) {
      return json({ ok: false, error: 'invalid wpm', code: 'bad_wpm' });
    }
    if (wpm > MAX_WPM) {
      return json({ ok: false, error: shame(), code: 'too_fast' });
    }
    const minKeys = MIN_KEYSTROKES_BY_MODE[mode] || MIN_KEYSTROKES;
    if (!keystrokes || keystrokes < minKeys) {
      return json({ ok: false, error: 'we see you pasting, type it yourself', code: 'no_keystrokes' });
    }

    // HMAC check: rejects anyone hitting the endpoint without replicating the
    // client-side signing. Obfuscation, not real auth — the secret is public.
    const now = Date.now();
    if (!submittedAt || Math.abs(now - submittedAt) > MAX_CLOCK_SKEW_MS) {
      return json({ ok: false, error: 'stale submission, refresh the page', code: 'bad_sig' });
    }
    const expectedSig = hmacHex(HMAC_SECRET, signatureMessage(wpm, keystrokes, errors, mode, submittedAt));
    if (sig !== expectedSig) {
      return json({ ok: false, error: 'invalid signature, refresh the page', code: 'bad_sig' });
    }

    const cache = CacheService.getScriptCache();
    const ownerHash = userToken ? sha256Hex(userToken) : '';
    // Seed the name off the owner hash so a returning player keeps one identity.
    // Tokenless submits fall back to the signature: stable within the request,
    // just not restorable on another device.
    const seedHex = ownerHash || sha256Hex(sig || String(submittedAt));

    const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
    ensureHeaders(sheet);
    const lastRow = sheet.getLastRow();

    // Read existing names + owners once. Used to (a) keep a returning player's
    // existing name and (b) avoid minting a name already owned by someone else.
    const takenByOther = {};
    let myExistingHandle = '';
    if (lastRow > 1) {
      const handleCol = sheet.getRange(2, 2, lastRow - 1, 1).getValues();
      const ownerCol = sheet.getRange(2, 10, lastRow - 1, 1).getValues();
      for (let i = 0; i < handleCol.length; i++) {
        const h = String(handleCol[i][0] || '');
        if (!h) continue;
        const o = String(ownerCol[i][0] || '');
        if (ownerHash && o === ownerHash) myExistingHandle = h;
        else takenByOther[h] = true;
      }
    }

    // A returning player keeps their existing name; otherwise mint a fresh one.
    const handle = myExistingHandle || generateHandle(seedHex, takenByOther);

    // Handle-level cooldown (blocks rapid resubmits under the same name).
    const handleRateKey = 'rl_h_' + handle;
    if (cache.get(handleRateKey)) {
      return json({ ok: false, error: 'chill, slow down', code: 'rate_limit' });
    }
    // Token-level cooldown: blocks one token from spamming submissions.
    if (ownerHash) {
      const tokKey = 'rl_tok_' + ownerHash;
      const prevHandle = cache.get(tokKey);
      if (prevHandle && prevHandle !== handle) {
        return json({ ok: false, error: 'chill, slow down', code: 'rate_limit' });
      }
    }

    const msPerChar = 60000 / (wpm * 5);
    const savedS = (35 * msPerChar) / 1000;
    const flag = (wpm > 280 && errors < 1) ? 'review' : '';
    const recCell = REC_SUMMARY_ONLY
      ? JSON.stringify(summarizeRecording(recording))
      : JSON.stringify(recording).slice(0, 10000);

    sheet.appendRow([
      new Date(),
      handle,
      wpm,
      savedS,
      keystrokes,
      errors,
      JSON.stringify(breakdown),
      recCell,
      flag,
      ownerHash,
      mode
    ]);

    cache.put(handleRateKey, '1', RATE_LIMIT_SEC);
    if (ownerHash) cache.put('rl_tok_' + ownerHash, handle, RATE_LIMIT_SEC);
    cache.remove(CACHE_KEY_PREFIX + mode);

    const newLast = sheet.getLastRow();
    const wpmCol = sheet.getRange(2, 3, newLast - 1, 1).getValues();
    const flagCol = sheet.getRange(2, 9, newLast - 1, 1).getValues();
    const modeCol = sheet.getRange(2, MODE_COL, newLast - 1, 1).getValues();
    const valid = [];
    for (let i = 0; i < wpmCol.length; i++) {
      const w = wpmCol[i][0];
      const rowMode = normalizeMode(modeCol[i][0]);
      if (rowMode !== mode) continue;
      if (!flagCol[i][0] && typeof w === 'number' && !isNaN(w)) valid.push(w);
    }
    valid.sort((a, b) => b - a);
    const rank = valid.indexOf(wpm) + 1;

    return json({ ok: true, rank: rank, total: valid.length, flagged: !!flag, handle: handle });
  } catch (err) {
    return json({ ok: false, error: 'submission failed: ' + err.message });
  }
}

function ensureHeaders(sheet) {
  const width = SHEET_HEADERS.length;
  const row = sheet.getRange(1, 1, 1, width).getValues()[0];
  const needsWrite = SHEET_HEADERS.some((h, i) => String(row[i] || '').trim() !== h);
  if (needsWrite) {
    sheet.getRange(1, 1, 1, width).setValues([SHEET_HEADERS]);
    sheet.getRange(1, 1, 1, width).setFontWeight('bold');
    sheet.setFrozenRows(1);
  }
}

function signatureMessage(wpm, keystrokes, errors, mode, submittedAt) {
  return [wpm, keystrokes, errors, mode, submittedAt].join('|');
}

function hmacHex(secret, message) {
  const bytes = Utilities.computeHmacSha256Signature(message, secret);
  let out = '';
  for (let i = 0; i < bytes.length; i++) {
    const b = bytes[i] < 0 ? bytes[i] + 256 : bytes[i];
    out += ('0' + b.toString(16)).slice(-2);
  }
  return out;
}

function sha256Hex(s) {
  const bytes = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, s, Utilities.Charset.UTF_8);
  let out = '';
  for (let i = 0; i < bytes.length; i++) {
    const b = bytes[i] < 0 ? bytes[i] + 256 : bytes[i];
    out += ('0' + b.toString(16)).slice(-2);
  }
  return out;
}

// Deterministic name from a 64-char hex seed. `salt` nudges the combination so
// we can re-roll on collision without losing determinism.
function nameFromSeed(seedHex, salt) {
  const h = sha256Hex(seedHex + '|' + salt);
  const pick = function (start, len, arr) {
    return arr[parseInt(h.substr(start, len), 16) % arr.length];
  };
  const adj = pick(2, 4, NAME_ADJECTIVES);
  const noun = pick(6, 4, NAME_NOUNS);
  // ~45% of names get a title for variety.
  if (parseInt(h.substr(0, 2), 16) < 115) {
    return pick(10, 4, NAME_TITLES) + ' ' + adj + ' ' + noun;
  }
  return adj + ' ' + noun;
}

// Mint a name not already owned by someone else. Re-rolls via salt; a returning
// player's existing name is handled by the caller before this is reached.
function generateHandle(seedHex, takenByOther) {
  for (let salt = 0; salt < 60; salt++) {
    const candidate = nameFromSeed(seedHex, salt);
    if (!takenByOther[candidate]) return candidate;
  }
  // Pathological fallback (vocabulary exhausted): guaranteed-unique suffix.
  return nameFromSeed(seedHex, 0) + ' ' + seedHex.substring(0, 4);
}

function readTopEntries(limit, mode) {
  const filterMode = normalizeMode(mode);
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return [];
  const values = sheet.getRange(2, 1, lastRow - 1, MODE_COL).getValues();
  const rows = [];
  for (let i = 0; i < values.length; i++) {
    const r = values[i];
    if (!r[1] || r[8]) continue;
    const rowMode = normalizeMode(r[MODE_COL - 1]);
    if (rowMode !== filterMode) continue;
    const wpm = Number(r[2]);
    if (isNaN(wpm)) continue;
    rows.push({
      timestamp: r[0],
      handle: String(r[1]),
      wpm: wpm,
      saved_s: Number(r[3]),
      keystrokes: Number(r[4]),
      errors: Number(r[5])
    });
  }
  rows.sort((a, b) => b.wpm - a.wpm);
  return rows.slice(0, limit);
}

function summarizeRecording(recording) {
  let len = 0, firstGap = 0, phases = 0;
  if (Array.isArray(recording)) {
    for (const phase of recording) {
      if (Array.isArray(phase) && phase.length > 0) {
        phases++;
        len += phase.length;
        if (!firstGap) firstGap = phase[0].t || 0;
      }
    }
  }
  return { len: len, firstGap: firstGap, phases: phases };
}

function json(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function jsonRaw(str) {
  return ContentService.createTextOutput(str)
    .setMimeType(ContentService.MimeType.JSON);
}

function shame() {
  return SHAMES[Math.floor(Math.random() * SHAMES.length)];
}

function clearCache() {
  const cache = CacheService.getScriptCache();
  VALID_MODES.forEach(function (m) { cache.remove(CACHE_KEY_PREFIX + m); });
}

function normalizeMode(raw) {
  const m = String(raw || '').toLowerCase().trim();
  return VALID_MODES.indexOf(m) >= 0 ? m : DEFAULT_MODE;
}

// One-time manual migration: fill `mode` for legacy rows with DEFAULT_MODE.
// Run from the Apps Script editor after deploying. Idempotent.
function backfillClaudeMode() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  ensureHeaders(sheet);
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return { ok: true, filled: 0 };
  const range = sheet.getRange(2, MODE_COL, lastRow - 1, 1);
  const values = range.getValues();
  let filled = 0;
  for (let i = 0; i < values.length; i++) {
    const v = String(values[i][0] || '').toLowerCase().trim();
    if (VALID_MODES.indexOf(v) < 0) {
      values[i][0] = DEFAULT_MODE;
      filled++;
    }
  }
  if (filled > 0) range.setValues(values);
  clearCache();
  return { ok: true, filled: filled };
}
