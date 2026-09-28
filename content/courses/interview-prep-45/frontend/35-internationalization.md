---
kind: lesson
id_key: interview-prep-45/day-26-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Internationalization"
position: 35
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Internationalization questions test whether you know that "translate the strings" is only the easy 10% of the job. The hard part is pluralization rules, locale-aware formatting, right-to-left layout, and not shipping every language's translations to every single user.

## The main ways to translate an app

| Approach | How it works | Trade-off |
|---|---|---|
| Key-based lookup (react-intl, react-i18next) | `t("welcome.message")` maps to a translated string per locale | Needs discipline to keep keys and translations in sync, though tooling can flag missing ones |
| ICU MessageFormat | Rich format strings inside the value handle plurals, gender, interpolation | More powerful pluralization, steeper syntax |
| Native `Intl` API | Built into the browser, for numbers, dates, lists, relative time, plural rules | Only formatting, no phrases, no string management |

Most real apps combine the first and third: a translation library for UI copy, and `Intl` for locale-aware formatting of dates, numbers, and currency, since `Intl` already knows every locale's formatting rules, writing your own would be redundant and easy to get wrong.

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

The `{count, plural, =0 {...} one {...} other {...}}` syntax is **ICU MessageFormat**, and it's the actual reason to reach for react-intl over a simpler key-value library. Pluralization isn't "singular versus plural" in most languages, some have separate forms for one, two, few, many, and everything else. ICU's plural categories map onto whichever subset a given locale actually needs, applying the right grammatical rule automatically through `Intl.PluralRules` underneath.

> **Remember:** a manual `count === 1 ? "item" : "items"` check only handles English. ICU MessageFormat handles the languages that need more than two plural forms.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-i18n-plural-q1", "type": "mcq",
      "prompt": "Why does react-intl use ICU MessageFormat's {count, plural, ...} syntax instead of a simple count === 1 ? singular : plural check?",
      "options": [
        {"id":"a","text":"It's purely a stylistic preference"},
        {"id":"b","text":"Many languages have more than two plural forms (one, few, many, other); ICU's categories map onto whichever set a given locale actually needs, which a binary singular/plural check can't represent"},
        {"id":"c","text":"ICU syntax runs faster at render time"},
        {"id":"d","text":"count === 1 checks don't work in JSX"}
      ],
      "correct": "b",
      "explanation": "A binary singular/plural check only ever works for English-like languages. Russian and Polish, for example, have multiple plural categories based on the exact count, which ICU MessageFormat and Intl.PluralRules handle correctly." }
] }
```

## Loading translations lazily, per locale

Shipping every locale's bundle to every visitor wastes bytes, an English visitor doesn't need the French, German, and Japanese translation files downloaded alongside their page. Load translations the same way you'd code-split a route.

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

In a framework like Next.js, the routing layer itself, `[locale]` dynamic segments, `next-intl`, resolves the locale from the URL path or the `Accept-Language` header on the server, and serves only that one locale's bundle, skipping a client-side fetch waterfall on the very first load.

> **Remember:** load one locale's translations on demand, not every locale up front. An English visitor should never download the French bundle.

## Formatting with Intl, never by hand

The native `Intl` API is the right tool for formatting. Never hand-roll date or currency formatting, decimal separators, thousands separators, date field order, and currency symbol placement vary in ways that are easy to get wrong and expensive to keep maintaining yourself.

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

React components typically wrap these to avoid rebuilding a formatter, which has real construction cost, on every single render.

```tsx
function useCurrencyFormatter(locale: string, currency: string) {
  return useMemo(() => new Intl.NumberFormat(locale, { style: "currency", currency }), [locale, currency]);
}
```

react-intl's `FormattedDate`, `FormattedNumber`, and `FormattedRelativeTime` components are thin wrappers around exactly these `Intl` constructors, plus this same memoization, plus reading the active locale from context automatically.

> **Remember:** never build your own date or currency formatting logic. `Intl` already encodes every locale's actual rules correctly.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-i18n-intl-q1", "type": "mcq",
      "prompt": "Why is a component built around Intl.NumberFormat usually wrapped in useMemo?",
      "options": [
        {"id":"a","text":"useMemo is required syntax for any Intl usage"},
        {"id":"b","text":"Constructing a new Intl.NumberFormat instance has a real cost, and useMemo avoids rebuilding it on every render when the locale and currency haven't changed"},
        {"id":"c","text":"Intl.NumberFormat doesn't work inside React components otherwise"},
        {"id":"d","text":"It prevents the formatted number from updating"}
      ],
      "correct": "b",
      "explanation": "Formatter construction isn't free. Memoizing it on the values that actually determine its behavior (locale, currency) avoids paying that construction cost on every single render." }
] }
```

## RTL: the whole layout flips, not just the text

A handful of widely-used languages, Arabic, Hebrew, Persian, Urdu, are right-to-left, and getting this right means more than mirroring the text, the entire layout direction flips.

```html
<html dir="rtl" lang="ar">
```

Setting `dir="rtl"` on `<html>`, or any container, flips text alignment, flexbox and grid item order (with zero JSX changes needed), the visual direction `margin`/`padding`/`border` shorthand apply, and native form control alignment, all automatically, because these are direction-aware properties by the CSS spec itself, not something needing JavaScript to flip.

The CSS mistake to avoid: physical properties, `margin-left`, `padding-right`, `text-align: left`, never flip with `dir="rtl"`. They stay pinned to the physical left or right no matter the reading direction, which breaks the layout in RTL. **Logical properties** flip automatically, since they're defined relative to text flow, not a fixed screen side.

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

Icons that show direction, a "back" arrow, a "next" chevron, need to mirror in RTL too, and that's not automatic, it needs explicit handling, usually scoped to `[dir="rtl"]`.

```css
[dir="rtl"] .back-arrow-icon { transform: scaleX(-1); }
```

> **Remember:** a physical property like `margin-left` stays pinned left in RTL and breaks. A logical property like `margin-inline-start` flips correctly on its own.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-i18n-rtl-q1", "type": "mcq",
      "prompt": "A card component uses margin-left: 16px. In an RTL layout (dir=\"rtl\"), what happens?",
      "options": [
        {"id":"a","text":"It automatically flips to margin-right, since dir=\"rtl\" flips all margin properties"},
        {"id":"b","text":"It stays pinned to the physical left side regardless of reading direction, since physical properties never flip with dir; margin-inline-start would flip correctly instead"},
        {"id":"c","text":"The browser throws an error"},
        {"id":"d","text":"Margins are ignored entirely in RTL mode"}
      ],
      "correct": "b",
      "explanation": "Physical properties like margin-left are tied to a fixed screen side, not to reading direction, so they don't respond to dir=\"rtl\" at all. Logical properties like margin-inline-start are defined relative to text flow and flip automatically." }
] }
```

## What breaks past the obvious date and currency cases

Pluralization is not binary in many languages, Russian and Polish have several plural forms depending on the exact count, and `Intl.PluralRules`/ICU MessageFormat handle this correctly where a manual check simply doesn't generalize. Name order and formality vary too, some locales expect the family name before the given name, or need formal and informal address forms English doesn't have at all. Text expansion is a layout concern worth naming out loud: German and Finnish UI strings routinely run 30 to 40 percent longer than the English original, and a layout built to fit English exactly visibly breaks once translated, so fixed-width buttons and labels should be designed to tolerate that from the start.

The failures that actually show up in production rarely come from a missing translation key. They come from formatting logic hardcoded for one locale and never revisited: a price built with string concatenation instead of `Intl.NumberFormat`, a plural check that only handles English, a fixed-width button that clips German text. Treating `Intl` and ICU pluralization as the default from day one, rather than a retrofit once a second locale ships, is what separates code that scales to new markets from code that needs a rewrite to get there.

> **Remember:** the real internationalization bugs are almost never a missing translation key. They're formatting logic quietly hardcoded for one locale from the start.
