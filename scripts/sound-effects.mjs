#!/usr/bin/env node
// Writes the app's four sounds (specs/26 "Sound and haptics") to app/assets/sounds/*.wav:
//   node scripts/sound-effects.mjs            (from the repo root)
// They are synthesised here from sine tones, so they belong to the project and need no
// licence entry beyond the repository's own (Q56). Each is mono 16-bit PCM at 16 kHz (the highest partial is near 5.3 kHz),
// under one second and under 30 KB, with a soft attack, a decay and a short linear release
// at the end of each note, so nothing clicks.
//   tick    a chore ticked: one short, bright blip
//   coin    points arriving: two quick rising notes
//   fertig  the last chore of the day: a rising major arpeggio
//   badge   a badge or a reward: a little sparkle
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const RATE = 16000;
// The last 8 ms of every note fade to zero: the decay alone leaves a note at about 6 % of
// its peak when it ends, and that step is an audible click.
const RELEASE = Math.round(0.008 * RATE);
const out = path.join(path.dirname(fileURLToPath(import.meta.url)), '../app/assets/sounds');

const hz = (note) => 440 * 2 ** ((note - 69) / 12); // MIDI note number to frequency

/** A note: start and length in seconds, a MIDI pitch, a loudness. */
function render(notes, seconds) {
  const samples = new Float64Array(Math.round(RATE * seconds));
  for (const { at, len, note, gain = 0.5 } of notes) {
    const f = hz(note);
    const start = Math.round(at * RATE);
    const n = Math.round(len * RATE);
    for (let i = 0; i < n && start + i < samples.length; i++) {
      const t = i / RATE;
      const attack = Math.min(1, t / 0.006);
      const decay = Math.exp(-t / (len * 0.35));
      const release = Math.min(1, (n - i) / RELEASE);
      // A sine with a quiet octave on top: rounder than a pure tone, never harsh.
      const v = Math.sin(2 * Math.PI * f * t) + 0.25 * Math.sin(4 * Math.PI * f * t);
      samples[start + i] += gain * attack * decay * release * v;
    }
  }
  return samples;
}

function wav(samples) {
  const data = Buffer.alloc(samples.length * 2);
  for (let i = 0; i < samples.length; i++) {
    const v = Math.max(-1, Math.min(1, samples[i] * 0.8));
    data.writeInt16LE(Math.round(v * 32767), i * 2);
  }
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // mono
  header.writeUInt32LE(RATE, 24);
  header.writeUInt32LE(RATE * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36);
  header.writeUInt32LE(data.length, 40);
  return Buffer.concat([header, data]);
}

const sounds = {
  tick: render([{ at: 0, len: 0.09, note: 88, gain: 0.45 }], 0.12),
  coin: render([
    { at: 0, len: 0.09, note: 83, gain: 0.4 },
    { at: 0.07, len: 0.2, note: 88, gain: 0.45 },
  ], 0.3),
  fertig: render([
    { at: 0, len: 0.22, note: 72 },
    { at: 0.11, len: 0.22, note: 76 },
    { at: 0.22, len: 0.22, note: 79 },
    { at: 0.33, len: 0.4, note: 84, gain: 0.55 },
  ], 0.75),
  badge: render([
    { at: 0, len: 0.25, note: 79, gain: 0.4 },
    { at: 0.08, len: 0.3, note: 84, gain: 0.4 },
    { at: 0.16, len: 0.5, note: 88, gain: 0.45 },
    { at: 0.3, len: 0.35, note: 96, gain: 0.18 },
    { at: 0.42, len: 0.3, note: 100, gain: 0.12 },
  ], 0.85),
};

fs.mkdirSync(out, { recursive: true });
for (const [name, samples] of Object.entries(sounds)) {
  const file = path.join(out, `${name}.wav`);
  fs.writeFileSync(file, wav(samples));
  console.log(`${path.relative(process.cwd(), file)}  ${fs.statSync(file).size} bytes`);
}
