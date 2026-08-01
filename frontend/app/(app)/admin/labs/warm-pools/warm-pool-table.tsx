"use client";

import { useState } from "react";
import Link from "next/link";
import { useFieldArray, useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Pencil } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Form, FormControl, FormField, FormItem, FormMessage } from "@/components/ui/form";
import { WARM_POOL_MODE, WARM_POOL_MODE_OPTIONS } from "@/lib/constants";
import ROUTES from "@/lib/routes";
import { updateWarmPoolConfigAction } from "./actions";

export interface WarmPoolRowData {
  lab_id: string;
  title: string;
  lab_type: string;
  mode: string;
  fixed_size: number;
  max_size: number;
  ready: number;
  warming: number;
  claimed: number;
  target: number;
  decided_at: string | null;
}

const RowSchema = z.object({
  lab_id: z.string(),
  mode: z.enum([WARM_POOL_MODE.AUTO, WARM_POOL_MODE.FIXED, WARM_POOL_MODE.OFF]),
  fixed_size: z.coerce.number().int().min(0).max(20),
  max_size: z.coerce.number().int().min(0).max(20),
});
const Schema = z.object({ rows: z.array(RowSchema) });
type FormInput = z.input<typeof Schema>;
type FormData = z.output<typeof Schema>;

function ModeBadge({ mode }: { mode: string }) {
  if (mode === "fixed") return <Badge className="badge-info" variant="outline">Fixed</Badge>;
  if (mode === "off") return <Badge className="badge-muted" variant="outline">Off</Badge>;
  return <Badge className="badge-success" variant="outline">Auto</Badge>;
}

function PoolCell({ value, tone }: { value: number; tone: "success" | "warning" }) {
  const toneClass = value === 0 ? "text-muted-foreground" : tone === "success" ? "text-success" : "text-warning-foreground";
  return <span className={`font-semibold tabular-nums ${toneClass}`}>{value}</span>;
}

export function WarmPoolTable({ labs }: { labs: WarmPoolRowData[] }) {
  const [isEditing, setIsEditing] = useState(false);

  const form = useForm<FormInput, unknown, FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      rows: labs.map((lab) => ({
        lab_id: lab.lab_id,
        mode: lab.mode as FormInput["rows"][number]["mode"],
        fixed_size: lab.fixed_size,
        max_size: lab.max_size,
      })),
    },
  });
  const { fields } = useFieldArray({ control: form.control, name: "rows" });

  const onSubmit = async (data: FormData) => {
    const results = await Promise.all(
      data.rows.map((row) =>
        updateWarmPoolConfigAction(row.lab_id, {
          mode: row.mode,
          fixed_size: row.fixed_size,
          max_size: row.max_size,
        }),
      ),
    );
    const failed = results.filter((r) => r.error).length;
    if (failed > 0) {
      toast.error(`${failed} lab${failed === 1 ? "" : "s"} failed to save.`);
    } else {
      toast.success("Warm pool configs updated.");
    }
    setIsEditing(false);
  };

  if (labs.length === 0) {
    return (
      <div className="empty-state">
        <p className="font-medium text-foreground">No container-backed labs yet</p>
        <p className="text-sm text-muted-foreground mt-1">
          Publish a terminal, guided, playground, or sandbox lab to see it here — code labs
          never appear, they don&apos;t use a container.
        </p>
      </div>
    );
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        <div className="page-header">
          <div>
            <h1 className="page-title">Warm Pool Sizing</h1>
            <p className="text-muted-foreground mt-1 max-w-2xl">
              Container-backed labs only — code labs run through Piston and never need a
              sandbox. Idle rows (nothing warm, nothing targeted) are dimmed.
            </p>
            <Link
              className="text-sm text-primary underline underline-offset-2 mt-2 inline-block"
              href={ROUTES.ADMIN_LABS_USAGE}
            >
              View compute usage →
            </Link>
          </div>
          <div className="flex items-center gap-3">
            <Badge className="badge-muted" variant="outline">{labs.length} labs</Badge>
            {isEditing ? (
              <>
                <Button
                  type="button"
                  variant="ghost"
                  onClick={() => {
                    form.reset();
                    setIsEditing(false);
                  }}
                >
                  Cancel
                </Button>
                <Button disabled={form.formState.isSubmitting} type="submit">
                  {form.formState.isSubmitting ? "Saving…" : "Save all"}
                </Button>
              </>
            ) : (
              <Button type="button" variant="outline" onClick={() => setIsEditing(true)}>
                <Pencil className="size-4" />
                Edit
              </Button>
            )}
          </div>
        </div>

        <div className="mt-8 card-base table-responsive">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-muted-foreground">
                <th className="p-4 font-medium">Lab</th>
                <th className="p-4 font-medium">Mode</th>
                <th className="p-4 font-medium text-right">Fixed</th>
                <th className="p-4 font-medium text-right">Max</th>
                <th className="p-4 font-medium text-right">Ready</th>
                <th className="p-4 font-medium text-right">Warming</th>
                <th className="p-4 font-medium text-right">Claimed</th>
                <th className="p-4 font-medium text-right">Target</th>
                <th className="p-4 font-medium whitespace-nowrap">Decided</th>
              </tr>
            </thead>
            <tbody>
              {fields.map((field, index) => {
                const lab = labs[index];
                const isIdle = lab.mode === "auto" && lab.target === 0 && lab.ready === 0 && lab.warming === 0 && lab.claimed === 0;
                return (
                  <tr
                    className={`border-b border-border last:border-0 ${isIdle && !isEditing ? "opacity-60" : ""}`}
                    key={field.id}
                  >
                    <td className="p-4 max-w-64">
                      <div className="font-medium text-foreground truncate">{lab.title}</div>
                      <div className="text-xs text-muted-foreground capitalize">{lab.lab_type}</div>
                    </td>
                    <td className="p-4">
                      {isEditing ? (
                        <FormField
                          control={form.control}
                          name={`rows.${index}.mode`}
                          render={({ field: f }) => (
                            <FormItem>
                              <Select value={f.value} onValueChange={f.onChange}>
                                <FormControl>
                                  <SelectTrigger aria-label={`Mode for ${lab.title}`} className="h-9 w-36">
                                    <SelectValue />
                                  </SelectTrigger>
                                </FormControl>
                                <SelectContent>
                                  {WARM_POOL_MODE_OPTIONS.map((opt) => (
                                    <SelectItem key={opt.value} value={opt.value}>{opt.label}</SelectItem>
                                  ))}
                                </SelectContent>
                              </Select>
                              <FormMessage />
                            </FormItem>
                          )}
                        />
                      ) : (
                        <ModeBadge mode={lab.mode} />
                      )}
                    </td>
                    <td className="p-4 text-right">
                      {isEditing ? (
                        <FormField
                          control={form.control}
                          name={`rows.${index}.fixed_size`}
                          render={({ field: f }) => (
                            <FormItem>
                              <FormControl>
                                <Input
                                  aria-label={`Fixed size for ${lab.title}`}
                                  className="h-9 w-16 text-right"
                                  max={20}
                                  min={0}
                                  name={f.name}
                                  ref={f.ref}
                                  type="number"
                                  value={f.value as number}
                                  onBlur={f.onBlur}
                                  onChange={f.onChange}
                                />
                              </FormControl>
                              <FormMessage />
                            </FormItem>
                          )}
                        />
                      ) : (
                        <span className="tabular-nums text-muted-foreground">{lab.fixed_size}</span>
                      )}
                    </td>
                    <td className="p-4 text-right">
                      {isEditing ? (
                        <FormField
                          control={form.control}
                          name={`rows.${index}.max_size`}
                          render={({ field: f }) => (
                            <FormItem>
                              <FormControl>
                                <Input
                                  aria-label={`Max size for ${lab.title}`}
                                  className="h-9 w-16 text-right"
                                  max={20}
                                  min={0}
                                  name={f.name}
                                  ref={f.ref}
                                  type="number"
                                  value={f.value as number}
                                  onBlur={f.onBlur}
                                  onChange={f.onChange}
                                />
                              </FormControl>
                              <FormMessage />
                            </FormItem>
                          )}
                        />
                      ) : (
                        <span className="tabular-nums text-muted-foreground">{lab.max_size}</span>
                      )}
                    </td>
                    <td className="p-4 text-right"><PoolCell tone="success" value={lab.ready} /></td>
                    <td className="p-4 text-right"><PoolCell tone="warning" value={lab.warming} /></td>
                    <td className="p-4 text-right text-muted-foreground tabular-nums">{lab.claimed}</td>
                    <td className="p-4 text-right font-semibold text-primary tabular-nums">{lab.target}</td>
                    <td className="p-4 text-xs text-muted-foreground whitespace-nowrap">
                      {lab.decided_at ? new Date(lab.decided_at).toLocaleString() : "—"}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </form>
    </Form>
  );
}
