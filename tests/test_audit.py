from __future__ import annotations

from io import BytesIO

import joblib
import pandas as pd
import pytest
from fastapi.testclient import TestClient

import app.main as main_module
from app.audit import AuditError, build_model_pipeline, calculate_severity, normalize_outcome, run_audit
from app.main import app
from app.policies import load_policy
from app.report import build_pdf_report


@pytest.fixture(autouse=True)
def disable_gemini_for_tests(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)


def biased_frame() -> pd.DataFrame:
    rows = []
    for index in range(240):
        race = "Group A" if index < 120 else "Group B"
        gender = "Male" if index % 3 else "Female"
        zip_code = "10001" if race == "Group A" else "20002"
        income = 80000 + index if race == "Group A" else 36000 + index
        education = "Bachelors" if race == "Group A" or index % 5 == 0 else "HighSchool"
        approved = 1 if race == "Group A" or (income > 36180 and education == "Bachelors") else 0
        rows.append(
            {
                "age": 25 + (index % 35),
                "gender": gender,
                "race": race,
                "zip_code": zip_code,
                "income": income,
                "education": education,
                "loan_approved": approved,
            }
        )
    return pd.DataFrame(rows)


def test_normalize_outcome_handles_text_labels() -> None:
    normalized, mapping = normalize_outcome(pd.Series(["approved", "denied", "yes", "no"]))

    assert normalized.tolist() == [1, 0, 1, 0]
    assert mapping["approved"] == 1
    assert mapping["denied"] == 0


def test_run_audit_flags_representation_proxy_and_bias_sources() -> None:
    result = run_audit(
        biased_frame(),
        protected_attributes=["race", "gender"],
        outcome_column="loan_approved",
        model_type="logistic_regression",
    )

    proxy_pairs = {(item["feature"], item["protected_attribute"]) for item in result["pre_audit"]["proxy_flags"]}
    race_representation = next(item for item in result["pre_audit"]["representation"] if item["protected_attribute"] == "race")
    race_metric = next(item for item in result["model"]["bias_metrics"] if item["protected_attribute"] == "race")

    assert result["model"]["performance"]["test_samples"] == 48
    assert race_representation["minimum_representation_ratio"] < 0.8
    assert ("zip_code", "race") in proxy_pairs
    assert race_metric["demographic_parity_difference"] > 0.2
    assert result["severity"] in {"High", "Critical"}
    assert result["report"]["text"]
    assert result["traceability"]["run_id"]
    assert result["traceability"]["dataset_hash_sha256"]
    assert "Set GEMINI_API_KEY" not in result["report"]["text"]


def test_decision_tree_path_and_pdf_generation() -> None:
    result = run_audit(
        biased_frame(),
        protected_attributes=["race"],
        outcome_column="loan_approved",
        model_type="decision_tree",
    )
    pdf = build_pdf_report(result)

    assert result["model"]["feature_importance"]
    assert pdf.startswith(b"%PDF")


def test_compare_all_tunes_and_recommends_a_model() -> None:
    result = run_audit(
        biased_frame(),
        protected_attributes=["race"],
        outcome_column="loan_approved",
        model_type="compare_all",
    )

    comparison = result["model"]["model_comparison"]
    selected = [row for row in comparison if row["selected"]]

    assert len(comparison) >= 5
    assert len(selected) == 1
    assert result["model"]["selected_model_key"] == selected[0]["model_key"]
    assert result["model"]["tuning"]["status"]
    assert selected[0]["audit_selection_score"] is not None
    assert result["model"]["audit_trace"]["records"]
    assert result["model"]["audit_trace"]["records"][0]["top_contributions"]
    assert result["model"]["conditional_fairness"]["results"]
    assert result["model"]["intersectional_bias"]["available"] is False


def test_intersectional_analysis_and_traceability() -> None:
    result = run_audit(
        biased_frame(),
        protected_attributes=["race", "gender"],
        outcome_column="loan_approved",
        model_type="decision_tree",
    )

    intersectional = result["model"]["intersectional_bias"]
    trace_record = result["model"]["audit_trace"]["records"][0]

    assert intersectional["available"] is True
    assert intersectional["groups"]
    assert "race=" in intersectional["groups"][0]["group"]
    assert trace_record["row_id"] is not None
    assert trace_record["model_relied_on"]
    assert result["traceability"]["model_fingerprint_sha256"]


@pytest.mark.parametrize(
    "model_type",
    [
        "logistic_regression",
        "decision_tree",
        "random_forest",
        "extra_trees",
        "gradient_boosting",
        "ada_boost",
        "linear_svm",
        "knn",
        "gaussian_nb",
    ],
)
def test_supported_model_pipelines_fit(model_type: str) -> None:
    df = biased_frame().iloc[80:180]
    X = df.drop(columns=["loan_approved"])
    y = df["loan_approved"]

    pipeline = build_model_pipeline(X, model_type)
    pipeline.fit(X, y)

    assert len(pipeline.predict(X.head(5))) == 5


def test_severity_logic_uses_governance_policy() -> None:
    default_policy = load_policy("default_governance_v1")
    strict_policy = load_policy("medical_triage_strict")

    assert calculate_severity(0.25, 0.21, 3, 0.4, policy=default_policy) in {"High", "Critical"}
    assert calculate_severity(0.11, 0.11, 0, 0.9, policy=default_policy) == "Low"
    assert calculate_severity(0.11, 0.11, 0, 0.9, policy=strict_policy) in {"Medium", "High"}
    assert calculate_severity(0.01, 0.02, 0, 0.95) == "Low"


def test_upload_and_audit_api_flow() -> None:
    client = TestClient(app)
    csv_bytes = biased_frame().to_csv(index=False).encode()

    landing = client.get("/", follow_redirects=False)
    assert landing.status_code in {302, 307}
    assert "localhost:5050" in landing.headers["location"]

    upload = client.post("/api/upload", files={"file": ("biased.csv", BytesIO(csv_bytes), "text/csv")})
    assert upload.status_code == 200
    session_id = upload.json()["session_id"]

    audit = client.post(
        "/api/audit",
        json={
            "session_id": session_id,
            "protected_attributes": ["race"],
            "outcome_column": "loan_approved",
            "model_type": "logistic_regression",
        },
    )

    assert audit.status_code == 200
    body = audit.json()
    assert body["report_id"]
    assert body["severity"] in {"High", "Critical"}


def test_pre_audit_api_flow() -> None:
    client = TestClient(app)
    upload = client.post(
        "/api/upload",
        files={"file": ("biased.csv", BytesIO(biased_frame().to_csv(index=False).encode()), "text/csv")},
    )
    session_id = upload.json()["session_id"]

    response = client.post(
        "/api/pre-audit",
        json={
            "session_id": session_id,
            "protected_attributes": ["race"],
            "outcome_column": "loan_approved",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert "report_id" not in body
    assert body["pre_audit"]["validation"]["checks"]
    assert body["pre_audit_severity"] in {"Low", "Medium", "High"}


def test_uploaded_model_api_flow(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(main_module, "UPLOADED_MODEL_MODE_ENABLED", True)
    client = TestClient(app)
    df = biased_frame()
    upload = client.post(
        "/api/upload",
        files={"file": ("biased.csv", BytesIO(df.to_csv(index=False).encode()), "text/csv")},
    )
    session_id = upload.json()["session_id"]

    X = df.drop(columns=["loan_approved"])
    y = df["loan_approved"]
    model = build_model_pipeline(X, "logistic_regression")
    model.fit(X, y)
    model_bytes = BytesIO()
    joblib.dump(model, model_bytes)
    model_bytes.seek(0)

    model_upload = client.post(
        "/api/model",
        data={"session_id": session_id},
        files={"file": ("loan_model.joblib", model_bytes, "application/octet-stream")},
    )
    assert model_upload.status_code == 200
    model_id = model_upload.json()["model_id"]

    audit = client.post(
        "/api/audit",
        json={
            "session_id": session_id,
            "protected_attributes": ["race"],
            "outcome_column": "loan_approved",
            "audit_mode": "uploaded_model",
            "model_id": model_id,
        },
    )

    assert audit.status_code == 200
    body = audit.json()
    assert body["post_audit"]["mode"] == "uploaded_model"
    assert body["post_audit"]["performance"]["training_samples"] is None
    assert body["post_audit"]["prediction_validation"]["status"] == "Pass"


def test_uploaded_model_api_disabled_by_default(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(main_module, "UPLOADED_MODEL_MODE_ENABLED", False)
    client = TestClient(app)
    df = biased_frame()
    upload = client.post(
        "/api/upload",
        files={"file": ("biased.csv", BytesIO(df.to_csv(index=False).encode()), "text/csv")},
    )

    model_upload = client.post(
        "/api/model",
        data={"session_id": upload.json()["session_id"]},
        files={"file": ("loan_model.joblib", BytesIO(b"not-used"), "application/octet-stream")},
    )
    assert model_upload.status_code == 410


def test_prediction_csv_api_flow_and_persistent_report() -> None:
    client = TestClient(app)
    df = biased_frame()
    upload = client.post(
        "/api/upload",
        files={"file": ("biased.csv", BytesIO(df.to_csv(index=False).encode()), "text/csv")},
    )
    session_id = upload.json()["session_id"]
    predictions = pd.DataFrame({"prediction": df["loan_approved"]})

    prediction_upload = client.post(
        "/api/predictions",
        data={"session_id": session_id},
        files={"file": ("predictions.csv", BytesIO(predictions.to_csv(index=False).encode()), "text/csv")},
    )
    assert prediction_upload.status_code == 200
    prediction_artifact_id = prediction_upload.json()["prediction_artifact_id"]

    audit = client.post(
        "/api/audit",
        json={
            "session_id": session_id,
            "protected_attributes": ["race"],
            "outcome_column": "loan_approved",
            "audit_mode": "prediction_csv",
            "prediction_artifact_id": prediction_artifact_id,
            "policy_id": "employment_screening_strict",
            "report_template": "compliance_review",
            "control_features": ["income", "education"],
        },
    )

    assert audit.status_code == 200
    body = audit.json()
    assert body["post_audit"]["mode"] == "prediction_csv"
    assert body["deployment_decision"]
    assert body["traceability"]["policy"]["policy_id"] == "employment_screening_strict"
    assert any(section["title"] == "Limitations" for section in body["report"]["sections"])

    detail = client.get(f"/api/report/{body['report_id']}")
    assert detail.status_code == 200
    assert detail.json()["report_id"] == body["report_id"]


def test_prediction_csv_row_id_matching_and_scores() -> None:
    client = TestClient(app)
    df = biased_frame().reset_index().rename(columns={"index": "row_id"})
    upload = client.post(
        "/api/upload",
        files={"file": ("biased.csv", BytesIO(df.to_csv(index=False).encode()), "text/csv")},
    )
    session_id = upload.json()["session_id"]
    predictions = pd.DataFrame(
        {
            "external_id": list(reversed(df["row_id"].tolist())),
            "prediction": list(reversed(df["loan_approved"].tolist())),
            "probability": [0.8 if value else 0.2 for value in reversed(df["loan_approved"].tolist())],
        }
    )

    prediction_upload = client.post(
        "/api/predictions",
        data={
            "session_id": session_id,
            "dataset_row_id_column": "row_id",
            "prediction_row_id_column": "external_id",
            "prediction_column": "prediction",
        },
        files={"file": ("predictions.csv", BytesIO(predictions.to_csv(index=False).encode()), "text/csv")},
    )

    assert prediction_upload.status_code == 200
    details = prediction_upload.json()["details"]
    assert details["matched_rows"] == len(df)
    assert details["missing_predictions"] == 0
    assert details["extra_predictions"] == 0
    assert details["selected_prediction_column"] == "prediction"
    assert details["selected_score_column"] == "probability"

    audit = client.post(
        "/api/audit",
        json={
            "session_id": session_id,
            "protected_attributes": ["race"],
            "outcome_column": "loan_approved",
            "audit_mode": "prediction_csv",
            "prediction_artifact_id": prediction_upload.json()["prediction_artifact_id"],
        },
    )
    assert audit.status_code == 200
    assert audit.json()["model"]["threshold_sensitivity"]["available"] is True


def test_uploaded_model_predictions_must_be_binary() -> None:
    class BadModel:
        def predict(self, X: pd.DataFrame) -> list[float]:
            return [0.2] * len(X)

    try:
        run_audit(
            biased_frame(),
            protected_attributes=["race"],
            outcome_column="loan_approved",
            audit_mode="uploaded_model",
            uploaded_model=BadModel(),
            uploaded_model_name="bad.pkl",
        )
    except AuditError as exc:
        assert "binary" in str(exc)
    else:
        raise AssertionError("Expected uploaded non-binary predictions to fail")
