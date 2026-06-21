// @ts-check
import { dirname } from 'path'
import { fileURLToPath } from 'url'
import js from '@eslint/js'
import tseslint from 'typescript-eslint'
import jsxA11y from 'eslint-plugin-jsx-a11y'
import reactPlugin from 'eslint-plugin-react'
import reactHooks from 'eslint-plugin-react-hooks'
import nextPlugin from '@next/eslint-plugin-next'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM ENFORCEMENT
//
// These patterns are banned to protect the semantic token system defined in
// globals.css. Violations mean "use the CSS-variable-backed Tailwind class
// instead of the raw colour utility."
//
// Allowed alternatives:
//   bg-primary  bg-secondary  bg-muted  bg-card  bg-background  bg-accent
//   bg-ai       bg-destructive bg-success bg-warning
//   text-foreground  text-muted-foreground  text-primary  text-ai
//   text-success  text-destructive  text-warning-foreground
//   border-border  border-primary  border-ai  ring-ring
// ─────────────────────────────────────────────────────────────────────────────

const RAW_COLOR_SHADES = [
  'slate', 'gray', 'zinc', 'neutral', 'stone',
  'red', 'orange', 'amber', 'yellow', 'lime',
  'green', 'emerald', 'teal', 'cyan', 'sky',
  'blue', 'indigo', 'violet', 'purple', 'fuchsia',
  'pink', 'rose',
].join('|')

const COLOR_PROPERTIES = [
  'bg', 'text', 'border', 'ring', 'shadow', 'fill', 'stroke',
  'accent', 'from', 'via', 'to', 'outline', 'decoration',
  'divide', 'caret', 'placeholder', 'inset-shadow',
].join('|')

// Matches e.g. bg-amber-500, text-gray-900, border-slate-200
const RAW_COLOR_PATTERN = `(${COLOR_PROPERTIES})-(${RAW_COLOR_SHADES})-[0-9]`

// Matches absolute colours: bg-white bg-black text-white text-black
const ABSOLUTE_COLOR_PATTERN = `(bg|text|border|ring)-(white|black)`

// Matches arbitrary hex: bg-[#fff] text-[#1a2b3c]
const HEX_ARBITRARY_PATTERN = String.raw`\[#[0-9a-fA-F]`

// Matches arbitrary RGB/HSL: bg-[rgb(...)] text-[hsl(...)]
const COLOR_FN_PATTERN = String.raw`\[(?:rgb|hsl|oklch|lch)\(`

// ─────────────────────────────────────────────────────────────────────────────

/** @type {import('typescript-eslint').Config} */
export default tseslint.config(
  // ── 1. Ignore generated / built output ─────────────────────────────────
  {
    ignores: [
      '.next/**',
      'node_modules/**',
      'out/**',
      'public/**',
      '*.min.js',
      'eslint-rules/**',
      '**/*.css',
      '**/*.postcss',
    ],
  },

  // ── 2. JS base ──────────────────────────────────────────────────────────
  js.configs.recommended,

  // ── 3. TypeScript — strict ──────────────────────────────────────────────
  ...tseslint.configs.strict,
  {
    files: ['**/*.ts', '**/*.tsx'],
    languageOptions: {
      parserOptions: {
        project: true,
        tsconfigRootDir: __dirname,
      },
    },
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-non-null-assertion': 'error',
      '@typescript-eslint/consistent-type-imports': [
        'error',
        { prefer: 'type-imports', fixStyle: 'inline-type-imports' },
      ],
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      // Allow require() only in config files
      '@typescript-eslint/no-require-imports': 'error',
    },
  },

  // ── 4. React ─────────────────────────────────────────────────────────────
  {
    plugins: {
      react: reactPlugin,
      'react-hooks': reactHooks,
    },
    settings: { react: { version: 'detect' } },
    rules: {
      ...reactPlugin.configs.recommended.rules,
      ...reactHooks.configs.recommended.rules,
      'react/react-in-jsx-scope': 'off',      // Not needed in Next.js
      'react/prop-types': 'off',              // TypeScript handles this
      'react/self-closing-comp': 'error',
      'react/jsx-no-useless-fragment': ['error', { allowExpressions: true }],
      'react/jsx-sort-props': ['warn', { callbacksLast: true, shorthandFirst: true }],
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'error',
    },
  },

  // ── 5. Next.js ───────────────────────────────────────────────────────────
  {
    plugins: { '@next/next': nextPlugin },
    rules: {
      ...nextPlugin.configs.recommended.rules,
      ...nextPlugin.configs['core-web-vitals'].rules,
    },
  },

  // ── 6. Accessibility (WCAG 2.2 AA) ─────────────────────────────────────
  {
    plugins: { 'jsx-a11y': jsxA11y },
    rules: {
      ...jsxA11y.configs.recommended.rules,
      // Enforce beyond the defaults
      'jsx-a11y/anchor-is-valid': 'error',
      'jsx-a11y/no-autofocus': 'warn',
      'jsx-a11y/interactive-supports-focus': 'error',
    },
  },

  // ── 7. Tailwind CSS v4 ───────────────────────────────────────────────────
  // Validates class names, detects conflicts, prefers theme tokens
  // Disabled due to ESLint flat config compatibility issues
  // tailwind.configs.strict,

  // ── 8. Design System Enforcement ────────────────────────────────────────
  // These rules guard the semantic token system in globals.css.
  // A violation means you're bypassing CSS variables and hardcoding a colour.
  {
    files: ['**/*.tsx', '**/*.jsx', '**/*.ts', '**/*.js', '**/*.mjs'],
    rules: {
      'no-restricted-syntax': [
        'error',

        // ── Ban: dark: prefix ─────────────────────────────────────────────
        // Themes are handled by CSS variables under .dark — components must
        // NEVER know which theme is active.
        {
          selector: `JSXAttribute[name.name="className"] Literal[value=/\\bdark:/]`,
          message:
            '[Design] Do not use the dark: prefix. ' +
            'Use semantic tokens (bg-card, text-foreground) — the .dark class on <html> handles dark mode automatically.',
        },
        {
          selector: `JSXAttribute[name.name="className"] TemplateElement[value.raw=/\\bdark:/]`,
          message:
            '[Design] Do not use the dark: prefix in template literals. ' +
            'Use semantic tokens — globals.css .dark handles theme switching.',
        },

        // ── Ban: raw Tailwind colour shades ──────────────────────────────
        // e.g. bg-amber-600, text-gray-900, border-cyan-400
        {
          selector: `JSXAttribute[name.name="className"] Literal[value=/${RAW_COLOR_PATTERN}/]`,
          message:
            '[Design] Raw Tailwind colour class detected. ' +
            'Use semantic tokens: bg-primary, bg-ai, text-foreground, text-muted-foreground, ' +
            'border-border, bg-card, bg-muted, bg-success, bg-destructive, bg-warning.',
        },
        {
          selector: `JSXAttribute[name.name="className"] TemplateElement[value.raw=/${RAW_COLOR_PATTERN}/]`,
          message:
            '[Design] Raw Tailwind colour class in template literal. Use semantic tokens from globals.css.',
        },

        // ── Ban: bg-white, text-black, etc. ──────────────────────────────
        {
          selector: `JSXAttribute[name.name="className"] Literal[value=/${ABSOLUTE_COLOR_PATTERN}/]`,
          message:
            '[Design] Avoid bg-white / bg-black / text-white / text-black. ' +
            'Use bg-background, bg-card, text-foreground, or text-primary-foreground.',
        },
        {
          selector: `JSXAttribute[name.name="className"] TemplateElement[value.raw=/${ABSOLUTE_COLOR_PATTERN}/]`,
          message:
            '[Design] Avoid absolute colour names. Use semantic tokens from globals.css.',
        },

        // ── Ban: arbitrary hex values ─────────────────────────────────────
        // e.g. bg-[#fff], text-[#1a2b3c]
        {
          selector: `JSXAttribute[name.name="className"] Literal[value=/${HEX_ARBITRARY_PATTERN}/]`,
          message:
            '[Design] No hardcoded hex colour in className. ' +
            'Add a CSS variable to globals.css (:root and .dark), register it in @theme inline, ' +
            'then use the semantic class name.',
        },
        {
          selector: `JSXAttribute[name.name="className"] TemplateElement[value.raw=/${HEX_ARBITRARY_PATTERN}/]`,
          message:
            '[Design] No hardcoded hex colour in className template. ' +
            'Add a CSS variable to globals.css instead.',
        },

        // ── Ban: arbitrary colour functions ───────────────────────────────
        // e.g. bg-[rgb(255,0,0)], text-[hsl(0,0%,0%)]
        {
          selector: `JSXAttribute[name.name="className"] Literal[value=/${COLOR_FN_PATTERN}/]`,
          message:
            '[Design] No hardcoded colour function in className. Use semantic CSS variable tokens.',
        },
        {
          selector: `JSXAttribute[name.name="className"] TemplateElement[value.raw=/${COLOR_FN_PATTERN}/]`,
          message:
            '[Design] No hardcoded colour function in className template. Use semantic CSS variable tokens.',
        },

        // ── Warn: inline style prop ───────────────────────────────────────
        // Inline styles bypass the token system and the theme.
        // Exception: dynamic CSS custom properties (--var: value) are allowed.
        // Use a `// eslint-disable-next-line no-restricted-syntax` comment
        // with a brief explanation when a dynamic value genuinely needs it.
        {
          selector:
            'JSXAttribute[name.name="style"] > JSXExpressionContainer > ObjectExpression',
          message:
            '[Design] Avoid inline style props — they bypass the design token system. ' +
            'Prefer Tailwind utilities or add a CSS variable. ' +
            'If a dynamic value is unavoidable (e.g. --progress-width), disable this line with a comment explaining why.',
        },

        // ── Ban: useEffect for data fetching ─────────────────────────────
        {
          selector:
            "CallExpression[callee.name='useEffect'] > ArrowFunctionExpression > BlockStatement > ExpressionStatement > CallExpression[callee.name='fetch']",
          message:
            '[Architecture] Do not fetch inside useEffect. ' +
            'Use Server Components to fetch by default, or SWR/React Query for client-side. ' +
            'See: frontend/CLAUDE.md → Data Fetching.',
        },

        // ── Responsive: ban w-screen ─────────────────────────────────────
        // w-screen = 100vw which causes horizontal overflow on iOS when the
        // page has a scrollbar (scrollbar width is included in vw).
        // Use w-full instead. If you genuinely need viewport width, add a
        // CSS custom property or use the -webkit-fill-available pattern.
        {
          selector: `JSXAttribute[name.name="className"] Literal[value=/\\bw-screen\\b/]`,
          message:
            '[Responsive] Avoid w-screen — it causes horizontal overflow on iOS. ' +
            'Use w-full for full-width elements. ' +
            'If you need 100vw, add a CSS variable in globals.css.',
        },
        {
          selector: `JSXAttribute[name.name="className"] TemplateElement[value.raw=/\\bw-screen\\b/]`,
          message:
            '[Responsive] Avoid w-screen — use w-full instead.',
        },

        // ── Responsive: ban h-screen ─────────────────────────────────────
        // h-screen = 100vh which on mobile browsers excludes the browser
        // chrome, causing content to be cut off behind address bars.
        // Use min-h-dvh or h-dvh (dynamic viewport height) instead.
        {
          selector: `JSXAttribute[name.name="className"] Literal[value=/\\bh-screen\\b/]`,
          message:
            '[Responsive] Avoid h-screen — on mobile browsers the address bar is included, ' +
            'cutting off content. Use h-dvh or min-h-dvh (dynamic viewport height).',
        },
        {
          selector: `JSXAttribute[name.name="className"] TemplateElement[value.raw=/\\bh-screen\\b/]`,
          message:
            '[Responsive] Avoid h-screen — use h-dvh or min-h-dvh instead.',
        },

        // ── Responsive: ban overflow-x-hidden on root elements ───────────
        // Applying overflow-x-hidden to body/html breaks position:sticky and
        // masks real overflow bugs rather than fixing them. Fix the root cause.
        {
          selector:
            'JSXAttribute[name.name="className"][parent.name.name=/^(html|body|Html|Body)$/] Literal[value=/\\boverflow-x-hidden\\b/]',
          message:
            '[Responsive] Do not apply overflow-x-hidden to html/body — it breaks position:sticky. ' +
            'Find and fix the element that is actually overflowing.',
        },

        // ── Responsive: ban fixed arbitrary widths without responsive intent ──
        // A bare w-[Npx] with no sm:/md:/lg: sibling suggests the developer
        // forgot to make it responsive. This is a warning, not a hard error.
        {
          selector: `JSXAttribute[name.name="className"] Literal[value=/(?<![\\w:])w-\\[\\d+px\\]/]`,
          message:
            '[Responsive] Fixed pixel width detected. ' +
            'Add a responsive variant (e.g. w-full sm:w-[320px]) or use a Tailwind sizing token. ' +
            'Disable this line with a comment if the fixed width is genuinely intentional.',
        },
      ],

      // ── General code quality ─────────────────────────────────────────────
      'prefer-const': 'error',
      'no-console': ['warn', { allow: ['warn', 'error'] }],
      'no-debugger': 'error',
      eqeqeq: ['error', 'always'],
    },
  },

  // ── 9. Relax rules for config / tooling files ────────────────────────────
  {
    files: ['*.config.*', 'eslint.config.*', 'postcss.config.*', 'next.config.*'],
    rules: {
      '@typescript-eslint/no-require-imports': 'off',
      '@typescript-eslint/no-explicit-any': 'off',
    },
  },
)
