import initSqlJs, { type Database, type QueryExecResult, type SqlJsStatic, type SqlValue } from "sql.js";

// Original sample dataset for the SQL Mastery course's in-browser "Try it
// Yourself" boxes — a small library domain. Chosen because it naturally
// covers every topic in the course on one schema: multi-table joins,
// aggregation, NULL handling (an open loan has no return_date), dates, a
// self-join (members.referred_by), and a "never happened" subquery (a book
// with zero loans).
export const SEED_SQL = `
CREATE TABLE genres (
  id   INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);

CREATE TABLE authors (
  id      INTEGER PRIMARY KEY,
  name    TEXT NOT NULL,
  country TEXT
);

CREATE TABLE books (
  id              INTEGER PRIMARY KEY,
  title           TEXT NOT NULL,
  author_id       INTEGER REFERENCES authors(id),
  genre_id        INTEGER REFERENCES genres(id),
  price           REAL NOT NULL,
  published_year  INTEGER,
  stock           INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE members (
  id           INTEGER PRIMARY KEY,
  name         TEXT NOT NULL,
  email        TEXT NOT NULL UNIQUE,
  joined_date  TEXT NOT NULL,
  city         TEXT,
  referred_by  INTEGER REFERENCES members(id)
);

CREATE TABLE loans (
  id           INTEGER PRIMARY KEY,
  book_id      INTEGER REFERENCES books(id),
  member_id    INTEGER REFERENCES members(id),
  loan_date    TEXT NOT NULL,
  return_date  TEXT
);

INSERT INTO genres (id, name) VALUES
  (1, 'Fiction'), (2, 'Science Fiction'), (3, 'Fantasy'),
  (4, 'Mystery'), (5, 'Non-Fiction'), (6, 'Biography');

INSERT INTO authors (id, name, country) VALUES
  (1, 'Isabel March',    'UK'),
  (2, 'Kenji Watanabe',  'Japan'),
  (3, 'Amara Diallo',    'Senegal'),
  (4, 'Lucas Ferreira',  'Brazil'),
  (5, 'Priya Nair',      'India'),
  (6, 'Oskar Lindgren',  'Sweden'),
  (7, 'Grace Whitfield', 'USA'),
  (8, 'Tomas Novak',     'Czech Republic');

INSERT INTO books (id, title, author_id, genre_id, price, published_year, stock) VALUES
  (1,  'The Silent Harbor',        1, 1, 12.99, 2018, 4),
  (2,  'Neon Tide',                2, 2, 15.50, 2021, 2),
  (3,  'Kingdom of Ash Roses',     3, 3, 18.00, 2016, 0),
  (4,  'The Cartographer''s Debt', 4, 1, 11.25, 2019, 5),
  (5,  'Signals From Rhea',        2, 2, 14.75, 2023, 3),
  (6,  'A Quiet Kind of Fire',     5, 1, 9.99,  2014, 6),
  (7,  'The Last Alchemist',       3, 3, 16.40, 2020, 1),
  (8,  'Murder on Platform Nine',  7, 4, 10.50, 2017, 2),
  (9,  'Cold Case: Reykjavik',     6, 4, 13.20, 2022, 0),
  (10, 'How Rivers Remember',      5, 5, 19.99, 2015, 3),
  (11, 'The Empire of Salt',       4, 1, 12.00, 2012, 2),
  (12, 'Watanabe: A Life',         8, 6, 22.50, 2020, 1),
  (13, 'Diallo Speaks',            8, 6, 21.00, 2021, 2),
  (14, 'Ash Roses: The Sequel',    3, 3, 18.00, 2019, 0),
  (15, 'Nobody''s Almanac',        6, 5, 8.75,  2011, 4);

INSERT INTO members (id, name, email, joined_date, city, referred_by) VALUES
  (1,  'Ana Torres',      'ana.torres@example.com',      '2021-03-14', 'Lisbon',    NULL),
  (2,  'Ben Okafor',      'ben.okafor@example.com',      '2021-06-02', 'Lagos',     1),
  (3,  'Chloe Martin',    'chloe.martin@example.com',    '2022-01-19', 'Paris',     NULL),
  (4,  'Dev Patel',       'dev.patel@example.com',       '2022-02-27', 'Mumbai',    1),
  (5,  'Elin Karlsson',   'elin.karlsson@example.com',   '2022-05-30', 'Stockholm', NULL),
  (6,  'Farid Haidari',   'farid.haidari@example.com',   '2022-09-11', 'Kabul',     3),
  (7,  'Grace Kim',       'grace.kim@example.com',       '2023-01-05', 'Seoul',     NULL),
  (8,  'Hiro Tanaka',     'hiro.tanaka@example.com',     '2023-04-22', 'Osaka',     7),
  (9,  'Ines Costa',      'ines.costa@example.com',      '2023-07-08', 'Porto',     1),
  (10, 'Jonas Weber',     'jonas.weber@example.com',     '2023-10-16', 'Berlin',    NULL);

INSERT INTO loans (id, book_id, member_id, loan_date, return_date) VALUES
  (1,  1, 1,  '2023-11-01', '2023-11-14'),
  (2,  2, 1,  '2023-12-05', '2023-12-19'),
  (3,  4, 2,  '2023-11-20', '2023-12-01'),
  (4,  5, 3,  '2024-01-03', NULL),
  (5,  1, 3,  '2024-01-10', '2024-01-24'),
  (6,  8, 4,  '2024-01-15', '2024-01-29'),
  (7,  9, 4,  '2024-02-01', NULL),
  (8,  2, 5,  '2024-02-04', '2024-02-18'),
  (9,  6, 5,  '2024-02-10', '2024-02-24'),
  (10, 6, 6,  '2024-02-12', NULL),
  (11, 10, 6, '2024-02-20', '2024-03-05'),
  (12, 4, 7,  '2024-03-01', '2024-03-15'),
  (13, 11, 7, '2024-03-02', NULL),
  (14, 5, 8,  '2024-03-10', '2024-03-24'),
  (15, 2, 9,  '2024-03-12', '2024-03-26'),
  (16, 1, 9,  '2024-03-15', NULL),
  (17, 8, 10, '2024-03-18', '2024-04-01'),
  (18, 6, 10, '2024-04-02', NULL),
  (19, 15, 2, '2024-04-05', '2024-04-19'),
  (20, 10, 3, '2024-04-08', NULL);
`;

let sqlJsPromise: Promise<SqlJsStatic> | null = null;

// Lazily loads the sql.js WASM engine once per page session (module-level
// cache, shared by every LessonSqlRunner instance) — no useEffect needed
// since this is only ever invoked from an event handler.
export function loadSqlJs(): Promise<SqlJsStatic> {
  if (!sqlJsPromise) {
    sqlJsPromise = initSqlJs({ locateFile: () => "/sql-wasm.wasm" });
  }
  return sqlJsPromise;
}

// Each try-it box gets its own fresh, isolated database so edits in one
// box (INSERT/UPDATE/DELETE) never leak into another box on the same page.
export async function createSeededDatabase(): Promise<Database> {
  const SQL = await loadSqlJs();
  const db = new SQL.Database();
  db.run(SEED_SQL);
  return db;
}

function lastResultRows(results: QueryExecResult[]): SqlValue[][] {
  if (results.length === 0) return [];
  return results[results.length - 1].values;
}

export interface GradeResult {
  correct: boolean;
  reason?: string;
}

// Grades a practice exercise: runs the student's query and the lesson
// author's solution query against two independent, freshly-seeded databases
// and compares their output. Compares cell values only (not column aliases),
// so `SELECT title AS t` still matches a solution written as `SELECT title`.
// Row order matters only if the solution query itself contains ORDER BY —
// otherwise both result sets are sorted before comparing, since two queries
// that are logically equivalent may return rows in a different order.
export async function gradeQuery(studentQuery: string, solutionQuery: string): Promise<GradeResult> {
  const [studentDb, solutionDb] = await Promise.all([createSeededDatabase(), createSeededDatabase()]);
  try {
    let studentRows: SqlValue[][];
    try {
      studentRows = lastResultRows(studentDb.exec(studentQuery));
    } catch (err) {
      return { correct: false, reason: err instanceof Error ? err.message : String(err) };
    }
    const solutionRows = lastResultRows(solutionDb.exec(solutionQuery));

    if (studentRows.length !== solutionRows.length) {
      return { correct: false, reason: `Expected ${solutionRows.length} row(s), got ${studentRows.length}.` };
    }
    const respectOrder = /order\s+by/i.test(solutionQuery);
    const normalize = (rows: SqlValue[][]) => {
      const stringified = rows.map((row) => JSON.stringify(row.map(String)));
      return respectOrder ? stringified : stringified.sort();
    };
    const studentNormalized = normalize(studentRows);
    const solutionNormalized = normalize(solutionRows);
    const matches = studentNormalized.every((row, i) => row === solutionNormalized[i]);
    return matches ? { correct: true } : { correct: false, reason: "Query ran, but the results don't match what's expected." };
  } finally {
    studentDb.close();
    solutionDb.close();
  }
}
