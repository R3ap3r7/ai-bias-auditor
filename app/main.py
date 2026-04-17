from __future__ import annotations

import uuid
import pickle
from io import BytesIO
from typing import Any

import joblib
import pandas as pd
from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import HTMLResponse, Response, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from dotenv import load_dotenv
from pydantic import BaseModel, Field

from app.audit import AuditError, profile_dataframe, run_audit, run_pre_audit_only
from app.demo_data import list_demos, load_demo_dataset
from app.report import build_pdf_report

load_dotenv()

app = FastAPI(title="AI Bias Auditor", version="0.1.0")
app.mount("/static", StaticFiles(directory="app/static"), name="static")
templates = Jinja2Templates(directory="app/templates")

SESSIONS: dict[str, dict[str, Any]] = {}
MODELS: dict[str, dict[str, Any]] = {}
REPORTS: dict[str, dict[str, Any]] = {}
MAX_MEMORY_ITEMS = 25
MAX_MODEL_BYTES = 50 * 1024 * 1024


class AuditRequest(BaseModel):
    session_id: str
    protected_attributes: list[str] = Field(min_length=1)
    outcome_column: str
    model_type: str = "logistic_regression"
    audit_mode: str = "train"
    model_id: str | None = None


@app.get("/", response_class=HTMLResponse)
async def index(request: Request) -> HTMLResponse:
    return templates.TemplateResponse(request, "index.html", {})


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/favicon.ico", include_in_schema=False)
async def favicon() -> Response:
    return Response(status_code=204)


@app.get("/api/demos")
async def demos() -> dict[str, Any]:
    return {"demos": list_demos()}


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
    return {"session_id": session_id, "profile": profile_dataframe(df), "source": file.filename}


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
        "warning": "Only upload pickle/joblib models from trusted sources. Loading these files can execute code.",
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
        )
    except AuditError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Pre-audit failed: {exc}") from exc

    result.pop("_clean_dataframe", None)
    return result


@app.post("/api/audit")
async def audit_dataset(request: AuditRequest) -> dict[str, Any]:
    session = SESSIONS.get(request.session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Dataset session expired. Upload the CSV again.")

    model = None
    model_name = None
    if request.audit_mode == "uploaded_model":
        if not request.model_id or request.model_id not in MODELS:
            raise HTTPException(status_code=400, detail="Upload a model before running uploaded-model audit.")
        model_record = MODELS[request.model_id]
        if model_record.get("session_id") != request.session_id:
            raise HTTPException(status_code=400, detail="The uploaded model belongs to a different dataset session.")
        model = model_record["model"]
        model_name = model_record["filename"]

    df = session["dataframe"]
    try:
        result = run_audit(
            df,
            protected_attributes=request.protected_attributes,
            outcome_column=request.outcome_column,
            model_type=request.model_type,
            audit_mode=request.audit_mode,
            uploaded_model=model,
            uploaded_model_name=model_name,
        )
    except AuditError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Audit failed: {exc}") from exc

    report_id = uuid.uuid4().hex
    REPORTS[report_id] = result
    prune_memory(REPORTS)
    return {"report_id": report_id, **result}


@app.get("/api/report/{report_id}/pdf")
async def report_pdf(report_id: str) -> StreamingResponse:
    result = REPORTS.get(report_id)
    if not result:
        raise HTTPException(status_code=404, detail="Report expired. Run the audit again.")
    pdf = build_pdf_report(result)
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
        first_key = next(iter(container))
        container.pop(first_key, None)
