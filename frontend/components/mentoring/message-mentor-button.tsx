"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { MessageCircle } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { createOrGetConversationAction } from "@/lib/mentoring/actions";
import ROUTES from "@/lib/routes";

interface MessageMentorButtonProps {
  mentorId: string;
  size?: "sm" | "default";
  variant?: "outline" | "default";
  className?: string;
}

// Starts (or resumes) a ticket-independent DM with any mentor — unlike
// ticket chat, this works regardless of whether the caller is currently
// assigned to this mentor.
export function MessageMentorButton({
  mentorId,
  size = "default",
  variant = "outline",
  className,
}: MessageMentorButtonProps) {
  const router = useRouter();
  const [pending, setPending] = useState(false);

  async function handleClick() {
    setPending(true);
    const result = await createOrGetConversationAction(mentorId);
    setPending(false);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Could not start a conversation.");
      return;
    }
    router.push(ROUTES.mentorConversation(result.data.id));
  }

  return (
    <Button className={className} disabled={pending} size={size} variant={variant} onClick={handleClick}>
      <MessageCircle aria-hidden className="h-4 w-4" />
      {pending ? "Opening…" : "Message mentor"}
    </Button>
  );
}
