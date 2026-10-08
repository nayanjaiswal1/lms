"use client";

import { parseAsInteger, useQueryStates } from "nuqs";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import {
  ANALYTICS_DEFAULT_DAYS,
  ANALYTICS_TREND_DAY_OPTIONS,
  AT_RISK_DEFAULT_INACTIVE_DAYS,
  AT_RISK_DEFAULT_PROGRESS_PCT,
  AT_RISK_INACTIVE_DAY_OPTIONS,
  AT_RISK_PROGRESS_OPTIONS,
} from "@/lib/constants";

interface FilterOption {
  label: string;
  value: number;
}

interface FilterSelectProps {
  label: string;
  value: number;
  options: readonly FilterOption[];
  onChange: (v: number) => void;
}

function FilterSelect({ label, value, options, onChange }: FilterSelectProps) {
  return (
    <Select value={String(value)} onValueChange={(v) => onChange(Number(v))}>
      <SelectTrigger aria-label={label} className="w-full sm:w-[180px]"><SelectValue /></SelectTrigger>
      <SelectContent>
        {options.map((o) => <SelectItem key={o.value} value={String(o.value)}>{o.label}</SelectItem>)}
      </SelectContent>
    </Select>
  );
}

/** URL-driven filters; the analytics page server component re-reads the params. */
export function AnalyticsFilters() {
  const [f, setF] = useQueryStates(
    {
      days: parseAsInteger.withDefault(ANALYTICS_DEFAULT_DAYS),
      inactive_days: parseAsInteger.withDefault(AT_RISK_DEFAULT_INACTIVE_DAYS),
      max_progress_pct: parseAsInteger.withDefault(AT_RISK_DEFAULT_PROGRESS_PCT),
    },
    { shallow: false },
  );
  return (
    <div className="flex flex-wrap items-center gap-2">
      <FilterSelect label="Enrollment period" options={ANALYTICS_TREND_DAY_OPTIONS} value={f.days} onChange={(v) => void setF({ days: v })} />
      <FilterSelect label="Inactivity threshold" options={AT_RISK_INACTIVE_DAY_OPTIONS} value={f.inactive_days} onChange={(v) => void setF({ inactive_days: v })} />
      <FilterSelect label="Progress threshold" options={AT_RISK_PROGRESS_OPTIONS} value={f.max_progress_pct} onChange={(v) => void setF({ max_progress_pct: v })} />
    </div>
  );
}
