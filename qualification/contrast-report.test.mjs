import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  buildContrastReport,
  groupContrastResults,
  parseContrastReason,
  renderContrastMarkdown,
} from './contrast-report.mjs';

const firstIssue = `SemanticsNode#22(Rect.fromLTRB(4.0, 4.0, 116.0, 47.0), label: "Mo", textDirection: ltr):
Expected contrast ratio of at least 4.5 but found 1.13 for a font size of 15.0.
The computed colors was:
light - Color(alpha: 1.0000, red: 0.9686, green: 0.9569, blue: 0.9333, colorSpace: ColorSpace.sRGB), dark - Color(alpha: 1.0000, red: 0.9176, green: 0.9020, blue: 0.8706, colorSpace: ColorSpace.sRGB)
See also: contrast standard

`;

const secondIssue = `SemanticsNode#91(Rect.fromLTRB(0.0, 2.0, 38.0, 19.0), label: "Mo", textDirection: ltr):
Expected contrast ratio of at least 4.5 but found 1.13 for a font size of 15.0.
The computed colors was:
light - Color(alpha: 1.0000, red: 0.9686, green: 0.9569, blue: 0.9333, colorSpace: ColorSpace.sRGB), dark - Color(alpha: 1.0000, red: 0.9176, green: 0.9020, blue: 0.8706, colorSpace: ColorSpace.sRGB)
See also: contrast standard`;

test('parses multiple issues and normalizes semantics node IDs out of issue data', () => {
  const parsed = parseContrastReason(`${firstIssue}${secondIssue}`);
  assert.equal(parsed.issues.length, 2);
  assert.deepEqual(parsed.unparsed, []);
  assert.deepEqual(parsed.issues.map(issue => issue.semanticsNodeId), [22, 91]);
  assert.equal(parsed.issues[0].label, 'Mo');
  assert.equal(parsed.issues[0].fontSize, 15);
  assert.equal(parsed.issues[0].requiredContrast, 4.5);
  assert.equal(parsed.issues[0].measuredContrast, 1.13);
  assert.equal(parsed.issues[0].colors.light, 'Color(alpha: 1.0000, red: 0.9686, green: 0.9569, blue: 0.9333, colorSpace: ColorSpace.sRGB)');
});

test('groups duplicate cases and repeated issues while retaining case occurrence counts', () => {
  const input = {
    matrix: 'full', expected: 10, executed: 3, qualification: 'INCOMPLETE',
    results: [
      { id: 'case-a', status: 'FAIL', findings: [{ rule: 'textContrast', reason: `${firstIssue}${secondIssue}` }] },
      { id: 'case-a', status: 'FAIL', findings: [{ rule: 'textContrast', reason: firstIssue }] },
      { id: 'case-b', status: 'FAIL', findings: [{ rule: 'tapTarget', reason: 'target too small' }] },
    ],
  };
  const report = groupContrastResults(input);
  assert.equal(report.qualification, 'INCOMPLETE');
  assert.equal(report.automaticWaivers, false);
  assert.deepEqual(report.originalFailureCounts, {
    resultCases: 3,
    failedCases: 3,
    casesByStatus: { FAIL: 3 },
    findings: 3,
    findingsByRule: { textContrast: 2, tapTarget: 1 },
    textContrastFindings: 2,
    parsedContrastOccurrences: 3,
  });
  assert.equal(report.groups.length, 1);
  assert.equal(report.groups[0].occurrenceCount, 3);
  assert.deepEqual(report.groups[0].caseIds, ['case-a']);
  assert.equal(report.groups[0].caseOccurrences['case-a'], 3);
  assert.deepEqual(report.groups[0].semanticsNodeIds, [22, 91]);
  assert.deepEqual(report.unparsedFindings[0].finding, { rule: 'tapTarget', reason: 'target too small' });
});

test('keeps unknown contrast formats verbatim and does not silently drop them', () => {
  const reason = 'New SDK wording with no semantics node details';
  const report = groupContrastResults({ results: [
    { id: 'unknown-case', status: 'FAIL', findings: [{ rule: 'textContrast', reason }] },
  ] });
  assert.equal(report.groups.length, 0);
  assert.equal(report.unparsedFindings.length, 1);
  assert.equal(report.unparsedFindings[0].reason, reason);
  assert.equal(report.unparsedFindings[0].finding.reason, reason);
});

test('retains nonempty text before the first SemanticsNode as an unparsed finding', () => {
  const prefix = 'SDK preamble that may contain context\n';
  const parsed = parseContrastReason(`${prefix}${firstIssue}`);
  assert.equal(parsed.issues.length, 1);
  assert.equal(parsed.unparsed[0], prefix);
});

test('counts diagnostic classifications from Flutter paintTextContrast.details', () => {
  const report = groupContrastResults({ results: [
    { id: 'a', status: 'FAIL', findings: [{ rule: 'textContrast', reason: firstIssue }],
      paintTextContrast: { mode: 'diagnostic', details: [
        { text: 'Mo', classification: 'UNSUPPORTED' },
        { text: 'Tu', classification: 'UNSUPPORTED' },
        { text: 'We', classification: 'PROVEN_FAIL' },
      ] } },
    { id: 'b', status: 'FAIL', findings: [{ rule: 'textContrast', reason: firstIssue }],
      paintTextContrast: { mode: 'diagnostic', details: [{ text: 'Th', classification: 'UNSUPPORTED' }] } },
  ] });
  assert.deepEqual(report.diagnosticPaintClassifications, { UNSUPPORTED: 3, PROVEN_FAIL: 1 });
});

test('counter maps safely preserve special object-property names', () => {
  const report = groupContrastResults({ results: [
    { id: '__proto__', status: '__proto__', findings: [{ rule: '__proto__', reason: 'raw' }] },
    { id: 'constructor', status: 'constructor', findings: [{ rule: 'constructor', reason: 'raw' }] },
  ] });
  assert.deepEqual(report.originalFailureCounts.findingsByRule, Object.fromEntries([['__proto__', 1], ['constructor', 1]]));
  assert.deepEqual(report.originalFailureCounts.casesByStatus, Object.fromEntries([['__proto__', 1], ['constructor', 1]]));
  assert.equal(report.unparsedFindings.length, 2);
  assert.equal(report.unparsedFindings[0].caseId, '__proto__');
});

test('escapes markdown labels and links and fences unparsed reasons safely', () => {
  const adversarialReason = firstIssue.replace('label: "Mo"', 'label: "x]\n[link](url)```"');
  const rawReason = 'raw finding with ```` embedded\ntext';
  const input = { results: [
    { id: 'case](#injected)\nname', status: 'FAIL', findings: [
      { rule: 'textContrast', reason: adversarialReason },
      { rule: 'textContrast', reason: rawReason },
    ] },
  ] };
  const markdown = renderContrastMarkdown(groupContrastResults(input), { file: 'input.json', sha256: 'abc' });
  assert.ok(markdown.includes('x\\] ⏎ \\[link\\]\\(url\\)\\`\\`\\`'));
  assert.ok(markdown.includes('[case\\]\\(\\#injected\\) ⏎ name](#case-'));
  assert.ok(markdown.includes('`````text\nraw finding with ```` embedded\ntext\n`````'));
});

test('rejects malformed input and renders local case links, qualification status, and provenance', () => {
  assert.throws(() => groupContrastResults({ results: 'not-an-array' }), /results array/);
  assert.throws(() => groupContrastResults({ results: [null] }), /case id/);
  const input = { matrix: 'full', expected: 1, executed: 1, results: [
    { id: 'screen-case-1', status: 'FAIL', findings: [{ rule: 'textContrast', reason: firstIssue }] },
  ] };
  const bytes = Buffer.from(JSON.stringify(input));
  const built = buildContrastReport(input, bytes, '/private/path/results.json');
  assert.equal(built.json.provenance.file, 'results.json');
  assert.match(built.json.provenance.sha256, /^[a-f0-9]{64}$/);
  assert.match(built.markdown, /Qualification: \*\*INCOMPLETE\*\*/);
  assert.match(built.markdown, /no automatic waivers/i);
  assert.match(built.markdown, /\[screen-case-1\]\(#case-[a-f0-9]{16}\)/);
  assert.doesNotMatch(built.markdown, /private\/path/);
  const markdown = renderContrastMarkdown(groupContrastResults(input), { file: 'input.json', sha256: 'abc' });
  assert.match(markdown, /not classify a finding as a product defect or sampling artifact/);
});
