// Tailwind CSS v4 runs entirely through its PostCSS plugin.
// Without this file Tailwind never processes globals.css and no styles render.
const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};

export default config;
