import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Reveal } from "@/components/landing/landing-motion";

export interface FaqItem {
  question: string;
  answer: string;
}

interface LandingFaqProps {
  faqs: FaqItem[];
}

export function LandingFaq({ faqs }: LandingFaqProps) {
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
            {faqs.map(({ question, answer }) => (
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
