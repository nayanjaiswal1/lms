---
kind: lesson
id_key: interview-prep-45/note-debounce-throttle-leading-trailing
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: Debounce vs Throttle — Leading and Trailing Edges"
position: 109
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

Debounce fires after activity stops; throttle fires at a fixed interval regardless of activity. This note goes one level deeper: when, exactly, does the function fire? At the start of the wait window, the end, or both?

## Debounce: wait for quiet

Debounce means keep resetting the timer while events keep coming, and only act once they stop.

**Trailing (the default, and the common case).** Nothing fires while events keep arriving. The moment they stop for the full delay, the *last* call's arguments fire. This is search-as-you-type: no request while the user is still typing, one request once they pause.

**Leading.** The *first* event in a burst fires immediately; every event after that, within the wait window, is swallowed. Good for ignoring rapid double-clicks: the first click registers, the rest in that window don't.

**Leading + trailing.** The first call fires immediately, and if more events arrived during the window, one final trailing call fires too, with the latest arguments. Rare, but useful when you want instant feedback *and* a guaranteed final sync.

```ts
function debounce(fn: (...a: any[]) => void, ms: number, opts: { leading?: boolean; trailing?: boolean } = { trailing: true }) {
  let timer: ReturnType<typeof setTimeout> | null = null;
  return (...args: any[]) => {
    const callNow = opts.leading && !timer;
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      timer = null;
      if (opts.trailing) fn(...args);
    }, ms);
    if (callNow) fn(...args);
  };
}
```

Debounce's timer resets on every new event: each call clears the previous `setTimeout` and starts a fresh one. That's why a steady stream of events with trailing debounce never fires at all until the stream stops long enough for one full `ms` window to elapse uninterrupted.

## Throttle: run at most once per interval

Throttle means no matter how many events come in, only act once every N ms; the clock doesn't reset.

**Leading (the default in lodash).** Fires immediately when the interval starts, then ignores further calls until the interval ends, then the next call starts a new interval. Good for scroll-position tracking, where you want the first update instantly.

**Trailing.** Nothing fires until the interval ends, at which point it fires once with whatever the latest call's arguments were. This adds initial delay, but guarantees you get the freshest state at each tick.

**Leading + trailing (common combo).** Fires at the start of the interval, and if calls kept coming during it, fires once more at the end with the latest arguments. Window-resize handlers often want this: instant feedback, plus a final accurate value once resizing settles.

```ts
function throttle(fn: (...a: any[]) => void, ms: number, opts: { leading?: boolean; trailing?: boolean } = { leading: true, trailing: true }) {
  let last = 0;
  let timer: ReturnType<typeof setTimeout> | null = null;
  let lastArgs: any[] | null = null;
  return (...args: any[]) => {
    const now = Date.now();
    if (!last && !opts.leading) last = now;
    const remaining = ms - (now - last);
    if (remaining <= 0) {
      if (timer) { clearTimeout(timer); timer = null; }
      last = now;
      fn(...args);
    } else if (opts.trailing) {
      lastArgs = args;
      if (!timer) {
        timer = setTimeout(() => {
          last = opts.leading ? Date.now() : 0;
          timer = null;
          if (lastArgs) fn(...lastArgs);
        }, remaining);
      }
    }
  };
}
```

Trace a burst of calls arriving faster than `ms`: the first call sees `remaining <= 0` (nothing has run yet), so it calls `fn` immediately and sets `last` to now. The next few calls land while `remaining` is still positive, so instead of calling `fn` they just update `lastArgs` and schedule one `setTimeout` for whatever time is left in the window. When that timeout fires, it calls `fn` once with the most recent `lastArgs`, then resets `last`. So a whole burst collapses into exactly one leading call and, if `trailing` is on, one trailing call at the end. Throttle's clock runs on a fixed schedule, independent of how many events arrive; it doesn't reset per event the way debounce's timer does.

## The interview one-liner

Debounce trailing waits for inactivity, since its timer resets on every event. Throttle waits for a fixed clock tick regardless of activity, since its timer never resets mid-interval. That's the distinction interviewers are actually probing for when they ask "what's the difference," not just "one waits, one limits."

lodash exposes both as explicit flags: `_.debounce(fn, ms, { leading, trailing })` and `_.throttle(fn, ms, { leading, trailing })`. Knowing the flag names, not just the underlying concept, is usually what separates a confident answer from a hand-wavy one.
