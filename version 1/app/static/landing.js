/* ============================================================
   AI Bias Auditor — Landing Page JavaScript
   Parallax · Scroll Animations · Counters · Nav · Marquee
   ============================================================ */

'use strict';

/* ── NAVBAR ─────────────────────────────────────────────────── */
const navbar = document.getElementById('navbar');
const navHamburger = document.getElementById('navHamburger');
const navMobile = document.getElementById('navMobile');

function updateNavbar() {
  if (window.scrollY > 30) {
    navbar.classList.add('scrolled');
  } else {
    navbar.classList.remove('scrolled');
  }
}

navHamburger && navHamburger.addEventListener('click', () => {
  navMobile.classList.toggle('open');
  const spans = navHamburger.querySelectorAll('span');
  const isOpen = navMobile.classList.contains('open');
  if (isOpen) {
    spans[0].style.cssText = 'transform: rotate(45deg) translate(5px, 5px)';
    spans[1].style.cssText = 'opacity: 0';
    spans[2].style.cssText = 'transform: rotate(-45deg) translate(5px, -5px)';
  } else {
    spans.forEach(s => s.style.cssText = '');
  }
});

// Close mobile menu when clicking a link
navMobile && navMobile.querySelectorAll('a').forEach(link => {
  link.addEventListener('click', () => {
    navMobile.classList.remove('open');
    navHamburger.querySelectorAll('span').forEach(s => s.style.cssText = '');
  });
});

/* ── PARALLAX ───────────────────────────────────────────────── */
let rafPending = false;
const parallaxEls = document.querySelectorAll('[data-parallax]');

function runParallax() {
  const scrollY = window.scrollY;
  parallaxEls.forEach(el => {
    const speed = parseFloat(el.dataset.parallax) || 0.3;
    el.style.transform = `translateY(${scrollY * speed}px)`;
  });
}

/* ── SCROLL ANIMATION OBSERVER ──────────────────────────────── */
const animateObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.classList.add('animate-in');
      animateObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.15, rootMargin: '0px 0px -40px 0px' });

document.querySelectorAll('[data-animate]').forEach(el => {
  animateObserver.observe(el);
});

/* ── HERO STAT BADGES ───────────────────────────────────────── */
const statBadges = document.querySelectorAll('.stat-badge');
statBadges.forEach((badge, i) => {
  setTimeout(() => {
    badge.classList.add('visible');
  }, 800 + i * 160);
});

/* ── COUNTER ANIMATION ──────────────────────────────────────── */
function animateCounter(el) {
  const target = parseInt(el.dataset.target, 10);
  if (isNaN(target)) return;
  const suffix = el.dataset.suffix || '';
  const duration = 1800;
  const startTime = performance.now();

  function tick(now) {
    const elapsed = now - startTime;
    const progress = Math.min(elapsed / duration, 1);
    // ease-out cubic
    const eased = 1 - Math.pow(1 - progress, 3);
    el.textContent = Math.round(eased * target) + suffix;
    if (progress < 1) requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);
}

const counterObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.querySelectorAll('[data-counter]').forEach(animateCounter);
      counterObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.4 });

const bentoStats = document.querySelector('.bento-card-stats');
if (bentoStats) counterObserver.observe(bentoStats);

/* ── FAIRNESS BAR ANIMATION ─────────────────────────────────── */
const barObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.querySelectorAll('.fairness-bar-fill[data-width]').forEach(bar => {
        // small delay then set width to trigger CSS transition
        setTimeout(() => {
          bar.style.width = bar.dataset.width;
        }, 200);
      });
      barObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.4 });

const bentoChart = document.querySelector('.bento-card-chart');
if (bentoChart) barObserver.observe(bentoChart);

/* ── TECH TAG STAGGER ───────────────────────────────────────── */
const techTagObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      const tags = entry.target.querySelectorAll('.tech-tag');
      tags.forEach((tag, i) => {
        setTimeout(() => tag.classList.add('tag-visible'), i * 80);
      });
      techTagObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.3 });

const techCard = document.querySelector('.bento-card-tech');
if (techCard) techTagObserver.observe(techCard);

/* ── STEPS STAGGER ──────────────────────────────────────────── */
const stepsObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      const steps = entry.target.querySelectorAll('.step-item');
      steps.forEach((step, i) => {
        setTimeout(() => step.classList.add('animate-in'), i * 150);
      });
      stepsObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.2 });

const stepsGrid = document.querySelector('.steps-grid');
if (stepsGrid) stepsObserver.observe(stepsGrid);

/* ── UNIFIED SCROLL HANDLER ─────────────────────────────────── */
function onScroll() {
  if (!rafPending) {
    rafPending = true;
    requestAnimationFrame(() => {
      updateNavbar();
      runParallax();
      rafPending = false;
    });
  }
}

window.addEventListener('scroll', onScroll, { passive: true });
updateNavbar();
runParallax();

/* ── SMOOTH SCROLL FOR ANCHOR LINKS ─────────────────────────── */
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', e => {
    const target = document.querySelector(anchor.getAttribute('href'));
    if (target) {
      e.preventDefault();
      const navH = navbar ? navbar.offsetHeight : 80;
      const top = target.getBoundingClientRect().top + window.scrollY - navH - 16;
      window.scrollTo({ top, behavior: 'smooth' });
    }
  });
});

/* ── HANDLE DEMO QUERY PARAM ON AUDIT PAGE ───────────────────── */
// If on /audit page with ?demo=xxx, auto-load that demo
if (window.location.pathname === '/audit') {
  const params = new URLSearchParams(window.location.search);
  const demoId = params.get('demo');
  if (demoId) {
    // Wait for DOMContentLoaded + loadDemos() to finish
    window.addEventListener('DOMContentLoaded', () => {
      setTimeout(() => {
        if (typeof loadDemo === 'function') {
          loadDemo(demoId);
        }
      }, 600);
    });
  }
}
