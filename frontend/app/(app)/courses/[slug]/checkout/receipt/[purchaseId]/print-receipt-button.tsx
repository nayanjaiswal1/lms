"use client";

import { Button } from "@/components/ui/button";

export function PrintReceiptButton() {
  return (
    <Button className="h-auto p-0" type="button" variant="link" onClick={() => window.print()}>
      Print / save as PDF
    </Button>
  );
}
