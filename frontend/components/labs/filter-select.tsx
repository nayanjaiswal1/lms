import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import type { CatalogOption } from "@/lib/labs/kinds/catalog"

interface FilterSelectProps {
  allValue: string
  label: string
  allLabel: string
  value: string
  options: CatalogOption[]
  onChange: (value: string) => void
}

/** A labelled filter select whose first entry clears the filter (`allValue`). */
export function FilterSelect({ allValue, label, allLabel, value, options, onChange }: FilterSelectProps) {
  return (
    <Select value={value} onValueChange={onChange}>
      <SelectTrigger aria-label={label} className="w-full sm:w-44">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value={allValue}>{allLabel}</SelectItem>
        {options.map((o) => (
          <SelectItem key={o.value} value={o.value}>
            {o.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

