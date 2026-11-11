// Job-level selection only: required status workflows always run. Unknown inputs and
// unavailable diffs select every check; manual, reusable and tag runs are always full.
import { execFileSync } from 'node:child_process';
import { appendFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export const fullChecks = () => ({ app: true, browser: true, backend: true, edge: true });

export function classifyPaths(paths) {
  const checks = { app: false, browser: false, backend: false, edge: false };
  if (!paths.length) return fullChecks();
  for (const path of paths) {
    if (!path || path.startsWith('/') || path.split('/').includes('..')) return fullChecks();
    if (/^\.github\/workflows\//.test(path) || /^scripts\/ci-(changes|gate)(\.test)?\.mjs$/.test(path)) return fullChecks();
    if (/^(package(-lock)?\.json|deno\.lock)$/.test(path)) return fullChecks();
    if (/^supabase\//.test(path)) {
      checks.backend = true;
      if (/^supabase\/migrations\//.test(path)) checks.app = true;
      if (/^supabase\/(functions|templates)\//.test(path)) checks.edge = true;
      continue;
    }
    if (/^app\//.test(path)) {
      if (/\.md$/.test(path)) continue;
      checks.app = true;
      if (/^app\/(web\/|env\/|pubspec\.(yaml|lock)$|lib\/(main[^/]*\.dart$|app\/(bootstrap|router|app|server_session)\.dart$|core\/(cache|config|server|storage|supabase)\/|features\/(setup|identity|shopping)\/))/.test(path)) checks.browser = true;
      if (/^app\/(pubspec\.(yaml|lock)$|env\/|dart_test\.yaml$|test\/integration\/|lib\/(app\/(bootstrap|server_session)\.dart$|core\/(cache|config|server|storage|supabase|error|connectivity|realtime)\/|features\/[^/]+\/(data|domain|application)\/))/.test(path)) checks.backend = true;
      // A new app area must not silently miss the server/transport gate.
      if (!/^app\/(lib\/(main[^/]*\.dart$|app\/|core\/(cache|config|connectivity|error|l10n|legal|logging|matching|notifications|realtime|server|storage|supabase|text|time|ui|wusel)\/|demo\/|l10n\/|features\/[^/]+\/(ui|data|domain|application)\/)|test\/|l10n\/|assets\/|web\/|env\/|android\/|ios\/|linux\/|macos\/|windows\/|qualification\/|qualification_test\/|integration_test\/|test_driver\/|tool\/|pubspec\.(yaml|lock)$|[^/]+\.(yaml|json)$)/.test(path)) return fullChecks();
      continue;
    }
    if (/^dictionary\//.test(path)) checks.app = true;
    if (/^scripts\/(backend-stack-images|image-pull)(\.test)?\.mjs$/.test(path) || /^scripts\/local-pgtap\//.test(path)) checks.backend = true;
    if (/^scripts\/.*\.browser\.mjs$/.test(path)) checks.browser = true;
    if (path === 'specs/mockups/shopping-quick-add.html') checks.browser = true;
    // These have their own script, documentation or candidate checks. They are not
    // Flutter test or app-server contract inputs. Everything else fails open below.
    if (/^(docs\/|specs\/|scripts\/|qualification\/|dictionary\/|server\/|infra\/|licenses\/|store\/|\.github\/(ISSUE_TEMPLATE\/|rulesets\/|[^/]+$))/.test(path) || /^[^/]+\.(md|txt)$/.test(path) || /^(LICENSE|NOTICE|\.gitignore|\.gitattributes|osv-scanner\.toml)$/.test(path)) continue;
    return fullChecks();
  }
  return checks;
}

export function detectChecks({ event, base, head, diff, full = false }) {
  if (full || event !== 'pull_request' || !/^[a-f0-9]{40}$/.test(base || '') || !/^[a-f0-9]{40}$/.test(head || '')) return fullChecks();
  try {
    // Use the PR merge base so unrelated changes on main do not select builds.
    // Include both paths of a rename so moving a contract into a UI directory cannot
    // hide its removal from backend validation.
    return classifyPaths(diff(base, head).split('\0').filter(Boolean));
  } catch {
    return fullChecks();
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const checks = detectChecks({ event: process.env.EVENT_NAME, full: process.env.FULL_CHECKS === 'true', base: process.env.BASE_SHA, head: process.env.HEAD_SHA,
    diff: (base, head) => execFileSync('git', ['diff', '--no-renames', '--name-only', '-z', `${base}...${head}`], { encoding: 'utf8' }) });
  const output = Object.entries(checks).map(([name, selected]) => `${name}=${selected}`).join('\n') + '\n';
  console.log(output);
  appendFileSync(process.env.GITHUB_OUTPUT, output);
}
