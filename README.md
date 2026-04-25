<div align="center">

# AI Bias Auditor

### *Local. Private. Fair.*

[![Python](https://img.shields.io/badge/Python-3.12-7c3aed?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-7c3aed?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![scikit-learn](https://img.shields.io/badge/scikit--learn-1.5+-7c3aed?style=for-the-badge&logo=scikitlearn&logoColor=white)](https://scikit-learn.org)
[![Fairlearn](https://img.shields.io/badge/Fairlearn-0.10+-7c3aed?style=for-the-badge&color=7c3aed)](https://fairlearn.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-7c3aed?style=for-the-badge)](LICENSE)

</div>

---

## About

Algorithmic bias is not a hypothetical risk — it is a documented, recurring harm. The **COMPAS recidivism algorithm** was found to predict higher recuse rates for Black defendants at nearly twice the rate of white defendants. Amazon scrapped an internal hiring algorithm after it systematically downgraded résumés that included the word *women's*. Credit scoring models trained on postcode data routinely encode historical redlining, penalising applicants not for their credit behaviour but for where they live. These systems cause real harm at scale, and most practitioners have no practical way to audit them before deployment.

**AI Bias Auditor** is a local, privacy-first fairness auditing tool that gives teams the ability to measure, understand, and document bias in their ML models — before a single prediction reaches a real person. Upload a CSV dataset and a trained model (or let AI Bias Auditor train one), mark your protected attributes, and receive a full fairness report covering demographic parity, equalized odds, disparate impact, proxy variable detection, intersectional group analysis, and row-level decision traces — all within minutes.

Raw datasets and uploaded model artifacts are processed by the audit engine and are not persisted by default. Optional Gemini reporting sends a compact audit summary, not raw CSV rows, to generate stakeholder language. Optional Firestore history stores report artifacts and aggregate governance metadata. For fully offline use, disable Gemini, leave Firestore unconfigured, and self-host frontend assets such as fonts and Chart.js.

---

## Features

| Feature | Description |
|---|---|
| **Data Pre-Audit** | Validates binary outcomes, detects group imbalance using the four-fifths rule, and reports missing-value imputation decisions before any model is trained |
| **Configurable Governance Policies** | Applies policy presets for default governance, employment screening, credit lending, medical triage, and low-risk internal tools |
| **Demographic Parity Difference** | Measures the maximum difference in positive prediction rates between groups for each protected attribute |
| **Equalized Odds Difference** | Measures the maximum gap in true positive and false positive rates across groups — penalising models that are accurate on average but unfair under the hood |
| **Disparate Impact Ratio** | Computes the ratio of the lowest to highest selection rate across groups; values below 0.8 violate the legal four-fifths rule |
| **Statistical Representation** | Reports the positive-outcome rate per protected group relative to the group with the highest rate, flagging ratios below 0.8 (warning) and 0.5 (danger) |
| **Proxy Variable Detection** | Identifies non-protected features that are strongly correlated with protected attributes using Pearson correlation, Cramér's V, and the correlation ratio — flagging features that may laundering discrimination |
| **Model Comparison Engine** | Trains and tunes all 9 supported classifiers, ranks them with policy-configurable accuracy/fairness weights, and marks models that fail policy constraints |
| **Decision Audit Traces** | Explains individual high-risk predictions using local baseline perturbation: for each flagged row, the contribution of each feature to the prediction is quantified |
| **Intersectional Bias Analysis** | Analyses combinatorial subgroups (e.g. `race=Black | sex=Female`) to detect bias that disappears in single-attribute averages |
| **Same-Background Fairness** | Stratified same-background cohort analysis: compares outcomes across protected groups after controlling for up to three non-protected features, isolating discrimination from confounding |
| **Mitigation Simulation** | Rapid diagnostic simulation that retrains the model after dropping protected attributes and high-risk proxy features to estimate potential fairness gains |
| **PDF Reports** | Exports a full audit report as a structured PDF including traceability metadata (run ID, dataset SHA-256 hash, model fingerprint) suitable for governance documentation |
| **Persistent Audit History** | Stores JSON/PDF audit artifacts locally and can mirror report summaries to Firestore when Google credentials are configured |
| **Safer Prediction CSV Mode** | Audits externally generated prediction CSVs without loading unsafe pickle/joblib artifacts |
| **Optional Gemini Integration** | When a `GEMINI_API_KEY` is configured, Gemini 2.5 Flash generates a plain-English narrative report for non-technical stakeholders from a compact, anonymised audit summary |

---

## How It Works

### Step 1 — Upload or select a dataset

Navigate to [http://127.0.0.1:8000/audit](http://127.0.0.1:8000/audit). Upload any CSV file, or choose one of the three preloaded benchmark datasets. AI Bias Auditor profiles the uploaded data immediately — reporting row count, column count, missing value rates, and a five-row preview.

### Step 2 — Configure protected attributes and outcome column

The column configuration table lists every column in your dataset. Toggle the **Protected Attribute** switch for each column you want to monitor for fairness (e.g. `race`, `sex`, `age`). Select the binary **Outcome Column** (the prediction target), choose a governance policy, choose a report template, choose same-background control variables, and select whether to train a model, audit an uploaded model, or audit a prediction CSV.

### Step 3 — Run pre-audit and/or post-model audit

Click **Run Data Pre-Audit** to check for data-level fairness issues — group imbalance, proxy variable risks, and validation warnings — before any model is involved. This step is fast and does not require model training. When you are ready, click **Run Post-Model Audit** to train (or evaluate) the model and compute the full fairness scorecard.

### Step 4 — Explore results and export your PDF report

Results are organised across seven tabs:

- **Overview** — dataset stats and data cleaning log
- **Data Pre-Audit** — validation checks, representation ratios, proxy variable flags
- **Bias Scorecard** — per-attribute demographic parity, equalized odds, and disparate impact with interactive charts
- **Model Comparison** — ranked table and bar chart of all nine tuned candidates with their audit scores
- **Decision Traces** — governance metadata, same-background fairness analysis, intersectional bias, and row-level explanations
- **Features** — normalised feature importance bars, bias source links, and mitigation simulation
- **Report** — plain-English narrative (Gemini or local deterministic) with a **Download PDF** button

---

## Demo Datasets

| Dataset | Domain | Rows | Protected Attributes | Use Case |
|---|---|---|---|---|
| **COMPAS Criminal Justice** | Criminal justice | 7,214 | `race`, `gender`, `age_cat` | Audit recidivism risk scores for racial and gender bias |
| **UCI Adult Income** | Income prediction | ~48,800 | `sex`, `race` | Detect gender and racial bias in income classification |
| **German Credit Risk** | Credit scoring | 1,000 | `age` | Assess age-based discrimination in credit decisions |

Three CSV demos are bundled in `data/demos/` for immediate local and Docker use. The optional `scripts/download_demos.py` script can refresh larger source datasets, but it is not required for the default demo flow.

Demo sources:

- COMPAS: [ProPublica `compas-analysis`](https://github.com/propublica/compas-analysis), including `compas-scores-two-years.csv`.
- Adult Income: [UCI Machine Learning Repository Adult dataset](https://archive.ics.uci.edu/dataset/2/adult).
- German Credit: [UCI Machine Learning Repository Statlog German Credit dataset](https://archive.ics.uci.edu/dataset/144/statlog+german+credit+data).

---

## Governance Policies

Policy presets live in `policies/` and are selected from the audit workspace:

- `default_governance_v1`
- `employment_screening_strict`
- `credit_lending_strict`
- `medical_triage_strict`
- `low_risk_internal_tool`

Each policy configures fairness thresholds, severity weights, deployment-decision thresholds, model-selection weights, and protected-attribute grouping rules. Every audit records the policy ID and version in traceability metadata, report JSON, and PDF exports.

## Persistence

Audit sessions still keep raw uploaded datasets and unsafe model artifacts in process memory only. Completed reports are persisted as JSON under `data/audit_history/` and are exposed through `/history` and `/api/history`. When `google-cloud-firestore` is installed and `FIRESTORE_PROJECT_ID` plus credentials are configured, report summaries and report JSON are mirrored to Firestore collections `auditRuns` and `reports`.

The stored artifact intentionally avoids raw CSV persistence by default. It stores dataset hashes, model fingerprints, aggregate metrics, policy metadata, report text, severity, and deployment decisions.

## Supported Scope and Limitations

Supported now:

- Tabular binary classification.
- Locally trained sklearn-compatible model families.
- Trusted uploaded pickle/joblib models with a visible unsafe-artifact warning.
- Safer prediction-CSV audits for external models.
- Configurable policy thresholds, severity scoring, model-selection scoring, grouping presets, report templates, and user-selected same-background controls.

Not yet supported:

- Regression fairness.
- Ranking/recommendation fairness.
- Multiclass fairness.
- LLM, image, audio, or generative-model bias audits.
- ONNX Runtime Web, Web Workers, WebGPU, or browser-side model execution.

The report includes a limitations section because fairness metrics are governance evidence, not proof of legal compliance or causal discrimination.

---

## Setup & Installation

### Prerequisites

- Python 3.11 or 3.12 (required — `datetime.UTC` was introduced in Python 3.11)
- [`uv`](https://github.com/astral-sh/uv) package manager (recommended) or `pip`

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/R3ap3r7/ai-bias-auditor.git
cd ai-bias-auditor

# 2. Create a virtual environment with Python 3.12
uv venv --python 3.12
source .venv/bin/activate  # Windows: .venv\Scripts\activate

# 3. Install dependencies
uv pip install -r requirements.txt

# 4. Start the development server
.venv/bin/uvicorn app.main:app --reload

# 5. Open in your browser
# http://127.0.0.1:8000
```

> [!IMPORTANT]
> Always launch using `.venv/bin/uvicorn` (not a globally installed `uvicorn`) to ensure the Python 3.12 interpreter from your virtual environment is used. `datetime.UTC` requires Python 3.11+; using an older system Python will cause an `ImportError` at startup.

### Optional: Gemini AI Integration

To enable plain-English AI-written audit summaries, create a `.env` file in the project root:

```bash
cp .env.example .env
```

Then add your key:

```env
GEMINI_API_KEY=your_google_ai_studio_key_here
GEMINI_MODEL=gemini-2.5-flash   # optional, this is the default
```

Get a free API key at [aistudio.google.com](https://aistudio.google.com). When no key is configured, AI Bias Auditor falls back to a deterministic local report automatically.

---

## Project Structure

```
ai-bias-auditor/
│
├── app/                        # FastAPI application package
│   ├── main.py                 # API routes: /, /audit, /history, /api/upload, /api/audit, /api/report
│   ├── audit.py                # Core audit engine: cleaning, fairness metrics, model training, traces
│   ├── governance.py           # Policy scoring, grouping, model-selection, and deployment decisions
│   ├── policies.py             # Policy loading and validation
│   ├── report.py               # PDF report generation via ReportLab
│   ├── storage.py              # Local persistent history plus optional Firestore mirroring
│   ├── demo_data.py            # Demo dataset registry and loader
│   │
│   ├── static/
│   │   ├── app.js              # Frontend application logic, API calls, result rendering
│   │   ├── audit.js            # Audit workspace: tab system, Chart.js charts, toggle switches
│   │   ├── audit.css           # Audit workspace design system (dark theme, toggles, tabs)
│   │   ├── landing.js          # Landing page animations, parallax, intersection observer
│   │   ├── landing.css         # Landing page design system (glassmorphism, gradients)
│   │   └── styles.css          # Base CSS variables and shared utility classes
│   │
│   └── templates/
│       ├── index.html          # Marketing landing page served at /
│       └── audit.html          # Audit workspace served at /audit
│
├── data/
│   └── demos/                  # Bundled demo CSVs (compas.csv, adult.csv, german_credit.csv)
│
├── policies/                   # Configurable governance policy presets
│
├── scripts/
│   └── download_demos.py       # Optional refresh script for source demo datasets
│
├── tests/
│   └── test_audit.py           # pytest test suite for the audit engine
│
├── .env.example                # Environment variable template
├── Dockerfile                  # Container build for deployment
├── pyproject.toml              # Project metadata and dependency spec (requires-python >=3.11,<3.14)
├── requirements.txt            # Pinned dependency list
└── README.md                   # This file
```

---

## Fairness Metrics Explained

AI Bias Auditor computes four primary fairness metrics per protected attribute. All metrics are computed on the **held-out test split** (20% of the dataset) to reflect true generalisation behaviour.

### Demographic Parity Difference
> *Are positive predictions given at similar rates to all groups?*

The maximum difference in positive **prediction** rate (selection rate) between any two groups. A value of `0.0` means every group receives positive predictions at exactly the same rate. Values above `0.1` are flagged Medium; above `0.2` are flagged High or Critical. Implemented via `fairlearn.metrics.demographic_parity_difference`.

### Equalized Odds Difference
> *Does the model make the same types of errors for all groups?*

The maximum difference in **true positive rate** (TPR) or **false positive rate** (FPR) between groups — whichever gap is larger. A model that is equally accurate overall can still have dramatically different error profiles across groups. Values follow the same thresholds as demographic parity (>0.1 = Medium, >0.2 = High, >0.3 = Critical). Implemented via `fairlearn.metrics.equalized_odds_difference`.

### Disparate Impact Ratio
> *Does the group with the lowest selection rate receive at least 80% of the rate of the best-served group?*

Computed as: `min(selection_rate across groups) / max(selection_rate across groups)`. A ratio below **0.8** violates the EEOC four-fifths rule — the legal standard used in US employment discrimination law. A value of `1.0` is ideal; `0.0` means one group receives no positive predictions at all.

### Statistical Parity Difference (Representation Ratio)
> *Are all groups represented fairly in the training data's positive outcomes?*

Measured during the **Data Pre-Audit** phase, before model training. For each group within a protected attribute, AI Bias Auditor computes the ratio of that group's positive outcome rate to the group with the highest rate. Ratios below `0.8` are warned; below `0.5` are flagged Red. This is distinct from demographic parity difference because it measures the **data distribution**, not the model's predictions.

---

## Tech Stack

| Technology | Purpose |
|---|---|
| **Python 3.12** | Primary runtime; `datetime.UTC` requires 3.11+ |
| **FastAPI 0.115+** | REST API framework; serves HTML templates and JSON endpoints |
| **uvicorn** | ASGI server with hot-reload for development |
| **scikit-learn 1.5+** | Model training, preprocessing pipelines, hyperparameter tuning via `GridSearchCV` |
| **Fairlearn 0.10+** | `demographic_parity_difference` and `equalized_odds_difference` computation |
| **Pandas 2.2+** | Data cleaning, group aggregation, missing-value imputation |
| **NumPy 1.26+** | Numerical operations and array-level metric computation |
| **SciPy 1.13+** | Pearson correlation and chi-squared tests for proxy variable detection |
| **ReportLab 4.2+** | PDF report generation with styled tables and traceability metadata |
| **Jinja2 3.1+** | Server-side HTML templating |
| **Chart.js 4.4** | Interactive bar charts for representation, bias, model comparison, and feature importance |
| **Google Generative AI 0.8+** | Optional Gemini 2.5 Flash integration for plain-English narrative reports |
| **python-dotenv** | `.env` file loading for API key configuration |

---

## Contributing

Contributions are warmly welcome. If you find a bug, have a feature idea, or want to improve the fairness metric coverage, please:

1. **Open an issue** describing the problem or proposal
2. **Fork the repository** and create a feature branch
3. **Submit a pull request** — include a short description and, where applicable, a new test in `tests/test_audit.py`

Please ensure `pytest` passes before submitting:

```bash
pytest tests/
```

---

## License

This project is licensed under the **MIT License**. See [`LICENSE`](LICENSE) for details.

---

<div align="center">

Made with ❤️ for Solution Challenge '26

</div>
