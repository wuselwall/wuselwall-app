import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

test('review application requires a protected job and never exposes download credentials to review code', () => {
  const workflow = fs.readFileSync('.github/workflows/qualify-candidate.yml', 'utf8');
  const approval = workflow.split('\n  review_approval:\n')[1]?.split('\n  flutter:\n')[0];
  assert.ok(approval, 'Missing protected review job');
  assert.match(approval, /environment: release-promotion/);
  assert.match(approval, /needs: prepare/);
  const validation = approval.split('- name: Validate the explicitly approved review without repository credentials')[1];
  assert.ok(validation);
  assert.doesNotMatch(validation, /GH_TOKEN/);
  assert.match(validation, /validateEnvironment/);
  assert.match(validation, /reviews\.mjs validate .*--approved/);
  const download = approval.split('- name: Read the review artifact')[1]?.split('- name: Validate')[0];
  assert.match(download, /GH_TOKEN:/);
  assert.doesNotMatch(download, /node |npm |bash qualification\//);
  const native = workflow.split('\n  native:\n')[1]?.split('\n  production:\n')[0];
  assert.match(native, /needs: \[prepare, review_approval\]/);
  assert.match(native, /needs\.review_approval\.result == 'success'/);
  assert.match(native, /needs\.review_approval\.result == 'skipped'/);
  assert.match(native, /QUALIFY_NATIVE_REVIEW_APPROVED: \$\{\{ needs\.review_approval\.outputs\.approved \}\}/);
  assert.match(native, /QUALIFY_NATIVE_REVIEW_SHA256: \$\{\{ needs\.review_approval\.outputs\.manifest_sha256 \}\}/);
  assert.match(workflow, /needs: \[prepare, review_approval, flutter, web, native, production\]/);
});
