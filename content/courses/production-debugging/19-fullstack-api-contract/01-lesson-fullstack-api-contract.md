---
kind: lesson
id_key: production-debugging/lesson-fullstack-api-contract
course: production-debugging
section: fullstack-api-contract
section_title: "The API contract"
section_position: 19
section_group: "Fullstack"
title: "Contracts across the wire: error bodies, query strings and paging"
position: 1
estimated_minutes: 15
source:
    - docs/debug-labs.md
---

## The API contract

Frontend and backend only agree through the wire format. Error bodies must have the shape the client reads, query strings must be encoded, and page numbers must mean the same thing on both sides (1-based vs 0-based). Test the contract end to end: send the real request and read the real response before blaming either side.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fullstack-api-contract-q1",
      "type": "mcq",
      "prompt": "A search for \"R&D Kit\" returns every product containing R. What is the most likely cause?",
      "options": [
        {
          "id": "a",
          "text": "The query was not URL-encoded so & started a new parameter"
        },
        {
          "id": "b",
          "text": "The API lowercases the query"
        },
        {
          "id": "c",
          "text": "The database collation is wrong"
        },
        {
          "id": "d",
          "text": "The browser caches the response"
        }
      ],
      "correct": "a",
      "explanation": "An unencoded & ends the q parameter, so the server sees q=R."
    }
  ]
}
```
