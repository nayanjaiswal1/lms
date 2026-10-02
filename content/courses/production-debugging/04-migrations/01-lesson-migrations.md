---
kind: lesson
id_key: production-debugging/lesson-migrations-graph-and-data
course: production-debugging
section: django-migrations
section_title: "Migrations"
section_position: 4
section_group: "Django"
title: "Debugging migrations: the graph and the data"
position: 1
estimated_minutes: 20
source:
    - docs/debug-labs.md
---

A migration bug is a deployment bug: it is discovered at the worst moment, on the machine you cannot experiment on. The skill this section trains is bringing the failure back to your own machine, by reproducing the exact starting state the migration ran on.

## Migrations are a graph, and the numbers are decoration

Each migration lists its dependencies; the file number is only a naming convention. Two migrations that depend on the same parent are two leaf nodes, and `migrate` refuses to choose an order. Learn to read the graph (`showmigrations`, the dependencies list at the top of each file) rather than the file names, and to fix a fork by merging it, not by deleting files that may already have been applied somewhere.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-mig-graph-q1", "type": "mcq",
      "prompt": "Two branches each add orders/migrations/0004_something.py depending on 0003. After merging, migrate fails with conflicting leaf nodes. What is the right fix?",
      "options": [
        {"id":"a","text":"Delete one of the migrations"},
        {"id":"b","text":"Add a merge migration that depends on both 0004 migrations"},
        {"id":"c","text":"Rename one file to 0005"},
        {"id":"d","text":"Run migrate with --fake"}
      ],
      "correct": "b",
      "explanation": "The dependencies define the graph, not the numbers. A merge migration depending on both leaves restores a single head without discarding history that may already be applied elsewhere." }
] }
```

## Reproduce the starting state, not just the code

A migration is a function of the schema and the data it meets. It can pass on an empty database and on staging and still fail on production because production has NULLs, duplicates and legacy values nobody remembers. To debug it, recreate that starting state: migrate a scratch database back to the migration before the failing one, insert rows shaped like production, then migrate forward and read the actual error.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-mig-data-q1", "type": "mcq",
      "prompt": "A migration works locally and in staging but fails on production with a unique-index error. What should you do first?",
      "options": [
        {"id":"a","text":"Re-run it on production until it works"},
        {"id":"b","text":"Reproduce it on a scratch database: migrate to the previous migration, insert production-shaped rows, then migrate forward"},
        {"id":"c","text":"Remove the unique constraint from the model"},
        {"id":"d","text":"Wrap the backfill in try/except"}
      ],
      "correct": "b",
      "explanation": "The migration depends on data you have not reproduced yet. Recreating the pre-migration state with realistic rows lets you see the exact failure and test the fix, on your machine." }
] }
```

## Expand, backfill, constrain

The safe shape for adding a required or unique column is three steps: add it nullable (expand), fill it with values that satisfy the future constraint by construction (backfill), then tighten it (constrain). Most migration failures on real data are a backfill that assumed the data was clean. Keep migrations reversible where you can, keep the model and the migrations in agreement (`makemigrations --check` in CI), and never weaken the model just to make a deploy pass.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-mig-shape-q1", "type": "mcq",
      "prompt": "You backfill a new unique slug column from an optional, non-unique title. What is the safest backfill?",
      "options": [
        {"id":"a","text":"slugify(title) alone"},
        {"id":"b","text":"A value that is unique by construction, for example the slugified title (or a default word) plus the primary key"},
        {"id":"c","text":"A random number with no relation to the row"},
        {"id":"d","text":"Leave the column empty and drop the unique constraint"}
      ],
      "correct": "b",
      "explanation": "Titles can be missing or repeated. Deriving the slug from data you do not control cannot guarantee uniqueness; adding the primary key does." }
] }
```
