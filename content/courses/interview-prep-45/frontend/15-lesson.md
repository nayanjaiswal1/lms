---
kind: lesson
id_key: interview-prep-45/day-15-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Web Security"
position: 18
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Security questions show up in almost every senior frontend interview because shipping a login form or a comment box without understanding XSS, CSRF, and CORS is how real breaches happen. Today covers the three attacks interviewers ask about most, how to defend against them in React, and the auth-storage question ("localStorage or cookies?") that trips up most candidates.

## XSS (Cross-Site Scripting)

XSS happens when an attacker gets their JavaScript to run in your page, in your user's session. Three flavors:

- **Stored XSS**: the attacker's payload is saved server-side (a comment, a username) and served to every viewer.
- **Reflected XSS**: the payload comes from the URL or query string and is echoed back into the page immediately.
- **DOM-based XSS**: client-side JS takes untrusted data and writes it into the DOM without a server round-trip.

React protects you by default: JSX escapes everything you render as `{value}`. This is safe even if `value` is `"<img src=x onerror=alert(1)>"`, because React renders it as text, not markup.

```tsx
function Comment({ text }: { text: string }) {
  // Safe: React escapes text nodes automatically.
  return <p>{text}</p>;
}
```

The escape hatch is `dangerouslySetInnerHTML`. The name is a warning label, not decoration. Only use it with sanitized HTML.

```tsx
import DOMPurify from "dompurify";

function RichComment({ html }: { html: string }) {
  const clean = DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ["b", "i", "em", "strong", "a", "p", "br"],
    ALLOWED_ATTR: ["href"],
  });
  return <div dangerouslySetInnerHTML={{ __html: clean }} />;
}
```

Other common XSS holes that React doesn't save you from:

```tsx
// UNSAFE: attacker-controlled href can be "javascript:alert(document.cookie)"
<a href={userSuppliedUrl}>Profile</a>

// Fix: allow-list the protocol before rendering
function safeHref(url: string): string {
  try {
    const parsed = new URL(url, window.location.origin);
    return ["http:", "https:"].includes(parsed.protocol) ? parsed.href : "#";
  } catch {
    return "#";
  }
}
```

`window.location.href = userInput`, `eval`, `new Function(userInput)`, and setting `iframe.src` from user data are the other usual DOM-XSS suspects. Interviewers like asking you to spot these in a code review snippet.

**Interview question: "How does React prevent XSS, and how would you still introduce it?"**
Answer: JSX text interpolation escapes values before writing them to the DOM, so `{}` bindings are safe. You reintroduce XSS via `dangerouslySetInnerHTML` with unsanitized input, via attribute injection (`javascript:` URLs, unvalidated `href`/`src`), or by writing directly to the DOM with `ref.current.innerHTML = ...` outside React's render path.

## CSRF (Cross-Site Request Forgery)

CSRF tricks a logged-in user's browser into firing a request they didn't intend. The browser automatically attaches cookies, so a malicious page can submit a form to `your-bank.com/transfer` and the request looks authenticated.

```html
<!-- hosted on evil.com, victim is logged into bank.com in another tab -->
<form action="https://bank.com/api/transfer" method="POST">
  <input type="hidden" name="to" value="attacker" />
  <input type="hidden" name="amount" value="10000" />
</form>
<script>document.forms[0].submit()</script>
```

Three defenses, from most to least common in modern stacks:

1. **`SameSite` cookies.** Set auth cookies with `SameSite=Lax` or `SameSite=Strict`. `Lax` (the browser default today) blocks cookies on cross-site POST requests but still allows top-level navigation, which stops the classic auto-submit form attack.
2. **CSRF tokens.** The server issues a random token embedded in the page (a hidden field or a meta tag); every mutating request must echo it back in a header. An attacker's cross-origin form can't read that token, because of the same-origin policy.
3. **Custom headers.** Requiring a header like `X-Requested-With` on mutating requests works as a CSRF defense too, because plain HTML forms can't set custom headers. Only same-origin `fetch`/XHR can.

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

**Interview question: "Does CSRF apply to a token stored in localStorage and sent as a Bearer header?"**
No. CSRF exploits the browser's automatic credential attachment (cookies). If your auth token lives in JS memory or localStorage and you attach it manually via an `Authorization` header, a forged cross-site form can't replicate that, because it can't read your localStorage or set custom headers. LocalStorage tokens are then exposed to XSS instead, so this is a trade-off, not a free win.

## CORS (Cross-Origin Resource Sharing)

CORS is a browser enforcement mechanism, not a server security feature. It protects users from a malicious frontend reading responses from an API they're authenticated against; it does not protect servers from malicious clients (curl ignores CORS entirely).

The browser sends an `Origin` header; the server responds with `Access-Control-Allow-Origin`. For anything beyond a simple GET, the browser sends a preflight `OPTIONS` request first.

```
OPTIONS /api/users HTTP/1.1
Origin: https://app.example.com
Access-Control-Request-Method: POST
Access-Control-Request-Headers: content-type, authorization

HTTP/1.1 204 No Content
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE
Access-Control-Allow-Headers: content-type, authorization
Access-Control-Allow-Credentials: true
```

Handling it correctly on the client side is mostly about knowing when `credentials` matters:

```tsx
fetch("https://api.example.com/me", {
  credentials: "include", // send cookies cross-origin; server must echo the exact origin,
});                       // Access-Control-Allow-Origin: * is rejected when credentials are included
```

Common gotcha: `Access-Control-Allow-Origin: *` cannot be combined with `Access-Control-Allow-Credentials: true`. If you need cookies cross-origin, the server must reflect the specific requesting origin.

**Interview question: "Is CORS a security feature that stops attackers?"**
It protects users, not servers. It stops a malicious website from reading another site's authenticated API responses in the victim's browser. It does nothing to stop direct server-to-server or curl requests, since those never enforce CORS. CORS is implemented by browsers, not by the HTTP protocol itself.

## JWT vs Sessions

| | Session cookie | JWT |
|---|---|---|
| State | Server stores session in memory/DB, cookie holds only an opaque ID | Server stores nothing; the token itself carries claims |
| Revocation | Instant: delete the server-side session | Hard: must wait for expiry or maintain a blocklist |
| Scaling | Needs a shared session store (Redis) across servers | Stateless, any server can verify with the secret/public key |
| Size | Tiny cookie | Larger (header + payload + signature), sent on every request |
| XSS exposure | Low if `httpOnly`: JS can't read it | High if stored in localStorage: JS (and any injected script) can read it |
| CSRF exposure | Yes, needs `SameSite`/tokens | No, if sent via `Authorization` header instead of a cookie |

The safest common pattern for SPAs: a short-lived JWT access token kept in memory (React state, not localStorage), paired with a long-lived refresh token in an `httpOnly`, `Secure`, `SameSite=Strict` cookie. This limits XSS blast radius, since a stolen access token expires in minutes, and avoids CSRF, since the refresh cookie isn't readable by JS and the endpoint is protected by `SameSite`.

## HTTPS everywhere and Content Security Policy

HTTPS isn't just "encrypt the login form." Mixed content (an HTTPS page loading an HTTP script) is blocked by browsers and is itself an XSS vector, since a network attacker can inject into any unencrypted resource on the page, not just the page's main document.

CSP is an HTTP response header that tells the browser which sources are allowed to execute or load, turning a successful injection into a no-op because the injected script violates the policy and never runs.

```
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'nonce-r4nd0m';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https:;
  connect-src 'self' https://api.example.com;
  frame-ancestors 'none';
```

- `default-src 'self'` is the baseline: only load resources from your own origin.
- `script-src` with a per-request nonce lets you allow specific inline `<script>` tags without opening the door to `unsafe-inline` generally. An attacker's injected `<script>` won't have the correct nonce.
- `frame-ancestors 'none'` blocks your site from being embedded in an `<iframe>` elsewhere, the standard clickjacking defense.

**Interview question: "You have a stored XSS bug you can't patch today. What limits the damage?"**
A strict CSP (no `unsafe-inline`, no `unsafe-eval`) stops the injected script from executing even though the payload made it into the DOM. It's defense in depth: sanitize input, escape output, and set CSP, so a single missed sanitization point isn't a full compromise.

Three questions carry most of the interview weight on this topic: what does React protect you from by default, what does the browser enforce versus what the server must enforce, and where should a token actually live. Get those three solid and the specific defenses (SameSite, CSP, DOMPurify) fall out as supporting detail rather than things to memorize separately.
