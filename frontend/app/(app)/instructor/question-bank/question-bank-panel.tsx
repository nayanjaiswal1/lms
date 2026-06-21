"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Plus, X } from "lucide-react";

import { Button } from "@/components/ui/button";
import { CreateQuestionForm } from "@/app/instructor/question-bank/create-question-form";

// QuestionBankPanel is the client island that toggles and hosts the create form,
// refreshing the server-rendered list on success.
export function QuestionBankPanel() {
  const router = useRouter();
  const [open, setOpen] = React.useState(false);

  if (!open) {
    return (
      <Button onClick={() => setOpen(true)}>
        <Plus /> New question
      </Button>
    );
  }

  return (
    <div className="card-raised flex flex-col gap-4 p-6">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold">New question</h2>
        <Button aria-label="Close" size="icon" variant="ghost" onClick={() => setOpen(false)}>
          <X />
        </Button>
      </div>
      <CreateQuestionForm
        onCreated={() => {
          setOpen(false);
          router.refresh();
        }}
      />
    </div>
  );
}
