---
kind: lesson
id_key: linux/talking-to-the-world/curl-and-http
course: linux
section: talking-to-the-world
section_title: "Chapter 8: Talking to the World - Networking"
section_position: 8
title: "Talking HTTP with curl (and jq)"
position: 2
estimated_minutes: 7
source:
  - curl(1), jq(1) manual pages; RFC 9110 (HTTP semantics)
---

## Why this matters

Browsers hide everything that matters for debugging: status codes, headers,
redirects, TLS errors, timings. `curl` shows all of it from a terminal, works
over SSH, and fits in scripts. It is how you prove "the API is up" in one line.

## Mental model: a waiter who reports everything

You give curl a URL; it walks to the server, orders, and reports back exactly
what happened.

```
 curl -v https://orbit.coffee/api/status
   * resolve name (DNS)  -> * connect TCP :443 -> * TLS handshake
   > GET /api/status HTTP/2        (request: method, path, headers)
   < HTTP/2 200                    (response: status code, headers)
   < content-type: application/json
   {"healthy": true}               (body)
```

Status codes in one breath: **2xx** success, **3xx** redirect, **4xx** your
request is wrong (404 not found, 401/403 not allowed), **5xx** the server failed
(500 error, 502 bad gateway, 503 unavailable, 504 timeout).

## See it work

In the lab, start a tiny web server first (it serves `~/work/site`):

```bash
nohup python3 -m http.server 8080 --directory ~/work/site >/dev/null 2>&1 &
curl http://localhost:8080/
```

What this does: Python's built-in server listens on port 8080; `curl` fetches
the page and prints the body:

```
<!doctype html>
<title>Orbit Coffee</title>
<h1>Orbit Coffee - fresh beans, roasted on atlas</h1>
```

### Headers only

```bash
curl -I http://localhost:8080/
```

```
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.12.3
Date: Wed, 14 Oct 2026 10:30:00 GMT
Content-type: text/html
Content-Length: 87
Last-Modified: Wed, 14 Oct 2026 09:00:00 GMT
```

`-I` sends a HEAD request: "is it up, and what is answering?"

### The options you need

```bash
curl -v https://orbit.coffee            # verbose: DNS, TLS, request, response
curl -s URL | jq .                      # -s silent (no progress bar) + pretty JSON
curl -sf URL || echo "DOWN"             # -f: exit non-zero on HTTP errors (scripts!)
curl -L URL                             # follow redirects
curl -o file.tar.gz URL                 # save to a file (or: wget URL)
curl -X POST -H 'Content-Type: application/json' -d '{"qty":2}' URL
curl -m 5 URL                           # give up after 5 seconds
curl -o /dev/null -s -w '%{http_code} %{time_total}\n' URL   # status and timing only
curl --resolve orbit.coffee:443:10.0.0.42 https://orbit.coffee/   # test a server before DNS points to it
```

### JSON with jq

```bash
curl -s http://localhost:8080/status.json | jq -r .version
```

```
2.4.1
```

`jq .` pretty-prints; `.version` picks one field; `-r` prints raw text without
quotes. `jq '.items[] | .name'` walks arrays.

## Try it

Write one command that prints only the HTTP status code of
`http://localhost:8080/missing`, and say which family it belongs to.

<details>
<summary>Show answer</summary>

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/missing
```

It prints `404`: a 4xx, client-side error (the page does not exist).

</details>

## Common mistakes

- **Using curl without `-f` in scripts.** A 500 page still exits 0, so the
  script thinks all is well.
- **Ignoring redirects.** A `301` with an empty body is not "down"; add `-L` or
  read the `Location` header.
- **`-k` (skip TLS checks) in production scripts.** It hides expired or wrong
  certificates. Fix the certificate instead.
- **Forgetting quotes around URLs with `&` or `?`.** The shell treats `&` as
  "run in background".

## Remember

- `curl URL` body, `-I` headers, `-v` everything, `-s` quiet, `-f` fail on
  errors, `-L` follow.
- `-w '%{http_code} %{time_total}'` = status and timing.
- 2xx ok, 3xx redirect, 4xx client error, 5xx server error.
- `jq -r .field` extracts JSON values.

**Self-check:**

1. What does a 502 from nginx tell you?
2. Why use `-f` in health-check scripts?
3. How do you show only the response headers?
