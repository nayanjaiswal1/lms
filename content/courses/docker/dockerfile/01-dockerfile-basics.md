---
kind: lesson
id_key: docker/dockerfile/basics
course: docker
section: dockerfile
section_title: Writing Dockerfiles
section_position: 4
title: "Your First Dockerfile: FROM, WORKDIR, COPY, RUN, CMD"
position: 0
estimated_minutes: 9
source:
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

## Why this matters

Pulling other people's images only gets you so far. To ship **your** app you
write a Dockerfile: a short text file that says exactly how to build your
image. Five instructions are enough for most real apps.

## Mental model: a recipe executed top to bottom

A **Dockerfile** is a recipe. `docker build` follows it line by line, and every
instruction that changes files produces a new **layer** (Section 3).

```
Dockerfile                     image layers (bottom = first)
----------                     -----------------------------
FROM python:3.12-slim   --->   [ base image layers        ]
WORKDIR /app            --->   [ create /app              ]
COPY requirements.txt . --->   [ requirements.txt         ]
RUN pip install -r ...  --->   [ installed packages       ]
COPY . .                --->   [ your source code         ]
CMD ["python","app.py"] --->   metadata only (no files)
```

The five core instructions:

| Instruction | Plain meaning | Runs when? |
|---|---|---|
| `FROM` | Start from this base image | Build |
| `WORKDIR` | `cd` into this folder (creates it if missing) | Build (and sets start folder) |
| `COPY` | Copy files from your project into the image | Build |
| `RUN` | Run a shell command and save the result as a layer | Build |
| `CMD` | Default command when a container starts | **Run** (container start) |

The single most important distinction: **`RUN` happens at build time, once.
`CMD` happens at container start, every time.**

## See it work

A tiny Python web app. Create a folder with three files:

`app.py`:

```python
from http.server import HTTPServer, SimpleHTTPRequestHandler
print("serving on 8000", flush=True)
HTTPServer(("0.0.0.0", 8000), SimpleHTTPRequestHandler).serve_forever()
```

`requirements.txt` (empty is fine for this example, real apps list packages here).

`Dockerfile`:

```dockerfile
# 1. Base image: Python already installed, small Debian userland
FROM python:3.12-slim

# 2. All following paths are relative to /app
WORKDIR /app

# 3. Copy the dependency list first (lesson 4 explains why)
COPY requirements.txt .

# 4. Install dependencies at build time; --no-cache-dir keeps the layer small
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copy the rest of the source code
COPY . .

# 6. Document the port the app listens on (does not publish it)
EXPOSE 8000

# 7. What runs when a container starts
CMD ["python", "app.py"]
```

Build and run:

```bash
docker build -t pyweb:1.0 .
docker run -d --name pyweb -p 8000:8000 pyweb:1.0
docker logs pyweb            # serving on 8000
curl -s localhost:8000 | head -n 3
```

Build output shows one numbered step per instruction:

```
 => [1/5] FROM docker.io/library/python:3.12-slim
 => [2/5] WORKDIR /app
 => [3/5] COPY requirements.txt .
 => [4/5] RUN pip install --no-cache-dir -r requirements.txt
 => [5/5] COPY . .
 => naming to docker.io/library/pyweb:1.0
```

### The build context and `.dockerignore`

The `.` at the end of `docker build -t pyweb:1.0 .` is the **build context**:
the folder whose files Docker may `COPY`. Everything in it is sent to the
builder. Exclude what the image should not contain with a `.dockerignore` file,
which works like `.gitignore`:

```
.git
node_modules
__pycache__
*.log
.env
```

This makes builds faster and stops secrets (`.env`) and junk from leaking into images.

## Try it

Write a Dockerfile for a static website in `site/` served by nginx. The nginx
image serves files from `/usr/share/nginx/html` and already has a default `CMD`.

<details>
<summary>Show answer</summary>

```dockerfile
FROM nginx:1.27-alpine
COPY site/ /usr/share/nginx/html/
EXPOSE 80
```

No `CMD` needed: it is inherited from the base image. Build with
`docker build -t mysite .` and run with `docker run -d -p 8080:80 mysite`.

</details>

## Common mistakes

- **Using `RUN` to start the app.** `RUN python app.py` runs during the build (and
  hangs it). Use `CMD` for what runs at container start.
- **`RUN cd /app`.** Each `RUN` is a fresh shell; the `cd` is forgotten on the
  next line. Use `WORKDIR`.
- **No `.dockerignore`.** Your `.git` folder, local `node_modules` and `.env` secrets end up in the image.
- **`COPY` paths outside the context.** `COPY ../shared .` fails: only files inside
  the build context are visible.

## Remember

- `FROM` → `WORKDIR` → `COPY` → `RUN` → `CMD` covers most apps.
- `RUN` = build time, once. `CMD` = container start, every time.
- Each file-changing instruction = one layer.
- The build context (the `.`) is all `COPY` can see; trim it with `.dockerignore`.

**Self-check:**

1. Why does `RUN cd /app` not work as expected?
2. What is the build context?
3. Which instruction sets the default command, and when does it run?
