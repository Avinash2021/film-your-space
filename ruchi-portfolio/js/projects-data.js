/* ==========================================================================
   YOUR CONTENT LIVES HERE
   ==========================================================================
   Two lists in this one file:

     1. PROJECTS      — the case study cards in the "Selected work" section
     2. TESTIMONIALS  — the quote cards in the "Kind words" section

   You never need to touch index.html to add a project. Copy a { ... } block,
   paste it into the list, change the text. That's it.
   ========================================================================== */


/* --------------------------------------------------------------------------
   1. PROJECTS
   --------------------------------------------------------------------------
   Fields on each project:

   - title      : the project name (card heading)
   - role       : your role + company, shown in orange under the title
   - year       : shown small in the top-right of the thumbnail, e.g. "2025"
   - tags       : 2–4 short labels, e.g. ["Fintech", "Design System"]
   - summary    : 1–3 sentences on the problem and what you did
   - image      : path to a cover image, e.g. "assets/images/kharch.jpg"
                  Leave it as "" and a tinted placeholder is drawn instead.
                  Recommended size: 1600 × 1000px (landscape).
   - tint       : background colour of that placeholder / image frame.
                  Any CSS colour. Keep them soft so the type stays readable.
   - link       : URL of your full case study (Figma, Notion, Behance, Medium…)
                  Leave as "#" while it isn't live yet.
   - linkLabel  : the text on the link. When link is "#" this shows as plain
                  grey text instead of a clickable link.

   LAYOUT NOTE: the 1st, 4th, 7th… project automatically renders as a wide
   full-width card with the image on the left. So put your strongest work
   first, and 4th.
   -------------------------------------------------------------------------- */

const PROJECTS = [
  {
    title: "Mashreq Bank Design System",
    role: "Product Designer · Gloify",
    year: "2025 — now",
    tags: ["Fintech", "Design System", "Enterprise"],
    summary:
      "One source of truth sitting under an entire regional bank's product suite — components, patterns and accessibility standards used by multiple teams shipping in parallel, across several product verticals at once.",
    image: "",
    tint: "#E7EDF3",
    link: "#",
    linkLabel: "Case study coming soon"
  },
  {
    title: "Kalppo",
    role: "Founding Product Designer",
    year: "2025",
    tags: ["Edtech", "0→1", "Mobile & Web"],
    summary:
      "A study-abroad platform designed from a blank canvas — turning a genuinely confusing, high-stakes decision into a guided, personalised experience with built-in mentorship matching and progress tracking.",
    image: "",
    tint: "#EDE7F3",
    link: "#",
    linkLabel: "Case study coming soon"
  },
  {
    title: "Kharch",
    role: "Founding Product Designer, Freelance",
    year: "2024",
    tags: ["Fintech", "Consumer App", "0→1"],
    summary:
      "A personal finance app built around how Indian adults actually track money, not how finance apps assume they do. Research-led work that helped the founder close pre-seed funding and a 5,000-person waitlist.",
    image: "",
    tint: "#F3EDE0",
    link: "#",
    linkLabel: "Case study coming soon"
  },
  {
    title: "Vichaar",
    role: "Product Designer, Freelance",
    year: "2024",
    tags: ["Web3", "Community", "MVP"],
    summary:
      "An information hub for the Web3-curious — articles, news and a way to find your local community — designed and shipped as an MVP alongside the product manager, reaching 200+ early users at launch.",
    image: "",
    tint: "#E4EFE7",
    link: "#",
    linkLabel: "Case study coming soon"
  },
  {
    title: "Emotion-Aware AI Assistant",
    role: "Product Designer · Techolution",
    year: "2024",
    tags: ["AI", "Research", "Feature"],
    summary:
      "Led UX research and design for an AI application end to end, then partnered with engineering to ship an emotion-detection feature that reads user sentiment and adapts its response to it.",
    image: "",
    tint: "#F3E5E5",
    link: "#",
    linkLabel: "Case study coming soon"
  }

  /* Copy this shape to add a new project — remember the leading comma:

  ,{
    title: "Your New Project",
    role: "Your Role · Company",
    year: "2026",
    tags: ["Category", "Platform"],
    summary: "One to three sentences on the problem and what you did about it.",
    image: "assets/images/your-cover.jpg",
    tint: "#EFE9E0",
    link: "https://your-case-study-link.com",
    linkLabel: "Read the case study"
  }

  */
];


/* --------------------------------------------------------------------------
   2. TESTIMONIALS
   --------------------------------------------------------------------------
   - quote : what they said (keep it to 2–3 sentences so cards stay even)
   - name  : who said it
   - role  : their title and company

   PLACEHOLDERS: the three below are written as examples so you can see the
   layout. Replace them with real quotes before publishing — or delete the
   entries entirely and the whole "Kind words" section hides itself.
   -------------------------------------------------------------------------- */

const TESTIMONIALS = [
  {
    quote:
      "Placeholder — replace with a real quote. Ruchi joined as our first designer and had a working product flow in front of users within weeks.",
    name: "Name Surname",
    role: "Founder · Company"
  },
  {
    quote:
      "Placeholder — replace with a real quote. She asks the questions nobody else in the room thought to ask, and the design is better for it every time.",
    name: "Name Surname",
    role: "Product Manager · Company"
  },
  {
    quote:
      "Placeholder — replace with a real quote. Handoff was the cleanest I've had: components, states and edge cases all already thought through.",
    name: "Name Surname",
    role: "Engineering Lead · Company"
  }
];
