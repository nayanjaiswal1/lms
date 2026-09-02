---
kind: lab
id_key: interview-prep-45/lab-react-counter
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Lab: React — Stateful Counter Component"
position: 16
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
lab_type: terminal
environment: mindforge/lab-node-web:22
preview_port: 5173
max_duration: 60
max_resets: 3
hint_penalty_pct: 10
is_required: false
setup_script: |
    #!/bin/bash
    # The image's app-runner starts .lab/start.sh (written above) as labuser;
    # this probe just confirms readiness — the platform retries it.
    curl -sf --max-time 2 http://localhost:5173/ >/dev/null
files:
    - path: .lab/start.sh
      content: |
        cd /home/labuser/work
        # Copy the baked scaffold WITHOUT clobbering the task starter files
        # this lab shipped, and symlink node_modules (a real copy would flood
        # the file explorer and the disk quota). Runs as labuser, so the
        # copies stay student-editable.
        cp -rn /opt/scaffold/react-app/. .
        rm -rf node_modules
        ln -sfn /opt/scaffold/react-app/node_modules node_modules
        exec node node_modules/vite/bin/vite.js --host 0.0.0.0 --port 5173
    - path: TASKS.md
      content: |
        # React Counter Lab

        A Vite + React dev server is ALREADY RUNNING on http://localhost:5173
        with hot reload. Try it:

            curl -s http://localhost:5173/ | head -5

        ## Task 1 — Implement the Counter component
        Open `src/Counter.jsx` and implement a stateful counter:
        - `useState` starting at 0
        - render the text `Count: 0` (updating with state)
        - a `<button>` that increments the count on click

        ## Task 2 — Render Counter inside App
        Open `src/App.jsx` and render `<Counter />` inside the app.

        Check each task with the "Check" button in the task panel.
    - path: src/Counter.jsx
      content: |
        // TASK 1: implement a stateful counter.
        //
        // Requirements:
        //   - use the useState hook, initial value 0
        //   - render the current value as: Count: {count}
        //   - render a <button> that increments the count when clicked
        //
        // The dev server hot-reloads on save — watch http://localhost:5173.

        export default function Counter() {
          return null;
        }
    - path: src/App.jsx
      content: |
        // TASK 2: import Counter and render <Counter /> inside <main>.

        export default function App() {
          return (
            <main>
              <h1>MindForge React Lab</h1>
              <p>Implement src/Counter.jsx, then render it here.</p>
            </main>
          );
        }
tasks:
    - id_key: task-counter-component
      title: "Counter renders 'Count: 0' with a button, using useState"
      points: 15
      description: |
        Implement `src/Counter.jsx`: a component using `useState` (initial value
        0) that renders `Count: 0` and an increment `<button>`. The checker
        compiles your component and server-renders it.
      verification_script: |
        cd /home/labuser/work
        cat > .check-counter.jsx <<'CHECK'
        import React from "react";
        import { renderToStaticMarkup } from "react-dom/server";
        import Counter from "./src/Counter.jsx";
        const html = renderToStaticMarkup(React.createElement(Counter));
        if (!/Count:\s*0/.test(html)) { console.error("Counter must initially render 'Count: 0' — got: " + (html || "(empty output)")); process.exit(1); }
        if (!/<button/.test(html)) { console.error("Counter must render a <button> that increments the count"); process.exit(1); }
        CHECK
        node_modules/.bin/esbuild .check-counter.jsx --bundle --outfile=.check-counter.cjs --format=cjs --platform=node --jsx=automatic --log-level=silent || { echo "src/Counter.jsx does not compile"; rm -f .check-counter.jsx; exit 1; }
        node .check-counter.cjs; rc=$?
        rm -f .check-counter.jsx .check-counter.cjs
        [ $rc -eq 0 ] || exit 1
        grep -q "useState" src/Counter.jsx || { echo "Counter must manage its value with the useState hook"; exit 1; }
      hint_context: >-
        The student must import { useState } from "react", call const [count,
        setCount] = useState(0), and return JSX containing the text "Count:
        {count}" plus a button with onClick={() => setCount(count + 1)}.
        Common mistakes: returning null (the starter), forgetting to export
        default, calling useState outside the component, or hardcoding
        "Count: 0" as a string without state (the useState grep catches this).
      explanation_context: >-
        useState gives the component a state cell that survives re-renders;
        calling the setter schedules a re-render with the new value. Server
        rendering shows the initial state (0), which is what the checker
        asserts.
    - id_key: task-app-renders-counter
      title: "App renders the Counter and the dev server serves it"
      points: 10
      is_stateful: true
      description: |
        Render `<Counter />` inside `src/App.jsx`. The checker server-renders the
        whole App and confirms the counter markup appears alongside the heading,
        and that the Vite dev server on port 5173 is still serving.
      verification_script: |
        curl -sf http://localhost:5173/ >/dev/null || { echo "Vite dev server is not responding on :5173"; exit 1; }
        cd /home/labuser/work
        cat > .check-app.jsx <<'CHECK'
        import React from "react";
        import { renderToStaticMarkup } from "react-dom/server";
        import App from "./src/App.jsx";
        const html = renderToStaticMarkup(React.createElement(App));
        if (!/Count:\s*0/.test(html)) { console.error("App must render <Counter /> (expected 'Count: 0' in its output) — got: " + html); process.exit(1); }
        CHECK
        node_modules/.bin/esbuild .check-app.jsx --bundle --outfile=.check-app.cjs --format=cjs --platform=node --jsx=automatic --log-level=silent || { echo "src/App.jsx does not compile"; rm -f .check-app.jsx; exit 1; }
        node .check-app.cjs; rc=$?
        rm -f .check-app.jsx .check-app.cjs
        exit $rc
      hint_context: >-
        The student must add `import Counter from "./Counter.jsx"` at the top
        of src/App.jsx and place <Counter /> inside the returned JSX. This
        task depends on Task 1's Counter being implemented (is_stateful).
        Common mistakes: importing from "./Counter" without implementing Task
        1 first, or rendering the component as {Counter} instead of
        <Counter />.
      explanation_context: >-
        Composition is React's core model: App imports Counter and renders it
        as an element. Server-rendering App recursively renders Counter, which
        is why its 'Count: 0' output proves the wiring.
---

A hands-on checkpoint for the React fundamentals you just covered: a Vite +
React dev server is already running on port 5173 with hot reload. Implement a
`useState` counter component and compose it into the app. The checker compiles
and server-renders your actual components.
