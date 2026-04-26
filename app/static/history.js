document.addEventListener("DOMContentLoaded", () => {
  if (!localStorage.getItem("aiBiasAuditorUser")) {
    window.location.href = "/";
    return;
  }
  loadHistory();
});

async function loadHistory() {
  const status = document.getElementById("historyStatus");
  const table = document.getElementById("historyTable");
  try {
    const response = await fetch("/api/history?limit=50");
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail || "Could not load history.");
    const storage = data.storage || {};
    status.textContent = storage.firestore_enabled
      ? `Firestore enabled for project ${storage.project_id}.`
      : `Using local report storage. Firestore status: ${storage.firestore_error || "not configured"}.`;
    const rows = [["Created", "Dataset", "Policy", "Severity", "Decision", "Report"]];
    for (const item of data.items || []) {
      rows.push([
        item.created_at_utc || "",
        item.dataset_name || "",
        item.policy_id || "",
        item.severity || "",
        item.deployment_decision || "",
        item.report_id ? { html: `<a href="/api/report/${escapeHtml(item.report_id)}/pdf">PDF</a>` } : "",
      ]);
    }
    if (rows.length === 1) rows.push(["No stored audits yet", "", "", "", "", ""]);
    table.innerHTML = renderTable(rows);
  } catch (error) {
    status.textContent = error.message;
    table.innerHTML = "";
  }
}

function renderTable(rows) {
  return `
    <table class="table">
      <tbody>
        ${rows.map((row, index) => `
          <tr>
            ${row.map((cell) => `<td>${cell && cell.html ? cell.html : escapeHtml(String(cell))}</td>`).join("")}
          </tr>
        `).join("")}
      </tbody>
    </table>
  `;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
