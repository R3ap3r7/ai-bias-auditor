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
from fastapi.responses import HTMLResponse, Response, StreamingResponse
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
MAX_MODEL_BYTES = 50 * 1024 * 1024
MAX_PREDICTION_ROWS = 250000


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


@app.get("/", response_class=HTMLResponse)
async def index(request: Request) -> HTMLResponse:
    return templates.TemplateResponse(request, "index.html", {})


@app.get("/audit", response_class=HTMLResponse)
async def audit_page(request: Request) -> HTMLResponse:
    return templates.TemplateResponse(request, "audit.html", {})


@app.get("/history", response_class=HTMLResponse)
async def history_page(request: Request) -> HTMLResponse:
    return templates.TemplateResponse(request, "history.html", {})


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
async def upload_predictions(session_id: str = Form(...), file: UploadFile = File(...)) -> dict[str, Any]:
    if session_id not in SESSIONS:
        raise HTTPException(status_code=404, detail="Dataset session expired. Upload the CSV again.")
    if not file.filename or not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Upload a prediction CSV file.")

    content = await file.read()
    try:
        prediction_frame = pd.read_csv(BytesIO(content))
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Could not read prediction CSV: {exc}") from exc

    dataset_rows = len(SESSIONS[session_id]["dataframe"])
    try:
        prediction_series, details = parse_prediction_csv(prediction_frame, expected_rows=dataset_rows)
    except AuditError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    artifact_id = uuid.uuid4().hex
    PREDICTION_ARTIFACTS[artifact_id] = {
        "session_id": session_id,
        "filename": file.filename,
        "predictions": prediction_series,
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
    prediction_metadata: dict[str, Any] | None = None

    if request.audit_mode == "uploaded_model":
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
    STORE.save_report(report_id, result)
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


def parse_prediction_csv(prediction_frame: pd.DataFrame, *, expected_rows: int) -> tuple[pd.Series, dict[str, Any]]:
    if prediction_frame.empty:
        raise AuditError("The prediction CSV is empty.")
    if len(prediction_frame) > MAX_PREDICTION_ROWS:
        raise AuditError(f"Prediction CSV exceeds the limit of {MAX_PREDICTION_ROWS} rows.")

    candidate_columns = [
        column
        for column in prediction_frame.columns
        if str(column).strip().lower() in {"prediction", "predictions", "predicted_label", "y_pred", "output"}
    ]
    if len(prediction_frame.columns) == 1:
        selected_column = prediction_frame.columns[0]
    elif candidate_columns:
        selected_column = candidate_columns[0]
    else:
        raise AuditError(
            "Prediction CSV must contain exactly one column or a recognized prediction column such as "
            "`prediction`, `predicted_label`, or `y_pred`."
        )

    predictions = prediction_frame[selected_column]
    if len(predictions) != expected_rows:
        raise AuditError(
            f"Prediction CSV has {len(predictions)} rows, but the dataset session has {expected_rows} rows. "
            "Provide predictions aligned one-to-one with the uploaded dataset."
        )
    return predictions.reset_index(drop=True), {
        "selected_column": str(selected_column),
        "columns": [str(column) for column in prediction_frame.columns],
        "mode": "prediction_csv",
        "warnings": [
            "Prediction-only audits are safer than pickle loading but cannot inspect the model internals or reproduce feature-level local explanations.",
        ],
    }


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
