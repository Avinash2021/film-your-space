# Ruchi — Portfolio

A single-page product design portfolio. Plain HTML, CSS and JavaScript — no build
step, no framework, no npm. Open `index.html` in a browser and it works.

```
ruchi-portfolio/
├── index.html            all the page content
├── css/styles.css        all the styling (design tokens at the top)
├── js/
│   ├── projects-data.js  ← YOUR CONTENT: projects + testimonials
│   └── script.js         rendering, scroll progress, reveal animations
└── assets/
    ├── images/           project covers + your photo go here
    └── resume/           Ruchi_resume_2026.pdf
```

## Page structure

| # | Section | What it does |
|---|---------|--------------|
| 1 | Floating pill nav | Fixed, centred, condenses on scroll. Highlights the section you're reading. |
| 2 | Hero | Availability badge, big editorial headline, intro, CTAs, social row, side card with your photo + quick facts. |
| 3 | Marquee | Slow-scrolling strip of specialisms on a dark bar. |
| 4 | Stats | Four numbers pulled from the résumé. |
| 5 | Selected work | Case study cards generated from `projects-data.js`. |
| 6 | Process | Four numbered steps: Understand → Research → Design → Ship. |
| 7 | About | Long-form bio, tool chips, education + "currently" cards. |
| 8 | Experience | Timeline of roles. |
| 9 | Kind words | Testimonial cards (auto-hides if the list is empty). |
| 10 | Playground | The off-the-clock cards. |
| 11 | Contact | Dark rounded panel with the big email address. |
| 12 | Footer | Copyright + back to top. |

---

## The three things to do next

### 1. Add your case study links

Open `js/projects-data.js`. Each project is one `{ ... }` block. To make a card
clickable, change two fields:

```js
link: "https://www.notion.so/your-case-study",
linkLabel: "Read the case study"
```

While `link` is `"#"`, the card shows the `linkLabel` as plain grey text instead
of a link — so "Case study coming soon" is safe to leave in place.

To **add a project**: copy a whole `{ ... }` block, paste it into the list, put a
comma between blocks, and edit the text. Nothing else needs to change.

**Ordering matters for layout:** the 1st, 4th, 7th… project renders as a wide
full-width card with the image on the left. Put your strongest work first and
fourth.

### 2. Add project cover images

Drop images into `assets/images/` and point at them:

```js
image: "assets/images/kharch.jpg",
tint:  "#F3EDE0"
```

Landscape, roughly **1600 × 1000px**, under ~400KB each. With `image: ""` the
card draws a soft tinted panel with the project's initial instead — the page
looks intentional either way, so add them whenever you're ready.

### 3. Fill in the placeholders

Search `index.html` for `TODO` — there are three spots:

- **Social links** — the `href="#"` values in the hero and in the contact
  section (LinkedIn, Behance, Dribbble).
- **Your photo** — save a square image as `assets/images/ruchi.jpg`, then in the
  hero swap the `<div class="hero-photo">…</div>` block for:
  ```html
  <img class="hero-photo" src="assets/images/ruchi.jpg" alt="Ruchi">
  ```
- **Testimonials** — the three quotes in `projects-data.js` are written as
  visible placeholders. Replace them with real quotes, or delete all three and
  the whole "Kind words" section (and its nav link) removes itself.

---

## Changing the look

All colours and fonts are CSS variables at the top of `css/styles.css`:

```css
--paper:  #F6F2EC;   /* warm off-white page background */
--card:   #FFFDFA;   /* card surfaces */
--ink:    #141210;   /* text and dark panels */
--accent: #FF5B2E;   /* links, highlights, the CTA */
--muted:  #7A7168;   /* secondary text */
```

Change `--accent` in that one place and every highlight on the page follows.

Fonts: **Fraunces** (serif, headlines), **Plus Jakarta Sans** (body), **IBM Plex
Mono** (labels and numbers). They load from Google Fonts in the `<head>` of
`index.html` — swap the `<link>` and the `--font-*` variables together if you
want different ones.

## Publishing

It's a static site, so anything works:

- **GitHub Pages** — push the folder to a repo, then Settings → Pages → deploy
  from branch.
- **Netlify / Vercel** — drag the folder onto the dashboard.

Custom domain: point it at whichever host you picked; no config in the code.

## Notes

- Responsive down to ~360px; grids collapse to one column on mobile.
- Keyboard accessible: skip link, visible focus rings, semantic headings.
- Every animation is disabled automatically for visitors with
  "reduce motion" enabled in their OS settings.
- Project and testimonial text is HTML-escaped when rendered, so pasting an
  ampersand or a quote mark can't break the layout.
