import { notFound } from 'next/navigation'
import type { Metadata } from 'next'
import { fetchPublicProfile } from '@/lib/server/profile'
import { PublicProfileCard } from '@/components/profile/public-profile-card'

interface PageProps {
  params: Promise<{ slug: string }>
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params
  const profile = await fetchPublicProfile(slug)
  if (!profile) {
    return { title: 'Profile Not Found | MindForge' }
  }
  return {
    title: `${profile.name} | MindForge`,
    description: profile.bio ?? `${profile.name}'s learning profile on MindForge`,
  }
}

export default async function PublicProfilePage({ params }: PageProps) {
  const { slug } = await params
  const profile = await fetchPublicProfile(slug)

  if (!profile) notFound()

  return (
    <main className="page-container py-10 min-h-dvh">
      <div className="mx-auto max-w-2xl">
        <PublicProfileCard profile={profile} />
      </div>
    </main>
  )
}
