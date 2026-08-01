"use client";

import { Share2 } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";

interface ShareProfileButtonProps {
  mentorName: string;
  path: string;
  className?: string;
}

export function ShareProfileButton({ mentorName, path, className }: ShareProfileButtonProps) {
  async function handleShare() {
    const url = `${window.location.origin}${path}`;
    if (navigator.share) {
      try {
        await navigator.share({ title: `${mentorName} — MindForge Mentor`, url });
      } catch {
        // User cancelled the native share sheet — not an error.
      }
      return;
    }
    await navigator.clipboard.writeText(url);
    toast.success("Profile link copied to clipboard.");
  }

  return (
    <Button className={className} size="sm" variant="outline" onClick={handleShare}>
      <Share2 aria-hidden className="mr-1.5 h-4 w-4" />
      Share
    </Button>
  );
}
