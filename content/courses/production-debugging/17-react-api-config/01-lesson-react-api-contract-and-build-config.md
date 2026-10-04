---
kind: lesson
id_key: production-debugging/lesson-react-api-contract-and-build-config
course: production-debugging
section: react-api-config
section_title: "API and configuration"
section_position: 17
section_group: "React"
title: "Debugging the edges: API results, dates and build-time config"
position: 1
estimated_minutes: 15
source:
    - docs/debug-labs.md
---

## The client decides what failure means

A fetch promise only rejects on network errors, so the API client must turn error statuses into errors. Check the status handling for every range, and read dates without a time zone as local calendar days. Build-time configuration is baked in: a bundler only exposes variables with its public prefix, so a missing prefix silently falls back to a default.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-re-api-q1",
      "type": "mcq",
      "prompt": "A Vite app reads import.meta.env.API_URL and always calls relative URLs in staging. Why?",
      "options": [
        {
          "id": "a",
          "text": "The staging server blocks CORS"
        },
        {
          "id": "b",
          "text": "Vite only exposes variables prefixed VITE_ to client code"
        },
        {
          "id": "c",
          "text": "The URL needs a trailing slash"
        },
        {
          "id": "d",
          "text": "Env files load only in production"
        }
      ],
      "correct": "b",
      "explanation": "Unprefixed variables are not exposed, so the value is undefined and the fallback is used."
    }
  ]
}
```
