"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { z } from "zod";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Button } from "@/components/ui/button";
import { Form, FormControl, FormField, FormItem, FormMessage } from "@/components/ui/form";
import { Textarea } from "@/components/ui/textarea";
import { sendConversationMessageAction } from "@/lib/mentoring/actions";

const MessageSchema = z.object({
  body: z.string().min(1, "Message can't be empty.").max(4000),
});
type MessageFormData = z.infer<typeof MessageSchema>;

interface MentorDmComposerProps {
  conversationId: string;
}

export function MentorDmComposer({ conversationId }: MentorDmComposerProps) {
  const router = useRouter();
  const [sending, setSending] = useState(false);
  const form = useForm<MessageFormData>({
    resolver: zodResolver(MessageSchema),
    defaultValues: { body: "" },
  });

  async function onSubmit(data: MessageFormData) {
    setSending(true);
    const result = await sendConversationMessageAction(conversationId, data.body);
    setSending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    form.reset();
    router.refresh();
  }

  return (
    <Form {...form}>
      <form className="flex items-end gap-2" onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="body"
          render={({ field }) => (
            <FormItem className="flex-1">
              <FormControl>
                <Textarea placeholder="Write a message…" rows={2} {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <Button disabled={sending} type="submit">
          {sending ? "Sending…" : "Send"}
        </Button>
      </form>
    </Form>
  );
}
