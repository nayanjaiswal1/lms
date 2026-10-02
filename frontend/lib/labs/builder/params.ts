import type { BlockManifest, ParamSchema } from "@/lib/labs/builder/types";

// Block params are a small JSON Schema subset (labauthor/params.go). The
// wizard edits each property as a string field; "" means "not set" (the
// block's default, or a variant axis when the property is randomizable).

export type ParamField =
  | { name: string; schema: ParamSchema; control: "number" | "text" | "markdown" | "json" }
  | { name: string; schema: ParamSchema; control: "choice"; choices: string[] };

export function paramFields(manifest: BlockManifest | null): ParamField[] {
  const props = manifest?.params?.properties ?? {};
  return Object.entries(props).map(([name, schema]): ParamField => {
    if (schema.enum) return { name, schema, control: "choice", choices: schema.enum.map(String) };
    switch (schema.type) {
      case "boolean":
        return { name, schema, control: "choice", choices: ["true", "false"] };
      case "integer":
      case "number":
        return { name, schema, control: "number" };
      case "array":
      case "object":
        return { name, schema, control: "json" };
      default:
        return { name, schema, control: schema["x-mf-use"] === "text" ? "markdown" : "text" };
    }
  });
}

export function isRandomizable(schema: ParamSchema): boolean {
  return schema.randomize !== undefined;
}

/** The values a randomizable parameter varies over. */
export function axisValues(schema: ParamSchema): (string | number | boolean)[] {
  const r = schema.randomize;
  if (!r) return [];
  if (r.choices) return r.choices;
  if (!r.range) return [];
  const out: number[] = [];
  const step = r.range.step ?? 1;
  for (let v = r.range.min; v <= r.range.max && out.length < 50; v += step) out.push(v);
  return out;
}

/** Stored value -> form string. */
export function toFieldString(field: ParamField, value: unknown): string {
  if (value === undefined || value === null) return "";
  if (field.control === "json") return JSON.stringify(value, null, 2);
  return String(value);
}

/** Form string -> stored value (undefined clears it). Throws on invalid input. */
export function fromFieldString(field: ParamField, raw: string): unknown {
  const s = raw.trim();
  if (s === "") return undefined;
  switch (field.control) {
    case "number": {
      const n = Number(s);
      if (!Number.isFinite(n) || (field.schema.type === "integer" && !Number.isInteger(n))) {
        throw new Error(field.schema.type === "integer" ? "Enter a whole number" : "Enter a number");
      }
      return n;
    }
    case "json":
      try {
        return JSON.parse(s) as unknown;
      } catch {
        throw new Error("Enter valid JSON");
      }
    case "choice":
      if (field.schema.type === "boolean") return s === "true";
      return field.schema.enum?.find((e) => String(e) === s) ?? s;
    default:
      return raw;
  }
}
