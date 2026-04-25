from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path
from typing import Any

POLICY_DIR = Path(__file__).resolve().parent.parent / "policies"
DEFAULT_POLICY_ID = "default_governance_v1"


class PolicyError(ValueError):
    """Raised when a governance policy cannot be loaded or validated."""


def list_policies() -> list[dict[str, str]]:
    policies = []
    for path in sorted(POLICY_DIR.glob("*.json")):
        payload = load_policy(path.stem)
        policies.append(
            {
                "policy_id": payload["policy_id"],
                "version": payload["version"],
                "name": payload["name"],
                "description": payload.get("description", ""),
            }
        )
    return policies


def load_policy(policy_id: str | None = None) -> dict[str, Any]:
    target = policy_id or DEFAULT_POLICY_ID
    path = POLICY_DIR / f"{target}.json"
    if not path.exists():
        raise PolicyError(f"Unknown policy `{target}`.")

    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)

    validate_policy(payload)
    return deepcopy(payload)


def validate_policy(policy: dict[str, Any]) -> None:
    required_top_level = {
        "policy_id",
        "version",
        "name",
        "fairness_thresholds",
        "severity_weights",
        "severity_thresholds",
        "deployment_decision_thresholds",
        "model_selection",
        "grouping_rules",
    }
    missing = sorted(required_top_level - set(policy))
    if missing:
        raise PolicyError(f"Policy is missing required field(s): {', '.join(missing)}")

    model_weights = policy["model_selection"].get("weights", {})
    if not model_weights:
        raise PolicyError("Policy model_selection.weights cannot be empty.")

    severity_weights = policy.get("severity_weights", {})
    if not severity_weights:
        raise PolicyError("Policy severity_weights cannot be empty.")


def resolve_grouping_rule(
    column_name: str,
    policy: dict[str, Any],
    override: dict[str, Any] | None = None,
    *,
    is_numeric: bool,
) -> dict[str, Any]:
    if override:
        return override

    rules = policy.get("grouping_rules", {})
    if column_name in rules:
        return rules[column_name]

    if column_name.lower() == "age" and "age" in rules:
        return rules["age"]

    return rules.get("default_numeric" if is_numeric else "default_categorical", {"type": "categorical"})


REPORT_TEMPLATES: dict[str, dict[str, str]] = {
    "executive_summary": {
        "title": "Executive Summary",
        "description": "Short decision-oriented summary for leadership or judges.",
    },
    "technical_audit": {
        "title": "Technical Audit",
        "description": "Detailed fairness metrics, controls, and model behavior.",
    },
    "compliance_review": {
        "title": "Compliance Review",
        "description": "Policy, traceability, limitations, and deployment recommendation.",
    },
    "model_card": {
        "title": "Model Card",
        "description": "Compact model-card style artifact with intended use and caveats.",
    },
    "full_report": {
        "title": "Full Report",
        "description": "Combined executive, technical, and governance view.",
    },
}


def list_report_templates() -> list[dict[str, str]]:
    return [
        {"template_id": template_id, **metadata}
        for template_id, metadata in REPORT_TEMPLATES.items()
    ]
