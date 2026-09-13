# Cider website

React, TypeScript, Tailwind CSS, and Vite. Run `npm ci` then `npm run dev` from this folder. `npm run build` creates the production site in `dist/`.

User guides live in `docs/*.md` and render through React Markdown with GFM support. Add a guide to the navigation in `src/Docs.tsx`. Links use `#/docs/<filename>` so direct links work on GitHub Pages. Public assets use Vite's `/Cider/` base path.

The warm palette and fonts are defined in `src/styles.css`. Background motion and reveal transitions respect reduced-motion preferences. Manrope and Fraunces are bundled through Fontsource with their included licenses.

Screenshots in `public/images/` were supplied by the repository owner on September 13, 2026. The Cider mascot is the app's existing artwork. Screenshots depict the early native app; the checklist on the landing page is illustrative.

GitHub Pages deploys after pushes to main that change the site. App downloads point to the latest GitHub release.
