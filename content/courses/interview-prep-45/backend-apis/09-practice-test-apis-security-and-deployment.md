---
kind: quiz
id_key: interview-prep-45/test-backend-apis
course: interview-prep-45
section: backend-apis
section_title: "APIs, Security & Deployment"
section_position: 11
section_group: "Backend"
title: "Practice Test: APIs, Security and Deployment"
position: 9
estimated_minutes: 30
pass_percentage: 70
duration_minutes: 30
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
    - checkpoints/02-quiz-week-2.md
    - backend/07-lesson.md
    - backend/14-lesson.md
    - backend/21-lesson.md
questions:
  - id_key: interview-prep-45/quiz-week-2/q7
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Which HTTP method semantics are correct for a REST API?"
    options:
      - text: "PUT replaces a resource idempotently; PATCH applies a partial update; POST creates without idempotency"
        correct: true
      - text: "POST is idempotent; PUT is not"
      - text: "PATCH fully replaces the resource"
      - text: "PUT and POST are interchangeable by spec"
    explanation: "PUT sends the full replacement representation and repeated calls give the same result; PATCH sends only changed fields; POST creates a new resource each call, so retries need idempotency keys."

  - id_key: interview-prep-45/test-backend-apis/richardson-level
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What does Richardson Maturity Level 2 actually require, and why is Level 3 (HATEOAS) rarely fully implemented?"
    options:
      - text: "Level 2 requires resources with correct HTTP verbs and status codes; Level 3 adds navigable links, which most teams skip for the client complexity against limited benefit"
        correct: true
      - text: "Level 2 requires HATEOAS; Level 3 requires only resource URLs"
      - text: "Level 2 and Level 3 are identical in practice"
      - text: "Level 2 means every endpoint must be a POST"
    explanation: "Level 2, resources plus correctly used HTTP verbs and status codes, is what most real APIs mean by RESTful. Level 3 adds links to related actions in every response, which adds client complexity most typical API consumers don't need."

  - id_key: interview-prep-45/test-backend-apis/cursor-pagination
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Why does cursor pagination scale better than offset pagination on a large, actively written table?"
    options:
      - text: "Cursor pagination uses an indexed range scan from the last seen row, avoiding the scan-and-discard cost of OFFSET and staying correct under concurrent inserts"
        correct: true
      - text: "Cursor pagination does not require an index at all"
      - text: "Offset pagination is always faster but less secure"
      - text: "Cursor pagination loads the entire table into memory once"
    explanation: "OFFSET N still makes the database scan and discard N rows before returning results, and a concurrent insert shifts every later page. A cursor encodes the last-seen sort key and queries with a WHERE clause, which is an indexed range scan unaffected by concurrent inserts."

  - id_key: interview-prep-45/test-backend-apis/breaking-change
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "Which of these is a breaking API change, not a safe additive one?"
    options:
      - text: "Renaming a field in an existing response"
        correct: true
      - text: "Adding a new optional field to a response"
      - text: "Adding a new endpoint"
      - text: "Loosening a validation rule so more requests succeed"
    explanation: "Renaming, removing, or retyping an existing field breaks any client already parsing it. Adding a new field, a new endpoint, or loosening validation are all additive and safe."

  - id_key: interview-prep-45/test-backend-apis/unhandled-exception
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "What's wrong with letting an unhandled exception's stack trace reach the client directly?"
    options:
      - text: "It can leak internal details, like a database connection string or file paths, to whoever sent the request"
        correct: true
      - text: "Nothing; stack traces help clients debug their own requests"
      - text: "It only matters for GET requests"
      - text: "Clients cannot parse stack traces, so it has no effect either way"
    explanation: "A raw stack trace can expose internal implementation details an attacker could use. The fix is a catch-all handler that logs full detail server-side and returns a generic error to the client."

  - id_key: interview-prep-45/test-backend-apis/jwt-vs-apikey
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "Which credential type identifies a client/service rather than a logged-in user, has no built-in expiry, and carries no claims?"
    options:
      - text: "An API key"
        correct: true
      - text: "A JWT"
      - text: "An OAuth access token"
      - text: "A CSRF token"
    explanation: "An API key is a static, long-lived secret identifying a client or service, not a person. A JWT and an OAuth token both identify a user and carry an expiry and claims."

  - id_key: interview-prep-45/test-backend-apis/bearer-vs-rbac
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A request carries a perfectly valid bearer token for a known user, but is still rejected. What's the most likely reason?"
    options:
      - text: "Authorization (RBAC) rejected the specific action, since a valid bearer token only proves authentication, not permission to do this"
        correct: true
      - text: "Bearer tokens cannot be validated by the server"
      - text: "The token must actually be invalid, since a valid token can never be rejected"
      - text: "Bearer tokens are only used for guest, unauthenticated traffic"
    explanation: "Bearer token is a transport scheme proving authentication (who is asking). RBAC is a separate authorization check (what they can do), and a valid, authenticated request can still fail it if the user's role lacks the required permission."

  - id_key: interview-prep-45/test-backend-apis/csrf-defense
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Which defense stops most CSRF attacks today with the least implementation effort?"
    options:
      - text: "Setting SameSite=Lax or SameSite=Strict on session cookies"
        correct: true
      - text: "Encrypting the request body"
      - text: "Rate limiting every endpoint"
      - text: "Requiring HTTPS on all requests"
    explanation: "SameSite cookies block a cookie from being auto-attached on a cross-site request in the first place, which stops most CSRF today with a one-line cookie setting. HTTPS protects data in transit but does nothing against CSRF specifically."

  - id_key: interview-prep-45/test-backend-apis/presigned-url-flow
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In the standard presigned-URL upload flow, what does the client actually receive from your server?"
    options:
      - text: "A signed, time-limited URL scoped to one bucket, key, and content type, which the client PUTs the file bytes to directly"
        correct: true
      - text: "The server's raw AWS credentials"
      - text: "A copy of the file, pre-uploaded by the server"
      - text: "A permanent, unscoped upload URL that never expires"
    explanation: "The server never sends AWS credentials to the client. It signs a time-limited URL scoped to one exact bucket, key, and content type; the client uploads directly to S3 with a plain PUT, and the server's own storage never touches the file bytes."

  - id_key: interview-prep-45/test-backend-apis/s3-consistency-change
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What changed about S3's consistency model in December 2020?"
    options:
      - text: "All S3 operations became strongly read-after-write consistent, including overwrite PUTs and deletes, which were previously only eventually consistent"
        correct: true
      - text: "S3 switched from strong consistency to eventual consistency for all operations"
      - text: "S3 began supporting multipart uploads for the first time"
      - text: "S3 removed support for presigned URLs"
    explanation: "Before December 2020, an overwrite PUT or a delete was only eventually consistent, so a GET right after could briefly return stale data. AWS made every S3 operation strongly read-after-write consistent from that point on."

  - id_key: interview-prep-45/test-backend-apis/s3-error-categories
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "An S3 upload fails with a SlowDown error. What's the correct response?"
    options:
      - text: "Retry with exponential backoff, since SlowDown means you're being throttled, a transient condition"
        correct: true
      - text: "Fail immediately, since SlowDown always means a permanent misconfiguration"
      - text: "Delete the bucket and recreate it"
      - text: "Ignore the error entirely, since S3 retries automatically"
    explanation: "SlowDown is a transient, throttling-related error, retried with exponential backoff. Permanent errors like AccessDenied or NoSuchBucket should fail immediately instead, since retrying won't change the outcome."

  - id_key: interview-prep-45/test-backend-apis/dockerfile-order
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "Why does copying requirements.txt and running pip install before COPY . . speed up repeated Docker builds?"
    options:
      - text: "It keeps the dependency install layer cached across ordinary source code changes, since only a change to requirements.txt itself invalidates it"
        correct: true
      - text: "It makes pip install run in parallel automatically"
      - text: "It reduces the number of layers in the final image"
      - text: "Docker requires requirements.txt to be copied first by convention"
    explanation: "Docker caches each layer by its inputs' hash. Copying requirements.txt first means only a real dependency change invalidates the install layer; an ordinary source code edit afterward leaves that expensive layer cached."

  - id_key: interview-prep-45/test-backend-apis/multistage-build
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What does a multi-stage Docker build actually remove from the final image, using the psycopg2/build-essential example?"
    options:
      - text: "The compiler toolchain (build-essential, dev headers) used only to compile the package; the final stage copies just the already-compiled result"
        correct: true
      - text: "The Python interpreter itself"
      - text: "All application source code"
      - text: "The base image's operating system"
    explanation: "A multi-stage build isolates the compiler toolchain needed to build a package like psycopg2 from source in one stage. The final runtime stage copies only the compiled output, never the compiler or headers that produced it."

  - id_key: interview-prep-45/test-backend-apis/depends-on-healthy
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "What's the practical difference between depends_on alone and depends_on with condition: service_healthy in docker-compose?"
    options:
      - text: "Plain depends_on only waits for a container to start; condition: service_healthy waits for its healthcheck to actually pass, meaning it's ready"
        correct: true
      - text: "They behave identically in every version of Compose"
      - text: "condition: service_healthy is slower but otherwise identical"
      - text: "Plain depends_on only works for database containers"
    explanation: "A database container can be 'started' well before it's accepting connections. Plain depends_on only orders container start; condition: service_healthy waits for a defined healthcheck to pass before starting the dependent service."

  - id_key: interview-prep-45/test-backend-apis/websocket-scaling
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "User A is connected to server 1 and user B to server 2, behind a load balancer with no sticky sessions. A naive in-process ConnectionManager cannot let A message B. What fixes this?"
    options:
      - text: "A shared pub/sub backbone (Redis Pub/Sub or Kafka) that every server subscribes to, so any instance can publish a message that reaches whichever instance holds the recipient's socket"
        correct: true
      - text: "Increasing the WebSocket connection timeout"
      - text: "Switching from WebSocket to Server-Sent Events"
      - text: "Running the ConnectionManager on the load balancer itself"
    explanation: "A WebSocket connection is sticky to the one process that accepted it. A shared pub/sub channel that every instance subscribes to is what lets a message published from any server reach the specific instance holding the recipient's live connection."

  - id_key: interview-prep-45/test-backend-apis/mock-vs-stub
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "A test replaces a dependency to verify that send_email() was called exactly once with the correct arguments. Is this dependency being used as a mock or a stub?"
    options:
      - text: "A mock, since the test is verifying an interaction happened correctly, not just checking a returned value"
        correct: true
      - text: "A stub, since it returns canned data"
      - text: "Neither; this requires a real email service"
      - text: "A stub, since mocks cannot assert on call arguments"
    explanation: "A stub just supplies canned responses so a test can run; a mock's defining feature is asserting that an interaction, like a specific call with specific arguments, actually happened. Checking call arguments is exactly what a mock does."

  - id_key: interview-prep-45/test-backend-apis/asyncmock
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A test replaces an async dependency with a plain Mock() instead of an AsyncMock(), and the code under test does await dependency(). What happens?"
    options:
      - text: "A TypeError is raised, since a plain Mock's return value is not awaitable"
        correct: true
      - text: "The test passes exactly as if AsyncMock had been used"
      - text: "pytest silently skips the test"
      - text: "The await keyword is ignored for any mocked object automatically"
    explanation: "A plain Mock returns a synchronous Mock object when called, which is not awaitable. AsyncMock exists specifically so an awaited call returns something Python's await syntax can actually work with."
---
This test covers REST API design and pagination, versioning and standardized error handling, JWT/OAuth/API key authentication and CSRF, WebSocket scaling, Docker layering and multi-stage builds, S3 consistency and presigned uploads, and the mock-versus-stub distinction in testing. Pass 70% to complete the section.
