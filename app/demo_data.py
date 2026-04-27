from __future__ import annotations

from pathlib import Path
from typing import Any

import pandas as pd

DEMO_DIR = Path(__file__).resolve().parent.parent / "data" / "demos"

DEMO_CONFIGS: dict[str, dict[str, Any]] = {
    "compas": {
        "name": "COMPAS Criminal Justice",
        "filename": "compas.csv",
        "protected_attributes": ["race", "gender", "age_cat"],
        "outcome_column": "two_year_recid",
        "model_type": "compare_all",
    },
    "adult": {
        "name": "UCI Adult Income",
        "filename": "adult.csv",
        "protected_attributes": ["sex", "race"],
        "outcome_column": "income",
        "model_type": "compare_all",
    },
    "german": {
        "name": "German Credit",
        "filename": "german_credit.csv",
        "protected_attributes": ["age"],
        "outcome_column": "credit_risk",
        "model_type": "compare_all",
    },
}


def list_demos() -> list[dict[str, Any]]:
    return [
        {
            "id": demo_id,
            "name": config["name"],
            "protected_attributes": config["protected_attributes"],
            "outcome_column": config["outcome_column"],
            "model_type": config["model_type"],
            "available": (DEMO_DIR / config["filename"]).exists(),
        }
        for demo_id, config in DEMO_CONFIGS.items()
    ]


def load_demo_dataset(demo_id: str) -> tuple[pd.DataFrame, dict[str, Any]]:
    if demo_id not in DEMO_CONFIGS:
        raise KeyError(f"Unknown demo dataset: {demo_id}")

    config = DEMO_CONFIGS[demo_id].copy()
    path = DEMO_DIR / config["filename"]
    if path.exists():
        df = pd.read_csv(path)
        config["source"] = str(path)
        return df, config

    raise FileNotFoundError(
        f"Demo CSV not found at {path}. Run `python scripts/download_demos.py` before using this demo."
    )
