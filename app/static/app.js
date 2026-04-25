const state = {
  sessionId: null,
  modelId: null,
  predictionArtifactId: null,
  columns: [],
  defaults: {},
  reportId: null,
  policies: [],
  reportTemplates: [],
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
  auditModeSelect: document.getElementById("auditModeSelect"),
  policySelect: document.getElementById("policySelect"),
  reportTemplateSelect: document.getElementById("reportTemplateSelect"),
  modelPriority: document.getElementById("modelPriority"),
  modelPriorityLabel: document.getElementById("modelPriorityLabel"),
  controlFeatureOptions: document.getElementById("controlFeatureOptions"),
  modelUploadForm: document.getElementById("modelUploadForm"),
  modelFile: document.getElementById("modelFile"),
  modelStatus: document.getElementById("modelStatus"),
  predictionUploadForm: document.getElementById("predictionUploadForm"),
  predictionFile: document.getElementById("predictionFile"),
  predictionStatus: document.getElementById("predictionStatus"),
  runPreAuditButton: document.getElementById("runPreAuditButton"),
  runAuditButton: document.getElementById("runAuditButton"),
  resetButton: document.getElementById("resetButton"),
  severityBadge: document.getElementById("severityBadge"),
  preAuditBadge: document.getElementById("preAuditBadge"),
  dataOverview: document.getElementById("dataOverview"),
  cleaningLog: document.getElementById("cleaningLog"),
  validationTable: document.getElementById("validationTable"),
  representationTables: document.getElementById("representationTables"),
  proxyTable: document.getElementById("proxyTable"),
  postAuditSection: document.getElementById("postAuditSection"),
  performanceSection: document.getElementById("performanceSection"),
  biasSection: document.getElementById("biasSection"),
  governanceSection: document.getElementById("governanceSection"),
  featureSection: document.getElementById("featureSection"),
  reportSection: document.getElementById("reportSection"),
  modelAuditSummary: document.getElementById("modelAuditSummary"),
  modelComparison: document.getElementById("modelComparison"),
  predictionValidationTable: document.getElementById("predictionValidationTable"),
  modelPerformance: document.getElementById("modelPerformance"),
  biasScorecard: document.getElementById("biasScorecard"),
  traceabilityTable: document.getElementById("traceabilityTable"),
  governanceDecision: document.getElementById("governanceDecision"),
  groupingPreview: document.getElementById("groupingPreview"),
  conditionalFairness: document.getElementById("conditionalFairness"),
  intersectionalBias: document.getElementById("intersectionalBias"),
  auditTrace: document.getElementById("auditTrace"),
  featureImportance: document.getElementById("featureImportance"),
  biasSources: document.getElementById("biasSources"),
  simulationSummary: document.getElementById("simulationSummary"),
  reportSource: document.getElementById("reportSource"),
  reportText: document.getElementById("reportText"),
  downloadPdf: document.getElementById("downloadPdf"),
  fileDropZone: document.getElementById("fileDropZone"),
};

// Scroll helper functions
function scrollToApp() {
  const appEntry = document.getElementById("app-entry");
  if (appEntry) {
    appEntry.scrollIntoView({ behavior: "smooth", block: "start" });
  }
}

function scrollToFeatures() {
  const features = document.getElementById("features");
  if (features) {
    features.scrollIntoView({ behavior: "smooth", block: "start" });
  }
}

// Intersection Observer for scroll animations
function initScrollAnimations() {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("visible");
        }
      });
    },
    { threshold: 0.1, rootMargin: "0px 0px -50px 0px" }
  );

  document.querySelectorAll(".reveal").forEach((el) => observer.observe(el));
}

document.addEventListener("DOMContentLoaded", () => {
  loadDemos();
  loadPolicies();
  initScrollAnimations();
  els.uploadForm.addEventListener("submit", uploadDataset);
  els.modelUploadForm.addEventListener("submit", uploadModel);
  els.predictionUploadForm.addEventListener("submit", uploadPredictions);
  els.auditModeSelect.addEventListener("change", toggleModelUpload);
  els.modelPriority.addEventListener("input", renderPriorityLabel);
  els.runPreAuditButton.addEventListener("click", runPreAudit);
  els.runAuditButton.addEventListener("click", runAudit);
  els.resetButton.addEventListener("click", resetApp);
  
  // File drop zone effects
  if (els.fileDropZone) {
    els.fileDropZone.addEventListener("dragover", (e) => {
      e.preventDefault();
      els.fileDropZone.style.borderColor = "var(--accent-secondary)";
      els.fileDropZone.style.background = "var(--bg-tertiary)";
    });
    
    els.fileDropZone.addEventListener("dragleave", () => {
      els.fileDropZone.style.borderColor = "";
      els.fileDropZone.style.background = "";
    });
    
    els.fileDropZone.addEventListener("drop", (e) => {
      e.preventDefault();
      els.fileDropZone.style.borderColor = "";
      els.fileDropZone.style.background = "";
      const files = e.dataTransfer.files;
      if (files.length > 0 && files[0].name.endsWith(".csv")) {
        els.csvFile.files = files;
      }
    });
  }
});

async function loadDemos() {
  const data = await requestJson("/api/demos");
  els.demoButtons.innerHTML = data.demos
    .map(
      (demo) => `
        <button class="card demo-card" data-demo-id="${demo.id}" ${!demo.available ? 'disabled' : ''}>
          <span style="font-weight: 600; display: block; margin-bottom: 0.25rem;">${escapeHtml(demo.name)}</span>
          <span class="status">
            <span class="status-dot"></span>
            ${demo.available ? "Bundled & Ready" : "Demo CSV missing"}
          </span>
        </button>
      `,
    )
    .join("");
  els.demoButtons.querySelectorAll("button:not([disabled])").forEach((button) => {
    button.addEventListener("click", () => loadDemo(button.dataset.demoId));
  });
}

async function loadPolicies() {
  const data = await requestJson("/api/policies");
  state.policies = data.policies || [];
  state.reportTemplates = data.report_templates || [];
  els.policySelect.innerHTML = state.policies
    .map((policy) => `<option value="${escapeHtml(policy.policy_id)}">${escapeHtml(policy.name)} (${escapeHtml(policy.version)})</option>`)
    .join("");
  els.reportTemplateSelect.innerHTML = state.reportTemplates
    .map((template) => `<option value="${escapeHtml(template.template_id)}">${escapeHtml(template.title)}</option>`)
    .join("");
  renderPriorityLabel();
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

async function uploadModel(event) {
  event.preventDefault();
  clearMessage();
  if (!state.sessionId) {
    showMessage("Upload a dataset before uploading a model.", "error");
    return;
  }
  const file = els.modelFile.files[0];
  if (!file) {
    showMessage("Choose a .joblib, .pkl, or .pickle model file.", "error");
    return;
  }

  const formData = new FormData();
  formData.append("session_id", state.sessionId);
  formData.append("file", file);
  setBusy("Uploading model...");
  try {
    const data = await requestJson("/api/model", { method: "POST", body: formData });
    state.modelId = data.model_id;
    els.modelStatus.textContent = `${data.filename} loaded as ${data.class_name}. ${data.warning}`;
  } catch (error) {
    state.modelId = null;
    els.modelStatus.textContent = "";
    showMessage(error.message, "error");
  } finally {
    clearBusy();
  }
}

async function uploadPredictions(event) {
  event.preventDefault();
  clearMessage();
  if (!state.sessionId) {
    showMessage("Upload a dataset before uploading predictions.", "error");
    return;
  }
  const file = els.predictionFile.files[0];
  if (!file) {
    showMessage("Choose a prediction CSV.", "error");
    return;
  }

  const formData = new FormData();
  formData.append("session_id", state.sessionId);
  formData.append("file", file);
  setBusy("Uploading predictions...");
  try {
    const data = await requestJson("/api/predictions", { method: "POST", body: formData });
    state.predictionArtifactId = data.prediction_artifact_id;
    els.predictionStatus.textContent = `${data.filename} loaded with ${data.rows} predictions from column ${data.details.selected_column}.`;
  } catch (error) {
    state.predictionArtifactId = null;
    els.predictionStatus.textContent = "";
    showMessage(error.message, "error");
  } finally {
    clearBusy();
  }
}

function configureDataset(data) {
  state.sessionId = data.session_id;
  state.modelId = null;
  state.predictionArtifactId = null;
  state.columns = data.profile.column_names;
  state.defaults = data.defaults || {};
  state.reportId = null;

  els.landing.classList.add("hidden");
  els.config.classList.remove("hidden");
  els.results.classList.add("hidden");
  hidePostAuditSections();
  els.severityBadge.classList.add("hidden");
  els.preAuditBadge.classList.add("hidden");
  els.modelStatus.textContent = "";
  els.predictionStatus.textContent = "";
  els.modelFile.value = "";
  els.predictionFile.value = "";
  els.auditModeSelect.value = "train";
  if (state.defaults.policy_id && Array.from(els.policySelect.options).some((option) => option.value === state.defaults.policy_id)) {
    els.policySelect.value = state.defaults.policy_id;
  }
  toggleModelUpload();

  els.datasetSummary.textContent = `${data.profile.rows} rows, ${data.profile.columns} columns loaded from ${data.name || data.source}.`;

  els.columnRows.innerHTML = state.columns
    .map((column) => {
      const checked = (state.defaults.protected_attributes || []).includes(column) ? "checked" : "";
      return `
        <tr>
          <td>${escapeHtml(column)}</td>
          <td>
            <label class="checkbox-wrapper">
              <input type="checkbox" class="protected-checkbox" value="${escapeHtml(column)}" ${checked} />
              <span style="font-size: 0.875rem; color: var(--text-secondary);">Protected Attribute</span>
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
  renderControlFeatureOptions();
  
  // Scroll to config section with animation
  setTimeout(() => {
    els.config.scrollIntoView({ behavior: "smooth", block: "start" });
    els.config.classList.add("animate-fade-in-up");
  }, 100);
}

function selectedAuditPayload() {
  const protectedAttributes = Array.from(document.querySelectorAll(".protected-checkbox:checked")).map((input) => input.value);
  if (!protectedAttributes.length) {
    throw new Error("Select at least one protected attribute.");
  }
  return {
    session_id: state.sessionId,
    protected_attributes: protectedAttributes,
    outcome_column: els.outcomeSelect.value,
    model_type: els.modelSelect.value,
    audit_mode: els.auditModeSelect.value,
    model_id: state.modelId,
    prediction_artifact_id: state.predictionArtifactId,
    policy_id: els.policySelect.value,
    report_template: els.reportTemplateSelect.value,
    control_features: selectedControlFeatures(),
    model_selection_priority: Number(els.modelPriority.value) / 100,
  };
}

async function runPreAudit() {
  clearMessage();
  let payload;
  try {
    payload = selectedAuditPayload();
  } catch (error) {
    showMessage(error.message, "error");
    return;
  }

  setBusy("Running pre-audit...");
  try {
    const result = await requestJson("/api/pre-audit", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    renderPreAuditResult(result);
  } catch (error) {
    showMessage(error.message, "error");
  } finally {
    clearBusy();
  }
}

async function runAudit() {
  clearMessage();
  let payload;
  try {
    payload = selectedAuditPayload();
  } catch (error) {
    showMessage(error.message, "error");
    return;
  }
  if (payload.audit_mode === "uploaded_model" && !state.modelId) {
    showMessage("Upload a model before running uploaded-model audit.", "error");
    return;
  }
  if (payload.audit_mode === "prediction_csv" && !state.predictionArtifactId) {
    showMessage("Upload a prediction CSV before running prediction-only audit.", "error");
    return;
  }

  setBusy("Running post-model audit...");
  try {
    const result = await requestJson("/api/audit", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    renderFullAuditResult(result);
  } catch (error) {
    showMessage(error.message, "error");
  } finally {
    clearBusy();
  }
}

function renderPreAuditResult(result) {
  els.results.classList.remove("hidden");
  hidePostAuditSections();
  els.severityBadge.classList.add("hidden");
  renderPreAuditBadge(result.pre_audit_severity);
  renderDataOverview(result);
  renderPreAudit(result.pre_audit);
  
  // Add animation to results sections
  els.results.classList.add("animate-fade-in-up");
  setTimeout(() => {
    els.results.scrollIntoView({ behavior: "smooth", block: "start" });
  }, 100);
}

function renderFullAuditResult(result) {
  state.reportId = result.report_id;
  els.results.classList.remove("hidden");
  renderSeverity(result.severity);
  renderPreAuditBadge(result.pre_audit_severity || "Low");
  renderDataOverview(result);
  renderPreAudit(result.pre_audit);
  renderPostAudit(result.post_audit || result.model);
  renderGovernance(result);
  renderReport(result);
  
  // Add animation to results sections
  els.results.classList.add("animate-fade-in-up");
  setTimeout(() => {
    els.results.scrollIntoView({ behavior: "smooth", block: "start" });
  }, 100);
}

function renderSeverity(severity) {
  els.severityBadge.className = `severity-badge ${severityClass(severity)}`;
  els.severityBadge.textContent = `Post-Audit Severity: ${severity}`;
}

function renderPreAuditBadge(severity) {
  els.preAuditBadge.className = `severity-badge ${severityClass(severity)}`;
  els.preAuditBadge.textContent = `Pre-Audit Severity: ${severity}`;
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
    ["Governance policy", `${dataset.policy_name || dataset.policy_id || ""}`],
    ["Deployment decision", result.deployment_decision || "Only available after post-model audit"],
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
  const validationRows = [["Check", "Status", "Details"]];
  for (const item of preAudit.validation?.checks || []) {
    validationRows.push([item.name, raw(badge(item.status)), item.details]);
  }
  for (const warning of preAudit.validation?.warnings || []) {
    validationRows.push(["Warning", raw(badge("Warn")), warning]);
  }
  if (validationRows.length === 1) validationRows.push(["No validation issues", raw(badge("Pass")), ""]);
  els.validationTable.innerHTML = table(validationRows);

  els.representationTables.innerHTML = preAudit.representation
    .map((item) => {
      const rows = [["Group", "Count", "Positive rate", "Ratio", "Status"]];
      for (const group of item.groups) {
        rows.push([group.group, group.count, percent(group.positive_rate), group.ratio_to_highest, raw(badge(group.status))]);
      }
      return `<div style="margin-bottom: 1.5rem;"><h3 style="font-weight: 600; margin-bottom: 0.75rem;">${escapeHtml(item.protected_attribute)}</h3><div class="table-container">${table(rows)}</div></div>`;
    })
    .join("");

  const proxyRows = [["Feature", "Protected attribute", "Strength", "Method", "Risk"]];
  for (const item of preAudit.proxy_flags) {
    proxyRows.push([item.feature, item.protected_attribute, item.strength, item.method, raw(badge(item.risk))]);
  }
  if (proxyRows.length === 1) proxyRows.push(["None detected", "", "", "", ""]);
  els.proxyTable.innerHTML = table(proxyRows);
}

function renderPostAudit(postAudit) {
  els.postAuditSection.classList.remove("hidden");
  els.performanceSection.classList.remove("hidden");
  els.biasSection.classList.remove("hidden");
  els.governanceSection.classList.remove("hidden");
  els.featureSection.classList.remove("hidden");
  els.reportSection.classList.remove("hidden");

  const tuning = postAudit.tuning;
  const tuningText = tuning
    ? `${tuning.status}. Best parameters: ${Object.keys(tuning.best_params || {}).length ? JSON.stringify(tuning.best_params) : "defaults"}.`
    : "";
  els.modelAuditSummary.textContent = `${postAudit.model_type} using ${postAudit.model_input?.strategy || "unknown input strategy"}. ${tuningText}`;
  renderModelComparison(postAudit.model_comparison || []);

  const predictionRows = [["Check", "Status", "Details"]];
  predictionRows.push([
    "Binary predictions",
    raw(badge(postAudit.prediction_validation?.status || "Pass")),
    `Unique values: ${(postAudit.prediction_validation?.unique_values || []).join(", ") || "none"}`,
  ]);
  if (postAudit.prediction_validation?.mapping) {
    predictionRows.push(["Prediction mapping", raw(badge("Info")), JSON.stringify(postAudit.prediction_validation.mapping)]);
  }
  for (const warning of postAudit.prediction_validation?.warnings || []) {
    predictionRows.push(["Warning", raw(badge("Warn")), warning]);
  }
  for (const warning of postAudit.model_input?.warnings || []) {
    predictionRows.push(["Model input warning", raw(badge("Warn")), warning]);
  }
  els.predictionValidationTable.innerHTML = table(predictionRows);

  renderPerformance(postAudit.performance);
  renderBiasScorecard(postAudit.bias_metrics);
  renderFeatureImportance(postAudit.feature_importance || [], postAudit.bias_sources || []);
  renderSimulation(postAudit.improvement_simulation);
}

function renderGovernance(result) {
  const postAudit = result.post_audit || result.model;
  renderGovernanceDecision(result.governance || {});
  renderGroupingPreview(result.grouping_preview || result.pre_audit?.grouping_preview || []);
  renderTraceability(result.traceability || {});
  renderConditionalFairness(postAudit.conditional_fairness || {});
  renderIntersectionalBias(postAudit.intersectional_bias || {});
  renderAuditTrace(postAudit.audit_trace || {});
}

function renderGovernanceDecision(governance) {
  const rows = [["Field", "Value"]];
  rows.push(["Risk score", governance.risk_score ?? ""]);
  rows.push(["Severity", raw(badge(governance.severity || "Info"))]);
  rows.push(["Deployment decision", governance.deployment_decision || ""]);
  rows.push(["Policy", `${governance.policy_name || ""} ${governance.policy_version || ""}`]);
  for (const driver of governance.top_risk_drivers || []) {
    rows.push(["Risk driver", driver]);
  }
  els.governanceDecision.innerHTML = table(rows);
}

function renderGroupingPreview(preview) {
  const rows = [["Column", "Detected type", "Method", "Groups"]];
  for (const item of preview || []) {
    rows.push([item.column, item.detected_type, item.grouping_method, (item.groups || []).join(", ")]);
  }
  if (rows.length === 1) rows.push(["No grouping preview available", "", "", ""]);
  els.groupingPreview.innerHTML = table(rows);
}

function renderTraceability(traceability) {
  const rows = [
    ["Field", "Value"],
    ["Run ID", traceability.run_id || ""],
    ["Created UTC", traceability.created_at_utc || ""],
    ["Dataset hash", traceability.dataset_hash_sha256 || ""],
    ["Model fingerprint", traceability.model_fingerprint_sha256 || ""],
    ["Policy", JSON.stringify(traceability.policy || {})],
  ];
  els.traceabilityTable.innerHTML = table(rows);
}

function renderConditionalFairness(conditional) {
  if (!conditional.available) {
    els.conditionalFairness.innerHTML = `<p style="color: var(--text-muted);">${escapeHtml(conditional.reason || "Conditional fairness analysis is unavailable.")}</p>`;
    return;
  }
  els.conditionalFairness.innerHTML = conditional.results
    .map((item) => {
      const rows = [["Cohort", "Count", "Highest group", "Highest rate", "Lowest group", "Lowest rate", "Gap", "Status"]];
      for (const cohort of item.worst_cohorts || []) {
        rows.push([
          cohort.cohort,
          cohort.count,
          cohort.highest_group,
          percent(cohort.highest_selection_rate),
          cohort.lowest_group,
          percent(cohort.lowest_selection_rate),
          cohort.selection_gap,
          raw(badge(cohort.status)),
        ]);
      }
      if (rows.length === 1) rows.push(["No comparable cohorts", "", "", "", "", "", "", ""]);
      return `
        <div style="margin-bottom: 1.5rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 0.75rem;">
            <h4 style="font-weight: 600;">${escapeHtml(item.protected_attribute)}</h4>
            <p style="font-size: 0.875rem; color: var(--text-muted);">Controls: ${escapeHtml((item.control_features || []).join(", "))} | Weighted gap ${item.weighted_selection_gap} | ${item.status}</p>
          </div>
          <div class="table-container">${table(rows)}</div>
        </div>
      `;
    })
    .join("");
}

function renderIntersectionalBias(intersectional) {
  if (!intersectional.available) {
    els.intersectionalBias.innerHTML = `<p style="color: var(--text-muted);">${escapeHtml(intersectional.reason || "Intersectional analysis is unavailable.")}</p>`;
    return;
  }
  const rows = [["Group", "Count", "Positive predictions", "Selection rate", "Ratio", "Accuracy", "Small group"]];
  for (const group of intersectional.groups || []) {
    rows.push([
      group.group,
      group.count,
      group.positive_predictions,
      percent(group.selection_rate),
      group.ratio_to_highest,
      group.accuracy,
      group.small_group_warning ? raw(badge("Warn")) : "",
    ]);
  }
  els.intersectionalBias.innerHTML = table(rows);
}

function renderAuditTrace(trace) {
  if (!trace.explainability_available || !trace.records?.length) {
    els.auditTrace.innerHTML = `<p style="color: var(--text-muted);">${escapeHtml(trace.reason || "No row-level audit trace records were generated.")}</p>`;
    return;
  }
  els.auditTrace.innerHTML = trace.records
    .map((record) => {
      const rows = [["Feature", "Value", "Baseline", "Contribution", "Direction"]];
      for (const contribution of record.top_contributions || []) {
        rows.push([
          contribution.feature,
          contribution.value,
          contribution.baseline,
          contribution.contribution,
          contribution.direction,
        ]);
      }
      return `
        <div class="card" style="padding: 1rem; margin-bottom: 1rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 0.5rem;">
            <h4 style="font-weight: 600;">Row ${escapeHtml(record.row_id)}</h4>
            <p style="font-size: 0.875rem; color: var(--text-muted);">Prediction ${record.prediction}, actual ${record.actual}, score ${record.decision_score}</p>
          </div>
          <p style="font-size: 0.875rem; color: var(--text-muted); margin-bottom: 0.75rem;">${escapeHtml(record.risk_reason)} | Protected: ${escapeHtml(JSON.stringify(record.protected_attributes || {}))}</p>
          <div class="table-container">${table(rows)}</div>
        </div>
      `;
    })
    .join("");
}

function renderModelComparison(rows) {
  if (!rows.length) {
    els.modelComparison.innerHTML = `<p style="color: var(--text-muted);">No local model comparison was run for this audit mode.</p>`;
    return;
  }
  const tableRows = [
    ["Selected", "Model", "Tuning", "CV", "Balanced acc", "Accuracy", "Precision", "Recall", "Max DP", "Max EO", "Audit score", "Fails policy", "Best params"],
  ];
  for (const row of rows) {
    tableRows.push([
      row.selected ? raw(badge("Selected")) : "",
      row.model,
      row.status || "",
      row.cv_score ?? "",
      row.balanced_accuracy ?? "",
      row.accuracy ?? "",
      row.precision ?? "",
      row.recall ?? "",
      row.max_demographic_parity_difference ?? "",
      row.max_equalized_odds_difference ?? "",
      row.audit_selection_score ?? "",
      row.fails_policy ? (row.policy_failures || []).join("; ") : "No",
      row.error || JSON.stringify(row.best_params || {}),
    ]);
  }
  els.modelComparison.innerHTML = table(tableRows);
}

function renderPerformance(performance) {
  els.modelPerformance.innerHTML = [
    statCard("Accuracy", performance.accuracy),
    statCard("Precision", performance.precision),
    statCard("Recall", performance.recall),
    statCard("Train", performance.training_samples ?? "External"),
    statCard("Eval", performance.test_samples),
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
        <div style="margin-bottom: 1.5rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 0.75rem;">
            <h3 style="font-weight: 600;">${escapeHtml(metric.protected_attribute)}</h3>
            <p style="font-size: 0.875rem; color: var(--text-muted);">
              DP ${metric.demographic_parity_difference} | EO ${metric.equalized_odds_difference} | Impact ${metric.disparate_impact_ratio} | ${metric.status}
            </p>
          </div>
          <div class="table-container">${table(rows)}</div>
        </div>
      `;
    })
    .join("");
}

function renderFeatureImportance(importances, sources) {
  if (!importances.length) {
    els.featureImportance.innerHTML = `<p style="color: var(--text-muted);">Feature importance is not available for this model artifact.</p>`;
  } else {
    const max = Math.max(...importances.map((item) => item.normalized_importance), 0.01);
    els.featureImportance.innerHTML = importances
      .map((item) => {
        const width = Math.max((item.normalized_importance / max) * 100, 2);
        return `
          <div style="margin-bottom: 1rem;">
            <div style="display: flex; justify-content: space-between; font-size: 0.875rem; margin-bottom: 0.25rem;">
              <span>${item.rank}. ${escapeHtml(item.feature)}</span>
              <span>${item.importance}</span>
            </div>
            <div class="progress-bar">
              <div class="progress-bar-fill" style="width:${width}%"></div>
            </div>
          </div>
        `;
      })
      .join("");
  }

  const rows = [["Feature", "Importance rank", "Proxy link"]];
  for (const source of sources) {
    const links = source.proxy_links.map((link) => `${link.protected_attribute}: ${link.strength}`).join(", ");
    rows.push([source.feature, source.rank, links]);
  }
  if (rows.length === 1) rows.push(["None in top 10", "", ""]);
  els.biasSources.innerHTML = table(rows);
}

function renderSimulation(simulation) {
  if (!simulation) {
    els.simulationSummary.textContent = "No simulation data available.";
    return;
  }
  if (!simulation.available) {
    els.simulationSummary.textContent = simulation.reason || simulation.recommended_next_step || "Simulation is unavailable.";
    return;
  }
  els.simulationSummary.innerHTML = `
    <p style="margin-bottom: 0.5rem;">${escapeHtml(simulation.strategy)}</p>
    <p style="margin-bottom: 0.5rem;">Dropped features: ${escapeHtml((simulation.dropped_features || []).join(", "))}</p>
    <p style="margin-bottom: 0.5rem;">Simulated accuracy ${simulation.accuracy}, max DP ${simulation.max_demographic_parity_difference}, max EO ${simulation.max_equalized_odds_difference}.</p>
    <p style="font-size: 0.75rem; color: var(--text-muted);">${escapeHtml(simulation.note || "")}</p>
  `;
}

function renderReport(result) {
  els.reportSource.textContent = result.report.source;
  if (result.report.sections?.length) {
    els.reportText.innerHTML = result.report.sections
      .map((section) => `<section style="margin-bottom:1rem;"><h3 style="font-weight:700;margin-bottom:0.35rem;">${escapeHtml(section.title)}</h3><p style="white-space:pre-wrap;color:#d4d4d8;">${escapeHtml(section.content)}</p></section>`)
      .join("");
  } else {
    els.reportText.textContent = result.report.text;
  }
  els.downloadPdf.href = `/api/report/${result.report_id}/pdf`;
  els.downloadPdf.classList.remove("hidden");
}

function resetApp() {
  state.sessionId = null;
  state.modelId = null;
  state.predictionArtifactId = null;
  state.columns = [];
  state.defaults = {};
  state.reportId = null;
  els.landing.classList.remove("hidden");
  els.config.classList.add("hidden");
  els.results.classList.add("hidden");
  hidePostAuditSections();
  els.severityBadge.classList.add("hidden");
  els.preAuditBadge.classList.add("hidden");
  els.csvFile.value = "";
  els.modelFile.value = "";
  els.predictionFile.value = "";
  els.modelStatus.textContent = "";
  els.predictionStatus.textContent = "";
  clearMessage();
}

function hidePostAuditSections() {
  els.postAuditSection.classList.add("hidden");
  els.performanceSection.classList.add("hidden");
  els.biasSection.classList.add("hidden");
  els.governanceSection.classList.add("hidden");
  els.featureSection.classList.add("hidden");
  els.reportSection.classList.add("hidden");
}

function toggleModelUpload() {
  const useUpload = els.auditModeSelect.value === "uploaded_model";
  const usePredictions = els.auditModeSelect.value === "prediction_csv";
  els.modelUploadForm.classList.toggle("hidden", !useUpload);
  els.predictionUploadForm.classList.toggle("hidden", !usePredictions);
  els.modelSelect.disabled = useUpload || usePredictions;
}

function renderPriorityLabel() {
  const accuracy = Number(els.modelPriority.value);
  els.modelPriorityLabel.textContent = `Balanced: ${accuracy}% accuracy / ${100 - accuracy}% fairness`;
}

function renderControlFeatureOptions() {
  const protectedDefaults = new Set(state.defaults.protected_attributes || []);
  const outcome = state.defaults.outcome_column || els.outcomeSelect.value;
  const defaultControls = new Set(state.defaults.control_features || []);
  els.controlFeatureOptions.innerHTML = state.columns
    .filter((column) => column !== outcome && !protectedDefaults.has(column))
    .map((column) => `
      <label class="checkbox-wrapper" style="padding:0.5rem;border:1px solid #27272a;border-radius:8px;">
        <input type="checkbox" class="control-feature-checkbox" value="${escapeHtml(column)}" ${defaultControls.has(column) ? "checked" : ""} />
        <span style="font-size:0.875rem;color:var(--text-secondary);">${escapeHtml(column)}</span>
      </label>
    `)
    .join("");
}

function selectedControlFeatures() {
  return Array.from(document.querySelectorAll(".control-feature-checkbox:checked")).map((input) => input.value);
}

function setBusy(text) {
  els.runAuditButton.disabled = true;
  els.runPreAuditButton.disabled = true;
  els.runAuditButton.innerHTML = `<span class="spinner"></span> ${text}`;
}

function clearBusy() {
  els.runAuditButton.disabled = false;
  els.runPreAuditButton.disabled = false;
  els.runAuditButton.innerHTML = `
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
      <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>
    </svg>
    Run Post-Model Audit
  `;
}

function statCard(label, value) {
  return `
    <div class="card stat-card">
      <div class="stat-label">${escapeHtml(label)}</div>
      <div class="stat-value">${escapeHtml(String(value))}</div>
    </div>
  `;
}

function table(rows) {
  return `
    <table class="table">
      <tbody>
        ${rows
          .map(
            (row, index) => `
              <tr class="${index === 0 ? "" : ""}">
                ${row
                  .map((cell) => `<td>${cell && cell.__html ? cell.__html : escapeHtml(String(cell))}</td>`)
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
  const badgeClasses = {
    Green: "badge-success",
    Pass: "badge-success",
    Yellow: "badge-warning",
    Warn: "badge-warning",
    Info: "badge-info",
    Red: "badge-error",
    Low: "badge-success",
    Medium: "badge-warning",
    High: "badge-error",
    Critical: "badge-error",
    Selected: "badge-neutral",
  };
  return `<span class="badge ${badgeClasses[value] || "badge-neutral"}">${escapeHtml(value)}</span>`;
}

function severityClass(severity) {
  const classes = {
    Low: "severity-low",
    Medium: "severity-medium",
    High: "severity-high",
    Critical: "severity-critical",
  };
  return classes[severity] || classes.Medium;
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
      ? "message message-error"
      : type === "success"
      ? "message message-success"
      : "message message-info";
}

function clearMessage() {
  els.message.className = "message hidden";
  els.message.textContent = "";
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
