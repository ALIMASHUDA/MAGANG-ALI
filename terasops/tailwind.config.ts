import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        // Brand palette — dark blue + white, low-chroma, no gradients
        ink: {
          50: "#f6f8fb",
          100: "#e9eef5",
          200: "#cdd9e8",
          300: "#a4bad6",
          400: "#7596c0",
          500: "#4f77aa",
          600: "#3a5f8e",
          700: "#2f4d73",
          800: "#243c5b",
          900: "#1b2c44",
          950: "#0f1b2e",
        },
        primary: {
          DEFAULT: "#1f3a5f",
          foreground: "#f6f8fb",
        },
      },
      fontFamily: {
        sans: ["var(--font-inter)", "system-ui", "sans-serif"],
        mono: ["var(--font-geist-mono)", "ui-monospace", "monospace"],
      },
      transitionTimingFunction: {
        // Kurva organik ala Apple — cepat di awal, melandai lembut.
        smooth: "cubic-bezier(0.22, 1, 0.36, 1)",
      },
    },
  },
  plugins: [],
};

export default config;
