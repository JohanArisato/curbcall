-- SQLite mirror of db/schema.sql (coordinates as lon/lat columns instead of PostGIS geometry).
PRAGMA foreign_keys = ON;

CREATE TABLE neighborhoods (neighborhood_id INTEGER PRIMARY KEY, name TEXT UNIQUE NOT NULL, area_name TEXT NOT NULL);
CREATE TABLE report_types (name TEXT PRIMARY KEY);
CREATE TABLE conditions (id INTEGER PRIMARY KEY, type_name TEXT REFERENCES report_types(name), label TEXT NOT NULL,
                         UNIQUE (type_name, label));
CREATE TABLE reports (
  report_id TEXT PRIMARY KEY, title TEXT NOT NULL CHECK (length(title) <= 70),
  type_name TEXT NOT NULL REFERENCES report_types(name), where_text TEXT, details TEXT,
  lon REAL NOT NULL, lat REAL NOT NULL, neighborhood TEXT REFERENCES neighborhoods(name), area_name TEXT,
  is_example INTEGER NOT NULL DEFAULT 0, created_by TEXT);
CREATE TABLE report_conditions (report_id TEXT REFERENCES reports(report_id), condition_id INTEGER REFERENCES conditions(id),
                                PRIMARY KEY (report_id, condition_id));
CREATE TABLE votes (report_id TEXT REFERENCES reports(report_id), voter TEXT NOT NULL,
                    value INTEGER NOT NULL CHECK (value IN (-1, 1)), reasons TEXT, note TEXT, voted_at TEXT,
                    PRIMARY KEY (report_id, voter));
CREATE TABLE status_updates (id INTEGER PRIMARY KEY, report_id TEXT REFERENCES reports(report_id),
                             status TEXT NOT NULL, photo_url TEXT, note TEXT, updated_at TEXT);

CREATE VIEW report_ranking AS
SELECT r.report_id, r.title, r.type_name, r.neighborhood, r.area_name, r.is_example,
       COALESCE(SUM(v.value), 0) AS net_support, COUNT(v.voter) AS voters,
       RANK() OVER (ORDER BY COALESCE(SUM(v.value), 0) DESC, COUNT(v.voter) DESC) AS city_rank,
       RANK() OVER (PARTITION BY r.area_name ORDER BY COALESCE(SUM(v.value), 0) DESC, COUNT(v.voter) DESC) AS area_rank
FROM reports r LEFT JOIN votes v ON v.report_id = r.report_id
GROUP BY r.report_id;

CREATE VIEW area_summary AS
SELECT n.area_name,
       COUNT(DISTINCT r.report_id) FILTER (WHERE r.is_example = 0) AS resident_reports,
       COUNT(DISTINCT r.report_id) FILTER (WHERE r.is_example = 1) AS example_reports,
       COUNT(v.voter) AS votes
FROM neighborhoods n
LEFT JOIN reports r ON r.neighborhood = n.name
LEFT JOIN votes v ON v.report_id = r.report_id
GROUP BY n.area_name;
