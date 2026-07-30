import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Award, CalendarCheck2, ShieldCheck } from "lucide-react";
import { getPublicCertificate } from "@/lib/server/certificates-public";
import { CertificateActions } from "@/components/certificates/certificate-actions";

interface PageProps {
  params: Promise<{ uuid: string }>;
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { uuid } = await params;
  try {
    const cert = await getPublicCertificate(uuid);
    return { title: `${cert.course_title} — Certificate` };
  } catch {
    return { title: "Certificate" };
  }
}

export default async function CertificateVerifyPage({ params }: PageProps) {
  const { uuid } = await params;
  let cert;
  try {
    cert = await getPublicCertificate(uuid);
  } catch {
    notFound();
  }

  return (
    <main className="page-container-sm flex min-h-dvh flex-col items-center justify-center gap-8 py-16">
      <div className="card-raised flex w-full flex-col items-center gap-6 p-10 text-center">
        <div className="flex-center h-16 w-16 rounded-full bg-primary/10">
          <Award aria-hidden className="h-8 w-8 text-primary" />
        </div>

        <div className="flex flex-col gap-2">
          <p className="text-sm font-medium uppercase tracking-wide text-muted-foreground">Certificate of Completion</p>
          <h1 className="page-title">{cert.course_title}</h1>
          <p className="text-lg text-muted-foreground">Awarded to {cert.learner_name}</p>
        </div>

        <div className="flex flex-col gap-2 border-t border-border pt-6 text-sm text-muted-foreground">
          <p className="flex items-center justify-center gap-2">
            <CalendarCheck2 aria-hidden className="h-4 w-4" />
            Issued {new Date(cert.issued_at).toLocaleDateString(undefined, { year: "numeric", month: "long", day: "numeric" })}
          </p>
          <p className="flex items-center justify-center gap-2 text-success">
            <ShieldCheck aria-hidden className="h-4 w-4" />
            Verified certificate
          </p>
        </div>

        <p className="font-mono text-xs text-muted-foreground">{cert.cert_uuid}</p>
      </div>

      <CertificateActions certUuid={cert.cert_uuid} />
    </main>
  );
}
