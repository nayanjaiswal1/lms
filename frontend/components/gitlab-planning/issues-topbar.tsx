import { Bell, Plus, Search, User } from "lucide-react";

export function IssuesTopbar() {
  return (
    <header className="m-shadow safe-top sticky top-0 z-sticky flex h-14 items-center justify-between gap-3 bg-card/90 px-4 backdrop-blur-xl">
      <div className="flex min-w-0 items-center gap-2">
        <span className="m-headline-sm hidden truncate text-muted-foreground sm:inline">Auto Expand Board</span>
        <span className="m-label-sm hidden text-(--m-outline-variant) sm:inline">/</span>
        <span className="m-headline-sm truncate text-foreground">Issues &amp; Tasks</span>
      </div>
      <div className="flex items-center gap-2">
        <label className="relative hidden w-80 items-center md:flex">
          <span className="sr-only">Search issues</span>
          <Search aria-hidden className="pointer-events-none absolute left-2 size-4.5 text-muted-foreground" />
          <input
            className="m-body-sm h-8 w-full rounded-lg bg-muted pl-9 pr-10 text-foreground transition-all placeholder:text-muted-foreground focus:bg-muted focus:outline-none"
            placeholder="Search issues, steps, tags..."
            type="search"
          />
          <kbd className="m-label-sm absolute right-2 rounded bg-accent px-1.5 py-0.5 text-xs text-muted-foreground">⌘K</kbd>
        </label>
        <button aria-label="Notifications" className="flex size-8 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-muted hover:text-foreground" type="button">
          <Bell aria-hidden className="size-4.5" />
        </button>
        <button
          className="m-headline-sm flex h-8 items-center gap-1 rounded-lg bg-(--m-primary-container) px-3 text-(--m-on-primary-container) shadow-card transition-colors hover:bg-primary hover:text-(--m-sc-lowest)"
          type="button"
        >
          <Plus aria-hidden className="size-4.5" />
          <span className="hidden sm:inline">New Issue</span>
        </button>
        <div className="ml-1 hidden size-8 items-center justify-center rounded-full bg-primary sm:flex">
          <User aria-hidden className="size-4.5 text-(--m-sc-lowest)" />
        </div>
      </div>
    </header>
  );
}
