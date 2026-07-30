// ponytail: exists only so server actions can `revalidatePath(ROUTES.INTERVIEW_EXP, "layout")`
// and refresh whichever /interview-exp/[id] page is currently mounted, not just the list.
export default function InterviewExpLayout({ children }: { children: React.ReactNode }) {
  return children;
}
