interface PageHeaderProps {
  title: React.ReactNode;
  /** A string renders as the standard muted subtitle; pass an element for custom markup. */
  description?: React.ReactNode;
  /** Leading icon shown beside the title. */
  icon?: React.ReactNode;
  /** Badge/status chip shown beside the title. */
  badge?: React.ReactNode;
  /** Extra rows under the description (stats, tags, progress). */
  meta?: React.ReactNode;
  /** Top-align the right-hand actions with the title block instead of centering. */
  alignStart?: boolean;
  /** Right-hand actions (buttons, menus, counts). */
  children?: React.ReactNode;
}

// The single page-title row — keeps heading size and spacing identical on every page.
export function PageHeader({ title, description, icon, badge, meta, alignStart, children }: PageHeaderProps) {
  const subtitle =
    typeof description === "string" ? <p className="page-description">{description}</p> : description;
  const heading = <h1 className="page-title">{title}</h1>;
  return (
    <div className={alignStart ? "page-header items-start" : "page-header"}>
      {description || icon || badge || meta ? (
        <div className="flex min-w-0 flex-col gap-1">
          {icon || badge ? (
            <div className="flex flex-wrap items-center gap-2">
              {icon}
              {heading}
              {badge}
            </div>
          ) : (
            heading
          )}
          {subtitle}
          {meta}
        </div>
      ) : (
        heading
      )}
      {children}
    </div>
  );
}
