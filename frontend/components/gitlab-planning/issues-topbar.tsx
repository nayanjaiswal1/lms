import { Bell, Plus, Search, User } from "lucide-react";

export function IssuesTopbar() {
  return (
    <header className="m-shadow safe-top sticky top-0 z-sticky flex h-14 items-center justify-between gap-3 bg-(--m-sc-lowest)/90 px-4 backdrop-blur-xl">
      <div className="flex min-w-0 items-center gap-2">
        <span className="m-headline-sm hidden truncate text-(--m-on-surface-variant) sm:inline">Auto Expand Board</span>
        <span className="m-label-sm hidden text-(--m-outline-variant) sm:inline">/</span>
        <span className="m-headline-sm truncate text-(--m-on-surface)">Issues &amp; Tasks</span>
      </div>
      <div className="flex items-center gap-2">
        <label className="relative hidden w-80 items-center md:flex">
          <span className="sr-only">Search issues</span>
          <Search className="pointer-events-none absolute left-2 size-4.5 text-(--m-on-surface-variant)" aria-hidden />
          <input
            type="search"
            placeholder="Search issues, steps, tags..."
            className="m-body-sm h-8 w-full rounded-lg bg-(--m-sc-low) pl-9 pr-10 text-(--m-on-surface) transition-all placeholder:text-(--m-on-surface-variant) focus:bg-(--m-sc) focus:outline-none"
          />
          <kbd className="m-label-sm absolute right-2 rounded bg-(--m-sc-highest) px-1.5 py-0.5 text-[10px] text-(--m-on-surface-variant)">⌘K</kbd>
        </label>
        <button type="button" aria-label="Notifications" className="flex size-8 items-center justify-center rounded-lg text-(--m-on-surface-variant) transition-colors hover:bg-(--m-sc-low) hover:text-(--m-on-surface)">
          <Bell className="size-4.5" aria-hidden />
        </button>
        <button
          type="button"
          className="m-headline-sm flex h-8 items-center gap-1 rounded-lg bg-(--m-primary-container) px-3 text-(--m-on-primary-container) shadow-sm transition-colors hover:bg-(--m-primary) hover:text-(--m-sc-lowest)"
        >
          <Plus className="size-4.5" aria-hidden />
          <span className="hidden sm:inline">New Issue</span>
        </button>
        <div className="ml-1 hidden size-8 items-center justify-center rounded-full bg-(--m-primary) sm:flex">
          <User className="size-4.5 text-(--m-sc-lowest)" aria-hidden />
        </div>
      </div>
    </header>
  );
}
