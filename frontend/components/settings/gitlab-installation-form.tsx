"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import {
  createGitlabInstallationPATAction,
  startGitlabInstallOAuthAction,
} from "@/app/(app)/settings/integrations/actions";

const InstallSchema = z
  .object({
    name: z.string().min(1, "A name is required."),
    authKind: z.enum(["pat", "oauth"]),
    baseUrl: z.string().min(1, "GitLab instance URL is required.").url("Enter a valid URL, e.g. https://gitlab.example.com"),
    // Plain (non-optional) strings, not `.optional().default("")` — that pair
    // makes z.infer's input type differ from its output type (input optional,
    // output required), which zodResolver's Resolver<TFieldValues> can't
    // reconcile with useForm<InstallFormData>. defaultValues below already
    // supplies "" for each, and superRefine enforces which ones are truly
    // required per authKind.
    personalAccessToken: z.string(),
    oauthClientId: z.string(),
    oauthClientSecret: z.string(),
  })
  .superRefine((data, ctx) => {
    if (data.authKind === "pat" && data.personalAccessToken.trim() === "") {
      ctx.addIssue({ code: "custom", path: ["personalAccessToken"], message: "A personal access token is required." });
    }
    if (data.authKind === "oauth" && data.oauthClientId.trim() === "") {
      ctx.addIssue({ code: "custom", path: ["oauthClientId"], message: "An OAuth application client ID is required." });
    }
  });
type InstallFormData = z.infer<typeof InstallSchema>;

interface GitlabInstallationFormProps {
  onDone: () => void;
}

export function GitlabInstallationForm({ onDone }: GitlabInstallationFormProps) {
  const form = useForm<InstallFormData>({
    resolver: zodResolver(InstallSchema),
    defaultValues: { name: "", authKind: "pat", baseUrl: "", personalAccessToken: "", oauthClientId: "", oauthClientSecret: "" },
  });
  const authKind = form.watch("authKind");

  async function onSubmit(data: InstallFormData) {
    if (data.authKind === "pat") {
      const result = await createGitlabInstallationPATAction({
        name: data.name,
        baseUrl: data.baseUrl,
        personalAccessToken: data.personalAccessToken,
        oauthClientId: data.oauthClientId,
        oauthClientSecret: data.oauthClientSecret,
      });
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success(`"${data.name}" connected.`);
      onDone();
      return;
    }

    const result = await startGitlabInstallOAuthAction({
      name: data.name,
      baseUrl: data.baseUrl,
      oauthClientId: data.oauthClientId,
      oauthClientSecret: data.oauthClientSecret,
    });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    if (result.data?.authorize_url) {
      window.location.href = result.data.authorize_url;
    }
  }

  return (
    <Form {...form}>
      <form className="form-stack rounded-lg border border-dashed border-border p-4" onSubmit={form.handleSubmit(onSubmit)}>
        <FormInputField
          control={form.control}
          label="Connection name"
          name="name"
          placeholder="e.g. GitLab.com, Self-hosted EU"
        />

        <FormField
          control={form.control}
          name="authKind"
          render={({ field }) => (
            <FormItem>
              <FormLabel>How should MindForge authenticate?</FormLabel>
              <FormControl>
                <RadioGroup className="grid-cols-1 sm:grid-cols-2" value={field.value} onValueChange={field.onChange}>
                  <label className="flex items-center gap-2 rounded-md border border-border p-3 text-sm" htmlFor="auth-kind-pat">
                    <RadioGroupItem id="auth-kind-pat" value="pat" />
                    Personal access token
                  </label>
                  <label className="flex items-center gap-2 rounded-md border border-border p-3 text-sm" htmlFor="auth-kind-oauth">
                    <RadioGroupItem id="auth-kind-oauth" value="oauth" />
                    OAuth application
                  </label>
                </RadioGroup>
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormInputField
          control={form.control}
          label="GitLab instance URL"
          name="baseUrl"
          placeholder="https://gitlab.example.com"
        />

        {authKind === "pat" ? (
          <FormInputField
            autoComplete="off"
            control={form.control}
            label="Personal access token"
            name="personalAccessToken"
            placeholder="glpat-…"
            type="password"
          />
        ) : (
          <>
            <FormInputField
              control={form.control}
              label="OAuth application client ID"
              name="oauthClientId"
            />
            <FormInputField
              autoComplete="off"
              control={form.control}
              description={`Only needed if the application isn't marked "public"/PKCE-only.`}
              label="OAuth application client secret (optional)"
              name="oauthClientSecret"
              type="password"
            />
          </>
        )}

        {authKind === "pat" && (
          <div className="rounded-lg border border-dashed border-border p-4 space-y-4">
            <p className="text-xs text-muted-foreground">
              Optional — also register an OAuth application so members can personally connect
              their own GitLab accounts, even though this connection itself uses a token.
            </p>
            <FormInputField
              control={form.control}
              label="OAuth application client ID (optional)"
              name="oauthClientId"
            />
            <FormInputField
              autoComplete="off"
              control={form.control}
              label="OAuth application client secret (optional)"
              name="oauthClientSecret"
              type="password"
            />
          </div>
        )}

        <div className="flex gap-2">
          <Button disabled={form.formState.isSubmitting} type="submit">
            {form.formState.isSubmitting ? "Connecting…" : "Connect"}
          </Button>
          <Button type="button" variant="outline" onClick={onDone}>
            Cancel
          </Button>
        </div>
      </form>
    </Form>
  );
}
