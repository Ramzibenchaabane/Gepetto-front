import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        accenture: {
          primary: "#A100FF",
          secondary: "#000000",
          accent: "#32C5FF",
        },
      },
    },
  },
  plugins: [],
};
export default config;