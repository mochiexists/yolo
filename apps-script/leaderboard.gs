const MAX_WPM = 400;
const MIN_KEYSTROKES = 50;
const MAX_HANDLE_LEN = 24;
const RATE_LIMIT_SEC = 20;
const CACHE_TTL_SEC = 30;
const CACHE_KEY = 'lb_top100_v1';
const REC_SUMMARY_ONLY = true;
const SHAMES = [
  "don't be a dick",
  "no.",
  "nice try, touch grass",
  "we're watching you",
  "even vim users can't do that",
  "suspiciously fast, suspiciously rejected"
];

function doGet(e) {
  try {
    const cache = CacheService.getScriptCache();
    const cached = cache.get(CACHE_KEY);
    if (cached) return jsonRaw(cached);

    const entries = readTopEntries(100);
    const payload = JSON.stringify({ ok: true, entries });
    cache.put(CACHE_KEY, payload, CACHE_TTL_SEC);
    return jsonRaw(payload);
  } catch (err) {
    return json({ ok: false, error: 'server error' });
  }
}

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents);
    const handleRaw = (body.handle || '').toString().trim();
    const wpm = Number(body.wpm);
    const keystrokes = Number(body.keystrokes);
    const errors = Number(body.errors) || 0;
    const breakdown = body.breakdown || [];
    const recording = body.recording || [];
    const userToken = (body.userToken || '').toString();

    const handle = handleRaw.replace(/[<>\n\r\t]/g, '').slice(0, MAX_HANDLE_LEN);
    if (!handle) return json({ ok: false, error: 'sanitize your handle', code: 'bad_handle' });
    if (/https?:|<script|javascript:/i.test(handle)) {
      return json({ ok: false, error: 'no links in handles', code: 'bad_handle' });
    }
    if (!wpm || wpm < 1 || isNaN(wpm)) {
      return json({ ok: false, error: 'invalid wpm', code: 'bad_wpm' });
    }
    if (wpm > MAX_WPM) {
      return json({ ok: false, error: shame(), code: 'too_fast' });
    }
    if (!keystrokes || keystrokes < MIN_KEYSTROKES) {
      return json({ ok: false, error: 'we see you pasting, type it yourself', code: 'no_keystrokes' });
    }

    const cache = CacheService.getScriptCache();
    const rateKey = 'rl_' + handle;
    if (cache.get(rateKey)) {
      return json({ ok: false, error: 'chill, slow down', code: 'rate_limit' });
    }

    const ownerHash = userToken ? sha256Hex(userToken) : '';

    const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
    const lastRow = sheet.getLastRow();

    // Soft handle ownership: if anyone has claimed this handle with a
    // different owner hash, reject. Rows without an owner_hash are legacy /
    // unclaimed and don't count.
    if (lastRow > 1) {
      const handleRange = sheet.getRange(2, 2, lastRow - 1, 1).getValues();
      const ownerRange = sheet.getRange(2, 10, lastRow - 1, 1).getValues();
      for (let i = 0; i < handleRange.length; i++) {
        if (String(handleRange[i][0]) !== handle) continue;
        const existingOwner = String(ownerRange[i][0] || '');
        if (existingOwner && existingOwner !== ownerHash) {
          return json({ ok: false, error: 'handle taken, pick another', code: 'handle_taken' });
        }
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
      ownerHash
    ]);

    cache.put(rateKey, '1', RATE_LIMIT_SEC);
    cache.remove(CACHE_KEY);

    const newLast = sheet.getLastRow();
    const wpmCol = sheet.getRange(2, 3, newLast - 1, 1).getValues();
    const flagCol = sheet.getRange(2, 9, newLast - 1, 1).getValues();
    const valid = [];
    for (let i = 0; i < wpmCol.length; i++) {
      const w = wpmCol[i][0];
      if (!flagCol[i][0] && typeof w === 'number' && !isNaN(w)) valid.push(w);
    }
    valid.sort((a, b) => b - a);
    const rank = valid.indexOf(wpm) + 1;

    return json({ ok: true, rank: rank, total: valid.length, flagged: !!flag });
  } catch (err) {
    return json({ ok: false, error: 'submission failed: ' + err.message });
  }
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

function readTopEntries(limit) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return [];
  const values = sheet.getRange(2, 1, lastRow - 1, 9).getValues();
  const rows = [];
  for (let i = 0; i < values.length; i++) {
    const r = values[i];
    if (!r[1] || r[8]) continue;
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
  CacheService.getScriptCache().remove(CACHE_KEY);
}
