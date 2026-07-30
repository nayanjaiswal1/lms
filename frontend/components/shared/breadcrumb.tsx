import Link from "next/link";

export interface BreadcrumbItem {
  label: string;
  href?: string;
}

interface BreadcrumbProps {
  items: BreadcrumbItem[];
}

/**
 * Trail of parent links ending in the current page (no href on the last item).
 * Use on any page nested under a list/detail parent where the sidebar alone
 * doesn't show where the page sits (e.g. batches/[id]/tests/[testId]).
 */
export function Breadcrumb({ items }: BreadcrumbProps) {
  return (
    <nav aria-label="Breadcrumb" className="mb-4 flex flex-wrap items-center gap-1 text-sm text-muted-foreground">
      {items.map((item, i) => (
        <span className="flex items-center gap-1" key={item.label}>
          {i > 0 && <span aria-hidden>/</span>}
          {item.href ? (
            <Link className="hover:text-foreground" href={item.href}>
              {item.label}
            </Link>
          ) : (
            <span className="text-foreground">{item.label}</span>
          )}
        </span>
      ))}
    </nav>
  );
}
