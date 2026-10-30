# 06 — Module: Tasks & Gamification (A2)

Implements FR-2.1 – FR-2.12. This is the module most likely to succeed or fail on
psychology rather than engineering, so the design rationale gets as much space as the
mechanics.

## Design position

You chose **points with redeemable rewards** plus **streaks and badges**, for households
whose children are usually of different ages — the reference household
([21](21-household-settings.md#the-reference-household)) has a 7-year-old and a
9-year-old. Three consequences follow, and they are worth accepting deliberately rather
than discovering later. The numbers below are curated defaults; every one of them is a
household setting ([21](21-household-settings.md#tasks-and-gamification-m12)).

**1. The age gap is the hard part.** A nine-year-old understands a savings
economy: 40 points now, cinema trip in three weeks. A seven-year-old largely does not —
the reward has to be visible within days or the points stop meaning anything. The
mechanism that handles this without two separate systems is **rewards at different price
points**, with genuinely cheap ones (5–10 points: choose the Saturday film, stay up
fifteen minutes longer) alongside expensive ones. Same economy, different time horizons.

**2. Sibling comparison is left out on purpose.** A leaderboard between a 7- and a
9-year-old is a machine for producing an unhappy younger child, because the older one
will win almost every week on reading speed and stamina alone. FR-2.12 is a deliberate
"won't". If you want a shared goal, use a **family goal**: a household-wide points bar
that unlocks a joint reward. Cooperation instead of competition, same motivational pull,
none of the resentment.

**3. Extrinsic rewards erode intrinsic motivation** when they are attached to things a
child would have done anyway. The practical mitigation is not to abandon points — it is
to keep the point-earning surface narrow. Mandatory duties (`kind='duty'`) are simply
expected; they build a streak and satisfaction, and award few or no points. Points
concentrate on `kind='bonus'` tasks — genuinely optional, above-and-beyond work. If
everything earns points, nothing does, and you have taught your children that unpaid
family contribution is not a thing.

## Definitions vs instances

The central modelling decision: a **task definition** is a template, a **task instance**
is one concrete occurrence with state.

```
task_definition                        task_instance
  "Empty the dishwasher"      ──▶        due 2026-08-29, Emma, open
  RRULE:FREQ=DAILY                       due 2026-08-30, Jonas, open
  assignment: rotating                   due 2026-08-31, Emma, open
  points: 3, kind: duty
```

A **materialiser job** (`pg_cron` invoking the `materialise-tasks` Edge Function, which
needs the shared RRULE code) runs nightly and creates instances for a rolling 14-day horizon.
Reasons this beats computing occurrences on the fly:

- Instances carry state (done, by whom, when, verified) that has nowhere to live otherwise.
- Rotation needs a durable cursor: "whose turn is it next" must survive a restart.
- Editing a definition must not retroactively rewrite last week's history. Instances
  snapshot `title`, `points` and `kind` at creation, so changing a chore from 3 points
  to 5 does not silently revalue what was already done.

The job also expires instances whose window has passed (`opens_on + window_days`), so
the list does not accumulate three-week-old guilt.

## Assignment policies

| Policy | Behaviour | Good for |
|---|---|---|
| `fixed` | Always the same person | "Jonas: feed the cat" |
| `rotating` | Round-robin through a pool, cursor persisted | "Empty the dishwasher" |
| `open` | One instance, unassigned; whoever completes it claims it | "Bring the bins out" |
| `each` | One instance per person in the pool | "Tidy your room" |

`open` tasks are where the point economy gets interesting: a bonus task nobody is
obliged to do, visible on the wall display, first come first served. Consider a small
"ageing bonus" for open tasks that stay open — a task worth 5 points on day one and 8 by
day three clears itself.

## The points ledger

Append-only. **There is no balance column.** Every credit and debit is a
`point_transaction` row with a reason and a source reference, and a balance is the sum.

Why this matters beyond bookkeeping purity: when a child says "I had more points
yesterday", you can show them exactly what happened. A mutable counter cannot do that,
and the first unexplained discrepancy is the moment the whole system loses credibility
with the people it is meant to motivate.

Two structural safeguards from [04](04-data-model.md):

- A unique index on `(source_type, source_id)` means one completed task can never credit
  points twice, no matter how many times a request is retried on a flaky supermarket
  connection.
- Guardian corrections use `reason='adjustment'` and appear in the audit log with the
  guardian's name. Corrections are possible but never invisible.

## Rewards

```
requested ──▶ approved ──▶ fulfilled
     └──────▶ declined
```

- Points are debited at **approved**, not at requested. A pending request does not
  freeze the balance; approval revalidates it and fails if the balance no longer covers
  the cost.
- Approval is a guardian action and therefore requires a PIN step-up ([08](08-users-auth-permissions.md)).
- `stock` limits scarce rewards. `requires_approval = false` is available for trivial
  ones you are happy to have self-served.
- Declining should carry an optional note. "Not this week — we're away" lands very
  differently from a silent rejection.
- A child asks for a reward (the kid register's Punkte tab, or the adult Belohnungen tab
  while a child is the acting profile on a shared device). With a grown-up acting, that
  tab is the catalogue: a tap edits a reward, and there is no request button and no
  "x Punkte fehlen" computed from the grown-up's own balance.

Seed the reward catalogue with roughly a 1 : 3 : 10 cost ratio so younger and older
children can both engage: something at 5 points, something at 15, something at 50. The
starter rewards are offered when a household is created ([21](21-household-settings.md), [Q4](14-open-questions.md)).

## Streaks

Per `(profile, definition)`, advanced by the nightly job.

- A streak counts consecutive **due** days completed, not consecutive calendar days —
  a weekly chore builds a streak of weeks.
- **Joker days** are the anti-frustration mechanism: a household setting
  (`tasks.jokers_per_month`, default 1, overridable per member — [Q7](14-open-questions.md))
  that absorbs a miss without breaking the chain. Jokers count **per streak** and per
  calendar month, and the nightly job uses them automatically: a sick day misses every
  chore that day, and each chain survives it. A
  seven-year-old losing a 22-day streak to one sick day is a real, avoidable source of
  tears.
- Streaks never go negative and are never displayed comparatively. The framing is
  "you're on 12 days", never "Jonas is on 19".

## Badges

`badge_definition.rule` is a small JSON predicate evaluated by the nightly job, not
arbitrary code:

```json
{ "type": "streak_reached",     "definitionKey": "dishwasher", "length": 14 }
{ "type": "total_tasks",        "count": 100 }
{ "type": "points_earned",      "amount": 500 }
{ "type": "distinct_tasks_week","count": 5 }
{ "type": "first_time",         "definitionKey": "cooked_dinner" }
```

Keep the set small at launch — six to eight — and add more when you see what actually
gets done. Badges are cheap to add and impossible to remove without disappointment.

## Verification

`requires_verification` holds points in `done` until a guardian moves the instance to
`verified`. Use it sparingly: on high-value bonus tasks, or where "done" is genuinely
ambiguous ("tidy your room"). Applying it broadly turns every chore into an inspection
and adds a parental bottleneck that will quietly kill adoption within a fortnight.

## Screens

| Screen | Register | Content |
|---|---|---|
| My tasks | kid | Today's instances as large cards with icons; one tap to complete; points fly into the balance |
| Balance & rewards | kid | Current balance, reward shop with affordability clearly shown, redemption history |
| Family board | kiosk | Today's tasks for every member in columns, done items visibly struck through, streak indicators |
| Chore admin | adult | Definition CRUD, rotation pools, points, verification flags — laptop-oriented, dense |
| Approvals | adult | Pending redemptions and verifications, with a PIN gate |

Feedback on completion should be immediate and physical: a tick animation, the points
counter incrementing visibly, a short sound the child can switch off. This is the part
that makes a 7-year-old want to open the app, and it is worth more implementation time
than it looks like it deserves.

## v1 scope cut

**In:** definitions with RRULE, all four assignment policies, the materialiser, duty vs
bonus, the ledger, rewards with an approval flow, streaks with jokers, three or four
badges, the kid task screen and the kiosk board.

**Out:** the family goal bar, ageing bonuses on open tasks, photo proof of completion,
task dependencies, time estimates, seasonal point resets, allowance payouts, and
anything resembling a leaderboard.
