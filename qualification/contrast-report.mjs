import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const nodeStart = /SemanticsNode#(\d+)\(/g;
const labelPattern = /label:\s*((?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'))/s;
const contrastPattern = /Expected contrast ratio of at least\s+(\d+(?:\.\d+)?)\s+but found\s+(\d+(?:\.\d+)?)\s+for a font size of\s+(\d+(?:\.\d+)?)/;
const colorsPattern = /light\s+-\s+(Color\(.*?\))\s*,\s*dark\s+-\s+(Color\([^\n]+)/;

function decodeLabel(value) {
  if (value.startsWith('"')) {
    try { return JSON.parse(value); } catch { /* Keep the source text below. */ }
  }
  return value.slice(1, -1).replace(/\\(['"\\])/g, '$1');
}

/** Parse every independently reported SemanticsNode issue in a Flutter reason. */
export function parseContrastReason(reason) {
  if (typeof reason !== 'string') return { issues: [], unparsed: [String(reason)] };
  const starts = [...reason.matchAll(nodeStart)];
  if (!starts.length) return { issues: [], unparsed: [reason] };

  const issues = [];
  const unparsed = [];
  const prefix = reason.slice(0, starts[0].index);
  if (prefix.trim()) unparsed.push(prefix);
  for (let i = 0; i < starts.length; i++) {
    const start = starts[i].index;
    const end = i + 1 < starts.length ? starts[i + 1].index : reason.length;
    const block = reason.slice(start, end).trim();
    const label = block.match(labelPattern);
    const contrast = block.match(contrastPattern);
    const colors = block.match(colorsPattern);
    if (!label || !contrast || !colors) {
      unparsed.push(block);
      continue;
    }
    issues.push({
      semanticsNodeId: Number(starts[i][1]),
      label: decodeLabel(label[1]),
      requiredContrast: Number(contrast[1]),
      measuredContrast: Number(contrast[2]),
      fontSize: Number(contrast[3]),
      colors: { light: colors[1].trim(), dark: colors[2].trim() },
    });
  }
  return { issues, unparsed };
}

function groupKey(issue) {
  return JSON.stringify([
    issue.label, issue.fontSize, issue.requiredContrast, issue.measuredContrast,
    issue.colors.light, issue.colors.dark,
  ]);
}

function diagnosticPaintClassifications(results) {
  const counts = new Map();
  for (const result of results) {
    const details = result?.paintTextContrast?.details;
    if (!Array.isArray(details)) continue;
    for (const detail of details) {
      if (typeof detail?.classification !== 'string') continue;
      counts.set(detail.classification, (counts.get(detail.classification) ?? 0) + 1);
    }
  }
  return Object.fromEntries(counts);
}

/** Count the exact audit's decisions and the SDK blocks they superseded (Flutter exactTextContrast). */
function exactContrastClassifications(results) {
  const counts = new Map();
  let supersededSdkBlocks = 0;
  for (const result of results) {
    const exact = result?.exactTextContrast;
    if (!exact || typeof exact !== 'object') continue;
    if (Array.isArray(exact.superseded)) supersededSdkBlocks += exact.superseded.length;
    if (!Array.isArray(exact.details)) continue;
    for (const detail of exact.details) {
      if (typeof detail?.classification !== 'string') continue;
      counts.set(detail.classification, (counts.get(detail.classification) ?? 0) + 1);
    }
  }
  return { ...Object.fromEntries(counts), supersededSdkBlocks };
}

/** Group raw textContrast reports without interpreting whether they are genuine. */
export function groupContrastResults(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input) || !Array.isArray(input.results)) {
    throw new TypeError('Flutter results JSON must be an object with a results array');
  }
  const groups = new Map();
  const unparsedFindings = [];
  const failuresByRule = new Map();
  let failedCases = 0;
  let originalFindingCount = 0;
  let textContrastFindingCount = 0;
  const casesByStatus = new Map();

  for (const result of input.results) {
    if (!result || typeof result !== 'object' || typeof result.id !== 'string') {
      throw new TypeError('Every Flutter result must have a case id');
    }
    const status = typeof result.status === 'string' ? result.status : '(unknown status)';
    casesByStatus.set(status, (casesByStatus.get(status) ?? 0) + 1);
    const findings = Array.isArray(result.findings) ? result.findings : [];
    if (result.status === 'FAIL' || findings.length > 0) failedCases++;
    for (const finding of findings) {
      if (!finding || typeof finding !== 'object') {
        throw new TypeError(`Finding in ${result.id} must be an object`);
      }
      originalFindingCount++;
      const rule = typeof finding.rule === 'string' ? finding.rule : '(unknown rule)';
      failuresByRule.set(rule, (failuresByRule.get(rule) ?? 0) + 1);
      if (rule !== 'textContrast') {
        unparsedFindings.push({ caseId: result.id, rule, finding });
        continue;
      }
      textContrastFindingCount++;
      const parsed = parseContrastReason(finding.reason);
      for (const issue of parsed.issues) {
        const key = groupKey(issue);
        let group = groups.get(key);
        if (!group) {
          group = {
            label: issue.label,
            fontSize: issue.fontSize,
            requiredContrast: issue.requiredContrast,
            measuredContrast: issue.measuredContrast,
            colors: issue.colors,
            occurrenceCount: 0,
            caseOccurrences: new Map(),
            semanticsNodeIds: [],
          };
          groups.set(key, group);
        }
        group.occurrenceCount++;
        group.caseOccurrences.set(result.id, (group.caseOccurrences.get(result.id) ?? 0) + 1);
        if (!group.semanticsNodeIds.includes(issue.semanticsNodeId)) {
          group.semanticsNodeIds.push(issue.semanticsNodeId);
        }
      }
      for (const reason of parsed.unparsed) {
        unparsedFindings.push({ caseId: result.id, rule, reason, finding });
      }
    }
  }

  const grouped = [...groups.values()].map(group => ({
    label: group.label,
    fontSize: group.fontSize,
    requiredContrast: group.requiredContrast,
    measuredContrast: group.measuredContrast,
    colors: group.colors,
    occurrenceCount: group.occurrenceCount,
    caseOccurrences: Object.fromEntries(group.caseOccurrences),
    caseIds: [...group.caseOccurrences.keys()].sort(),
    semanticsNodeIds: group.semanticsNodeIds.sort((a, b) => a - b),
  })).sort((a, b) => b.occurrenceCount - a.occurrenceCount || a.label.localeCompare(b.label));

  return {
    schema: 1,
    qualification: 'INCOMPLETE',
    automaticWaivers: false,
    matrix: input.matrix ?? null,
    expected: input.expected ?? null,
    executed: input.executed ?? input.results.length,
    originalFailureCounts: {
      resultCases: input.results.length,
      failedCases,
      casesByStatus: Object.fromEntries(casesByStatus),
      findings: originalFindingCount,
      findingsByRule: Object.fromEntries(failuresByRule),
      textContrastFindings: textContrastFindingCount,
      parsedContrastOccurrences: grouped.reduce((sum, group) => sum + group.occurrenceCount, 0),
    },
    diagnosticPaintClassifications: diagnosticPaintClassifications(input.results),
    exactContrastClassifications: exactContrastClassifications(input.results),
    groups: grouped,
    unparsedFindings,
  };
}

function anchor(caseId) {
  return `case-${crypto.createHash('sha256').update(caseId).digest('hex').slice(0, 16)}`;
}

function escapeMarkdown(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replace(/\r\n|\r|\n/g, ' ⏎ ')
    .replace(/([\\`*_{}\[\]()#+.!|~])/g, '\\$1');
}

function caseLink(caseId) {
  return `[${escapeMarkdown(caseId)}](#${anchor(caseId)})`;
}

function codeFence(text) {
  let longest = 0;
  for (const match of text.matchAll(/`+/g)) longest = Math.max(longest, match[0].length);
  return '`'.repeat(Math.max(3, longest + 1));
}

export function renderContrastMarkdown(report, provenance) {
  const lines = [
    '# Flutter contrast diagnostic report',
    '',
    `Qualification: **${report.qualification}**. This report grants **no automatic waivers**.`,
    '',
    `Matrix: ${report.matrix ?? 'unknown'}; executed ${report.executed} of ${report.expected ?? 'unknown'} cases.`,
    `Original results: ${report.originalFailureCounts.failedCases} failing cases; ${report.originalFailureCounts.findings} findings (${report.originalFailureCounts.textContrastFindings} textContrast findings); ${report.originalFailureCounts.parsedContrastOccurrences} parsed contrast occurrences; ${report.unparsedFindings.length} retained unparsed findings.`,
    `Input: \`${provenance.file}\`; SHA-256 \`${provenance.sha256}\`.`,
    `Exact audit (retained findings exclude SDK blocks it superseded): ${Object.entries(report.exactContrastClassifications ?? {}).map(([k, v]) => `${k} ${v}`).join('; ') || 'not recorded'}.`,
    '',
    'Findings are grouped by label, font size, required and measured ratios, and reported colors. Grouping is diagnostic only; it does not classify a finding as a product defect or sampling artifact.',
    '',
    '## Repeated contrast reports',
    '',
  ];
  if (!report.groups.length) lines.push('No parseable textContrast reports were found.', '');
  for (const [index, group] of report.groups.entries()) {
    lines.push(`### ${index + 1}. “${escapeMarkdown(group.label)}”`,'',
      `- ${group.occurrenceCount} occurrence(s); font ${group.fontSize}px; required ${group.requiredContrast}:1; measured ${group.measuredContrast}:1.`,
      `- Colors: light \`${group.colors.light}\`; dark \`${group.colors.dark}\`.`,
      `- Cases: ${group.caseIds.map(caseLink).join(', ') || 'none'}.`,
      `- Semantics node IDs (informational): ${group.semanticsNodeIds.join(', ') || 'none'}.`, '');
  }
  lines.push('## Unparsed findings retained verbatim', '');
  if (!report.unparsedFindings.length) lines.push('None.', '');
  for (const [index, item] of report.unparsedFindings.entries()) {
    const reason = item.reason ?? JSON.stringify(item.finding);
    const fence = codeFence(reason);
    lines.push(`### ${index + 1}. ${caseLink(item.caseId)} (${escapeMarkdown(item.rule)})`, '', `${fence}text`, reason, fence, '');
  }
  const allCaseIds = [...new Set([
    ...report.groups.flatMap(group => group.caseIds),
    ...report.unparsedFindings.map(item => item.caseId),
  ])].sort();
  lines.push('## Case index', '');
  if (!allCaseIds.length) lines.push('None.', '');
  for (const caseId of allCaseIds) lines.push(`<a id="${anchor(caseId)}"></a>`, `- ${escapeMarkdown(caseId)}`);
  lines.push('');
  return `${lines.join('\n')}\n`;
}

export function buildContrastReport(input, sourceBytes, inputPath = 'results.json') {
  const report = groupContrastResults(input);
  const provenance = {
    file: path.basename(inputPath),
    sha256: crypto.createHash('sha256').update(sourceBytes).digest('hex'),
    bytes: Buffer.byteLength(sourceBytes),
  };
  return {
    json: { ...report, provenance },
    markdown: renderContrastMarkdown(report, provenance),
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [inputPath, outputDirectory, ...extra] = process.argv.slice(2);
  if (!inputPath || !outputDirectory || extra.length) {
    console.error('Usage: node qualification/contrast-report.mjs <results.json> <output-directory>');
    process.exitCode = 2;
  } else {
    try {
      const sourceBytes = fs.readFileSync(inputPath);
      const input = JSON.parse(sourceBytes.toString('utf8'));
      const output = buildContrastReport(input, sourceBytes, inputPath);
      fs.mkdirSync(outputDirectory, { recursive: true });
      fs.writeFileSync(path.join(outputDirectory, 'contrast-report.json'), `${JSON.stringify(output.json, null, 2)}\n`);
      fs.writeFileSync(path.join(outputDirectory, 'contrast-report.md'), output.markdown);
    } catch (error) {
      console.error(`Contrast report failed: ${error.message}`);
      process.exitCode = 1;
    }
  }
}
