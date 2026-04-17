from __future__ import annotations

from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

DEMO_DIR = Path(__file__).resolve().parent.parent / "data" / "demos"

DEMO_CONFIGS: dict[str, dict[str, Any]] = {
    "compas": {
        "name": "COMPAS Criminal Justice",
        "filename": "compas.csv",
        "protected_attributes": ["race", "gender", "age_cat"],
        "outcome_column": "two_year_recid",
        "model_type": "logistic_regression",
    },
    "adult": {
        "name": "UCI Adult Income",
        "filename": "adult.csv",
        "protected_attributes": ["sex", "race"],
        "outcome_column": "income",
        "model_type": "logistic_regression",
    },
    "german": {
        "name": "German Credit",
        "filename": "german_credit.csv",
        "protected_attributes": ["age"],
        "outcome_column": "credit_risk",
        "model_type": "decision_tree",
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

    fallback = synthetic_demo(demo_id)
    config["source"] = "synthetic fallback"
    return fallback, config


def synthetic_demo(demo_id: str) -> pd.DataFrame:
    rng = np.random.default_rng(42)
    size = 420

    if demo_id == "adult":
        sex = rng.choice(["Male", "Female"], size=size, p=[0.54, 0.46])
        race = rng.choice(["White", "Black", "Asian-Pac-Islander", "Amer-Indian-Eskimo", "Other"], size=size)
        education = rng.choice(["HS-grad", "Bachelors", "Masters", "Some-college"], size=size)
        hours = rng.normal(40, 9, size).clip(10, 80).round()
        capital_gain = rng.choice([0, 0, 0, 5000, 10000], size=size)
        score = (
            0.8 * (sex == "Male")
            + 0.35 * (race == "White")
            + 0.5 * np.isin(education, ["Bachelors", "Masters"])
            + 0.02 * (hours - 40)
            + 0.00008 * capital_gain
            + rng.normal(0, 0.7, size)
        )
        income = np.where(score > 0.9, ">50K", "<=50K")
        return pd.DataFrame(
            {
                "age": rng.integers(19, 70, size=size),
                "workclass": rng.choice(["Private", "Self-emp", "Government"], size=size),
                "education": education,
                "hours_per_week": hours,
                "capital_gain": capital_gain,
                "sex": sex,
                "race": race,
                "income": income,
            }
        )

    if demo_id == "german":
        age = rng.integers(18, 76, size=size)
        checking_status = rng.choice(["low", "medium", "high"], size=size)
        employment = np.where(age < 25, "short", rng.choice(["short", "medium", "long"], size=size, p=[0.25, 0.35, 0.4]))
        credit_amount = rng.normal(4200, 1900, size).clip(500, 15000).round()
        score = (
            0.7 * (age >= 35)
            + 0.45 * (checking_status == "high")
            + 0.4 * (employment == "long")
            - 0.00006 * credit_amount
            + rng.normal(0, 0.65, size)
        )
        credit_risk = np.where(score > 0.25, 1, 0)
        return pd.DataFrame(
            {
                "age": age,
                "checking_status": checking_status,
                "employment": employment,
                "credit_amount": credit_amount,
                "duration_months": rng.integers(6, 60, size=size),
                "housing": rng.choice(["own", "rent", "free"], size=size),
                "credit_risk": credit_risk,
            }
        )

    race = rng.choice(["African-American", "Caucasian", "Hispanic", "Asian", "Other"], size=size, p=[0.42, 0.34, 0.12, 0.04, 0.08])
    gender = rng.choice(["Male", "Female"], size=size, p=[0.78, 0.22])
    age = rng.integers(18, 70, size=size)
    age_cat = pd.cut(age, bins=[0, 25, 45, 200], labels=["Less than 25", "25 - 45", "Greater than 45"]).astype(str)
    priors_count = rng.poisson(np.where(race == "African-American", 4.5, 2.2)).clip(0, 20)
    juvenile_offenses = rng.poisson(np.where(race == "African-American", 1.6, 0.5)).clip(0, 8)
    score = (
        0.35 * (race == "African-American")
        + 0.25 * (gender == "Male")
        + 0.12 * (age < 25)
        + 0.16 * priors_count
        + 0.25 * juvenile_offenses
        + rng.normal(0, 0.8, size)
    )
    two_year_recid = (score > 1.2).astype(int)
    return pd.DataFrame(
        {
            "age": age,
            "gender": gender,
            "race": race,
            "age_cat": age_cat,
            "priors_count": priors_count,
            "juv_fel_count": juvenile_offenses,
            "c_charge_degree": rng.choice(["F", "M"], size=size, p=[0.64, 0.36]),
            "two_year_recid": two_year_recid,
        }
    )
