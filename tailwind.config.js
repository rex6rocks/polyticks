/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        saffron: {
          DEFAULT: '#FF9933',
          hover: '#E58822',
          light: '#FFF0E6',
        },
        navy: {
          deep: '#0A1628',
          card: '#152342',
          light: '#1E3054',
          border: '#243450',
          subtle: '#2A3C5C',
        },
        emerald: {
          DEFAULT: '#10B981',
          dark: '#059669',
        },
        gold: {
          DEFAULT: '#FFB700',
        },
        crimson: {
          DEFAULT: '#EF4444',
        },
        janta: {
          DEFAULT: '#38BDF8',
        },
        party: {
          DEFAULT: '#FF9933',
        },
        member: {
          DEFAULT: '#A855F7',
        },
        admin: {
          DEFAULT: '#EC4899',
        }
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
        display: ['Inter', 'sans-serif'],
      }
    },
  },
  plugins: [],
}
