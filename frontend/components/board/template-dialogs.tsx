"use client";

import { useState, useTransition } from "react";
import { Plus, X } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import {
  createTemplateAction,
  instantiateTemplateAction,
  type TaskTemplate,
  type TemplateFieldKind,
} from "@/lib/server/whatnow";

interface TemplateControlsProps {
  templates: TaskTemplate[];
}

// Trigger row above the board: pick a saved template to fill in (creates one
// new task, the template itself never changes) or save a new one.
export function TemplateControls({ templates }: TemplateControlsProps) {
  const [activeTemplate, setActiveTemplate] = useState<TaskTemplate | null>(null);
  const [saveOpen, setSaveOpen] = useState(false);

  return (
    <div className="flex items-center gap-2">
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button size="sm" variant="outline">
            Use template
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start">
          {templates.length === 0 ? (
            <div className="px-2 py-1.5 text-sm text-muted-foreground">No templates saved yet.</div>
          ) : (
            templates.map((t) => (
              <DropdownMenuItem key={t.id} onSelect={() => setActiveTemplate(t)}>
                {t.name}
              </DropdownMenuItem>
            ))
          )}
        </DropdownMenuContent>
      </DropdownMenu>
      <Button size="sm" variant="outline" onClick={() => setSaveOpen(true)}>
        Save template
      </Button>

      {activeTemplate && (
        <TemplateFormDialog template={activeTemplate} onOpenChange={(open) => !open && setActiveTemplate(null)} />
      )}
      <TemplateSaveDialog open={saveOpen} onOpenChange={setSaveOpen} />
    </div>
  );
}

interface TemplateFormDialogProps {
  template: TaskTemplate;
  onOpenChange: (open: boolean) => void;
}

// Renders one input per saved field, fills them in, creates a new task —
// the saved template row itself is never mutated by this.
function TemplateFormDialog({ template, onOpenChange }: TemplateFormDialogProps) {
  const [values, setValues] = useState<Record<string, string>>({});
  const [, startTransition] = useTransition();

  function submit() {
    startTransition(async () => {
      await instantiateTemplateAction(template.id, values);
    });
    onOpenChange(false);
  }

  return (
    <Dialog open onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{template.name}</DialogTitle>
        </DialogHeader>
        <div className="flex flex-col gap-4">
          {template.fields.map((f) => (
            <div className="flex flex-col gap-1.5" key={f.id}>
              <Label htmlFor={`tpl-field-${f.id}`}>{f.label}</Label>
              {f.kind === "textarea" ? (
                <Textarea
                  id={`tpl-field-${f.id}`}
                  value={values[f.id] ?? ""}
                  onChange={(e) => setValues((v) => ({ ...v, [f.id]: e.target.value }))}
                />
              ) : (
                <Input
                  id={`tpl-field-${f.id}`}
                  value={values[f.id] ?? ""}
                  onChange={(e) => setValues((v) => ({ ...v, [f.id]: e.target.value }))}
                />
              )}
            </div>
          ))}
        </div>
        <DialogFooter>
          <Button onClick={submit}>Create task</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

interface DraftField {
  key: string;
  label: string;
  kind: TemplateFieldKind;
}

interface TemplateSaveDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

// The only place templates are authored: a name + a repeatable field-list
// editor (label + kind, add/remove row).
function TemplateSaveDialog({ open, onOpenChange }: TemplateSaveDialogProps) {
  const [name, setName] = useState("");
  const [fields, setFields] = useState<DraftField[]>([{ key: crypto.randomUUID(), label: "", kind: "text" }]);
  const [, startTransition] = useTransition();

  function addField() {
    setFields((f) => [...f, { key: crypto.randomUUID(), label: "", kind: "text" }]);
  }

  function removeField(key: string) {
    setFields((f) => f.filter((x) => x.key !== key));
  }

  function updateField(key: string, patch: Partial<DraftField>) {
    setFields((f) => f.map((x) => (x.key === key ? { ...x, ...patch } : x)));
  }

  function submit() {
    const cleanFields = fields.filter((f) => f.label.trim() !== "").map((f) => ({ label: f.label, kind: f.kind }));
    if (name.trim() === "" || cleanFields.length === 0) return;
    startTransition(async () => {
      await createTemplateAction(name, cleanFields);
    });
    setName("");
    setFields([{ key: crypto.randomUUID(), label: "", kind: "text" }]);
    onOpenChange(false);
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Save template</DialogTitle>
        </DialogHeader>
        <div className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="tpl-name">Name</Label>
            <Input id="tpl-name" placeholder="Stuck protocol" value={name} onChange={(e) => setName(e.target.value)} />
          </div>
          <div className="flex flex-col gap-2">
            <Label>Fields</Label>
            {fields.map((f) => (
              <div className="flex items-center gap-2" key={f.key}>
                <Input
                  placeholder="Question"
                  value={f.label}
                  onChange={(e) => updateField(f.key, { label: e.target.value })}
                />
                <Select value={f.kind} onValueChange={(v) => updateField(f.key, { kind: v as TemplateFieldKind })}>
                  <SelectTrigger className="w-32">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="text">Short text</SelectItem>
                    <SelectItem value="textarea">Long text</SelectItem>
                  </SelectContent>
                </Select>
                <Button
                  aria-label="Remove field"
                  disabled={fields.length === 1}
                  size="icon"
                  variant="ghost"
                  onClick={() => removeField(f.key)}
                >
                  <X aria-hidden className="h-4 w-4" />
                </Button>
              </div>
            ))}
            <Button className="self-start" size="sm" variant="outline" onClick={addField}>
              <Plus aria-hidden className="h-3.5 w-3.5" />
              Add field
            </Button>
          </div>
        </div>
        <DialogFooter>
          <Button onClick={submit}>Save</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
