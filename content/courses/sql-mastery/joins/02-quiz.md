---
kind: quiz
id_key: sql-mastery/joins/quiz
course: sql-mastery
section: joins
section_title: "Joining Tables"
section_position: 4
title: "Quiz: Joining Tables"
position: 1
estimated_minutes: 10
source: [sql-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 10
questions:
  - id_key: inner-vs-left
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "What's the key difference between INNER JOIN and LEFT JOIN?"
    multiple: false
    options:
      - { text: "INNER JOIN only returns rows with a match in both tables; LEFT JOIN keeps every row from the left table even without a match", correct: true }
      - { text: "INNER JOIN is faster but returns identical results to LEFT JOIN in every case", correct: false }
      - { text: "LEFT JOIN can only be used with two columns of the same name", correct: false }
      - { text: "INNER JOIN keeps unmatched rows; LEFT JOIN discards them", correct: false }
    explanation: "INNER JOIN drops any row lacking a match on either side. LEFT JOIN always keeps every left-table row, filling unmatched right-side columns with NULL."
  - id_key: never-loaned-trace
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "`SELECT b.title FROM books b LEFT JOIN loans l ON b.id = l.book_id WHERE l.id IS NULL;` — what does this return?"
    multiple: false
    options:
      - { text: "Every book that has been loaned at least once", correct: false }
      - { text: "Every book that has never been loaned", correct: true }
      - { text: "Every loan that has no matching book", correct: false }
      - { text: "An error, because WHERE can't reference a joined column", correct: false }
    explanation: "LEFT JOIN keeps every book even without a loan match, producing NULL loan columns for unmatched books. Filtering to l.id IS NULL isolates exactly the books with zero loans."
  - id_key: self-join-trace
    type: mcq
    difficulty: advanced
    points: 3
    prompt: "Using a self join on members (m.referred_by = r.id), who referred Hiro Tanaka? (Hiro Tanaka's referred_by points at member id 7.)"
    multiple: false
    options:
      - { text: "Ana Torres" }
      - { text: "Chloe Martin" }
      - { text: "Grace Kim", correct: true }
      - { text: "No one — Hiro Tanaka joined with no referrer" }
    explanation: "Member id 7 is Grace Kim, so Hiro Tanaka's referred_by (7) resolves to Grace Kim in the self join."
  - id_key: mysql-full-outer-workaround
    type: mcq
    difficulty: advanced
    points: 2
    prompt: "MySQL has historically had no native FULL OUTER JOIN. What's the standard workaround?"
    multiple: false
    options:
      - { text: "A LEFT JOIN combined with a RIGHT JOIN (or a mirrored LEFT JOIN), combined with UNION to de-duplicate overlapping rows", correct: true }
      - { text: "MySQL simply cannot express a full outer join under any circumstances", correct: false }
      - { text: "Running the query twice and manually merging the results in application code", correct: false }
      - { text: "Using INNER JOIN with an extra WHERE clause", correct: false }
    explanation: "A LEFT JOIN unions with a RIGHT JOIN (or a second LEFT JOIN with tables swapped) reproduces FULL OUTER JOIN behavior, with UNION removing the rows both sides already agree on."
  - id_key: union-vs-union-all
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "What's the difference between UNION and UNION ALL?"
    multiple: false
    options:
      - { text: "UNION requires the two SELECTs to query the same table; UNION ALL does not", correct: false }
      - { text: "UNION removes duplicate rows that appear in both result sets; UNION ALL keeps every row, duplicates included", correct: true }
      - { text: "UNION ALL is only valid inside a subquery", correct: false }
      - { text: "UNION sorts the combined result; UNION ALL does not", correct: false }
    explanation: "UNION de-duplicates the combined rows; UNION ALL skips that step entirely, so it's both faster and keeps duplicates."
  - id_key: union-all-overlap-trace
    type: mcq
    difficulty: advanced
    points: 3
    prompt: "Amara Diallo (author_id 3) wrote exactly the three Fantasy (genre_id 3) books in the library — no more, no less. How many rows does `SELECT title FROM books WHERE author_id = 3 UNION ALL SELECT title FROM books WHERE genre_id = 3;` return?"
    multiple: false
    options:
      - { text: "3 — UNION ALL always de-duplicates" }
      - { text: "6 — each of the three titles appears twice, once from each SELECT", correct: true }
      - { text: "0 — the two conditions never overlap" }
      - { text: "9 — because author_id and genre_id together match nine books" }
    explanation: "Since every author-3 book is also a genre-3 book, both SELECTs produce the same three titles. UNION ALL doesn't remove duplicates, so all six rows come back — 3 + 3."
---
