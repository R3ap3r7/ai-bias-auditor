from __future__ import annotations

from pathlib import Path

import pandas as pd

DEMO_DIR = Path(__file__).resolve().parent.parent / "data" / "demos"
DEMO_DIR.mkdir(parents=True, exist_ok=True)


def download_compas() -> None:
    url = "https://raw.githubusercontent.com/propublica/compas-analysis/master/compas-scores-two-years.csv"
    df = pd.read_csv(url)
    columns = [
        "age",
        "sex",
        "race",
        "age_cat",
        "priors_count",
        "juv_fel_count",
        "juv_misd_count",
        "c_charge_degree",
        "decile_score",
        "two_year_recid",
    ]
    selected = df[columns].rename(columns={"sex": "gender"}).dropna()
    selected.to_csv(DEMO_DIR / "compas.csv", index=False)


def download_adult() -> None:
    url = "https://archive.ics.uci.edu/ml/machine-learning-databases/adult/adult.data"
    columns = [
        "age",
        "workclass",
        "fnlwgt",
        "education",
        "education_num",
        "marital_status",
        "occupation",
        "relationship",
        "race",
        "sex",
        "capital_gain",
        "capital_loss",
        "hours_per_week",
        "native_country",
        "income",
    ]
    df = pd.read_csv(url, header=None, names=columns, na_values=[" ?"], skipinitialspace=True)
    df = df.dropna()
    df.to_csv(DEMO_DIR / "adult.csv", index=False)


def download_german() -> None:
    url = "https://archive.ics.uci.edu/ml/machine-learning-databases/statlog/german/german.data"
    columns = [
        "checking_status",
        "duration_months",
        "credit_history",
        "purpose",
        "credit_amount",
        "savings_status",
        "employment",
        "installment_rate",
        "personal_status_sex",
        "other_debtors",
        "residence_since",
        "property",
        "age",
        "other_installment_plans",
        "housing",
        "existing_credits",
        "job",
        "dependents",
        "telephone",
        "foreign_worker",
        "credit_risk_raw",
    ]
    df = pd.read_csv(url, sep=r"\s+", header=None, names=columns)
    df["credit_risk"] = df["credit_risk_raw"].map({1: 1, 2: 0})
    df = df.drop(columns=["credit_risk_raw"])
    df.to_csv(DEMO_DIR / "german_credit.csv", index=False)


def main() -> None:
    download_compas()
    download_adult()
    download_german()
    print(f"Demo datasets saved in {DEMO_DIR}")


if __name__ == "__main__":
    main()
