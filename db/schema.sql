-- CurbCall database schema: PostgreSQL 14+ with PostGIS.
-- Load the shared GeoAI Cities layers first (geoai-cities-db/postgis/load.sh), which creates
-- sd_neighborhoods and sd_areas. Then run this file, then seed.sql.

CREATE EXTENSION IF NOT EXISTS postgis;

-- Infrastructure categories and their checklist items ------------------------
CREATE TABLE IF NOT EXISTS report_types (
  name TEXT PRIMARY KEY            -- Sidewalk, Crosswalk, Pothole, Streetlight, Flooding, Bike lane, Shade and trees, Other
);

CREATE TABLE IF NOT EXISTS conditions (
  id         SERIAL PRIMARY KEY,
  type_name  TEXT REFERENCES report_types(name),   -- NULL = applies to every type
  label      TEXT NOT NULL,
  UNIQUE (type_name, label)
);

-- One row per photo report --------------------------------------------------
CREATE TABLE IF NOT EXISTS reports (
  report_id        TEXT PRIMARY KEY,
  title            TEXT NOT NULL CHECK (char_length(title) <= 70),
  type_name        TEXT NOT NULL REFERENCES report_types(name),
  where_text       TEXT,
  details          TEXT,
  geom             GEOMETRY(Point, 4326) NOT NULL,
  neighborhood     TEXT,                          -- filled from the pin by trigger
  area_name        TEXT,
  photo_url        TEXT,                          -- object storage URL; never store raw images here
  is_example       BOOLEAN NOT NULL DEFAULT FALSE, -- demo rows are excluded from research views
  created_by       TEXT,                          -- opaque or hashed id, never a name or email
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS reports_geom_idx ON reports USING GIST (geom);

CREATE TABLE IF NOT EXISTS report_conditions (
  report_id     TEXT REFERENCES reports(report_id) ON DELETE CASCADE,
  condition_id  INT  REFERENCES conditions(id),
  PRIMARY KEY (report_id, condition_id)
);

-- One vote per person per report: fix it (+1) or not now (-1) ---------------
CREATE TABLE IF NOT EXISTS votes (
  report_id  TEXT REFERENCES reports(report_id) ON DELETE CASCADE,
  voter      TEXT NOT NULL,                       -- hashed id
  value      SMALLINT NOT NULL CHECK (value IN (-1, 1)),
  reasons    TEXT[] NOT NULL DEFAULT '{}',        -- Safety, Accessibility, Kids and schools, ...
  note       TEXT,
  voted_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (report_id, voter)
);

-- Progress from Reported to Fixed, with before/after photos -----------------
CREATE TABLE IF NOT EXISTS status_updates (
  id          SERIAL PRIMARY KEY,
  report_id   TEXT REFERENCES reports(report_id) ON DELETE CASCADE,
  status      TEXT NOT NULL CHECK (status IN ('Reported', 'Sent to city', 'Scheduled', 'Fixed', 'Closed without fix')),
  photo_url   TEXT,
  note        TEXT,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Assign neighborhood and area from the pin ---------------------------------
CREATE OR REPLACE FUNCTION assign_neighborhood() RETURNS trigger AS $$
BEGIN
  SELECT n.name, n.area_name INTO NEW.neighborhood, NEW.area_name
  FROM sd_neighborhoods n WHERE ST_Within(NEW.geom, n.geom) LIMIT 1;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS reports_assign_neighborhood ON reports;
CREATE TRIGGER reports_assign_neighborhood BEFORE INSERT OR UPDATE OF geom ON reports
FOR EACH ROW EXECUTE FUNCTION assign_neighborhood();

-- Ranking shown in the app: net support, citywide and within each area ------
CREATE OR REPLACE VIEW report_ranking AS
SELECT r.report_id, r.title, r.type_name, r.neighborhood, r.area_name, r.is_example,
       COALESCE(SUM(v.value), 0)                       AS net_support,
       COUNT(v.voter)                                  AS voters,
       COUNT(v.voter) FILTER (WHERE v.value = 1)       AS fix_votes,
       RANK() OVER (ORDER BY COALESCE(SUM(v.value), 0) DESC, COUNT(v.voter) DESC)   AS city_rank,
       RANK() OVER (PARTITION BY r.area_name
                    ORDER BY COALESCE(SUM(v.value), 0) DESC, COUNT(v.voter) DESC)   AS area_rank
FROM reports r LEFT JOIN votes v ON v.report_id = r.report_id
GROUP BY r.report_id;

-- Research view: who is being heard, per area (examples excluded) -----------
CREATE OR REPLACE VIEW area_summary AS
SELECT a.area_name,
       COUNT(DISTINCT r.report_id)                                   AS reports,
       COUNT(v.voter)                                                AS votes,
       COUNT(DISTINCT v.voter)                                       AS voters,
       COUNT(DISTINCT r.report_id) FILTER (WHERE s.status = 'Fixed') AS fixed
FROM sd_areas a
LEFT JOIN reports r ON r.area_name = a.area_name AND NOT r.is_example
LEFT JOIN votes v ON v.report_id = r.report_id
LEFT JOIN status_updates s ON s.report_id = r.report_id
GROUP BY a.area_name;
