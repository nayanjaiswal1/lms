---
kind: lesson
id_key: interview-prep-45/day-26-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Internationalization"
position: 29
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

Internationalization (i18n) questions test whether you understand that "translate the strings" is the easy 10%. The hard parts are pluralization rules, locale-aware formatting, RTL layout, and not shipping every locale's translations to every user. Today covers the standard approaches, react-intl, the `Intl` browser API, and RTL support.

## i18n approaches: the landscape

| Approach | How it works | Trade-off |
|---|---|---|
| Key-based lookup (react-intl/FormatJS, react-i18next) | `t("welcome.message")` maps to a translated string per locale | Requires discipline to keep keys and translations in sync, though tooling can catch missing keys |
| ICU MessageFormat | Rich format strings inside the value handle plurals, gender, and interpolation | More powerful pluralization, with steeper syntax to learn |
| Native `Intl` API | Browser-built-in for numbers, dates, lists, relative time, pluralization rules | No translation string management, only formatting, not fluent phrases |

Most real apps combine the first and third: a translation library for UI copy, and the native `Intl` API for locale-aware formatting of dates, numbers, and currency. `Intl` already knows every locale's formatting rules, so shipping your own would be redundant and error-prone.

## react-intl (FormatJS) setup

```bash
npm install react-intl
```

```tsx
// messages/en.json
{
  "welcome": "Welcome back, {name}!",
  "cart.itemCount": "{count, plural, =0 {No items} one {# item} other {# items}} in your cart"
}
```

```tsx
// messages/fr.json
{
  "welcome": "Content de vous revoir, {name} !",
  "cart.itemCount": "{count, plural, =0 {Aucun article} one {# article} other {# articles}} dans votre panier"
}
```

```tsx
// App.tsx
import { IntlProvider } from "react-intl";
import en from "./messages/en.json";
import fr from "./messages/fr.json";

const messages = { en, fr };

function App({ locale }: { locale: "en" | "fr" }) {
  return (
    <IntlProvider locale={locale} messages={messages[locale]} defaultLocale="en">
      <Dashboard />
    </IntlProvider>
  );
}
```

```tsx
// Dashboard.tsx
import { FormattedMessage, useIntl } from "react-intl";

function Dashboard() {
  const intl = useIntl();
  const cartCount = 3;

  return (
    <div>
      <h1>
        <FormattedMessage id="welcome" values={{ name: "Jane" }} />
      </h1>
      <p>{intl.formatMessage({ id: "cart.itemCount" }, { count: cartCount })}</p>
    </div>
  );
}
```

The `{count, plural, =0 {...} one {...} other {...}}` syntax is **ICU MessageFormat**, the key reason to reach for react-intl instead of a simpler key-value library. Pluralization is not "singular vs. plural" in most languages; some languages have distinct forms for one, two, few, many, and other. ICU's plural categories (`zero`, `one`, `two`, `few`, `many`, `other`) map onto whichever subset a given locale actually uses, applying the correct grammatical rule for that language automatically via `Intl.PluralRules` under the hood.

## Translation loading

Shipping every locale's translation bundle to every user is wasted bytes: a user viewing the English site doesn't need the French, German, and Japanese bundles downloaded too. Load translations lazily, per locale, the same way you'd code-split a route.

```tsx
import { lazy, Suspense, useState, useEffect } from "react";

async function loadMessages(locale: string) {
  const messages = await import(`./messages/${locale}.json`);
  return messages.default;
}

function App() {
  const [locale, setLocale] = useState(detectLocale());
  const [messages, setMessages] = useState<Record<string, string> | null>(null);

  useEffect(() => {
    loadMessages(locale).then(setMessages);
  }, [locale]);

  if (!messages) return <Spinner />;

  return (
    <IntlProvider locale={locale} messages={messages}>
      <Dashboard />
    </IntlProvider>
  );
}

function detectLocale(): string {
  // navigator.language reflects the browser/OS locale setting
  const supported = ["en", "fr", "de", "ja"];
  const browserLocale = navigator.language.split("-")[0];
  return supported.includes(browserLocale) ? browserLocale : "en";
}
```

In a framework like Next.js, this is handled by the routing layer itself (`[locale]` dynamic segments, `next-intl`), which resolves the locale from the URL path or `Accept-Language` header on the server and only serves that locale's bundle, avoiding a client-side fetch waterfall entirely for the initial page load.

## Date/number formatting with `Intl`

The native `Intl` API is the correct tool for formatting. Never hand-roll date or currency formatting, because locale rules (decimal separators, thousands separators, date field order, currency symbol placement) vary in ways that are easy to get wrong and expensive to maintain yourself.

```ts
// Numbers — note the different separators
new Intl.NumberFormat("en-US").format(1234567.89); // "1,234,567.89"
new Intl.NumberFormat("de-DE").format(1234567.89); // "1.234.567,89"
new Intl.NumberFormat("fr-FR").format(1234567.89); // "1 234 567,89"

// Currency — symbol placement and spacing differ per locale
new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(49.99);
// "$49.99"
new Intl.NumberFormat("de-DE", { style: "currency", currency: "EUR" }).format(49.99);
// "49,99 €"

// Dates — field order and separators differ per locale
const date = new Date("2026-07-16");
new Intl.DateTimeFormat("en-US").format(date); // "7/16/2026"
new Intl.DateTimeFormat("en-GB").format(date); // "16/07/2026"
new Intl.DateTimeFormat("ja-JP", { dateStyle: "long" }).format(date); // "2026年7月16日"

// Relative time — "3 days ago", "in 2 hours", correctly pluralized per locale
const rtf = new Intl.RelativeTimeFormat("en", { numeric: "auto" });
rtf.format(-3, "day"); // "3 days ago"
rtf.format(2, "hour"); // "in 2 hours"

// Lists — correct conjunction per locale ("A, B, and C" vs "A, B et C")
new Intl.ListFormat("en", { type: "conjunction" }).format(["Alice", "Bob", "Carol"]);
// "Alice, Bob, and Carol"
```

React components typically wrap these to avoid recreating formatter instances (which have real construction cost) on every render:

```tsx
function useCurrencyFormatter(locale: string, currency: string) {
  return useMemo(
    () => new Intl.NumberFormat(locale, { style: "currency", currency }),
    [locale, currency]
  );
}

function Price({ amount }: { amount: number }) {
  const formatter = useCurrencyFormatter("en-US", "USD");
  return <span>{formatter.format(amount)}</span>;
}
```

react-intl's `FormattedDate`, `FormattedNumber`, and `FormattedRelativeTime` components are thin wrappers around exactly these `Intl` constructors, plus this memoization, plus reading the active locale from context automatically.

## RTL support

Roughly a dozen widely-used languages (Arabic, Hebrew, Persian, Urdu) are right-to-left, and getting RTL right involves more than mirroring text: the whole layout direction flips.

```html
<html dir="rtl" lang="ar">
```

Setting `dir="rtl"` on `<html>` (or any container) flips text alignment, flexbox/grid item order (without changing your JSX), the direction `margin`/`padding`/`border` shorthand apply visually, and native form control alignment. All of this happens automatically, because these are direction-aware by the CSS spec, not something you write JS to flip.

**The CSS mistake to avoid:** physical properties (`margin-left`, `padding-right`, `text-align: left`) don't flip with `dir="rtl"`. They stay pinned to the physical left/right regardless of reading direction, which breaks the layout in RTL locales. **Logical properties** flip automatically because they're defined relative to text flow direction, not physical screen sides:

```css
/* Bad: pinned to physical left, breaks visually in RTL */
.card {
  margin-left: 16px;
  padding-right: 8px;
  text-align: left;
}

/* Good: logical properties, correct in both LTR and RTL automatically */
.card {
  margin-inline-start: 16px;
  padding-inline-end: 8px;
  text-align: start;
}
```

| Physical (avoid) | Logical (prefer) |
|---|---|
| `margin-left` / `margin-right` | `margin-inline-start` / `margin-inline-end` |
| `padding-left` / `padding-right` | `padding-inline-start` / `padding-inline-end` |
| `left` / `right` (positioning) | `inset-inline-start` / `inset-inline-end` |
| `text-align: left/right` | `text-align: start/end` |
| `border-left` / `border-right` | `border-inline-start` / `border-inline-end` |

Icons that convey direction (a "back" arrow, a "next" chevron) also need to mirror in RTL. This is not automatic and needs explicit handling, typically a CSS rule scoped to `[dir="rtl"]`:

```css
[dir="rtl"] .back-arrow-icon {
  transform: scaleX(-1);
}
```

## Locale-specific formatting beyond dates and numbers

A few details interviewers use to check depth beyond the obvious date/currency examples. Pluralization is not binary in many languages: Russian and Polish have multiple plural forms depending on the exact count, and `Intl.PluralRules`/ICU MessageFormat handle this correctly where a manual `count === 1 ? "item" : "items"` check does not generalize. Name order and formality vary too: some locales expect family name before given name, or require formal and informal address forms that don't exist in English at all. Text expansion is a layout concern worth naming explicitly: German and Finnish UI strings routinely run 30-40% longer than the English original, and layouts hardcoded to English string lengths break visibly when translated, so fixed-width buttons and labels should be designed to tolerate that, not to fit English exactly.

## Where this actually breaks in production

The failures that show up in real apps rarely come from missing a translation key. They come from formatting logic that was hardcoded for one locale and never revisited: a price built with string concatenation instead of `Intl.NumberFormat`, a plural check that only handles English, or a fixed-width button that clips German text. Treating `Intl` and ICU pluralization as the default from day one, rather than a retrofit once a second locale ships, is what separates code that scales to new markets from code that needs a rewrite to get there.
