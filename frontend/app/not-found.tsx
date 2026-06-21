import Link from "next/link";
import { Button } from "@/components/ui/button";
import ROUTES from "@/lib/routes";

export default function NotFound() {
  return (
    <main className="flex-center min-h-[60vh] flex-col gap-4 text-center">
      <div>
        <p className="text-sm font-medium text-primary">404</p>
        <h1 className="mt-1 text-2xl font-semibold tracking-tight">Page not found</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          The page you’re looking for doesn’t exist or has moved.
        </p>
      </div>
      <Button asChild size="sm">
        <Link href={ROUTES.HOME}>Back to home</Link>
      </Button>
    </main>
  );
}
