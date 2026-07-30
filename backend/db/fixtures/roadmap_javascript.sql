-- ══════════════════════════════════════════════════════════════════════════
-- "JavaScript Developer" roadmap fixture — mirrors the topic coverage of
-- roadmap.sh/javascript, seeded as a DEFINED-mode, public roadmap owned by
-- the dev student account. Exercises every roadmap_modules.module_type
-- ('course','lab','dsa_problem','project','reading','quiz') so the roadmap
-- UI (tree, catalog links, progress, public/Discover) has real data to
-- render without an AI call. See docs/roadmap.md for schema + semantics.
-- Safe to re-run: phases/milestones/modules are deleted and reinserted,
-- matching the app's own regenerate/fork transaction shape.
-- ══════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_roadmap_id   UUID := '00000000-0000-0000-0000-000000006000';
  v_user_id      UUID := '00000000-0000-0000-0000-000000000014'; -- student@mindforge.dev
  v_org_id       UUID := '00000000-0000-0000-0000-000000000001'; -- default org
  v_phase_id     UUID;
  v_milestone_id UUID;
BEGIN
  INSERT INTO roadmaps
    (id, user_id, org_id, title, mode, status, is_public, goal_description,
     target_role, skill_level, timeframe_weeks, focus_areas, generated_at)
  VALUES
    (v_roadmap_id, v_user_id, v_org_id, 'JavaScript Developer Roadmap', 'defined', 'active', true,
     'Go from JavaScript syntax fundamentals to async patterns, browser APIs, tooling, and modern frameworks.',
     'Frontend Developer', 'beginner', 16,
     '["javascript","frontend","web"]'::jsonb, now())
  ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title, goal_description = EXCLUDED.goal_description,
    is_public = EXCLUDED.is_public, updated_at = now();

  DELETE FROM roadmap_phases WHERE roadmap_id = v_roadmap_id;

  -- ─── Phase 1: Environment & Fundamentals ────────────────────────────────
  INSERT INTO roadmap_phases (roadmap_id, title, description, position, estimated_weeks)
  VALUES (v_roadmap_id, 'Environment & Fundamentals', 'Tooling setup and core language basics', 0, 2)
  RETURNING id INTO v_phase_id;

  INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
  VALUES (v_phase_id, 'Setup & Syntax', 'Get tooling running and learn basic syntax', 0, 6)
  RETURNING id INTO v_milestone_id;
  INSERT INTO roadmap_modules (milestone_id, title, description, position, module_type, estimated_minutes) VALUES
    (v_milestone_id, 'Pick an editor and runtime', 'Install Node.js and VS Code (or your editor of choice)', 0, 'reading', 30),
    (v_milestone_id, 'Basic syntax, statements & comments', 'Expressions, statements, semicolons, comments', 1, 'course', 60),
    (v_milestone_id, 'Variables: var, let, const', 'Declarations, block scope, hoisting basics', 2, 'course', 60),
    (v_milestone_id, 'Strict mode', 'Why and how to opt in to strict mode', 3, 'reading', 20);

  INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
  VALUES (v_phase_id, 'Core Data Types', 'The built-in types and their methods', 1, 10)
  RETURNING id INTO v_milestone_id;
  INSERT INTO roadmap_modules (milestone_id, title, description, position, module_type, estimated_minutes) VALUES
    (v_milestone_id, 'Numbers & Math', 'Number type, precision, Math object, BigInt', 0, 'course', 60),
    (v_milestone_id, 'Strings & template literals', 'String methods, template literals, tagged templates', 1, 'course', 60),
    (v_milestone_id, 'Booleans & operators', 'Truthy/falsy, comparison, logical, nullish coalescing', 2, 'course', 45),
    (v_milestone_id, 'Arrays & array methods', 'map, filter, reduce, forEach, find, spread', 3, 'course', 90),
    (v_milestone_id, 'Objects & destructuring', 'Object methods, property shorthand, destructuring', 4, 'course', 90),
    (v_milestone_id, 'Fundamentals check', 'Self-check quiz on types, operators and arrays/objects', 5, 'quiz', 20);

  -- ─── Phase 2: Control Flow & Functions ──────────────────────────────────
  INSERT INTO roadmap_phases (roadmap_id, title, description, position, estimated_weeks)
  VALUES (v_roadmap_id, 'Control Flow & Functions', 'Functions, scope, closures and iteration', 1, 2)
  RETURNING id INTO v_phase_id;

  INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
  VALUES (v_phase_id, 'Functions & Scope', 'Function forms, parameters, and closures', 0, 8)
  RETURNING id INTO v_milestone_id;
  INSERT INTO roadmap_modules (milestone_id, title, description, position, module_type, estimated_minutes) VALUES
    (v_milestone_id, 'Functions & arrow functions', 'Declarations, expressions, arrow functions, this binding', 0, 'course', 60),
    (v_milestone_id, 'Default, rest & spread parameters', 'Flexible function signatures', 1, 'course', 45),
    (v_milestone_id, 'Hoisting', 'var/function hoisting vs the temporal dead zone', 2, 'reading', 20),
    (v_milestone_id, 'Closures', 'Lexical scope and closures in practice', 3, 'course', 60);

  INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
  VALUES (v_phase_id, 'Loops & Iteration', 'Iterating data and practicing with problems', 1, 8)
  RETURNING id INTO v_milestone_id;
  INSERT INTO roadmap_modules (milestone_id, title, description, position, module_type, estimated_minutes) VALUES
    (v_milestone_id, 'for, while, for...of, for...in', 'Loop forms and when to use each', 0, 'course', 45),
    (v_milestone_id, 'Iterators & generators', 'The iterator protocol and function*', 1, 'reading', 30),
    (v_milestone_id, 'DSA warmup: array manipulation', 'Practice problems on arrays', 2, 'dsa_problem', 45),
    (v_milestone_id, 'DSA warmup: string manipulation', 'Practice problems on strings', 3, 'dsa_problem', 45);

  -- ─── Phase 3: Browser & DOM ──────────────────────────────────────────────
  INSERT INTO roadmap_phases (roadmap_id, title, description, position, estimated_weeks)
  VALUES (v_roadmap_id, 'Browser & DOM', 'Manipulating pages and talking to servers', 2, 2)
  RETURNING id INTO v_phase_id;

  INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
  VALUES (v_phase_id, 'DOM Manipulation', 'Reading and updating the page', 0, 6)
  RETURNING id INTO v_milestone_id;
  INSERT INTO roadmap_modules (milestone_id, title, description, position, module_type, estimated_minutes) VALUES
    (v_milestone_id, 'DOM basics & selectors', 'Node tree, querySelector, traversal', 0, 'course', 45),
    (v_milestone_id, 'Creating & updating elements', 'Build a small interactive page', 1, 'lab', 60),
    (v_milestone_id, 'Events & bubbling/capturing', 'addEventListener, delegation, propagation', 2, 'course', 45);

  INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
  VALUES (v_phase_id, 'Network Requests', 'Talking to APIs from the browser', 1, 6)
  RETURNING id INTO v_milestone_id;
  INSERT INTO roadmap_modules (milestone_id, title, description, position, module_type, estimated_minutes) VALUES
    (v_milestone_id, 'Fetch API & AJAX', 'fetch(), headers, JSON, error handling', 0, 'course', 60),
    (v_milestone_id, 'Build a REST API consumer', 'Wire a small UI to a real API', 1, 'project', 120),
    (v_milestone_id, 'XHR & legacy patterns', 'XMLHttpRequest and when you still see it', 2, 'reading', 20);

  -- ─── Phase 4: Modern JavaScript ──────────────────────────────────────────
  INSERT INTO roadmap_phases (roadmap_id, title, description, position, estimated_weeks)
  VALUES (v_roadmap_id, 'Modern JavaScript', 'ES6+ syntax and object-oriented patterns', 3, 2)
  RETURNING id INTO v_phase_id;

  INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
  VALUES (v_phase_id, 'ES6+ Features', 'Modern syntax that shows up everywhere', 0, 5)
  RETURNING id INTO v_milestone_id;
  INSERT INTO roadmap_modules (milestone_id, title, description, position, module_type, estimated_minutes) VALUES
    (v_milestone_id, 'Destructuring, spread & rest', 'Array/object destructuring, spread everywhere', 0, 'course', 45),
    (v_milestone_id, 'Template literals & tagged templates', 'String interpolation and tag functions', 1, 'course', 30),
    (v_milestone_id, 'Block scope recap', 'let/const semantics revisited in depth', 2, 'reading', 20);

  INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
  VALUES (v_phase_id, 'OOP & Prototypes', 'Objects, prototypes, and classes', 1, 7)
  RETURNING id INTO v_milestone_id;
  INSERT INTO roadmap_modules (milestone_id, title, description, position, module_type, estimated_minutes) VALUES
    (v_milestone_id, 'Prototype chain & inheritance', 'How JS objects really inherit', 0, 'course', 60),
    (v_milestone_id, 'Classes, this, call/apply/bind', 'Class syntax and explicit binding', 1, 'course', 60),
    (v_milestone_id, 'OOP mini project', 'Model a small domain with classes', 2, 'project', 90);

  -- ─── Phase 5: Asynchronous JavaScript ────────────────────────────────────
  INSERT INTO roadmap_phases (roadmap_id, title, description, position, estimated_weeks)
  VALUES (v_roadmap_id, 'Asynchronous JavaScript', 'Event loop, promises, async/await, modules', 4, 2)
  RETURNING id INTO v_phase_id;

  INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
  VALUES (v_phase_id, 'Event Loop & Async', 'How async code actually runs', 0, 8)
  RETURNING id INTO v_milestone_id;
  INSERT INTO roadmap_modules (milestone_id, title, description, position, module_type, estimated_minutes) VALUES
    (v_milestone_id, 'Event loop, call stack & task queue', 'Microtasks vs macrotasks, timers', 0, 'course', 60),
    (v_milestone_id, 'Callbacks & Promises', 'Promise chaining, error handling, combinators', 1, 'course', 60),
    (v_milestone_id, 'Async/await', 'Writing readable async code', 2, 'course', 45),
    (v_milestone_id, 'Async coding challenge', 'Practice problem combining promises and timing', 3, 'dsa_problem', 45);

  INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
  VALUES (v_phase_id, 'Modules', 'Organizing code across files', 1, 3)
  RETURNING id INTO v_milestone_id;
  INSERT INTO roadmap_modules (milestone_id, title, description, position, module_type, estimated_minutes) VALUES
    (v_milestone_id, 'CommonJS vs ES Modules', 'require vs import/export, interop', 0, 'reading', 30),
    (v_milestone_id, 'Dynamic imports', 'Code-splitting with import()', 1, 'reading', 20);

  -- ─── Phase 6: Tooling & Build ─────────────────────────────────────────────
  INSERT INTO roadmap_phases (roadmap_id, title, description, position, estimated_weeks)
  VALUES (v_roadmap_id, 'Tooling & Build', 'Package managers, bundlers, types, tests', 5, 2)
  RETURNING id INTO v_phase_id;

  INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
  VALUES (v_phase_id, 'Package & Build Tooling', 'The npm ecosystem and build pipeline', 0, 6)
  RETURNING id INTO v_milestone_id;
  INSERT INTO roadmap_modules (milestone_id, title, description, position, module_type, estimated_minutes) VALUES
    (v_milestone_id, 'Package managers: npm, yarn, pnpm', 'Lockfiles, semver, workspaces', 0, 'reading', 30),
    (v_milestone_id, 'Bundlers: Webpack, Vite, esbuild', 'Why bundling exists and how to configure it', 1, 'course', 60),
    (v_milestone_id, 'Babel & transpiling', 'Targeting older runtimes', 2, 'reading', 20),
    (v_milestone_id, 'Minification & production builds', 'Shipping optimized bundles', 3, 'reading', 20);

  INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
  VALUES (v_phase_id, 'Type Safety & Testing', 'Catching bugs before runtime', 1, 8)
  RETURNING id INTO v_milestone_id;
  INSERT INTO roadmap_modules (milestone_id, title, description, position, module_type, estimated_minutes) VALUES
    (v_milestone_id, 'TypeScript basics', 'Types, interfaces, generics essentials', 0, 'course', 90),
    (v_milestone_id, 'Unit testing with Jest/Vitest', 'Write and run a real test suite', 1, 'lab', 60),
    (v_milestone_id, 'TDD practice', 'Build a small feature test-first', 2, 'project', 90);

  -- ─── Phase 7: Frameworks & Rendering ──────────────────────────────────────
  INSERT INTO roadmap_phases (roadmap_id, title, description, position, estimated_weeks)
  VALUES (v_roadmap_id, 'Frameworks & Rendering', 'Component frameworks and rendering strategies', 6, 2)
  RETURNING id INTO v_phase_id;

  INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
  VALUES (v_phase_id, 'Frameworks', 'Component-based UI development', 0, 10)
  RETURNING id INTO v_milestone_id;
  INSERT INTO roadmap_modules (milestone_id, title, description, position, module_type, estimated_minutes) VALUES
    (v_milestone_id, 'Pick a framework: React, Vue, Angular or Svelte', 'Compare the mental models before committing', 0, 'reading', 45),
    (v_milestone_id, 'Build a small React app', 'Components, props, state, hooks', 1, 'project', 150),
    (v_milestone_id, 'Web Components & Shadow DOM', 'Framework-agnostic custom elements', 2, 'reading', 30);

  INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
  VALUES (v_phase_id, 'Rendering Patterns', 'Where and when your JS runs', 1, 5)
  RETURNING id INTO v_milestone_id;
  INSERT INTO roadmap_modules (milestone_id, title, description, position, module_type, estimated_minutes) VALUES
    (v_milestone_id, 'CSR vs SSR vs SSG vs ISR', 'Tradeoffs of each rendering strategy', 0, 'course', 45),
    (v_milestone_id, 'Runtime environments: Node.js, Deno, Bun', 'Server-side JS runtimes compared', 1, 'reading', 30);

  -- ─── Phase 8: Real-World Practice ─────────────────────────────────────────
  INSERT INTO roadmap_phases (roadmap_id, title, description, position, estimated_weeks)
  VALUES (v_roadmap_id, 'Real-World Practice', 'Design patterns and a capstone build', 7, 1)
  RETURNING id INTO v_phase_id;

  INSERT INTO roadmap_milestones (phase_id, title, description, position, estimated_hours)
  VALUES (v_phase_id, 'Design Patterns & Capstone', 'Pull it all together', 0, 10)
  RETURNING id INTO v_milestone_id;
  INSERT INTO roadmap_modules (milestone_id, title, description, position, module_type, estimated_minutes) VALUES
    (v_milestone_id, 'Common JS design patterns', 'Module, singleton, observer, factory', 0, 'course', 60),
    (v_milestone_id, 'Capstone project', 'Ship a small full-stack JavaScript app', 1, 'project', 240),
    (v_milestone_id, 'Final assessment', 'Comprehensive check across the roadmap', 2, 'quiz', 30);

END $$;
