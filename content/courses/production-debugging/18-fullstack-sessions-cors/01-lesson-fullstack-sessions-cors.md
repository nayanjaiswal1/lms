---
kind: lesson
id_key: production-debugging/lesson-fullstack-sessions-cors
course: production-debugging
section: fullstack-sessions-cors
section_title: "Sessions, cookies and CORS"
section_position: 18
section_group: "Fullstack"
title: "Where the browser and the API disagree: sessions, cookies and CORS"
position: 1
estimated_minutes: 15
source:
    - docs/debug-labs.md
---

## Sessions, cookies and CORS

A cookie session crosses three boundaries: CORS decides whether the browser lets a page use credentials, cookie attributes (Path, HttpOnly, SameSite) decide where the cookie travels and who can read it, and the CSRF token has to be read by script and echoed in a header. Break any one and sign-in looks fine while every later request fails. Reproduce with the network tab: check Set-Cookie flags, the request's Cookie header and the response's Access-Control-* headers.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fullstack-sessions-cors-q1",
      "type": "mcq",
      "prompt": "A script must echo the CSRF token in a header. Which cookie flag breaks that?",
      "options": [
        {
          "id": "a",
          "text": "HttpOnly on the CSRF cookie"
        },
        {
          "id": "b",
          "text": "Secure on the CSRF cookie"
        },
        {
          "id": "c",
          "text": "SameSite=Lax on the CSRF cookie"
        },
        {
          "id": "d",
          "text": "Path=/ on the CSRF cookie"
        }
      ],
      "correct": "a",
      "explanation": "HttpOnly hides the cookie from document.cookie, so the client cannot read the token to send it."
    }
  ]
}
```
