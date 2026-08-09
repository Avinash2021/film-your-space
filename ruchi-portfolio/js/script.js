/* ==========================================================================
   script.js — five small jobs
   1. Render the case study cards from PROJECTS
   2. Render the testimonial cards from TESTIMONIALS (hides if empty)
   3. Scroll progress line at the top of the viewport
   4. Highlight the nav link for the section you're currently reading
   5. Reveal sections gently as they scroll into view
      (all motion is skipped if the visitor has "reduce motion" turned on)
   ========================================================================== */

document.addEventListener("DOMContentLoaded", () => {
  renderProjects();
  renderTestimonials();
  setupProgressAndNav();
  setupScrollReveal();
});

/* --------------------------------------------------------------------
   1. CASE STUDY CARDS
   -------------------------------------------------------------------- */
function renderProjects() {
  const grid = document.getElementById("work-grid");
  if (!grid || typeof PROJECTS === "undefined") return;

  grid.innerHTML = PROJECTS.map((project, i) => {
    // 1st, 4th, 7th… card renders wide, with the cover image on the left
    const wide = i % 3 === 0 ? " is-wide" : "";
    const index = String(i + 1).padStart(2, "0");

    const tags = (project.tags || [])
      .map((tag) => `<span class="tag">${escapeHTML(tag)}</span>`)
      .join("");

    const thumbInner = project.image
      ? `<img src="${escapeAttr(project.image)}" alt="${escapeAttr(project.title)} cover">`
      : `<span class="work-thumb-mark" aria-hidden="true">${escapeHTML(
          (project.title || "?").trim().charAt(0)
        )}</span>`;

    const isRealLink = project.link && project.link !== "#";
    const linkHTML = isRealLink
      ? `<a class="work-link" href="${escapeAttr(project.link)}" target="_blank" rel="noopener">
           ${escapeHTML(project.linkLabel || "Read the case study")} <span aria-hidden="true">→</span>
         </a>`
      : `<span class="work-link work-link-disabled">${escapeHTML(
          project.linkLabel || "Case study coming soon"
        )}</span>`;

    return `
      <article class="work-card${wide}">
        <div class="work-thumb" style="--tint:${escapeAttr(project.tint || "#EFE9E0")}">
          <span class="work-index">${index}</span>
          ${project.year ? `<span class="work-year">${escapeHTML(project.year)}</span>` : ""}
          ${thumbInner}
        </div>
        <div class="work-body">
          <div class="work-tags">${tags}</div>
          <h3 class="work-title">${escapeHTML(project.title)}</h3>
          <p class="work-role">${escapeHTML(project.role || "")}</p>
          <p class="work-summary">${escapeHTML(project.summary || "")}</p>
          ${linkHTML}
        </div>
      </article>
    `;
  }).join("");
}

/* --------------------------------------------------------------------
   2. TESTIMONIALS — the section removes itself if the list is empty
   -------------------------------------------------------------------- */
function renderTestimonials() {
  const grid = document.getElementById("quote-grid");
  if (!grid) return;

  const list = typeof TESTIMONIALS === "undefined" ? [] : TESTIMONIALS;
  const section = document.getElementById("testimonials");

  if (!list.length) {
    if (section) section.remove();
    const navLink = document.querySelector('.nav-links a[href="#testimonials"]');
    if (navLink) navLink.remove();
    return;
  }

  grid.innerHTML = list
    .map(
      (t) => `
      <blockquote class="quote-card">
        <span class="quote-mark" aria-hidden="true">"</span>
        <p class="quote-text">${escapeHTML(t.quote)}</p>
        <footer class="quote-who">
          <span class="quote-name">${escapeHTML(t.name)}</span>
          <span class="quote-role">${escapeHTML(t.role)}</span>
        </footer>
      </blockquote>
    `
    )
    .join("");
}

/* Basic escaping so pasted text never breaks the page */
function escapeHTML(str) {
  const div = document.createElement("div");
  div.textContent = str == null ? "" : String(str);
  return div.innerHTML;
}
function escapeAttr(str) {
  return escapeHTML(str).replace(/"/g, "&quot;");
}

/* --------------------------------------------------------------------
   3 + 4. SCROLL PROGRESS LINE, STICKY-NAV SHADOW, ACTIVE SECTION
   -------------------------------------------------------------------- */
function setupProgressAndNav() {
  const bar = document.getElementById("progress");
  const nav = document.querySelector(".nav");
  const links = Array.from(document.querySelectorAll(".nav-links a"));
  const sections = links
    .map((a) => document.querySelector(a.getAttribute("href")))
    .filter(Boolean);

  function update() {
    const scrollTop = window.scrollY;
    const docHeight = document.documentElement.scrollHeight - window.innerHeight;

    if (bar) {
      const progress = docHeight > 0 ? scrollTop / docHeight : 0;
      bar.style.width = `${Math.min(progress, 1) * 100}%`;
    }

    if (nav) nav.classList.toggle("is-stuck", scrollTop > 24);

    // the section whose top has most recently passed the middle of the screen
    let currentIndex = -1;
    sections.forEach((section, i) => {
      if (section.getBoundingClientRect().top <= window.innerHeight * 0.45) {
        currentIndex = i;
      }
    });
    links.forEach((link, i) => link.classList.toggle("is-current", i === currentIndex));
  }

  update();
  window.addEventListener("scroll", update, { passive: true });
  window.addEventListener("resize", update);
}

/* --------------------------------------------------------------------
   5. SCROLL REVEAL
   -------------------------------------------------------------------- */
function setupScrollReveal() {
  const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const revealables = document.querySelectorAll(
    ".section-head, .work-card, .process-card, .timeline-item, .quote-card, .play-card, .stat, .about-side, .about-text, .contact-inner"
  );

  if (prefersReducedMotion || !("IntersectionObserver" in window)) {
    revealables.forEach((el) => el.classList.add("is-visible"));
    return;
  }

  revealables.forEach((el) => el.classList.add("reveal"));

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.1 }
  );

  revealables.forEach((el) => observer.observe(el));
}
