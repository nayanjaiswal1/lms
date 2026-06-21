export const DEMO_LEARNER = {
  name: "Alex Chen",
  role: "Software Engineer",
  goal: "Get a promotion",
  streak: 7,
  weeklyGoalHrs: 5,
  hoursThisWeek: 3.5,
  skillsAcquired: ["JavaScript", "HTML & CSS", "Git", "Node.js"],
  path: {
    title: "Full-Stack Development",
    totalModules: 20,
    completedModules: 8,
    progressPct: 40,
    estimatedWeeks: 4,
  },
  currentModule: {
    title: "State & Effects",
    course: "React Fundamentals",
    moduleNumber: 3,
    totalModules: 8,
    progressPct: 65,
    minutesLeft: 18,
  },
  aiRecommendation:
    "Based on your promotion goal, TypeScript is the highest-impact next skill for a Software Engineer.",
  recentActivity: [
    { title: "JavaScript Arrays & Objects", completedAt: "Yesterday" },
    { title: "Async/Await Deep Dive",        completedAt: "2 days ago" },
    { title: "Git Branching Strategies",      completedAt: "3 days ago" },
  ],
};

export const DEMO_ORG = {
  name: "Acme Corp",
  totalMembers: 12,
  activeMembers: 9,
  avgCompletionPct: 67,
  overdueCount: 2,
  assignedPaths: 4,
};

export type MemberStatus = "completed" | "in_progress" | "overdue" | "not_started";

export interface TeamMember {
  name: string;
  role: string;
  department: string;
  course: string;
  progressPct: number;
  status: MemberStatus;
  isYou?: boolean;
}

export const DEMO_TEAM: TeamMember[] = [
  { name: "Alex Chen",    role: "Software Engineer", department: "Engineering", course: "Full-Stack Dev",          progressPct: 40,  status: "in_progress", isYou: true },
  { name: "Sarah Kim",    role: "UX Designer",       department: "Design",      course: "UX Design Fundamentals",  progressPct: 100, status: "completed" },
  { name: "James Park",   role: "DevOps Engineer",   department: "Engineering", course: "Cloud & AWS",             progressPct: 15,  status: "overdue" },
  { name: "Maria Garcia", role: "Product Manager",   department: "Product",     course: "Product Strategy",        progressPct: 80,  status: "in_progress" },
  { name: "David Liu",    role: "Software Engineer", department: "Engineering", course: "Full-Stack Dev",          progressPct: 60,  status: "in_progress" },
  { name: "Emma Wilson",  role: "Marketing Lead",    department: "Marketing",   course: "Digital Marketing",       progressPct: 0,   status: "not_started" },
  { name: "Ryan Chen",    role: "DevOps Engineer",   department: "Engineering", course: "Cloud & AWS",             progressPct: 0,   status: "overdue" },
  { name: "Priya Patel",  role: "Software Engineer", department: "Engineering", course: "Full-Stack Dev",          progressPct: 95,  status: "in_progress" },
];

export const DEMO_COMPLIANCE = [
  { title: "Security Awareness 2024",   dueInDays: 5,  completedCount: 8, totalCount: 12 },
  { title: "Data Privacy Fundamentals", dueInDays: 14, completedCount: 5, totalCount: 12 },
];
