"use server"

import Anthropic from '@anthropic-ai/sdk'
import { revalidatePath } from 'next/cache'
import { authHeaders, baseURL } from '@/lib/server/api'
import type { ResumeExtract } from '@/lib/profile/types'

async function patchProfile(
  body: Record<string, unknown>
): Promise<{ error?: string; success?: boolean }> {
  const headers = await authHeaders()
  try {
    const res = await fetch(`${baseURL()}/api/profile/me`, {
      method: 'PATCH',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      cache: 'no-store',
    })
    if (!res.ok) {
      const json = await res.json().catch(() => ({}))
      return { error: (json as { error?: string }).error ?? 'Failed to save.' }
    }
    return { success: true }
  } catch {
    return { error: 'Network error. Please try again.' }
  }
}

export async function updateBasicInfoAction(
  formData: FormData
): Promise<void> {
  const yearsRaw = formData.get('years_of_experience')
  const result = await patchProfile({
    name: formData.get('name'),
    display_name: formData.get('display_name') || null,
    bio: formData.get('bio') || null,
    current_role: formData.get('current_role') || null,
    years_of_experience: yearsRaw ? Number(yearsRaw) : null,
  })
  if (result.success) revalidatePath('/settings/profile')
}

export async function updateLearningAction(
  formData: FormData
): Promise<void> {
  const topics = formData.getAll('topics_interest[]') as string[]
  const result = await patchProfile({
    experience_level: formData.get('experience_level') || null,
    learning_goal: formData.get('learning_goal') || null,
    preferred_learning_style: formData.get('preferred_learning_style') || null,
    weekly_time_commitment: formData.get('weekly_time_commitment') || null,
    topics_interest: topics,
  })
  if (result.success) revalidatePath('/settings/profile')
}

export async function updatePrivacyAction(
  formData: FormData
): Promise<void> {
  const toBool = (v: FormDataEntryValue | null) => v === 'on'
  const result = await patchProfile({
    public_enabled: toBool(formData.get('public_enabled')),
    show_skills: toBool(formData.get('show_skills')),
    show_achievements: toBool(formData.get('show_achievements')),
    show_certificates: toBool(formData.get('show_certificates')),
    show_activity: toBool(formData.get('show_activity')),
  })
  if (result.success) revalidatePath('/settings/profile')
}

export async function updateSocialLinksAction(
  formData: FormData
): Promise<void> {
  const result = await patchProfile({
    social_links: {
      linkedin: formData.get('linkedin') || null,
      github: formData.get('github') || null,
      portfolio: formData.get('portfolio') || null,
    },
  })
  if (result.success) revalidatePath('/settings/profile')
}

export async function updatePreferencesAction(
  formData: FormData
): Promise<void> {
  const weeklyRaw = formData.get('weekly_goal_hrs')
  const result = await patchProfile({
    timezone: formData.get('timezone') || null,
    language: formData.get('language') || null,
    weekly_goal_hrs: weeklyRaw ? Number(weeklyRaw) : null,
    notifications: {
      email: ['on', 'true'].includes(formData.get('email_notifications') as string),
      push: ['on', 'true'].includes(formData.get('push_notifications') as string),
    },
  })
  if (result.success) revalidatePath('/settings/profile')
}

export async function addSkillAction(
  _prev: unknown,
  formData: FormData
): Promise<{ error?: string; success?: boolean }> {
  const headers = await authHeaders()
  try {
    const res = await fetch(`${baseURL()}/api/profile/me/skills`, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        skill_name: formData.get('skill_name'),
        skill_level: formData.get('skill_level'),
      }),
      cache: 'no-store',
    })
    if (!res.ok) {
      const json = await res.json().catch(() => ({}))
      return { error: (json as { error?: string }).error ?? 'Failed to add skill.' }
    }
    revalidatePath('/settings/profile')
    return { success: true }
  } catch {
    return { error: 'Network error. Please try again.' }
  }
}

export async function removeSkillAction(
  skillId: string
): Promise<{ error?: string }> {
  const headers = await authHeaders()
  try {
    const res = await fetch(`${baseURL()}/api/profile/me/skills/${skillId}`, {
      method: 'DELETE',
      headers,
      cache: 'no-store',
    })
    if (!res.ok) {
      const json = await res.json().catch(() => ({}))
      return { error: (json as { error?: string }).error ?? 'Failed to remove skill.' }
    }
    revalidatePath('/settings/profile')
    return {}
  } catch {
    return { error: 'Network error. Please try again.' }
  }
}

export async function parseResumeAction(
  _prev: unknown,
  formData: FormData
): Promise<{ data?: ResumeExtract; error?: string }> {
  const file = formData.get('resume') as File | null
  if (!file) return { error: 'No file provided.' }
  if (file.type !== 'application/pdf') return { error: 'File must be a PDF.' }
  if (file.size > 5 * 1024 * 1024) return { error: 'File must be under 5 MB.' }

  const bytes = await file.arrayBuffer()
  const base64 = Buffer.from(bytes).toString('base64')

  const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY })

  try {
    const stream = anthropic.messages.stream({
      model: 'claude-opus-4-8',
      max_tokens: 2048,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'document',
              source: { type: 'base64', media_type: 'application/pdf', data: base64 },
            },
            {
              type: 'text',
              text: `Extract the following from this resume as a JSON object (omit any fields not found):
{
  "name": string,
  "bio": string (2-3 sentence professional summary),
  "current_role": string,
  "years_of_experience": number,
  "skills": [{"skill_name": string, "skill_level": "beginner"|"intermediate"|"advanced"}] (max 10, most relevant),
  "social_links": {"linkedin": string|null, "github": string|null, "portfolio": string|null}
}
Respond with ONLY the JSON object — no markdown fences, no explanation.`,
            },
          ],
        },
      ],
    })

    const msg = await stream.finalMessage()
    const text = msg.content[0]?.type === 'text' ? msg.content[0].text.trim() : ''
    const data = JSON.parse(text) as ResumeExtract
    return { data }
  } catch {
    return { error: 'Failed to parse resume. Please try again.' }
  }
}

export async function applyResumeAction(
  _prev: unknown,
  formData: FormData
): Promise<{ error?: string; success?: boolean }> {
  const raw = formData.get('extract') as string | null
  if (!raw) return { error: 'No extracted data provided.' }

  let extract: ResumeExtract
  try {
    extract = JSON.parse(raw) as ResumeExtract
  } catch {
    return { error: 'Invalid data. Please parse the resume again.' }
  }

  const profileFields: Record<string, unknown> = {}
  if (extract.name) profileFields.name = extract.name
  if (extract.bio) profileFields.bio = extract.bio
  if (extract.current_role) profileFields.current_role = extract.current_role
  if (extract.years_of_experience !== undefined)
    profileFields.years_of_experience = extract.years_of_experience
  if (extract.social_links) profileFields.social_links = extract.social_links

  if (Object.keys(profileFields).length > 0) {
    const profileResult = await patchProfile(profileFields)
    if (profileResult.error) return profileResult
  }

  if (extract.skills?.length) {
    const headers = await authHeaders()
    for (const skill of extract.skills) {
      try {
        await fetch(`${baseURL()}/api/profile/me/skills`, {
          method: 'POST',
          headers: { ...headers, 'Content-Type': 'application/json' },
          body: JSON.stringify(skill),
          cache: 'no-store',
        })
      } catch {
        // best-effort — partial skill failures don't abort the apply
      }
    }
  }

  revalidatePath('/settings/profile')
  return { success: true }
}

export async function uploadAvatarAction(
  formData: FormData
): Promise<void> {
  const file = formData.get('avatar') as File | null
  if (!file) return

  const headers = await authHeaders()
  // Remove Content-Type so the browser/fetch sets the multipart boundary
  const { 'Content-Type': _ct, ...headersWithoutContentType } = headers

  const body = new FormData()
  body.append('avatar', file)

  try {
    const res = await fetch(`${baseURL()}/api/profile/me/avatar`, {
      method: 'POST',
      headers: headersWithoutContentType,
      body,
      cache: 'no-store',
    })
    if (!res.ok) {
      console.error('Failed to upload avatar:', res.status)
      return
    }
    revalidatePath('/settings/profile')
  } catch (err) {
    console.error('Avatar upload network error:', err)
  }
}
