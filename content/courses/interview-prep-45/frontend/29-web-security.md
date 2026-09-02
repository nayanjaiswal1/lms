---
kind: lesson
id_key: interview-prep-45/day-15-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Web Security"
position: 29
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Security questions show up in almost every senior frontend interview because shipping a login form or a comment box without understanding XSS, CSRF, and CORS is exactly how real breaches happen. This lesson covers the three attacks interviewers ask about most, how to defend against each in React, and the auth-storage question, "localStorage or cookies?", that trips up most candidates who haven't actually had to answer it for real.

## XSS: getting an attacker's JS to run in your page

Cross-site scripting happens when an attacker's JavaScript ends up executing in your page, inside your user's own session. There are three flavors: stored (the payload is saved server-side, a comment, a username, and served to every viewer), reflected (the payload comes from the URL or query string and gets echoed straight back into the page), and DOM-based (client-side JS takes untrusted data and writes it into the DOM with no server round-trip involved at all).

React protects you by default here. JSX escapes everything rendered as `{value}`, which is safe even if `value` is `"<img src=x onerror=alert(1)>"`, because React renders it as text, never as markup.

```tsx
function Comment({ text }: { text: string }) {
  return <p>{text}</p>; // safe: React escapes text nodes automatically
}
```

The escape hatch is `dangerouslySetInnerHTML`, and the name is a warning label, not decoration. Use it only with sanitized HTML:

```tsx
import DOMPurify from "dompurify";
function RichComment({ html }: { html: string }) {
  const clean = DOMPurify.sanitize(html, { ALLOWED_TAGS: ["b", "i", "em", "strong", "a", "p", "br"], ALLOWED_ATTR: ["href"] });
  return <div dangerouslySetInnerHTML={{ __html: clean }} />;
}
```

There are XSS holes React doesn't save you from at all, and knowing them is exactly what "how does React prevent XSS, and how would you still introduce it" is asking about. Attribute injection through an unvalidated `href` (`javascript:alert(document.cookie)`) is one:

```tsx
// UNSAFE: attacker-controlled href can be "javascript:alert(document.cookie)"
<a href={userSuppliedUrl}>Profile</a>

// Fix: allow-list the protocol before rendering
function safeHref(url: string): string {
  try {
    const parsed = new URL(url, window.location.origin);
    return ["http:", "https:"].includes(parsed.protocol) ? parsed.href : "#";
  } catch { return "#"; }
}
```

`window.location.href = userInput`, `eval`, `new Function(userInput)`, and setting `iframe.src` from user-controlled data round out the usual DOM-XSS suspects, and spotting these in a code-review snippet is a common way this gets tested live.

## CSRF: the browser's automatic cookie attachment used against you

CSRF tricks a logged-in user's browser into firing a request they never intended. The browser attaches cookies automatically, so a malicious page can submit a form to `your-bank.com/transfer` and the request looks fully authenticated.

```html
<!-- hosted on evil.com, victim is logged into bank.com in another tab -->
<form action="https://bank.com/api/transfer" method="POST">
  <input type="hidden" name="to" value="attacker" />
  <input type="hidden" name="amount" value="10000" />
</form>
<script>document.forms[0].submit()</script>
```

Three defenses, most to least common in a modern stack. **`SameSite` cookies**: set auth cookies with `SameSite=Lax` or `Strict`. `Lax`, the browser default today, blocks cookies on cross-site POST requests but still allows top-level navigation, which stops the classic auto-submit form attack above. **CSRF tokens**: the server embeds a random token in the page, a hidden field or meta tag, and every mutating request must echo it back in a header, an attacker's cross-origin form can't read that token, thanks to the same-origin policy. **Custom headers**: requiring something like `X-Requested-With` on mutating requests works too, because a plain HTML form can't set a custom header, only same-origin `fetch`/XHR can.

```tsx
async function transferFunds(amount: number) {
  const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content");
  return fetch("/api/transfer", {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-CSRF-Token": token ?? "" },
    credentials: "same-origin",
    body: JSON.stringify({ amount }),
  });
}
```

Does CSRF apply to a token stored in `localStorage` and sent manually via a `Bearer` header? No. CSRF exploits the browser's *automatic* credential attachment, cookies. A token you attach yourself through an `Authorization` header can't be replicated by a forged cross-site form, since that form can't read your `localStorage` or set custom headers. That's not a free win, though, a `localStorage` token trades CSRF exposure for XSS exposure instead, covered next.

## CORS: a browser rule protecting the user, not the server

CORS is a browser enforcement mechanism, not a server security feature. It protects a user from a malicious frontend reading another site's authenticated API responses; it does nothing to protect the server itself from a malicious client, `curl` ignores CORS entirely.

The browser sends an `Origin` header; the server responds with `Access-Control-Allow-Origin`. Anything beyond a simple GET triggers a preflight `OPTIONS` request first.

```
OPTIONS /api/users HTTP/1.1
Origin: https://app.example.com
Access-Control-Request-Method: POST

HTTP/1.1 204 No Content
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE
Access-Control-Allow-Credentials: true
```

```tsx
fetch("https://api.example.com/me", { credentials: "include" }); // sends cookies cross-origin
```

`Access-Control-Allow-Origin: *` cannot be combined with `Access-Control-Allow-Credentials: true`, if cookies need to cross an origin, the server must reflect the specific requesting origin back, not a wildcard. Is CORS a security feature that stops attackers? It protects users, not servers: it stops a malicious site from reading another site's authenticated responses in the victim's browser, but it does nothing to stop a direct server-to-server or `curl` request, since neither ever enforces CORS, that enforcement lives entirely in the browser.

## Where the auth token should actually live

| | Session cookie | JWT |
|---|---|---|
| State | Server stores the session, cookie holds only an opaque ID | Server stores nothing, the token carries its own claims |
| Revocation | Instant, delete the server-side session | Hard, needs to wait for expiry or a blocklist |
| XSS exposure | Low if `httpOnly`, JS can't read it | High if in `localStorage`, JS and any injected script can |
| CSRF exposure | Yes, needs `SameSite`/tokens | No, if sent via an `Authorization` header instead of a cookie |

The pattern that shows up repeatedly in real SPAs: a short-lived JWT access token kept in memory, React state, never `localStorage`, paired with a long-lived refresh token in an `httpOnly`, `Secure`, `SameSite=Strict` cookie. This caps the XSS blast radius, since a stolen access token expires in minutes, and avoids CSRF, since the refresh cookie isn't readable by JS and the refresh endpoint is protected by `SameSite`.

## HTTPS, mixed content, and CSP as a last line of defense

HTTPS isn't just "encrypt the login form." Mixed content, an HTTPS page loading an HTTP script, is blocked by browsers and is itself an XSS vector: a network attacker can inject into any unencrypted resource on the page, not only the main document.

CSP is a response header restricting which sources the browser will execute or load from at all, turning a successful injection into a no-op, since the injected script violates policy and simply never runs.

```
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'nonce-r4nd0m';
  frame-ancestors 'none';
```

`default-src 'self'` is the baseline, only load from your own origin. `script-src` with a per-request nonce lets you allow specific inline `<script>` tags without opening the door to `unsafe-inline` generally, an attacker's injected `<script>` never has the correct nonce. `frame-ancestors 'none'` blocks your site from being embedded elsewhere, the standard clickjacking defense.

Given a stored XSS bug you can't patch today, what limits the damage? A strict CSP, no `unsafe-inline`, no `unsafe-eval`, stops the injected script from executing even though the payload already made it into the DOM. That's the whole idea behind defense in depth: sanitize input, escape output, and set CSP, so one missed sanitization point isn't a full compromise on its own.

Three questions carry most of the actual interview weight here: what does React protect you from by default, what does the browser enforce versus what the server has to enforce itself, and where should a token actually live. Get those three genuinely solid and the specific defenses, `SameSite`, CSP, DOMPurify, fall out as supporting detail rather than a list to memorize separately.
