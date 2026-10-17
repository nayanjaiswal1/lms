"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { ChevronRight, Loader2, Search, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Command, CommandEmpty, CommandItem, CommandList } from "@/components/ui/command";
import { useAllVisibleNavItems } from "@/lib/nav";
import { isCourseLearnRoute } from "@/lib/routes";

const ID_SEGMENT = /^(\d+|[0-9a-f]{8}-[0-9a-f-]{27}|[0-9a-f]{20,})$/i;
const SEARCH_DEBOUNCE_MS = 300;

// Pages whose search filters the page's own list through a query param. Every
// other page uses the same box to jump to a page.
type PageSearch = { placeholder: string; param: string };
const PAGE_SEARCH: [RegExp, PageSearch][] = [
  [/^\/courses(\/browse)?$/, { placeholder: "Search courses…", param: "q" }],
  [/^\/users$/, { placeholder: "Search by name or email…", param: "search" }],
  [/^\/assessments$/, { placeholder: "Search assessments by title…", param: "search" }],
  [/^\/question-bank$/, { placeholder: "Search questions by title…", param: "search" }],
  [/^\/admin\/rbac\/roles$/, { placeholder: "Search roles…", param: "search" }],
  [/^\/mentors$/, { placeholder: "Search by name, role or skill…", param: "q" }],
  [/^\/journal$/, { placeholder: "Search your learning…", param: "q" }],
  [/^\/interview-exp$/, { placeholder: "Search interview posts…", param: "q" }],
  [/^\/workspaces\/[^/]+\/(board|list)$/, { placeholder: "Search items…", param: "q" }],
  [/^\/wiki(\/[^/]+)?$/, { placeholder: "Search the wiki…", param: "q" }],
  [/^\/calendar$/, { placeholder: "Search events…", param: "q" }],
  [/^\/batches\/[^/]+$/, { placeholder: "Search people or courses…", param: "q" }],
  [/^\/platform\/features$/, { placeholder: "Search organisations…", param: "search" }],
  [/^\/library$/, { placeholder: "Search labs, quizzes, notes…", param: "q" }],
];
const findPageSearch = (pathname: string) => PAGE_SEARCH.find(([re]) => re.test(pathname))?.[1];

function humanize(segment: string): string {
  if (ID_SEGMENT.test(segment)) return "Details";
  const words = decodeURIComponent(segment).replace(/[-_]+/g, " ");
  return words.charAt(0).toUpperCase() + words.slice(1);
}

// Trail derived from the URL: Home / Segment / … / Current. Labels come from
// the sidebar nav where a segment is a nav destination, else the humanized slug.
function useTrail(pathname: string) {
  const items = useAllVisibleNavItems();
  const navLabels = new Map(items.map((i) => [i.href, i.label]));
  const segments = pathname.split("/").filter(Boolean);
  return segments.map((segment, i) => {
    const href = "/" + segments.slice(0, i + 1).join("/");
    return { href, label: navLabels.get(href) ?? humanize(segment), current: i === segments.length - 1 };
  });
}

function SearchBar({ pathname }: { pathname: string }) {
  const router = useRouter();
  const params = useSearchParams();
  const items = useAllVisibleNavItems();
  const inputRef = useRef<HTMLInputElement>(null);
  const pageSearch = findPageSearch(pathname);
  const current = pageSearch ? (params.get(pageSearch.param) ?? "") : "";
  const [value, setValue] = useState(pageSearch ? current : "");
  const [focused, setFocused] = useState(false);
  const [pending, startTransition] = useTransition();
  // Typing but not yet applied to the URL (debounce window) also counts as busy.
  const busy = pageSearch ? pending || value.trim() !== current : false;
  const matches = items.filter((i) => i.label.toLowerCase().includes(value.trim().toLowerCase()));

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        inputRef.current?.focus();
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  useEffect(() => {
    if (!pageSearch) return;
    const q = value.trim();
    if (q === current) return;
    const t = setTimeout(() => {
      startTransition(() => {
        const next = new URLSearchParams(params.toString());
        if (q) next.set(pageSearch.param, q);
        else next.delete(pageSearch.param);
        const qs = next.toString();
        router.replace(qs ? `${pathname}?${qs}` : pathname);
      });
    }, SEARCH_DEBOUNCE_MS);
    return () => clearTimeout(t);
  }, [value, current, pathname, pageSearch, params, router]);

  const placeholder = pageSearch?.placeholder ?? "Search pages…";
  const showResults = !pageSearch && focused && value.trim() !== "";

  return (
    <search className="relative block w-72">
      <Command className="overflow-visible bg-transparent" shouldFilter={false}>
        <label className="sr-only" htmlFor="top-search">
          {placeholder}
        </label>
        <Search aria-hidden className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <input
          className="w-full rounded-md border border-border bg-background py-2 pl-9 pr-16 text-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
          id="top-search"
          placeholder={placeholder}
          ref={inputRef}
          type="text"
          value={value}
          onBlur={() => setFocused(false)}
          onChange={(e) => setValue(e.target.value)}
          onFocus={() => setFocused(true)}
          onKeyDown={(e) => {
            if (e.key === "Escape") setValue("");
            if (e.key === "Enter" && showResults && matches[0]) {
              router.push(matches[0].href);
              setValue("");
            }
          }}
        />
        <div aria-live="polite" className="absolute right-2 top-1/2 -translate-y-1/2">
          {busy ? (
            <Loader2 aria-label="Searching" className="h-4 w-4 animate-spin text-muted-foreground" />
          ) : value ? (
            <Button aria-label="Clear search" className="h-6 w-6 p-0" size="sm" variant="ghost" onClick={() => setValue("")}>
              <X aria-hidden className="h-3.5 w-3.5" />
            </Button>
          ) : (
            <kbd className="rounded-sm border border-border px-1.5 text-xs text-muted-foreground">Ctrl K</kbd>
          )}
        </div>
        {showResults && (
          <CommandList className="absolute left-0 right-0 top-full z-dropdown mt-1 rounded-md border border-border bg-popover p-1 shadow-modal">
            <CommandEmpty>No pages found.</CommandEmpty>
            {matches.map((item) => (
              <CommandItem
                className="gap-3 px-3 py-2"
                key={item.href}
                value={item.href}
                // mousedown keeps the input from blurring before the click lands
                onMouseDown={(e) => e.preventDefault()}
                onSelect={() => {
                  router.push(item.href);
                  setValue("");
                }}
              >
                <item.icon aria-hidden className="h-4 w-4 text-muted-foreground" />
                <span className="flex-1 truncate">{item.label}</span>
              </CommandItem>
            ))}
          </CommandList>
        )}
      </Command>
    </search>
  );
}

export function TopBar() {
  const pathname = usePathname();
  const trail = useTrail(pathname);

  if (isCourseLearnRoute(pathname)) return null;

  return (
    <div className="hidden lg:flex items-center gap-4 border-b border-border bg-background px-6 lg:px-8 py-2.5">
      <nav aria-label="Breadcrumb" className="min-w-0 flex-1">
        <ol className="flex items-center gap-1 text-sm text-muted-foreground">
          <li>
            <Link className="hover:text-foreground" href="/">
              Home
            </Link>
          </li>
          {trail.map((c) => (
            <li className="flex min-w-0 items-center gap-1" key={c.href}>
              <ChevronRight aria-hidden className="h-3.5 w-3.5 shrink-0" />
              {c.current ? (
                <span aria-current="page" className="truncate text-foreground">
                  {c.label}
                </span>
              ) : (
                <Link className="truncate hover:text-foreground" href={c.href}>
                  {c.label}
                </Link>
              )}
            </li>
          ))}
        </ol>
      </nav>
      <SearchBar key={pathname} pathname={pathname} />
    </div>
  );
}
