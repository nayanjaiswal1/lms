"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { parseAsBoolean, useQueryState } from "nuqs";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { requestMentorAction } from "@/lib/mentoring/actions";

const RequestMentorSchema = z.object({
  course_id: z.string().min(1, "Please choose a course."),
});
type RequestMentorFormData = z.infer<typeof RequestMentorSchema>;

interface Props {
  enrollments: { id: string; title: string }[];
}

export function RequestMentorDialog({ enrollments }: Props) {
  const [open, setOpen] = useQueryState("request-mentor", parseAsBoolean.withDefault(false));
  const router = useRouter();
  const form = useForm<RequestMentorFormData>({
    resolver: zodResolver(RequestMentorSchema),
    defaultValues: { course_id: enrollments.length === 1 ? enrollments[0].id : "" },
  });

  if (enrollments.length === 0) return null;

  async function onSubmit(data: RequestMentorFormData) {
    const result = await requestMentorAction(data.course_id);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Mentor request submitted.");
    void setOpen(null);
    router.refresh();
  }

  return (
    <Dialog open={open} onOpenChange={(next) => void setOpen(next || null)}>
      <DialogTrigger asChild>
        <Button size="sm">Request a mentor</Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Request a mentor</DialogTitle>
          <DialogDescription>
            We&apos;ll match you with an available mentor for the course you pick below.
          </DialogDescription>
        </DialogHeader>

        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            {enrollments.length > 1 && (
              <FormField
                control={form.control}
                name="course_id"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Course</FormLabel>
                    <FormControl>
                      <Select value={field.value} onValueChange={field.onChange}>
                        <SelectTrigger aria-label="Course">
                          <SelectValue placeholder="Choose a course" />
                        </SelectTrigger>
                        <SelectContent>
                          {enrollments.map((e) => (
                            <SelectItem key={e.id} value={e.id}>
                              {e.title}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            )}
            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Requesting…" : "Submit request"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
