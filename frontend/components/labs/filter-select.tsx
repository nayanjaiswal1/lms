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
  const shown = options.find((o) => o.value === value)?.label ?? allLabel
  return (
    <Select value={value} onValueChange={onChange}>
      <SelectTrigger aria-label={label} className="w-full sm:w-48">
        {/* Explicit label: the portaled items aren't mounted while closed, so the value would render blank. */}
        <SelectValue>{shown}</SelectValue>
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
