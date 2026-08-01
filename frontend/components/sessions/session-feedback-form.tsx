"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Star } from "lucide-react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
import { submitSessionFeedbackAction, type SessionFeedback, type SessionStatus } from "@/lib/server/sessions";

const FeedbackSchema = z.object({
  rating: z.enum(["1", "2", "3", "4", "5"]),
  comment: z.string().max(1000, "Keep it under 1000 characters.").optional(),
});
type FeedbackFormData = z.infer<typeof FeedbackSchema>;

interface SessionFeedbackFormProps {
  sessionId: string;
  status: SessionStatus;
  endsAt: string;
  myFeedback: SessionFeedback | null;
}

export function SessionFeedbackForm({ sessionId, status, endsAt, myFeedback }: SessionFeedbackFormProps) {
  const router = useRouter();
  const form = useForm<FeedbackFormData>({
    resolver: zodResolver(FeedbackSchema),
    defaultValues: {
      rating: myFeedback ? (String(myFeedback.rating) as FeedbackFormData["rating"]) : "5",
      comment: myFeedback?.comment ?? "",
    },
  });

  // Defensive guard — the parent already decides whether to render this
  // form, but a session that hasn't ended yet or was cancelled never takes
  // feedback even if a caller forgets the check.
  const hasEnded = new Date(endsAt).getTime() <= Date.now();
  if (status === "cancelled" || !hasEnded) return null;

  async function onSubmit(data: FeedbackFormData) {
    const result = await submitSessionFeedbackAction(sessionId, Number(data.rating), data.comment ?? "");
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(myFeedback ? "Feedback updated." : "Feedback submitted.");
    router.refresh();
  }

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="rating"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Rating</FormLabel>
              <div aria-label="Star rating" className="flex items-center gap-1" role="radiogroup">
                {(["1", "2", "3", "4", "5"] as const).map((n) => (
                  <button
                    aria-checked={field.value === n}
                    aria-label={`${n} star${n === "1" ? "" : "s"}`}
                    className="touch-target"
                    key={n}
                    role="radio"
                    type="button"
                    onClick={() => field.onChange(n)}
                  >
                    <Star
                      aria-hidden
                      className={cn(
                        "h-6 w-6 transition-colors",
                        Number(field.value) >= Number(n) ? "fill-primary text-primary" : "text-muted-foreground",
                      )}
                    />
                  </button>
                ))}
              </div>
              <FormMessage />
            </FormItem>
          )}
        />
        <FormField
          control={form.control}
          name="comment"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Comment (optional)</FormLabel>
              <FormControl>
                <Textarea placeholder="How did the session go?" rows={3} {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <Button className="w-fit" disabled={form.formState.isSubmitting} type="submit">
          {form.formState.isSubmitting ? "Saving…" : myFeedback ? "Update feedback" : "Submit feedback"}
        </Button>
      </form>
    </Form>
  );
}
