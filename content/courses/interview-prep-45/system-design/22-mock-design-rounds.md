---
kind: lesson
type: system_design
id_key: interview-prep-45/sd-mock-rounds
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Mock Design Rounds"
position: 22
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
    - mock-interviews/29-lesson.md
    - mock-interviews/30-lesson.md
    - mock-interviews/31-lesson.md
    - mock-interviews/33-lesson.md
    - mock-interviews/34-lesson.md
    - mock-interviews/35-lesson.md
    - final-prep/37-lesson.md
    - final-prep/38-lesson.md
    - final-prep/39-lesson.md
    - final-prep/42-lesson.md
---

You've now studied a full set of case studies one at a time, with time to think. A real interview gives you none of that: one prompt, 40 minutes, and someone watching how you think out loud. This lesson is about closing that gap. There is no new system design content here, only the script, the timing, and the rubric for turning what you've learned into something you can actually perform under pressure.

## How to run a full 40-minute mock round

Pick any case study from this section and treat it as if you'd never seen it before. Set a timer. The shape below is the same one every lesson in this section already follows, which is exactly the point: the framework should feel automatic by now.

1. **Clarify (2-4 minutes).** Ask before you design. What's in scope, what's out? What's the read:write ratio? Is strong consistency required anywhere specific? What's the rough scale? A strong candidate spends this time extracting constraints instead of jumping straight to a diagram, and lets the interviewer's answers shape the design that follows, rather than just going through the motions of asking questions and then ignoring the answers.
2. **State requirements out loud (1-2 minutes).** Functional, then non-functional. This is fast because you just clarified it.
3. **Estimate (3-5 minutes).** Real numbers: requests/sec, storage, read:write ratio. Say the arithmetic out loud. This number should drive design choices later, not sit unused.
4. **Define the API (2-3 minutes).** The contract between client and system. This forces you to nail down what data flows where before you draw boxes.
5. **Design the data model (3-5 minutes).** Tables or documents, and which field is the natural sharding or partition key.
6. **Draw the high-level design (5-8 minutes).** Boxes and arrows, then narrate the request path through them out loud.
7. **Deep-dive (10-15 minutes).** Go deep on whatever the interviewer steers toward, or the single hardest part of the system if they don't steer you anywhere. This is where most of the signal comes from; don't stay shallow here to save time elsewhere.
8. **Trade-offs and follow-ups (3-5 minutes).** Name what breaks first, and how you'd fix it. Answer curveballs by adapting your existing design, not restarting from scratch.

> **Remember:** the clock is not your enemy, vague scope is. Almost every mock round that runs out of time ran out because the first five minutes were spent drawing boxes instead of asking questions.

```knowledge-check
{ "questions": [
    { "id": "system-design-mock-script-q1", "type": "mcq", "prompt": "What is the most common reason a candidate runs out of time in a 40-minute system design round?", "options": [
        {"id": "a", "text": "The deep-dive phase always takes too long no matter what"},
        {"id": "b", "text": "Skipping or rushing the clarifying-questions phase, which leads to designing the wrong thing or re-scoping midway through"},
        {"id": "c", "text": "Spending too much time on the data model"},
        {"id": "d", "text": "Asking too many clarifying questions up front"}
    ], "correct": "b", "explanation": "Time spent clarifying scope early is what prevents a costly mid-interview pivot later. Skipping it to 'save time' usually costs far more time than it saves." }
] }
```

## The 40-minute grading signals: what a strong round actually looks like

Grade yourself, or a study partner, against these signals after every mock round:

- Time on requirements and estimates stays under about 10 minutes total.
- You drive the conversation and propose the next step yourself, rather than waiting to be asked "so what's next?"
- The deep dive gets real detail on one component, a data model, an algorithm, a protocol, not just more boxes on the same diagram.
- You make at least two explicit "I chose X over Y because Z" statements during the round, not just a list of technologies.
- You handle a curveball (the interviewer changes a requirement mid-design) by adapting your existing design, not by starting over.

For confident systems, ones you could explain start to finish in under 10 minutes out loud with no pause longer than 3 seconds, that fluency is the actual target for every case study in this section. For weaker areas, the honest goal is different: nail requirements, the API, and the high-level design even if the deep dive is where you slow down. Knowing which of your systems are which is more useful than pretending they're all equally solid.

## A general-purpose scoring rubric

Use this rubric for any case study in this section, not just the ones it was originally written for:

- Asked clarifying questions before designing, and let the answers actually shape the design.
- Covered both functional and non-functional requirements explicitly, and used the non-functional ones to justify later design choices.
- Named at least two real trade-offs, with a reasoned pick, not just a list of options.
- Handled a follow-up ("what if this server dies," "what if traffic goes up 10x") confidently, with a concrete change to the design.
- Was honest about weaknesses in the design instead of pretending it was complete. A senior answer names what it would do with more time, rather than hand-waving past a gap.

> **Remember:** an interviewer isn't grading whether you can recite a known-good architecture. They're grading whether you can reason about trade-offs live, including admitting where your design is weaker.

```knowledge-check
{ "questions": [
    { "id": "system-design-mock-rubric-q1", "type": "mcq", "prompt": "What does a strong system design candidate do when asked about a weakness in their own design, rather than pretending it doesn't exist?", "options": [
        {"id": "a", "text": "Deflects the question and moves to a different topic"},
        {"id": "b", "text": "Names the weakness honestly and states what they'd do about it with more time or information"},
        {"id": "c", "text": "Insists the design has no weaknesses"},
        {"id": "d", "text": "Refuses to discuss anything not already covered"}
    ], "correct": "b", "explanation": "Interviewers are listening for judgment under uncertainty, not a flawless design. Naming a real gap and how you'd address it is a stronger signal than claiming the design is complete." }
] }
```

## The 15-minute speed round: a warm-up drill

Before a full 40-minute mock, or as a standalone drill, run this fast variant on two different case studies back to back:

1. State functional and non-functional requirements out loud, 60 seconds.
2. Draw the high-level box diagram (client, load balancer, service, cache, database), 3-4 minutes.
3. Name the single hardest part of the system and describe, in two sentences, how you'd approach it, without actually solving it, 2 minutes.
4. Stop. Move to the next design.

This drills structuring a design under real time pressure without freezing on where to start. Think of it as a warm-up, not a substitute for the full 40-minute round: it builds the habit of moving fast through the parts of the framework that shouldn't take long, so you have more time left for the parts that should.

## The hard part, per system: a recap table

For each case study in this section, the interview almost always narrows to one genuinely hard decision. If you can name it from memory before opening the lesson, you've internalized the design.

| System | The hard part |
|---|---|
| URL shortener | Collision-free code generation at scale (a Key Generation Service beats checking for collisions on every write) |
| Rate limiter | Distributed counting without a single point of failure |
| Notification service | Fan-out to many channels plus delivery and read tracking, without one slow channel blocking the others |
| Job queue | Delivery guarantees (at-least-once, not exactly-once) and what that means for handler design |
| Chat / messaging | Message ordering and delivery guarantees across devices, without the server ever seeing plaintext |
| Analytics pipeline | Reconciling a fast approximate stream with a slow exact batch job for late-arriving data |
| Multi-tenant SaaS | Choosing an isolation model (Pool, Bridge, Silo) and enforcing it at the database layer, not just in code |
| Social feed / Twitter | Fan-out on write vs. fan-out on read for celebrity accounts |
| Search autocomplete | Precomputing top-K per trie node instead of ranking live on every keystroke |
| File storage (Dropbox) | Content-addressed chunking for resume, dedup, and safe ref-counted deletion |
| Google Docs | Choosing and correctly implementing OT or CRDT-based conflict resolution |
| Code review system | Re-validating mergeability atomically at merge time, not trusting a stale display state |
| Netflix | CDN-first delivery and proactive edge placement for a predictable catalog |
| YouTube | Elastic, unpredictable upload and cache demand for a catalog too large to pre-place |
| Spotify | CDN-bound audio delivery plus licensing enforcement that must propagate in seconds |
| Uber / ride-sharing | Real-time geospatial matching (geohash or a quadtree) at scale |
| Airbnb | Preventing double-booking with an atomic database constraint, not a check-then-write |
| Ticketmaster | Converting extreme contention into a controlled admission queue, not just rate limiting |
| E-commerce cart/checkout | A crash-safe checkout state machine that survives an external payment call it can't roll back |
| Payment system | Idempotency at two layers, plus an immutable audit log as the real source of truth |
| Logging/monitoring | Never letting the write path block the very applications it's observing |

## Trade-offs and follow-up questions

**Q: How do I know if I'm ready to stop drilling and just take the real interview?**
A: When you can run the 40-minute script on any case study in this section without checking notes, and your deep dive consistently goes into real detail rather than staying at the box-diagram level. If you're still pausing to remember requirements or the API shape, that's a sign to run a few more speed rounds on that specific system, not the whole section again.

**Q: The interviewer keeps interrupting with follow-up questions before I finish my planned structure. Is that a bad sign?**
A: No. Interviewers change a requirement mid-design specifically to see whether you adapt your existing design or panic and restart. Treat an interruption as a chance to show that skill, not as a derailment. Adjust the part of the design the new constraint actually affects, and say out loud what changes and why.

**Q: I finished a design in 25 minutes with time to spare. Did I move too fast?**
A: Probably. Extra time almost always means the deep dive was too shallow. Use remaining time to go one level deeper into whatever component you glossed over, discuss a second failure mode, or walk through a concrete numeric example, rather than just stopping early.

```knowledge-check
{ "questions": [
    { "id": "system-design-mock-followup-q1", "type": "mcq", "prompt": "An interviewer changes a requirement partway through your design (e.g., \"actually, assume 10x more traffic\"). What's the strongest response?", "options": [
        {"id": "a", "text": "Restart the design from scratch with the new number in mind"},
        {"id": "b", "text": "Adapt the specific parts of the existing design the new constraint actually affects, and explain what changes and why"},
        {"id": "c", "text": "Ignore the new information and finish the original plan"},
        {"id": "d", "text": "Ask the interviewer to keep the original assumption instead"}
    ], "correct": "b", "explanation": "A curveball is testing adaptability, not memorization. Adjusting the affected parts of an already-solid design, out loud, is exactly the skill the interviewer is checking for." }
] }
```
