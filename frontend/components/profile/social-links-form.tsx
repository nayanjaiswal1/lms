import { Code2, Globe, Link2 } from "lucide-react"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { SettingsSection } from "@/components/profile/settings-section"
import { FormSaveFooter } from "@/components/profile/form-save-footer"
import type { SocialLinks } from "@/lib/profile/types"

interface Props {
  socialLinks: SocialLinks | null
  updateAction: (formData: FormData) => Promise<void>
}

interface SocialFieldProps {
  id: string
  name: string
  label: string
  placeholder: string
  defaultValue: string | null | undefined
  icon: React.ReactNode
}

function SocialField({
  id,
  name,
  label,
  placeholder,
  defaultValue,
  icon,
}: SocialFieldProps) {
  return (
    <div className="space-y-1.5">
      <Label htmlFor={id}>{label}</Label>
      <div className="relative flex items-center">
        <span
          aria-hidden="true"
          className="pointer-events-none absolute left-3 flex items-center text-muted-foreground"
        >
          {icon}
        </span>
        <Input
          autoComplete="url"
          className="pl-9"
          defaultValue={defaultValue ?? ""}
          id={id}
          inputMode="url"
          name={name}
          placeholder={placeholder}
          type="url"
        />
      </div>
    </div>
  )
}

export function SocialLinksForm({ socialLinks, updateAction }: Props) {
  return (
    <SettingsSection
      description="Shown on your public profile. Paste full URLs, starting with https://."
      id="social-links"
      title="Social links"
    >
      <form action={updateAction} className="form-stack">
        <div className="form-row">
          <SocialField
            defaultValue={socialLinks?.linkedin}
            icon={<Link2 size={16} />}
            id="linkedin-url"
            label="LinkedIn"
            name="linkedin"
            placeholder="https://linkedin.com/in/username"
          />

          <SocialField
            defaultValue={socialLinks?.github}
            icon={<Code2 size={16} />}
            id="github-url"
            label="GitHub"
            name="github"
            placeholder="https://github.com/username"
          />
        </div>

        <SocialField
          defaultValue={socialLinks?.portfolio}
          icon={<Globe size={16} />}
          id="portfolio-url"
          label="Portfolio"
          name="portfolio"
          placeholder="https://yourwebsite.com"
        />

        <FormSaveFooter hint="Clear a field to remove that link." label="Save links" />
      </form>
    </SettingsSection>
  )
}
