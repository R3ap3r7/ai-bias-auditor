from __future__ import annotations

import os
import pickle
import uuid
from io import BytesIO
from typing import Any

import joblib
import pandas as pd
from dotenv import load_dotenv
from fastapi import FastAPI, File, Form, HTTPException, Query, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse, Response, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, Field

from app.audit import AuditError, profile_dataframe, run_audit, run_pre_audit_only
from app.demo_data import list_demos, load_demo_dataset
from app.policies import DEFAULT_POLICY_ID, list_policies, list_report_templates
from app.report import build_pdf_report
from app.storage import STORE

load_dotenv()

app = FastAPI(title="AI Bias Auditor", version="0.2.0")
default_cors_origins = ",".join(
    [
        "http://localhost:5000",
        "http://localhost:5050",
        "http://localhost:8080",
        "http://localhost:5173",
        "http://127.0.0.1:5050",
    ]
)
cors_origins = [
    origin.strip()
    for origin in os.getenv("CORS_ALLOWED_ORIGINS", default_cors_origins).split(",")
    if origin.strip()
]
if cors_origins:
    allow_all_origins = "*" in cors_origins
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"] if allow_all_origins else cors_origins,
        allow_credentials=not allow_all_origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )
app.mount("/static", StaticFiles(directory="app/static"), name="static")
templates = Jinja2Templates(directory="app/templates")

SESSIONS: dict[str, dict[str, Any]] = {}
MODELS: dict[str, dict[str, Any]] = {}
PREDICTION_ARTIFACTS: dict[str, dict[str, Any]] = {}
MAX_MEMORY_ITEMS = 25
MAX_DATASET_BYTES = int(os.getenv("MAX_DATASET_BYTES", str(25 * 1024 * 1024)))
MAX_MODEL_BYTES = 50 * 1024 * 1024
MAX_PREDICTION_ROWS = 250000
SCORE_COLUMN_NAMES = {"score", "probability", "confidence", "decision_score", "y_score", "predicted_probability"}
UPLOADED_MODEL_MODE_ENABLED = os.getenv("ENABLE_UPLOADED_MODEL_MODE", "").strip().lower() in {"1", "true", "yes"}


class AuditRequest(BaseModel):
    session_id: str
    protected_attributes: list[str] = Field(min_length=1)
    outcome_column: str
    model_type: str = "logistic_regression"
    audit_mode: str = "train"
    model_id: str | None = None
    prediction_artifact_id: str | None = None
    policy_id: str = DEFAULT_POLICY_ID
    report_template: str = "full_report"
    control_features: list[str] = Field(default_factory=list)
    grouping_overrides: dict[str, dict[str, Any]] = Field(default_factory=dict)
    model_selection_priority: float | None = Field(default=None, ge=0.0, le=1.0)
    persistence_mode: str | None = Field(default=None, pattern="^(aggregate_only|anonymized_traces|full_report)$")
    user_id: str | None = None
    project_id: str | None = None
    organization_id: str | None = None


def frontend_url(path: str = "") -> str:
    base = os.getenv("FRONTEND_URL", "http://localhost:5050").rstrip("/")
    return f"{base}{path}"


@app.get("/")
async def index(request: Request) -> RedirectResponse:
    return RedirectResponse(frontend_url())


@app.get("/audit")
async def audit_page(request: Request) -> RedirectResponse:
    return RedirectResponse(frontend_url())


@app.get("/history")
async def history_page(request: Request) -> RedirectResponse:
    return RedirectResponse(frontend_url())


@app.get("/health")
async def health() -> dict[str, Any]:
    return {"status": "ok", "storage": STORE.storage_status()}


@app.get("/favicon.ico", include_in_schema=False)
async def favicon() -> Response:
    return Response(status_code=204)


@app.get("/api/demos")
async def demos() -> dict[str, Any]:
    return {"demos": list_demos()}


@app.get("/api/policies")
async def policies() -> dict[str, Any]:
    return {
        "policies": list_policies(),
        "report_templates": list_report_templates(),
        "storage": STORE.storage_status(),
    }


@app.get("/api/firebase-config")
async def firebase_config() -> dict[str, Any]:
    config = {
        "apiKey": os.getenv("FIREBASE_API_KEY", ""),
        "authDomain": os.getenv("FIREBASE_AUTH_DOMAIN", ""),
        "projectId": os.getenv("FIREBASE_PROJECT_ID", ""),
        "storageBucket": os.getenv("FIREBASE_STORAGE_BUCKET", ""),
        "messagingSenderId": os.getenv("FIREBASE_MESSAGING_SENDER_ID", ""),
        "appId": os.getenv("FIREBASE_APP_ID", ""),
    }
    return {
        "enabled": all(config.values()),
        "config": config,
    }


@app.get("/api/history")
async def history(limit: int = Query(default=25, ge=1, le=100)) -> dict[str, Any]:
    return {"items": STORE.list_reports(limit=limit), "storage": STORE.storage_status()}


@app.get("/api/report/{report_id}")
async def report_detail(report_id: str) -> dict[str, Any]:
    report = STORE.get_report(report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found in persistent storage.")
    return report


@app.post("/api/upload")
async def upload_dataset(file: UploadFile = File(...)) -> dict[str, Any]:
    if not file.filename or not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Upload a CSV file.")

    content = await file.read()
    if len(content) > MAX_DATASET_BYTES:
        limit_mb = MAX_DATASET_BYTES / (1024 * 1024)
        raise HTTPException(status_code=413, detail=f"CSV file exceeds the configured limit of {limit_mb:.1f} MB.")
    try:
        df = pd.read_csv(BytesIO(content))
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Could not read CSV: {exc}") from exc

    session_id = create_session(df, {"source": file.filename, "demo": None})
    return {
        "session_id": session_id,
        "profile": profile_dataframe(df),
        "source": file.filename,
    }


@app.post("/api/model")
async def upload_model(session_id: str = Form(...), file: UploadFile = File(...)) -> dict[str, Any]:
    if not UPLOADED_MODEL_MODE_ENABLED:
        raise HTTPException(
            status_code=410,
            detail="Uploaded model artifacts are disabled for this release. Use prediction CSV mode instead.",
        )
    if session_id not in SESSIONS:
        raise HTTPException(status_code=404, detail="Dataset session expired. Upload the CSV again.")
    if not file.filename:
        raise HTTPException(status_code=400, detail="Upload a .joblib, .pkl, or .pickle model file.")

    lower_name = file.filename.lower()
    if not lower_name.endswith((".joblib", ".pkl", ".pickle")):
        raise HTTPException(status_code=400, detail="Upload a .joblib, .pkl, or .pickle model file.")

    content = await file.read()
    if len(content) > MAX_MODEL_BYTES:
        raise HTTPException(status_code=400, detail="Model file is too large. The MVP limit is 50 MB.")

    try:
        model, loader = load_uploaded_model(content)
    except AuditError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    if not hasattr(model, "predict"):
        raise HTTPException(status_code=400, detail="Uploaded model must expose a predict(...) method.")

    model_id = uuid.uuid4().hex
    MODELS[model_id] = {
        "model": model,
        "filename": file.filename,
        "loader": loader,
        "session_id": session_id,
        "class_name": f"{model.__class__.__module__}.{model.__class__.__name__}",
    }
    prune_memory(MODELS)
    return {
        "model_id": model_id,
        "filename": file.filename,
        "loader": loader,
        "class_name": MODELS[model_id]["class_name"],
        "warning": (
            "Unsafe artifact mode: pickle/joblib loading can execute code during deserialization. "
            "Use prediction-CSV mode for safer third-party model audits whenever possible."
        ),
    }


@app.post("/api/predictions")
async def upload_predictions(
    session_id: str = Form(...),
    file: UploadFile = File(...),
    dataset_row_id_column: str | None = Form(default=None),
    prediction_row_id_column: str | None = Form(default=None),
    prediction_column: str | None = Form(default=None),
    score_column: str | None = Form(default=None),
) -> dict[str, Any]:
    if session_id not in SESSIONS:
        raise HTTPException(status_code=404, detail="Dataset session expired. Upload the CSV again.")
    if not file.filename or not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Upload a prediction CSV file.")

    content = await file.read()
    try:
        prediction_frame = pd.read_csv(BytesIO(content))
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Could not read prediction CSV: {exc}") from exc

    dataset_frame = SESSIONS[session_id]["dataframe"]
    dataset_rows = len(dataset_frame)
    try:
        prediction_series, score_series, details = parse_prediction_csv(
            prediction_frame,
            dataset_frame=dataset_frame,
            expected_rows=dataset_rows,
            dataset_row_id_column=dataset_row_id_column,
            prediction_row_id_column=prediction_row_id_column,
            prediction_column=prediction_column,
            score_column=score_column,
        )
    except AuditError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except ValueError as exc:
        detail = exc.args[0] if exc.args and isinstance(exc.args[0], dict) else str(exc)
        raise HTTPException(status_code=400, detail=detail) from exc

    artifact_id = uuid.uuid4().hex
    PREDICTION_ARTIFACTS[artifact_id] = {
        "session_id": session_id,
        "filename": file.filename,
        "predictions": prediction_series,
        "scores": score_series,
        "details": details,
    }
    prune_memory(PREDICTION_ARTIFACTS)
    return {
        "prediction_artifact_id": artifact_id,
        "filename": file.filename,
        "rows": int(len(prediction_series)),
        "details": details,
    }


@app.post("/api/demo/{demo_id}")
async def demo_dataset(demo_id: str) -> dict[str, Any]:
    try:
        df, config = load_demo_dataset(demo_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not load demo dataset: {exc}") from exc

    session_id = create_session(df, {"source": config["source"], "demo": demo_id})
    return {
        "session_id": session_id,
        "profile": profile_dataframe(df),
        "defaults": {
            "protected_attributes": config["protected_attributes"],
            "outcome_column": config["outcome_column"],
            "model_type": config["model_type"],
            "policy_id": config.get("policy_id", DEFAULT_POLICY_ID),
            "control_features": config.get("control_features", []),
        },
        "source": config["source"],
        "name": config["name"],
    }


@app.post("/api/pre-audit")
async def pre_audit_dataset(request: AuditRequest) -> dict[str, Any]:
    session = SESSIONS.get(request.session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Dataset session expired. Upload the CSV again.")

    try:
        result = run_pre_audit_only(
            session["dataframe"],
            protected_attributes=request.protected_attributes,
            outcome_column=request.outcome_column,
            policy_id=request.policy_id,
            grouping_overrides=request.grouping_overrides,
            control_features=request.control_features,
        )
    except AuditError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Pre-audit failed: {exc}") from exc

    result.pop("_clean_dataframe", None)
    result["dataset"]["source_name"] = session["metadata"].get("source")
    result["dataset"]["demo_id"] = session["metadata"].get("demo")
    return result


@app.post("/api/audit")
async def audit_dataset(request: AuditRequest) -> dict[str, Any]:
    session = SESSIONS.get(request.session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Dataset session expired. Upload the CSV again.")

    model = None
    model_name = None
    prediction_series = None
    score_series = None
    prediction_metadata: dict[str, Any] | None = None

    if request.audit_mode == "uploaded_model":
        if not UPLOADED_MODEL_MODE_ENABLED:
            raise HTTPException(
                status_code=410,
                detail="Uploaded model artifacts are disabled for this release. Use prediction CSV mode instead.",
            )
        if not request.model_id or request.model_id not in MODELS:
            raise HTTPException(status_code=400, detail="Upload a model before running uploaded-model audit.")
        model_record = MODELS[request.model_id]
        if model_record.get("session_id") != request.session_id:
            raise HTTPException(status_code=400, detail="The uploaded model belongs to a different dataset session.")
        model = model_record["model"]
        model_name = model_record["filename"]
    elif request.audit_mode == "prediction_csv":
        if not request.prediction_artifact_id or request.prediction_artifact_id not in PREDICTION_ARTIFACTS:
            raise HTTPException(status_code=400, detail="Upload a prediction CSV before running prediction-only audit.")
        prediction_record = PREDICTION_ARTIFACTS[request.prediction_artifact_id]
        if prediction_record.get("session_id") != request.session_id:
            raise HTTPException(status_code=400, detail="The uploaded prediction CSV belongs to a different dataset session.")
        prediction_series = prediction_record["predictions"]
        score_series = prediction_record.get("scores")
        prediction_metadata = {
            "filename": prediction_record["filename"],
            **prediction_record.get("details", {}),
        }

    try:
        result = run_audit(
            session["dataframe"],
            protected_attributes=request.protected_attributes,
            outcome_column=request.outcome_column,
            model_type=request.model_type,
            audit_mode=request.audit_mode,
            uploaded_model=model,
            uploaded_model_name=model_name,
            uploaded_predictions=prediction_series,
            uploaded_prediction_scores=score_series,
            uploaded_prediction_metadata=prediction_metadata,
            policy_id=request.policy_id,
            report_template=request.report_template,
            control_features=request.control_features,
            grouping_overrides=request.grouping_overrides,
            model_selection_priority=request.model_selection_priority,
        )
    except AuditError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Audit failed: {exc}") from exc

    report_id = uuid.uuid4().hex
    result["report_id"] = report_id
    result["dataset"]["source_name"] = session["metadata"].get("source")
    result["dataset"]["demo_id"] = session["metadata"].get("demo")
    result["traceability"]["user_id"] = request.user_id
    result["traceability"]["project_id"] = request.project_id
    result["traceability"]["organization_id"] = request.organization_id
    result["traceability"]["persistence_mode"] = request.persistence_mode or os.getenv("REPORT_PERSISTENCE_MODE", "anonymized_traces")
    STORE.save_report(report_id, result, persistence_mode=request.persistence_mode)
    return result


@app.get("/api/report/{report_id}/pdf")
async def report_pdf(report_id: str, template_id: str | None = Query(default=None)) -> StreamingResponse:
    result = STORE.get_report(report_id)
    if not result:
        raise HTTPException(status_code=404, detail="Report not found in persistent storage.")
    pdf = build_pdf_report(result, template_id=template_id)
    return StreamingResponse(
        BytesIO(pdf),
        media_type="application/pdf",
        headers={"Content-Disposition": 'attachment; filename="ai-bias-audit-report.pdf"'},
    )


@app.delete("/api/report/{report_id}")
async def delete_report(report_id: str) -> dict[str, Any]:
    deleted = STORE.delete_report(report_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Report not found in persistent storage.")
    return {"deleted": True, "report_id": report_id}


@app.post("/api/report/pdf")
async def report_pdf_from_payload(
    payload: dict[str, Any],
    template_id: str | None = Query(default=None),
) -> StreamingResponse:
    pdf = build_pdf_report(payload, template_id=template_id)
    return StreamingResponse(
        BytesIO(pdf),
        media_type="application/pdf",
        headers={"Content-Disposition": 'attachment; filename="ai-bias-audit-report.pdf"'},
    )


def create_session(df: pd.DataFrame, metadata: dict[str, Any]) -> str:
    session_id = uuid.uuid4().hex
    SESSIONS[session_id] = {"dataframe": df, "metadata": metadata}
    prune_memory(SESSIONS)
    return session_id


def parse_prediction_csv(
    prediction_frame: pd.DataFrame,
    *,
    dataset_frame: pd.DataFrame,
    expected_rows: int,
    dataset_row_id_column: str | None = None,
    prediction_row_id_column: str | None = None,
    prediction_column: str | None = None,
    score_column: str | None = None,
) -> tuple[pd.Series, pd.Series | None, dict[str, Any]]:
    if prediction_frame.empty:
        raise AuditError("The prediction CSV is empty.")
    if len(prediction_frame) > MAX_PREDICTION_ROWS:
        raise AuditError(f"Prediction CSV exceeds the limit of {MAX_PREDICTION_ROWS} rows.")

    selected_column = resolve_column(
        prediction_frame,
        prediction_column,
        {"prediction", "predictions", "predicted_label", "y_pred", "output"},
        allow_single_column=True,
        label="prediction",
    )
    selected_score_column = resolve_column(
        prediction_frame,
        score_column,
        SCORE_COLUMN_NAMES,
        allow_single_column=False,
        label="score",
        required=False,
    )

    details: dict[str, Any] = {
        "selected_column": str(selected_column),
        "selected_prediction_column": str(selected_column),
        "selected_score_column": str(selected_score_column) if selected_score_column is not None else None,
        "columns": [str(column) for column in prediction_frame.columns],
        "mode": "prediction_csv",
        "matched_rows": 0,
        "missing_predictions": 0,
        "extra_predictions": 0,
        "row_id_matching": False,
        "warnings": [
            "Prediction-only audits are safer than pickle loading but cannot inspect the model internals or reproduce feature-level local explanations.",
        ],
    }
    if selected_score_column is not None:
        details["warnings"].append("Score metadata was captured for threshold and sensitivity review; current fairness metrics still use the selected binary prediction column.")

    if dataset_row_id_column or prediction_row_id_column:
        if not dataset_row_id_column or not prediction_row_id_column:
            raise AuditError("Provide both dataset_row_id_column and prediction_row_id_column for row-id matching.")
        dataset_id_column = require_column(dataset_frame, dataset_row_id_column, "dataset row ID")
        prediction_id_column = require_column(prediction_frame, prediction_row_id_column, "prediction row ID")
        merged = dataset_frame[[dataset_id_column]].reset_index().merge(
            prediction_frame[[prediction_id_column, selected_column] + ([selected_score_column] if selected_score_column is not None else [])],
            left_on=dataset_id_column,
            right_on=prediction_id_column,
            how="left",
            indicator=True,
        )
        matched_rows = int((merged["_merge"] == "both").sum())
        missing_predictions = int((merged["_merge"] == "left_only").sum())
        dataset_ids = set(dataset_frame[dataset_id_column].dropna().astype(str))
        prediction_ids = set(prediction_frame[prediction_id_column].dropna().astype(str))
        extra_predictions = len(prediction_ids - dataset_ids)
        details.update(
            {
                "row_id_matching": True,
                "dataset_row_id_column": str(dataset_id_column),
                "prediction_row_id_column": str(prediction_id_column),
                "matched_rows": matched_rows,
                "missing_predictions": missing_predictions,
                "extra_predictions": int(extra_predictions),
            }
        )
        if missing_predictions:
            raise ValueError(
                {
                    "message": "Prediction CSV is missing predictions for one or more dataset row IDs.",
                    "validation": details,
                }
            )
        score_series = merged[selected_score_column].reset_index(drop=True) if selected_score_column is not None else None
        return merged[selected_column].reset_index(drop=True), score_series, details

    predictions = prediction_frame[selected_column]
    if len(predictions) != expected_rows:
        raise AuditError(
            f"Prediction CSV has {len(predictions)} rows, but the dataset session has {expected_rows} rows. "
            "Provide predictions aligned one-to-one with the uploaded dataset or supply row ID columns."
        )
    details.update({"matched_rows": int(expected_rows)})
    score_series = prediction_frame[selected_score_column].reset_index(drop=True) if selected_score_column is not None else None
    return predictions.reset_index(drop=True), score_series, details


def resolve_column(
    frame: pd.DataFrame,
    requested: str | None,
    recognized_names: set[str],
    *,
    allow_single_column: bool,
    label: str,
    required: bool = True,
) -> Any:
    if requested:
        return require_column(frame, requested, label)
    candidate_columns = [
        column for column in frame.columns if str(column).strip().lower() in recognized_names
    ]
    if candidate_columns:
        return candidate_columns[0]
    if allow_single_column and len(frame.columns) == 1:
        return frame.columns[0]
    if required:
        recognized = ", ".join(f"`{name}`" for name in sorted(recognized_names))
        raise AuditError(f"Prediction CSV must include a {label} column such as {recognized}, or select one explicitly.")
    return None


def require_column(frame: pd.DataFrame, requested: str, label: str) -> Any:
    requested_normalized = requested.strip().lower()
    for column in frame.columns:
        if str(column).strip().lower() == requested_normalized:
            return column
    raise AuditError(f"Unknown {label} column `{requested}`.")


def load_uploaded_model(content: bytes) -> tuple[Any, str]:
    try:
        return joblib.load(BytesIO(content)), "joblib"
    except Exception as joblib_error:
        try:
            return pickle.loads(content), "pickle"
        except Exception as pickle_error:
            raise AuditError(
                f"Could not load model with joblib or pickle. joblib: {joblib_error}; pickle: {pickle_error}"
            ) from pickle_error


def prune_memory(container: dict[str, Any]) -> None:
    while len(container) > MAX_MEMORY_ITEMS:
        oldest_key = next(iter(container))
        del container[oldest_key]
