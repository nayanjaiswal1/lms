import Link from "next/link"
import { Button } from "@/components/ui/button"
import ROUTES from "@/lib/routes"

interface ResultNextProps {
  labId: string
}

/** Where to go from here: back to the catalog or another attempt. */
export function ResultNext({ labId }: ResultNextProps) {
  return (
    <section aria-labelledby="result-next" className="flex flex-col gap-3">
      <h2 className="subsection-title" id="result-next">
        Next
      </h2>
      <div className="flex flex-col gap-2 sm:flex-row">
        <Button asChild className="min-h-11">
          <Link href={ROUTES.lab(labId)}>Try again</Link>
        </Button>
        <Button asChild className="min-h-11" variant="outline">
          <Link href={ROUTES.LABS_CATALOG}>Back to Labs</Link>
        </Button>
      </div>
    </section>
  )
}
