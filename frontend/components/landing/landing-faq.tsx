import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Reveal } from "@/components/landing/landing-motion";

const FAQS = [
  {
    question: "Is MindForge free to use?",
    answer:
      "Everything is included for free while we're in beta. Pro and Enterprise plans are coming for teams that need more seats and support — nothing changes for you until then.",
  },
  {
    question: "Can my college, bootcamp, or company use this?",
    answer:
      "Yes. Create an organization to get your own tenant with member invites, role-based access (admin, instructor, mentor, student), and a shared course library. MindForge is self-hosted, so your data stays yours.",
  },
  {
    question: "Do I need an organization to start learning?",
    answer:
      "No. You can register as an individual, enroll in free or paid courses, and use labs, mentoring, and review tools entirely on your own.",
  },
  {
    question: "Can I run assessments or interviews without asking candidates to sign up?",
    answer:
      "Yes — anonymous tests and public shareable links let anyone attempt a coding problem or quiz without an account, useful for screening or open practice.",
  },
] as const;

export function LandingFaq() {
  return (
    <section
      aria-labelledby="faq-heading"
      className="scroll-mt-16 border-b border-border bg-muted/30 py-16 sm:py-24"
      id="faq"
    >
      <div className="page-container-sm">
        <Reveal>
          <h2 className="text-center text-2xl font-bold sm:text-3xl" id="faq-heading">
            Frequently asked
          </h2>
        </Reveal>

        <Reveal className="mt-8" delay={0.08}>
          <Accordion collapsible type="single">
            {FAQS.map(({ question, answer }) => (
              <AccordionItem key={question} value={question}>
                <AccordionTrigger className="py-4 text-base normal-case tracking-normal text-foreground">
                  {question}
                </AccordionTrigger>
                <AccordionContent className="text-muted-foreground">{answer}</AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        </Reveal>
      </div>
    </section>
  );
}
