import fs from 'node:fs';

// Reads the `stats` block of a Playwright JSON report without loading the whole
// file. The full-matrix web report is hundreds of MB; `stats` is the report's
// last key in both the built-in and the streamed reporter, so a bounded tail
// suffices. Returns null when the file is missing, truncated or has no stats.
export function readReportStats(file, tailBytes = 64 * 1024) {
  let handle;
  try {
    handle = fs.openSync(file, 'r');
  } catch {
    return null;
  }
  try {
    const size = fs.fstatSync(handle).size;
    const tail = Buffer.alloc(Math.min(size, tailBytes));
    fs.readSync(handle, tail, 0, tail.length, size - tail.length);
    const match = tail.toString('utf8').match(/"stats"\s*:\s*(\{[^}]*\})\s*\}\s*$/);
    return match ? JSON.parse(match[1]) : null;
  } catch {
    return null;
  } finally {
    fs.closeSync(handle);
  }
}
