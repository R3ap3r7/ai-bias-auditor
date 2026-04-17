from __future__ import annotations

import math
import os
import textwrap
from dataclasses import dataclass
from typing import Any

import numpy as np
import pandas as pd
from scipy import stats
from sklearn.compose import ColumnTransformer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, precision_score, recall_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.tree import DecisionTreeClassifier

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
    "logistic_regression": "Logistic Regression",
    "decision_tree": "Decision Tree",
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
) -> dict[str, Any]:
    if not protected_attributes:
        raise AuditError("Select at least one protected attribute.")
    if outcome_column in protected_attributes:
        raise AuditError("The outcome column cannot also be marked as protected.")
    if model_type not in MODEL_LABELS:
        raise AuditError("Unsupported model type.")

    cleaned = clean_dataframe(df, outcome_column, protected_attributes)
    clean_df = cleaned.dataframe

    pre_audit = run_pre_model_audit(clean_df, protected_attributes, outcome_column)
    model_results = train_and_audit_model(clean_df, protected_attributes, outcome_column, model_type, pre_audit["proxy_flags"])

    max_dp = max((item["demographic_parity_difference"] for item in model_results["bias_metrics"]), default=0.0)
    max_eo = max((item["equalized_odds_difference"] for item in model_results["bias_metrics"]), default=0.0)
    min_representation_ratio = min(
        (item["minimum_representation_ratio"] for item in pre_audit["representation"]),
        default=1.0,
    )
    severity = calculate_severity(max_dp, max_eo, len(pre_audit["proxy_flags"]), min_representation_ratio)

    summary = {
        "dataset": {
            "rows": int(len(clean_df)),
            "columns": int(len(clean_df.columns)),
            "outcome_column": outcome_column,
            "protected_attributes": protected_attributes,
            "model_type": MODEL_LABELS[model_type],
        },
        "cleaning": cleaned.cleaning_log,
        "pre_audit": pre_audit,
        "model": model_results,
        "severity": severity,
        "report": {},
    }
    summary["report"] = generate_explanation_report(summary)
    return json_safe(summary)


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
) -> dict[str, Any]:
    representation = []
    for protected in protected_attributes:
        grouped = grouped_sensitive_feature(df[protected], protected)
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
                    "status": status_from_threshold(ratio_to_best, warning=0.8, danger=0.5, higher_is_better=True),
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

    proxy_flags = detect_proxy_variables(df, protected_attributes, outcome_column)
    return {"representation": representation, "proxy_flags": proxy_flags}


def detect_proxy_variables(df: pd.DataFrame, protected_attributes: list[str], outcome_column: str) -> list[dict[str, Any]]:
    protected_set = set(protected_attributes)
    proxy_flags: list[dict[str, Any]] = []

    for feature in df.columns:
        if feature == outcome_column or feature in protected_set:
            continue
        for protected in protected_attributes:
            strength, method = association_strength(df[feature], df[protected])
            if strength >= 0.5:
                proxy_flags.append(
                    {
                        "feature": feature,
                        "protected_attribute": protected,
                        "strength": round(float(strength), 4),
                        "method": method,
                        "risk": "High" if strength >= 0.7 else "Medium",
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

    pipeline = build_model_pipeline(X, model_type)
    pipeline.fit(X_train, y_train)
    y_pred = pipeline.predict(X_test)

    performance = {
        "training_samples": int(len(X_train)),
        "test_samples": int(len(X_test)),
        "accuracy": round(float(accuracy_score(y_test, y_pred)), 4),
        "precision": round(float(precision_score(y_test, y_pred, zero_division=0)), 4),
        "recall": round(float(recall_score(y_test, y_pred, zero_division=0)), 4),
    }

    bias_metrics = []
    for protected in protected_attributes:
        sensitive = grouped_sensitive_feature(X_test[protected], protected)
        dp = safe_metric(
            lambda: demographic_parity_difference(y_test, y_pred, sensitive_features=sensitive),
            default=0.0,
        )
        eo = safe_metric(
            lambda: equalized_odds_difference(y_test, y_pred, sensitive_features=sensitive),
            default=0.0,
        )

        group_table = group_prediction_table(y_test, y_pred, sensitive)
        bias_metrics.append(
            {
                "protected_attribute": protected,
                "demographic_parity_difference": round(float(dp), 4),
                "equalized_odds_difference": round(float(eo), 4),
                "status": bias_status(max(float(dp), float(eo))),
                "groups": group_table,
                "disparate_impact_ratio": round(
                    min((group["selection_rate"] for group in group_table), default=0.0)
                    / max((group["selection_rate"] for group in group_table), default=1.0),
                    4,
                )
                if group_table and max((group["selection_rate"] for group in group_table), default=0.0) > 0
                else 0.0,
            }
        )

    feature_importance = model_feature_importance(pipeline, X)
    proxy_lookup = {(item["feature"], item["protected_attribute"]): item for item in proxy_flags}
    flagged_features = {item["feature"] for item in proxy_flags}
    bias_sources = []
    for row in feature_importance[:10]:
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

    return {
        "performance": performance,
        "bias_metrics": bias_metrics,
        "feature_importance": feature_importance[:10],
        "bias_sources": bias_sources,
    }


def build_model_pipeline(X: pd.DataFrame, model_type: str) -> Pipeline:
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
    else:
        estimator = LogisticRegression(max_iter=1000, random_state=42)

    return Pipeline([("preprocess", preprocessor), ("model", estimator)])


def group_prediction_table(y_true: pd.Series, y_pred: np.ndarray, sensitive: pd.Series) -> list[dict[str, Any]]:
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
        item["status"] = status_from_threshold(item["ratio_to_highest"], warning=0.8, danger=0.5, higher_is_better=True)
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
        raw_importances = np.zeros(len(transformed_names))

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


def grouped_sensitive_feature(series: pd.Series, column_name: str) -> pd.Series:
    numeric, is_numeric = coerce_numeric_if_reasonable(series)
    if is_numeric and numeric.nunique(dropna=True) > 8:
        lower_name = column_name.lower()
        if "age" in lower_name:
            bins = [-math.inf, 24, 44, 64, math.inf]
            labels = ["Under 25", "25-44", "45-64", "65+"]
            return pd.cut(numeric, bins=bins, labels=labels).astype(str).replace("nan", "Unknown")
        try:
            return pd.qcut(numeric, q=min(4, numeric.nunique()), duplicates="drop").astype(str).replace("nan", "Unknown")
        except ValueError:
            return numeric.fillna(numeric.median()).astype(str)
    return series.fillna("Unknown").astype(str)


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


def calculate_severity(dp_score: float, eo_score: float, proxy_count: int, representation_ratio: float) -> str:
    score = 0
    if dp_score > 0.2:
        score += 3
    elif dp_score > 0.1:
        score += 2
    else:
        score += 1

    if eo_score > 0.2:
        score += 3
    elif eo_score > 0.1:
        score += 2
    else:
        score += 1

    score += min(proxy_count, 3)

    if representation_ratio < 0.5:
        score += 2
    elif representation_ratio < 0.8:
        score += 1

    if score >= 9:
        return "Critical"
    if score >= 6:
        return "High"
    if score >= 4:
        return "Medium"
    return "Low"


def generate_explanation_report(summary: dict[str, Any]) -> dict[str, str]:
    prompt = build_report_prompt(summary)
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if api_key:
        try:
            import google.generativeai as genai

            genai.configure(api_key=api_key)
            model_name = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
            model = genai.GenerativeModel(model_name)
            response = model.generate_content(prompt)
            text = response.text.strip()
            if text:
                return {"source": f"Gemini ({model_name})", "text": text}
        except Exception as exc:
            return {
                "source": "Local fallback",
                "text": f"Gemini report generation failed: {exc}\n\n{build_local_report(summary)}",
            }
    return {"source": "Local fallback", "text": build_local_report(summary)}


def build_report_prompt(summary: dict[str, Any]) -> str:
    compact = {
        "dataset": summary["dataset"],
        "representation": summary["pre_audit"]["representation"],
        "proxy_flags": summary["pre_audit"]["proxy_flags"][:10],
        "model_performance": summary["model"]["performance"],
        "bias_metrics": summary["model"]["bias_metrics"],
        "bias_sources": summary["model"]["bias_sources"],
        "severity": summary["severity"],
    }
    return textwrap.dedent(
        f"""
        You are an AI ethics expert. Based on this bias audit, provide:
        1. A plain English summary of what bias was found and how serious it is.
        2. The real-world impact this bias would have on affected groups.
        3. Three specific, actionable recommendations to reduce the bias.
        4. An overall bias severity rating: Low / Medium / High / Critical.

        Write for a non-technical manager, not a data scientist.

        Audit data:
        {compact}
        """
    ).strip()


def build_local_report(summary: dict[str, Any]) -> str:
    severity = summary["severity"]
    dataset = summary["dataset"]
    bias_metrics = summary["model"]["bias_metrics"]
    proxy_count = len(summary["pre_audit"]["proxy_flags"])
    bias_sources = summary["model"]["bias_sources"]

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
        "Collect more balanced data or add review safeguards for groups with low representation ratios.",
    ]

    return "\n\n".join(
        [
            first_line,
            f"The model was trained to predict `{dataset['outcome_column']}` using {dataset['rows']} cleaned rows. {proxy_count} proxy-risk feature links were detected.",
            source_line,
            "Recommended actions:\n" + "\n".join(f"{index}. {item}" for index, item in enumerate(recommendations, start=1)),
            f"Overall severity rating: {severity}.",
        ]
    )


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
