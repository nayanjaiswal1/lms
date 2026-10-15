const STACK_IMAGES: Record<string, string> = {
  django: "/labs/django.svg",
  fastapi: "/labs/fastapi.svg",
  react: "/labs/react.svg",
  fullstack: "/labs/fullstack.svg",
}

const FALLBACK_STACK_IMAGE = "/labs/generic.svg"

/** Per-stack illustration under public/labs; unknown stacks get the generic mark. */
export function stackImage(stack: string): string {
  return STACK_IMAGES[stack] ?? FALLBACK_STACK_IMAGE
}
