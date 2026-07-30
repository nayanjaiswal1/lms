"use client";

import { Copy, Download } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import ROUTES from "@/lib/routes";

interface Props {
  certUuid: string;
}

// Print-to-PDF via the browser's native "Save as PDF" destination — no PDF
// library needed, and the print stylesheet below hides this action bar so
// the exported/printed page is just the certificate card.
export function CertificateActions({ certUuid }: Props) {
  const verifyUrl = `${process.env.NEXT_PUBLIC_APP_URL ?? ""}${ROUTES.certificate(certUuid)}`;

  const copyLink = () => {
    void navigator.clipboard.writeText(verifyUrl).then(() => toast.success("Verification link copied."));
  };

  return (
    <div className="flex flex-wrap items-center justify-center gap-3 print:hidden">
      <Button size="sm" onClick={() => window.print()}>
        <Download aria-hidden className="h-4 w-4" />
        Download / Export PDF
      </Button>
      <Button size="sm" variant="outline" onClick={copyLink}>
        <Copy aria-hidden className="h-4 w-4" />
        Copy link
      </Button>
    </div>
  );
}
