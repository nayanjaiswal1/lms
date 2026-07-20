# 45-Day Interview Preparation Roadmap

## Full-Stack Engineer | 3 Years Experience

---

## Table of Contents

- [Week 1](#day-1) (Days 1-7)
- [Week 2](#day-8) (Days 8-14)
- [Week 3](#day-15) (Days 15-21)
- [Week 4](#day-22) (Days 22-28)
- [Week 5](#day-29) (Days 29-35) - Mock Interviews Begin
- [Week 6](#day-36) (Days 36-42)
- [Final](#day-43) (Days 43-45)

---

## How to Use This Roadmap

This is a 45-day plan with DSA, System Design, Backend, Frontend, and Behavioral prep.
Mock interviews begin on Day 30. Follow the plan exactly without skipping.

---

## Day 1 {#day-1}

**Topic:** Arrays and Hashing - Fundamentals

**Concepts to learn:**
- [ ] Hash table basics and collision resolution
- [ ] Time complexity analysis for array operations
- [ ] Space complexity trade-offs

**Coding problems:**
- [ ] Two Sum (LeetCode 1) — Hash map — Use complement approach
- [ ] Valid Anagram (LeetCode 242) — Hash map — Frequency counting
- [ ] Contains Duplicate (LeetCode 217) — Hash set — Basic existence check

**Implementation tasks:**
- [ ] Implement hash map from scratch with chaining
- [ ] Implement dynamic array with amortized O(1) push

**Review tasks:**
- [ ] Review Big-O notation for arrays and hash tables
- [ ] Memorize: hash map lookup is O(1) average, O(n) worst case
---

**System Design:** URL Shortener

**Tasks to complete:**
- [ ] Define functional requirements: redirect, create short URL, custom aliases
- [ ] Define non-functional requirements: high availability, low latency, redirect speed
- [ ] Design database schema: URL table with original_url, short_code, click_count, created_at
- [ ] Design API endpoints: POST /shorten, GET /{short_code}, GET /{short_code}/stats
- [ ] Discuss hash function choices: base-62 encoding vs random ID
- [ ] Analyze read vs write ratio implications

**Backend Deep Dive: Django Request Lifecycle**

**Tasks:**
- [ ] Read: Django request lifecycle diagram
- [ ] Implement: Add custom middleware that logs request path and response time
- [ ] Implement: Create a decorator to time function execution
- [ ] Common interview question: What happens when a POST request hits Django?

**Implementation tasks:**
- [ ] Write middleware that adds X-Request-ID to every response
- [ ] Trace through: request -> URLconf -> view -> response

---


**Frontend Deep Dive: React Rendering Fundamentals**

**Tasks:**
- [ ] Read: React reconciliation algorithm documentation
- [ ] Implement: Create a class component and trace through render cycle
- [ ] Implement: Build a counter showing render count (use logs)

**Concept exploration:**
- [ ] Virtual DOM vs Real DOM
- [ ] Why React re-renders
- [ ] Component lifecycle phases

**Behavioral Preparation: Resume Walkthrough**

**Tasks:**
- [ ] Write 3-paragraph summary of your background:
  - [ ] Paragraph 1: Current role, company, tech stack
  - [ ] Paragraph 2: Key projects and achievements with metrics
  - [ ] Paragraph 3: Why you're looking to move, what you want next
- [ ] Practice saying this in 2 minutes
- [ ] Identify 3 projects to deep-dive later

**Revision tasks:**
- [ ] Review hash map implementation
- [ ] Review Django middleware flow

---

## Day 2


**Topic:** Two Pointers Pattern

**Concepts to learn:**
- [ ] When to use two pointers vs hash maps
- [ ] Sorted array assumptions
- [ ] In-place modifications

**Coding problems:**
- [ ] Valid Palindrome (LeetCode 125) — Two pointers — Compare characters
- [ ] 3Sum (LeetCode 15) — Two pointers + hashing — Avoid duplicates
- [ ] Container With Most Water (LeetCode 11) — Two pointers — Move smaller pointer

**Implementation tasks:**
- [ ] Implement linked list node class for future problems
- [ ] Practice writing pointer movement logic cleanly

**Review tasks:**
- [ ] Review: How to avoid duplicates when using two pointers
- [ ] Memorize: 3Sum time complexity is O(n²)

---


**System Design Exercise:** Rate Limiter (api gateway style)

**Tasks to complete:**
- [ ] Define functional requirements: limit requests per user/IP
- [ ] Define non-functional requirements: accuracy vs performance trade-off
- [ ] Design algorithms: token bucket, leaky bucket, sliding window, fixed window
- [ ] Discuss where to store counters: Redis vs in-memory
- [ ] Handle distributed rate limiting challenges

**Backend Deep Dive: Django ORM Internals**

**Tasks:**
- [ ] Read: Django ORM query execution flow
- [ ] Implement: Write raw SQL and compare with ORM generated SQL
- [ ] Implement: Use EXPLAIN ANALYZE on a complex query
- [ ] Common interview questions:
  - [ ] What happens when you call Model.objects.filter()?
  - [ ] What is lazy evaluation in Django ORM?

**Implementation tasks:**
- [ ] Create a model with 1000 records
- [ ] Write query using select_related and prefetch_related
- [ ] Compare query counts

---


**Frontend Deep Dive: React Hooks Internals**

**Tasks:**
- [ ] Read: React hooks rules and implementation
- [ ] Implement: Build useState from scratch
- [ ] Implement: Build useEffect with cleanup

**Concept exploration:**
- [ ] How useState updates trigger re-renders
- [ ] How useEffect handles dependencies
- [ ] Why hooks can't be conditional

**Behavioral Preparation: Project Deep Dive - Project 1**

**Tasks:**
- [ ] Pick your most complex project
- [ ] Write structure:
  - [ ] Problem: What problem did you solve?
  - [ ] Solution: What did you build?
  - [ ] Impact: What was the result? (metrics)
  - [ ] Challenges: What was hard?
  - [ ] Decisions: What trade-offs did you make?
- [ ] Practice explaining in 5 minutes

**Revision tasks:**
- [ ] Review two pointers patterns
- [ ] Review Django ORM lazy evaluation

---

## Day 3


**Topic:** Sliding Window

**Concepts to learn:**
- [ ] Fixed vs variable window size
- [ ] When to expand vs contract window
- [ ] Tracking multiple variables in window

**Coding problems:**
- [ ] Best Time to Buy and Sell Stock (LeetCode 121) — Sliding window
- [ ] Longest Substring Without Repeating Characters (LeetCode 3) — Sliding window + hash
- [ ] Minimum Window Substring (LeetCode 76) — Sliding window — Hard

**Implementation tasks:**
- [ ] Implement sliding window template
- [ ] Practice identifying when sliding window applies

**Review tasks:**
- [ ] Memorize: Sliding window reduces O(n²) to O(n)
- [ ] Review: How to handle characters outside ASCII range

---


**System Design Exercise:** Notification Service

**Tasks to complete:**
- [ ] Define functional requirements: send email, SMS, push notifications
- [ ] Define non-functional requirements: reliability, ordering, retry logic
- [ ] Design message queue architecture
- [ ] Discuss notification templates
- [ ] Handle delivery failures and retries
- [ ] Design for scale: millions of notifications

**Backend Deep Dive: FastAPI ASGI and Async**

**Tasks:**
- [ ] Read: ASGI vs WSGI difference
- [ ] Implement: Create async endpoint with background task
- [ ] Implement: Measure difference between sync and async function
- [ ] Common interview questions:
  - [ ] What is the difference between async and await?
  - [ ] How does FastAPI handle concurrency?

**Implementation tasks:**
- [ ] Build endpoint that fetches from 3 APIs concurrently using asyncio.gather
- [ ] Implement proper error handling in async context

---


**Frontend Deep Dive: Event Loop and Browser Rendering**

**Tasks:**
- [ ] Read: JS event loop MDN documentation
- [ ] Implement: Write code demonstrating macro vs micro tasks
- [ ] Implement: Trace render pipeline (frame anatomy)

**Concept exploration:**
- [ ] Task queue vs microtask queue
- [ ] requestAnimationFrame
- [ ] Layout and paint phases

**Behavioral Preparation: Project Deep Dive - Project 2**

**Tasks:**
- [ ] Pick second most complex project
- [ ] Write same structure as Day 2
- [ ] Practice explaining in 5 minutes

**Revision tasks:**
- [ ] Review sliding window template
- [ ] Review async/await patterns

---

## Day 4


**Topic:** Binary Search

**Concepts to learn:**
- [ ] Search space reduction
- [ ] Finding boundaries (lower bound, upper bound)
- [ ] Monotonic functions

**Coding problems:**
- [ ] Binary Search (LeetCode 704) — Binary search — Basic template
- [ ] Search in Rotated Sorted Array (LeetCode 33) — Binary search — Identify sorted half
- [ ] Find Minimum in Rotated Sorted Array (LeetCode 153) — Binary search
- [ ] Search a 2D Matrix (LeetCode 74) — Binary search — Treat as 1D

**Implementation tasks:**
- [ ] Implement lower_bound and upper_bound functions
- [ ] Practice identifying when binary search applies

**Review tasks:**
- [ ] Memorize: Binary search is O(log n)
- [ ] Review: Common off-by-one errors

---


**System Design Exercise:** Chat Application (WhatsApp style)

**Tasks to complete:**
- [ ] Define functional requirements: 1-on-1 chat, groups, read receipts
- [ ] Define non-functional requirements: real-time, offline support
- [ ] Design WebSocket connection handling
- [ ] Design database schema for messages
- [ ] Design message ordering and consistency
- [ ] Handle message delivery guarantees

**Backend Deep Dive: PostgreSQL Indexing**

**Tasks:**
- [ ] Read: B-tree index internals
- [ ] Implement: Create indexes and measure query performance
- [ ] Implement: Use EXPLAIN ANALYZE to understand query planner
- [ ] Common interview questions:
  - [ ] When would you NOT use an index?
  - [ ] What is index selectivity?

**Implementation tasks:**
- [ ] Create table with 100k rows
- [ ] Write queries and add appropriate indexes
- [ ] Measure before/after performance

---


**Frontend Deep Dive: State Management**

**Tasks:**
- [ ] Read: Redux vs Context API vs Zustand
- [ ] Implement: Build simple Redux-like store
- [ ] Implement: Implement useReducer for complex state

**Concept exploration:**
- [ ] When to use local state vs global state
- [ ] Immutable update patterns
- [ ] State normalization

**Behavioral Preparation: Conflict Resolution Story**

**Tasks:**
- [ ] Write STAR story about a technical disagreement
- [ ] Structure: Situation, Task, Action, Result
- [ ] Practice answering: "Tell me about a time you disagreed with someone"

**Revision tasks:**
- [ ] Review binary search variations
- [ ] Review PostgreSQL index types

---

## Day 5


**Topic:** Stacks

**Concepts to learn:**
- [ ] LIFO principle
- [ ] Stack vs recursion
- [ ] Monotonic stack pattern

**Coding problems:**
- [ ] Valid Parentheses (LeetCode 20) — Stack — Matching brackets
- [ ] Daily Temperatures (LeetCode 739) — Monotonic stack
- [ ] Largest Rectangle in Histogram (LeetCode 84) — Monotonic stack — Hard
- [ ] Min Stack (LeetCode 155) — Stack — O(1) min retrieval

**Implementation tasks:**
- [ ] Implement stack using linked list
- [ ] Practice monotonic stack template

**Review tasks:**
- [ ] Memorize: Monotonic stack solves next greater/smaller problems
- [ ] Review: When to use stack over recursion

---


**System Design Exercise:** Analytics Pipeline

**Tasks to complete:**
- [ ] Define functional requirements: track events, generate reports
- [ ] Define non-functional requirements: high throughput, data accuracy
- [ ] Design event ingestion pipeline (Kafka/Kinesis)
- [ ] Design storage: data lake vs data warehouse
- [ ] Design real-time vs batch processing
- [ ] Handle late-arriving data

**Backend Deep Dive: PostgreSQL Query Optimization**

**Tasks:**
- [ ] Read: Query planner internals
- [ ] Implement: Analyze slow queries from your projects
- [ ] Implement: Write query with and without JOIN optimization
- [ ] Common interview questions:
  - [ ] What is the difference between WHERE and HAVING?
  - [ ] Explain JOIN types

**Implementation tasks:**
- [ ] Create queries with N+1 problems
- [ ] Fix using JOINs and measure improvement

---


**Frontend Deep Dive: React Performance Optimization**

**Tasks:**
- [ ] Read: React Profiler API documentation
- [ ] Implement: Add React.memo to components
- [ ] Implement: Use useMemo and useCallback correctly

**Concept exploration:**
- [ ] When to use memoization
- [ ] Cost of memoization
- [ ] DevTools performance tab usage

**Behavioral Preparation: Production Failure Story**

**Tasks:**
- [ ] Write STAR story about a production incident
- [ ] Include: What happened, your role, how you fixed it, what you learned
- [ ] Practice: "Tell me about a time something went wrong in production"

**Revision tasks:**
- [ ] Review stack problems
- [ ] Review PostgreSQL query optimization

---

## Day 6


**Topic:** Trees - Basics

**Concepts to learn:**
- [ ] Tree traversal: inorder, preorder, postorder, level-order
- [ ] Recursive vs iterative traversal
- [ ] Tree properties

**Coding problems:**
- [ ] Invert Binary Tree (LeetCode 226) — Tree — Basic manipulation
- [ ] Maximum Depth of Binary Tree (LeetCode 104) — Tree — Recursion
- [ ] Same Tree (LeetCode 100) — Tree — Compare structures
- [ ] Binary Tree Level Order Traversal (LeetCode 102) — BFS

**Implementation tasks:**
- [ ] Implement tree node class
- [ ] Implement all four traversals iteratively and recursively

**Review tasks:**
- [ ] Memorize: DFS uses stack or recursion, BFS uses queue
- [ ] Review: When to use preorder vs inorder vs postorder

---


**System Design Exercise:** Multi-tenant SaaS Architecture

**Tasks to complete:**
- [ ] Define functional requirements: isolation, billing per tenant
- [ ] Define non-functional requirements: security, performance
- [ ] Design tenancy models: shared database, separate schema, separate database
- [ ] Design RBAC for multi-tenant access
- [ ] Discuss tenant-specific customization
- [ ] Handle data migration across tenants

**Backend Deep Dive: Redis Caching Strategies**

**Tasks:**
- [ ] Read: Redis data structures and use cases
- [ ] Implement: Cache-aside pattern implementation
- [ ] Implement: Redis distributed lock
- [ ] Common interview questions:
  - [ ] What is cache invalidation?
  - [ ] What are the problems with distributed locks?

**Implementation tasks:**
- [ ] Implement cache-aside pattern with TTL
- [ ] Implement rate limiter using Redis

---


**Frontend Deep Dive: HTTP and Caching**

**Tasks:**
- [ ] Read: HTTP caching headers (Cache-Control, ETag, Last-Modified)
- [ ] Implement: Service worker for caching
- [ ] Implement: Demonstrate browser caching behavior

**Concept exploration:**
- [ ] CDN caching strategies
- [ ] Stale-while-revalidate
- [ ] Cache invalidation strategies

**Behavioral Preparation: Leadership Story**

**Tasks:**
- [ ] Write STAR story about taking initiative
- [ ] Include: What you saw, what you did, what happened
- [ ] Practice: "Tell me about a time you took the lead"

**Revision tasks:**
- [ ] Review tree traversals
- [ ] Review caching patterns

---

## Day 7 — WEEKLY CHECKPOINT


**DSA Progress Review:**
- [ ] Arrays/Hashing: 3 problems completed
- [ ] Two Pointers: 3 problems completed
- [ ] Sliding Window: 3 problems completed
- [ ] Binary Search: 4 problems completed
- [ ] Stacks: 4 problems completed
- [ ] Trees: 4 problems completed

**Revision tasks:**
- [ ] Re-solve 3 hardest problems from this week without looking
- [ ] Note which patterns still feel weak

**Key metrics:**
- [ ] Track time per problem
- [ ] Track blind spots (topics where you struggle)

---


**System Design Understanding Review:**
- [ ] URL Shortener: Completed
- [ ] Rate Limiter: Completed
- [ ] Notification Service: Completed
- [ ] Chat Application: Completed
- [ ] Analytics Pipeline: Completed
- [ ] Multi-tenant SaaS: Completed

**Backend Knowledge Review:**
- [ ] Django request lifecycle: Completed
- [ ] Django ORM internals: Completed
- [ ] FastAPI async: Completed
- [ ] PostgreSQL indexing: Completed
- [ ] Redis caching: Completed

**Revision tasks:**
- [ ] Review system design notes
- [ ] Pick 2 weakest designs to re-practice

---


**Frontend Knowledge Review:**
- [ ] React rendering: Completed
- [ ] React hooks: Completed
- [ ] Event loop: Completed
- [ ] State management: Completed

**Behavioral Progress:**
- [ ] Resume walkthrough: Prepared
- [ ] 2 project deep-dives: Prepared
- [ ] Conflict story: Prepared
- [ ] Production failure story: Prepared
- [ ] Leadership story: Prepared

**Weaknesses to address:**
- [ ] Note topics where you need more practice
- [ ] Plan specific improvements for Week 2

---

## Day 8 {#day-8}


**Topic:** Trees - BST and Reconstruction

**Concepts to learn:**
- [ ] BST properties
- [ ] Inorder traversal of BST is sorted
- [ ] Tree reconstruction from traversals

**Coding problems:**
- [ ] Validate Binary Search Tree (LeetCode 98) — BST — Range validation
- [ ] Lowest Common Ancestor (LeetCode 235) — BST — BST properties
- [ ] Construct Binary Tree from Preorder and Inorder (LeetCode 105) — Reconstruction
- [ ] Kth Smallest Element in BST (LeetCode 230) — BST — Inorder traversal

**Implementation tasks:**
- [ ] Implement BST insert and search
- [ ] Practice range-based validation

**Review tasks:**
- [ ] Memorize: Inorder of BST gives sorted array
- [ ] Review: Why reconstruct from preorder + inorder but not preorder alone

---


**System Design Exercise:** Job Queue System

**Tasks to complete:**
- [ ] Define functional requirements: enqueue jobs, process workers, retry failed
- [ ] Define non-functional requirements: ordering, exactly-once, priorities
- [ ] Design job schema: id, payload, status, retries, scheduled_at
- [ ] Design worker architecture
- [ ] Handle dead letter queue
- [ ] Discuss scalability

**Backend Deep Dive: Celery and Task Queues**

**Tasks:**
- [ ] Read: Celery architecture documentation
- [ ] Implement: Create task with retry logic
- [ ] Implement: Schedule periodic task
- [ ] Common interview questions:
  - [ ] How do you ensure idempotency?
  - [ ] What happens when a worker dies?

**Implementation tasks:**
- [ ] Set up Celery with Redis broker
- [ ] Implement task with exponential backoff

---


**Frontend Deep Dive: Network Performance**

**Tasks:**
- [ ] Read: Network waterfall visualization
- [ ] Implement: Measure request performance with Performance API
- [ ] Implement: Optimize bundle size analysis

**Concept exploration:**
- [ ] Preload vs prefetch
- [ ] Image optimization techniques
- [ ] Code splitting strategies

**Behavioral Preparation: STAR Story Refinement**

**Tasks:**
- [ ] Refine all 5 prepared stories
- [ ] Each story should be 2-3 minutes when spoken
- [ ] Practice with a timer
- [ ] Remove filler words

**Revision tasks:**
- [ ] Review BST patterns
- [ ] Review Celery architecture

---

## Day 9


**Topic:** Graphs - BFS and DFS

**Concepts to learn:**
- [ ] Graph representation: adjacency list vs matrix
- [ ] When to use BFS vs DFS
- [ ] Visited set management

**Coding problems:**
- [ ] Number of Islands (LeetCode 200) — DFS/BFS — Grid traversal
- [ ] Clone Graph (LeetCode 133) — BFS/DFS — Deep copy
- [ ] Rotting Oranges (LeetCode 994) — BFS — Multi-source BFS
- [ ] Walls and Gates (LeetCode 286) — BFS — Fill distances

**Implementation tasks:**
- [ ] Implement graph using adjacency list
- [ ] Implement BFS and DFS from scratch

**Review tasks:**
- [ ] Memorize: BFS uses queue, DFS uses stack/recursion
- [ ] Review: When BFS is better than DFS

---


**System Design Exercise:** Social Media Feed

**Tasks to complete:**
- [ ] Define functional requirements: post, feed, like, comment
- [ ] Define non-functional requirements: consistency, availability
- [ ] Design Twitter timeline: chronological vs algorithmic
- [ ] Design for high read throughput
- [ ] Handle new user problem (cold start)
- [ ] Discuss pagination

**Backend Deep Dive: REST API Design**

**Tasks:**
- [ ] Read: REST best practices (Richardson Maturity Model)
- [ ] Implement: Design API for a resource with full CRUD
- [ ] Implement: Add pagination, filtering, sorting to endpoint
- [ ] Common interview questions:
  - [ ] When to use POST vs PUT vs PATCH?
  - [ ] How would you version an API?

**Implementation tasks:**
- [ ] Design API for blog system with posts, comments, likes

---


**Frontend Deep Dive: Code Splitting and Bundle Optimization**

**Tasks:**
- [ ] Read: Webpack code splitting strategies
- [ ] Implement: Dynamic imports in React
- [ ] Implement: Measure bundle with source-map-explorer

**Concept exploration:**
- [ ] Tree shaking
- [ ] Lazy loading components
- [ ] Bundle budget

**Behavioral Preparation: Collaboration Story**

**Tasks:**
- [ ] Write STAR story about working with cross-functional team
- [ ] Include: PM, designer, or other stakeholder interaction
- [ ] Practice: "Tell me about working with non-engineers"

**Revision tasks:**
- [ ] Review graph traversal patterns
- [ ] Review REST API design principles

---

## Day 10


**Topic:** Graphs - Topological Sort and Cycles

**Concepts to learn:**
- [ ] DAG properties
- [ ] Kahn's algorithm (BFS-based)
- [ ] DFS-based topological sort
- [ ] Cycle detection

**Coding problems:**
- [ ] Course Schedule (LeetCode 207) — Topological sort — Detect cycle
- [ ] Course Schedule II (LeetCode 210) — Topological sort — Return order
- [ ] Alien Dictionary (LeetCode 269) — Topological sort — Hard
- [ ] Longest Increasing Path in Matrix (LeetCode 329) — DFS + Memoization

**Implementation tasks:**
- [ ] Implement Kahn's algorithm
- [ ] Implement cycle detection in directed graph

**Review tasks:**
- [ ] Memorize: Topological sort only works on DAGs
- [ ] Review: How to handle multiple valid orderings

---


**System Design Exercise:** Design Twitter/X

**Tasks to complete:**
- [ ] Define functional requirements: tweets, timeline, followers
- [ ] Define non-functional requirements: latency, consistency
- [ ] Design tweet storage: fan-out on write vs read
- [ ] Design search functionality
- [ ] Handle viral content
- [ ] Discuss database sharding strategy

**Backend Deep Dive: API Versioning and Error Handling**

**Tasks:**
- [ ] Read: API versioning strategies
- [ ] Implement: Add versioning to FastAPI endpoint
- [ ] Implement: Standardized error response format
- [ ] Common interview questions:
  - [ ] How do you handle breaking changes?
  - [ ] What HTTP status codes do you use?

**Implementation tasks:**
- [ ] Design error handling middleware for FastAPI
- [ ] Implement rate limiting at API level

---


**Frontend Deep Dive: Virtualization**

**Tasks:**
- [ ] Read: react-window or react-virtual documentation
- [ ] Implement: Render large list efficiently
- [ ] Implement: Variable height list item handling

**Concept exploration:**
- [ ] Windowing vs virtualization
- [ ] Overscan
- [ ] Performance trade-offs

**Behavioral Preparation: Failure and Learning Story**

**Tasks:**
- [ ] Write STAR story about a project that failed or went wrong
- [ ] Include: What you learned, how you applied it
- [ ] Practice: "Tell me about a mistake you made"

**Revision tasks:**
- [ ] Review topological sort
- [ ] Review API versioning

---

## Day 11


**Topic:** Heaps / Priority Queues

**Concepts to learn:**
- [ ] Heap properties (complete binary tree)
- [ ] Max heap vs min heap
- [ ] Heapify operation

**Coding problems:**
- [ ] Kth Largest Element in Array (LeetCode 215) — Heap — QuickSelect alternative
- [ ] Top K Frequent Elements (LeetCode 347) — Heap — Frequency counting
- [ ] Merge K Sorted Lists (LeetCode 23) — Heap — Merge technique
- [ ] Find Median from Data Stream (LeetCode 295) — Heap — Two heaps pattern

**Implementation tasks:**
- [ ] Implement heap from scratch (array-based)
- [ ] Implement heapify operation

**Review tasks:**
- [ ] Memorize: Heap push/pop is O(log n), peek is O(1)
- [ ] Review: Why use heap for top-K problems

---


**System Design Exercise:** Search Autocomplete System

**Tasks to complete:**
- [ ] Define functional requirements: prefix matching, ranking
- [ ] Define non-functional requirements: latency, freshness
- [ ] Design Trie data structure
- [ ] Design ranking algorithm
- [ ] Handle real-time updates
- [ ] Discuss storage and scalability

**Backend Deep Dive: FastAPI Background Tasks**

**Tasks:**
- [ ] Read: FastAPI background tasks documentation
- [ ] Implement: Offload heavy computation to background task
- [ ] Implement: Progress tracking for long-running tasks
- [ ] Common interview questions:
  - [ ] How do you handle long-running tasks?
  - [ ] What is the difference between sync and async tasks?

**Implementation tasks:**
- [ ] Implement file processing endpoint with progress updates

---


**Frontend Deep Dive: CSS and Rendering Performance**

**Tasks:**
- [ ] Read: CSS containment and will-change
- [ ] Implement: Measure layout thrashing
- [ ] Implement: Optimize render-blocking resources

**Concept exploration:**
- [ ] Composite-only properties
- [ ] GPU acceleration
- [ ] Critical CSS

**Behavioral Preparation: Time Management Story**

**Tasks:**
- [ ] Write STAR story about managing competing priorities
- [ ] Include: How you decided what to do first
- [ ] Practice: "Tell me about a time you had too much work"

**Revision tasks:**
- [ ] Review heap implementations
- [ ] Review background task patterns

---

## Day 12


**Topic:** Dynamic Programming - Basics

**Concepts to learn:**
- [ ] Recursion vs memoization vs tabulation
- [ ] State definition
- [ ] Base cases and transitions

**Coding problems:**
- [ ] Climbing Stairs (LeetCode 70) — DP — Basic
- [ ] Min Cost Climbing Stairs (LeetCode 746) — DP — Basic
- [ ] House Robber (LeetCode 198) — DP — State selection
- [ ] House Robber II (LeetCode 213) — DP — Circular array

**Implementation tasks:**
- [ ] Implement both top-down and bottom-up for same problem
- [ ] Practice converting recurrence to code

**Review tasks:**
- [ ] Memorize: DP is optimization over recursion
- [ ] Review: When to use 1D vs 2D DP

---


**System Design Exercise:** File Storage Service (Dropbox style)

**Tasks to complete:**
- [ ] Define functional requirements: upload, download, sync
- [ ] Define non-functional requirements: consistency, deduplication
- [ ] Design file storage architecture
- [ ] Design chunk upload for large files
- [ ] Handle sync conflicts
- [ ] Discuss metadata storage

**Backend Deep Dive: AWS S3 and Storage**

**Tasks:**
- [ ] Read: S3 best practices documentation
- [ ] Implement: Upload file to S3 with presigned URL
- [ ] Implement: Multipart upload for large files
- [ ] Common interview questions:
  - [ ] What is eventual consistency in S3?
  - [ ] How do you handle S3 failures?

**Implementation tasks:**
- [ ] Implement file upload endpoint using boto3

---


**Frontend Deep Dive: TypeScript for React**

**Tasks:**
- [ ] Read: React TypeScript cheatsheet
- [ ] Implement: Generic component with proper types
- [ ] Implement: Type-safe API response handling

**Concept exploration:**
- [ ] Utility types (Partial, Required, Pick)
- [ ] Generic components
- [ ] Event handler types

**Behavioral Preparation: Handling Ambiguity Story**

**Tasks:**
- [ ] Write STAR story about unclear requirements
- [ ] Include: How you got clarity, what you did
- [ ] Practice: "Tell me about a time requirements were unclear"

**Revision tasks:**
- [ ] Review DP basics
- [ ] Review S3 patterns

---

## Day 13


**Topic:** Dynamic Programming - Intermediate

**Concepts to learn:**
- [ ] 2D DP state
- [ ] String DP
- [ ] State machines

**Coding problems:**
- [ ] Longest Common Subsequence (LeetCode 1143) — DP — 2D
- [ ] Edit Distance (LeetCode 72) — DP — 2D — Hard
- [ ] Longest Increasing Subsequence (LeetCode 300) — DP — Binary search optimization
- [ ] Word Break (LeetCode 139) — DP — String

**Implementation tasks:**
- [ ] Implement LCS with space optimization to O(min(m,n))
- [ ] Practice drawing DP table

**Review tasks:**
- [ ] Memorize: LCS time complexity is O(m*n)
- [ ] Review: How to reconstruct solution from DP table

---


**System Design Exercise:** Design Netflix

**Tasks to complete:**
- [ ] Define functional requirements: streaming, recommendations
- [ ] Define non-functional requirements: buffering, quality adaptation
- [ ] Design video encoding pipeline
- [ ] Design CDN strategy
- [ ] Design recommendation system basics
- [ ] Discuss availability vs consistency

**Backend Deep Dive: Docker and Containerization**

**Tasks:**
- [ ] Read: Docker networking and volumes
- [ ] Implement: Multi-stage Dockerfile for Python app
- [ ] Implement: Docker-compose for app + database + redis
- [ ] Common interview questions:
  - [ ] What is the difference between COPY and ADD?
  - [ ] How do you reduce image size?

**Implementation tasks:**
- [ ] Write production-ready Dockerfile for Django/FastAPI app

---


**Frontend Deep Dive: React Testing**

**Tasks:**
- [ ] Read: React Testing Library best practices
- [ ] Implement: Write unit tests for a component
- [ ] Implement: Write integration test for user flow

**Concept exploration:**
- [ ] Testing vs implementation details
- [ ] Mocking API calls
- [ ] Coverage vs quality

**Behavioral Preparation: Situational Questions**

**Tasks:**
- [ ] Prepare answers for: "Why are you looking to change?"
- [ ] Prepare answers for: "What are you looking for in a new role?"
- [ ] Prepare answers for: "What is your greatest strength/weakness?"

**Revision tasks:**
- [ ] Review DP patterns
- [ ] Review Docker

---

## Day 14 — WEEKLY CHECKPOINT


**DSA Progress Review:**
- [ ] Trees (BST): 4 problems completed
- [ ] Graphs: 8 problems completed
- [ ] Heaps: 4 problems completed
- [ ] DP Basics: 4 problems completed
- [ ] DP Intermediate: 4 problems completed

**Total: 42 LeetCode problems solved**

**Revision tasks:**
- [ ] Re-solve 5 hardest problems from Week 2
- [ ] Identify which patterns need more practice

---


**System Design Understanding Review:**
- [ ] Job Queue: Completed
- [ ] Social Media Feed: Completed
- [ ] Twitter: Completed
- [ ] Search Autocomplete: Completed
- [ ] File Storage: Completed
- [ ] Netflix: Completed

**Backend Knowledge Review:**
- [ ] Celery: Completed
- [ ] REST API Design: Completed
- [ ] API Versioning: Completed
- [ ] FastAPI Background Tasks: Completed
- [ ] AWS S3: Completed
- [ ] Docker: Completed

**Revision tasks:**
- [ ] Review all 12 system designs
- [ ] Pick weakest 3 to re-practice

---


**Frontend Knowledge Review:**
- [ ] Network Performance: Completed
- [ ] Code Splitting: Completed
- [ ] Virtualization: Completed
- [ ] Rendering Performance: Completed
- [ ] TypeScript: Completed
- [ ] Testing: Completed

**Behavioral Progress:**
- [ ] Resume: 2 minutes prepared
- [ ] 5 STAR stories prepared
- [ ] Situational questions prepared

**Plan for Week 3:**
- [ ] Start DP hard problems
- [ ] Add more system designs
- [ ] Deepen backend knowledge

---

## Day 15 {#day-15}


**Topic:** Dynamic Programming - Hard

**Concepts to learn:**
- [ ] State reduction
- [ ] Space optimization
- [ ] Complex transitions

**Coding problems:**
- [ ] Regular Expression Matching (LeetCode 10) — DP — Hard
- [ ] Wildcard Matching (LeetCode 44) — DP — Hard
- [ ] Minimum Path Sum (LeetCode 64) — DP — 2D
- [ ] Longest Palindromic Substring (LeetCode 5) — DP

**Implementation tasks:**
- [ ] Implement wildcard matching with O(m*n) time, O(n) space
- [ ] Practice understanding state transitions

**Review tasks:**
- [ ] Memorize: Both pattern matching problems use 2D DP
- [ ] Review: Why space optimization matters

---


**System Design Exercise:** Design Uber/Lyft

**Tasks to complete:**
- [ ] Define functional requirements: matching, tracking, payments
- [ ] Define non-functional requirements: real-time, availability
- [ ] Design rider-driver matching system
- [ ] Design surge pricing logic
- [ ] Handle driver location updates
- [ ] Discuss dispatch algorithms

**Backend Deep Dive: PostgreSQL Transactions**

**Tasks:**
- [ ] Read: Transaction isolation levels documentation
- [ ] Implement: Demonstrate dirty read, non-repeatable read
- [ ] Implement: Use savepoints in transaction
- [ ] Common interview questions:
  - [ ] What is ACID?
  - [ ] Difference between READ COMMITTED and SERIALIZABLE?

**Implementation tasks:**
- [ ] Write transaction handling for bank transfer scenario

---


**Frontend Deep Dive: Web Security**

**Tasks:**
- [ ] Read: XSS, CSRF, CORS documentation
- [ ] Implement: Sanitize user input
- [ ] Implement: Handle CORS properly

**Concept exploration:**
- [ ] JWT vs Sessions
- [ ] HTTPS everywhere
- [ ] Content Security Policy

**Behavioral Preparation: Why This Company**

**Tasks:**
- [ ] Research 3 target companies
- [ ] Write 3 specific reasons for each
- [ ] Practice: "Why do you want to work at [Company]?"

**Revision tasks:**
- [ ] Review DP hard problems
- [ ] Review transactions

---

## Day 16


**Topic:** Backtracking

**Concepts to learn:**
- [ ] Choice, constraints, goal framework
- [ ] Pruning optimization
- [ ] Combination vs permutation

**Coding problems:**
- [ ] Subsets (LeetCode 78) — Backtracking — Generate all subsets
- [ ] Subsets II (LeetCode 90) — Backtracking — Handle duplicates
- [ ] Combination Sum (LeetCode 39) — Backtracking — Unbounded knapsack
- [ ] Permutations (LeetCode 46) — Backtracking — Generate permutations

**Implementation tasks:**
- [ ] Implement subsets iteratively and recursively
- [ ] Practice identifying when to prune

**Review tasks:**
- [ ] Memorize: Backtracking is O(n * 2^n) worst case
- [ ] Review: How to handle duplicate elements

---


**System Design Exercise:** Design Spotify

**Tasks to complete:**
- [ ] Define functional requirements: music streaming, playlists
- [ ] Define non-functional requirements: latency, audio quality
- [ ] Design music recommendation
- [ ] Design playlist management
- [ ] Handle offline playback
- [ ] Discuss licensing

**Backend Deep Dive: Redis Advanced Patterns**

**Tasks:**
- [ ] Read: Redis sorted sets and streams
- [ ] Implement: Leaderboard using sorted sets
- [ ] Implement: Pub/sub for real-time updates
- [ ] Common interview questions:
  - [ ] What is Redis persistence?
  - [ ] How do you handle Redis failure?

**Implementation tasks:**
- [ ] Implement rate limiter using sliding window algorithm

---


**Frontend Deep Dive: WebSockets and Real-time**

**Tasks:**
- [ ] Read: WebSocket vs HTTP long-polling vs SSE
- [ ] Implement: React component with WebSocket
- [ ] Implement: Reconnection logic

**Concept exploration:**
- [ ] Heartbeat/ping-pong
- [ ] Message acknowledgment
- [ ] Scaling WebSocket servers

**Behavioral Preparation: Negotiation Story**

**Tasks:**
- [ ] Write story about negotiating scope, timeline, or resources
- [ ] Include: How you approached it, outcome
- [ ] Practice: "Tell me about a time you negotiated"

**Revision tasks:**
- [ ] Review backtracking patterns
- [ ] Review Redis patterns

---

## Day 17


**Topic:** Backtracking - Advanced

**Concepts to learn:**
- [ ] Constraint satisfaction
- [ ] N-Queens pattern
- [ ] Sudoku solving

**Coding problems:**
- [ ] N-Queens (LeetCode 51) — Backtracking — Hard
- [ ] N-Queens II (LeetCode 52) — Backtracking — Count solutions
- [ ] Letter Combinations of a Phone Number (LeetCode 17) — Backtracking
- [ ] Restore IP Addresses (LeetCode 93) — Backtracking — Validation

**Implementation tasks:**
- [ ] Implement N-Queens with position validation
- [ ] Practice pruning invalid states early

**Review tasks:**
- [ ] Memorize: N-Queens uses 3 sets for column/diag constraints
- [ ] Review: How to convert problem to backtracking

---


**System Design Exercise:** Design Google Docs

**Tasks to complete:**
- [ ] Define functional requirements: real-time editing, collaboration
- [ ] Define non-functional requirements: consistency, latency
- [ ] Design operational transformation (OT) or CRDT
- [ ] Handle conflict resolution
- [ ] Design undo/redo
- [ ] Discuss storage strategy

**Backend Deep Dive: Distributed Systems Basics**

**Tasks:**
- [ ] Read: CAP theorem and trade-offs
- [ ] Implement: Simple distributed lock
- [ ] Implement: Retry with exponential backoff
- [ ] Common interview questions:
  - [ ] What is eventual consistency?
  - [ ] How do you handle network partitions?

**Implementation tasks:**
- [ ] Implement idempotent API endpoint

---


**Frontend Deep Dive: SSR and Next.js**

**Tasks:**
- [ ] Read: Next.js rendering strategies
- [ ] Implement: Page with getServerSideProps
- [ ] Implement: Static generation with dynamic routes

**Concept exploration:**
- [ ] Hydration
- [ ] Streaming SSR
- [ ] Edge functions

**Behavioral Preparation: Innovation Story**

**Tasks:**
- [ ] Write story about introducing something new
- [ ] Include: What you saw, what you built, adoption
- [ ] Practice: "Tell me about an innovation you brought"

**Revision tasks:**
- [ ] Review backtracking
- [ ] Review distributed systems concepts

---

## Day 18


**Topic:** Greedy Algorithms

**Concepts to learn:**
- [ ] Greedy choice property
- [ ] Local vs global optimum
- [ ] When greedy fails

**Coding problems:**
- [ ] Jump Game (LeetCode 55) — Greedy — Forward traversal
- [ ] Jump Game II (LeetCode 45) — Greedy — Minimum jumps
- [ ] Meeting Rooms II (LeetCode 253) — Greedy — Min heap
- [ ] Task Scheduler (LeetCode 621) — Greedy — Formula

**Implementation tasks:**
- [ ] Implement meeting rooms with heap
- [ ] Practice proving greedy correctness

**Review tasks:**
- [ ] Memorize: Greedy works when local optimal leads to global optimal
- [ ] Review: Difference between Jump Game I and II

---


**System Design Exercise:** Design Airbnb

**Tasks to complete:**
- [ ] Define functional requirements: listings, booking, search
- [ ] Define non-functional requirements: availability, consistency
- [ ] Design booking system with date locking
- [ ] Design search with filters
- [ ] Handle payments
- [ ] Discuss review system

**Backend Deep Dive: Message Queues (Kafka)**

**Tasks:**
- [ ] Read: Kafka architecture documentation
- [ ] Implement: Producer and consumer
- [ ] Implement: Consumer groups
- [ ] Common interview questions:
  - [ ] What is message ordering in Kafka?
  - [ ] How do you handle message duplication?

**Implementation tasks:**
- [ ] Build simple producer/consumer with Kafka

---


**Frontend Deep Dive: Micro-frontends**

**Tasks:**
- [ ] Read: Micro-frontend architecture patterns
- [ ] Implement: Module federation config
- [ ] Implement: Shared component library

**Concept exploration:**
- [ ] Independent deployment
- [ ] Communication patterns
- [ ] Testing challenges

**Behavioral Preparation: Overcoming Obstacle Story**

**Tasks:**
- [ ] Write story about technical challenge you overcame
- [ ] Include: What made it hard, how you solved it
- [ ] Practice: "Tell me about a technical challenge"

**Revision tasks:**
- [ ] Review greedy algorithms
- [ ] Review Kafka

---

## Day 19


**Topic:** Union Find / DSU

**Concepts to learn:**
- [ ] Find with path compression
- [ ] Union by rank
- [ ] Cycle detection in graphs

**Coding problems:**
- [ ] Number of Connected Components (LeetCode 323) — DSU
- [ ] Longest Consecutive Sequence (LeetCode 128) — DSU
- [ ] Graph Valid Tree (LeetCode 261) — DSU
- [ ] Number of Islands II (LeetCode 305) — DSU — Hard

**Implementation tasks:**
- [ ] Implement DSU with both optimizations
- [ ] Compare with BFS/DFS approach

**Review tasks:**
- [ ] Memorize: DSU nearly O(1) amortized
- [ ] Review: When to use DSU vs DFS

---


**System Design Exercise:** Design WhatsApp

**Tasks to complete:**
- [ ] Define functional requirements: messaging, groups, status
- [ ] Define non-functional requirements: delivery, ordering
- [ ] Design message storage
- [ ] Design end-to-end encryption
- [ ] Handle media storage
- [ ] Discuss message synchronization

**Backend Deep Dive: Celery Deep Dive**

**Tasks:**
- [ ] Read: Celery task routing and priority queues
- [ ] Implement: Task with chain and chord
- [ ] Implement: Custom task states
- [ ] Common interview questions:
  - [ ] How do you handle tasks that take too long?
  - [ ] What is result backend?

**Implementation tasks:**
- [ ] Build task pipeline: fetch -> process -> save -> notify

---


**Frontend Deep Dive: React Performance Patterns**

**Tasks:**
- [ ] Read: React performance optimization checklist
- [ ] Implement: Optimistic updates
- [ ] Implement: Debounced search input

**Concept exploration:**
- [ ] useTransition vs useDeferredValue
- [ ] Automatic batching
- [ ] Suspense for data fetching

**Behavioral Preparation: Success Story**

**Tasks:**
- [ ] Write story about biggest achievement
- [ ] Include: What you did, impact, recognition
- [ ] Practice: "What is your biggest professional achievement?"

**Revision tasks:**
- [ ] Review DSU patterns
- [ ] Review Celery

---

## Day 20


**Topic:** Bit Manipulation

**Concepts to learn:**
- [ ] Bitwise operations
- [ ] Two's complement
- [ ] Common patterns

**Coding problems:**
- [ ] Number of 1 Bits (LeetCode 191) — Bit — Hamming weight
- [ ] Reverse Bits (LeetCode 190) — Bit — Bit swapping
- [ ] Single Number (LeetCode 136) — Bit — XOR trick
- [ ] Missing Number (LeetCode 268) — Bit — XOR

**Implementation tasks:**
- [ ] Implement all bit operations from scratch
- [ ] Practice XOR properties

**Review tasks:**
- [ ] Memorize: XOR a^a = 0, a^0 = a
- [ ] Review: How to count bits efficiently

---


**System Design Exercise:** Design Ticketmaster/Eventbrite

**Tasks to complete:**
- [ ] Define functional requirements: events, seats, booking
- [ ] Define non-functional requirements: high concurrency, fairness
- [ ] Design seat selection
- [ ] Handle double booking
- [ ] Design waiting room
- [ ] Discuss anti-scalping

**Backend Deep Dive: Distributed Locks**

**Tasks:**
- [ ] Read: Redis distributed lock patterns
- [ ] Implement: Lock with TTL and renewal
- [ ] Implement: Redlock algorithm
- [ ] Common interview questions:
  - [ ] What are the problems with distributed locks?
  - [ ] How do you handle lock expiration?

**Implementation tasks:**
- [ ] Implement distributed mutex

---


**Frontend Deep Dive: Build Tools and Bundling**

**Tasks:**
- [ ] Read: How bundlers work (Webpack, Vite, Esbuild)
- [ ] Implement: Simple bundler
- [ ] Implement: Babel transform

**Concept exploration:**
- [ ] Module resolution
- [ ] Tree shaking mechanism
- [ ] Hot module replacement

**Behavioral Preparation: New Skill Story**

**Tasks:**
- [ ] Write story about learning new technology quickly
- [ ] Include: What you learned, how you applied it
- [ ] Practice: "Tell me about a time you learned something fast"

**Revision tasks:**
- [ ] Review bit manipulation
- [ ] Review distributed locks

---

## Day 21 — WEEKLY CHECKPOINT


**DSA Progress Review:**
- [ ] DP Hard: 4 problems completed
- [ ] Backtracking: 8 problems completed
- [ ] Greedy: 4 problems completed
- [ ] DSU: 4 problems completed
- [ ] Bit Manipulation: 4 problems completed

**Total: 66 LeetCode problems solved**

**Revision tasks:**
- [ ] Focus on weak areas: DP hard, backtracking
- [ ] Re-solve problems without looking

---


**System Design Understanding Review:**
- [ ] Uber: Completed
- [ ] Spotify: Completed
- [ ] Google Docs: Completed
- [ ] Airbnb: Completed
- [ ] WhatsApp: Completed
- [ ] Ticketmaster: Completed

**Backend Knowledge Review:**
- [ ] PostgreSQL Transactions: Completed
- [ ] Redis Advanced: Completed
- [ ] Distributed Systems: Completed
- [ ] Kafka: Completed
- [ ] Celery Deep Dive: Completed
- [ ] Distributed Locks: Completed

**Plan for Week 4:**
- [ ] Complete remaining DSA topics
- [ ] Add more system designs
- [ ] Start frontend deep dives

---


**Frontend Knowledge Review:**
- [ ] Web Security: Completed
- [ ] WebSockets: Completed
- [ ] SSR/Next.js: Completed
- [ ] Micro-frontends: Completed
- [ ] React Performance: Completed
- [ ] Build Tools: Completed

**Behavioral Progress:**
- [ ] All STAR stories prepared
- [ ] Company-specific answers prepared

**Weaknesses to address:**
- [ ] Note any remaining gaps
- [ ] Plan for Day 30+ mock interviews

---

## Day 22


**Topic:** Tries (Prefix Trees)

**Concepts to learn:**
- [ ] Trie node structure
- [ ] Insert, search, prefix search
- [ ] Space optimization

**Coding problems:**
- [ ] Implement Trie (LeetCode 208) — Trie — Basic implementation
- [ ] Word Search II (LeetCode 212) — Trie + Backtracking — Hard
- [ ] Replace Words (LeetCode 648) — Trie
- [ ] Maximum XOR of Two Numbers (LeetCode 421) — Trie — Hard

**Implementation tasks:**
- [ ] Implement Trie with all operations
- [ ] Compare with hash table for prefix queries

**Review tasks:**
- [ ] Memorize: Trie search is O(m) where m is word length
- [ ] Review: When Trie is better than hash table

---


**System Design Exercise:** Design YouTube

**Tasks to complete:**
- [ ] Define functional requirements: upload, stream, recommendations
- [ ] Define non-functional requirements: buffering, quality
- [ ] Design video transcoding pipeline
- [ ] Design recommendation engine basics
- [ ] Handle millions of views
- [ ] Discuss CDN strategy

**Backend Deep Dive: Django ORM Querysets**

**Tasks:**
- [ ] Read: Django queryset internals
- [ ] Implement: Custom queryset methods
- [ ] Implement: Manager with custom methods
- [ ] Common interview questions:
  - [ ] What is select_related vs prefetch_related?
  - [ ] How does bulk_create work?

**Implementation tasks:**
- [ ] Optimize N+1 query in existing project code

---


**Frontend Deep Dive: CSS Architecture**

**Tasks:**
- [ ] Read: BEM, CSS Modules, CSS-in-JS approaches
- [ ] Implement: Theme system with CSS variables
- [ ] Implement: Responsive component

**Concept exploration:**
- [ ] Atomic CSS
- [ ] CSS-in-JS runtime cost
- [ ] Design tokens

**Behavioral Preparation: Communication Story**

**Tasks:**
- [ ] Write story about explaining technical concept to non-technical person
- [ ] Include: How you simplified, outcome
- [ ] Practice: "Explain [technical topic] to a 5-year-old"

**Revision tasks:**
- [ ] Review Trie implementations
- [ ] Review Django ORM

---

## Day 23


**Topic:** Sliding Window - Advanced

**Concepts to learn:**
- [ ] Fixed window with data structures
- [ ] Variable window tracking multiple conditions

**Coding problems:**
- [ ] Longest Repeating Character Replacement (LeetCode 424) — Sliding window
- [ ] Fruit Into Baskets (LeetCode 904) — Sliding window
- [ ] Minimum Size Subarray Sum (LeetCode 209) — Sliding window
- [ ] Longest Subarray with Ones after Replacement (LeetCode 424 variant)

**Implementation tasks:**
- [ ] Implement all with proper window management
- [ ] Practice different window conditions

**Review tasks:**
- [ ] Memorize: Character replacement uses frequency count
- [ ] Review: How to handle multiple conditions

---


**System Design Exercise:** Design Amazon/Library System

**Tasks to complete:**
- [ ] Define functional requirements: inventory, recommendations
- [ ] Define non-functional requirements: consistency
- [ ] Design inventory management
- [ ] Design recommendation system
- [ ] Handle returns and refunds
- [ ] Discuss scalability

**Backend Deep Dive: FastAPI Dependency Injection**

**Tasks:**
- [ ] Read: FastAPI dependency injection system
- [ ] Implement: Custom dependency with cache
- [ ] Implement: Scoped dependencies (request-level)
- [ ] Common interview questions:
  - [ ] How does FastAPI manage dependencies?
  - [ ] What is Depends()?

**Implementation tasks:**
- [ ] Implement authentication dependency

---


**Frontend Deep Dive: Accessibility (a11y)**

**Tasks:**
- [ ] Read: WCAG guidelines
- [ ] Implement: Accessible form components
- [ ] Implement: Screen reader testing

**Concept exploration:**
- [ ] ARIA attributes
- [ ] Keyboard navigation
- [ ] Color contrast

**Behavioral Preparation: Mentorship Story**

**Tasks:**
- [ ] Write story about mentoring someone
- [ ] Include: What you taught, how you helped them grow
- [ ] Practice: "Tell me about mentoring someone"

**Revision tasks:**
- [ ] Review sliding window advanced
- [ ] Review FastAPI DI

---

## Day 24


**Topic:** Interval Problems

**Concepts to learn:**
- [ ] Sorting intervals by start/end
- [ ] Merging overlapping intervals
- [ ] Scheduling problems

**Coding problems:**
- [ ] Merge Intervals (LeetCode 56) — Intervals
- [ ] Insert Interval (LeetCode 57) — Intervals
- [ ] Meeting Rooms (LeetCode 252) — Intervals
- [ ] Minimum Number of Arrows to Burst Balloons (LeetCode 452) — Intervals

**Implementation tasks:**
- [ ] Implement merge intervals cleanly
- [ ] Practice interval comparison logic

**Review tasks:**
- [ ] Memorize: Sort by start time for merge
- [ ] Review: Difference between Meeting Rooms I and II

---


**System Design Exercise:** Design E-commerce Cart/Checkout

**Tasks to complete:**
- [ ] Define functional requirements: cart, payment, inventory
- [ ] Define non-functional requirements: consistency, availability
- [ ] Design cart persistence
- [ ] Design checkout flow
- [ ] Handle payment processing
- [ ] Discuss inventory reservation

**Backend Deep Dive: API Security**

**Tasks:**
- [ ] Read: JWT, OAuth, API keys
- [ ] Implement: JWT authentication
- [ ] Implement: Rate limiting decorator
- [ ] Common interview questions:
  - [ ] What is the difference between JWT and session?
  - [ ] How do you prevent CSRF?

**Implementation tasks:**
- [ ] Implement refresh token rotation

---


**Frontend Deep Dive: State Machines in React**

**Tasks:**
- [ ] Read: XState basics
- [ ] Implement: Simple state machine for UI
- [ ] Implement: Complex form with state machine

**Concept exploration:**
- [ ] Unidirectional data flow
- [ ] Predictable state transitions
- [ ] Testing benefits

**Behavioral Preparation: Difficult Coworker Story**

**Tasks:**
- [ ] Write story about working with difficult person
- [ ] Include: How you handled it professionally
- [ ] Practice: "Tell me about a difficult coworker"

**Revision tasks:**
- [ ] Review interval patterns
- [ ] Review API security

---

## Day 25


**Topic:** Math and Geometry

**Concepts to learn:**
- [ ] Prime numbers
- [ ] GCD/LCM
- [ ] Matrix rotation

**Coding problems:**
- [ ] Rotate Image (LeetCode 48) — Matrix
- [ ] Spiral Matrix (LeetCode 54) — Matrix
- [ ] Count Primes (LeetCode 204) — Math
- [ ] Pow(x, n) (LeetCode 50) — Math — Binary exponentiation

**Implementation tasks:**
- [ ] Implement matrix rotation in-place
- [ ] Implement Sieve of Eratosthenes

**Review tasks:**
- [ ] Memorize: Matrix rotation is 4-way swap
- [ ] Review: Fast power reduces multiplications to O(log n)

---


**System Design Exercise:** Design Payment System

**Tasks to complete:**
- [ ] Define functional requirements: process, refund, dispute
- [ ] Define non-functional requirements: security, reliability
- [ ] Design payment flow
- [ ] Handle failed payments
- [ ] Design idempotency
- [ ] Discuss PCI compliance

**Backend Deep Dive: WebSocket Systems**

**Tasks:**
- [ ] Read: WebSocket protocol
- [ ] Implement: FastAPI WebSocket endpoint
- [ ] Implement: Connection management
- [ ] Common interview questions:
  - [ ] How do you handle WebSocket failures?
  - [ ] How do you scale WebSockets?

**Implementation tasks:**
- [ ] Build real-time chat with WebSocket

---


**Frontend Deep Dive: Error Handling**

**Tasks:**
- [ ] Read: Error boundaries in React
- [ ] Implement: Global error handler
- [ ] Implement: Retry logic for failed requests

**Concept exploration:**
- [ ] Graceful degradation
- [ ] Error reporting
- [ ] User feedback

**Behavioral Preparation: Career Goals**

**Tasks:**
- [ ] Write 1-year and 5-year career goals
- [ ] Align with target companies
- [ ] Practice: "Where do you see yourself in 5 years?"

**Revision tasks:**
- [ ] Review math/geometry
- [ ] Review WebSocket

---

## Day 26


**Topic:** String Manipulation

**Concepts to learn:**
- [ ] String building
- [ ] Pattern matching
- [ ] Anagram detection

**Coding problems:**
- [ ] Longest Substring with At Least K Repeating Characters (LeetCode 395) — String
- [ ] Find All Anagrams in a String (LeetCode 438) — String
- [ ] Minimum Window Substring (LeetCode 76) — String — Review
- [ ] Rabin-Karp Algorithm (LeetCode implement) — String

**Implementation tasks:**
- [ ] Implement substring search with sliding window
- [ ] Practice string building efficiently

**Review tasks:**
- [ ] Review: All sliding window problems
- [ ] Review: Anagram detection techniques

---


**System Design Exercise:** Design Notification System (Advanced)

**Tasks to complete:**
- [ ] Define functional requirements: push, email, SMS
- [ ] Define non-functional requirements: delivery, ordering
- [ ] Design notification preferences
- [ ] Handle unsubscribes
- [ ] Design template system
- [ ] Discuss delivery guarantees

**Backend Deep Dive: Async Pipelines**

**Tasks:**
- [ ] Read: Async processing patterns
- [ ] Implement: Pipeline with multiple stages
- [ ] Implement: Dead letter queue handling
- [ ] Common interview questions:
  - [ ] How do you handle partial failures?
  - [ ] What is the outbox pattern?

**Implementation tasks:**
- [ ] Implement reliable event publishing

---


**Frontend Deep Dive: Internationalization**

**Tasks:**
- [ ] Read: i18n approaches
- [ ] Implement: react-intl setup
- [ ] Implement: Date/number formatting

**Concept exploration:**
- [ ] Translation loading
- [ ] RTL support
- [ ] Locale-specific formatting

**Behavioral Preparation: Asking for Help Story**

**Tasks:**
- [ ] Write story about when you needed help
- [ ] Include: How you asked, what you learned
- [ ] Practice: "How do you ask for help?"

**Revision tasks:**
- [ ] Review string problems
- [ ] Review async pipelines

---

## Day 27


**Topic:** Design Patterns

**Concepts to learn:**
- [ ] Singleton, Factory, Observer
- [ ] Strategy, Repository, Builder

**Coding problems:**
- [ ] Implement Singleton (coding interview)
- [ ] Design Tic-Tac-Toe (LeetCode 348) — Design
- [ ] Design HashMap (LeetCode 706) — Design
- [ ] LRU Cache (LeetCode 146) — Design

**Implementation tasks:**
- [ ] Implement LRU cache with hash map + doubly linked list
- [ ] Practice explaining design choices

**Review tasks:**
- [ ] Memorize: When to use each pattern
- [ ] Review: LRU uses hash map + doubly linked list

---


**System Design Exercise:** Design Logging/Monitoring System

**Tasks to complete:**
- [ ] Define functional requirements: collect, search, alert
- [ ] Define non-functional requirements: throughput, retention
- [ ] Design log aggregation
- [ ] Design metrics collection
- [ ] Design alerting system
- [ ] Discuss Elasticsearch usage

**Backend Deep Dive: Testing Strategies**

**Tasks:**
- [ ] Read: Testing pyramid
- [ ] Implement: Unit tests with pytest
- [ ] Implement: Integration tests with fixtures
- [ ] Common interview questions:
  - [ ] How do you test async code?
  - [ ] What is mock vs stub?

**Implementation tasks:**
- [ ] Write tests with 80% coverage on a module

---


**Frontend Deep Dive: React Patterns**

**Tasks:**
- [ ] Read: Compound components, Render props, HOCs
- [ ] Implement: Compound component pattern
- [ ] Implement: Custom hook

**Concept exploration:**
- [ ] When to use each pattern
- [ ] Trade-offs
- [ ] React patterns in popular libraries

**Behavioral Preparation: Feedback Story**

**Tasks:**
- [ ] Write story about receiving difficult feedback
- [ ] Include: How you reacted, what you changed
- [ ] Practice: "Tell me about receiving feedback"

**Revision tasks:**
- Review design patterns
- Review testing

---

## Day 28


**Topic:** Database Design

**Concepts to learn:**
- [ ] ER diagrams
- [ ] Normalization (1NF, 2NF, 3NF)
- [ ] Denormalization trade-offs

**Coding problems:**
- [ ] Design SQL Schema (various)
- [ ] SQL queries for typical problems
- [ ] Join exercises
- [ ] Subquery practice

**Implementation tasks:**
- [ ] Design database for blog system
- [ ] Write complex queries with JOINs

**Review tasks:**
- [ ] Memorize: Normal forms
- [ ] Review: When to denormalize

---


**System Design Exercise:** Design Code Review System

**Tasks to complete:**
- [ ] Define functional requirements: submit, review, approve
- [ ] Define non-functional requirements: notifications
- [ ] Design code diff storage
- [ ] Design review workflow
- [ ] Handle merge conflicts
- [ ] Discuss CI/CD integration

**Backend Deep Dive: Migrations and Schema Changes**

**Tasks:**
- [ ] Read: Django migrations best practices
- [ ] Implement: Safe migration for large table
- [ ] Implement: Data migration with Django
- [ ] Common interview questions:
  - [ ] How do you handle migrations on production?
  - [ ] What is zero-downtime migration?

**Implementation tasks:**
- [ ] Implement migration for adding column with default

---


**Frontend Deep Dive: Animation**

**Tasks:**
- [ ] Read: CSS animations vs JS animations
- [ ] Implement: Framer Motion animations
- [ ] Implement: Complex gesture animations

**Concept exploration:**
- [ ] Performance considerations
- [ ] Accessibility concerns
- [ ] Libraries comparison

**Behavioral Preparation: Ownership Story**

**Tasks:**
- [ ] Write story about owning a project end-to-end
- [ ] Include: What you were responsible for, outcomes
- [ ] Practice: "Tell me about a project you owned"

**Revision tasks:**
- Review database design
- Review migrations

---

## Day 29


**Topic:** Mock Interview - Arrays and Strings

**Practice tasks:**
- [ ] Two Sum - solve in 15 minutes
- [ ] Longest Substring Without Repeating - solve in 20 minutes
- [ ] Practice thinking out loud

**Evaluation criteria:**
- [ ] Did you clarify the problem?
- [ ] Did you consider edge cases?
- [ ] Did you discuss time/space complexity?
- [ ] Was your code clean?

---


**System Design Mock: URL Shortener**

**Practice tasks:**
- [ ] Define requirements in 5 minutes
- [ ] Design high-level architecture in 10 minutes
- [ ] Deep dive into components in 15 minutes
- [ ] Discuss scaling in 10 minutes

**Evaluation criteria:**
- [ ] Did you ask clarifying questions?
- [ ] Did you cover functional and non-functional requirements?
- [ ] Did you discuss trade-offs?
- [ ] Could you answer follow-up questions?

---


**Frontend Mock: React Component**

**Practice tasks:**
- [ ] Build a component from scratch
- [ ] Add state management
- [ ] Optimize for performance

**Evaluation criteria:**
- [ ] Did you plan component structure?
- [ ] Did you handle edge cases?
- [ ] Did you consider accessibility?

---

## Day 30 — MOCK INTERVIEW WEEK BEGINS


**Mock Interview 1: DSA (Easy/Medium)**

**Instructions:**
- Set timer for 30 minutes
- Pick problem: Merge Intervals (LeetCode 56)
- Solve as if in real interview
- Think out loud throughout
- After solving, note what went well and what to improve

**Time allocation:**
- Clarification: 3 minutes
- Algorithm: 10 minutes
- Code: 15 minutes
- Test: 5 minutes

---


**Mock Interview 2: System Design**

**Instructions:**
- Set timer for 40 minutes
- Problem: Design a Chat Application
- Follow system design framework:
  1. Clarify requirements (5 min)
  2. High-level design (10 min)
  3. Deep dive (15 min  )
  4. Wrap up (5 min)
- Speak continuously

---


**Mock Interview 3: Behavioral**

**Instructions:**
- Set timer for 20 minutes
- Answer 3 behavioral questions:
  1. Tell me about yourself (2 min)
  2. Why do you want to join? (3 min)
  3. Project deep dive (10 min)
- Record yourself and review

---

## Day 31


**Mock Interview 4: DSA (Medium)**

**Instructions:**
- Set timer for 30 minutes
- Problem: Number of Islands (LeetCode 200)
- Practice BFS and DFS approaches
- Compare both

**Problems to practice:**
- [ ] Clone Graph
- [ ] Pacific Atlantic Water Flow
- [ ] Walls and Gates

---


**Mock Interview 5: System Design**

**Instructions:**
- Set timer for 40 minutes
- Problem: Design Twitter
- Focus on feed generation
- Discuss trade-offs between approaches

---


**Mock Interview 6: Frontend**

**Instructions:**
- Set timer for 30 minutes
- Problem: Build a Todo App
- Include all CRUD operations
- Add persistence
- Style it properly

---

## Day 32


**Mock Interview 7: DSA (Medium/Hard)**

**Instructions:**
- Set timer for 35 minutes
- Problem: Longest Increasing Subsequence (LeetCode 300)
- Solve with both DP and binary search
- Explain both approaches

**Problems to practice:**
- [ ] Word Break
- [ ] Coin Change
- [ ] Edit Distance

---


**Mock Interview 8: Backend Deep Dive**

**Instructions:**
- Set timer for 30 minutes
- Topic: Django/FastAPI questions
- Common questions:
  - [ ] Explain Django request lifecycle
  - [ ] How does async work in FastAPI?
  - [ ] How would you optimize a slow query?
  - [ ] Explain database transactions

---


**Mock Interview 9: Behavioral**

**Instructions:**
- Set timer for 25 minutes
- STAR method practice:
  - [ ] Conflict resolution (5 min)
  - [ ] Technical challenge (5 min)
  - [ ] Leadership (5 min)
  - [ ] Failure (5 min)

---

## Day 33


**Mock Interview 10: DSA (Hard)**

**Instructions:**
- Set timer for 40 minutes
- Problem: Merge K Sorted Lists (LeetCode 23)
- Solve with heap approach
- Optimize to O(N log k)

**Problems to practice:**
- [ ] Median of Data Stream
- [ ] Sliding Window Maximum
- [ ] Top K Frequent Elements

---


**Mock Interview 11: System Design**

**Instructions:**
- Set timer for 40 minutes
- Problem: Design YouTube
- Focus on video streaming
- Discuss CDN and caching

---


**Mock Interview 12: Full Stack**

**Instructions:**
- Set timer for 45 minutes
- Build REST API + frontend
- Connect frontend to backend
- Handle errors gracefully

---

## Day 34


**Mock Interview 13: DSA**

**Instructions:**
- Set timer for 30 minutes
- Problem: Binary Tree Level Order
- Solve with BFS and DFS
- Compare approaches

**Problems to practice:**
- [ ] Validate BST
- [ ] LCA
- [ ] Invert Binary Tree

---


**Mock Interview 14: System Design**

**Instructions:**
- Set timer for 40 minutes
- Problem: Design Airbnb
- Focus on booking system
- Discuss concurrency

---


**Mock Interview 15: Frontend Deep**

**Instructions:**
- Set timer for 30 minutes
- React questions:
  - [ ] How does reconciliation work?
  - [ ] When would you use useMemo?
  - [ ] Explain the component lifecycle

---

## Day 35


**Mock Interview 16: Behavioral + Resume**

**Instructions:**
- Set timer for 30 minutes
- Full resume walkthrough
- Deep dive into 2 projects
- Ask for feedback

---


**Mock Interview 17: System Design**

**Instructions:**
- Set timer for 40 minutes
- Problem: Design Notification System
- Include email, push, SMS
- Discuss reliability

---


**Weakness Identification**

**Tasks:**
- [ ] Review all mock interviews
- [ ] Identify 3 biggest weaknesses
- [ ] Create targeted practice plan
- [ ] Focus remaining days on weaknesses

---

## Day 36


**Focus: DP Weakness**

**Practice tasks:**
- [ ] Regular Expression Matching - 30 min
- [ ] Wildcard Matching - 30 min
- [ ] Edit Distance - 30 min
- [ ] Review solutions and patterns

**Key insights:**
- [ ] State definition is critical
- [ ] Base case handling
- [ ] Space optimization

---


**Focus: System Design Weakness**

**Practice tasks:**
- [ ] Pick 3 weakest system designs
- [ ] Redesign from scratch
- [ ] Compare with reference solutions
- [ ] Note common patterns

---


**Focus: Frontend Weakness**

**Practice tasks:**
- [ ] Pick React topics you're weak on
- [ ] Build small examples
- [ ] Read documentation thoroughly

---

## Day 37


**Focus: Backend Deep Dive**

**Practice tasks:**
- [ ] Write database migration with data - 45 min
- [ ] Implement Redis distributed lock - 45 min
- [ ] Write unit tests with mocking - 30 min

---


**Focus: System Design Practice**

**Practice tasks:**
- [ ] Design Amazon - 45 min
- [ ] Design WhatsApp - 45 min
- [ ] Review and self-evaluate - 30 min

---


**Focus: Behavioral Final Prep**

**Practice tasks:**
- [ ] All 10 stories: 2 min each
- [ ] Record and review
- [ ] Remove all filler words

---

## Day 38


**Focus: Final DSA Practice (Easy/Medium)**

**Practice tasks:**
- [ ] Two Pointers: 15 min each
- [ ] Sliding Window: 15 min each
- [ ] Binary Search: 15 min each
- [ ] BFS/DFS: 15 min each

**Goal:** Solve quickly with clean code

---


**Focus: Final System Design**

**Practice tasks:**
- [ ] Design Uber - 40 min
- [ ] Design Netflix - 40 min
- [ ] Design Ticketmaster - 40 min

**Focus:** Speed and confidence

---


**Focus: Mock Interview Routine**

**Tasks:**
- [ ] Light practice
- [ ] Prepare materials for tomorrow
- [ ] Get good rest

---

## Day 39


**Focus: Final Mock Day 1**

**Mock 1: DSA - 30 min**
- [ ] Problem: Medium difficulty
- [ ] Focus on communication

**Mock 2: System Design - 40 min**
- [ ] Pick random system
- [ ] Full interview simulation

**Mock 3: Behavioral - 20 min**
- [ ] Full interview simulation

---


**Focus: Final Mock Day 2**

**Mock 4: Frontend - 30 min**
- [ ] Build component

**Mock 5: Backend - 30 min**
- [ ] Deep technical questions

**Mock 6: Behavioral - 20 min**
- [ ] Situational questions

---


**Review and Rest**

**Tasks:**
- [ ] Review today's mocks
- [ ] Note final improvements
- [ ] Relax and rest

---

## Day 40


**Focus: Company-Specific Prep**

**Tasks:**
- [ ] Research 3 target companies
- [ ] Study their tech stack
- [ ] Look up recent news
- [ ] Prepare specific questions

---


**Focus: System Design Final**

**Practice tasks:**
- [ ] Design 2 systems
- [ ] Focus on clarity
- [ ] Practice speaking continuously

---


**Focus: Behavioral Final**

**Practice tasks:**
- [ ] All stories: perfect timing
- [ ] All company answers ready
- [ ] Questions to ask prepared

---

## Day 41


**Focus: Last DSA Push**

**Practice tasks:**
- [ ] Medium problems - 8 problems
- [ ] Focus on clean solutions
- [ ] Time yourself: 15 min per problem

---


**Focus: Mock Interviews**

**Practice tasks:**
- [ ] 2 full mock interviews
- [ ] 1 system design
- [ ] 1 behavioral

---


**Focus: Prep Day**

**Tasks:**
- [ ] Prepare outfit
- [ ] Check tech setup
- [ ] Prepare questions list
- [ ] Review logistics

---

## Day 42


**Focus: Light Practice**

**Tasks:**
- [ ] 3 easy problems
- [ ] 2 system designs
- [ ] Relax

---


**Focus: Final Prep**

**Tasks:**
- [ ] Review all STAR stories
- [ ] Review all system designs
- [ ] Review common technical questions

---


**Focus: Rest**

**Tasks:**
- [ ] Get good sleep
- [ ] Stay calm
- [ ] Believe in yourself

---

## Day 43

**Interview Day 1**

**Focus:**
- [ ] Morning interview
- [ ] Afternoon interview
- [ ] Review after each

**Evening:**
- [ ] Brief review
- [ ] Rest

---

## Day 44

**Interview Day 2**

**Focus:**
- [ ] Follow-up interviews
- [ ] Final rounds
- [ ] Thank you notes

**Evening:**
- [ ] Reflect
- [ ] Plan next steps

---

## Day 45 — FINAL CHECKPOINT


**Final Self-Assessment:**

**DSA Progress:**
- [ ] Total problems solved: 100+
- [ ] Strong areas: Arrays, Trees, Graphs, DP Basics
- [ ] Weak areas identified: Backtracking, Hard DP

**System Design:**
- [ ] Systems practiced: 20+
- [ ] Confident with: URL shortener, Chat, Twitter, Uber
- [ ] Need more practice: Payment systems, Logging

**Backend:**
- [ ] Django: Strong
- [ ] FastAPI: Strong
- [ ] PostgreSQL: Strong
- [ ] Redis: Strong

**Frontend:**
- [ ] React: Strong
- [ ] Performance: Strong
- [ ] TypeScript: Strong

**Behavioral:**
- [ ] 10 STAR stories: Ready
- [ ] Company-specific answers: Ready

---


**Final Improvements Needed:**

1. [ ] Continue daily LeetCode
2. [ ] Keep practicing system design
3. [ ] Read more about company-specific tech
4. [ ] Stay updated on industry trends

---


**Ongoing Roadmap:**

**Week 1-2 post-interview:**
- [ ] Review any feedback
- [ ] Keep practicing 2 problems daily

**Month 1-3:**
- [ ] System design once weekly
- [ ] Mock interview monthly

**Resources to continue:**
- [ ] LeetCode premium
- [ ] Exponent
- [ ] System Design Primer
- [ ] Tech blogs

---

## Summary: 45-Day Achievement

**DSA:** 100+ problems solved covering all major patterns

**System Design:** 20+ systems designed with full depth

**Backend:** Production-ready knowledge in Django, FastAPI, PostgreSQL, Redis

**Frontend:** Strong React skills with performance optimization

**Behavioral:** 10+ STAR stories, company-specific preparation

**Mock Interviews:** 15+ completed with self-evaluation

**Ready for interviews at top product companies and startups.**
