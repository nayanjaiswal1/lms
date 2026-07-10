import Link from "next/link";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import ROUTES from "@/lib/routes";

export function SheetsToolbar() {
  return (
    <Button asChild size="sm">
      <Link href={ROUTES.SHEETS_NEW}>
        <Plus aria-hidden className="h-4 w-4" />
        Create sheet
      </Link>
    </Button>
  );
}
