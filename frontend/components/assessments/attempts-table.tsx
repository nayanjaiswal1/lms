"use client";

import Link from "next/link";
import { useMemo } from "react";
import { ExternalLink, ShieldAlert } from "lucide-react";
import { parseAsBoolean, parseAsInteger, parseAsString, parseAsStringLiteral, useQueryState } from "nuqs";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { AttemptRow } from "@/lib/assessments/types";
import ROUTES from "@/lib/routes";

const RESULT_VALUES = ["all", "passed", "failed"] as const;
type ResultFilter = (typeof RESULT_VALUES)[number];

const STATUS_OPTIONS = [
  { value: "all", label: "All statuses" },
  { value: "submitted", label: "Submitted" },
  { value: "evaluating", label: "Evaluating" },
  { value: "evaluated", label: "Evaluated" },
  { value: "eval_failed", label: "Eval failed" },
  { value: "expired", label: "Expired" },
];

interface Props {
  attempts: AttemptRow[];
}

export function AttemptsTable({ attempts }: Props) {
  const [result, setResult] = useQueryState(
    "result",
    parseAsStringLiteral(RESULT_VALUES).withDefault("all"),
  );
  const [flagged, setFlagged] = useQueryState("flagged", parseAsBoolean.withDefault(false));
  const [status, setStatus] = useQueryState("status", parseAsString.withDefault("all"));
  const [scoreMin, setScoreMin] = useQueryState("score_min", parseAsInteger.withDefault(0));
  const [scoreMax, setScoreMax] = useQueryState("score_max", parseAsInteger.withDefault(100));

  const filtered = useMemo(
    () =>
      attempts.filter((a) => {
        if (result === "passed" && a.passed !== true) return false;
        if (result === "failed" && a.passed !== false) return false;
        if (flagged && a.flags === 0) return false;
        if (status !== "all" && a.status !== status) return false;
        if (a.percentage !== null) {
          if (a.percentage < scoreMin) return false;
          if (a.percentage > scoreMax) return false;
        }
        return true;
      }),
    [attempts, result, flagged, status, scoreMin, scoreMax],
  );

  return (
    <div className="flex flex-col gap-4">
      <div className="card-base flex flex-wrap items-end gap-4 p-4">
        <div className="flex flex-col gap-1.5">
          <Label className="text-xs text-muted-foreground">Result</Label>
          <Select value={result} onValueChange={(v) => setResult(v as ResultFilter)}>
            <SelectTrigger className="w-36">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All results</SelectItem>
              <SelectItem value="passed">Passed</SelectItem>
              <SelectItem value="failed">Failed</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="flex flex-col gap-1.5">
          <Label className="text-xs text-muted-foreground">Status</Label>
          <Select value={status} onValueChange={setStatus}>
            <SelectTrigger className="w-40">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {STATUS_OPTIONS.map((o) => (
                <SelectItem key={o.value} value={o.value}>
                  {o.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="flex flex-col gap-1.5">
          <Label className="text-xs text-muted-foreground">Score min %</Label>
          <Input
            className="w-24"
            max={100}
            min={0}
            type="number"
            value={String(scoreMin)}
            onChange={(e) => {
              const n = parseInt(e.target.value, 10);
              if (!Number.isNaN(n)) void setScoreMin(Math.min(100, Math.max(0, n)));
            }}
          />
        </div>

        <div className="flex flex-col gap-1.5">
          <Label className="text-xs text-muted-foreground">Score max %</Label>
          <Input
            className="w-24"
            max={100}
            min={0}
            type="number"
            value={String(scoreMax)}
            onChange={(e) => {
              const n = parseInt(e.target.value, 10);
              if (!Number.isNaN(n)) void setScoreMax(Math.min(100, Math.max(0, n)));
            }}
          />
        </div>

        <Button
          className="self-end"
          size="sm"
          variant={flagged ? "default" : "outline"}
          onClick={() => void setFlagged(!flagged)}
        >
          <ShieldAlert className="mr-1.5 h-4 w-4" />
          Has violations
        </Button>

        <p className="ml-auto self-end text-sm text-muted-foreground">
          {filtered.length} / {attempts.length}
        </p>
      </div>

      {filtered.length === 0 ? (
        <p className="py-4 text-sm text-muted-foreground">No attempts match the current filters.</p>
      ) : (
        <div className="table-responsive">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-muted-foreground">
                <th className="py-3 pr-4 font-medium">Student</th>
                <th className="py-3 pr-4 font-medium">#</th>
                <th className="py-3 pr-4 font-medium">Status</th>
                <th className="py-3 pr-4 font-medium">Score</th>
                <th className="py-3 pr-4 font-medium">Result</th>
                <th className="py-3 pr-4 font-medium">Duration</th>
                <th className="py-3 pr-4 font-medium">Violations</th>
                <th className="py-3 font-medium">
                  <span className="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((a) => (
                <tr className="border-b border-border/60" key={a.id}>
                  <td className="py-3 pr-4">
                    <p className="font-medium">{a.user_name}</p>
                    <p className="text-xs text-muted-foreground">{a.user_email}</p>
                  </td>
                  <td className="py-3 pr-4 tabular-nums text-muted-foreground">
                    {a.attempt_number}
                  </td>
                  <td className="py-3 pr-4 capitalize text-muted-foreground">
                    {a.status.replace(/_/g, " ")}
                  </td>
                  <td className="py-3 pr-4 tabular-nums font-medium">
                    {a.percentage !== null ? `${Math.round(a.percentage)}%` : "—"}
                  </td>
                  <td className="py-3 pr-4">
                    {a.passed === null ? (
                      <span className="text-muted-foreground">—</span>
                    ) : (
                      <Badge variant={a.passed ? "default" : "destructive"}>
                        {a.passed ? "Passed" : "Failed"}
                      </Badge>
                    )}
                  </td>
                  <td className="py-3 pr-4 tabular-nums text-muted-foreground">
                    {a.duration_sec < 60
                      ? `${a.duration_sec}s`
                      : `${Math.round(a.duration_sec / 60)}m`}
                  </td>
                  <td className="py-3 pr-4">
                    {a.flags > 0 ? (
                      <Badge className="gap-1" variant="destructive">
                        <ShieldAlert className="h-3 w-3" />
                        {a.flags}
                      </Badge>
                    ) : (
                      <span className="text-muted-foreground">—</span>
                    )}
                  </td>
                  <td className="py-3">
                    <Link
                      aria-label="View proctoring log"
                      className="text-muted-foreground hover:text-foreground"
                      href={ROUTES.attemptProctoring(a.id)}
                    >
                      <ExternalLink className="h-4 w-4" />
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
