export interface Profile {
  user_id: string
  name: string
  avatar_url: string | null
  email: string
  display_name: string | null
  bio: string | null
  profile_slug: string | null
  public_enabled: boolean
  show_skills: boolean
  show_achievements: boolean
  show_certificates: boolean
  show_activity: boolean
  experience_level: string | null
  learning_goal: string | null
  topics_interest: string[]
  weekly_time_commitment: string | null
  preferred_learning_style: string | null
  current_role: string | null
  years_of_experience: number | null
  language: string | null
  timezone: string | null
  weekly_goal_hrs: number | null
  notifications: Record<string, boolean>
  completion_score: number
  skills: Skill[]
  social_links: SocialLinks | null
  stats: Stats | null
  created_at: string
  updated_at: string
}

export interface Skill {
  id: string
  skill_name: string
  skill_level: 'beginner' | 'intermediate' | 'advanced'
  created_at: string
}

export interface SocialLinks {
  linkedin: string | null
  github: string | null
  portfolio: string | null
}

export interface Stats {
  courses_enrolled: number
  courses_completed: number
  tests_attempted: number
  tests_passed: number
  problems_solved: number
  certificates_earned: number
  current_streak_days: number
  learning_hours: number
  roadmaps_completed: number
}

export interface ResumeExtract {
  name?: string
  bio?: string
  current_role?: string
  years_of_experience?: number
  skills?: { skill_name: string; skill_level: 'beginner' | 'intermediate' | 'advanced' }[]
  social_links?: { linkedin?: string | null; github?: string | null; portfolio?: string | null }
}

export interface PublicProfile {
  name: string
  display_name: string | null
  avatar_url: string | null
  bio: string | null
  profile_slug: string
  experience_level: string | null
  current_role: string | null
  skills?: Skill[]
  social_links?: SocialLinks
  stats?: Stats
}
