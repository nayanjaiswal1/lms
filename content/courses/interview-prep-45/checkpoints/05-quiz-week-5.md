---
kind: quiz
id_key: interview-prep-45/quiz-week-5
course: interview-prep-45
section: checkpoints
section_title: "Weekly Checkpoints"
section_position: 6
title: "Week 5 Checkpoint Quiz — Mock Interview Skills"
position: 5
estimated_minutes: 20
source:
    - 45-day-interview-roadmap.md
pass_percentage: 70
duration_minutes: 15
questions:
  - id_key: interview-prep-45/quiz-week-5/q1
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What should you do FIRST when given a coding problem in an interview?"
    options:
      - text: "Restate the problem, ask clarifying questions, and confirm constraints and edge cases"
        correct: true
      - text: "Start typing the brute-force solution immediately"
      - text: "Ask for a hint to save time"
      - text: "Write all the test cases before discussing the approach"
    explanation: "Interviewers grade the process: restating catches misunderstandings when they're free to fix, and constraints (input size, value ranges, duplicates?) determine which complexity class is acceptable."
  - id_key: interview-prep-45/quiz-week-5/q2
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In a system design interview, what comes immediately after gathering functional requirements?"
    options:
      - text: "Back-of-the-envelope estimation — users, QPS, storage, read/write ratio"
        correct: true
      - text: "Choosing the programming language"
      - text: "Drawing the final architecture with every microservice"
      - text: "Writing the database schema in full detail"
    explanation: "Scale numbers drive every later decision: 100 QPS and 100k QPS produce different designs. Estimating first keeps you from designing for a scale the interviewer never asked about."
  - id_key: interview-prep-45/quiz-week-5/q3
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Designing a Twitter-like feed: what is the core trade-off between fan-out-on-write and fan-out-on-read?"
    options:
      - text: "Write fan-out precomputes timelines for fast reads but wastes work for celebrity accounts; read fan-out queries followees at read time"
        correct: true
      - text: "Read fan-out is always faster for every account size"
      - text: "Write fan-out means tweets are stored twice for durability"
      - text: "There is no difference — both cost the same"
    explanation: "Push (write fan-out) makes reads O(1) but a 100M-follower account triggers 100M timeline inserts per tweet. The classic hybrid: push for normal users, pull-and-merge for celebrities."
  - id_key: interview-prep-45/quiz-week-5/q4
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What is the STAR format for behavioral answers?"
    options:
      - text: "Situation, Task, Action, Result"
        correct: true
      - text: "Strengths, Talents, Achievements, References"
      - text: "Summary, Timeline, Analysis, Reflection"
      - text: "Situation, Team, Attitude, Response"
    explanation: "STAR keeps behavioral answers concrete and scoped: set the scene briefly, state your responsibility, spend most time on YOUR actions, and land on a measurable result."
  - id_key: interview-prep-45/quiz-week-5/q5
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "You're stuck on a mock-interview problem for several minutes. Best move?"
    options:
      - text: "Talk through what you know, name the pattern you suspect, and solve a simpler version out loud"
        correct: true
      - text: "Go silent until you find the optimal solution"
      - text: "Give up and ask for the answer"
      - text: "Write code randomly hoping it compiles into insight"
    explanation: "Silence is the worst signal in an interview. Verbalizing partial progress shows your debugging process and invites the interviewer's calibrated hints — which they want to give."
  - id_key: interview-prep-45/quiz-week-5/q6
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "Designing YouTube-scale video storage, the standard serving approach is:"
    options:
      - text: "Store transcoded segments in blob storage and serve through a CDN, keeping metadata in a database"
        correct: true
      - text: "Store video bytes as BLOB columns in PostgreSQL"
      - text: "Stream every request from the original upload server"
      - text: "Keep all videos in Redis for speed"
    explanation: "Video bytes belong in object storage (S3-style), delivered from CDN edges near users; databases hold only metadata (title, owner, segment manifest). Databases handle neither the size nor the bandwidth."
  - id_key: interview-prep-45/quiz-week-5/q7
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "After a mock interview, the highest-leverage habit is:"
    options:
      - text: "Log every stumble — pattern gaps, communication misses — and drill those specific weaknesses next"
        correct: true
      - text: "Immediately schedule another mock to stay warm"
      - text: "Re-solve only the problems you already got right"
      - text: "Memorize the exact solution to that one problem"
    explanation: "Mocks are diagnostic instruments. Week 5's whole design is mock → weakness log → targeted drilling (that's Week 6). Repeating what you're good at feels productive but moves nothing."
  - id_key: interview-prep-45/quiz-week-5/q8
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "In a full-stack interview asking for a Todo app, which answer demonstrates senior judgment?"
    options:
      - text: "Start with the data model and API contract, then build UI state on top, mentioning optimistic updates and error rollback"
        correct: true
      - text: "Install as many libraries as possible to show ecosystem knowledge"
      - text: "Build the CSS animations first for visual impact"
      - text: "Refuse to discuss the frontend because backend matters more"
    explanation: "Schema and API contract are the load-bearing decisions — UI follows from them. Mentioning optimistic updates with rollback shows you've handled real client-server state, which is what the question probes."
---

Checkpoint for mock-interview week: coding-interview process, system design method
(estimation, feed fan-out, video serving), STAR behavioral answers, and how to
convert mock feedback into a weakness plan. Score 70%+ before final prep week.
