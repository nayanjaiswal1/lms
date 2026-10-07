---
kind: lesson
id_key: production-debugging/lesson-proxies-and-ownership
course: production-debugging
section: fastapi-config-security
section_title: "Configuration and security"
section_position: 12
section_group: "FastAPI"
title: "Debugging deployment settings and authorization"
position: 1
estimated_minutes: 20
source:
    - docs/debug-labs.md
---

Two kinds of bugs only exist outside your laptop: the ones created by the environment around the app, and the ones created by people who are not you. The skill this section trains is checking what the app assumes about both.

## The proxy is part of the environment

Behind a gateway the service is often mounted under a path prefix that the proxy strips before forwarding. The app learns the prefix as `root_path` (uvicorn's `--root-path`) and needs it only for URLs it hands back to the browser, such as the OpenAPI document that the docs page fetches. Built-in FastAPI routes handle that; a hand-written URL like `/openapi.json` does not. Test it the way the proxy sees it: `TestClient(app, root_path="/api")`, with more than one prefix so a hard-coded value cannot pass.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-cfg-root-q1",
      "type": "mcq",
      "prompt": "The docs page works locally and is blank behind the gateway that mounts the service under /api. The page requests /openapi.json. Why does the browser get a 404?",
      "options": [
        {
          "id": "a",
          "text": "The schema is not generated in production"
        },
        {
          "id": "b",
          "text": "The schema URL ignores the gateway's path prefix (root_path), so it points at the gateway root"
        },
        {
          "id": "c",
          "text": "CORS is blocking it"
        },
        {
          "id": "d",
          "text": "Swagger UI does not support proxies"
        }
      ],
      "correct": "b",
      "explanation": "The proxy strips /api before forwarding but the browser still has to request /api/openapi.json. The prefix must come from root_path instead of being hard-coded."
    }
  ]
}
```

## Authentication is not authorization

A valid token says who is calling, not what they may touch. An endpoint that takes an id from the URL must scope the query to the caller (`WHERE id = :id AND customer_id = :me`) so that somebody else's id is indistinguishable from a missing one. Sequential ids make the missing check trivially exploitable (an insecure direct object reference), but random ids only make it harder to guess, not safe. Test with two users: the owner gets the object, the stranger gets a 404.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-sec-idor-q1",
      "type": "mcq",
      "prompt": "GET /orders/{id} returns any order to any signed-in customer. What is the correct fix?",
      "options": [
        {
          "id": "a",
          "text": "Use random UUIDs instead of sequential ids"
        },
        {
          "id": "b",
          "text": "Scope the query to the signed-in customer so other people's ids return 404"
        },
        {
          "id": "c",
          "text": "Rate-limit the endpoint"
        },
        {
          "id": "d",
          "text": "Hide the endpoint from the docs page"
        }
      ],
      "correct": "b",
      "explanation": "The vulnerability is the missing ownership check. Scoping the query fixes the root cause, whatever the id format."
    }
  ]
}
```
