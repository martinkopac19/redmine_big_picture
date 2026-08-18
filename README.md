# Redmine Big Picture

A portfolio and pre-development tracker for Redmine. It covers the stage *before* a project
becomes real development work: collecting ideas, letting stakeholders score them, tracking how
ready each one is for development, and planning who will work on what in the coming months.

It is meant to replace the spreadsheet that teams usually keep for this, without giving up
Redmine's issues, permissions and history.

A portfolio project is an ordinary Redmine issue on a tracker you choose. Description, status,
comments and journal therefore stay native — the plugin only adds three screens on
top and stores its own scores, phases and allocations alongside.

## Screens

**Priorities** (`/big_picture`) lists portfolio projects grouped by Project Manager and sorted by
score. Columns: project, idea owner, OPP score, dev readiness (as a bar), whether project evidence
exists, and status as a coloured label. You can filter by name, status, PM, idea owner, minimum
score, minimum readiness and presence of evidence, and sort by score, readiness or status. The
list reads pre-computed metrics from a cache table, so it stays flat at a constant number of
queries even with hundreds of projects.

**Project card** (`/big_picture/:id`) shows the two headline metrics, the description from the
issue, the project-evidence link, stakeholder scoring and the pre-dev phases. Scores and phases
are dropdowns that save over AJAX and recompute both metrics immediately. Each score row records
who set it and when.

**Calendar** (`/big_picture/calendar`) is an editable grid of developers × months. Developers are
grouped under their PM, which is derived from the projects they are most often allocated to. An
allocation is a chip in a cell — either a portfolio project or free text (useful for maintenance
or placeholders) — and chips can be dragged to another month or person, or duplicated into the
next month. Each developer can carry a free-text capacity note. Instead of paging, the grid
scrolls horizontally: it is anchored on last month and shows eight months by default, extendable
six at a time in either direction.

## How the two metrics are computed

**OPP TOTAL SCORE** is the arithmetic mean of the stakeholder scores that are filled in. Each
stakeholder scores 1–3, and anything left at *no score* is skipped entirely — it counts neither
towards the sum nor the divisor. A project scored 3 and 1 with five stakeholders left empty
therefore reads 2.00, not 0.80.

**DEV READINESS** is the share of pre-dev phases marked `DONE`, out of the phases that apply.
Phases set to `NOT APPLY` drop out of the denominator, so a project with four phases where one
does not apply and two are done reads 67 %, not 50 %. The remaining states are `IN PROGRESS`
and `NO`.

Both are cached in `bp_project_metrics` and refreshed from model callbacks whenever a score or a
phase changes, so the list never serves stale numbers.

Changing a score or a phase also writes a normal Redmine journal entry onto the issue. The
history of *why* a project moved is therefore in the issue itself, and it goes out through the
usual notifications.

## Requirements

Redmine 6.x. Developed and used on 6.1; the migrations target Rails 7.2, so 6.0 is the floor.
No external services and no changes to Redmine core.

## Installation

The plugin needs two custom fields that it looks up **by name**, so create them first if you do
not have them already — both of format *user*, both *for all projects*:

- `Project Manager` — used to group Priorities and the calendar
- `Idea owner` — shown as a column and offered as a filter

Then install as usual:

```bash
cd /path/to/redmine/plugins
git clone https://github.com/martinkopac19/redmine_big_picture.git
cd ..
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

Restart Redmine, then run the one-off seed script:

```bash
RAILS_ENV=production bundle exec rails runner plugins/redmine_big_picture/extra/seed.rb
```

The seed creates the `Big Picture` tracker and selects it in the plugin settings, creates the
`Project evidence` custom field (format *link*), attaches the three fields to the tracker, adds
the `Dev prep` and `Ready for dev` statuses with workflow transitions for every role, enables the
tracker in every active project, and back-fills the metric cache. It is idempotent, so re-running
it is safe.

Finally, grant the permissions. `View Big Picture` and `Manage Big Picture` are **global**
permissions, not per-project ones — Administration → Roles and permissions → *Big Picture*.
Without them the pages return 403 even for members of the projects involved.

## Configuration

Administration → Plugins → Big Picture:

| Setting | What it does |
|---|---|
| Hide plugin | Removes the header link. **Not** a disable — tracker, fields, scores and data stay untouched, and the pages remain reachable by direct URL. Takes effect without a restart. |
| Big Picture tracker | Which tracker's issues are portfolio projects. |
| Developer roles | Roles treated as developers; only these people are offered in the calendar. Empty falls back to roles named `Developer` / `Developer-HU`, then to all active users. |
| Stakeholders | One per line; the order is the order they appear in scoring. |
| Pre-dev phases | One per line; the order is the order in the Progress section. |

Renaming a stakeholder or a phase does not migrate the rows already stored under the old name —
those simply stop being shown. Plan the lists before scoring starts, or expect to fix the
`bp_scores` / `bp_phases` rows by hand.

## Rough edges worth knowing

- The custom fields are matched by their **exact English names**. Rename or localise
  `Project Manager`, `Idea owner` or `Project evidence` in Redmine and the corresponding column,
  filter or grouping silently goes blank.
- The seed enables the tracker in **every active project**, so the *Big Picture* tracker shows up
  in the new-issue dropdown everywhere. That is deliberate — an idea can be raised anywhere — but
  it is a visible change across the whole instance.
- Permissions are global. There is no way to expose the portfolio to one project only.
- A developer's PM in the calendar is a guess: the most frequent PM across their project
  allocations. Someone splitting time evenly between two PMs lands under one of them arbitrarily.
- `extra/selftest.rb` is a regression check for the metric maths, but it has a hard-coded
  `Project.find(19)`. Change that to a project id of your own before running it.
- A `Product` custom field is still looked up by the controller and still has a translation
  string, but no screen displays it. Leftover from an earlier version.

## License

Copyright (C) 2026 Martin Kopáč

GPL-2.0-or-later, matching Redmine. See [LICENSE](LICENSE).
