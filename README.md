# CurbCall

**Snap it. Vote it. Get it fixed.** A prototype where San Diego residents photograph a broken sidewalk, pothole, flooded corner or dark street, tick a short checklist, and swipe to vote on what each part of the city should fix first.

**Johan (Jhoven) Fernandez** · Product lead: concept, feature design, user flow and research framing · Prototype, not yet tested with residents

## Why

San Diego's reporting app, Get It Done, works like a complaint inbox: one report becomes one ticket. In March 2026 it had nearly 85,000 open cases, and closure times varied widely by neighborhood ([Hoodline](https://hoodline.com/2026/03/san-diego-s-get-it-done-app-drowning-in-85-000-complaints/)). CurbCall is designed as a layer on top of that system. It adds what an inbox cannot show: what residents think matters most, why, and which neighborhoods are being heard.

**Research question:** if residents can report and vote on what to fix first, whose problems get heard, and does that match where the city responds?

## How it works

1. **Snap it.** Photo, pin, category and a short infrastructure checklist, so every report is comparable.
2. **Vote it.** Swipe right to fix it (+1), left if it can wait (−1), and say why: safety, accessibility, kids and schools, flooding, heat.
3. **See the ranking.** Reports are ranked by net support within each of seven areas, from North to South Bay, so busy neighborhoods don't drown out quieter ones.

## What's in this repository

| Path | Contents |
|---|---|
| `app/index.html` | The whole app in one file. Open it in a browser: outside its hosted page it runs in preview mode with the example reports, and votes stay on your device. |
| `data/checklists.json` | Report types, checklist items and vote reasons |
| `data/example_reports.geojson` | 17 **example** reports written to demonstrate the app; not resident data |
| `db/schema.sql` | PostgreSQL + PostGIS schema: reports, votes, status updates, a trigger that assigns each pin to its neighborhood, a per-area ranking view and an area summary for research |
| `db/sqlite_schema.sql`, `db/curbcall.sqlite` | The same model in SQLite; no server needed |
| `scripts/build_db.py` | Rebuilds `db/curbcall.sqlite` and `db/seed.sql` |

Neighborhoods and areas come from the shared **[geoai-cities-db](https://github.com/JohanArisato/geoai-cities-db)** database, so CurbCall reports can be joined with my other projects' data, for example housing sites the city counts on for new homes.

## Quick start

```bash
# keep geoai-cities-db next to this repo (or set GEOAI_DB_REPO)
pip install geopandas pyogrio
python scripts/build_db.py
python -c "import sqlite3; c=sqlite3.connect('db/curbcall.sqlite'); print(c.execute('SELECT * FROM area_summary').fetchall())"
pytest -q
```

### Live database (PostGIS)

```bash
export DATABASE_URL="postgresql://..."          # Supabase or Neon free tier works
../geoai-cities-db/postgis/load.sh               # neighborhoods and areas
psql "$DATABASE_URL" -f db/schema.sql
psql "$DATABASE_URL" -f db/seed.sql
psql "$DATABASE_URL" -c "SELECT title, area_name, net_support, area_rank FROM report_ranking;"
```

Tested on PostgreSQL 16 + PostGIS 3.

## Design decisions

- A required photo and short checklist, so reports are comparable.
- One vote per person per report, with reasons, so staff see the *why* as well as the count.
- Rankings per area, not only citywide.
- Privacy by design: voter and reporter ids are hashed; photos live in object storage, never in the table; example rows are flagged and excluded from research views.
- Accessibility and language: plans for Spanish, Tagalog and Vietnamese, and ways to take part without a smartphone.

## Next steps

- Pilot with community partners in Southeast San Diego, Mid-City and South Bay.
- Consent language and ethics (IRB) review before collecting data for research.
- Pair with Get It Done response times to show where residents wait longest.

## How this was made

The app, database and repository were built with an AI assistant (Claude, Anthropic) from my product direction across several design rounds. The 17 reports are labeled examples.

Part of **[GeoAI for Cities](https://github.com/JohanArisato/geoai-for-cities)**.
