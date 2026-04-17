from __future__ import annotations

from io import BytesIO

import joblib
import pandas as pd
from fastapi.testclient import TestClient

from app.audit import AuditError, build_model_pipeline, calculate_severity, normalize_outcome, run_audit
from app.main import app
from app.report import build_pdf_report


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


def test_severity_logic_matches_mvp_rules() -> None:
    assert calculate_severity(0.25, 0.21, 3, 0.4) == "Critical"
    assert calculate_severity(0.11, 0.11, 0, 0.9) == "Medium"
    assert calculate_severity(0.01, 0.02, 0, 0.95) == "Low"


def test_upload_and_audit_api_flow() -> None:
    client = TestClient(app)
    csv_bytes = biased_frame().to_csv(index=False).encode()

    landing = client.get("/")
    assert landing.status_code == 200
    assert "AI Bias Auditor" in landing.text

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


def test_uploaded_model_api_flow() -> None:
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
