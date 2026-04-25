from __future__ import annotations

from io import BytesIO
from typing import Any

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


def build_pdf_report(result: dict[str, Any], template_id: str | None = None) -> bytes:
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=letter, rightMargin=48, leftMargin=48, topMargin=48, bottomMargin=48)
    styles = getSampleStyleSheet()
    story = []

    dataset = result["dataset"]
    model = result["model"]
    pre_audit = result["pre_audit"]
    traceability = result.get("traceability", {})

    story.append(Paragraph("AI Bias Auditor Report", styles["Title"]))
    story.append(Spacer(1, 12))
    story.append(Paragraph(f"Severity: {result['severity']}", styles["Heading2"]))
    if result.get("deployment_decision"):
        story.append(Paragraph(f"Deployment decision: {result['deployment_decision']}", styles["Heading2"]))
    story.append(
        Paragraph(
            f"Dataset: {dataset['rows']} rows, {dataset['columns']} columns. Outcome: {dataset['outcome_column']}. Model: {dataset['model_type']}.",
            styles["BodyText"],
        )
    )
    if model.get("model_input"):
        story.append(Paragraph(f"Model input: {model['model_input'].get('details', '')}", styles["BodyText"]))
    if traceability:
        story.append(Paragraph(f"Run ID: {traceability.get('run_id', '')}", styles["BodyText"]))
        story.append(Paragraph(f"Dataset hash: {traceability.get('dataset_hash_sha256', '')}", styles["BodyText"]))
        story.append(Paragraph(f"Model fingerprint: {traceability.get('model_fingerprint_sha256', '')}", styles["BodyText"]))
        policy = traceability.get("policy", {})
        if policy:
            story.append(
                Paragraph(
                    f"Policy: {policy.get('policy_name', '')} ({policy.get('policy_id', '')} v{policy.get('policy_version', '')})",
                    styles["BodyText"],
                )
            )
    story.append(Spacer(1, 12))

    governance = result.get("governance", {})
    if governance:
        story.append(Paragraph("Governance Decision", styles["Heading2"]))
        governance_rows = [["Field", "Value"]]
        governance_rows.append(["Risk score", governance.get("risk_score", "")])
        governance_rows.append(["Deployment decision", governance.get("deployment_decision", "")])
        for driver in governance.get("top_risk_drivers", [])[:5]:
            governance_rows.append(["Risk driver", driver])
        story.append(simple_table(governance_rows))
        story.append(Spacer(1, 12))

    performance = model["performance"]
    story.append(Paragraph("Model Performance", styles["Heading2"]))
    story.append(
        simple_table(
            [
                ["Metric", "Value"],
                ["Accuracy", performance["accuracy"]],
                ["Precision", performance["precision"]],
                ["Recall", performance["recall"]],
                ["Training samples", performance["training_samples"]],
                ["Test samples", performance["test_samples"]],
            ]
        )
    )
    story.append(Spacer(1, 12))

    if model.get("model_comparison"):
        story.append(Paragraph("Tuned Model Comparison", styles["Heading2"]))
        comparison_rows = [["Selected", "Model", "Balanced acc", "Accuracy", "Max DP", "Max EO", "Audit score", "Best params"]]
        for item in model["model_comparison"][:10]:
            comparison_rows.append(
                [
                    "Yes" if item.get("selected") else "",
                    item.get("model", ""),
                    item.get("balanced_accuracy", ""),
                    item.get("accuracy", ""),
                    item.get("max_demographic_parity_difference", ""),
                    item.get("max_equalized_odds_difference", ""),
                    item.get("audit_selection_score", ""),
                    str(item.get("best_params") or item.get("error") or {}),
                ]
            )
        story.append(simple_table(comparison_rows))
        story.append(Spacer(1, 12))

    story.append(Paragraph("Bias Metrics", styles["Heading2"]))
    metric_rows = [["Protected attribute", "Demographic parity", "Equalized odds", "Impact ratio", "Status"]]
    for item in model["bias_metrics"]:
        metric_rows.append(
            [
                item["protected_attribute"],
                item["demographic_parity_difference"],
                item["equalized_odds_difference"],
                item["disparate_impact_ratio"],
                item["status"],
            ]
        )
    story.append(simple_table(metric_rows))
    story.append(Spacer(1, 12))

    conditional = model.get("conditional_fairness", {})
    if conditional.get("available"):
        story.append(Paragraph("Same-Background Fairness", styles["Heading2"]))
        conditional_rows = [["Protected attribute", "Controls", "Cohorts", "Weighted gap", "Status"]]
        for item in conditional.get("results", []):
            conditional_rows.append(
                [
                    item.get("protected_attribute", ""),
                    ", ".join(item.get("control_features", [])),
                    item.get("cohorts_analyzed", ""),
                    item.get("weighted_selection_gap", ""),
                    item.get("status", ""),
                ]
            )
        story.append(simple_table(conditional_rows))
        story.append(Spacer(1, 12))

    intersectional = model.get("intersectional_bias", {})
    if intersectional.get("available"):
        story.append(Paragraph("Intersectional Bias", styles["Heading2"]))
        intersectional_rows = [["Group", "Count", "Selection rate", "Accuracy", "Small group"]]
        for item in intersectional.get("groups", [])[:8]:
            intersectional_rows.append(
                [
                    item.get("group", ""),
                    item.get("count", ""),
                    item.get("selection_rate", ""),
                    item.get("accuracy", ""),
                    "Yes" if item.get("small_group_warning") else "",
                ]
            )
        story.append(simple_table(intersectional_rows))
        story.append(Spacer(1, 12))

    audit_trace = model.get("audit_trace", {})
    if audit_trace.get("records"):
        story.append(Paragraph("Decision Audit Trace", styles["Heading2"]))
        trace_rows = [["Row", "Prediction", "Actual", "Reason", "Top contributing features"]]
        for item in audit_trace.get("records", [])[:8]:
            contributors = ", ".join(
                f"{contribution.get('feature')} ({contribution.get('contribution')})"
                for contribution in item.get("top_contributions", [])[:3]
            )
            trace_rows.append(
                [
                    item.get("row_id", ""),
                    item.get("prediction", ""),
                    item.get("actual", ""),
                    item.get("risk_reason", ""),
                    contributors,
                ]
            )
        story.append(simple_table(trace_rows))
        story.append(Spacer(1, 12))

    story.append(Paragraph("Proxy Risks", styles["Heading2"]))
    proxy_rows = [["Feature", "Protected attribute", "Strength", "Risk"]]
    for item in pre_audit["proxy_flags"][:10]:
        proxy_rows.append([item["feature"], item["protected_attribute"], item["strength"], item["risk"]])
    if len(proxy_rows) == 1:
        proxy_rows.append(["None detected", "", "", ""])
    story.append(simple_table(proxy_rows))
    story.append(Spacer(1, 12))

    story.append(Paragraph("Explanation Report", styles["Heading2"]))
    report = result.get("report", {})
    sections = report.get("sections") or []
    if sections:
        for section in sections:
            story.append(Paragraph(str(section.get("title", "")), styles["Heading3"]))
            story.append(Paragraph(str(section.get("content", "")).replace("\n", "<br/>"), styles["BodyText"]))
            story.append(Spacer(1, 8))
    else:
        for paragraph in report.get("text", "").split("\n\n"):
            story.append(Paragraph(paragraph.replace("\n", "<br/>"), styles["BodyText"]))
            story.append(Spacer(1, 8))

    doc.build(story)
    return buffer.getvalue()


def simple_table(rows: list[list[Any]]) -> Table:
    table = Table(rows, hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#111827")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, -1), 8),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#d1d5db")),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f9fafb")]),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
            ]
        )
    )
    return table
