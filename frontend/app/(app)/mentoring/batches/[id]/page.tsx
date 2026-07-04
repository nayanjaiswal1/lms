import { redirect } from "next/navigation";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
}

export default async function MentorBatchDetailPage({ params }: Props) {
  const { id } = await params;
  redirect(ROUTES.mentoringBatchMembers(id));
}
