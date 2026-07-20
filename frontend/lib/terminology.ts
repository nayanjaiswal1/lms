import { ORG_TYPE, type OrgType } from "@/lib/constants";

// ─────────────────────────────────────────────
// Org-level display wording. "default" reproduces the app's existing
// copy exactly, so an org with no org_type set sees no visual change.
// ─────────────────────────────────────────────

export interface Terminology {
  teacher:        string;
  teacherPlural:  string;
  class_:         string;
  classPlural:    string;
  student:        string;
  studentPlural:  string;
}

const DEFAULT_TERMINOLOGY: Terminology = {
  teacher:       "Mentor",
  teacherPlural: "Mentors",
  class_:        "Batch",
  classPlural:   "Batches",
  student:       "Student",
  studentPlural: "Students",
};

export const TERMINOLOGY_BY_ORG_TYPE: Record<OrgType, Terminology> = {
  [ORG_TYPE.SCHOOL]: {
    teacher: "Teacher", teacherPlural: "Teachers",
    class_: "Class", classPlural: "Classes",
    student: "Student", studentPlural: "Students",
  },
  [ORG_TYPE.COLLEGE]: {
    teacher: "Professor", teacherPlural: "Professors",
    class_: "Class", classPlural: "Classes",
    student: "Student", studentPlural: "Students",
  },
  [ORG_TYPE.UNIVERSITY]: {
    teacher: "Faculty", teacherPlural: "Faculty",
    class_: "Section", classPlural: "Sections",
    student: "Student", studentPlural: "Students",
  },
  [ORG_TYPE.BOOTCAMP]: {
    teacher: "Mentor", teacherPlural: "Mentors",
    class_: "Cohort", classPlural: "Cohorts",
    student: "Learner", studentPlural: "Learners",
  },
  [ORG_TYPE.CORPORATE]: {
    teacher: "Trainer", teacherPlural: "Trainers",
    class_: "Team", classPlural: "Teams",
    student: "Employee", studentPlural: "Employees",
  },
};

export function resolveTerminology(orgType: string | null | undefined): Terminology {
  if (orgType && orgType in TERMINOLOGY_BY_ORG_TYPE) {
    return TERMINOLOGY_BY_ORG_TYPE[orgType as OrgType];
  }
  return DEFAULT_TERMINOLOGY;
}
