"use client";

import { useRef, useState, useTransition } from "react";
import { toast } from "sonner";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { updateOrgBrandingAction, uploadOrgLogoAction } from "@/app/org/settings/actions";

interface OrgBrandingCardProps {
  orgId: string;
  orgName: string;
  logoUrl: string | null;
}

export function OrgBrandingCard({ orgId, orgName, logoUrl }: OrgBrandingCardProps) {
  const [name, setName] = useState(orgName);
  const [logo, setLogo] = useState(logoUrl);
  const [isPending, startTransition] = useTransition();
  const [isUploading, setIsUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const dirty = name !== orgName || logo !== logoUrl;

  async function onFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    setIsUploading(true);
    const fd = new FormData();
    fd.append("file", file);
    const res = await uploadOrgLogoAction(fd);
    setIsUploading(false);
    if (res.error || !res.data) {
      toast.error(res.error ?? "Logo upload failed.");
      return;
    }
    setLogo(res.data.url);
  }

  function onSave() {
    const trimmed = name.trim();
    if (trimmed.length < 2 || trimmed.length > 100) {
      toast.error("Name must be between 2 and 100 characters.");
      return;
    }
    startTransition(async () => {
      const res = await updateOrgBrandingAction(orgId, { name: trimmed, logo_url: logo });
      if (res.error) {
        toast.error(res.error);
        return;
      }
      toast.success("Branding saved.");
    });
  }

  return (
    <div className="card-base p-6">
      <h3 className="text-base font-semibold text-foreground">Branding</h3>
      <p className="text-sm text-muted-foreground mt-0.5 mb-4">
        Replaces the MindForge name and logo everywhere your members see the product —
        sidebar, login, and every page.
      </p>
      <div className="flex flex-col gap-4">
        <div className="flex items-center gap-4">
          <div className="flex-center h-14 w-14 shrink-0 rounded-lg border border-border bg-muted overflow-hidden">
            {logo ? (
              /* eslint-disable-next-line @next/next/no-img-element -- org-uploaded logo from an arbitrary media host, same pattern as the read view above */
              <img alt="Logo preview" className="h-full w-full object-contain" src={logo} />
            ) : (
              <span className="text-xs text-muted-foreground">No logo</span>
            )}
          </div>
          <div className="flex flex-col gap-1.5">
            <input
              accept="image/png,image/jpeg,image/svg+xml,image/webp"
              className="hidden"
              ref={fileInputRef}
              type="file"
              onChange={onFileChange}
            />
            <Button
              disabled={isUploading}
              size="sm"
              type="button"
              variant="outline"
              onClick={() => fileInputRef.current?.click()}
            >
              {isUploading ? "Uploading…" : "Upload logo"}
            </Button>
            {logo && (
              <Button
                className="text-muted-foreground"
                size="sm"
                type="button"
                variant="ghost"
                onClick={() => setLogo(null)}
              >
                Remove logo
              </Button>
            )}
          </div>
        </div>

        <div className="max-w-sm space-y-1.5">
          <Label htmlFor="org-brand-name">Product name</Label>
          <Input
            id="org-brand-name"
            maxLength={100}
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </div>

        <div>
          <Button disabled={isPending || isUploading || !dirty} type="button" onClick={onSave}>
            {isPending ? "Saving…" : "Save"}
          </Button>
        </div>
      </div>
    </div>
  );
}
