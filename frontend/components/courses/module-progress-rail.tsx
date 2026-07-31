interface ModuleProgressRailProps {
  children?: React.ReactNode;
}

// Desktop-only rail (xl+) — holds the module's type/duration/completion
// badges plus the on-page TOC for reading modules, so the wide right gutter
// isn't left empty on narrower (lg) layouts where those badges stay inline
// in the article header instead.
export function ModuleProgressRail({ children }: ModuleProgressRailProps) {
  if (!children) return null;

  return (
    <aside
      aria-label="On this page"
      className="hidden w-64 shrink-0 flex-col gap-6 pb-8 pl-6 xl:flex xl:sticky-rail xl:top-8 xl:max-h-[calc(100dvh-9rem)]"
    >
      {children}
    </aside>
  );
}
