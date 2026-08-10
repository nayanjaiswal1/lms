package jobs

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
