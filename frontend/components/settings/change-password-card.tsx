"use client";

import { useTransition } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2 } from "lucide-react";
import { toast } from "sonner";

import { changePasswordAction } from "@/app/(app)/settings/security/actions";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { changePasswordSchema, type ChangePasswordInput } from "@/lib/validation/auth";

const EMPTY: ChangePasswordInput = { currentPassword: "", newPassword: "", confirmPassword: "" };

// Backend field keys -> form field names.
const SERVER_FIELDS = { current_password: "currentPassword", new_password: "newPassword" } as const;

export function ChangePasswordCard() {
  const [pending, startTransition] = useTransition();
  const form = useForm<ChangePasswordInput>({
    resolver: zodResolver(changePasswordSchema),
    defaultValues: EMPTY,
    mode: "onTouched",
  });

  const onSubmit = form.handleSubmit(({ currentPassword, newPassword }) => {
    startTransition(async () => {
      const res = await changePasswordAction(currentPassword, newPassword);
      if (res.error || res.fieldErrors) {
        let shown = false;
        for (const [key, message] of Object.entries(res.fieldErrors ?? {})) {
          const field = SERVER_FIELDS[key as keyof typeof SERVER_FIELDS];
          if (field) {
            form.setError(field, { message });
            shown = true;
          }
        }
        if (!shown) toast.error(res.error ?? "Couldn't change your password.");
        return;
      }
      form.reset(EMPTY);
      toast.success("Password changed. Your other devices were signed out.");
    });
  });

  return (
    <section aria-labelledby="change-password-heading" className="card-base space-y-5 p-6">
      <div>
        <h2 className="text-lg font-semibold text-foreground" id="change-password-heading">
          Change password
        </h2>
        <p className="text-sm text-muted-foreground">
          You&apos;ll stay signed in here; every other session is signed out.
        </p>
      </div>
      <Form {...form}>
        <form noValidate className="form-stack" onSubmit={onSubmit}>
          <FormInputField
            autoComplete="current-password"
            control={form.control}
            disabled={pending}
            label="Current password"
            name="currentPassword"
            type="password"
          />
          <FormInputField
            autoComplete="new-password"
            control={form.control}
            disabled={pending}
            label="New password"
            name="newPassword"
            type="password"
          />
          <FormInputField
            autoComplete="new-password"
            control={form.control}
            disabled={pending}
            label="Confirm new password"
            name="confirmPassword"
            type="password"
          />
          <Button className="touch-target self-start" disabled={pending} type="submit">
            {pending && <Loader2 aria-hidden className="animate-spin" />}
            Change password
          </Button>
        </form>
      </Form>
    </section>
  );
}
