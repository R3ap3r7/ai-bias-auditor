from __future__ import annotations

import math
import os
import textwrap
import warnings
from dataclasses import dataclass
from datetime import UTC, datetime
from hashlib import sha256
from typing import Any
from uuid import uuid4

import numpy as np
import pandas as pd
from scipy import stats
from sklearn.compose import ColumnTransformer
from sklearn.exceptions import ConvergenceWarning
from sklearn.ensemble import AdaBoostClassifier, ExtraTreesClassifier, GradientBoostingClassifier, RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, balanced_accuracy_score, precision_score, recall_score
from sklearn.model_selection import GridSearchCV, StratifiedKFold, train_test_split
from sklearn.naive_bayes import GaussianNB
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.svm import LinearSVC
from sklearn.tree import DecisionTreeClassifier

from app.governance import (
    build_governance_assessment,
    gap_status,
    group_series,
    grouping_preview,
    model_policy_failures,
    model_selection_score,
    ratio_status,
    report_template,
)
from app.policies import DEFAULT_POLICY_ID, load_policy

try:
    from fairlearn.metrics import (
        MetricFrame,
        demographic_parity_difference,
        equalized_odds_difference,
        selection_rate,
    )
except Exception:  # pragma: no cover - only used when Fairlearn cannot import locally.
    MetricFrame = None

    def selection_rate(y_true: Any, y_pred: Any) -> float:
        y_pred_array = np.asarray(y_pred)
        return float(np.mean(y_pred_array == 1)) if len(y_pred_array) else 0.0

    def demographic_parity_difference(y_true: Any, y_pred: Any, *, sensitive_features: Any) -> float:
        groups = pd.Series(sensitive_features).astype(str)
        rates = pd.Series(y_pred).groupby(groups).mean()
        return float(rates.max() - rates.min()) if len(rates) else 0.0

    def equalized_odds_difference(y_true: Any, y_pred: Any, *, sensitive_features: Any) -> float:
        frame = pd.DataFrame(
            {"y_true": np.asarray(y_true), "y_pred": np.asarray(y_pred), "group": pd.Series(sensitive_features).astype(str)}
        )
        tpr = frame[frame["y_true"] == 1].groupby("group")["y_pred"].mean()
        fpr = frame[frame["y_true"] == 0].groupby("group")["y_pred"].mean()
        diffs = []
        if len(tpr):
            diffs.append(float(tpr.max() - tpr.min()))
        if len(fpr):
            diffs.append(float(fpr.max() - fpr.min()))
        return max(diffs) if diffs else 0.0


POSITIVE_LABELS = {
    "1",
    "yes",
    "y",
    "true",
    "approved",
    "approve",
    "accepted",
    "accept",
    "hired",
    "hire",
    "admitted",
    "pass",
    "passed",
    "positive",
    "good",
    ">50k",
    ">50k.",
}

NEGATIVE_LABELS = {
    "0",
    "no",
    "n",
    "false",
    "denied",
    "deny",
    "rejected",
    "reject",
    "not hired",
    "not admitted",
    "fail",
    "failed",
    "negative",
    "bad",
    "<=50k",
    "<=50k.",
}

MODEL_LABELS = {
    "compare_all": "Compare All Tuned Models",
    "logistic_regression": "Logistic Regression",
    "decision_tree": "Decision Tree",
    "random_forest": "Random Forest",
    "extra_trees": "Extra Trees",
    "gradient_boosting": "Gradient Boosting",
    "ada_boost": "AdaBoost",
    "linear_svm": "Linear SVM",
    "knn": "K-Nearest Neighbors",
    "gaussian_nb": "Gaussian Naive Bayes",
}

TRAINABLE_MODEL_KEYS = [key for key in MODEL_LABELS if key != "compare_all"]
TUNING_SAMPLE_LIMIT = 2500
MAX_CV_FOLDS = 2
MODEL_PARAM_GRIDS: dict[str, dict[str, list[Any]]] = {
    "logistic_regression": {
        "model__C": [0.5, 1.5],
        "model__class_weight": [None, "balanced"],
    },
    "decision_tree": {
        "model__max_depth": [4, 8, None],
        "model__min_samples_leaf": [5, 15],
        "model__class_weight": [None, "balanced"],
    },
    "random_forest": {
        "model__max_depth": [6, None],
        "model__min_samples_leaf": [1, 8],
        "model__class_weight": [None, "balanced_subsample"],
    },
    "extra_trees": {
        "model__max_depth": [6, None],
        "model__min_samples_leaf": [1, 8],
        "model__class_weight": [None, "balanced"],
    },
    "gradient_boosting": {
        "model__n_estimators": [80, 120],
        "model__learning_rate": [0.05, 0.1],
    },
    "ada_boost": {
        "model__n_estimators": [50, 100],
        "model__learning_rate": [0.5, 1.0],
    },
    "linear_svm": {
        "model__C": [0.5, 1.5],
        "model__class_weight": [None, "balanced"],
    },
    "knn": {
        "model__n_neighbors": [7, 21],
        "model__weights": ["uniform", "distance"],
    },
    "gaussian_nb": {
        "model__var_smoothing": [1e-9, 1e-7],
    },
}

AUDIT_MODE_LABELS = {
    "train": "Train a model in the auditor",
    "uploaded_model": "Audit an uploaded model",
    "prediction_csv": "Audit a prediction CSV",
}


@dataclass
class CleanedData:
    dataframe: pd.DataFrame
    cleaning_log: dict[str, Any]
    outcome_mapping: dict[str, int]


class AuditError(ValueError):
    """Raised when a dataset cannot be audited with the selected options."""


def profile_dataframe(df: pd.DataFrame) -> dict[str, Any]:
    preview = df.head(5).replace({np.nan: None}).to_dict(orient="records")
    missing = [
        {"column": column, "missing_percent": round(float(percent), 2)}
        for column, percent in (df.isnull().mean() * 100).items()
        if percent > 0
    ]
    return {
        "rows": int(len(df)),
        "columns": int(len(df.columns)),
        "column_names": list(df.columns),
        "missing_values": missing,
        "preview": preview,
    }


def run_audit(
    df: pd.DataFrame,
    protected_attributes: list[str],
    outcome_column: str,
    model_type: str = "logistic_regression",
    audit_mode: str = "train",
    uploaded_model: Any | None = None,
    uploaded_model_name: str | None = None,
    uploaded_predictions: pd.Series | None = None,
    uploaded_prediction_scores: pd.Series | None = None,
    uploaded_prediction_metadata: dict[str, Any] | None = None,
    policy_id: str = DEFAULT_POLICY_ID,
    report_template: str | None = None,
    control_features: list[str] | None = None,
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
    model_selection_priority: float | None = None,
) -> dict[str, Any]:
    policy = load_policy(policy_id)
    control_features = control_features or []
    grouping_overrides = grouping_overrides or {}
    template_id = report_template or policy.get("report_defaults", {}).get("template", "full_report")

    pre_result = run_pre_audit_only(
        df,
        protected_attributes,
        outcome_column,
        policy_id=policy["policy_id"],
        grouping_overrides=grouping_overrides,
        control_features=control_features,
    )
    clean_df = pre_result["_clean_dataframe"]
    pre_audit = pre_result["pre_audit"]

    if audit_mode not in AUDIT_MODE_LABELS:
        raise AuditError("Unsupported audit mode.")
    if audit_mode == "uploaded_model":
        if uploaded_model is None:
            raise AuditError("Upload a model before running an uploaded-model audit.")
        model_results = audit_uploaded_model(
            clean_df,
            protected_attributes,
            outcome_column,
            uploaded_model,
            uploaded_model_name or "Uploaded model",
            pre_audit["proxy_flags"],
            policy,
            grouping_overrides,
            control_features,
        )
    elif audit_mode == "prediction_csv":
        if uploaded_predictions is None:
            raise AuditError("Upload a prediction CSV before running prediction-only audit.")
        model_results = audit_prediction_csv(
            clean_df,
            protected_attributes,
            outcome_column,
            uploaded_predictions,
            uploaded_prediction_scores,
            uploaded_prediction_metadata or {},
            pre_audit["proxy_flags"],
            policy,
            grouping_overrides,
            control_features,
        )
    else:
        if model_type not in MODEL_LABELS:
            raise AuditError("Unsupported model type.")
        model_results = train_and_audit_model(
            clean_df,
            protected_attributes,
            outcome_column,
            model_type,
            pre_audit["proxy_flags"],
            policy,
            grouping_overrides,
            control_features,
            model_selection_priority,
        )

    governance = build_governance_assessment(pre_audit, model_results, policy)

    summary = {
        "traceability": build_traceability_metadata(
            clean_df,
            protected_attributes,
            outcome_column,
            audit_mode,
            model_results,
            policy,
            template_id,
            control_features,
            grouping_overrides,
        ),
        "dataset": pre_result["dataset"],
        "cleaning": pre_result["cleaning"],
        "pre_audit": pre_audit,
        "grouping_preview": pre_result.get("grouping_preview", []),
        "pre_audit_severity": pre_result["pre_audit_severity"],
        "post_audit": model_results,
        "model": model_results,
        "governance": governance,
        "severity": governance["severity"],
        "deployment_decision": governance["deployment_decision"],
        "report": {},
    }
    summary["dataset"]["audit_mode"] = AUDIT_MODE_LABELS[audit_mode]
    summary["dataset"]["model_type"] = model_results["model_type"]
    summary["dataset"]["policy_id"] = policy["policy_id"]
    summary["dataset"]["policy_name"] = policy["name"]
    summary["dataset"]["report_template"] = template_id
    summary["report"] = generate_explanation_report(summary, template_id=template_id)
    return json_safe(summary)


def run_pre_audit_only(
    df: pd.DataFrame,
    protected_attributes: list[str],
    outcome_column: str,
    policy_id: str = DEFAULT_POLICY_ID,
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
    control_features: list[str] | None = None,
) -> dict[str, Any]:
    policy = load_policy(policy_id)
    grouping_overrides = grouping_overrides or {}
    validate_audit_selections(df, protected_attributes, outcome_column)
    cleaned = clean_dataframe(df, outcome_column, protected_attributes)
    clean_df = cleaned.dataframe
    pre_audit = run_pre_model_audit(clean_df, protected_attributes, outcome_column, policy, grouping_overrides)
    min_representation_ratio = min(
        (item["minimum_representation_ratio"] for item in pre_audit["representation"]),
        default=1.0,
    )
    result = {
        "dataset": {
            "rows": int(len(clean_df)),
            "columns": int(len(clean_df.columns)),
            "outcome_column": outcome_column,
            "protected_attributes": protected_attributes,
            "policy_id": policy["policy_id"],
        },
        "cleaning": cleaned.cleaning_log,
        "pre_audit": pre_audit,
        "pre_audit_severity": calculate_pre_audit_severity(
            len(pre_audit["proxy_flags"]),
            min_representation_ratio,
            policy=policy,
        ),
        "policy": {
            "policy_id": policy["policy_id"],
            "policy_version": policy["version"],
            "policy_name": policy["name"],
        },
        "grouping_preview": grouping_preview(clean_df, protected_attributes, policy, grouping_overrides),
        "requested_control_features": control_features or [],
    }
    return json_safe(result) | {"_clean_dataframe": clean_df}


def validate_audit_selections(df: pd.DataFrame, protected_attributes: list[str], outcome_column: str) -> None:
    if not protected_attributes:
        raise AuditError("Select at least one protected attribute.")
    if outcome_column in protected_attributes:
        raise AuditError("The outcome column cannot also be marked as protected.")
    missing_columns = [column for column in [outcome_column, *protected_attributes] if column not in df.columns]
    if missing_columns:
        raise AuditError(f"Missing selected column(s): {', '.join(missing_columns)}")


def clean_dataframe(df: pd.DataFrame, outcome_column: str, protected_attributes: list[str]) -> CleanedData:
    if df.empty:
        raise AuditError("The uploaded CSV is empty.")

    missing_columns = [column for column in [outcome_column, *protected_attributes] if column not in df.columns]
    if missing_columns:
        raise AuditError(f"Missing selected column(s): {', '.join(missing_columns)}")

    cleaned = df.copy()
    cleaned = cleaned.dropna(how="all")
    cleaned.columns = [str(column).strip() for column in cleaned.columns]

    for column in cleaned.select_dtypes(include=["object", "string"]).columns:
        cleaned[column] = cleaned[column].map(lambda value: value.strip() if isinstance(value, str) else value)

    initial_rows = len(cleaned)
    missing_percent = cleaned.isnull().mean() * 100
    protected_set = set(protected_attributes)

    drop_columns = [
        column
        for column, percent in missing_percent.items()
        if percent > 50 and column not in protected_set and column != outcome_column
    ]
    if drop_columns:
        cleaned = cleaned.drop(columns=drop_columns)

    outcome, outcome_mapping = normalize_outcome(cleaned[outcome_column])
    invalid_outcome = outcome.isna()
    dropped_outcome_rows = int(invalid_outcome.sum())
    cleaned = cleaned.loc[~invalid_outcome].copy()
    outcome = outcome.loc[~invalid_outcome].astype(int)
    cleaned[outcome_column] = outcome

    if cleaned[outcome_column].nunique(dropna=True) != 2:
        raise AuditError("The selected outcome column must contain exactly two usable classes after normalization.")

    missing_actions: list[dict[str, Any]] = []
    for column in cleaned.columns:
        if column == outcome_column:
            continue

        missing_count = int(cleaned[column].isnull().sum())
        if missing_count == 0:
            continue

        numeric_values, is_numeric = coerce_numeric_if_reasonable(cleaned[column])
        if is_numeric:
            median = numeric_values.median()
            fill_value = 0 if pd.isna(median) else float(median)
            cleaned[column] = numeric_values.fillna(fill_value)
            strategy = f"filled with median ({round(fill_value, 4)})"
        else:
            mode = cleaned[column].mode(dropna=True)
            fill_value = "Unknown" if mode.empty else mode.iloc[0]
            cleaned[column] = cleaned[column].fillna(fill_value)
            strategy = f"filled with mode ({fill_value})"

        missing_actions.append(
            {
                "column": column,
                "missing_count": missing_count,
                "missing_percent": round(float(missing_percent.get(column, 0.0)), 2),
                "action": strategy,
            }
        )

    retained_high_missing = [
        {
            "column": column,
            "missing_percent": round(float(percent), 2),
            "reason": "selected protected or outcome column",
        }
        for column, percent in missing_percent.items()
        if percent > 50 and column in protected_set.union({outcome_column})
    ]

    return CleanedData(
        dataframe=cleaned.reset_index(drop=True),
        outcome_mapping=outcome_mapping,
        cleaning_log={
            "initial_rows": int(initial_rows),
            "rows_after_cleaning": int(len(cleaned)),
            "columns_after_cleaning": int(len(cleaned.columns)),
            "dropped_rows_missing_outcome": dropped_outcome_rows,
            "dropped_columns_over_50_percent_missing": drop_columns,
            "retained_high_missing_selected_columns": retained_high_missing,
            "missing_value_actions": missing_actions,
            "outcome_mapping": outcome_mapping,
            "preview": cleaned.head(5).replace({np.nan: None}).to_dict(orient="records"),
        },
    )


def normalize_outcome(series: pd.Series) -> tuple[pd.Series, dict[str, int]]:
    numeric = pd.to_numeric(series, errors="coerce")
    non_missing_original = series.dropna()

    if numeric.notna().sum() == non_missing_original.shape[0] and numeric.dropna().nunique() == 2:
        unique_values = sorted(numeric.dropna().unique().tolist())
        mapping = {str(unique_values[0]): 0, str(unique_values[1]): 1}
        if set(unique_values) == {0, 1}:
            mapping = {"0": 0, "1": 1}
        return numeric.map({float(unique_values[0]): 0, float(unique_values[1]): 1}), mapping

    normalized = series.map(lambda value: str(value).strip().lower() if pd.notna(value) else np.nan)
    mapped = normalized.map(lambda value: label_to_binary(value) if pd.notna(value) else np.nan)
    if mapped.dropna().nunique() == 2:
        mapping = {
            str(label): int(label_to_binary(str(label).strip().lower()))
            for label in sorted(non_missing_original.astype(str).str.strip().unique())
            if label_to_binary(str(label).strip().lower()) is not None
        }
        return mapped, mapping

    categories = sorted(normalized.dropna().unique().tolist())
    if len(categories) == 2:
        mapping = {categories[0]: 0, categories[1]: 1}
        return normalized.map(mapping), mapping

    raise AuditError("The selected outcome column could not be normalized to binary values.")


def label_to_binary(value: str) -> int | None:
    if value in POSITIVE_LABELS:
        return 1
    if value in NEGATIVE_LABELS:
        return 0
    return None


def run_pre_model_audit(
    df: pd.DataFrame,
    protected_attributes: list[str],
    outcome_column: str,
    policy: dict[str, Any],
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    validation = validate_pre_audit_data(df, protected_attributes, outcome_column, policy, grouping_overrides)
    representation = []
    for protected in protected_attributes:
        grouped = grouped_sensitive_feature(df[protected], protected, policy=policy, grouping_overrides=grouping_overrides)
        rates = df.assign(_group=grouped).groupby("_group", dropna=False)[outcome_column].agg(["count", "mean"])
        rates = rates.sort_values("mean", ascending=False)
        max_rate = float(rates["mean"].max()) if len(rates) else 0.0
        min_rate = float(rates["mean"].min()) if len(rates) else 0.0
        minimum_ratio = safe_ratio(min_rate, max_rate, default=1.0)
        groups = []
        for group_name, row in rates.iterrows():
            rate = float(row["mean"])
            ratio_to_best = safe_ratio(rate, max_rate, default=1.0)
            groups.append(
                {
                    "group": str(group_name),
                    "count": int(row["count"]),
                    "positive_rate": round(rate, 4),
                    "ratio_to_highest": round(ratio_to_best, 4),
                    "status": ratio_status(ratio_to_best, policy, "representation_ratio"),
                }
            )
        representation.append(
            {
                "protected_attribute": protected,
                "minimum_representation_ratio": round(minimum_ratio, 4),
                "warning": minimum_ratio < 0.8,
                "groups": groups,
            }
        )

    proxy_flags = detect_proxy_variables(df, protected_attributes, outcome_column, policy)
    return {"validation": validation, "representation": representation, "proxy_flags": proxy_flags}


def validate_pre_audit_data(
    df: pd.DataFrame,
    protected_attributes: list[str],
    outcome_column: str,
    policy: dict[str, Any],
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    warnings: list[str] = []
    checks: list[dict[str, Any]] = []

    outcome_values = sorted(df[outcome_column].dropna().unique().tolist())
    if outcome_values != [0, 1]:
        raise AuditError("The normalized outcome field must be binary 0/1.")

    positive_rate = float(df[outcome_column].mean()) if len(df) else 0.0
    if positive_rate < 0.05 or positive_rate > 0.95:
        warnings.append("The outcome is extremely imbalanced, so model metrics may be unstable.")
    checks.append(
        {
            "name": "Outcome is binary",
            "status": "Pass",
            "details": f"Outcome `{outcome_column}` normalized to 0/1 with positive rate {round(positive_rate, 4)}.",
        }
    )

    for protected in protected_attributes:
        grouped = grouped_sensitive_feature(df[protected], protected, policy=policy, grouping_overrides=grouping_overrides)
        counts = grouped.value_counts(dropna=False)
        if len(counts) < 2:
            warnings.append(f"Protected attribute `{protected}` has fewer than two groups after cleaning.")
            status = "Warn"
        elif int(counts.min()) < 10:
            warnings.append(f"Protected attribute `{protected}` has at least one group with fewer than 10 rows.")
            status = "Warn"
        else:
            status = "Pass"
        checks.append(
            {
                "name": f"Protected groups for {protected}",
                "status": status,
                "details": ", ".join(f"{group}: {count}" for group, count in counts.items()),
            }
        )

    return {"checks": checks, "warnings": warnings}


def detect_proxy_variables(
    df: pd.DataFrame,
    protected_attributes: list[str],
    outcome_column: str,
    policy: dict[str, Any],
) -> list[dict[str, Any]]:
    protected_set = set(protected_attributes)
    proxy_flags: list[dict[str, Any]] = []
    thresholds = policy["fairness_thresholds"]["proxy_variable_strength"]

    for feature in df.columns:
        if feature == outcome_column or feature in protected_set:
            continue
        for protected in protected_attributes:
            strength, method = association_strength(df[feature], df[protected])
            if strength >= thresholds["warning_above"]:
                proxy_flags.append(
                    {
                        "feature": feature,
                        "protected_attribute": protected,
                        "strength": round(float(strength), 4),
                        "method": method,
                        "risk": "Critical" if strength >= thresholds["critical_above"] else "High",
                    }
                )

    proxy_flags.sort(key=lambda item: item["strength"], reverse=True)
    return proxy_flags


def train_and_audit_model(
    df: pd.DataFrame,
    protected_attributes: list[str],
    outcome_column: str,
    model_type: str,
    proxy_flags: list[dict[str, Any]],
    policy: dict[str, Any],
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
    control_features: list[str] | None = None,
    model_selection_priority: float | None = None,
) -> dict[str, Any]:
    X = df.drop(columns=[outcome_column])
    y = df[outcome_column].astype(int)
    if X.empty:
        raise AuditError("At least one feature column is required in addition to the outcome column.")
    if len(df) < 10:
        raise AuditError("At least 10 rows are required to train and test a model.")

    stratify = y if y.value_counts().min() >= 2 else None
    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=0.2,
        random_state=42,
        stratify=stratify,
    )

    if model_type == "compare_all":
        selected = compare_and_select_model(
            X_train,
            X_test,
            y_train,
            y_test,
            protected_attributes,
            policy,
            grouping_overrides,
            model_selection_priority,
        )
    else:
        selected = fit_selected_model(
            X_train,
            X_test,
            y_train,
            y_test,
            protected_attributes,
            model_type,
            policy,
            grouping_overrides,
            model_selection_priority,
        )

    pipeline = selected["pipeline"]
    selected_model_type = selected["model_key"]
    y_pred, prediction_validation = normalize_prediction_output(pipeline.predict(X_test))
    y_pred.index = X_test.index
    feature_importance = model_feature_importance(pipeline, X)
    result = build_post_audit_result(
        X_test,
        y_test,
        y_pred,
        protected_attributes,
        proxy_flags,
        feature_importance,
        model_type=MODEL_LABELS[selected_model_type],
        mode="train",
        training_samples=int(len(X_train)),
        prediction_validation=prediction_validation,
        model_input={
            "strategy": "auditor_pipeline",
            "details": "The auditor tuned hyperparameters locally, trained the selected preprocessing + model pipeline, and evaluated it on the held-out test split.",
        },
        policy=policy,
        grouping_overrides=grouping_overrides,
        selected_control_features=control_features,
    )
    result["selected_model_key"] = selected_model_type
    result["requested_model_type"] = MODEL_LABELS[model_type]
    result["tuning"] = selected["tuning"]
    result["model_comparison"] = selected["model_comparison"]
    result["audit_trace"] = build_decision_audit_trace(
        pipeline,
        X_test,
        X_test,
        y_test,
        y_pred,
        protected_attributes,
        X_train,
        policy,
        grouping_overrides,
    )
    result["improvement_simulation"] = simulate_feature_drop(
        df,
        protected_attributes,
        outcome_column,
        selected_model_type,
        proxy_flags,
        selected["tuning"].get("best_params", {}),
        policy=policy,
        grouping_overrides=grouping_overrides,
    )
    return result


def fit_selected_model(
    X_train: pd.DataFrame,
    X_test: pd.DataFrame,
    y_train: pd.Series,
    y_test: pd.Series,
    protected_attributes: list[str],
    model_type: str,
    policy: dict[str, Any],
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
    model_selection_priority: float | None = None,
) -> dict[str, Any]:
    fitted = fit_tuned_model(X_train, y_train, model_type)
    y_pred, _ = normalize_prediction_output(fitted["pipeline"].predict(X_test))
    y_pred.index = X_test.index
    row = model_comparison_row(
        model_type,
        fitted["tuning"],
        y_test,
        y_pred,
        X_test,
        protected_attributes,
        policy,
        grouping_overrides,
        selected=True,
        model_selection_priority=model_selection_priority,
    )
    return {
        "pipeline": fitted["pipeline"],
        "model_key": model_type,
        "tuning": fitted["tuning"],
        "model_comparison": [row],
    }


def compare_and_select_model(
    X_train: pd.DataFrame,
    X_test: pd.DataFrame,
    y_train: pd.Series,
    y_test: pd.Series,
    protected_attributes: list[str],
    policy: dict[str, Any],
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
    model_selection_priority: float | None = None,
) -> dict[str, Any]:
    candidates: list[dict[str, Any]] = []
    selected: dict[str, Any] | None = None

    for candidate_key in TRAINABLE_MODEL_KEYS:
        try:
            fitted = fit_tuned_model(X_train, y_train, candidate_key)
            y_pred, _ = normalize_prediction_output(fitted["pipeline"].predict(X_test))
            y_pred.index = X_test.index
            row = model_comparison_row(
                candidate_key,
                fitted["tuning"],
                y_test,
                y_pred,
                X_test,
                protected_attributes,
                policy,
                grouping_overrides,
                selected=False,
                model_selection_priority=model_selection_priority,
            )
            candidates.append({"row": row, **fitted, "model_key": candidate_key})
            if selected is None or row["audit_selection_score"] > selected["row"]["audit_selection_score"]:
                selected = candidates[-1]
        except Exception as exc:
            candidates.append(
                {
                    "row": {
                        "model_key": candidate_key,
                        "model": MODEL_LABELS[candidate_key],
                        "selected": False,
                        "status": "Failed",
                        "error": str(exc),
                        "best_params": {},
                        "cv_score": None,
                        "balanced_accuracy": None,
                        "accuracy": None,
                        "precision": None,
                        "recall": None,
                        "max_demographic_parity_difference": None,
                        "max_equalized_odds_difference": None,
                        "min_disparate_impact_ratio": None,
                        "audit_selection_score": None,
                        "fails_policy": True,
                        "policy_failures": [str(exc)],
                    }
                }
            )

    if selected is None:
        raise AuditError("All local model candidates failed during tuning. Try a simpler CSV or upload a trained model.")

    for candidate in candidates:
        candidate["row"]["selected"] = candidate.get("model_key") == selected["model_key"]

    return {
        "pipeline": selected["pipeline"],
        "model_key": selected["model_key"],
        "tuning": selected["tuning"],
        "model_comparison": [candidate["row"] for candidate in candidates],
    }


def fit_tuned_model(X_train: pd.DataFrame, y_train: pd.Series, model_type: str) -> dict[str, Any]:
    X_tune, y_tune = tuning_sample(X_train, y_train)
    cv_folds = min(MAX_CV_FOLDS, int(y_tune.value_counts().min())) if y_tune.nunique() == 2 else 0
    param_grid = MODEL_PARAM_GRIDS.get(model_type, {})

    if cv_folds < 2 or not param_grid:
        pipeline = build_model_pipeline(X_train, model_type)
        pipeline.fit(X_train, y_train)
        return {
            "pipeline": pipeline,
            "tuning": {
                "status": "Default parameters",
                "best_params": {},
                "cv_score": None,
                "cv_folds": cv_folds,
                "tuning_samples": int(len(X_tune)),
                "scoring": "balanced_accuracy",
            },
        }

    search = GridSearchCV(
        build_model_pipeline(X_tune, model_type),
        param_grid=param_grid,
        scoring="balanced_accuracy",
        cv=StratifiedKFold(n_splits=cv_folds, shuffle=True, random_state=42),
        n_jobs=1,
        error_score=np.nan,
    )
    try:
        with warnings.catch_warnings():
            warnings.filterwarnings("ignore", category=ConvergenceWarning)
            search.fit(X_tune, y_tune)
        if not hasattr(search, "best_params_") or pd.isna(search.best_score_):
            raise AuditError("No valid hyperparameter combination completed.")
        pipeline = build_model_pipeline(X_train, model_type)
        pipeline.set_params(**search.best_params_)
        pipeline.fit(X_train, y_train)
        return {
            "pipeline": pipeline,
            "tuning": {
                "status": "Tuned",
                "best_params": clean_model_params(search.best_params_),
                "cv_score": round(float(search.best_score_), 4),
                "cv_folds": cv_folds,
                "tuning_samples": int(len(X_tune)),
                "scoring": "balanced_accuracy",
            },
        }
    except Exception as exc:
        pipeline = build_model_pipeline(X_train, model_type)
        pipeline.fit(X_train, y_train)
        return {
            "pipeline": pipeline,
            "tuning": {
                "status": "Tuning failed; default parameters used",
                "best_params": {},
                "cv_score": None,
                "cv_folds": cv_folds,
                "tuning_samples": int(len(X_tune)),
                "scoring": "balanced_accuracy",
                "warning": str(exc),
            },
        }


def tuning_sample(X_train: pd.DataFrame, y_train: pd.Series) -> tuple[pd.DataFrame, pd.Series]:
    if len(X_train) <= TUNING_SAMPLE_LIMIT:
        return X_train, y_train
    stratify = y_train if y_train.value_counts().min() >= 2 else None
    X_sample, _, y_sample, _ = train_test_split(
        X_train,
        y_train,
        train_size=TUNING_SAMPLE_LIMIT,
        random_state=42,
        stratify=stratify,
    )
    return X_sample, y_sample


def model_comparison_row(
    model_type: str,
    tuning: dict[str, Any],
    y_true: pd.Series,
    y_pred: pd.Series,
    X_eval: pd.DataFrame,
    protected_attributes: list[str],
    policy: dict[str, Any],
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
    *,
    selected: bool,
    model_selection_priority: float | None = None,
) -> dict[str, Any]:
    fairness = fairness_summary(y_true, y_pred, X_eval, protected_attributes, policy, grouping_overrides)
    balanced = float(balanced_accuracy_score(y_true, y_pred))
    selection_score = model_selection_score(
        balanced_accuracy=balanced,
        demographic_parity_difference=fairness["max_demographic_parity_difference"],
        equalized_odds_difference=fairness["max_equalized_odds_difference"],
        disparate_impact_ratio=fairness["min_disparate_impact_ratio"],
        policy=policy,
        priority=model_selection_priority,
    )
    row = {
        "model_key": model_type,
        "model": MODEL_LABELS[model_type],
        "selected": selected,
        "status": tuning.get("status", "Tuned"),
        "best_params": tuning.get("best_params", {}),
        "cv_score": tuning.get("cv_score"),
        "cv_folds": tuning.get("cv_folds"),
        "tuning_samples": tuning.get("tuning_samples"),
        "balanced_accuracy": round(balanced, 4),
        "accuracy": round(float(accuracy_score(y_true, y_pred)), 4),
        "precision": round(float(precision_score(y_true, y_pred, zero_division=0)), 4),
        "recall": round(float(recall_score(y_true, y_pred, zero_division=0)), 4),
        "max_demographic_parity_difference": fairness["max_demographic_parity_difference"],
        "max_equalized_odds_difference": fairness["max_equalized_odds_difference"],
        "min_disparate_impact_ratio": fairness["min_disparate_impact_ratio"],
        "audit_selection_score": round(float(selection_score), 4),
        "policy_failures": [],
    }
    row["policy_failures"] = model_policy_failures(row, policy)
    row["fails_policy"] = bool(row["policy_failures"])
    return row


def fairness_summary(
    y_true: pd.Series,
    y_pred: pd.Series,
    X_eval: pd.DataFrame,
    protected_attributes: list[str],
    policy: dict[str, Any],
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
) -> dict[str, float]:
    metric_rows = []
    for protected in protected_attributes:
        sensitive = grouped_sensitive_feature(X_eval[protected], protected, policy=policy, grouping_overrides=grouping_overrides)
        dp = safe_metric(
            lambda: demographic_parity_difference(y_true, y_pred, sensitive_features=sensitive),
            default=0.0,
        )
        eo = safe_metric(
            lambda: equalized_odds_difference(y_true, y_pred, sensitive_features=sensitive),
            default=0.0,
        )
        group_rows = group_prediction_table(y_true, y_pred, sensitive, policy)
        metric_rows.append((float(dp), float(eo), min((group["selection_rate"] for group in group_rows), default=1.0)))
    return {
        "max_demographic_parity_difference": round(max((item[0] for item in metric_rows), default=0.0), 4),
        "max_equalized_odds_difference": round(max((item[1] for item in metric_rows), default=0.0), 4),
        "min_disparate_impact_ratio": round(min((item[2] for item in metric_rows), default=1.0), 4),
    }


def clean_model_params(params: dict[str, Any]) -> dict[str, Any]:
    cleaned = {}
    for key, value in params.items():
        cleaned[key.replace("model__", "")] = value
    return cleaned


def build_decision_audit_trace(
    model: Any,
    feature_frame: pd.DataFrame,
    display_frame: pd.DataFrame,
    y_true: pd.Series,
    y_pred: pd.Series,
    protected_attributes: list[str],
    baseline_frame: pd.DataFrame,
    policy: dict[str, Any] | None = None,
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
    *,
    max_records: int = 8,
    max_features: int = 6,
) -> dict[str, Any]:
    if feature_frame.empty:
        return {
            "method": "local_baseline_perturbation",
            "explainability_available": False,
            "reason": "No evaluation features were available for row-level explanations.",
            "records": [],
        }

    baseline = feature_baseline_values(baseline_frame)
    risky_indices = select_audit_trace_indices(
        display_frame,
        y_true,
        y_pred,
        protected_attributes,
        max_records,
        policy=policy,
        grouping_overrides=grouping_overrides,
    )
    records = []
    warnings_list: list[str] = []

    for row_index in risky_indices:
        if row_index not in feature_frame.index:
            continue
        row = feature_frame.loc[[row_index]].copy()
        display_row = display_frame.loc[row_index] if row_index in display_frame.index else feature_frame.loc[row_index]
        try:
            original_score = prediction_score(model, row)
        except Exception as exc:
            return {
                "method": "local_baseline_perturbation",
                "explainability_available": False,
                "reason": f"Could not score rows for explanation: {exc}",
                "records": [],
            }

        contributions = []
        for feature in feature_frame.columns:
            if feature not in baseline:
                continue
            perturbed = row.copy()
            perturbed.at[row_index, feature] = baseline[feature]
            try:
                perturbed_score = prediction_score(model, perturbed)
            except Exception as exc:
                warnings_list.append(f"Feature `{feature}` explanation failed for row {row_index}: {exc}")
                continue
            contribution = original_score - perturbed_score
            value = display_row.get(feature, row.iloc[0].get(feature)) if hasattr(display_row, "get") else row.iloc[0].get(feature)
            contributions.append(
                {
                    "feature": str(feature),
                    "value": json_safe(value),
                    "baseline": json_safe(baseline[feature]),
                    "contribution": round(float(contribution), 5),
                    "absolute_contribution": round(abs(float(contribution)), 5),
                    "direction": "pushed_toward_positive" if contribution > 0 else "pushed_toward_negative",
                }
            )

        contributions.sort(key=lambda item: item["absolute_contribution"], reverse=True)
        top_contributions = contributions[:max_features]
        records.append(
            {
                "row_id": int(row_index) if isinstance(row_index, (int, np.integer)) else str(row_index),
                "prediction": int(y_pred.loc[row_index]) if row_index in y_pred.index else int(pd.Series(y_pred).loc[row_index]),
                "actual": int(y_true.loc[row_index]) if row_index in y_true.index else int(pd.Series(y_true).loc[row_index]),
                "decision_score": round(float(original_score), 5),
                "risk_reason": audit_trace_reason(
                    row_index,
                    display_frame,
                    y_true,
                    y_pred,
                    protected_attributes,
                    policy=policy,
                    grouping_overrides=grouping_overrides,
                ),
                "protected_attributes": {
                    protected: json_safe(display_row.get(protected))
                    for protected in protected_attributes
                    if hasattr(display_row, "get") and protected in display_row.index
                },
                "top_contributions": top_contributions,
                "model_relied_on": [item["feature"] for item in top_contributions],
            }
        )

    return {
        "method": "local_baseline_perturbation",
        "method_description": "Each listed feature is replaced with a training baseline value and the change in the positive-decision score is recorded. Negative contributions pushed the decision toward denial or rejection.",
        "explainability_available": bool(records),
        "records": records,
        "warnings": warnings_list[:10],
    }


def select_audit_trace_indices(
    X_eval: pd.DataFrame,
    y_true: pd.Series,
    y_pred: pd.Series,
    protected_attributes: list[str],
    max_records: int,
    policy: dict[str, Any] | None = None,
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
) -> list[Any]:
    frame = pd.DataFrame({"actual": y_true, "prediction": y_pred}, index=X_eval.index)
    frame["risk_score"] = 0.0
    frame.loc[(frame["actual"] == 1) & (frame["prediction"] == 0), "risk_score"] += 3.0
    frame.loc[frame["prediction"] == 0, "risk_score"] += 1.0

    for protected in protected_attributes:
        if protected not in X_eval.columns:
            continue
        groups = grouped_sensitive_feature(X_eval[protected], protected, policy=policy, grouping_overrides=grouping_overrides)
        rates = pd.Series(y_pred, index=X_eval.index).groupby(groups).mean()
        if rates.empty:
            continue
        lowest_groups = set(rates[rates == rates.min()].index.astype(str).tolist())
        frame.loc[groups.astype(str).isin(lowest_groups), "risk_score"] += 1.0

    frame = frame.sort_values(["risk_score", "actual"], ascending=[False, False])
    return frame.head(max_records).index.tolist()


def audit_trace_reason(
    row_index: Any,
    X_eval: pd.DataFrame,
    y_true: pd.Series,
    y_pred: pd.Series,
    protected_attributes: list[str],
    policy: dict[str, Any] | None = None,
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
) -> str:
    actual = int(y_true.loc[row_index])
    prediction = int(y_pred.loc[row_index])
    reasons = []
    if actual == 1 and prediction == 0:
        reasons.append("false negative")
    if prediction == 0:
        reasons.append("negative decision")
    for protected in protected_attributes:
        if protected not in X_eval.columns:
            continue
        groups = grouped_sensitive_feature(X_eval[protected], protected, policy=policy, grouping_overrides=grouping_overrides)
        group = str(groups.loc[row_index])
        rates = pd.Series(y_pred, index=X_eval.index).groupby(groups).mean()
        if len(rates) and group in set(rates[rates == rates.min()].index.astype(str)):
            reasons.append(f"member of lowest-selection {protected} group")
    return ", ".join(dict.fromkeys(reasons)) or "sampled decision"


def feature_baseline_values(df: pd.DataFrame) -> dict[str, Any]:
    baselines = {}
    for column in df.columns:
        numeric, is_numeric = coerce_numeric_if_reasonable(df[column])
        if is_numeric:
            median = numeric.median()
            if pd.isna(median):
                baselines[column] = 0
            elif pd.api.types.is_string_dtype(df[column]) or pd.api.types.is_object_dtype(df[column]):
                baselines[column] = str(int(round(float(median)))) if float(median).is_integer() else str(float(median))
            elif pd.api.types.is_integer_dtype(df[column]):
                baselines[column] = int(round(float(median)))
            else:
                baselines[column] = float(median)
        else:
            mode = df[column].mode(dropna=True)
            baselines[column] = "Unknown" if mode.empty else mode.iloc[0]
    return baselines


def prediction_score(model: Any, row: pd.DataFrame) -> float:
    if hasattr(model, "predict_proba"):
        probabilities = model.predict_proba(row)
        if np.asarray(probabilities).ndim == 2 and np.asarray(probabilities).shape[1] > 1:
            return float(np.asarray(probabilities)[0, 1])
    if hasattr(model, "decision_function"):
        margin = np.asarray(model.decision_function(row)).ravel()[0]
        return float(1 / (1 + math.exp(-float(np.clip(margin, -50, 50)))))
    prediction = np.asarray(model.predict(row)).ravel()[0]
    return float(prediction)


def audit_uploaded_model(
    df: pd.DataFrame,
    protected_attributes: list[str],
    outcome_column: str,
    model: Any,
    model_name: str,
    proxy_flags: list[dict[str, Any]],
    policy: dict[str, Any],
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
    control_features: list[str] | None = None,
) -> dict[str, Any]:
    X = df.drop(columns=[outcome_column])
    y = df[outcome_column].astype(int)
    if X.empty:
        raise AuditError("At least one feature column is required in addition to the outcome column.")
    if not hasattr(model, "predict"):
        raise AuditError("Uploaded model must expose a predict(...) method.")

    raw_predictions, input_frame, model_input = predict_with_uploaded_model(model, X)
    y_pred, prediction_validation = normalize_prediction_output(raw_predictions)
    y_pred.index = y.index
    if len(y_pred) != len(y):
        raise AuditError("Uploaded model returned a different number of predictions than dataset rows.")

    if len(set(y_pred.tolist())) < 2:
        prediction_validation["warnings"].append(
            "The uploaded model predicted only one class for this dataset. Bias metrics may look artificially low."
        )

    feature_importance = generic_model_feature_importance(model, input_frame)
    result = build_post_audit_result(
        X,
        y,
        y_pred,
        protected_attributes,
        proxy_flags,
        feature_importance,
        model_type=f"Uploaded model ({model_name})",
        mode="uploaded_model",
        training_samples=None,
        prediction_validation=prediction_validation,
        model_input=model_input,
        policy=policy,
        grouping_overrides=grouping_overrides,
        selected_control_features=control_features,
    )
    result["audit_trace"] = build_decision_audit_trace(
        model,
        input_frame,
        X,
        y,
        y_pred,
        protected_attributes,
        input_frame,
        policy,
        grouping_overrides,
    )
    result["improvement_simulation"] = {
        "available": False,
        "reason": "The uploaded model was evaluated as-is. The auditor cannot safely retrain or modify an external model artifact.",
        "recommended_next_step": "Retrain the source model without direct protected attributes and high-risk proxy variables, then upload the new artifact for comparison.",
    }
    return result


def audit_prediction_csv(
    df: pd.DataFrame,
    protected_attributes: list[str],
    outcome_column: str,
    predictions: pd.Series,
    scores: pd.Series | None,
    prediction_metadata: dict[str, Any],
    proxy_flags: list[dict[str, Any]],
    policy: dict[str, Any],
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
    control_features: list[str] | None = None,
) -> dict[str, Any]:
    X = df.drop(columns=[outcome_column])
    y = df[outcome_column].astype(int)
    y_pred, prediction_validation = normalize_prediction_output(predictions)
    y_pred.index = y.index
    threshold_metadata = build_score_metadata(scores, prediction_metadata) if scores is not None else {"available": False}
    prediction_validation["warnings"].append(
        "Prediction-only CSV mode does not inspect or execute the model artifact. Feature-level explanations and mitigation simulations are limited."
    )

    result = build_post_audit_result(
        X,
        y,
        y_pred,
        protected_attributes,
        proxy_flags,
        feature_importance=[],
        model_type="Prediction CSV audit",
        mode="prediction_csv",
        training_samples=None,
        prediction_validation=prediction_validation,
        model_input={
            "strategy": "prediction_csv",
            "details": (
                f"Audited externally generated predictions from `{prediction_metadata.get('filename', 'predictions.csv')}` "
                f"using column `{prediction_metadata.get('selected_prediction_column', prediction_metadata.get('selected_column', 'prediction'))}`."
            ),
            "warnings": prediction_metadata.get("warnings", []),
            "validation": prediction_metadata,
        },
        policy=policy,
        grouping_overrides=grouping_overrides,
        selected_control_features=control_features,
    )
    result["audit_trace"] = {
        "method": "prediction_only_review",
        "method_description": "Prediction CSV audits can validate fairness outcomes but cannot attribute row-level feature contributions because the model artifact was not executed in the auditor.",
        "explainability_available": False,
        "confidence": "Low-Medium",
        "limitations": [
            "Predictions were audited without model internals.",
            "No local feature contribution trace is available in prediction-only mode.",
        ],
        "records": [],
        "reason": "Prediction CSV mode validates outputs safely without loading a model artifact.",
    }
    result["improvement_simulation"] = {
        "available": False,
        "reason": "Prediction-only mode cannot retrain or simulate mitigations because the original model artifact was not provided.",
        "recommended_next_step": "Re-run with a safe supported model or retrain externally and compare a second prediction CSV after remediation.",
    }
    result["prediction_validation"]["csv_validation"] = prediction_metadata
    result["threshold_sensitivity"] = threshold_metadata
    return result


def build_score_metadata(scores: pd.Series, prediction_metadata: dict[str, Any]) -> dict[str, Any]:
    numeric_scores = pd.to_numeric(scores, errors="coerce")
    valid_scores = numeric_scores.dropna()
    if valid_scores.empty:
        return {
            "available": False,
            "selected_score_column": prediction_metadata.get("selected_score_column"),
            "reason": "The selected score column did not contain numeric score values.",
        }
    return {
        "available": True,
        "selected_score_column": prediction_metadata.get("selected_score_column"),
        "rows_with_scores": int(valid_scores.shape[0]),
        "missing_scores": int(numeric_scores.isna().sum()),
        "min_score": round(float(valid_scores.min()), 6),
        "max_score": round(float(valid_scores.max()), 6),
        "mean_score": round(float(valid_scores.mean()), 6),
        "recommended_threshold_review": True,
        "supported_future_analysis": [
            "threshold sweep",
            "group-specific sensitivity review",
            "calibration by protected group",
        ],
    }


def build_post_audit_result(
    X_eval: pd.DataFrame,
    y_true: pd.Series,
    y_pred: pd.Series,
    protected_attributes: list[str],
    proxy_flags: list[dict[str, Any]],
    feature_importance: list[dict[str, Any]],
    *,
    model_type: str,
    mode: str,
    training_samples: int | None,
    prediction_validation: dict[str, Any],
    model_input: dict[str, Any],
    policy: dict[str, Any],
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
    selected_control_features: list[str] | None = None,
) -> dict[str, Any]:
    performance = {
        "training_samples": training_samples,
        "test_samples": int(len(X_eval)),
        "accuracy": round(float(accuracy_score(y_true, y_pred)), 4),
        "precision": round(float(precision_score(y_true, y_pred, zero_division=0)), 4),
        "recall": round(float(recall_score(y_true, y_pred, zero_division=0)), 4),
    }

    bias_metrics = []
    for protected in protected_attributes:
        sensitive = grouped_sensitive_feature(X_eval[protected], protected, policy=policy, grouping_overrides=grouping_overrides)
        dp = safe_metric(
            lambda: demographic_parity_difference(y_true, y_pred, sensitive_features=sensitive),
            default=0.0,
        )
        eo = safe_metric(
            lambda: equalized_odds_difference(y_true, y_pred, sensitive_features=sensitive),
            default=0.0,
        )

        group_table = group_prediction_table(y_true, y_pred, sensitive, policy)
        disparate_impact_ratio = (
            round(
                min((group["selection_rate"] for group in group_table), default=0.0)
                / max((group["selection_rate"] for group in group_table), default=1.0),
                4,
            )
            if group_table and max((group["selection_rate"] for group in group_table), default=0.0) > 0
            else 0.0
        )
        bias_metrics.append(
            {
                "protected_attribute": protected,
                "demographic_parity_difference": round(float(dp), 4),
                "equalized_odds_difference": round(float(eo), 4),
                "status": gap_status(max(float(dp), float(eo)), policy, "equalized_odds_difference"),
                "groups": group_table,
                "disparate_impact_ratio": disparate_impact_ratio,
                "disparate_impact_status": ratio_status(disparate_impact_ratio, policy, "disparate_impact_ratio"),
            }
        )

    return {
        "mode": mode,
        "model_type": model_type,
        "model_input": model_input,
        "prediction_validation": prediction_validation,
        "performance": performance,
        "bias_metrics": bias_metrics,
        "conditional_fairness": build_conditional_fairness(
            X_eval,
            y_pred,
            protected_attributes,
            feature_importance,
            proxy_flags,
            policy,
            grouping_overrides,
            selected_control_features,
        ),
        "intersectional_bias": build_intersectional_analysis(
            X_eval,
            y_true,
            y_pred,
            protected_attributes,
            policy,
            grouping_overrides,
        ),
        "feature_importance": feature_importance[:10],
        "bias_sources": build_bias_sources(feature_importance, proxy_flags),
        "limitations": build_limitations(mode, feature_importance),
    }


def build_bias_sources(feature_importance: list[dict[str, Any]], proxy_flags: list[dict[str, Any]]) -> list[dict[str, Any]]:
    proxy_lookup = {(item["feature"], item["protected_attribute"]): item for item in proxy_flags}
    flagged_features = {item["feature"] for item in proxy_flags}
    bias_sources = []
    for row in feature_importance[:10]:
        if row["importance"] <= 0:
            continue
        if row["feature"] in flagged_features:
            related = [item for key, item in proxy_lookup.items() if key[0] == row["feature"]]
            bias_sources.append(
                {
                    "feature": row["feature"],
                    "importance": row["importance"],
                    "rank": row["rank"],
                    "proxy_links": related,
                }
            )
    return bias_sources


def build_conditional_fairness(
    X_eval: pd.DataFrame,
    y_pred: pd.Series,
    protected_attributes: list[str],
    feature_importance: list[dict[str, Any]],
    proxy_flags: list[dict[str, Any]],
    policy: dict[str, Any],
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
    selected_control_features: list[str] | None = None,
) -> dict[str, Any]:
    recommendations = rank_control_features(X_eval, y_pred, protected_attributes, feature_importance, proxy_flags)
    control_features = select_control_features(
        X_eval,
        protected_attributes,
        feature_importance,
        recommendations,
        selected_control_features,
    )
    if not control_features:
        return {
            "available": False,
            "reason": "No non-protected control features were available for same-background cohort analysis.",
            "control_features": [],
            "results": [],
            "recommendations": recommendations,
        }

    cohort_frame = pd.DataFrame(index=X_eval.index)
    for feature in control_features:
        cohort_frame[feature] = cohort_values(X_eval[feature], feature, policy, grouping_overrides)
    cohort_key = cohort_frame.astype(str).agg(" | ".join, axis=1)

    results = []
    for protected in protected_attributes:
        if protected not in X_eval.columns:
            continue
        sensitive = grouped_sensitive_feature(X_eval[protected], protected, policy=policy, grouping_overrides=grouping_overrides).astype(str)
        frame = pd.DataFrame(
            {
                "prediction": pd.Series(y_pred, index=X_eval.index).astype(int),
                "protected_group": sensitive,
                "cohort": cohort_key,
            },
            index=X_eval.index,
        )
        cohort_rows = []
        weighted_gap_sum = 0.0
        weighted_count = 0
        for cohort, group_df in frame.groupby("cohort"):
            if len(group_df) < 20 or group_df["protected_group"].nunique() < 2:
                continue
            counts = group_df["protected_group"].value_counts()
            valid_groups = counts[counts >= 5].index
            group_df = group_df[group_df["protected_group"].isin(valid_groups)]
            if group_df["protected_group"].nunique() < 2:
                continue
            rates = group_df.groupby("protected_group")["prediction"].mean().sort_values(ascending=False)
            gap = float(rates.max() - rates.min())
            weighted_gap_sum += gap * len(group_df)
            weighted_count += len(group_df)
            cohort_rows.append(
                {
                    "cohort": str(cohort),
                    "count": int(len(group_df)),
                    "highest_group": str(rates.index[0]),
                    "highest_selection_rate": round(float(rates.iloc[0]), 4),
                    "lowest_group": str(rates.index[-1]),
                    "lowest_selection_rate": round(float(rates.iloc[-1]), 4),
                    "selection_gap": round(gap, 4),
                    "status": gap_status(gap, policy, "demographic_parity_difference"),
                }
            )

        cohort_rows.sort(key=lambda item: item["selection_gap"], reverse=True)
        results.append(
            {
                "protected_attribute": protected,
                "control_features": control_features,
                "cohorts_analyzed": len(cohort_rows),
                "weighted_selection_gap": round(safe_ratio(weighted_gap_sum, weighted_count, default=0.0), 4),
                "status": gap_status(safe_ratio(weighted_gap_sum, weighted_count, default=0.0), policy, "demographic_parity_difference"),
                "worst_cohorts": cohort_rows[:5],
            }
        )

    return {
        "available": any(item["cohorts_analyzed"] for item in results),
        "method": "stratified_same_background_cohorts",
        "control_features": control_features,
        "minimum_group_size": 5,
        "minimum_cohort_size": 20,
        "results": results,
        "recommendations": recommendations,
    }


def rank_control_features(
    X_eval: pd.DataFrame,
    y_pred: pd.Series,
    protected_attributes: list[str],
    feature_importance: list[dict[str, Any]],
    proxy_flags: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    protected_set = set(protected_attributes)
    importance_lookup = {item["feature"]: float(item.get("normalized_importance", 0.0)) for item in feature_importance}
    proxy_lookup: dict[str, float] = {}
    for item in proxy_flags:
        proxy_lookup[item["feature"]] = max(proxy_lookup.get(item["feature"], 0.0), float(item.get("strength", 0.0)))

    rows = []
    target = pd.Series(y_pred).astype(int)
    for feature in X_eval.columns:
        if feature in protected_set or X_eval[feature].nunique(dropna=True) <= 1:
            continue
        predictive_strength, _ = association_strength(X_eval[feature], target)
        if feature in importance_lookup:
            predictive_strength = max(predictive_strength, importance_lookup[feature])
        proxy_risk = proxy_lookup.get(feature, 0.0)
        missingness = float(X_eval[feature].isna().mean())
        suitability = round(max(0.0, predictive_strength - proxy_risk - missingness), 4)
        rows.append(
            {
                "feature": feature,
                "predictive_strength": round(float(predictive_strength), 4),
                "proxy_risk": round(float(proxy_risk), 4),
                "missingness": round(float(missingness), 4),
                "suitability": suitability,
                "recommended": suitability > 0.15 and proxy_risk < 0.5,
            }
        )
    rows.sort(key=lambda item: item["suitability"], reverse=True)
    return rows[:12]


def select_control_features(
    X_eval: pd.DataFrame,
    protected_attributes: list[str],
    feature_importance: list[dict[str, Any]],
    recommendations: list[dict[str, Any]] | None = None,
    selected_control_features: list[str] | None = None,
    max_features: int = 3,
) -> list[str]:
    protected_set = set(protected_attributes)
    requested = [feature for feature in (selected_control_features or []) if feature in X_eval.columns and feature not in protected_set]
    if requested:
        return requested[:max_features]

    recommendations = recommendations or []
    if recommendations:
        ordered = [item["feature"] for item in recommendations]
    else:
        ordered = [
            item["feature"]
            for item in feature_importance
            if item["feature"] in X_eval.columns and item["feature"] not in protected_set
        ]
    if not ordered:
        ordered = [column for column in X_eval.columns if column not in protected_set]
    controls = []
    for feature in ordered:
        if X_eval[feature].nunique(dropna=True) <= 1:
            continue
        controls.append(feature)
        if len(controls) == max_features:
            break
    return controls


def cohort_values(
    series: pd.Series,
    column_name: str,
    policy: dict[str, Any],
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
) -> pd.Series:
    numeric, is_numeric = coerce_numeric_if_reasonable(series)
    if is_numeric and numeric.nunique(dropna=True) > 5:
        try:
            return pd.qcut(numeric, q=min(4, numeric.nunique()), duplicates="drop").astype(str).replace("nan", "Unknown")
        except ValueError:
            return grouped_sensitive_feature(series, column_name, policy=policy, grouping_overrides=grouping_overrides)
    values = series.fillna("Unknown").astype(str)
    if values.nunique(dropna=True) > 12:
        top_values = set(values.value_counts().head(10).index.tolist())
        return values.map(lambda value: value if value in top_values else "Other")
    return values


def build_intersectional_analysis(
    X_eval: pd.DataFrame,
    y_true: pd.Series,
    y_pred: pd.Series,
    protected_attributes: list[str],
    policy: dict[str, Any],
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    available_attributes = [protected for protected in protected_attributes if protected in X_eval.columns]
    if len(available_attributes) < 2:
        return {
            "available": False,
            "reason": "Select at least two protected attributes for intersectional analysis.",
            "groups": [],
        }

    grouped_parts = [
        grouped_sensitive_feature(X_eval[protected], protected, policy=policy, grouping_overrides=grouping_overrides).astype(str)
        for protected in available_attributes
    ]
    intersection = pd.concat(grouped_parts, axis=1)
    intersection.columns = available_attributes
    intersection_key = intersection.apply(
        lambda row: " | ".join(f"{column}={row[column]}" for column in available_attributes),
        axis=1,
    )
    groups = group_prediction_table(y_true, np.asarray(y_pred), intersection_key, policy)
    for group in groups:
        group["small_group_warning"] = group["count"] < 20
    groups.sort(key=lambda item: (item["selection_rate"], -item["count"]))
    return {
        "available": True,
        "protected_attributes": available_attributes,
        "minimum_recommended_group_size": 20,
        "groups": groups[:10],
        "worst_group": groups[0] if groups else None,
    }


def simulate_feature_drop(
    df: pd.DataFrame,
    protected_attributes: list[str],
    outcome_column: str,
    model_type: str,
    proxy_flags: list[dict[str, Any]],
    model_params: dict[str, Any] | None = None,
    policy: dict[str, Any] | None = None,
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    policy = policy or load_policy(DEFAULT_POLICY_ID)
    drop_features = sorted(
        {
            *protected_attributes,
            *(item["feature"] for item in proxy_flags),
        }
        & set(df.columns)
    )
    if not drop_features:
        return {
            "available": False,
            "reason": "No protected or proxy features were available to remove for a quick mitigation simulation.",
        }

    X = df.drop(columns=[outcome_column, *drop_features], errors="ignore")
    y = df[outcome_column].astype(int)
    if X.empty:
        return {
            "available": False,
            "reason": "Removing protected and proxy features leaves no model features to train on.",
            "dropped_features": drop_features,
        }

    try:
        stratify = y if y.value_counts().min() >= 2 else None
        X_train, X_test, y_train, y_test = train_test_split(
            X,
            y,
            test_size=0.2,
            random_state=42,
            stratify=stratify,
        )
        pipeline = build_model_pipeline(X, model_type, model_params=model_params)
        pipeline.fit(X_train, y_train)
        y_pred, _ = normalize_prediction_output(pipeline.predict(X_test))
        y_pred.index = X_test.index
        metric_rows = []
        for protected in protected_attributes:
            sensitive = grouped_sensitive_feature(
                df.loc[X_test.index, protected],
                protected,
                policy=policy,
                grouping_overrides=grouping_overrides,
            )
            dp = safe_metric(
                lambda: demographic_parity_difference(y_test, y_pred, sensitive_features=sensitive),
                default=0.0,
            )
            eo = safe_metric(
                lambda: equalized_odds_difference(y_test, y_pred, sensitive_features=sensitive),
                default=0.0,
            )
            metric_rows.append(
                {
                    "protected_attribute": protected,
                    "demographic_parity_difference": round(float(dp), 4),
                    "equalized_odds_difference": round(float(eo), 4),
                }
            )
        return {
            "available": True,
            "strategy": "Retrain after dropping protected attributes and proxy-risk features",
            "dropped_features": drop_features,
            "accuracy": round(float(accuracy_score(y_test, y_pred)), 4),
            "max_demographic_parity_difference": max(
                (item["demographic_parity_difference"] for item in metric_rows),
                default=0.0,
            ),
            "max_equalized_odds_difference": max(
                (item["equalized_odds_difference"] for item in metric_rows),
                default=0.0,
            ),
            "metrics": metric_rows,
            "note": "This is a quick diagnostic simulation, not a replacement for model governance or production retraining.",
        }
    except Exception as exc:
        return {
            "available": False,
            "reason": f"Simulation failed: {exc}",
            "dropped_features": drop_features,
        }


def predict_with_uploaded_model(model: Any, X: pd.DataFrame) -> tuple[Any, pd.DataFrame, dict[str, Any]]:
    errors: list[str] = []
    expected_features = get_model_expected_features(model)
    candidates: list[tuple[str, pd.DataFrame, str]] = []

    if expected_features:
        missing = [feature for feature in expected_features if feature not in X.columns]
        if missing:
            errors.append(f"expected_columns: missing {', '.join(missing[:10])}")
        else:
            candidates.append(
                (
                    "expected_columns",
                    X[expected_features],
                    f"Used model-declared feature columns: {', '.join(expected_features[:12])}.",
                )
            )

    candidates.append(("raw_dataframe", X, "Passed the cleaned raw DataFrame to model.predict(...)."))
    numeric_coded = numeric_code_dataframe(X)
    candidates.append(("numeric_coded_dataframe", numeric_coded, "Converted categorical columns to stable numeric category codes."))

    numeric_only = pd.DataFrame(
        {
            column: numeric
            for column in X.columns
            for numeric, is_numeric in [coerce_numeric_if_reasonable(X[column])]
            if is_numeric
        },
        index=X.index,
    )
    expected_count = getattr(model, "n_features_in_", None)
    if expected_count is not None and not numeric_only.empty and int(expected_count) == numeric_only.shape[1]:
        candidates.append(("numeric_only_dataframe", numeric_only, "Used only numeric columns to match model.n_features_in_."))

    for strategy, candidate, details in candidates:
        try:
            predictions = model.predict(candidate)
            if len(predictions) != len(X):
                errors.append(f"{strategy}: returned {len(predictions)} predictions for {len(X)} rows")
                continue
            return predictions, candidate, {
                "strategy": strategy,
                "details": details,
                "features_used": list(candidate.columns),
                "warnings": [
                    "Pickle/joblib model loading can execute code. Only upload models from trusted sources.",
                ],
            }
        except Exception as exc:
            errors.append(f"{strategy}: {exc}")

    raise AuditError(
        "Uploaded model could not generate predictions for this CSV. "
        "Use a sklearn Pipeline that includes preprocessing, or upload a CSV with columns matching the model's training features. "
        f"Attempts: {' | '.join(errors[-4:])}"
    )


def get_model_expected_features(model: Any) -> list[str]:
    features = getattr(model, "feature_names_in_", None)
    if features is not None:
        return [str(item) for item in list(features)]
    if isinstance(model, Pipeline):
        for _, step in model.steps:
            features = getattr(step, "feature_names_in_", None)
            if features is not None:
                return [str(item) for item in list(features)]
    return []


def numeric_code_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    encoded = pd.DataFrame(index=df.index)
    for column in df.columns:
        numeric, is_numeric = coerce_numeric_if_reasonable(df[column])
        if is_numeric:
            encoded[column] = numeric.fillna(numeric.median() if not pd.isna(numeric.median()) else 0)
        else:
            encoded[column] = pd.Categorical(df[column].fillna("Unknown").astype(str)).codes
    return encoded


def normalize_prediction_output(raw_predictions: Any) -> tuple[pd.Series, dict[str, Any]]:
    array = np.asarray(raw_predictions)
    if array.ndim > 1:
        if array.shape[1] == 1:
            array = array.ravel()
        else:
            raise AuditError("Model predictions must be a one-dimensional binary 0/1 field, not a probability matrix.")

    series = pd.Series(array)
    validation = {
        "status": "Pass",
        "unique_values": [str(value) for value in sorted(series.dropna().unique().tolist(), key=str)],
        "mapping": {},
        "warnings": [],
    }
    if series.isna().any():
        raise AuditError("Model predictions contain missing values.")

    numeric = pd.to_numeric(series, errors="coerce")
    if numeric.notna().sum() == len(series):
        unique_values = sorted(numeric.unique().tolist())
        if set(unique_values).issubset({0, 1, 0.0, 1.0}):
            return numeric.astype(int), validation | {"mapping": {"0": 0, "1": 1}}
        if len(unique_values) == 2:
            validation["warnings"].append(
                f"Predictions used numeric labels {unique_values}; the auditor mapped them to 0/1 for analysis."
            )
            mapping = {float(unique_values[0]): 0, float(unique_values[1]): 1}
            validation["mapping"] = {str(key): value for key, value in mapping.items()}
            return numeric.map(mapping).astype(int), validation
        raise AuditError("Model predictions must be binary. Received non-binary numeric predictions.")

    normalized = series.map(lambda value: str(value).strip().lower())
    mapped = normalized.map(label_to_binary)
    if mapped.notna().sum() == len(series) and set(mapped.unique()).issubset({0, 1}):
        validation["mapping"] = {
            str(label): int(label_to_binary(str(label).strip().lower()))
            for label in sorted(series.astype(str).str.strip().unique())
        }
        return mapped.astype(int), validation

    categories = sorted(normalized.unique().tolist())
    if len(categories) == 2:
        validation["warnings"].append(
            f"Predictions used two text labels {categories}; the auditor mapped them alphabetically to 0/1."
        )
        mapping = {categories[0]: 0, categories[1]: 1}
        validation["mapping"] = mapping
        return normalized.map(mapping).astype(int), validation

    raise AuditError("Model predictions must be binary 0/1 or recognizable binary labels.")


def generic_model_feature_importance(model: Any, input_frame: pd.DataFrame) -> list[dict[str, Any]]:
    if isinstance(model, Pipeline):
        try:
            return model_feature_importance(model, input_frame)
        except Exception:
            pass
        estimator = model.steps[-1][1]
    else:
        estimator = model

    if hasattr(estimator, "coef_"):
        raw_importances = np.abs(np.asarray(estimator.coef_))
        if raw_importances.ndim > 1:
            raw_importances = raw_importances.mean(axis=0)
    elif hasattr(estimator, "feature_importances_"):
        raw_importances = np.asarray(estimator.feature_importances_)
    else:
        return []

    if len(raw_importances) != len(input_frame.columns):
        return []

    max_score = float(np.max(raw_importances)) if len(raw_importances) else 0.0
    rows = []
    for rank, (feature, score) in enumerate(
        sorted(zip(input_frame.columns, raw_importances, strict=False), key=lambda item: item[1], reverse=True),
        start=1,
    ):
        rows.append(
            {
                "rank": rank,
                "feature": str(feature),
                "importance": round(float(score), 6),
                "normalized_importance": round(safe_ratio(float(score), max_score, default=0.0), 4),
            }
        )
    return rows


def build_model_pipeline(X: pd.DataFrame, model_type: str, model_params: dict[str, Any] | None = None) -> Pipeline:
    numeric_features = [column for column in X.columns if coerce_numeric_if_reasonable(X[column])[1]]
    categorical_features = [column for column in X.columns if column not in numeric_features]

    transformers = []
    if numeric_features:
        transformers.append(("num", StandardScaler(), numeric_features))
    if categorical_features:
        transformers.append(("cat", OneHotEncoder(handle_unknown="ignore", sparse_output=False), categorical_features))

    preprocessor = ColumnTransformer(transformers=transformers, remainder="drop", verbose_feature_names_out=True)
    if model_type == "decision_tree":
        estimator = DecisionTreeClassifier(max_depth=5, min_samples_leaf=10, random_state=42)
    elif model_type == "random_forest":
        estimator = RandomForestClassifier(
            n_estimators=80,
            max_depth=8,
            min_samples_leaf=5,
            random_state=42,
            n_jobs=-1,
        )
    elif model_type == "extra_trees":
        estimator = ExtraTreesClassifier(
            n_estimators=100,
            max_depth=8,
            min_samples_leaf=5,
            random_state=42,
            n_jobs=-1,
        )
    elif model_type == "gradient_boosting":
        estimator = GradientBoostingClassifier(random_state=42)
    elif model_type == "ada_boost":
        estimator = AdaBoostClassifier(random_state=42)
    elif model_type == "linear_svm":
        estimator = LinearSVC(max_iter=5000, random_state=42)
    elif model_type == "knn":
        estimator = KNeighborsClassifier(n_neighbors=15)
    elif model_type == "gaussian_nb":
        estimator = GaussianNB()
    else:
        estimator = LogisticRegression(max_iter=2000, random_state=42)

    pipeline = Pipeline([("preprocess", preprocessor), ("model", estimator)])
    if model_params:
        pipeline.set_params(**{f"model__{key}": value for key, value in model_params.items()})
    return pipeline


def group_prediction_table(
    y_true: pd.Series,
    y_pred: np.ndarray,
    sensitive: pd.Series,
    policy: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    policy = policy or load_policy(DEFAULT_POLICY_ID)
    frame = pd.DataFrame({"y_true": np.asarray(y_true), "y_pred": np.asarray(y_pred), "group": sensitive.astype(str).values})
    rows = []
    for group, group_df in frame.groupby("group"):
        positives = int(group_df["y_pred"].sum())
        selection = float(group_df["y_pred"].mean()) if len(group_df) else 0.0
        rows.append(
            {
                "group": str(group),
                "count": int(len(group_df)),
                "positive_predictions": positives,
                "selection_rate": round(selection, 4),
                "accuracy": round(float(accuracy_score(group_df["y_true"], group_df["y_pred"])), 4)
                if len(group_df)
                else 0.0,
            }
        )

    rows.sort(key=lambda item: item["selection_rate"], reverse=True)
    max_rate = max((item["selection_rate"] for item in rows), default=0.0)
    for item in rows:
        item["ratio_to_highest"] = round(safe_ratio(item["selection_rate"], max_rate, default=1.0), 4)
        item["status"] = ratio_status(item["ratio_to_highest"], policy, "representation_ratio")
    return rows


def model_feature_importance(pipeline: Pipeline, X: pd.DataFrame) -> list[dict[str, Any]]:
    preprocessor: ColumnTransformer = pipeline.named_steps["preprocess"]
    estimator = pipeline.named_steps["model"]
    transformed_names = preprocessor.get_feature_names_out()

    if hasattr(estimator, "coef_"):
        raw_importances = np.abs(estimator.coef_[0])
    elif hasattr(estimator, "feature_importances_"):
        raw_importances = estimator.feature_importances_
    else:
        return []

    original_scores = {column: 0.0 for column in X.columns}
    categorical_features = [
        column
        for name, _, columns in preprocessor.transformers_
        if name == "cat"
        for column in list(columns)
    ]

    for transformed_name, importance in zip(transformed_names, raw_importances, strict=False):
        original = transformed_to_original_feature(transformed_name, X.columns.tolist(), categorical_features)
        original_scores[original] = original_scores.get(original, 0.0) + float(importance)

    max_score = max(original_scores.values(), default=0.0)
    rows = []
    for rank, (feature, score) in enumerate(
        sorted(original_scores.items(), key=lambda item: item[1], reverse=True),
        start=1,
    ):
        rows.append(
            {
                "rank": rank,
                "feature": feature,
                "importance": round(float(score), 6),
                "normalized_importance": round(safe_ratio(score, max_score, default=0.0), 4),
            }
        )
    return rows


def transformed_to_original_feature(transformed_name: str, original_columns: list[str], categorical_features: list[str]) -> str:
    name = transformed_name.split("__", 1)[-1]
    if name in original_columns:
        return name
    matches = [column for column in categorical_features if name == column or name.startswith(f"{column}_")]
    if matches:
        return max(matches, key=len)
    return name


def grouped_sensitive_feature(
    series: pd.Series,
    column_name: str,
    policy: dict[str, Any] | None = None,
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
) -> pd.Series:
    policy = policy or load_policy(DEFAULT_POLICY_ID)
    return group_series(series, column_name, policy, grouping_overrides)


def coerce_numeric_if_reasonable(series: pd.Series) -> tuple[pd.Series, bool]:
    if pd.api.types.is_numeric_dtype(series):
        return pd.to_numeric(series, errors="coerce"), True
    numeric = pd.to_numeric(series, errors="coerce")
    non_missing = series.notna().sum()
    if non_missing == 0:
        return numeric, False
    return numeric, bool(numeric.notna().sum() / non_missing >= 0.9)


def association_strength(left: pd.Series, right: pd.Series) -> tuple[float, str]:
    left_num, left_is_numeric = coerce_numeric_if_reasonable(left)
    right_num, right_is_numeric = coerce_numeric_if_reasonable(right)

    if left.nunique(dropna=True) <= 1 or right.nunique(dropna=True) <= 1:
        return 0.0, "constant"

    if left_is_numeric and right_is_numeric:
        valid = pd.DataFrame({"left": left_num, "right": right_num}).dropna()
        if len(valid) < 3 or valid["left"].nunique() <= 1 or valid["right"].nunique() <= 1:
            return 0.0, "pearson"
        coefficient, _ = stats.pearsonr(valid["left"], valid["right"])
        return abs(float(coefficient)) if not pd.isna(coefficient) else 0.0, "pearson"

    if left_is_numeric != right_is_numeric:
        numeric = left_num if left_is_numeric else right_num
        categories = right if left_is_numeric else left
        return correlation_ratio(categories.astype(str), numeric), "correlation_ratio"

    return cramers_v(left.astype(str), right.astype(str)), "cramers_v"


def correlation_ratio(categories: pd.Series, values: pd.Series) -> float:
    frame = pd.DataFrame({"category": categories, "value": values}).dropna()
    if frame.empty:
        return 0.0
    grand_mean = frame["value"].mean()
    numerator = 0.0
    denominator = ((frame["value"] - grand_mean) ** 2).sum()
    if denominator == 0:
        return 0.0
    for _, group in frame.groupby("category"):
        numerator += len(group) * (group["value"].mean() - grand_mean) ** 2
    return float(math.sqrt(numerator / denominator))


def cramers_v(left: pd.Series, right: pd.Series) -> float:
    table = pd.crosstab(left, right)
    if table.empty or min(table.shape) < 2:
        return 0.0
    chi2 = stats.chi2_contingency(table, correction=False)[0]
    n = table.to_numpy().sum()
    if n == 0:
        return 0.0
    phi2 = chi2 / n
    r, k = table.shape
    denominator = min(k - 1, r - 1)
    if denominator <= 0:
        return 0.0
    return float(math.sqrt(phi2 / denominator))


def calculate_severity(
    dp_score: float,
    eo_score: float,
    proxy_count: int,
    representation_ratio: float,
    policy: dict[str, Any] | None = None,
) -> str:
    policy = policy or load_policy(DEFAULT_POLICY_ID)
    proxy_thresholds = policy["fairness_thresholds"]["proxy_variable_strength"]
    proxy_strength = proxy_thresholds["warning_above"] + (
        min(proxy_count, 3) / 3 * (proxy_thresholds["critical_above"] - proxy_thresholds["warning_above"])
    )
    governance = build_governance_assessment(
        {
            "proxy_flags": [{"strength": proxy_strength}] * proxy_count,
            "representation": [{"minimum_representation_ratio": representation_ratio, "groups": []}],
        },
        {
            "bias_metrics": [
                {
                    "demographic_parity_difference": dp_score,
                    "equalized_odds_difference": eo_score,
                    "disparate_impact_ratio": representation_ratio,
                }
            ],
            "conditional_fairness": {"results": []},
        },
        policy,
    )
    return governance["severity"]


def calculate_pre_audit_severity(
    proxy_count: int,
    representation_ratio: float,
    policy: dict[str, Any] | None = None,
) -> str:
    policy = policy or load_policy(DEFAULT_POLICY_ID)
    return calculate_severity(0.0, 0.0, proxy_count, representation_ratio, policy=policy)


def build_traceability_metadata(
    df: pd.DataFrame,
    protected_attributes: list[str],
    outcome_column: str,
    audit_mode: str,
    model_results: dict[str, Any],
    policy: dict[str, Any],
    template_id: str,
    control_features: list[str] | None = None,
    grouping_overrides: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    model_identity = {
        "model_type": model_results.get("model_type"),
        "selected_model_key": model_results.get("selected_model_key"),
        "requested_model_type": model_results.get("requested_model_type"),
        "mode": model_results.get("mode"),
        "tuning": model_results.get("tuning", {}),
        "model_input": model_results.get("model_input", {}),
    }
    return {
        "run_id": uuid4().hex,
        "created_at_utc": datetime.now(UTC).isoformat(),
        "auditor_version": "0.2.0",
        "audit_mode": AUDIT_MODE_LABELS.get(audit_mode, audit_mode),
        "dataset_hash_sha256": dataset_hash(df),
        "dataset_rows": int(len(df)),
        "dataset_columns": int(len(df.columns)),
        "outcome_column": outcome_column,
        "protected_attributes": protected_attributes,
        "model_fingerprint_sha256": stable_hash(model_identity),
        "model_identity": model_identity,
        "policy": {
            "policy_id": policy["policy_id"],
            "policy_version": policy["version"],
            "policy_name": policy["name"],
            "severity_weights": policy.get("severity_weights", {}),
            "fairness_thresholds": policy.get("fairness_thresholds", {}),
            "deployment_decision_thresholds": policy.get("deployment_decision_thresholds", {}),
            "grouping_rules": policy.get("grouping_rules", {}),
            "model_selection": policy.get("model_selection", {}),
            "report_template": template_id,
            "requested_control_features": control_features or [],
            "grouping_overrides": grouping_overrides or {},
        },
    }


def dataset_hash(df: pd.DataFrame) -> str:
    csv_bytes = df.sort_index(axis=1).to_csv(index=False).encode("utf-8")
    return sha256(csv_bytes).hexdigest()


def stable_hash(value: Any) -> str:
    return sha256(str(json_safe(value)).encode("utf-8")).hexdigest()


def generate_explanation_report(summary: dict[str, Any], template_id: str = "full_report") -> dict[str, Any]:
    prompt = build_report_prompt(summary)
    sections = build_local_report_sections(summary, template_id)
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if api_key:
        try:
            import google.generativeai as genai

            genai.configure(api_key=api_key)
            model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
            model = genai.GenerativeModel(model_name)
            response = model.generate_content(prompt)
            text = response.text.strip()
            if text:
                sections[1]["content"] = text
                return {
                    "source": f"Gemini ({model_name})",
                    "template_id": template_id,
                    "template_title": report_template(template_id)["title"],
                    "sections": sections,
                    "text": flatten_report_sections(sections),
                    "limitations": summary["model"].get("limitations", []),
                }
        except Exception as exc:
            return {
                "source": "Local deterministic report (Gemini unavailable)",
                "template_id": template_id,
                "template_title": report_template(template_id)["title"],
                "sections": sections,
                "text": flatten_report_sections(sections) + f"\n\nGemini enhancement was unavailable: {exc}",
                "limitations": summary["model"].get("limitations", []),
            }
    return {
        "source": "Local deterministic report",
        "template_id": template_id,
        "template_title": report_template(template_id)["title"],
        "sections": sections,
        "text": flatten_report_sections(sections),
        "limitations": summary["model"].get("limitations", []),
    }


def build_report_prompt(summary: dict[str, Any]) -> str:
    compact = {
        "dataset": summary["dataset"],
        "representation": summary["pre_audit"]["representation"],
        "data_validation": summary["pre_audit"].get("validation", {}),
        "pre_audit_severity": summary.get("pre_audit_severity"),
        "proxy_flags": summary["pre_audit"]["proxy_flags"][:10],
        "model_performance": summary["model"]["performance"],
        "selected_model": summary["model"].get("model_type"),
        "hyperparameter_tuning": summary["model"].get("tuning", {}),
        "model_comparison": summary["model"].get("model_comparison", [])[:10],
        "conditional_fairness": summary["model"].get("conditional_fairness", {}),
        "intersectional_bias": summary["model"].get("intersectional_bias", {}),
        "audit_trace": summary["model"].get("audit_trace", {}),
        "traceability": summary.get("traceability", {}),
        "prediction_validation": summary["model"].get("prediction_validation", {}),
        "bias_metrics": summary["model"]["bias_metrics"],
        "bias_sources": summary["model"]["bias_sources"],
        "improvement_simulation": summary["model"].get("improvement_simulation", {}),
        "severity": summary["severity"],
        "governance": summary.get("governance", {}),
        "limitations": summary["model"].get("limitations", []),
    }
    return textwrap.dedent(
        f"""
        You are an AI ethics expert. Based on this bias audit, provide a clear, structured advisory summary with these headings:
        1. An executive summary of what bias was found and how serious it is.
        2. A deployment recommendation: Safe to deploy / Needs review / Do not deploy, with reasons.
        3. Why the bias may be happening, based on proxy variables, feature importance, and group outcomes.
        4. Three specific, actionable recommendations to reduce the bias.
        5. A short mitigation simulation interpretation if simulation data is present.
        6. A limitations paragraph that prevents overclaiming.

        Write for a non-technical manager, not a data scientist.
        Avoid claiming the model has been fixed. Recommendations should be concrete, cautious, and implementation-ready.
        State that this LLM summary is advisory, cannot certify model safety, and is not proof of legal compliance or causal discrimination.

        Audit data:
        {compact}
        """
    ).strip()


def build_local_report(summary: dict[str, Any], template_id: str = "full_report") -> str:
    return flatten_report_sections(build_local_report_sections(summary, template_id))


def build_local_report_sections(summary: dict[str, Any], template_id: str = "full_report") -> list[dict[str, str]]:
    severity = summary["severity"]
    dataset = summary["dataset"]
    bias_metrics = summary["model"]["bias_metrics"]
    proxy_count = len(summary["pre_audit"]["proxy_flags"])
    bias_sources = summary["model"]["bias_sources"]
    conditional = summary["model"].get("conditional_fairness", {})
    intersectional = summary["model"].get("intersectional_bias", {})
    audit_trace = summary["model"].get("audit_trace", {})
    governance = summary.get("governance", {})
    report_mode = report_template(template_id)

    concerning = [item for item in bias_metrics if item["status"] in {"High", "Critical"}]
    if concerning:
        affected = ", ".join(item["protected_attribute"] for item in concerning)
        first_line = f"The audit found {severity.lower()} bias risk, mainly around {affected}."
    else:
        first_line = f"The audit found {severity.lower()} bias risk for the selected protected attributes."

    source_line = "No high-importance proxy source was found in the top features."
    if bias_sources:
        sources = ", ".join(f"{item['feature']} (rank {item['rank']})" for item in bias_sources[:3])
        source_line = f"Likely bias sources include {sources}, because these features are influential and correlated with protected attributes."

    recommendations = [
        "Review the flagged proxy variables before using this model in a real decision workflow.",
        "Compare approval or positive prediction rates by protected group after any feature changes.",
        "Review the row-level audit trace for false negatives and negative decisions before relying on the model operationally.",
        "Collect more balanced data or add review safeguards for groups with low representation ratios.",
    ]

    conditional_line = "Conditional same-background analysis was unavailable for this dataset."
    if conditional.get("available"):
        worst = max(conditional["results"], key=lambda item: item.get("weighted_selection_gap", 0.0), default=None)
        if worst:
            conditional_line = (
                f"Same-background cohort analysis controlled for {', '.join(conditional.get('control_features', []))} "
                f"and found the largest weighted selection gap for `{worst['protected_attribute']}` at {worst['weighted_selection_gap']}."
            )

    intersection_line = "Intersectional analysis was not available because fewer than two protected attributes were selected."
    if intersectional.get("available") and intersectional.get("worst_group"):
        worst_group = intersectional["worst_group"]
        intersection_line = (
            f"The lowest-selection intersectional group was {worst_group['group']} "
            f"with selection rate {worst_group['selection_rate']} across {worst_group['count']} records."
        )

    trace_line = "No row-level audit trace records were generated."
    if audit_trace.get("records"):
        first_record = audit_trace["records"][0]
        relied_on = ", ".join(first_record.get("model_relied_on", [])[:3])
        trace_line = (
            f"The audit trace captured {len(audit_trace['records'])} risky decisions. "
            f"Row {first_record['row_id']} was flagged as {first_record['risk_reason']}; the largest local contributors were {relied_on}."
        )

    scope_text = (
        "Supported scope: tabular binary classification, uploaded prediction outputs, and sklearn-compatible local models. "
        "Not yet supported: regression, ranking systems, multiclass fairness, LLM audits, or image-model audits."
    )
    policy_text = (
        f"Policy applied: {summary['traceability']['policy']['policy_name']} "
        f"({summary['traceability']['policy']['policy_id']} v{summary['traceability']['policy']['policy_version']}). "
        f"Deployment recommendation: {governance.get('deployment_decision', 'Needs review')} "
        f"with risk score {governance.get('risk_score', 'n/a')}."
    )
    driver_lines = governance.get("top_risk_drivers", []) or ["No major weighted risk drivers were detected."]
    limitations_text = "\n".join(f"- {item}" for item in summary["model"].get("limitations", []))

    sections = [
        {"title": "Template", "content": f"Report template: {report_mode['title']}. {report_mode['description']}"},
        {"title": "Executive Summary", "content": first_line},
        {"title": "Deployment Recommendation", "content": policy_text},
        {
            "title": "Key Findings",
            "content": "\n".join(
                [
                    f"The selected model was {summary['model'].get('model_type')} for `{dataset['outcome_column']}` using {dataset['rows']} cleaned rows.",
                    f"{proxy_count} proxy-risk feature links were detected.",
                    source_line,
                    conditional_line,
                    intersection_line,
                    trace_line,
                ]
            ),
        },
        {"title": "Top Risk Drivers", "content": "\n".join(f"{index}. {item}" for index, item in enumerate(driver_lines, start=1))},
        {
            "title": "Recommended Actions",
            "content": "\n".join(f"{index}. {item}" for index, item in enumerate(recommendations, start=1)),
        },
        {"title": "Supported Scope", "content": scope_text},
        {"title": "Limitations", "content": limitations_text},
    ]

    if template_id == "executive_summary":
        return sections[:4] + [sections[4], sections[7]]
    if template_id == "technical_audit":
        return [sections[1], sections[2], sections[3], sections[4], sections[7]]
    if template_id == "compliance_review":
        return [sections[0], sections[2], sections[4], sections[5], sections[7]]
    if template_id == "model_card":
        return [
            {"title": "Model Card", "content": f"Model: {summary['model'].get('model_type')}\nOutcome: {dataset['outcome_column']}\nRows audited: {dataset['rows']}"},
            sections[2],
            sections[3],
            sections[6],
            sections[7],
        ]
    return sections


def flatten_report_sections(sections: list[dict[str, str]]) -> str:
    return "\n\n".join(f"{section['title']}\n{section['content']}".strip() for section in sections)


def build_limitations(mode: str, feature_importance: list[dict[str, Any]]) -> list[str]:
    limitations = [
        "This auditor currently targets tabular binary classification workflows only.",
        "Fairness metrics quantify correlations in outcomes and errors; they do not prove causality or legal compliance by themselves.",
        "Gemini or other LLM-written summaries are advisory and cannot certify model safety.",
        "Small protected groups can make fairness estimates unstable.",
    ]
    if not feature_importance:
        limitations.append("This run did not have reliable model-internal feature importance, so root-cause analysis is limited.")
    if mode == "uploaded_model":
        limitations.append("Uploaded-model mode depends on the artifact's predict(...) behavior and does not guarantee preprocessing parity with the original training environment.")
    if mode == "prediction_csv":
        limitations.append("Prediction-only mode cannot inspect model internals, feature contributions, or mitigation simulations.")
    return limitations


def safe_metric(func: Any, default: float) -> float:
    try:
        value = func()
        return float(value) if not pd.isna(value) else default
    except Exception:
        return default


def safe_ratio(numerator: float, denominator: float, default: float = 0.0) -> float:
    if denominator == 0:
        return default
    return float(numerator) / float(denominator)


def status_from_threshold(value: float, *, warning: float, danger: float, higher_is_better: bool) -> str:
    if higher_is_better:
        if value < danger:
            return "Red"
        if value < warning:
            return "Yellow"
        return "Green"
    if value > danger:
        return "Red"
    if value > warning:
        return "Yellow"
    return "Green"


def bias_status(score: float) -> str:
    if score > 0.3:
        return "Critical"
    if score > 0.2:
        return "High"
    if score > 0.1:
        return "Medium"
    return "Low"


def json_safe(value: Any) -> Any:
    if isinstance(value, dict):
        return {str(key): json_safe(item) for key, item in value.items()}
    if isinstance(value, list):
        return [json_safe(item) for item in value]
    if isinstance(value, tuple):
        return [json_safe(item) for item in value]
    if isinstance(value, (np.integer,)):
        return int(value)
    if isinstance(value, (np.floating,)):
        return float(value)
    if isinstance(value, np.ndarray):
        return value.tolist()
    if pd.isna(value) if not isinstance(value, (list, dict, tuple, str, bytes)) else False:
        return None
    return value
