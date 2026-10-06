import sqlite3
from pathlib import Path

DB = Path(__file__).resolve().parents[1] / "db" / "curbcall.sqlite"


def test_examples_are_flagged_and_located():
    c = sqlite3.connect(DB)
    rows = c.execute("SELECT is_example, neighborhood, area_name FROM reports").fetchall()
    assert len(rows) == 17
    assert all(r[0] == 1 and r[1] and r[2] for r in rows)


def test_area_summary_excludes_examples():
    c = sqlite3.connect(DB)
    s = c.execute("SELECT SUM(resident_reports), SUM(example_reports) FROM area_summary").fetchone()
    assert s == (0, 17)
    assert len(c.execute("SELECT * FROM area_summary").fetchall()) == 7


def test_one_vote_per_person_and_ranking():
    c = sqlite3.connect(":memory:")
    c.executescript(DB.with_name("sqlite_schema.sql").read_text())
    c.execute("INSERT INTO neighborhoods VALUES (1,'A','North')")
    c.execute("INSERT INTO report_types VALUES ('Pothole')")
    for i in ("r1", "r2"):
        c.execute("INSERT INTO reports VALUES (?,?,?,?,?,?,?,?,?,?,?)", (i, i, "Pothole", "", "", 0, 0, "A", "North", 0, None))
    c.executemany("INSERT INTO votes VALUES (?,?,?,?,?,?)",
                  [("r1", "a", 1, "", "", ""), ("r1", "b", 1, "", "", ""), ("r2", "a", -1, "", "", "")])
    try:
        c.execute("INSERT INTO votes VALUES ('r1','a',1,'','','')")
        raise AssertionError("duplicate vote accepted")
    except sqlite3.IntegrityError:
        pass
    assert c.execute("SELECT report_id FROM report_ranking WHERE area_rank = 1").fetchone()[0] == "r1"
