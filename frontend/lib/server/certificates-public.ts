import { cache } from "react";
import "server-only";

import { apiGetPublic } from "@/lib/server/api";

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

export const getPublicCertificate = cache(async (certUuid: string): Promise<PublicCertificate> => {
  return apiGetPublic<PublicCertificate>(`/api/certificates/${certUuid}`, { revalidate: 60 });
});
