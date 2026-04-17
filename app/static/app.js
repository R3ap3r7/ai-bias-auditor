const state = {
  sessionId: null,
  columns: [],
  defaults: {},
  reportId: null,
};

const els = {
  message: document.getElementById("message"),
  landing: document.getElementById("landing"),
  config: document.getElementById("config"),
  results: document.getElementById("results"),
  uploadForm: document.getElementById("uploadForm"),
  csvFile: document.getElementById("csvFile"),
  demoButtons: document.getElementById("demoButtons"),
  datasetSummary: document.getElementById("datasetSummary"),
  columnRows: document.getElementById("columnRows"),
  outcomeSelect: document.getElementById("outcomeSelect"),
  modelSelect: document.getElementById("modelSelect"),
  runAuditButton: document.getElementById("runAuditButton"),
  resetButton: document.getElementById("resetButton"),
  severityBadge: document.getElementById("severityBadge"),
  dataOverview: document.getElementById("dataOverview"),
  cleaningLog: document.getElementById("cleaningLog"),
  representationTables: document.getElementById("representationTables"),
  proxyTable: document.getElementById("proxyTable"),
  modelPerformance: document.getElementById("modelPerformance"),
  biasScorecard: document.getElementById("biasScorecard"),
  featureImportance: document.getElementById("featureImportance"),
  biasSources: document.getElementById("biasSources"),
  reportSource: document.getElementById("reportSource"),
  reportText: document.getElementById("reportText"),
  downloadPdf: document.getElementById("downloadPdf"),
};

document.addEventListener("DOMContentLoaded", () => {
  loadDemos();
  els.uploadForm.addEventListener("submit", uploadDataset);
  els.runAuditButton.addEventListener("click", runAudit);
  els.resetButton.addEventListener("click", resetApp);
});

async function loadDemos() {
  const data = await requestJson("/api/demos");
  els.demoButtons.innerHTML = data.demos
    .map(
      (demo) => `
        <button class="rounded-md border border-zinc-300 px-4 py-3 text-left hover:bg-zinc-50" data-demo-id="${demo.id}">
          <span class="block font-semibold">${escapeHtml(demo.name)}</span>
          <span class="mt-1 block text-xs text-zinc-500">${demo.available ? "Preloaded" : "Synthetic fallback until downloaded"}</span>
        </button>
      `,
    )
    .join("");
  els.demoButtons.querySelectorAll("button").forEach((button) => {
    button.addEventListener("click", () => loadDemo(button.dataset.demoId));
  });
}

async function uploadDataset(event) {
  event.preventDefault();
  clearMessage();
  const file = els.csvFile.files[0];
  if (!file) return;

  const formData = new FormData();
  formData.append("file", file);
  setBusy("Uploading...");
  try {
    const data = await requestJson("/api/upload", { method: "POST", body: formData });
    configureDataset(data);
  } catch (error) {
    showMessage(error.message, "error");
  } finally {
    clearBusy();
  }
}

async function loadDemo(demoId) {
  clearMessage();
  setBusy("Loading demo...");
  try {
    const data = await requestJson(`/api/demo/${demoId}`, { method: "POST" });
    configureDataset(data);
  } catch (error) {
    showMessage(error.message, "error");
  } finally {
    clearBusy();
  }
}

function configureDataset(data) {
  state.sessionId = data.session_id;
  state.columns = data.profile.column_names;
  state.defaults = data.defaults || {};
  state.reportId = null;

  els.landing.classList.add("hidden");
  els.config.classList.remove("hidden");
  els.results.classList.add("hidden");
  els.severityBadge.classList.add("hidden");

  els.datasetSummary.textContent = `${data.profile.rows} rows, ${data.profile.columns} columns loaded from ${data.name || data.source}.`;

  els.columnRows.innerHTML = state.columns
    .map((column) => {
      const checked = (state.defaults.protected_attributes || []).includes(column) ? "checked" : "";
      return `
        <tr>
          <td class="border border-zinc-200 px-3 py-2">${escapeHtml(column)}</td>
          <td class="border border-zinc-200 px-3 py-2">
            <label class="inline-flex items-center gap-2">
              <input type="checkbox" class="protected-checkbox rounded border-zinc-300" value="${escapeHtml(column)}" ${checked} />
              <span class="text-xs text-zinc-600">Protected</span>
            </label>
          </td>
        </tr>
      `;
    })
    .join("");

  els.outcomeSelect.innerHTML = state.columns
    .map((column) => `<option value="${escapeHtml(column)}">${escapeHtml(column)}</option>`)
    .join("");
  if (state.defaults.outcome_column) {
    els.outcomeSelect.value = state.defaults.outcome_column;
  }
  if (state.defaults.model_type) {
    els.modelSelect.value = state.defaults.model_type;
  }
}

async function runAudit() {
  clearMessage();
  const protectedAttributes = Array.from(document.querySelectorAll(".protected-checkbox:checked")).map((input) => input.value);
  if (!protectedAttributes.length) {
    showMessage("Select at least one protected attribute.", "error");
    return;
  }

  setBusy("Running audit...");
  try {
    const result = await requestJson("/api/audit", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        session_id: state.sessionId,
        protected_attributes: protectedAttributes,
        outcome_column: els.outcomeSelect.value,
        model_type: els.modelSelect.value,
      }),
    });
    renderResults(result);
  } catch (error) {
    showMessage(error.message, "error");
  } finally {
    clearBusy();
  }
}

function renderResults(result) {
  state.reportId = result.report_id;
  els.results.classList.remove("hidden");
  els.config.scrollIntoView({ behavior: "smooth", block: "start" });

  renderSeverity(result.severity);
  renderDataOverview(result);
  renderPreAudit(result.pre_audit);
  renderPerformance(result.model.performance);
  renderBiasScorecard(result.model.bias_metrics);
  renderFeatureImportance(result.model.feature_importance, result.model.bias_sources);
  renderReport(result);
}

function renderSeverity(severity) {
  const colors = {
    Low: "border-emerald-300 bg-emerald-50 text-emerald-800",
    Medium: "border-amber-300 bg-amber-50 text-amber-800",
    High: "border-red-300 bg-red-50 text-red-800",
    Critical: "border-red-500 bg-red-100 text-red-900",
  };
  els.severityBadge.className = `rounded-md border px-4 py-2 text-sm font-semibold ${colors[severity] || colors.Medium}`;
  els.severityBadge.textContent = `Severity: ${severity}`;
}

function renderDataOverview(result) {
  const dataset = result.dataset;
  const cleaning = result.cleaning;
  els.dataOverview.innerHTML = [
    statCard("Rows", dataset.rows),
    statCard("Columns", dataset.columns),
    statCard("Dropped outcome rows", cleaning.dropped_rows_missing_outcome),
  ].join("");

  const rows = [
    ["Action", "Details"],
    ["Dropped columns over 50% missing", cleaning.dropped_columns_over_50_percent_missing.join(", ") || "None"],
    ["Outcome mapping", JSON.stringify(cleaning.outcome_mapping)],
    ["Rows after cleaning", cleaning.rows_after_cleaning],
  ];
  for (const action of cleaning.missing_value_actions) {
    rows.push([action.column, `${action.missing_count} missing values, ${action.action}`]);
  }
  els.cleaningLog.innerHTML = table(rows);
}

function renderPreAudit(preAudit) {
  els.representationTables.innerHTML = preAudit.representation
    .map((item) => {
      const rows = [["Group", "Count", "Positive rate", "Ratio", "Status"]];
      for (const group of item.groups) {
        rows.push([group.group, group.count, percent(group.positive_rate), group.ratio_to_highest, raw(badge(group.status))]);
      }
      return `<div><h3 class="font-semibold">${escapeHtml(item.protected_attribute)}</h3><div class="mt-2 overflow-x-auto">${table(rows)}</div></div>`;
    })
    .join("");

  const proxyRows = [["Feature", "Protected attribute", "Strength", "Method", "Risk"]];
  for (const item of preAudit.proxy_flags) {
    proxyRows.push([item.feature, item.protected_attribute, item.strength, item.method, raw(badge(item.risk))]);
  }
  if (proxyRows.length === 1) proxyRows.push(["None detected", "", "", "", ""]);
  els.proxyTable.innerHTML = table(proxyRows);
}

function renderPerformance(performance) {
  els.modelPerformance.innerHTML = [
    statCard("Accuracy", performance.accuracy),
    statCard("Precision", performance.precision),
    statCard("Recall", performance.recall),
    statCard("Train", performance.training_samples),
    statCard("Test", performance.test_samples),
  ].join("");
}

function renderBiasScorecard(metrics) {
  els.biasScorecard.innerHTML = metrics
    .map((metric) => {
      const rows = [["Group", "Count", "Positive predictions", "Selection rate", "Ratio", "Accuracy", "Status"]];
      for (const group of metric.groups) {
        rows.push([
          group.group,
          group.count,
          group.positive_predictions,
          percent(group.selection_rate),
          group.ratio_to_highest,
          group.accuracy,
          raw(badge(group.status)),
        ]);
      }
      return `
        <div>
          <div class="flex flex-col gap-1 md:flex-row md:items-center md:justify-between">
            <h3 class="font-semibold">${escapeHtml(metric.protected_attribute)}</h3>
            <p class="text-sm text-zinc-600">
              DP ${metric.demographic_parity_difference} | EO ${metric.equalized_odds_difference} | Impact ${metric.disparate_impact_ratio} | ${metric.status}
            </p>
          </div>
          <div class="mt-2 overflow-x-auto">${table(rows)}</div>
        </div>
      `;
    })
    .join("");
}

function renderFeatureImportance(importances, sources) {
  const max = Math.max(...importances.map((item) => item.normalized_importance), 0.01);
  els.featureImportance.innerHTML = importances
    .map((item) => {
      const width = Math.max((item.normalized_importance / max) * 100, 2);
      return `
        <div>
          <div class="mb-1 flex justify-between text-sm">
            <span>${item.rank}. ${escapeHtml(item.feature)}</span>
            <span>${item.importance}</span>
          </div>
          <div class="h-3 rounded-md bg-zinc-100">
            <div class="h-3 rounded-md bg-zinc-900" style="width:${width}%"></div>
          </div>
        </div>
      `;
    })
    .join("");

  const rows = [["Feature", "Importance rank", "Proxy link"]];
  for (const source of sources) {
    const links = source.proxy_links.map((link) => `${link.protected_attribute}: ${link.strength}`).join(", ");
    rows.push([source.feature, source.rank, links]);
  }
  if (rows.length === 1) rows.push(["None in top 10", "", ""]);
  els.biasSources.innerHTML = table(rows);
}

function renderReport(result) {
  els.reportSource.textContent = result.report.source;
  els.reportText.textContent = result.report.text;
  els.downloadPdf.href = `/api/report/${result.report_id}/pdf`;
  els.downloadPdf.classList.remove("hidden");
}

function resetApp() {
  state.sessionId = null;
  state.columns = [];
  state.defaults = {};
  state.reportId = null;
  els.landing.classList.remove("hidden");
  els.config.classList.add("hidden");
  els.results.classList.add("hidden");
  els.severityBadge.classList.add("hidden");
  els.csvFile.value = "";
  clearMessage();
}

function statCard(label, value) {
  return `
    <div class="rounded-md border border-zinc-200 bg-zinc-50 p-4">
      <div class="text-xs uppercase text-zinc-500">${escapeHtml(label)}</div>
      <div class="mt-1 text-2xl font-semibold">${escapeHtml(String(value))}</div>
    </div>
  `;
}

function table(rows) {
  return `
    <table class="min-w-full border-collapse text-left text-sm">
      <tbody>
        ${rows
          .map(
            (row, index) => `
              <tr class="${index === 0 ? "bg-zinc-100 text-xs uppercase text-zinc-600" : ""}">
                ${row
                  .map((cell) => `<td class="border border-zinc-200 px-3 py-2">${cell && cell.__html ? cell.__html : escapeHtml(String(cell))}</td>`)
                  .join("")}
              </tr>
            `,
          )
          .join("")}
      </tbody>
    </table>
  `;
}

function badge(value) {
  const colors = {
    Green: "bg-emerald-50 text-emerald-800 border-emerald-200",
    Yellow: "bg-amber-50 text-amber-800 border-amber-200",
    Red: "bg-red-50 text-red-800 border-red-200",
    Low: "bg-emerald-50 text-emerald-800 border-emerald-200",
    Medium: "bg-amber-50 text-amber-800 border-amber-200",
    High: "bg-red-50 text-red-800 border-red-200",
    Critical: "bg-red-100 text-red-900 border-red-300",
  };
  return `<span class="inline-block rounded-md border px-2 py-1 text-xs font-semibold ${colors[value] || "border-zinc-200"}">${escapeHtml(value)}</span>`;
}

function raw(value) {
  return { __html: value };
}

function percent(value) {
  return `${Math.round(Number(value) * 1000) / 10}%`;
}

async function requestJson(url, options = {}) {
  const response = await fetch(url, options);
  const contentType = response.headers.get("content-type") || "";
  const data = contentType.includes("application/json") ? await response.json() : await response.text();
  if (!response.ok) {
    const detail = typeof data === "object" ? data.detail : data;
    throw new Error(detail || `Request failed with status ${response.status}`);
  }
  return data;
}

function showMessage(text, type = "info") {
  els.message.textContent = text;
  els.message.className =
    type === "error"
      ? "mb-6 rounded-md border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-800"
      : "mb-6 rounded-md border border-zinc-300 bg-white px-4 py-3 text-sm text-zinc-700";
}

function clearMessage() {
  els.message.className = "mb-6 hidden rounded-md border px-4 py-3 text-sm";
  els.message.textContent = "";
}

function setBusy(text) {
  els.runAuditButton.disabled = true;
  els.runAuditButton.textContent = text;
}

function clearBusy() {
  els.runAuditButton.disabled = false;
  els.runAuditButton.textContent = "Run Audit";
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
