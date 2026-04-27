from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field, ValidationError, model_validator

POLICY_DIR = Path(__file__).resolve().parent.parent / "policies"
DEFAULT_POLICY_ID = "default_governance_v1"


class PolicyError(ValueError):
    """Raised when a governance policy cannot be loaded or validated."""


class MetricThresholds(BaseModel):
    model_config = ConfigDict(extra="allow")


class FairnessThresholds(BaseModel):
    demographic_parity_difference: MetricThresholds
    equalized_odds_difference: MetricThresholds
    disparate_impact_ratio: MetricThresholds
    representation_ratio: MetricThresholds
    proxy_variable_strength: MetricThresholds

    @model_validator(mode="after")
    def validate_ranges(self) -> "FairnessThresholds":
        for metric_name, metric in self.model_dump().items():
            values = metric if isinstance(metric, dict) else {}
            for key, value in values.items():
                if not isinstance(value, (int, float)):
                    raise ValueError(f"{metric_name}.{key} must be numeric")
                if float(value) < 0:
                    raise ValueError(f"{metric_name}.{key} must be non-negative")
            if {"medium", "high", "critical"} <= set(values) and not (
                values["medium"] <= values["high"] <= values["critical"]
            ):
                raise ValueError(f"{metric_name} thresholds must be ordered medium <= high <= critical")
            if {"critical_below", "warning_below"} <= set(values) and not (
                values["critical_below"] <= values["warning_below"]
            ):
                raise ValueError(f"{metric_name} lower-bound thresholds must be ordered critical_below <= warning_below")
            if {"warning_above", "critical_above"} <= set(values) and not (
                values["warning_above"] <= values["critical_above"]
            ):
                raise ValueError(f"{metric_name} upper-bound thresholds must be ordered warning_above <= critical_above")
        return self


class SeverityThresholds(BaseModel):
    medium_at_or_above: float = Field(ge=0, le=1)
    high_at_or_above: float = Field(ge=0, le=1)
    critical_at_or_above: float = Field(ge=0, le=1)

    @model_validator(mode="after")
    def validate_order(self) -> "SeverityThresholds":
        if not self.medium_at_or_above <= self.high_at_or_above <= self.critical_at_or_above:
            raise ValueError("severity thresholds must be ordered medium <= high <= critical")
        return self


class DeploymentDecisionThresholds(BaseModel):
    safe_to_deploy_below: float = Field(ge=0, le=1)
    needs_review_below: float = Field(ge=0, le=1)

    @model_validator(mode="after")
    def validate_order(self) -> "DeploymentDecisionThresholds":
        if self.safe_to_deploy_below >= self.needs_review_below:
            raise ValueError("deployment thresholds must be ordered safe_to_deploy_below < needs_review_below")
        return self


class ModelSelection(BaseModel):
    accuracy_metric: str
    weights: dict[str, float] = Field(min_length=1)
    minimum_recall: Optional[float] = Field(default=None, ge=0, le=1)
    maximum_equalized_odds_gap: Optional[float] = Field(default=None, ge=0, le=1)
    maximum_demographic_parity_gap: Optional[float] = Field(default=None, ge=0, le=1)
    minimum_disparate_impact_ratio: Optional[float] = Field(default=None, ge=0, le=1)

    @model_validator(mode="after")
    def validate_weights(self) -> "ModelSelection":
        for key, value in self.weights.items():
            if value < 0 or value > 1:
                raise ValueError(f"model_selection.weights.{key} must be between 0 and 1")
        if sum(self.weights.values()) <= 0:
            raise ValueError("model_selection.weights must have a positive total")
        return self


class GroupingRule(BaseModel):
    model_config = ConfigDict(extra="allow")
    type: str
    bins: Optional[list[float]] = None
    labels: Optional[list[str]] = None
    q: Optional[int] = Field(default=None, ge=2)
    top_k: Optional[int] = Field(default=None, ge=1)

    @model_validator(mode="after")
    def validate_schema(self) -> "GroupingRule":
        if self.type == "fixed_bins":
            if not self.bins or not self.labels:
                raise ValueError("fixed_bins grouping rules require bins and labels")
            if len(self.labels) != len(self.bins) - 1:
                raise ValueError("fixed_bins grouping rules require len(labels) == len(bins) - 1")
            if self.bins != sorted(self.bins):
                raise ValueError("fixed_bins bins must be sorted ascending")
        elif self.type == "quantile":
            if self.q is None:
                raise ValueError("quantile grouping rules require q")
        elif self.type == "top_k_plus_other":
            if self.top_k is None:
                raise ValueError("top_k_plus_other grouping rules require top_k")
        elif self.type != "categorical":
            raise ValueError(f"unsupported grouping rule type `{self.type}`")
        return self


class GovernancePolicy(BaseModel):
    policy_id: str
    version: str
    name: str
    fairness_thresholds: FairnessThresholds
    severity_weights: dict[str, float] = Field(min_length=1)
    severity_thresholds: SeverityThresholds
    deployment_decision_thresholds: DeploymentDecisionThresholds
    model_selection: ModelSelection
    grouping_rules: dict[str, GroupingRule] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_weights(self) -> "GovernancePolicy":
        for key, value in self.severity_weights.items():
            if value < 0 or value > 1:
                raise ValueError(f"severity_weights.{key} must be between 0 and 1")
        if sum(self.severity_weights.values()) <= 0:
            raise ValueError("severity_weights must have a positive total")
        return self


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


def load_policy(policy_id: Optional[str] = None) -> dict[str, Any]:
    target = policy_id or DEFAULT_POLICY_ID
    path = POLICY_DIR / f"{target}.json"
    if not path.exists():
        raise PolicyError(f"Unknown policy `{target}`.")

    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)

    validate_policy(payload)
    return deepcopy(payload)


def validate_policy(policy: dict[str, Any]) -> None:
    try:
        GovernancePolicy.model_validate(policy)
    except ValidationError as exc:
        errors = "; ".join(
            f"{'.'.join(str(part) for part in error['loc'])}: {error['msg']}"
            for error in exc.errors()
        )
        raise PolicyError(f"Invalid policy `{policy.get('policy_id', '<unknown>')}`: {errors}") from exc


def resolve_grouping_rule(
    column_name: str,
    policy: dict[str, Any],
    override: Optional[dict[str, Any]] = None,
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
