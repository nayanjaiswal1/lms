export const DEMO_TABS = [
  { id: "dashboard", label: "Dashboard" },
  { id: "courses", label: "Courses" },
  { id: "labs", label: "Labs" },
  { id: "quiz", label: "Quiz" },
  { id: "sheets", label: "Sheets" },
] as const;

export type DemoTabId = (typeof DEMO_TABS)[number]["id"];

export const DEMO_USER = { name: "Alex Chen" };

export const DEMO_UPCOMING = [
  { kind: "assessment", title: "Go Concurrency — Quiz 2", when: "Due tomorrow · 2 attempts left" },
  { kind: "event", title: "Mentor session: Mock system design", when: "Thu · 6:00 PM" },
  { kind: "event", title: "Live class: Query planning", when: "Sat · 10:00 AM" },
] as const;

export const DEMO_STANDING = [
  { rank: 1, name: "Priya S.", xp: 2840 },
  { rank: 2, name: "Alex Chen", xp: 2615, me: true },
  { rank: 3, name: "Marcus L.", xp: 2490 },
  { rank: 4, name: "Sofia R.", xp: 2310 },
];

export const DEMO_LEVEL = { label: "Level 7 · Forgemaster", progressPct: 62 };

export const DEMO_QUIZ = {
  title: "Go Concurrency — Quiz 2",
  questions: [
    {
      prompt: "When does a send on an unbuffered channel block?",
      options: ["Never", "Until a receiver is ready", "Until the channel is closed", "Until the buffer is full"],
      answer: 1,
    },
    {
      prompt: "Which primitive waits for a group of goroutines to finish?",
      options: ["sync.Mutex", "sync.Once", "sync.WaitGroup", "context.Context"],
      answer: 2,
    },
    {
      prompt: "What happens when you send on a closed channel?",
      options: ["The value is dropped", "It blocks forever", "It returns an error", "It panics"],
      answer: 3,
    },
  ],
};

export const DEMO_SHEET = {
  title: "Blind 75 — Core Patterns",
  problems: [
    { id: "two-sum", title: "Two Sum", topic: "Arrays", difficulty: "easy", done: true },
    { id: "valid-parens", title: "Valid Parentheses", topic: "Stack", difficulty: "easy", done: true },
    { id: "merge-intervals", title: "Merge Intervals", topic: "Intervals", difficulty: "medium", done: false },
    { id: "lru-cache", title: "LRU Cache", topic: "Design", difficulty: "medium", done: false },
    { id: "word-ladder", title: "Word Ladder", topic: "Graphs", difficulty: "hard", done: false },
    { id: "median-stream", title: "Find Median from Data Stream", topic: "Heap", difficulty: "hard", done: false },
  ],
};

export const DEMO_LAB_KINDS = [
  { id: "debug", label: "Debug lab" },
  { id: "ide", label: "VS Code lab" },
  { id: "docker", label: "Docker lab" },
] as const;

export type DemoLabKind = (typeof DEMO_LAB_KINDS)[number]["id"];

export const DEMO_DEBUG_LAB = {
  title: "Debug: the cart total is wrong",
  brief: "Customers are undercharged. The page below renders live from app.js — fix the bug and watch the preview update.",
  file: "app.js",
  buggy: `const cart = [
  { name: "Book", price: 12.5, qty: 2 },
  { name: "Pen", price: 1.2, qty: 5 },
];

function total(items) {
  let sum = 0;
  for (const item of items) sum += item.price;
  return sum;
}

document.getElementById("total").textContent =
  "Total: $" + total(cart).toFixed(2);`,
  tasks: [
    { id: "t1", title: "The cart total shows $31.00" },
    { id: "t2", title: "An item with no qty counts as quantity 1" },
  ],
  // Run inside the preview iframe after the learner's code; one boolean per task.
  harness: "[total(cart) === 31, total([{ price: 5 }]) === 5]",
  hints: [
    "Compare what total() reads from each item with what the cart stores.",
    "Each line item costs price × qty, not just price.",
    "Use `item.price * (item.qty ?? 1)` inside the loop.",
  ],
};

export const DEMO_IDE_LAB = {
  title: "Debug: the todo counter is wrong",
  brief: "Open the project in the editor, find both bugs across app.js and styles.css, then Run to see the live preview and terminal checks.",
  files: {
    "index.html": `<h3>Todos</h3>
<ul id="list"></ul>
<p id="count"></p>`,
    "styles.css": "li.done { text-decoration: none; opacity: 0.6; }",
    "app.js": `const todos = [
  { text: "Write tests", done: true },
  { text: "Fix the bug", done: false },
  { text: "Ship it", done: false },
];

function remaining(list) {
  return list.filter((t) => t.done).length;
}

for (const t of todos) {
  const li = document.createElement("li");
  li.textContent = t.text;
  if (t.done) li.className = "done";
  document.getElementById("list").appendChild(li);
}
document.getElementById("count").textContent = remaining(todos) + " left";`,
  } as Record<string, string>,
  tasks: [
    { id: "t1", title: "The counter shows 2 items left" },
    { id: "t2", title: "Completed todos are struck through" },
  ],
  harness: '[remaining(todos) === 2, getComputedStyle(document.querySelector("li.done")).textDecorationLine.includes("line-through")]',
  hints: [
    "remaining() should count the todos you have NOT finished yet.",
    "The CSS rule for finished items sets text-decoration to none.",
    "Use !t.done in remaining(), and text-decoration: line-through in styles.css.",
  ],
};

export const DEMO_DOCKER_LAB = {
  title: "Docker: serve a site with nginx",
  brief: "Run an nginx web server in a container, publish it on host port 8080, then read its logs.",
  tasks: [
    { id: "t1", title: "Run a detached container named web from the nginx image" },
    { id: "t2", title: "Publish container port 80 on host port 8080" },
    { id: "t3", title: "Read the container's logs" },
  ],
  hints: [
    "docker run takes -d to detach and --name to name the container.",
    "-p HOST:CONTAINER publishes a port, e.g. -p 8080:80.",
    "docker run -d --name web -p 8080:80 nginx, then docker logs web.",
  ],
};
