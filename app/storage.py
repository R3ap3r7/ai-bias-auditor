from __future__ import annotations

import json
import os
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

try:
    import google.auth
    from google.auth.transport.requests import Request as GoogleAuthRequest
    from google.cloud import firestore
    from google.oauth2.credentials import Credentials as UserCredentials
except Exception:  # pragma: no cover - optional dependency for local/offline development.
    google = None
    firestore = None
    GoogleAuthRequest = None
    UserCredentials = None


ARTIFACT_DIR = Path(__file__).resolve().parent.parent / "data" / "audit_history"
ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
MAX_LOCAL_ARTIFACTS = 200


@dataclass
class FirestoreContext:
    client: Any
    project_id: str
    audit_runs_collection: str = "auditRuns"
    reports_collection: str = "reports"


class AuditArtifactStore:
    def __init__(self) -> None:
        self._firestore: FirestoreContext | None = None
        self._firestore_error: str | None = None

    def storage_status(self) -> dict[str, Any]:
        firestore_enabled = self._ensure_firestore() is not None
        return {
            "local_path": str(ARTIFACT_DIR),
            "firestore_enabled": firestore_enabled,
            "firestore_error": self._firestore_error,
            "project_id": self._firestore.project_id if self._firestore else os.getenv("FIRESTORE_PROJECT_ID", ""),
        }

    def save_report(self, report_id: str, result: dict[str, Any]) -> None:
        payload = {"report_id": report_id, "stored_at_utc": datetime.now(UTC).isoformat(), **result}
        local_path = self._local_report_path(report_id)
        local_path.write_text(json.dumps(payload, ensure_ascii=True, indent=2), encoding="utf-8")
        self._prune_local_artifacts()

        summary = build_history_summary(payload)
        firestore_ctx = self._ensure_firestore()
        if firestore_ctx is None:
            return

        try:
            firestore_ctx.client.collection(firestore_ctx.audit_runs_collection).document(report_id).set(summary)
            firestore_ctx.client.collection(firestore_ctx.reports_collection).document(report_id).set(payload)
        except Exception as exc:  # pragma: no cover - depends on external credentials/network.
            self._firestore_error = str(exc)

    def get_report(self, report_id: str) -> dict[str, Any] | None:
        local_path = self._local_report_path(report_id)
        if local_path.exists():
            return json.loads(local_path.read_text(encoding="utf-8"))

        firestore_ctx = self._ensure_firestore()
        if firestore_ctx is None:
            return None
        try:
            document = firestore_ctx.client.collection(firestore_ctx.reports_collection).document(report_id).get()
            if document.exists:
                return document.to_dict()
        except Exception as exc:  # pragma: no cover - depends on external credentials/network.
            self._firestore_error = str(exc)
        return None

    def list_reports(self, limit: int = 25) -> list[dict[str, Any]]:
        local_reports = sorted(
            (json.loads(path.read_text(encoding="utf-8")) for path in ARTIFACT_DIR.glob("*.json")),
            key=lambda item: item.get("traceability", {}).get("created_at_utc", item.get("stored_at_utc", "")),
            reverse=True,
        )
        local_history = [build_history_summary(item) for item in local_reports[:limit]]
        if local_history:
            return local_history

        firestore_ctx = self._ensure_firestore()
        if firestore_ctx is None:
            return []
        try:
            docs = (
                firestore_ctx.client.collection(firestore_ctx.audit_runs_collection)
                .order_by("created_at_utc", direction=firestore.Query.DESCENDING)
                .limit(limit)
                .stream()
            )
            return [doc.to_dict() for doc in docs]
        except Exception as exc:  # pragma: no cover - depends on external credentials/network.
            self._firestore_error = str(exc)
            return []

    def _local_report_path(self, report_id: str) -> Path:
        return ARTIFACT_DIR / f"{report_id}.json"

    def _prune_local_artifacts(self) -> None:
        files = sorted(ARTIFACT_DIR.glob("*.json"), key=lambda path: path.stat().st_mtime, reverse=True)
        for stale in files[MAX_LOCAL_ARTIFACTS:]:
            stale.unlink(missing_ok=True)

    def _ensure_firestore(self) -> FirestoreContext | None:
        if self._firestore is not None:
            return self._firestore
        if firestore is None:
            self._firestore_error = "google-cloud-firestore is not installed."
            return None

        project_id = os.getenv("FIRESTORE_PROJECT_ID") or os.getenv("GOOGLE_CLOUD_PROJECT") or os.getenv("GCLOUD_PROJECT")
        if not project_id:
            self._firestore_error = "FIRESTORE_PROJECT_ID is not configured."
            return None

        try:
            access_token = os.getenv("FIRESTORE_ACCESS_TOKEN", "").strip()
            if access_token and UserCredentials is not None:
                credentials = UserCredentials(token=access_token)
                client = firestore.Client(project=project_id, credentials=credentials)
            else:
                credentials, detected_project = google.auth.default(
                    scopes=["https://www.googleapis.com/auth/datastore"]
                )
                if detected_project and not project_id:
                    project_id = detected_project
                if hasattr(credentials, "refresh") and GoogleAuthRequest is not None and not getattr(credentials, "valid", True):
                    credentials.refresh(GoogleAuthRequest())
                client = firestore.Client(project=project_id, credentials=credentials)

            self._firestore = FirestoreContext(client=client, project_id=project_id)
            self._firestore_error = None
        except Exception as exc:  # pragma: no cover - depends on external credentials/network.
            self._firestore_error = str(exc)
            self._firestore = None
        return self._firestore


def build_history_summary(result: dict[str, Any]) -> dict[str, Any]:
    traceability = result.get("traceability", {})
    governance = result.get("governance", {})
    model = result.get("model", {})
    report = result.get("report", {})
    dataset = result.get("dataset", {})
    performance = model.get("performance", {})
    bias_metrics = model.get("bias_metrics", [])
    dp = max((item.get("demographic_parity_difference", 0.0) for item in bias_metrics), default=0.0)
    eo = max((item.get("equalized_odds_difference", 0.0) for item in bias_metrics), default=0.0)
    di_values = [item.get("disparate_impact_ratio", 1.0) for item in bias_metrics if item.get("disparate_impact_ratio") is not None]
    return {
        "report_id": result.get("report_id"),
        "run_id": traceability.get("run_id"),
        "created_at_utc": traceability.get("created_at_utc", result.get("stored_at_utc")),
        "dataset_name": dataset.get("source_name") or dataset.get("source") or dataset.get("outcome_column", "Uploaded dataset"),
        "dataset_hash_sha256": traceability.get("dataset_hash_sha256"),
        "model_fingerprint_sha256": traceability.get("model_fingerprint_sha256"),
        "policy_id": traceability.get("policy", {}).get("policy_id", ""),
        "policy_version": traceability.get("policy", {}).get("policy_version", ""),
        "report_template": report.get("template_id", ""),
        "severity": result.get("severity", "Unknown"),
        "risk_score": governance.get("risk_score"),
        "deployment_decision": governance.get("deployment_decision"),
        "report_source": report.get("source", "Local deterministic report"),
        "rows": dataset.get("rows"),
        "columns": dataset.get("columns"),
        "model_type": model.get("model_type"),
        "accuracy": performance.get("accuracy"),
        "max_demographic_parity_difference": round(float(dp), 4),
        "max_equalized_odds_difference": round(float(eo), 4),
        "min_disparate_impact_ratio": round(float(min(di_values, default=1.0)), 4),
    }


STORE = AuditArtifactStore()
