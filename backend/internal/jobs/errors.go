package jobs

import "time"

// PermanentError marks a handler error as certain to fail again on retry —
// bad SMTP credentials, a recipient the mail relay rejected outright, a
// malformed payload. jobs.Fail moves a job straight to dead status on a
// PermanentError regardless of retries remaining, instead of spending the
// retry budget (with its exponential backoff) re-attempting an outcome that
// cannot change. Handlers signal this by returning jobs.Permanent(err)
// instead of a plain error.
type PermanentError struct{ err error }

// Permanent wraps err so jobs.Fail treats it as non-retryable.
func Permanent(err error) error {
	return &PermanentError{err: err}
}

func (e *PermanentError) Error() string { return e.err.Error() }
func (e *PermanentError) Unwrap() error { return e.err }

// RetryAfterError asks jobs.Fail to re-queue the job no sooner than After,
// without consuming a retry or sending it to dead. For conditions that are
// neither the job's fault nor permanent — a provider throttle, an open
// circuit breaker, an exhausted per-org send quota — where waiting is the
// correct response and burning the retry budget would kill a healthy job.
//
// Ceiling: nothing bounds how often a job can be deferred; a relay that
// throttles forever keeps its jobs queued (visible via the breaker, logs and
// the queued-job TTL sweep) rather than dropping them.
type RetryAfterError struct {
	err   error
	After time.Duration
}

// RetryAfter wraps err so jobs.Fail defers the job by at least d.
func RetryAfter(err error, d time.Duration) error {
	return &RetryAfterError{err: err, After: d}
}

func (e *RetryAfterError) Error() string { return e.err.Error() }
func (e *RetryAfterError) Unwrap() error { return e.err }
