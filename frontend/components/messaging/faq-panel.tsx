import { HelpCircle } from "lucide-react";
import type { CourseFAQ } from "@/lib/server/messaging";

interface FAQPanelProps {
  faqs: CourseFAQ[];
}

export function FAQPanel({ faqs }: FAQPanelProps) {
  if (faqs.length === 0) {
    return (
      <div className="empty-state py-10">
        <HelpCircle aria-hidden className="h-8 w-8 text-muted-foreground" />
        <p className="mt-2 text-sm text-muted-foreground">No FAQs yet for this course.</p>
      </div>
    );
  }

  return (
    <section aria-label="Frequently asked questions">
      <h2 className="section-title mb-4">Frequently Asked Questions</h2>
      <dl className="flex flex-col gap-4">
        {faqs.map((faq) => (
          <div key={faq.id} className="card-base p-5">
            <dt className="flex items-start gap-2 font-medium">
              {faq.ai_generated && (
                <span className="ai-badge mt-0.5 shrink-0">AI</span>
              )}
              {faq.question}
            </dt>
            <dd className="mt-2 text-sm leading-relaxed text-muted-foreground">{faq.answer}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
