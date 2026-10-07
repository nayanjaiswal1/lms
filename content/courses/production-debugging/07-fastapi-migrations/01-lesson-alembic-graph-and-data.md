---
kind: lesson
id_key: production-debugging/lesson-alembic-graph-and-data
course: production-debugging
section: fastapi-migrations
section_title: "Migrations (Alembic)"
section_position: 7
section_group: "FastAPI"
title: "Debugging Alembic: the revision graph and the data it meets"
position: 1
estimated_minutes: 20
source:
    - docs/debug-labs.md
---

A migration bug is a deployment bug: it shows up at the worst moment, on the machine you cannot experiment on. The skill this section trains is bringing the failure back to your own machine by reproducing the exact starting state the migration ran on.

## Alembic revisions are a graph, not a list

Each revision names its parent in `down_revision`. File names, dates and the order in which people merged branches mean nothing. Two revisions with the same parent are two heads, and `alembic upgrade head` refuses to choose. Learn to read the graph with `alembic heads` and `alembic history`, and to fix a fork with a merge revision (`down_revision` is a tuple of both heads) instead of deleting files that may already have been applied elsewhere.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-alembic-graph-q1",
      "type": "mcq",
      "prompt": "Two Alembic revisions both list the same down_revision after a merge, and upgrade head fails with multiple heads. What is the safe fix?",
      "options": [
        {
          "id": "a",
          "text": "Delete one of the revisions"
        },
        {
          "id": "b",
          "text": "Add a merge revision whose down_revision is the tuple of both heads"
        },
        {
          "id": "c",
          "text": "Rename one file so it sorts later"
        },
        {
          "id": "d",
          "text": "Run upgrade with the --sql flag"
        }
      ],
      "correct": "b",
      "explanation": "The graph is defined by down_revision. A merge revision depending on both heads restores a single head without discarding history that may already be applied elsewhere."
    }
  ]
}
```

## A migration is a function of the schema and the data

A migration can pass on an empty database and on a freshly built staging database, and still fail on production, because production has rows. Adding a NOT NULL column with no default, creating a unique index over duplicates, changing a type over legacy values: all of these only fail when there is data. To debug one, bring a scratch database to the revision before the failing one (`alembic upgrade <revision>`), insert rows shaped like production, then upgrade forward and read the real error.

The usual fix is expand, backfill, constrain: add the column in a form existing rows can satisfy (nullable or with a server default), fill it, then tighten it.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-alembic-notnull-q1",
      "type": "mcq",
      "prompt": "A revision adds a NOT NULL column without a server default. It passes in CI and fails in production. Why?",
      "options": [
        {
          "id": "a",
          "text": "CI uses a different Alembic version"
        },
        {
          "id": "b",
          "text": "CI starts from an empty table, production has rows that need a value for the new column"
        },
        {
          "id": "c",
          "text": "PostgreSQL ignores NOT NULL in CI"
        },
        {
          "id": "d",
          "text": "The model had a default, which Alembic applies automatically"
        }
      ],
      "correct": "b",
      "explanation": "The migration runs against existing rows. Without a default or a backfill there is no value for them, and PostgreSQL aborts the ALTER TABLE."
    }
  ]
}
```
