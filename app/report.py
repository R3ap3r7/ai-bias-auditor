from __future__ import annotations

from io import BytesIO
from typing import Any

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


def build_pdf_report(result: dict[str, Any]) -> bytes:
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=letter, rightMargin=48, leftMargin=48, topMargin=48, bottomMargin=48)
    styles = getSampleStyleSheet()
    story = []

    dataset = result["dataset"]
    model = result["model"]
    pre_audit = result["pre_audit"]

    story.append(Paragraph("AI Bias Auditor Report", styles["Title"]))
    story.append(Spacer(1, 12))
    story.append(Paragraph(f"Severity: {result['severity']}", styles["Heading2"]))
    story.append(
        Paragraph(
            f"Dataset: {dataset['rows']} rows, {dataset['columns']} columns. Outcome: {dataset['outcome_column']}. Model: {dataset['model_type']}.",
            styles["BodyText"],
        )
    )
    if model.get("model_input"):
        story.append(Paragraph(f"Model input: {model['model_input'].get('details', '')}", styles["BodyText"]))
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

    story.append(Paragraph("Proxy Risks", styles["Heading2"]))
    proxy_rows = [["Feature", "Protected attribute", "Strength", "Risk"]]
    for item in pre_audit["proxy_flags"][:10]:
        proxy_rows.append([item["feature"], item["protected_attribute"], item["strength"], item["risk"]])
    if len(proxy_rows) == 1:
        proxy_rows.append(["None detected", "", "", ""])
    story.append(simple_table(proxy_rows))
    story.append(Spacer(1, 12))

    story.append(Paragraph("Explanation Report", styles["Heading2"]))
    for paragraph in result["report"]["text"].split("\n\n"):
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
