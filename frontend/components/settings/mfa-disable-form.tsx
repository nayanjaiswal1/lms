"use client";

import { useTransition } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2 } from "lucide-react";
import { toast } from "sonner";

import { disableMfaAction } from "@/app/(app)/settings/security/actions";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { mfaCodeSchema, type MfaCodeInput } from "@/lib/validation/auth";

interface MfaDisableFormProps {
  onDisabled: () => void;
}

export function MfaDisableForm({ onDisabled }: MfaDisableFormProps) {
  const [pending, startTransition] = useTransition();
  const form = useForm<MfaCodeInput>({
    resolver: zodResolver(mfaCodeSchema),
    defaultValues: { code: "" },
  });

  const onSubmit = form.handleSubmit(({ code }) => {
    startTransition(async () => {
      const res = await disableMfaAction(code);
      if (res.error) {
        toast.error(res.error);
        return;
      }
      toast.success("Two-factor authentication turned off.");
      onDisabled();
    });
  });

  return (
    <Form {...form}>
      <form noValidate className="form-stack" onSubmit={onSubmit}>
        <FormInputField
          autoComplete="one-time-code"
          control={form.control}
          description="Enter a code from your authenticator app, or a recovery code, to turn it off."
          disabled={pending}
          label="Authentication code"
          name="code"
        />
        <Button className="touch-target self-start" disabled={pending} type="submit" variant="destructive">
          {pending && <Loader2 aria-hidden className="animate-spin" />}
          Turn off two-factor authentication
        </Button>
      </form>
    </Form>
  );
}
