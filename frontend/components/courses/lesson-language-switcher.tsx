import Link from "next/link";
import { Languages } from "lucide-react";
import { buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import type { ModuleTranslation } from "@/lib/server/courses";

interface LessonLanguageSwitcherProps {
  basePath: string;
  translations: ModuleTranslation[];
  activeLocale: string | null;
}

// Language names come from the browser/ICU locale data (Intl.DisplayNames)
// rendered in the language's own tongue, so there is no list to maintain.
function languageName(locale: string): string {
  try {
    return new Intl.DisplayNames([locale], { type: "language" }).of(locale) ?? locale;
  } catch {
    return locale;
  }
}

// Picks the translation a `?lang=` value selects; anything unknown or absent
// falls back to the original lesson body.
export function pickTranslation(translations: ModuleTranslation[], lang: string | undefined): ModuleTranslation | null {
  return translations.find((t) => t.locale === lang) ?? null;
}

// Renders nothing for an untranslated lesson. Plain links — the language lives
// in the URL (?lang=), so it survives refresh and can be shared.
export function LessonLanguageSwitcher({ basePath, translations, activeLocale }: LessonLanguageSwitcherProps) {
  if (translations.length === 0) return null;
  const options = [{ locale: null, label: "Original" }, ...translations.map((t) => ({ locale: t.locale, label: languageName(t.locale) }))];
  return (
    <nav aria-label="Lesson language" className="mb-6 flex flex-wrap items-center gap-2">
      <Languages aria-hidden className="h-4 w-4 text-muted-foreground" />
      {options.map((o) => (
        <Link
          aria-current={o.locale === activeLocale ? "true" : undefined}
          className={cn(buttonVariants({ variant: o.locale === activeLocale ? "default" : "outline", size: "sm" }))}
          href={o.locale ? `${basePath}?lang=${encodeURIComponent(o.locale)}` : basePath}
          key={o.locale ?? "original"}
          scroll={false}
        >
          {o.label}
        </Link>
      ))}
    </nav>
  );
}
