import { cache } from "react";
import "server-only";

export interface PublicCertificate {
  id: string;
  user_id: string;
  course_id: string;
  final_test_attempt_id: string | null;
  issued_at: string;
  cert_uuid: string;
  course_title: string;
  learner_name: string;
}

function publicBase(): string {
  const url = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!url) throw new Error("BACKEND_URL is not configured");
  return url;
}

export const getPublicCertificate = cache(async (certUuid: string): Promise<PublicCertificate> => {
  const res = await fetch(`${publicBase()}/api/certificates/${certUuid}`, { cache: "no-store" });
  if (!res.ok) {
    const body = await res.json().catch(() => ({})) as { error?: string };
    throw new Error(body.error ?? "Certificate not found.");
  }
  const body = await res.json() as { data: PublicCertificate };
  return body.data;
});
