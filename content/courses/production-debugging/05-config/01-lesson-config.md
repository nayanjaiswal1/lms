---
kind: lesson
id_key: production-debugging/lesson-config-dev-prod-parity
course: production-debugging
section: django-config
section_title: "Configuration and deployment"
section_position: 5
section_group: "Django"
title: "Debugging configuration: what differs between here and there"
position: 1
estimated_minutes: 15
source:
    - docs/debug-labs.md
---

"Works on my machine" is a configuration bug until proven otherwise. The application code is identical; what differs is the environment around it. The skill this section trains is listing the differences systematically instead of staring at the code.

## Make the failing environment reproducible

Start by running the app the way production runs it: the same settings module, DEBUG off, the same server, the same environment variables. Many bugs appear the moment you do. Then diff the two configurations: settings values, middleware, environment variables, installed packages, files that are generated at build time (collected static files, compiled assets).

```knowledge-check
{ "questions": [
    { "id": "production-debugging-config-repro-q1", "type": "mcq",
      "prompt": "A page looks fine locally but has no styles in production. What is the best first move?",
      "options": [
        {"id":"a","text":"Rewrite the CSS"},
        {"id":"b","text":"Run the app locally with the production settings and DEBUG off and look at what the browser requests and what it gets back"},
        {"id":"c","text":"Turn DEBUG on in production"},
        {"id":"d","text":"Clear the browser cache forever"}
      ],
      "correct": "b",
      "explanation": "Reproduce the failing environment first. Running with production settings usually shows the exact failing request (a 404 for /static/...) and narrows the question to what serves that URL when DEBUG is off." }
] }
```

## Know what serves what

Development conveniences hide dependencies. The development server serves static files by itself only while DEBUG is on; in production something else must: a web server, a CDN, or middleware such as WhiteNoise. The same is true for the database URL (a missing variable should fail loudly, not fall back to a local file), for allowed hosts and CSRF origins behind a proxy, and for cookies over HTTPS. For each feature that "just works" in development, ask who provides it in production.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-config-serves-q1", "type": "mcq",
      "prompt": "With DEBUG = False, who serves /static/ files in a typical Django deployment?",
      "options": [
        {"id":"a","text":"Django serves them automatically"},
        {"id":"b","text":"Something you configured: a front web server or CDN, or middleware such as WhiteNoise, fed by collectstatic"},
        {"id":"c","text":"The database"},
        {"id":"d","text":"Nobody, static files only work in development"}
      ],
      "correct": "b",
      "explanation": "Django's own static handling is a development convenience that only works with DEBUG on. Production needs an explicit serving path for the collected files." }
] }
```

## Fix the configuration, do not switch off the check

The tempting fixes are the ones that hide the difference: turning DEBUG on, adding development-only URL routes, changing a setting on the server by hand. Prefer the fix that makes the environments equivalent in code, keep it in version control, and back it with a test on the settings module so the next change cannot silently remove it.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-config-fix-q1", "type": "mcq",
      "prompt": "Which is the appropriate way to make static files work in production?",
      "options": [
        {"id":"a","text":"Set DEBUG = True in the production settings"},
        {"id":"b","text":"Restore the production static-file serving in the settings (for example the WhiteNoise middleware after SecurityMiddleware) and test the settings module"},
        {"id":"c","text":"Add staticfiles_urlpatterns() to urls.py and leave DEBUG off"},
        {"id":"d","text":"Copy the files by hand on the server"}
      ],
      "correct": "b",
      "explanation": "DEBUG on exposes internals; staticfiles_urlpatterns() returns nothing when DEBUG is off; hand-copying is not reproducible. Configure the serving path in code and pin it with a test." }
] }
```
