interface ModuleProgressRailProps {
  children?: React.ReactNode;
}

// Right rail at xl+ (sticky, beside the article). Below xl it stacks under
// the article at the article's width, so its actions (Launch Lab, My notes,
// compiler) stay reachable; callers hide xl-only children (TOC, progress)
// themselves.
export function ModuleProgressRail({ children }: ModuleProgressRailProps) {
  if (!children) return null;

  return (
    <aside
      aria-label="On this page"
      className="mx-auto flex w-full max-w-3xl flex-col gap-6 xl:mx-0 xl:w-80 xl:max-w-none xl:shrink-0 xl:px-6 xl:pb-8 xl:sticky-rail xl:top-8 xl:max-h-[calc(100dvh-9rem)]"
    >
      {children}
    </aside>
  );
}
