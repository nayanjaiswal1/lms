import { Bell, Plus, User } from "lucide-react";

import { Button } from "@/components/ui/button";
export function IssuesTopbar() {
  return (
    <header className="m-shadow safe-top sticky top-0 z-sticky flex h-14 items-center justify-between gap-3 bg-card/90 px-4 backdrop-blur-xl">
      <div className="flex min-w-0 items-center gap-2">
        <span className="m-headline-sm hidden truncate text-muted-foreground sm:inline">Auto Expand Board</span>
        <span className="m-label-sm hidden text-(--m-outline-variant) sm:inline">/</span>
        <span className="m-headline-sm truncate text-foreground">Issues &amp; Tasks</span>
      </div>
      <div className="flex items-center gap-2">
        <Button aria-label="Notifications" className="flex size-8 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-muted hover:text-foreground" type="button" variant="unstyled">
          <Bell aria-hidden className="size-4.5" />
        </Button>
        <Button className="m-headline-sm flex h-8 items-center gap-1 rounded-lg bg-(--m-primary-container) px-3 text-(--m-on-primary-container) shadow-card transition-colors hover:bg-primary hover:text-(--m-sc-lowest)"
          type="button"
          variant="unstyled"
        >
          <Plus aria-hidden className="size-4.5" />
          <span className="hidden sm:inline">New Issue</span>
        </Button>
        <div className="ml-1 hidden size-8 items-center justify-center rounded-full bg-primary sm:flex">
          <User aria-hidden className="size-4.5 text-(--m-sc-lowest)" />
        </div>
      </div>
    </header>
  );
}
