export interface CheckFailure {
  name: string
  message: string
}

const FAIL_LINE = /^FAIL\s+([^:]+?):\s*(.*)$/

/** Extracts `FAIL <check name>: <author message>` lines from a grader's stdout. */
export function parseCheckFailures(stdout: string | undefined): CheckFailure[] {
  if (!stdout) return []
  const failures: CheckFailure[] = []
  for (const line of stdout.split("\n")) {
    const match = FAIL_LINE.exec(line.trim())
    if (match) failures.push({ name: match[1], message: match[2] })
  }
  return failures
}
