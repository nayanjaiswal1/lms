---
kind: lesson
id_key: interview-prep-45/day-15-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Web Security"
position: 28
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Security questions show up in almost every senior frontend interview, because shipping a comment box or a login form without understanding XSS, CSRF, and CORS is exactly how real breaches happen. This lesson covers the three attacks interviewers ask about most, how React defends against each one, and the "where should the auth token live" question that trips up most candidates who've never had to answer it for real.

## XSS: getting your JavaScript to run in someone else's page

Cross-site scripting is what happens when an attacker's JavaScript ends up running inside your page, inside your user's own logged-in session. There are three flavors: stored (the payload is saved on the server, a comment, a username, and shown to every viewer), reflected (the payload comes straight from the URL and gets echoed back into the page), and DOM-based (client-side code takes untrusted data and writes it into the page with no server round trip at all).

React protects you here by default. JSX escapes everything you render as `{value}`, so it's safe even if `value` is `"<img src=x onerror=alert(1)>"`, because React renders it as plain text, never as markup.

```tsx
function Comment({ text }: { text: string }) {
  return <p>{text}</p>; // safe: React escapes text nodes automatically
}
```

The escape hatch is `dangerouslySetInnerHTML`, and the name is a warning, not decoration. Only ever use it with sanitized HTML.

```tsx
import DOMPurify from "dompurify";
function RichComment({ html }: { html: string }) {
  const clean = DOMPurify.sanitize(html, { ALLOWED_TAGS: ["b", "i", "em", "strong", "a", "p", "br"], ALLOWED_ATTR: ["href"] });
  return <div dangerouslySetInnerHTML={{ __html: clean }} />;
}
```

There are XSS holes React doesn't save you from at all, and knowing them is the real answer to "how does React prevent XSS, and how would you still cause it." An unvalidated `href` is one of them:

```tsx
// UNSAFE: an attacker can set userSuppliedUrl to "javascript:alert(document.cookie)"
<a href={userSuppliedUrl}>Profile</a>

// Fix: only allow safe protocols through
function safeHref(url: string): string {
  try {
    const parsed = new URL(url, window.location.origin);
    return ["http:", "https:"].includes(parsed.protocol) ? parsed.href : "#";
  } catch { return "#"; }
}
```

`window.location.href = userInput`, `eval`, `new Function(userInput)`, and setting an `iframe.src` from user-controlled data round out the usual list of DOM-XSS suspects, and spotting one of these hidden in a code snippet is a common way this gets tested live.

> **Remember:** React escapes `{value}` automatically. It never escapes `dangerouslySetInnerHTML`, that's the entire point of its name.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-security-xss-q1", "type": "mcq",
      "prompt": "Does rendering {userComment} inside JSX protect against XSS, even if userComment contains \"<img src=x onerror=alert(1)>\"?",
      "options": [
        {"id":"a","text":"No, React renders whatever string it's given as raw HTML"},
        {"id":"b","text":"Yes — JSX escapes text rendered this way automatically, so it's always shown as plain text, never parsed as markup"},
        {"id":"c","text":"Only if the string is first run through JSON.stringify"},
        {"id":"d","text":"Only in production builds, not in development"}
      ],
      "correct": "b",
      "explanation": "JSX's {value} interpolation escapes its content by default. The only way to render raw, unescaped HTML is the explicitly named dangerouslySetInnerHTML." }
] }
```

## CSRF: the browser's automatic cookies, turned against you

CSRF tricks a logged-in user's own browser into firing a request they never meant to send. Browsers attach cookies to a request automatically, so a page on another site can quietly submit a form to your bank, and the request looks fully authenticated.

```html
<!-- hosted on evil.com, while the victim is logged into bank.com in another tab -->
<form action="https://bank.com/api/transfer" method="POST">
  <input type="hidden" name="to" value="attacker" />
  <input type="hidden" name="amount" value="10000" />
</form>
<script>document.forms[0].submit()</script>
```

Three defenses, from most to least common in a modern stack. **`SameSite` cookies**: set auth cookies with `SameSite=Lax` or `Strict`. `Lax`, the browser default today, blocks cookies on cross-site POST requests but still allows normal top-level navigation, which stops the auto-submitting form above. **CSRF tokens**: the server embeds a random token in the page (a hidden field or a meta tag), and every request that changes something must send it back in a header. An attacker's cross-origin form can't read that token, thanks to the browser's same-origin rule. **Custom headers**: requiring something like `X-Requested-With` works too, since a plain HTML form can't set a custom header, only same-origin JavaScript can.

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

Does CSRF apply to a token you store in `localStorage` and attach yourself through a `Bearer` header? No. CSRF depends specifically on the browser's *automatic* cookie attachment. A token you attach yourself can't be copied by a forged cross-site form, since that form can't read your `localStorage` or set custom headers. That's not a free win, though, a `localStorage` token trades away CSRF risk for XSS risk instead, covered above.

> **Remember:** CSRF exploits automatic cookies. A token you attach by hand through a header isn't exposed to CSRF, but it is exposed to XSS, since any injected script can read `localStorage`.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-security-csrf-q1", "type": "mcq",
      "prompt": "An app stores its auth token in localStorage and attaches it manually via an Authorization header. Is this token exposed to CSRF attacks?",
      "options": [
        {"id":"a","text":"Yes, exactly like a cookie-based token"},
        {"id":"b","text":"No — CSRF exploits the browser's automatic cookie attachment, and a forged cross-site form can neither read localStorage nor set a custom Authorization header"},
        {"id":"c","text":"Only on mobile browsers"},
        {"id":"d","text":"Only if SameSite is not set"}
      ],
      "correct": "b",
      "explanation": "This exact setup is safe from CSRF specifically because CSRF relies on the browser attaching credentials for you. It's not a free win overall, though, since a localStorage token is now exposed to XSS instead." }
] }
```

## CORS: a rule for the browser, not for the server

CORS is a browser-enforced rule, not a server security feature. It protects a *user* from a malicious frontend reading another site's authenticated responses; it does nothing to protect the server itself, since `curl` ignores CORS entirely.

The browser sends an `Origin` header; the server replies with `Access-Control-Allow-Origin`. Anything beyond a simple GET triggers a preflight `OPTIONS` request first.

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

`Access-Control-Allow-Origin: *` can never be combined with `Access-Control-Allow-Credentials: true`. If cookies need to cross an origin, the server must echo back the exact requesting origin, never a wildcard.

> **Remember:** CORS stops a browser from letting a malicious site read another site's authenticated response. It never stops a direct server-to-server request, since only the browser enforces it.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-security-cors-q1", "type": "mcq",
      "prompt": "Does CORS stop an attacker from sending a direct, forged request to your API using curl?",
      "options": [
        {"id":"a","text":"Yes, CORS blocks all unauthorized requests to an API"},
        {"id":"b","text":"No — CORS is enforced entirely by the browser; curl and any direct server-to-server request never go through a browser at all, so CORS has no effect on them"},
        {"id":"c","text":"Only if the API uses HTTPS"},
        {"id":"d","text":"Yes, but only for POST requests"}
      ],
      "correct": "b",
      "explanation": "CORS protects a logged-in user from a malicious page reading another site's authenticated response inside their browser. It does nothing to stop a direct request that never goes through a browser at all." }
] }
```

## Where the auth token should actually live

| | Session cookie | JWT |
|---|---|---|
| State | Server stores the session, the cookie holds only an opaque ID | Server stores nothing, the token itself carries its claims |
| Revocation | Instant, delete the server-side session | Hard, needs to wait for expiry or a blocklist |
| XSS exposure | Low if `httpOnly`, JavaScript can't read it | High if kept in `localStorage`, JavaScript and any injected script can |
| CSRF exposure | Yes, needs `SameSite`/tokens | No, if sent via an `Authorization` header instead of a cookie |

The pattern that shows up again and again in real apps: a short-lived JWT access token kept in memory, React state, never `localStorage`, paired with a long-lived refresh token in an `httpOnly`, `Secure`, `SameSite=Strict` cookie. This caps how much damage a stolen access token can do, since it expires in minutes, and avoids CSRF, since the refresh cookie isn't readable by JavaScript and the refresh endpoint is protected by `SameSite`.

> **Remember:** short-lived token in memory, long-lived refresh token in an httpOnly cookie. That single pattern answers most "where should the token live" interview questions.

## HTTPS, mixed content, and CSP as a last line of defense

HTTPS isn't just "encrypt the login form." Mixed content, an HTTPS page loading a plain HTTP script, gets blocked by browsers, and it's itself an XSS door: a network attacker can inject into any unencrypted resource on the page, not only the main document.

CSP is a response header that restricts which sources the browser will run or load from at all, turning a successful injection into a no-op, since the injected script violates policy and simply never runs.

```
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'nonce-r4nd0m';
  frame-ancestors 'none';
```

`default-src 'self'` is the baseline: only load from your own origin. `script-src` with a per-request nonce lets you allow specific inline `<script>` tags without opening the door to `unsafe-inline` generally, since an attacker's injected script never has the correct nonce. `frame-ancestors 'none'` blocks your site from being embedded elsewhere, the standard defense against clickjacking.

Given a stored XSS bug you can't patch today, what limits the damage? A strict CSP, no `unsafe-inline`, no `unsafe-eval`, stops the injected script from ever running, even though the payload already made it into the page. That's the whole idea behind defense in depth: sanitize the input, escape the output, and set a CSP, so one missed spot isn't the whole story.

> **Remember:** three questions carry most of the interview weight here: what does React protect against by default, what does the browser enforce versus what the server must enforce itself, and where should a token actually live.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-security-csp-q1", "type": "mcq",
      "prompt": "A site has a known stored XSS bug that can't be patched today. What limits the actual damage in the meantime?",
      "options": [
        {"id":"a","text":"Nothing can help until the bug is fixed"},
        {"id":"b","text":"A strict Content-Security-Policy with no unsafe-inline or unsafe-eval, since it stops the injected script from executing even though the payload already reached the DOM"},
        {"id":"c","text":"Switching from cookies to localStorage for the auth token"},
        {"id":"d","text":"Enabling CORS more strictly"}
      ],
      "correct": "b",
      "explanation": "This is defense in depth: even when one layer (input sanitization) fails, a strict CSP is a separate layer that can still stop the injected script from ever running." }
] }
```
