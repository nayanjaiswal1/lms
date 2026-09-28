---
kind: lesson
id_key: interview-prep-45/start-here
course: interview-prep-45
section: start-here
section_title: "Start Here"
section_position: 1
title: "How to Use This Course"
position: 1
estimated_minutes: 20
source:
    - mock-interviews/29-lesson.md
    - mock-interviews/30-lesson.md
    - mock-interviews/31-lesson.md
    - mock-interviews/32-lesson.md
    - mock-interviews/33-lesson.md
    - mock-interviews/34-lesson.md
    - mock-interviews/35-lesson.md
    - final-prep/36-lesson.md
    - final-prep/37-lesson.md
    - final-prep/38-lesson.md
    - final-prep/39-lesson.md
    - final-prep/40-lesson.md
    - final-prep/41-lesson.md
    - final-prep/42-lesson.md
    - interview-days/43-lesson.md
    - interview-days/44-lesson.md
    - interview-days/45-lesson.md
    - dsa/07-lesson.md
    - backend/07-lesson.md
    - backend/21-lesson.md
    - behavioral/07-lesson.md
---

This course gets you ready for software engineering interviews. It covers data structures and algorithms, system design (both the foundations and full case studies), low-level design, backend engineering, frontend engineering, and behavioral interviews. This lesson tells you what is in each part, how they fit together, and how to actually study them so the material sticks.

## What this course covers

You have seven subjects to work through:

- **Data Structures & Algorithms (DSA):** the coding-interview patterns, from arrays to dynamic programming, plus practice tests and a final round of speed drills.
- **System Design Foundations:** the building blocks every system design answer is made of, estimation, caching, sharding, consensus, and so on.
- **System Design Case Studies:** full designs of real products, a URL shortener, a chat app, Twitter, a ride-sharing app, and more, built using the foundations.
- **Low-Level Design (LLD):** object-oriented design, the classic design patterns, and building small systems like a parking lot or an elevator from scratch.
- **Backend:** split into Python, Django, FastAPI, databases (PostgreSQL), systems (caching, queues, distributed systems), and APIs.
- **Frontend:** JavaScript and CSS fundamentals, React internals, performance, TypeScript, and testing.
- **Behavioral & Interview Day:** how to tell your work stories well, company research, and interview-day logistics.

Each subject is graded with its own short tests along the way, so you always know where you stand.

> **Remember:** this course is seven separate subjects. Start with whichever one you're weakest in and start there.

```knowledge-check
{ "questions": [
    { "id": "ip45-start-overview-q1", "type": "mcq", "prompt": "How many separate subjects does this course cover?",
      "options": [
        {"id": "a", "text": "One long combined track"},
        {"id": "b", "text": "Seven subjects: DSA, System Design Foundations, System Design Case Studies, LLD, Backend, Frontend, and Behavioral"},
        {"id": "c", "text": "Only DSA and System Design"},
        {"id": "d", "text": "Only Backend and Frontend"}
      ],
      "correct": "b",
      "explanation": "The course splits into seven independent subjects so you can study whichever one you need most, in any order." }
] }
```

## How the subjects fit together

Every subject in this course stands on its own. You do not need to finish DSA before starting System Design, and you do not need to finish Backend before starting Frontend. Each subject has its own lessons, its own tests, and its own final "mock round" lesson where you practice under interview conditions.

This matters because your own interview loop probably doesn't test everything. If your next interview is pure backend and behavioral, you can skip straight to those two subjects and ignore the rest for now. If you have a full loop (coding, system design, and behavioral in one day), work through all three in parallel using the plan below.

Two subjects lean on each other a little: System Design Case Studies uses the vocabulary built in System Design Foundations, so it helps to have looked at Foundations first. Everything else is genuinely independent.

> **Remember:** a subject you don't need for your interview is a subject you can skip. This course does not require finishing everything to be useful.

```knowledge-check
{ "questions": [
    { "id": "ip45-start-independence-q1", "type": "mcq", "prompt": "Which pair of subjects is NOT independent, i.e. one builds on the other?",
      "options": [
        {"id": "a", "text": "Frontend and Behavioral"},
        {"id": "b", "text": "System Design Foundations and System Design Case Studies"},
        {"id": "c", "text": "LLD and Backend"},
        {"id": "d", "text": "DSA and Frontend"}
      ],
      "correct": "b",
      "explanation": "System Design Case Studies uses the vocabulary (caching, sharding, consensus, and so on) taught in System Design Foundations, so it helps to see Foundations first. Every other pair of subjects is fully independent." }
] }
```

## A 45-day study plan

You do not have to follow this plan. It's there for people who want a ready-made pace. Expect about 4 to 5 hours a day. Two tracks run side by side: one DSA lesson every morning, and one other subject in the afternoon. Your STAR stories take time to find and polish, so a small behavioral lesson runs every few days from the start instead of being crammed at the end.

Lesson numbers below are positions inside each subject.

| Days | Morning: DSA | Afternoon: other subjects |
|---|---|---|
| 1 | Start Here, Arrays and Hashing | System Design Foundations 1-2; Behavioral 1 (resume walkthrough) |
| 2-6 | Two Pointers, Sliding Window, Sliding Window (Harder), Binary Search, Stacks | System Design Foundations 3-12, two a day |
| 7 | Practice Test 1 | System Design Foundations 13-16 and its test; Behavioral 2 (STAR method) |
| 8-14 | Trees Basics, BST, Tries, Heaps, Graphs BFS/DFS, Topological Sort, Union Find | System Design Case Studies 1-14, two a day; Behavioral 3 and 4 on days 10 and 13 |
| 15 | Practice Test 2 | Case Studies 15-17 |
| 16-21 | DP Basics, DP Intermediate, DP Hard, Backtracking, Backtracking (Advanced), Greedy | Case Studies 18-23 (Mock Design Rounds and test on day 21); Behavioral 5 and 6 on days 17 and 20 |
| 22-25 | Intervals, Bit Manipulation, Math and Geometry, Strings | Low-Level Design 1-10 |
| 26-27 | Pattern Recall and Mock Coding Rounds, Practice Test 3 | Low-Level Design 11-19 (test on day 27); Behavioral 7 |
| 28 | Redo one coding problem from each DSA test, timed | Backend: Python (all) and Django (all) |
| 29 | Two timed problems from the Pattern Recall lesson | Backend: FastAPI (all), Databases 1-3 |
| 30 | Two timed problems | Backend: Databases 4-6, Caching, Queues and Distributed Systems 1-4 |
| 31 | Two timed problems | Backend: Caching, Queues and Distributed Systems 5-8, APIs 1-3 |
| 32 | Two timed problems | Backend: APIs 4-9 (Mock Backend Round and test); Behavioral 8 |
| 33-35 | One timed problem a day | Frontend 1-12 (HTML, CSS, JavaScript and test 1) |
| 36-38 | One timed problem a day | Frontend 13-22 (React and test 2); Behavioral 9 |
| 39-41 | One timed problem a day | Frontend 23-38 (performance, security, production, Rapid Recall, test 3) |
| 42 | Mock coding round with a friend | Behavioral 10 (company research) for each company on your list |
| 43 | Mock coding round | Behavioral 11 (mock behavioral rounds), one mock design round |
| 44 | Light review only | Behavioral 12 (interview day) and the Behavioral test |
| 45 | Rest | Behavioral 13 (after the interview). Then pick your weakest subject and retake its test cold |

If your own interviews only cover some of these subjects, cut the rest and repeat mock rounds in the subjects you actually need instead.

> **Remember:** the plan is a default pace, not a rule. Rearrange it around your actual interview date and the subjects your interviews will actually cover.

```knowledge-check
{ "questions": [
    { "id": "ip45-start-plan-q1", "type": "mcq", "prompt": "You have interviews in two weeks that only cover backend and behavioral questions. What should you do with this 45-day plan?",
      "options": [
        {"id": "a", "text": "Follow it exactly from day 1, since skipping days breaks the course"},
        {"id": "b", "text": "Skip straight to the Backend and Behavioral subjects and ignore the rest for now"},
        {"id": "c", "text": "Wait until you have a full 45 days free before starting"},
        {"id": "d", "text": "Only do DSA, since it comes first in the plan"}
      ],
      "correct": "b",
      "explanation": "The subjects are independent. If your interviews only cover backend and behavioral, go directly to those two subjects instead of following the full generic plan." }
] }
```

## How to study one lesson

Every lesson in this course follows the same shape, so the same study method works everywhere:

1. **Read the whole lesson once, without stopping to take notes.** Get the shape of the idea first.
2. **Run any code in the lesson yourself.** Don't just read it. Type it, run it, change one thing, and see what breaks. A concept you've run is a concept you remember; a concept you only read is a concept you'll blank on in an interview.
3. **Answer the knowledge-check question after each section.** If you get it wrong, go back and re-read that section before moving on. These checks are short on purpose, one idea at a time, not a full quiz.
4. **Say the "Remember" line out loud.** Every concept in this course ends with a short blockquote starting with "Remember." Say it in your own words, out loud, like you're explaining it to a friend. If you can't say it without looking, you haven't actually learned it yet, you've only recognized it.

This last step matters more than it sounds. Recognizing an idea when you read it and producing that idea from scratch under pressure are two different skills, and only the second one is what an interview actually tests.

> **Remember:** reading a lesson once is not the same as learning it. You know a concept once you can say the Remember line without looking back.

```knowledge-check
{ "questions": [
    { "id": "ip45-start-studying-q1", "type": "mcq", "prompt": "You just read a lesson and understood it while reading. What's the real test of whether you actually learned it?",
      "options": [
        {"id": "a", "text": "You recognized the idea while reading it"},
        {"id": "b", "text": "You can say the lesson's Remember line out loud, in your own words, without looking back"},
        {"id": "c", "text": "You finished the lesson in under 20 minutes"},
        {"id": "d", "text": "The lesson's code blocks looked familiar"}
      ],
      "correct": "b",
      "explanation": "Recognizing an idea while reading it is a weaker skill than producing it from scratch. Being able to say the Remember line unprompted is the real signal you've learned it, since that's closer to what an interview actually demands." }
] }
```

## How to run a mock interview

Every subject's last lesson is a set of mock interview rounds with a rubric. Run them like this, whether you're alone or with a friend:

- **Use a real timer per round**, and do not pause it. A real interview does not pause either.
- **Talk out loud the entire time**, even if no one is listening. Silence is the single worst signal you can give in a real interview, since the interviewer is grading how you think, not just your final answer. If you get stuck, say what you'd ask an interviewer instead of guessing quietly.
- **Do not open the reference solution or rubric until you've submitted your own answer or the timer runs out.** Looking early defeats the entire exercise.
- **Score yourself honestly against the rubric right after**, like an interviewer would, not like your own cheerleader.
- **Write down, immediately, while it's fresh:** the single biggest mistake, why it happened (a knowledge gap, nerves, or running out of time), and one specific fix, a problem to redo, a concept to re-read, or a story to rewrite with real numbers.
- **Revisit anything that scored low within 48 hours.** That's the window where practice actually turns into memory. Waiting a week means starting over.

If you run several mock rounds over a few days, once you have four or five debriefs written down, go back through all of them together. Group the mistakes by what kind of gap they are, not by which round they happened in: not knowing something, fumbling the mechanics of something you do know, explaining something poorly, running out of time, or freezing up. A mistake that shows up once is bad luck. The same mistake showing up three times across different rounds is a habit, and habits are exactly what a real interview loop exposes. Pick your three most repeated mistakes and write a specific drill for each one, not "get better at system design," but "state the time and space complexity out loud before writing any code, every single round from now on."

> **Remember:** score yourself like an interviewer, fix the mistake within 48 hours, and if the same mistake shows up three times across different mock rounds, it's a habit, not bad luck.

```knowledge-check
{ "questions": [
    { "id": "ip45-start-mock-q1", "type": "mcq", "prompt": "During a mock interview, you get stuck on a problem for two minutes. What should you do?",
      "options": [
        {"id": "a", "text": "Stay completely silent while you think, since talking would show you're stuck"},
        {"id": "b", "text": "Say out loud what you're thinking and what you'd ask a real interviewer, instead of guessing silently"},
        {"id": "c", "text": "Immediately open the reference solution"},
        {"id": "d", "text": "Give up and restart the timer"}
      ],
      "correct": "b",
      "explanation": "Silence is the worst signal you can give in an interview. An interviewer grades your thinking process, not just your final answer, so narrating what you're stuck on (and what you'd ask) is far stronger than quiet guessing." }
] }
```

## How to track your progress

Two numbers predict interview readiness better than a raw count of problems solved or lessons finished:

**Time per problem, split by phase.** When you solve something, notice where the time actually went: recognizing which pattern to use, writing the code itself, or debugging edge cases afterward. If debugging eats most of your time, your actual weakness is precision, off-by-one errors, missed base cases, not pattern recognition. If recognizing the pattern is what's slow, more coding practice won't help; you need more exposure to how problems get phrased.

**How often the same gap repeats.** Keep a running list of what broke in each practice session or mock round, one line each: what happened, why, what you'd do differently. A gap that shows up once is noise. A gap that shows up three times across different problems is a structural hole in your knowledge, and it will show up again in a real interview unless you fix it directly.

The habit underneath both of these is the same one from the mock-interview section above: a skill only counts as learned once it survives a cold, timed check with no notes. Recognizing an answer when you read it is not the same as producing it yourself under pressure. If you can't produce something cold in roughly the time a real interview would give you, it goes back on your practice list, no matter how many times you've seen it before.

> **Remember:** track where your time goes and which mistakes repeat. A mistake you've made three times is a real gap, not bad luck.

```knowledge-check
{ "questions": [
    { "id": "ip45-start-tracking-q1", "type": "mcq", "prompt": "You solved a medium DSA problem, but it took much longer than expected. Debugging edge cases ate most of the time, not figuring out the approach. What does this actually tell you?",
      "options": [
        {"id": "a", "text": "You need to see more problems to improve pattern recognition"},
        {"id": "b", "text": "Your weakness here is precision, things like off-by-one errors and missed base cases, not recognizing the pattern"},
        {"id": "c", "text": "The problem was simply too hard and nothing can be learned from it"},
        {"id": "d", "text": "You should stop practicing this pattern entirely"}
      ],
      "correct": "b",
      "explanation": "Splitting your time by phase (recognizing the pattern vs. writing the code vs. debugging) tells you exactly what to fix. Time lost to debugging points at precision, not pattern recognition, so more volume of new problems isn't the right fix." }
] }
```

## What to do after interview season

Interview prep does not stop the moment your interviews end, whether you got an offer or not. Skills fade without upkeep, and staying sharp is worth far less effort than building the skill was in the first place.

**In the first one to two weeks after your interviews:** read any written feedback you received closely; it is rare and worth more than a dozen more practice problems. Keep a light maintenance pace, around two problems a day, just enough to not lose what you built, not to keep growing quickly.

**Over the following one to three months:** revisit one system design a week, rotating through designs you haven't touched in a while rather than replaying your favorites. Run one full mock interview a month with a real person if you can. Reviewing your own answers alone misses delivery problems, filler words, rambling, a flat "tell me about yourself", the same way reading a script hides how it actually sounds out loud.

**Keep using real resources, not just this course:** company-tagged problem sets once you're targeting specific employers, a structured mock-interview platform if you want feedback from a stranger, the System Design Primer (a well-known open reference) whenever a specific building block goes rusty, and the engineering blogs of companies you're targeting, which show you the real scale problems they actually care about.

> **Remember:** interview skill decays without upkeep. A couple of problems a day and one system design a week is enough to hold onto what you built here.

```knowledge-check
{ "questions": [
    { "id": "ip45-start-after-q1", "type": "mcq", "prompt": "Your interview loop just finished. What is the right amount of practice to keep up over the following months?",
      "options": [
        {"id": "a", "text": "Stop entirely until your next job search"},
        {"id": "b", "text": "A light maintenance pace: a couple of problems a day and one system design a week, plus a monthly mock with a real person"},
        {"id": "c", "text": "The exact same intensity as the 45-day plan, indefinitely"},
        {"id": "d", "text": "Only review written feedback, and nothing else"}
      ],
      "correct": "b",
      "explanation": "Interview skills fade without upkeep, but maintaining them takes far less effort than building them did. A light, steady pace plus periodic real mock interviews keeps the skill without the intensity of active prep." }
] }
```
