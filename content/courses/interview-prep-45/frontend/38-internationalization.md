---
kind: lesson
id_key: interview-prep-45/day-26-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Internationalization"
position: 38
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Internationalization questions test whether you understand that "translate the strings" is the easy 10%. The hard parts are pluralization rules, locale-aware formatting, RTL layout, and not shipping every locale's translations to every user. This lesson covers the standard approaches, react-intl, the native `Intl` API, and RTL support.

## The landscape

| Approach | How it works | Trade-off |
|---|---|---|
| Key-based lookup (react-intl, react-i18next) | `t("welcome.message")` maps to a translated string per locale | Needs discipline to keep keys and translations in sync, though tooling can catch missing keys |
| ICU MessageFormat | Rich format strings inside the value handle plurals, gender, interpolation | More powerful pluralization, steeper syntax |
| Native `Intl` API | Browser-built-in for numbers, dates, lists, relative time, plural rules | Only formatting, no fluent phrases, no string management |

Most real apps combine the first and third: a translation library for UI copy, and `Intl` for locale-aware formatting of dates, numbers, and currency, since `Intl` already knows every locale's formatting rules, shipping your own would be redundant and error-prone.

## react-intl (FormatJS)

```json
// messages/en.json
{ "welcome": "Welcome back, {name}!", "cart.itemCount": "{count, plural, =0 {No items} one {# item} other {# items}} in your cart" }
```

```json
// messages/fr.json
{ "welcome": "Content de vous revoir, {name} !", "cart.itemCount": "{count, plural, =0 {Aucun article} one {# article} other {# articles}} dans votre panier" }
```

```tsx
function App({ locale }: { locale: "en" | "fr" }) {
  return <IntlProvider locale={locale} messages={messages[locale]} defaultLocale="en"><Dashboard /></IntlProvider>;
}
function Dashboard() {
  const intl = useIntl();
  return (
    <div>
      <h1><FormattedMessage id="welcome" values={{ name: "Jane" }} /></h1>
      <p>{intl.formatMessage({ id: "cart.itemCount" }, { count: 3 })}</p>
    </div>
  );
}
```

The `{count, plural, =0 {...} one {...} other {...}}` syntax is **ICU MessageFormat**, and it's the actual reason to reach for react-intl over a simpler key-value library. Pluralization isn't "singular versus plural" in most languages, some have distinct forms for one, two, few, many, and other. ICU's plural categories map onto whichever subset a given locale actually uses, applying the correct grammatical rule automatically via `Intl.PluralRules` under the hood.

## Loading translations lazily, per locale

Shipping every locale's bundle to every user wastes bytes, an English visitor doesn't need the French, German, and Japanese bundles downloaded alongside it. Load translations the same way you'd code-split a route:

```tsx
async function loadMessages(locale: string) {
  return (await import(`./messages/${locale}.json`)).default;
}

function App() {
  const [locale, setLocale] = useState(detectLocale());
  const [messages, setMessages] = useState<Record<string, string> | null>(null);
  useEffect(() => { loadMessages(locale).then(setMessages); }, [locale]);
  if (!messages) return <Spinner />;
  return <IntlProvider locale={locale} messages={messages}><Dashboard /></IntlProvider>;
}

function detectLocale(): string {
  const supported = ["en", "fr", "de", "ja"];
  const browserLocale = navigator.language.split("-")[0];
  return supported.includes(browserLocale) ? browserLocale : "en";
}
```

In a framework like Next.js, the routing layer itself, `[locale]` dynamic segments, `next-intl`, resolves the locale from the URL path or `Accept-Language` header server-side and serves only that locale's bundle, avoiding a client-side fetch waterfall entirely on the initial load.

## Formatting with Intl, never by hand

The native `Intl` API is the correct tool for formatting. Never hand-roll date or currency formatting, locale rules, decimal separators, thousands separators, date field order, currency symbol placement, vary in ways that are easy to get wrong and expensive to maintain yourself.

```ts
new Intl.NumberFormat("en-US").format(1234567.89); // "1,234,567.89"
new Intl.NumberFormat("de-DE").format(1234567.89); // "1.234.567,89"

new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(49.99); // "$49.99"
new Intl.NumberFormat("de-DE", { style: "currency", currency: "EUR" }).format(49.99); // "49,99 €"

new Intl.DateTimeFormat("en-US").format(new Date("2026-07-16")); // "7/16/2026"
new Intl.DateTimeFormat("en-GB").format(new Date("2026-07-16")); // "16/07/2026"

const rtf = new Intl.RelativeTimeFormat("en", { numeric: "auto" });
rtf.format(-3, "day"); // "3 days ago"

new Intl.ListFormat("en", { type: "conjunction" }).format(["Alice", "Bob", "Carol"]); // "Alice, Bob, and Carol"
```

React components typically wrap these to avoid recreating a formatter instance, which has real construction cost, on every render:

```tsx
function useCurrencyFormatter(locale: string, currency: string) {
  return useMemo(() => new Intl.NumberFormat(locale, { style: "currency", currency }), [locale, currency]);
}
```

react-intl's `FormattedDate`, `FormattedNumber`, and `FormattedRelativeTime` components are thin wrappers around exactly these `Intl` constructors, plus this same memoization, plus reading the active locale from context automatically.

## RTL: the layout flips, not just the text

Roughly a dozen widely-used languages, Arabic, Hebrew, Persian, Urdu, are right-to-left, and getting it right involves more than mirroring text, the entire layout direction flips.

```html
<html dir="rtl" lang="ar">
```

Setting `dir="rtl"` on `<html>`, or any container, flips text alignment, flexbox and grid item order (with no JSX changes needed), the direction `margin`/`padding`/`border` shorthand apply visually, and native form control alignment, all automatically, because these properties are direction-aware by the CSS spec itself, not something requiring JS to flip.

The CSS mistake to avoid: physical properties, `margin-left`, `padding-right`, `text-align: left`, don't flip with `dir="rtl"` at all. They stay pinned to the physical left or right regardless of reading direction, which breaks layout in RTL locales. **Logical properties** flip automatically because they're defined relative to text-flow direction, not a physical screen side.

```css
/* Bad: pinned to physical left, breaks visually in RTL */
.card { margin-left: 16px; text-align: left; }
/* Good: logical properties, correct in both LTR and RTL automatically */
.card { margin-inline-start: 16px; text-align: start; }
```

| Physical (avoid) | Logical (prefer) |
|---|---|
| `margin-left` / `margin-right` | `margin-inline-start` / `margin-inline-end` |
| `padding-left` / `padding-right` | `padding-inline-start` / `padding-inline-end` |
| `left` / `right` (positioning) | `inset-inline-start` / `inset-inline-end` |
| `text-align: left/right` | `text-align: start/end` |
| `border-left` / `border-right` | `border-inline-start` / `border-inline-end` |

Icons that convey direction, a "back" arrow, a "next" chevron, need to mirror in RTL too, and that's not automatic, it needs explicit handling, typically scoped to `[dir="rtl"]`:

```css
[dir="rtl"] .back-arrow-icon { transform: scaleX(-1); }
```

## What breaks past the obvious date and currency cases

Pluralization is not binary in many languages, Russian and Polish have multiple plural forms depending on the exact count, and `Intl.PluralRules`/ICU MessageFormat handle this correctly where a manual `count === 1 ? "item" : "items"` check simply doesn't generalize. Name order and formality vary too, some locales expect family name before given name, or require formal and informal address forms English doesn't have at all. Text expansion is a layout concern worth naming explicitly: German and Finnish UI strings routinely run 30-40% longer than the English original, and a layout hardcoded to English string lengths visibly breaks once translated, so fixed-width buttons and labels should be designed to tolerate that from the start, not fit English exactly.

The failures that actually show up in production rarely come from a missing translation key. They come from formatting logic hardcoded for one locale and never revisited: a price built with string concatenation instead of `Intl.NumberFormat`, a plural check that only handles English, a fixed-width button that clips German text. Treating `Intl` and ICU pluralization as the default from day one, rather than a retrofit once a second locale ships, is what separates code that scales to new markets from code that needs a rewrite to get there.
