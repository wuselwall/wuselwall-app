// Which app release fits which server release, read from the release tags when the docs
// are built (docs.yml checks out the whole history with its tags), so the table cannot
// fall behind a release. A server tag (server-v0.3.0) carries its API version and the
// oldest app it accepts in the migrations (api.server_info); an app tag (v1.1.0) carries
// the API version it speaks in app/lib/core/server/server_compat.dart. An app speaks its
// own API version and the one before it (ADR-018, decision 5).
import { execFileSync } from 'node:child_process'

export type ServerRelease = { version: string; date: string; api: number; minApp: string }
export type AppRelease = { version: string; date: string; api: number }
export type Compat = { servers: ServerRelease[]; apps: AppRelease[] }

declare const data: Compat
export { data }

const git = (...args: string[]): string =>
  execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] })

const semver = (v: string): number[] => v.split('.').map((p) => Number.parseInt(p, 10) || 0)
const newestFirst = (a: { version: string }, b: { version: string }): number => {
  const x = semver(a.version)
  const y = semver(b.version)
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return y[i] - x[i]
  return 0
}

function tags(pattern: RegExp): string[] {
  return git('tag', '--list')
    .split('\n')
    .map((t) => t.trim())
    .filter((t) => pattern.test(t))
}

const dateOf = (tag: string): string => git('log', '-1', '--format=%cs', tag).trim()

/** The last values api.server_info() was given in the migrations at [tag]. */
function serverContract(tag: string): { api: number; minApp: string } | null {
  const files = git('ls-tree', '--name-only', tag, 'supabase/migrations/')
    .split('\n')
    .filter((f) => f.endsWith('.sql'))
    .sort()
  let api: number | null = null
  let minApp: string | null = null
  for (const file of files) {
    const sql = git('show', `${tag}:${file}`)
    for (const m of sql.matchAll(/'api_version',\s*(\d+)/g)) api = Number(m[1])
    for (const m of sql.matchAll(/'min_app_version',\s*'(\d+\.\d+\.\d+)'/g)) minApp = m[1]
  }
  return api === null || minApp === null ? null : { api, minApp }
}

/** The API version the app at [tag] speaks; null for an app from before the check. */
function appContract(tag: string): number | null {
  try {
    const dart = git('show', `${tag}:app/lib/core/server/server_compat.dart`)
    const m = dart.match(/const appApiVersion = (\d+);/)
    return m ? Number(m[1]) : null
  } catch {
    return null
  }
}

export default {
  load(): Compat {
    try {
      const servers: ServerRelease[] = []
      for (const tag of tags(/^server-v\d+\.\d+\.\d+$/)) {
        const contract = serverContract(tag)
        if (contract) servers.push({ version: tag.slice('server-v'.length), date: dateOf(tag), ...contract })
      }
      const apps: AppRelease[] = []
      for (const tag of tags(/^v\d+\.\d+\.\d+$/)) {
        const api = appContract(tag)
        if (api !== null) apps.push({ version: tag.slice(1), date: dateOf(tag), api })
      }
      return { servers: servers.sort(newestFirst), apps: apps.sort(newestFirst) }
    } catch {
      // No git or no history (a source archive): the page says there is nothing yet.
      return { servers: [], apps: [] }
    }
  },
}
