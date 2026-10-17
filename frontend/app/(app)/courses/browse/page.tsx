import { CatalogPage } from "@/components/courses/catalog-page";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Browse courses" };

export default function BrowseCoursesPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | undefined>>;
}) {
  return <CatalogPage discovery={false} basePath={ROUTES.COURSES_BROWSE} searchParams={searchParams} title="Browse courses" />;
}
