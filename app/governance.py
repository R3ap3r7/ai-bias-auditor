from __future__ import annotations

import math
from typing import Any

import numpy as np
import pandas as pd

from app.policies import REPORT_TEMPLATES, load_policy, resolve_grouping_rule


def get_policy(policy_id: str | None = None) -> dict[str, Any]:
    return load_policy(policy_id)


def group_series(
    series: pd.Series,
    column_name: str,
    policy: dict[str, Any],
    overrides: dict[str, dict[str, Any]] | None = None,
) -> pd.Series:
    overrides = overrides or {}
    numeric = pd.to_numeric(series, errors="coerce")
    non_missing = series.notna().sum()
    is_numeric = bool(pd.api.types.is_numeric_dtype(series) or (non_missing and numeric.notna().sum() / non_missing >= 0.9))
    rule = resolve_grouping_rule(column_name, policy, overrides.get(column_name), is_numeric=is_numeric)
    rule_type = rule.get("type", "categorical")

    if not is_numeric or rule_type in {"categorical", "treat_as_categorical", "top_k_plus_other"}:
        values = series.fillna("Unknown").astype(str)
        top_k = int(rule.get("top_k", 10))
        if rule_type == "top_k_plus_other" and values.nunique(dropna=True) > top_k:
            top_values = set(values.value_counts().head(top_k).index.tolist())
            return values.map(lambda value: value if value in top_values else "Other")
        return values

    if rule_type == "fixed_bins":
        bins = rule.get("bins")
        labels = rule.get("labels")
        if bins and len(bins) >= 2:
            cut = pd.cut(numeric, bins=bins, labels=labels, include_lowest=True)
            return cut.astype(str).replace("nan", "Unknown")

    if rule_type == "quantile":
        q = int(rule.get("q", 4))
        try:
            return pd.qcut(numeric, q=min(q, max(2, numeric.nunique(dropna=True))), duplicates="drop").astype(str).replace(
                "nan",
                "Unknown",
            )
        except ValueError:
            pass

    if column_name.lower() == "age":
        cut = pd.cut(numeric, bins=[0, 25, 45, 65, math.inf], labels=["Under 25", "25-44", "45-64", "65+"], include_lowest=True)
        return cut.astype(str).replace("nan", "Unknown")

    return series.fillna("Unknown").astype(str)


def grouping_preview(
    df: pd.DataFrame,
    protected_attributes: list[str],
    policy: dict[str, Any],
    overrides: dict[str, dict[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    preview = []
    for column in protected_attributes:
        if column not in df.columns:
            continue
        grouped = group_series(df[column], column, policy, overrides)
        numeric = pd.to_numeric(df[column], errors="coerce")
        is_numeric = bool(pd.api.types.is_numeric_dtype(df[column]) or (df[column].notna().sum() and numeric.notna().sum() / df[column].notna().sum() >= 0.9))
        rule = resolve_grouping_rule(column, policy, (overrides or {}).get(column), is_numeric=is_numeric)
        preview.append(
            {
                "column": column,
                "detected_type": "numeric protected" if is_numeric else "categorical protected",
                "grouping_method": rule.get("type", "categorical"),
                "groups": grouped.value_counts(dropna=False).head(8).index.astype(str).tolist(),
            }
        )
    return preview


def gap_status(score: float, policy: dict[str, Any], metric_name: str) -> str:
    thresholds = policy["fairness_thresholds"][metric_name]
    if score >= thresholds["critical"]:
        return "Critical"
    if score >= thresholds["high"]:
        return "High"
    if score >= thresholds["medium"]:
        return "Medium"
    return "Low"


def ratio_status(score: float, policy: dict[str, Any], metric_name: str) -> str:
    thresholds = policy["fairness_thresholds"][metric_name]
    if score <= thresholds["critical_below"]:
        return "Red"
    if score <= thresholds["warning_below"]:
        return "Yellow"
    return "Green"


def build_governance_assessment(pre_audit: dict[str, Any], model_results: dict[str, Any], policy: dict[str, Any]) -> dict[str, Any]:
    bias_metrics = model_results.get("bias_metrics", [])
    proxy_flags = pre_audit.get("proxy_flags", [])
    representation = pre_audit.get("representation", [])
    conditional_results = model_results.get("conditional_fairness", {}).get("results", [])

    max_dp = max((item.get("demographic_parity_difference", 0.0) for item in bias_metrics), default=0.0)
    max_eo = max((item.get("equalized_odds_difference", 0.0) for item in bias_metrics), default=0.0)
    min_di = min((item.get("disparate_impact_ratio", 1.0) for item in bias_metrics), default=1.0)
    min_representation = min((item.get("minimum_representation_ratio", 1.0) for item in representation), default=1.0)
    max_proxy_strength = max((item.get("strength", 0.0) for item in proxy_flags), default=0.0)
    min_group_count = min(
        (
            group.get("count", 999999)
            for item in representation
            for group in item.get("groups", [])
        ),
        default=999999,
    )
    conditional_gap = max((item.get("weighted_selection_gap", 0.0) for item in conditional_results), default=0.0)

    components = {
        "demographic_parity_difference": normalize_gap(
            max_dp,
            policy["fairness_thresholds"]["demographic_parity_difference"],
        ),
        "equalized_odds_difference": normalize_gap(
            max_eo,
            policy["fairness_thresholds"]["equalized_odds_difference"],
        ),
        "disparate_impact_ratio": normalize_lower_is_risk(
            min_di,
            policy["fairness_thresholds"]["disparate_impact_ratio"],
        ),
        "proxy_variable_risk": normalize_upper_is_risk(
            max_proxy_strength,
            policy["fairness_thresholds"]["proxy_variable_strength"],
        ),
        "underrepresentation": normalize_lower_is_risk(
            min_representation,
            policy["fairness_thresholds"]["representation_ratio"],
        ),
        "small_group_uncertainty": min(1.0, max(0.0, (20 - min(min_group_count, 20)) / 20)) if min_group_count != 999999 else 0.0,
        "conditional_fairness_gap": normalize_gap(
            conditional_gap,
            policy["fairness_thresholds"]["demographic_parity_difference"],
        ),
    }
    weights = policy["severity_weights"]
    total_weight = sum(weights.values()) or 1.0
    weighted_components = {
        key: round(float(weights.get(key, 0.0) * components.get(key, 0.0)), 4)
        for key in weights
    }
    risk_score = round(sum(weighted_components.values()) / total_weight, 4)
    severity = severity_from_risk_score(risk_score, policy)
    deployment_decision = deployment_decision_from_risk_score(risk_score, policy)

    driver_rows = []
    for key, weighted in weighted_components.items():
        if weighted <= 0:
            continue
        driver_rows.append(
            {
                "driver": key,
                "weighted_contribution": weighted,
                "component_score": round(components.get(key, 0.0), 4),
                "message": driver_message(key, max_dp, max_eo, min_di, min_representation, max_proxy_strength, conditional_gap),
            }
        )
    driver_rows.sort(key=lambda item: item["weighted_contribution"], reverse=True)

    return {
        "policy_id": policy["policy_id"],
        "policy_version": policy["version"],
        "policy_name": policy["name"],
        "risk_score": risk_score,
        "severity": severity,
        "deployment_decision": deployment_decision,
        "weighted_components": weighted_components,
        "component_scores": {key: round(value, 4) for key, value in components.items()},
        "top_risk_drivers": [item["message"] for item in driver_rows[:5]],
        "drivers": driver_rows[:8],
    }


def severity_from_risk_score(risk_score: float, policy: dict[str, Any]) -> str:
    thresholds = policy["severity_thresholds"]
    if risk_score >= thresholds["critical_at_or_above"]:
        return "Critical"
    if risk_score >= thresholds["high_at_or_above"]:
        return "High"
    if risk_score >= thresholds["medium_at_or_above"]:
        return "Medium"
    return "Low"


def deployment_decision_from_risk_score(risk_score: float, policy: dict[str, Any]) -> str:
    thresholds = policy["deployment_decision_thresholds"]
    if risk_score < thresholds["safe_to_deploy_below"]:
        return "Safe to deploy with monitoring"
    if risk_score < thresholds["needs_review_below"]:
        return "Needs review before deployment"
    return "Do not deploy without remediation"


def normalize_gap(score: float, thresholds: dict[str, float]) -> float:
    critical = max(float(thresholds.get("critical", 0.3)), 1e-6)
    return min(1.0, max(0.0, float(score) / critical))


def normalize_lower_is_risk(score: float, thresholds: dict[str, float]) -> float:
    warning = float(thresholds.get("warning_below", 0.8))
    critical = float(thresholds.get("critical_below", 0.5))
    if score >= warning:
        return 0.0
    if score <= critical:
        return 1.0
    return round((warning - score) / max(warning - critical, 1e-6), 4)


def normalize_upper_is_risk(score: float, thresholds: dict[str, float]) -> float:
    warning = float(thresholds.get("warning_above", 0.5))
    critical = float(thresholds.get("critical_above", 0.8))
    if score <= warning:
        return 0.0
    if score >= critical:
        return 1.0
    return round((score - warning) / max(critical - warning, 1e-6), 4)


def driver_message(
    key: str,
    max_dp: float,
    max_eo: float,
    min_di: float,
    min_representation: float,
    max_proxy_strength: float,
    conditional_gap: float,
) -> str:
    messages = {
        "demographic_parity_difference": f"Demographic parity gap reached {round(max_dp, 4)}.",
        "equalized_odds_difference": f"Equalized odds gap reached {round(max_eo, 4)}.",
        "disparate_impact_ratio": f"Disparate impact ratio fell to {round(min_di, 4)}.",
        "proxy_variable_risk": f"Strongest proxy association measured {round(max_proxy_strength, 4)}.",
        "underrepresentation": f"Minimum representation ratio fell to {round(min_representation, 4)}.",
        "small_group_uncertainty": "Small-group support is limited, so metrics may be unstable.",
        "conditional_fairness_gap": f"Same-background weighted selection gap reached {round(conditional_gap, 4)}.",
    }
    return messages.get(key, key.replace("_", " ").title())


def model_selection_weights(policy: dict[str, Any], priority: float | None = None) -> dict[str, float]:
    weights = dict(policy["model_selection"].get("weights", {}))
    if priority is None:
        return weights

    fairness_weight = 1.0 - float(priority)
    accuracy_weight = float(priority)
    weights["balanced_accuracy"] = max(0.05, accuracy_weight)
    fairness_keys = [key for key in weights if key != "balanced_accuracy"]
    if fairness_keys:
        fairness_share = fairness_weight / len(fairness_keys)
        for key in fairness_keys:
            weights[key] = fairness_share
    return weights


def model_selection_score(
    balanced_accuracy: float,
    demographic_parity_difference: float,
    equalized_odds_difference: float,
    disparate_impact_ratio: float,
    policy: dict[str, Any],
    priority: float | None = None,
) -> float:
    weights = model_selection_weights(policy, priority)
    return round(
        (
            weights.get("balanced_accuracy", 0.0) * balanced_accuracy
            - weights.get("demographic_parity_difference", 0.0) * demographic_parity_difference
            - weights.get("equalized_odds_difference", 0.0) * equalized_odds_difference
            + weights.get("disparate_impact_ratio", 0.0) * disparate_impact_ratio
        ),
        4,
    )


def model_policy_failures(row: dict[str, Any], policy: dict[str, Any]) -> list[str]:
    rules = policy.get("model_selection", {})
    failures = []
    if row.get("recall") is not None and row["recall"] < rules.get("minimum_recall", 0.0):
        failures.append(f"recall below {rules['minimum_recall']}")
    if (
        row.get("max_equalized_odds_difference") is not None
        and row["max_equalized_odds_difference"] > rules.get("maximum_equalized_odds_gap", 1.0)
    ):
        failures.append(f"equalized odds gap above {rules['maximum_equalized_odds_gap']}")
    if (
        row.get("max_demographic_parity_difference") is not None
        and row["max_demographic_parity_difference"] > rules.get("maximum_demographic_parity_gap", 1.0)
    ):
        failures.append(f"demographic parity gap above {rules['maximum_demographic_parity_gap']}")
    if (
        row.get("min_disparate_impact_ratio") is not None
        and row["min_disparate_impact_ratio"] < rules.get("minimum_disparate_impact_ratio", 0.0)
    ):
        failures.append(f"disparate impact ratio below {rules['minimum_disparate_impact_ratio']}")
    return failures


def report_template(template_id: str | None) -> dict[str, str]:
    return REPORT_TEMPLATES.get(template_id or "full_report", REPORT_TEMPLATES["full_report"])
