/**
 * audit.js — Audit workspace enhancements
 *
 * Responsibilities (in order of execution):
 *  1. Apply Chart.js global defaults
 *  2. Wire up tab bar click handlers (CSS-based: show/hide pane divs)
 *  3. Patch window.renderPreAuditResult / renderFullAuditResult / configureDataset
 *     to (a) activate the right tab, (b) draw charts, (c) upgrade headers
 *  4. Upgrade native checkboxes in columnRows to toggle switches
 *     (after app.js writes the HTML)
 *
 * Does NOT move any DOM elements.
 * Does NOT modify any fetch/event binding logic in app.js.
 * All IDs app.js uses exist in the HTML — they live inside tab panes.
 */
'use strict';

/* ─── CHART.JS DEFAULTS ──────────────────────────────────────── */
function applyChartDefaults() {
  if (typeof Chart === 'undefined') return;
  Chart.defaults.font.family = "'Inter', system-ui, sans-serif";
  Chart.defaults.color = '#71717a';
  Chart.defaults.borderColor = '#27272a';
  Chart.defaults.plugins.legend.display = false;
  Chart.defaults.plugins.tooltip.backgroundColor = '#18181b';
  Chart.defaults.plugins.tooltip.borderColor = '#3f3f46';
  Chart.defaults.plugins.tooltip.borderWidth = 1;
  Chart.defaults.plugins.tooltip.titleColor = '#fafafa';
  Chart.defaults.plugins.tooltip.bodyColor = '#a1a1aa';
  Chart.defaults.plugins.tooltip.padding = 10;
}

/* ─── CHART REGISTRY ─────────────────────────────────────────── */
const _charts = {};
function safeChart(id, type, data, options) {
  if (_charts[id]) { _charts[id].destroy(); delete _charts[id]; }
  const canvas = document.getElementById(id);
  if (!canvas) return null;
  _charts[id] = new Chart(canvas, { type, data, options });
  return _charts[id];
}

/* ─── COLOUR TOKENS ──────────────────────────────────────────── */
const C = {
  purple:  '#7c3aed', purpleA: 'rgba(124,58,237,0.55)',
  blue:    '#2563eb', blueA:   'rgba(37,99,235,0.50)',
  orange:  '#fb923c', orangeA: 'rgba(251,146,60,0.50)',
  grid:    '#27272a', tick:    '#71717a',
  multi: [
    'rgba(124,58,237,0.55)', 'rgba(37,99,235,0.50)',
    'rgba(74,222,128,0.50)', 'rgba(250,204,21,0.50)',
    'rgba(251,146,60,0.50)', 'rgba(248,113,113,0.50)',
    'rgba(167,139,250,0.50)', 'rgba(96,165,250,0.50)',
    'rgba(52,211,153,0.50)',
  ],
  multiBorder: [
    '#7c3aed','#2563eb','#4ade80','#facc15',
    '#fb923c','#f87171','#a78bfa','#60a5fa','#34d399',
  ],
};

const hBarOpts = (xLabel) => ({
  indexAxis: 'y',
  responsive: true,
  maintainAspectRatio: false,
  plugins: { legend: { display: false } },
  scales: {
    x: {
      grid: { color: C.grid },
      ticks: { color: C.tick },
      title: xLabel
        ? { display: true, text: xLabel, color: C.tick, font: { size: 11 } }
        : { display: false },
      beginAtZero: true,
    },
    y: {
      grid: { display: false },
      ticks: { color: '#a1a1aa', font: { size: 11 }, crossAlign: 'far' },
    },
  },
});

/* ─── TAB SYSTEM ─────────────────────────────────────────────── */
const PANE_MAP = {
  overview:   'pane-overview',
  preaudit:   'pane-preaudit',
  bias:       'pane-bias',
  model:      'pane-model',
  governance: 'pane-governance',
  features:   'pane-features',
  report:     'pane-report',
};

function activateTab(tabKey) {
  // Deactivate all
  document.querySelectorAll('.audit-tab').forEach(b => b.classList.remove('active'));
  document.querySelectorAll('.audit-tab-pane').forEach(p => p.classList.remove('active'));
  // Activate target
  const btn  = document.querySelector(`.audit-tab[data-tab="${tabKey}"]`);
  const pane = document.getElementById(PANE_MAP[tabKey]);
  if (btn)  { btn.classList.add('active'); btn.setAttribute('aria-selected', 'true'); }
  if (pane) pane.classList.add('active');
}

function showTab(tabKey) {
  const btn = document.querySelector(`.audit-tab[data-tab="${tabKey}"]`);
  if (btn) btn.classList.remove('hidden');
}

function hideTab(tabKey) {
  const btn = document.querySelector(`.audit-tab[data-tab="${tabKey}"]`);
  if (btn) btn.classList.add('hidden');
}

function wireTabBar() {
  document.querySelectorAll('.audit-tab').forEach(btn => {
    btn.addEventListener('click', () => activateTab(btn.dataset.tab));
  });
}

/* ─── TOGGLE UPGRADE ─────────────────────────────────────────── */
/**
 * app.js builds this HTML per column:
 *
 *   <tr>
 *     <td>column_name</td>
 *     <td>
 *       <label class="checkbox-wrapper">
 *         <input type="checkbox" class="protected-checkbox" value="col" checked? />
 *         <span>Protected Attribute</span>
 *       </label>
 *     </td>
 *   </tr>
 *
 * We keep the <input> in place (app.js reads .protected-checkbox:checked)
 * and replace the label interior with toggle UI.
 */
function upgradeToggles() {
  const tbody = document.getElementById('columnRows');
  if (!tbody) return;
  tbody.querySelectorAll('.checkbox-wrapper').forEach(wrapper => {
    if (wrapper.dataset.upgraded) return;
    wrapper.dataset.upgraded = 'true';

    const input = wrapper.querySelector('input[type="checkbox"]');
    if (!input) return;

    // Build the toggle structure
    const row = document.createElement('div');
    row.className = 'toggle-row';

    const labelText = document.createElement('span');
    labelText.className = 'toggle-label-text';
    labelText.textContent = 'Protected Attribute';

    // Outer label acts as the clickable toggle container
    const outerLabel = document.createElement('label');
    outerLabel.className = 'toggle-wrap';
    outerLabel.setAttribute('aria-label', 'Toggle protected attribute');

    // Move original input into the toggle label
    outerLabel.appendChild(input);

    const track = document.createElement('span');
    track.className = 'toggle-track';
    outerLabel.appendChild(track);

    const thumb = document.createElement('span');
    thumb.className = 'toggle-thumb';
    outerLabel.appendChild(thumb);

    row.appendChild(labelText);
    row.appendChild(outerLabel);

    // Clear the wrapper and re-insert
    wrapper.innerHTML = '';
    wrapper.appendChild(row);
  });
}

/* ─── ATTR HEADER UPGRADE ────────────────────────────────────── */
/**
 * app.js renders h3 elements for protected attribute names inside
 * #representationTables and #biasScorecard. We style them with
 * the left-border accent class after they're written.
 */
function upgradeAttrHeaders() {
  // Representation: each attr block has a plain <h3>
  const repContainer = document.getElementById('representationTables');
  if (repContainer) {
    repContainer.querySelectorAll('h3').forEach(h => {
      if (h.dataset.upgraded) return;
      h.dataset.upgraded = 'true';
      h.className = 'a-attr-name';
      const wrapper = document.createElement('div');
      wrapper.className = 'a-attr-header';
      h.parentNode.insertBefore(wrapper, h);
      wrapper.appendChild(h);
    });
  }

  // Bias scorecard: each attr block has a flex wrapper with h3 + p
  const biasContainer = document.getElementById('biasScorecard');
  if (biasContainer) {
    // The structure from app.js is:
    // <div>
    //   <div style="display:flex;justify-content:space-between...">
    //     <h3>attr name</h3>
    //     <p>DP ... | EO ... | ...</p>
    //   </div>
    //   <div class="table-container">...</div>
    // </div>
    biasContainer.querySelectorAll('[style*="justify-content: space-between"]').forEach(wrap => {
      if (wrap.dataset.upgraded) return;
      wrap.dataset.upgraded = 'true';
      wrap.className = 'a-attr-header';
      wrap.removeAttribute('style');
      const h = wrap.querySelector('h3');
      const p = wrap.querySelector('p');
      if (h) { h.className = 'a-attr-name'; h.removeAttribute('style'); }
      if (p) { p.className = 'a-attr-meta'; p.removeAttribute('style'); }
    });
  }
}

/* ─── CHART DRAWERS ──────────────────────────────────────────── */

function drawRepresentationChart(preAudit) {
  if (typeof Chart === 'undefined' || !preAudit?.representation?.length) return;

  const labels = [], values = [], colors = [], borders = [];
  let i = 0;
  preAudit.representation.forEach(attr => {
    (attr.groups || []).forEach(g => {
      labels.push(`${attr.protected_attribute}: ${g.group}`);
      values.push(Math.round(parseFloat(g.positive_rate) * 1000) / 1000 || 0);
      colors.push(C.multi[i % C.multi.length]);
      borders.push(C.multiBorder[i % C.multiBorder.length]);
      i++;
    });
  });
  if (!labels.length) return;

  document.getElementById('representationChartCard')?.classList.remove('hidden');
  const h = Math.max(180, labels.length * 28);
  const canvas = document.getElementById('representationChart');
  if (canvas) canvas.parentElement.style.height = h + 'px';

  safeChart('representationChart', 'bar', {
    labels,
    datasets: [{ label: 'Positive Rate', data: values,
      backgroundColor: colors, borderColor: borders, borderWidth: 1, borderRadius: 4 }],
  }, { ...hBarOpts('Positive Rate'), maintainAspectRatio: false,
       scales: { ...hBarOpts().scales, x: { ...hBarOpts().scales.x, max: 1 } } });
}

function drawBiasChart(biasMetrics) {
  if (typeof Chart === 'undefined' || !biasMetrics?.length) return;

  const labels = biasMetrics.map(m => m.protected_attribute);
  const dp = biasMetrics.map(m => parseFloat(m.demographic_parity_difference) || 0);
  const eo = biasMetrics.map(m => parseFloat(m.equalized_odds_difference) || 0);
  const di = biasMetrics.map(m => {
    const v = parseFloat(m.disparate_impact_ratio);
    return isNaN(v) ? 0 : parseFloat(Math.abs(1 - v).toFixed(3));
  });

  document.getElementById('biasChartCard')?.classList.remove('hidden');
  safeChart('biasChart', 'bar', {
    labels,
    datasets: [
      { label: 'DP Gap', data: dp,
        backgroundColor: C.purpleA, borderColor: C.purple, borderWidth: 1.5, borderRadius: 4 },
      { label: 'EO Gap', data: eo,
        backgroundColor: C.blueA, borderColor: C.blue, borderWidth: 1.5, borderRadius: 4 },
      { label: '|1−DI|', data: di,
        backgroundColor: C.orangeA, borderColor: C.orange, borderWidth: 1.5, borderRadius: 4 },
    ],
  }, {
    responsive: true, maintainAspectRatio: false,
    plugins: {
      legend: { display: true,
        labels: { color: '#a1a1aa', boxWidth: 12, font: { size: 11 }, padding: 16 } },
    },
    scales: {
      x: { grid: { color: C.grid }, ticks: { color: C.tick } },
      y: { grid: { color: C.grid }, ticks: { color: C.tick }, beginAtZero: true },
    },
  });
}

function drawModelCompChart(comparison) {
  if (typeof Chart === 'undefined' || !comparison?.length) return;

  const sorted = [...comparison]
    .filter(r => r.audit_selection_score != null)
    .sort((a, b) => b.audit_selection_score - a.audit_selection_score);
  if (!sorted.length) return;

  const labels  = sorted.map(r => r.model);
  const scores  = sorted.map(r => parseFloat(r.audit_selection_score) || 0);
  const colors  = sorted.map(r => r.selected ? C.purpleA : 'rgba(124,58,237,0.22)');
  const borders = sorted.map(r => r.selected ? '#a78bfa' : C.purple);

  document.getElementById('modelCompChartCard')?.classList.remove('hidden');
  const h = Math.max(200, labels.length * 32);
  const canvas = document.getElementById('modelCompChart');
  if (canvas) canvas.parentElement.style.height = h + 'px';

  safeChart('modelCompChart', 'bar', {
    labels,
    datasets: [{ label: 'Audit Score', data: scores,
      backgroundColor: colors, borderColor: borders, borderWidth: 1.5, borderRadius: 4 }],
  }, { ...hBarOpts('Audit Score (higher = fairer + accurate)'), maintainAspectRatio: false });
}

function drawFeatureChart(importances) {
  if (typeof Chart === 'undefined' || !importances?.length) return;

  const top = [...importances]
    .sort((a, b) => b.normalized_importance - a.normalized_importance)
    .slice(0, 12);

  document.getElementById('featureChartCard')?.classList.remove('hidden');
  const h = Math.max(200, top.length * 26);
  const canvas = document.getElementById('featureChart');
  if (canvas) canvas.parentElement.style.height = h + 'px';

  safeChart('featureChart', 'bar', {
    labels: top.map(i => i.feature),
    datasets: [{
      label: 'Normalized Importance',
      data: top.map(i => parseFloat(i.normalized_importance) || 0),
      backgroundColor: top.map((_, idx) => C.multi[idx % C.multi.length]),
      borderColor:     top.map((_, idx) => C.multiBorder[idx % C.multiBorder.length]),
      borderWidth: 1.5, borderRadius: 4,
    }],
  }, { ...hBarOpts('Normalized Importance'), maintainAspectRatio: false });
}

/* ─── PATCH app.js GLOBALS ───────────────────────────────────── */
function patchAppJs() {
  /* renderPreAuditResult */
  const origPre = window.renderPreAuditResult;
  if (origPre) {
    window.renderPreAuditResult = function (result) {
      origPre.call(this, result);
      setTimeout(() => {
        upgradeAttrHeaders();
        drawRepresentationChart(result.pre_audit);
        showTab('preaudit');
        activateTab('preaudit');
      }, 80);
    };
  }

  /* renderFullAuditResult */
  const origFull = window.renderFullAuditResult;
  if (origFull) {
    window.renderFullAuditResult = function (result) {
      origFull.call(this, result);
      setTimeout(() => {
        upgradeAttrHeaders();
        const pa = result.post_audit || result.model || {};
        drawRepresentationChart(result.pre_audit);
        drawBiasChart(pa.bias_metrics || []);
        drawModelCompChart(pa.model_comparison || []);
        drawFeatureChart(pa.feature_importance || []);
        // Show all tabs
        showTab('bias'); showTab('model');
        showTab('governance'); showTab('features'); showTab('report');
        activateTab('overview');
      }, 80);
    };
  }

  /* configureDataset — upgrade toggles after columnRows is written */
  const origConfig = window.configureDataset;
  if (origConfig) {
    window.configureDataset = function (data) {
      origConfig.call(this, data);
      // Hide post-audit tabs since this is a fresh dataset
      ['bias','model','governance','features','report'].forEach(hideTab);
      activateTab('overview');
      setTimeout(upgradeToggles, 60);
    };
  }
}

/* ─── INIT ───────────────────────────────────────────────────── */
function init() {
  applyChartDefaults();
  wireTabBar();
  activateTab('overview');

  // Patch must happen after app.js defines its globals.
  // app.js loads synchronously before us, so its globals exist now.
  patchAppJs();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  setTimeout(init, 0);
}
