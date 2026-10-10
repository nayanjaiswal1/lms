import { useId } from "react"
import { Label } from "@/components/ui/label"
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
  const id = useId()
  return (
    <div className="flex flex-col gap-1.5">
      <Label className="text-xs text-muted-foreground" htmlFor={id}>
        {label}
      </Label>
      <Select value={value} onValueChange={onChange}>
      <SelectTrigger className="w-full sm:w-48" id={id}>
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
    </div>
  )
}
