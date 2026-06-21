import { ExternalLink, Globe, Link2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
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
          className="absolute left-3 flex items-center text-muted-foreground pointer-events-none"
        >
          {icon}
        </span>
        <Input
          className="pl-9 pr-3 py-2.5"
          defaultValue={defaultValue ?? ""}
          id={id}
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
    <section aria-label="Social links" className="card-base p-6">
      <h2 className="section-title text-lg mb-6">Social Links</h2>

      <form action={updateAction} className="form-stack">
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
          icon={<ExternalLink size={16} />}
          id="github-url"
          label="GitHub"
          name="github"
          placeholder="https://github.com/username"
        />

        <SocialField
          defaultValue={socialLinks?.portfolio}
          icon={<Globe size={16} />}
          id="portfolio-url"
          label="Portfolio"
          name="portfolio"
          placeholder="https://yourwebsite.com"
        />

        <div className="pt-2">
          <Button className="px-5 py-2.5" type="submit">
            Save Social Links
          </Button>
        </div>
      </form>
    </section>
  )
}
