import { mintWSTokenAction } from "@/app/(app)/labs/[labId]/actions"

// labproxy preview tokens live 5 minutes; refresh a minute early.
const IDE_TOKEN_REFRESH_MS = 4 * 60 * 1000

export interface IdeTokens {
  /** Token the IDE iframe was first loaded with — never changes, so VS Code never reloads. */
  first: string | null
  /** Most recently minted token; feeds the hidden cookie-refresh iframe and pop-out. */
  latest: string | null
  failed: boolean
}

interface IdeTokenStore {
  subscribe: (listener: () => void) => () => void
  getSnapshot: () => IdeTokens
  /** Mints a fresh token right now (for a click that must not use a stale one); null on failure. */
  mintNow: () => Promise<string | null>
}

const INITIAL: IdeTokens = { first: null, latest: null, failed: false }

/**
 * External store for useSyncExternalStore: mints a token on first subscribe
 * and every IDE_TOKEN_REFRESH_MS while anything is subscribed, stopping when
 * the last subscriber leaves. Keeps the token lifecycle out of components
 * (no effects, no timers in render).
 */
export function createIdeTokenStore(sessionId: string): IdeTokenStore {
  let state = INITIAL
  let timer: ReturnType<typeof setInterval> | null = null
  const listeners = new Set<() => void>()

  const set = (next: IdeTokens) => {
    state = next
    listeners.forEach((l) => l())
  }

  const mint = async (): Promise<string | null> => {
    const res = await mintWSTokenAction(sessionId)
    if (!res.ok || !res.data) {
      // A failed refresh keeps the last good token; only the first mint is fatal.
      if (state.latest === null) set({ ...state, failed: true })
      return null
    }
    const token = res.data.session_token
    set({ first: state.first ?? token, latest: token, failed: false })
    return token
  }

  return {
    subscribe(listener) {
      listeners.add(listener)
      if (timer === null) {
        void mint()
        timer = setInterval(() => void mint(), IDE_TOKEN_REFRESH_MS)
      }
      return () => {
        listeners.delete(listener)
        if (listeners.size === 0 && timer !== null) {
          clearInterval(timer)
          timer = null
        }
      }
    },
    getSnapshot: () => state,
    mintNow: mint,
  }
}
