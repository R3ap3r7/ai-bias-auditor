<div align="center">

<br/>

<!-- ANIMATED HEADER SVG -->
<img src="https://readme-typing-svg.demolab.com?font=Syne&weight=800&size=15&duration=3000&pause=1000&color=7C3AED&center=true&vCenter=true&multiline=true&repeat=false&width=600&height=50&lines=Open-Source+%7C+Privacy-First+%7C+Google+Solution+Challenge+%2726" alt="Themis tagline" />

<br/>

# ⚖️ THEMIS

### *AI Bias Auditor — Detect Bias Before It Causes Harm*

<br/>

<!-- BADGES ROW 1 -->
[![Python](https://img.shields.io/badge/Python-3.12-7c3aed?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-06b6d4?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Flutter-Web-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth+Firestore-FF6F00?style=for-the-badge&logo=firebase&logoColor=white)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-22c55e?style=for-the-badge)](LICENSE)

<!-- BADGES ROW 2 -->
[![scikit-learn](https://img.shields.io/badge/scikit--learn-1.5+-f97316?style=for-the-badge&logo=scikitlearn&logoColor=white)](https://scikit-learn.org)
[![Fairlearn](https://img.shields.io/badge/Fairlearn-0.10+-a855f7?style=for-the-badge)](https://fairlearn.org)
[![Gemini](https://img.shields.io/badge/Gemini-2.5_Flash-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://aistudio.google.com)
[![ReportLab](https://img.shields.io/badge/ReportLab-PDF_Export-ef4444?style=for-the-badge)](https://reportlab.com)
[![Status](https://img.shields.io/badge/Status-Active_Dev-7c3aed?style=for-the-badge&logo=statuspage&logoColor=white)]()

<br/>

<img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&size=13&duration=2000&pause=500&color=94A3B8&center=true&vCenter=true&multiline=false&width=700&lines=Train+9+models.+Compute+6+fairness+metrics.+Export+PDF+reports.+100%25+local.;COMPAS+%7C+UCI+Adult+%7C+German+Credit+—+3+benchmark+datasets+built+in.;Detect+proxy+variables+%7C+Intersectional+bias+%7C+Decision+traces." alt="features typing" />

<br/><br/>

---

</div>

<br/>

## Table of Contents

| # | Section | Description |
|---|---------|-------------|
| 01 | [**The Problem**](#-the-problem) | Why algorithmic bias is a documented, recurring harm |
| 02 | [**What is Themis**](#-what-is-themis) | Mission, philosophy, and core guarantees |
| 03 | [**Architecture**](#-architecture) | System design, data flow, component map |
| 04 | [**Feature Deep-Dive**](#-feature-deep-dive) | Every capability explained in detail |
| 05 | [**Fairness Metrics**](#-fairness-metrics-explained) | The math behind demographic parity, equalized odds, disparate impact |
| 06 | [**Demo Datasets**](#-demo-datasets) | COMPAS, UCI Adult, German Credit |
| 07 | [**Governance Policies**](#-governance-policies) | Policy presets and threshold configuration |
| 08 | [**Tech Stack**](#-tech-stack) | Every dependency and why it was chosen |
| 09 | [**File Structure**](#-file-structure) | Complete annotated project layout |
| 10 | [**API Reference**](#-api-reference) | Every endpoint documented |
| 11 | [**Setup & Installation**](#-setup--installation) | Backend, frontend, Firebase — step by step |
| 12 | [**User Workflow**](#-user-workflow) | End-to-end journey from upload to PDF |
| 13 | [**Design System**](#-design-system) | Colors, typography, components |
| 14 | [**Security & Privacy**](#-security--privacy) | Local-first model, CORS, data handling |
| 15 | [**Firebase Integration**](#-firebase-integration) | Auth, Firestore schema, Security Rules |
| 16 | [**Environment Config**](#-environment-configuration) | All `.env` variables documented |
| 17 | [**Current Status**](#-current-status) | What's done, what's in progress |
| 18 | [**Roadmap**](#-roadmap) | Future enhancements planned |
| 19 | [**Contributing**](#-contributing) | How to contribute |
| 20 | [**License**](#-license) | MIT |

<br/>

---

<br/>

## The Problem

> *"Algorithmic bias is not a hypothetical risk — it is a documented, recurring harm."*

These are not hypothetical edge cases. They are real systems that affected real people:

<br/>

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         REAL-WORLD BIAS INCIDENTS                           │
├──────────────────────┬──────────────────────────────────────────────────────┤
│    COMPAS (2016)   │  Assigned 2× higher recidivism risk to Black         │
│                      │  defendants vs. white defendants with equal history  │
├──────────────────────┼──────────────────────────────────────────────────────┤
│   Amazon (2018)    │  Hiring model penalised résumés containing the word  │
│                      │  "women's" — trained on 10 years of male applicants  │
├──────────────────────┼──────────────────────────────────────────────────────┤
│   Credit Scoring   │  Postcode-based models encode historical redlining,  │
│     (Ongoing)        │  punishing applicants for geography, not credit      │
├──────────────────────┼──────────────────────────────────────────────────────┤
│   Healthcare AI    │  Commercial tool assigned lower risk scores to Black │
│     (2019)           │  patients with the same clinical needs as white ones │
└──────────────────────┴──────────────────────────────────────────────────────┘
```

<br/>

Most practitioners have **no practical, affordable way** to audit their models before deployment. Existing tools are either enterprise-gated, cloud-only (forcing you to upload sensitive data), or require deep ML expertise.

**Themis fills this gap.**

<br/>

---

<br/>

## 🏛️ What is Themis

**Themis** is an open-source, **privacy-first ML fairness auditing platform** that gives teams the ability to measure, understand, and document bias in their machine learning models — **before a single prediction reaches a real person.**

<br/>

```
╔═══════════════════════════════════════════════════════════════╗
║                    THEMIS CORE PROMISES                       ║
╠═══════════════════════════════════════════════════════════════╣
║    100% LOCAL      │  Your data never leaves your machine  ║
║    FAST            │  9 models trained + ranked in minutes ║
║    COMPREHENSIVE   │  6 fairness metrics per attribute      ║
║    AUDITABLE       │  Row-level decision traces, PDF export ║
║    FREE            │  MIT licensed, no SaaS subscriptions  ║
║    OPTIONAL CLOUD  │  Firebase is opt-in, not required      ║
╚═══════════════════════════════════════════════════════════════╝
```

<br/>

Upload a CSV, mark your protected attributes, and receive a full fairness report covering:
- **Demographic parity** across every protected group
- **Equalized odds** analysis (true positive + false positive rate gaps)
- **Disparate impact** ratios (four-fifths rule detection)
- **Proxy variable** detection (correlation-based laundering of discrimination)
- **Intersectional bias** (e.g. `race=Black AND sex=Female` subgroup analysis)
- **Row-level decision traces** with feature attribution for individual predictions

<br/>

---

<br/>

##  Architecture

Themis follows a clean **client-server architecture** with strict separation between the audit engine and the UI layer.

<br/>

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              THEMIS SYSTEM ARCHITECTURE                         │
└─────────────────────────────────────────────────────────────────────────────────┘

  USER BROWSER
  ┌──────────────────────────────────────────────────────┐
  │              Flutter Web Frontend  :5050             │
  │  ┌────────────┐ ┌────────────┐ ┌──────────────────┐ │
  │  │  Landing   │ │   Audit    │ │    Dashboard      │ │
  │  │   Page     │ │   Page     │ │  (Auth-Gated)     │ │
  │  └────────────┘ └─────┬──────┘ └────────┬─────────┘ │
  │                       │                 │           │
  │              backend_client.dart        │           │
  │              audit_repository.dart      │           │
  └───────────────────────┼─────────────────┼───────────┘
                          │ HTTP/REST        │ Firestore SDK
                          ▼                 ▼
  ┌──────────────────────────────┐   ┌─────────────────────────┐
  │   FastAPI Backend  :8000     │   │   Firebase Cloud         │
  │  ┌──────────┬──────────────┐ │   │  ┌─────────────────────┐│
  │  │ main.py  │   audit.py   │ │   │  │  Firestore           ││
  │  │ (routes) │  (engine)    │ │   │  │  users/{uid}/audits  ││
  │  └──────────┴──────┬───────┘ │   │  └─────────────────────┘│
  │  ┌──────────┬──────┘         │   │  ┌─────────────────────┐│
  │  │report.py │ storage.py     │   │  │  Firebase Auth       ││
  │  │  (PDF)   │ (history)      │◄──┤  │  Google Sign-In      ││
  │  └──────────┴────────────────┘   │  └─────────────────────┘│
  │  ┌──────────┬────────────────┐   │  ┌─────────────────────┐│
  │  │policies/ │  demo_data.py  │   │  │  Firebase Storage    ││
  │  │(presets) │  (3 datasets)  │   │  │  (trace JSON files)  ││
  │  └──────────┴────────────────┘   │  └─────────────────────┘│
  └──────────────────────────────┘   └─────────────────────────┘

  OPTIONAL EXTERNAL:
  ┌───────────────────────────────┐
  │  Gemini 2.5 Flash API         │
  │  Compact audit summary → IN   │
  │  Plain-English narrative → OUT│
  │  (raw CSV rows NEVER sent)    │
  └───────────────────────────────┘
```

<br/>

### Component Responsibilities

| Component | Language | Port | Responsibility |
|-----------|----------|------|----------------|
| **Flutter Web** | Dart | `:5050` | User-facing UI: audit setup, results viewer, dashboard |
| **FastAPI** | Python 3.12 | `:8000` | REST API, audit engine, model training, PDF generation |
| **Firebase Auth** | — | Cloud | Google Sign-In, guest mode support |
| **Firestore** | — | Cloud | Persisting audit history per user (opt-in) |
| **Firebase Storage** | — | Cloud | Large decision trace JSON blobs (opt-in) |
| **Gemini API** | — | External | Advisory narrative generation from anonymised summary |

<br/>

### Data Flow — Full Audit

```
  CSV Upload
      │
      ▼
  ┌─────────────────────┐
  │   /api/upload        │  POST — validates, profiles, returns column list
  └──────────┬──────────┘
             │
             ▼
  ┌─────────────────────┐
  │   /api/pre-audit     │  POST — representation checks, proxy detection,
  └──────────┬──────────┘         severity rating (NO model training)
             │
             ▼
  ┌─────────────────────┐
  │   /api/audit         │  POST — train 9 models via GridSearchCV,
  │                      │         compute fairness metrics per model,
  │                      │         generate decision traces for flagged rows,
  │                      │         intersectional analysis, mitigation sim
  └──────────┬──────────┘
             │
      ┌──────┴──────┐
      ▼             ▼
  Results        /api/report/{run_id}
  → Flutter      → PDF via ReportLab
  UI Tabs        → Optional Firestore mirror
```

<br/>

---

<br/>

## 🔬 Feature Deep-Dive

<br/>

### 1 — Data Pre-Audit Analysis

Before any model touches the data, Themis runs a **data-level fairness check**. This step is fast (< 2s on most datasets) and catches problems that no amount of model tuning can fix.

```
PRE-AUDIT CHECKS
├──  Binary outcome validation
│     Confirms target column is binary (0/1) and flags any issues
│
├──  Representation Balance (Four-Fifths Rule)
│     For each protected attribute, for each group:
│     ratio = group_positive_rate / max_positive_rate_across_groups
│     • ratio < 0.8  → ⚠️  WARNING (amber)
│     • ratio < 0.5  → 🔴 DANGER  (red)
│
├──  Proxy Variable Detection
│     Numerical features   → Pearson correlation with protected attributes
│     Categorical features → Cramér's V statistic
│     Mixed pairs          → Correlation ratio (eta²)
│     • |r| > 0.5 or V > 0.3 → flagged as HIGH-RISK proxy
│     • |r| > 0.3 or V > 0.1 → flagged as MODERATE proxy
│
└── 🧹 Missing Value Imputation Log
      Records every imputation decision (median/mode/drop)
      so the audit trail is complete
```

<br/>

### 2 — Fairness Metrics Engine

Six industry-standard metrics computed on the **held-out 20% test split**:

| Metric | What It Measures | Threshold (High) | Library |
|--------|-----------------|-----------------|---------|
| **Demographic Parity Difference** | Gap in positive prediction rates between groups | > 0.2 | Fairlearn |
| **Equalized Odds Difference** | Max gap in TPR or FPR between groups | > 0.2 | Fairlearn |
| **Disparate Impact Ratio** | `min_selection_rate / max_selection_rate` | < 0.8 | Custom |
| **Statistical Representation** | Data-level positive rate ratio per group | < 0.8 | Custom |
| **Intersectional Parity** | Same metrics on combinatorial subgroups | > 0.25 | Custom |
| **Same-Background Fairness** | Within-cohort controlled comparison | > 0.2 | Custom |

<br/>

### 3 — Model Comparison Engine

Themis trains **9 ML algorithms simultaneously**, each hyperparameter-tuned via `GridSearchCV`:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MODEL COMPARISON ENGINE                          │
├──────────────────────┬────────────────────────────────────────────┤
│  Algorithm           │  GridSearch Params                         │
├──────────────────────┼────────────────────────────────────────────┤
│  Logistic Regression │  C, solver, max_iter                       │
│  Random Forest       │  n_estimators, max_depth, min_samples_split│
│  Gradient Boosting   │  n_estimators, learning_rate, max_depth    │
│  Support Vector M.   │  C, kernel, gamma                          │
│  Decision Tree       │  max_depth, min_samples_split, criterion   │
│  K-Nearest Neighbors │  n_neighbors, weights, metric              │
│  Naive Bayes         │  var_smoothing                             │
│  AdaBoost            │  n_estimators, learning_rate               │
│  Extra Trees         │  n_estimators, max_depth                   │
└──────────────────────┴────────────────────────────────────────────┘

RANKING FORMULA (policy-configurable weights):
  audit_score = (accuracy_weight × balanced_accuracy)
              - (fairness_weight × max_fairness_gap)

  • Models that FAIL policy thresholds are MARKED and excluded from
    deployment recommendations regardless of accuracy score
```

<br/>

### 4 — Decision Audit Traces

Every **high-risk prediction** is individually explainable. Themis uses a **local baseline perturbation** method — no external SHAP dependency required.

```
For each flagged row:
  1. Record baseline prediction (all features at median/mode)
  2. For each feature f:
       • Set f to its actual value; keep all others at baseline
       • Measure Δprobability vs baseline
       • Δprob = feature_contribution[f]
  3. Sort by |feature_contribution| descending
  4. Return top-k drivers with direction (↑ increases risk, ↓ reduces)

Output per row:
  {
    "row_id": 142,
    "prediction": 1,
    "probability": 0.87,
    "protected_group": { "race": "Black", "sex": "Male" },
    "drivers": [
      { "feature": "prior_count",   "contribution": +0.31, "value": 7 },
      { "feature": "age",           "contribution": +0.18, "value": 21 },
      { "feature": "charge_degree", "contribution": +0.09, "value": "F" }
    ]
  }
```

<br/>

### 5 — Intersectional Bias Analysis

Single-attribute fairness can **mask** intersectional harm. Themis goes deeper:

```
Example with race + sex:
  ┌──────────────┬────────┬──────────────────┬─────────────────┐
  │  Subgroup    │  Size  │  Selection Rate  │  Parity Ratio   │
  ├──────────────┼────────┼──────────────────┼─────────────────┤
  │  White Male  │  2,841 │     38.2%        │  1.000 (ref)    │
  │  White Female│    982 │     34.1%        │  0.893          │
  │  Black Male  │  2,101 │     27.6%        │  0.723          │
  │  Black Female│    476 │     19.3%        │  0.505          │
  └──────────────┴────────┴──────────────────┴─────────────────┘

  → Race alone shows 0.72 ratio (flagged)
  → But Black Female subgroup is 0.50 — much worse
  → Single-attribute analysis would have HIDDEN this
```

<br/>

### 6 — Same-Background Fairness

Controls for confounding by comparing protected groups **within feature-defined cohorts**:

```
User selects control variables: e.g. ["age_cat", "prior_count_cat"]

Themis groups dataset into cohorts where these variables are identical,
then computes selection rate differences within each cohort.

Within cohort (age=25-45, prior=1-3):
  Black defendants: 31.2% positive
  White defendants: 34.8% positive
  Δ = 3.6pp  (vs 10.6pp unadjusted)

Interpretation: ~7pp of the raw gap is explained by the control variables.
The residual 3.6pp may indicate direct bias in the model.
```

<br/>

### 7 — Mitigation Simulation

A rapid diagnostic that **estimates potential fairness gains** from feature removal:

```
1. Drop all protected attributes from feature set
2. Drop all features flagged as HIGH-RISK proxies
3. Retrain best-performing model on cleaned feature set
4. Compare fairness metrics before / after

Output:
  Demographic Parity Diff:  0.21 → 0.09  (↓57% improvement)
  Equalized Odds Diff:      0.18 → 0.11  (↓39% improvement)
  Balanced Accuracy:        0.74 → 0.71  (↓4% cost)
```

> **Note:** This is a diagnostic simulation, not a deployment-ready solution.

<br/>

### 8 — PDF Report Generation

Themis generates **governance-grade PDF reports** via ReportLab:

```
REPORT CONTENTS
├── Cover page (run ID, dataset hash, timestamp, policy used)
├── Executive Summary
├── Dataset Profile (rows, columns, missing values, imputation log)
├── Pre-Audit Findings (representation ratios, proxy flags)
├── Model Comparison Table (all 9 models, ranked)
├── Fairness Scorecard (per-attribute, per-metric)
├── Intersectional Analysis
├── Same-Background Analysis
├── Decision Traces (sample of flagged predictions)
├── Mitigation Simulation Results
├── Governance Policy Applied
├── Limitations & Disclaimers
└── Methodology Notes

Traceability metadata on every page:
  Run ID: themis_20260104_143022_a7f3c
  Dataset SHA-256: 3f4a9b2c...
  Model Fingerprint: rf_v1_4e8d...
  Policy: employment_screening_strict v1.2
```

<br/>

### 9 — LLM Narrative (Gemini Integration)

When `GEMINI_API_KEY` is configured, Themis sends a **compact, anonymised audit summary** (never raw CSV rows) to Gemini 2.5 Flash and receives a structured JSON narrative with these sections:

```json
{
  "executive_summary": "...",
  "severity_assessment": "...",
  "key_findings": [...],
  "protected_attribute_analysis": {...},
  "proxy_variables": [...],
  "compliance_notes": "...",
  "remediation_roadmap": [...],
  "methodology": "..."
}
```

If no API key is configured, Themis falls back to a **deterministic local report** automatically — no degraded experience, no error.

<br/>

---

<br/>

## 📐 Fairness Metrics Explained

<br/>

### Demographic Parity Difference

> *Are positive predictions given at similar rates to all groups?*

$$\text{DPD} = \max_{g \in G} P(\hat{Y}=1 \mid A=g) - \min_{g \in G} P(\hat{Y}=1 \mid A=g)$$

```
  Group A selection rate: 38.2%     ████████████████████░░░░░
  Group B selection rate: 27.6%     ██████████████░░░░░░░░░░░

  DPD = 0.382 - 0.276 = 0.106

  Interpretation:
  • DPD = 0.00  → Perfect demographic parity
  • DPD < 0.10  → Low    (green)
  • DPD < 0.20  → Medium (amber)
  • DPD < 0.30  → High   (orange)
  • DPD ≥ 0.30  → Critical (red)
```

<br/>

### Equalized Odds Difference

> *Does the model make the same types of errors for all groups?*

$$\text{EOD} = \max\left( |TPR_A - TPR_B|,\ |FPR_A - FPR_B| \right)$$

```
  True Positive Rate:
    Group A: 72.1%    ████████████████████████████████████░░░░
    Group B: 58.4%    █████████████████████████████░░░░░░░░░░░
    TPR gap: 13.7pp

  False Positive Rate:
    Group A: 15.3%    ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
    Group B: 24.8%    ████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░
    FPR gap: 9.5pp

  EOD = max(0.137, 0.095) = 0.137  → MEDIUM
```

<br/>

### Disparate Impact Ratio

> *Does the lowest-served group receive at least 80% of the best-served group's rate?*

$$\text{DIR} = \frac{\min_{g \in G} P(\hat{Y}=1 \mid A=g)}{\max_{g \in G} P(\hat{Y}=1 \mid A=g)}$$

```
  DIR = 0.276 / 0.382 = 0.723

  The four-fifths (80%) rule:
  ├── DIR ≥ 0.80  →   Passes adverse impact screen
  ├── DIR < 0.80  →   May indicate adverse impact — review required
  └── DIR < 0.50  →   Severe adverse impact

  DIR of 0.723 falls BELOW the 0.80 threshold → FLAG
```

<br/>

### Severity Scoring System

```
┌──────────────────────────────────────────────────────────┐
│                  SEVERITY RATING MATRIX                  │
├──────────────┬───────────┬──────────────────────────────┤
│  Level       │  Color    │  Criteria                    │
├──────────────┼───────────┼──────────────────────────────┤
│  LOW         │   Green   │  All metrics within policy   │
│  MEDIUM      │   Amber   │  1-2 metrics exceed soft     │
│  HIGH        │   Orange  │  Any metric exceeds hard     │
│  CRITICAL    │   Red     │  Multiple hard thresholds or │
│              │           │  DIR < 0.50                  │
└──────────────┴───────────┴──────────────────────────────┘
```

<br/>

---

<br/>

## Demo Datasets

Three curated benchmark datasets ship with Themis — no download required.

<br/>

### COMPAS Criminal Justice Dataset

```
┌─────────────────────────────────────────────────────────────┐
│     compas.csv                                              │
├─────────────────────────────────────────────────────────────┤
│  Source       ProPublica compas-analysis                    │
│  Rows         7,214                                         │
│  Outcome      two_year_recid (0/1)                          │
│  Protected    race, gender, age_cat                         │
│  Recommended  employment_screening_strict policy            │
├─────────────────────────────────────────────────────────────┤
│  WHY IT MATTERS                                             │
│  This is the dataset that exposed real-world algorithmic    │
│  bias in the US criminal justice system. Themis lets you   │
│  reproduce and verify those findings yourself.             │
└─────────────────────────────────────────────────────────────┘
```

<br/>

### UCI Adult Income Dataset

```
┌─────────────────────────────────────────────────────────────┐
│     adult.csv                                               │
├─────────────────────────────────────────────────────────────┤
│  Source       UCI Machine Learning Repository               │
│  Rows         48,842                                        │
│  Outcome      income >$50K (0/1)                            │
│  Protected    sex, race                                     │
│  Recommended  default_governance_v1 policy                  │
├─────────────────────────────────────────────────────────────┤
│  WHY IT MATTERS                                             │
│  The classic fairness benchmark. Tests gender and racial    │
│  bias in income prediction — a proxy for hiring and credit. │
└─────────────────────────────────────────────────────────────┘
```

<br/>

### German Credit Risk Dataset

```
┌─────────────────────────────────────────────────────────────┐
│     german_credit.csv                                       │
├─────────────────────────────────────────────────────────────┤
│  Source       UCI Statlog German Credit                     │
│  Rows         1,000                                         │
│  Outcome      credit_risk (0=bad, 1=good)                   │
│  Protected    age                                           │
│  Recommended  credit_lending_strict policy                  │
├─────────────────────────────────────────────────────────────┤
│  WHY IT MATTERS                                             │
│  Tests age discrimination in credit decisions — a legally   │
│  protected attribute in most jurisdictions.                 │
└─────────────────────────────────────────────────────────────┘
```

<br/>

---

<br/>

## Governance Policies

Themis ships with **five configurable policy presets**, each with different fairness thresholds, accuracy/fairness weighting, and protected attribute grouping rules.

<br/>

```
POLICY PRESETS
│
├── default_governance_v1
│     Accuracy weight:  0.6
│     Fairness weight:  0.4
│     DPD threshold:    0.20 (medium cutoff)
│     EOD threshold:    0.20
│     DIR threshold:    0.80
│     Use when:         General-purpose auditing, internal tools
│
├── employment_screening_strict
│     Accuracy weight:  0.4
│     Fairness weight:  0.6
│     DPD threshold:    0.10 (strict)
│     EOD threshold:    0.10
│     DIR threshold:    0.80
│     Use when:         Hiring algorithms, promotion systems
│
├── credit_lending_strict
│     Accuracy weight:  0.4
│     Fairness weight:  0.6
│     DPD threshold:    0.10
│     EOD threshold:    0.10
│     DIR threshold:    0.80
│     Use when:         Credit scoring, loan approval systems
│
├── medical_triage_strict
│     Accuracy weight:  0.3
│     Fairness weight:  0.7
│     DPD threshold:    0.05 (most strict)
│     EOD threshold:    0.05
│     DIR threshold:    0.90
│     Use when:         Clinical risk scoring, resource allocation
│
└── low_risk_internal_tool
      Accuracy weight:  0.7
      Fairness weight:  0.3
      DPD threshold:    0.30 (relaxed)
      EOD threshold:    0.30
      DIR threshold:    0.70
      Use when:         Internal recommendation systems, low-stakes tools
```

<br/>

Every audit records:
- Policy ID and version in the PDF
- Policy thresholds used for all severity determinations
- Model selection weights applied to ranking

<br/>

---

<br/>

## 🛠️ Tech Stack

<br/>

### Backend

| Library | Version | Purpose |
|---------|---------|---------|
| **FastAPI** | ≥ 0.115.0 | REST API framework, async route handlers, OpenAPI docs |
| **Uvicorn** | ≥ 0.30.0 | ASGI server with hot-reload for development |
| **scikit-learn** | ≥ 1.5.0 | All 9 ML algorithms, `GridSearchCV`, preprocessing pipelines |
| **Fairlearn** | ≥ 0.10.0 | `demographic_parity_difference`, `equalized_odds_difference` |
| **Pandas** | ≥ 2.2.0 | Data loading, cleaning, group aggregation, imputation |
| **NumPy** | ≥ 1.26.0 | Numerical operations, array-level metric computation |
| **SciPy** | ≥ 1.13.0 | Pearson correlation, chi-squared for proxy detection |
| **ReportLab** | ≥ 4.2.0 | PDF generation with tables, governance metadata |
| **google-generativeai** | ≥ 0.8.0 | Gemini API integration for advisory narratives |
| **google-cloud-firestore** | ≥ 2.16.0 | Server-side Firestore mirroring for audit history |
| **python-multipart** | ≥ 0.0.9 | Multipart form data for CSV file uploads |
| **python-dotenv** | ≥ 1.0.0 | `.env` file loading for API keys |
| **httpx** | ≥ 0.27.0 | Async HTTP client for internal requests |
| **pytest** | ≥ 8.2.0 | Test suite for the audit engine |

<br/>

### Frontend

| Technology | Purpose |
|------------|---------|
| **Flutter Web** | Full UI framework — the only supported user-facing interface |
| **firebase_core** | Firebase SDK initialisation |
| **firebase_auth** | Google Sign-In + email/password authentication |
| **cloud_firestore** | Streaming audit history from Firestore |
| **url_launcher** | Opening external links from within the app |
| **visibility_detector** | Triggering animations when widgets scroll into view |
| **google_fonts** | Inter typeface for the entire UI |

<br/>

### Why These Choices?

```
scikit-learn  → Industry standard. Wide algorithm coverage, GridSearchCV
               built in. No CUDA required — runs on any machine.

Fairlearn     → Microsoft Research's fairness library. Implements the
               formal definitions of demographic parity and equalized
               odds used in the academic literature.

Flutter Web   → Single codebase for web + potential iOS/Android later.
               Dart's strong typing reduces runtime errors in the UI.

ReportLab     → Precise PDF control. Headers, tables, traceability
               footers on every page. No LaTeX dependency.

FastAPI       → Auto-generates OpenAPI docs. Async support.
               Pydantic validation. Easy to extend.
```

<br/>

---

<br/>

##   File Structure

```
ai-bias-auditor/
│
├── app/                              # FastAPI application package
│   ├── main.py                       # API routes and CORS config
│   │                                 # Routes: / /audit /history /api/*
│   ├── audit.py                      # ★ Core audit engine
│   │                                 # Data cleaning, fairness metrics,
│   │                                 # model training, traces, intersectional
│   ├── governance.py                 # Policy scoring, model-selection ranking,
│   │                                 # severity determination, deployment decisions
│   ├── policies.py                   # Policy loading, validation, versioning
│   ├── report.py                     # PDF generation via ReportLab
│   │                                 # + Gemini API integration (structured JSON)
│   ├── storage.py                    # Local JSON history + Firestore mirroring
│   │                                 # Persistence modes: aggregate/anonymized/full
│   └── demo_data.py                  # Demo dataset registry and loader
│
├── flutter_firebase_auditor/         # Flutter Web frontend
│   ├── lib/
│   │   ├── main.dart                 # App entry point
│   │   ├── app.dart                  # MaterialApp + routing table
│   │   ├── firebase_options.dart     # Firebase config (gitignored if sensitive)
│   │   ├── screens/
│   │   │   ├── landing/              # Marketing landing page
│   │   │   │   └── landing_screen.dart
│   │   │   ├── audit/                # ★ Main audit workspace
│   │   │   │   └── audit_screen.dart # Phase 1/2/3, tab results
│   │   │   ├── dashboard/            # Auth-gated audit history
│   │   │   │   └── dashboard_screen.dart
│   │   │   └── auth/                 # Sign in / Sign up
│   │   │       └── auth_screen.dart
│   │   ├── services/
│   │   │   ├── backend_client.dart   # HTTP client for FastAPI
│   │   │   └── audit_repository.dart # Firestore read/write
│   │   ├── models/
│   │   │   └── audit_record.dart     # Firestore document model
│   │   ├── widgets/                  # Reusable UI components
│   │   │   ├── glass_card.dart
│   │   │   ├── severity_badge.dart
│   │   │   ├── custom_tab_bar.dart
│   │   │   ├── gradient_button.dart
│   │   │   ├── metric_card.dart
│   │   │   ├── terminal_block.dart
│   │   │   ├── grid_background.dart  # Mouse-reactive grid + spotlight
│   │   │   └── animated_fade_slide.dart
│   │   └── core/
│   │       └── theme/
│   │           └── app_theme.dart    # Full design system
│   └── firestore.rules               # User-scoped security rules
│
├── data/
│   ├── demos/                        # Bundled demo CSVs (no download needed)
│   │   ├── compas.csv                # 7,214 rows
│   │   ├── adult.csv                 # 48,842 rows
│   │   └── german_credit.csv         # 1,000 rows
│   └── audit_history/                # Local JSON audit artifacts
│
├── policies/                         # Governance policy presets (JSON)
│   ├── default_governance_v1.json
│   ├── employment_screening_strict.json
│   ├── credit_lending_strict.json
│   ├── medical_triage_strict.json
│   └── low_risk_internal_tool.json
│
├── scripts/
│   └── download_demos.py             # Optional: refresh larger source datasets
│
├── tests/
│   └── test_audit.py                 # pytest test suite for audit engine
│
├── .env.example                      # Template — copy to .env and fill in keys
├── .env                              # Real secrets — NEVER commit this
├── .gitignore                        # Includes .venv, .env, __pycache__, etc.
├── Dockerfile                        # Container build for deployment
├── firebase.json                     # Firebase Hosting + Firestore config
├── .firebaserc                       # Firebase project association
├── firestore.rules                   # Firestore security rules (root copy)
├── pyproject.toml                    # Project metadata (requires-python >=3.11,<3.14)
├── requirements.txt                  # Pinned Python dependencies
└── README.md                         # This file
```

<br/>

---

<br/>

##   API Reference

All endpoints served by the FastAPI backend at `http://localhost:8000`.

<br/>

### Health & Navigation

```
GET  /
  → 302 Redirect to FRONTEND_URL (http://localhost:5050)

GET  /health
  → 200 { "status": "ok", "storage": "local|firestore", "version": "..." }

GET  /audit
  → 302 Redirect to Flutter audit page
```

<br/>

### Core Audit Endpoints

```
POST  /api/upload
  Body:    multipart/form-data  { file: CSV }
  Returns: {
    "upload_id": "...",
    "rows": 7214,
    "columns": 28,
    "column_names": [...],
    "preview": [[...], ...],   // 5 rows
    "missing_summary": {...}
  }

POST  /api/pre-audit
  Body: {
    "upload_id": "...",
    "protected_attributes": ["race", "sex"],
    "outcome_column": "two_year_recid",
    "policy": "employment_screening_strict"
  }
  Returns: {
    "representation": { "race": {...}, "sex": {...} },
    "proxy_variables": [...],
    "overall_severity": "HIGH",
    "cleaning_log": [...]
  }

POST  /api/audit
  Body: {
    "upload_id": "...",
    "protected_attributes": ["race", "sex"],
    "outcome_column": "two_year_recid",
    "policy": "employment_screening_strict",
    "report_template": "full",
    "same_background_controls": ["age_cat"],
    "mode": "train"              // or "prediction_csv"
  }
  Returns: {
    "run_id": "themis_20260104_143022_a7f3c",
    "models": [...],             // 9 models ranked
    "fairness_scorecard": {...},
    "intersectional": {...},
    "same_background": {...},
    "decision_traces": [...],
    "mitigation_sim": {...},
    "severity": "HIGH"
  }
```

<br/>

### Demo & Report Endpoints

```
GET   /api/demos
  → List of available demo datasets with metadata

POST  /api/demo/{id}
  id: "compas" | "adult" | "german_credit"
  → Loads demo and returns same response as /api/upload

GET   /api/report/{run_id}
  → Streams PDF file download
  Content-Type: application/pdf
  Content-Disposition: attachment; filename="themis_report_{run_id}.pdf"

GET   /api/policies
  → Returns all available governance policy presets and their thresholds
```

<br/>

### History Endpoints

```
GET  /history
  → Redirect to Flutter dashboard

GET  /api/history
  → List of persisted audit runs (local JSON + optional Firestore)
  Returns: [{ run_id, created_at, dataset_name, severity, ... }]

GET  /api/history/{run_id}
  → Full persisted audit result for a specific run
```

<br/>

---

<br/>

##   Setup & Installation

<br/>

### Prerequisites

```
   Python 3.11 or 3.12
      datetime.UTC was introduced in Python 3.11 — earlier versions will fail
      at import time with AttributeError

   Flutter SDK (stable channel)
      flutter --version  should show ≥ 3.19

   uv package manager (recommended)
      pip install uv
      OR use pip directly if preferred

   Git
   A modern browser (Chrome recommended for Flutter web)

OPTIONAL:
    Firebase CLI (for cloud features)
       npm install -g firebase-tools
    Google AI Studio API key (for Gemini narrative)
       https://aistudio.google.com/app/apikey
```

<br/>

### Step 1 — Clone the Repository

```bash
git clone https://github.com/R3ap3r7/ai-bias-auditor.git
cd ai-bias-auditor
```

<br/>

### Step 2 — Python Backend Setup

```bash
# Create virtual environment with Python 3.12
uv venv --python 3.12

# Activate it
source .venv/bin/activate        # macOS / Linux
.venv\Scripts\activate           # Windows PowerShell

# Install all dependencies
uv pip install -r requirements.txt

# Verify the install
python -c "import fastapi, fairlearn, sklearn; print('✅ All good')"
```

<br/>

### Step 3 — Environment Configuration

```bash
# Copy the template
cp .env.example .env

# Edit .env and fill in your values (see Environment Configuration section)
nano .env     # or code .env, vim .env, etc.
```

**Minimum required** (for core local functionality — no cloud features):
```env
# Leave blank or omit all Firebase + Gemini keys
# Everything works without them
```

<br/>

### Step 4 — Start the Backend

```bash
# ⚠️  IMPORTANT: Always use .venv/bin/uvicorn, NOT system uvicorn
# Using the system uvicorn may pick up an older Python and fail with
# AttributeError: module 'datetime' has no attribute 'UTC'

.venv/bin/uvicorn app.main:app --reload --port 8000
```

You should see:
```
INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
INFO:     Started reloader process using WatchFiles
INFO:     Started server process
INFO:     Application startup complete.
```

<br/>

### Step 5 — Flutter Frontend Setup

```bash
# In a new terminal
cd flutter_firebase_auditor

# Install Flutter dependencies
flutter pub get

# Run on Chrome at port 5050
flutter run -d chrome --web-port 5050
```

The app will open at `http://localhost:5050`.

<br/>

### Step 6 — Verify Everything Works

```
Open: http://localhost:5050

1. Click "Try Demo" on the landing page
2. Select "COMPAS Criminal Justice" dataset
3. Configure: protected = race, sex | outcome = two_year_recid
4. Click "Run Data Pre-Audit"
   → Should return within ~2 seconds with representation analysis
5. Click "Run Post-Model Audit"
   → Should train 9 models and return results within ~60-120 seconds
6. Download PDF report
   → Should download a complete audit PDF
```

<br/>

### Optional: Firebase Setup

```bash
# Login to Firebase
firebase login

# Set your project
firebase use --add      # follow prompts to select your project

# Deploy Firestore security rules
firebase deploy --only firestore:rules

# For Flutter web Firebase config:
# Update flutter_firebase_auditor/lib/firebase_options.dart
# with your project's config values from the Firebase console
```

<br/>

### Optional: Docker Deployment

```bash
# Build the container
docker build -t themis-backend .

# Run with environment variables
docker run -p 8000:8000 \
  -e GEMINI_API_KEY=your_key \
  -e CORS_ALLOWED_ORIGINS=http://localhost:5050 \
  themis-backend
```

<br/>

---

<br/>

## 🗺️ User Workflow

End-to-end journey from opening the app to downloading a PDF report.

<br/>

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           THEMIS USER WORKFLOW                               │
└──────────────────────────────────────────────────────────────────────────────┘

  ┌────────────────┐
  │  Landing Page  │  Browse features, read case studies, select demo or upload
  └───────┬────────┘
          │
          ▼
  ┌────────────────────────────────┐
  │  PHASE 1: Dataset Selection    │
  │                                │
  │  Option A: Upload CSV          │  Drag & drop any CSV file
  │  Option B: Choose Demo         │  COMPAS / UCI Adult / German Credit
  │                                │
  │  Themis immediately profiles:  │
  │  • Row & column count          │
  │  • Missing value rates         │
  │  • 5-row preview               │
  │  • Column type inference       │
  └───────────────┬────────────────┘
                  │
                  ▼
  ┌────────────────────────────────┐
  │  PHASE 2: Configuration        │
  │                                │
  │  For each column, toggle:      │
  │  [◉] Protected Attribute       │  (race, sex, age, etc.)
  │  [◎] Outcome Column            │  (binary target)
  │  [○] Feature                   │  (used for training)
  │  [○] Ignore                    │  (excluded from audit)
  │                                │
  │  Also configure:               │
  │  • Governance Policy           │
  │  • Report Template             │
  │  • Same-Background Controls    │
  │  • Audit Mode (train / CSV)    │
  └───────────────┬────────────────┘
                  │
          ┌───────┴────────┐
          ▼                ▼
  ┌──────────────┐  ┌──────────────────────────┐
  │ Pre-Audit    │  │ Post-Model Audit           │
  │ (fast, ~2s)  │  │ (~60-120s)                 │
  │              │  │                            │
  │ • Repr.      │  │ • Train 9 models           │
  │   balance    │  │ • GridSearchCV tuning       │
  │ • Proxy      │  │ • Fairness metrics          │
  │   detection  │  │ • Decision traces           │
  │ • Severity   │  │ • Intersectional analysis  │
  │   rating     │  │ • Same-background fairness │
  └──────┬───────┘  │ • Mitigation simulation    │
         │          └──────────────┬─────────────┘
         └──────────────┬──────────┘
                        │
                        ▼
  ┌─────────────────────────────────────────────────────┐
  │  PHASE 3: Results (7 tabs)                          │
  │                                                     │
  │  Overview       → Dataset stats, cleaning log       │
  │  Pre-Audit      → Representation, proxy flags       │
  │  Bias Scorecard → Per-attribute fairness metrics    │
  │  Model Compare  → Ranked table + bar chart          │
  │  Decision Traces→ Governance, intersectional,       │
  │                   same-background, row-level        │
  │  Features       → Importance, bias links, mitigation│
  │  Report         → LLM narrative + Download PDF      │
  └─────────────────────────────────────────────────────┘
                        │
          ┌─────────────┼──────────────┐
          ▼             ▼              ▼
  ┌─────────────┐ ┌──────────┐ ┌────────────────────┐
  │ Download PDF│ │ New Audit│ │ Save to Dashboard   │
  │ (always     │ │          │ │ (requires Google    │
  │  available) │ │          │ │  Sign-In, optional) │
  └─────────────┘ └──────────┘ └────────────────────┘
```

<br/>

---

<br/>

## 🎨 Design System

<br/>

### Color Palette

```
BACKGROUNDS
  --background:   #09090B   ████  Primary page background
  --surface:      #18181B   ████  Card backgrounds, panels
  --border:       #27272A   ████  Dividers, card borders

ACCENTS
  --accentPrimary:   #7C3AED   ████  Primary purple (buttons, active states)
  --accentSecondary: #6D28D9   ████  Hover states, gradients
  --accentBlue:      #2563EB   ████  Info states, links

TEXT
  --textPrimary:   #E4E4E7   ████  Main readable text
  --textSecondary: #A1A1AA   ████  Supporting text, labels
  --textMuted:     #71717A   ████  Placeholders, disabled

SEVERITY
  --severityLow:      #4ADE80   ████  Green  (safe)
  --severityMedium:   #FACC15   ████  Yellow (caution)
  --severityHigh:     #FB923C   ████  Orange (warning)
  --severityCritical: #F87171   ████  Red    (danger)
```

<br/>

### Typography

```
Font: Inter (Google Fonts)

  Display/Hero:   700-800 weight, tight tracking (-0.03em to -0.05em)
  Headings:       600-700 weight
  Body:           400 weight, 1.6 line-height
  Monospace:      JetBrains Mono (code blocks, run IDs, hashes)
  Labels:         500 weight, 0.08em letter-spacing, uppercase
```

<br/>

### Key Widget Library

```
Widget               Purpose
─────────────────────────────────────────────────────────────
GlassCard            Frosted glass container with subtle border + blur
GradientButton       Primary CTA with purple gradient + hover lift
OutlinedAccentButton Secondary CTA, outlined with purple border
SeverityBadge        Color-coded LOW/MEDIUM/HIGH/CRITICAL pill
CustomToggle         Smooth toggle for column configuration
CodePill             Monospace pill for displaying column names
AnimatedFadeSlide    Entrance animation wrapper for any widget
CustomTabBar         Horizontal tab bar with active underline animation
MetricCard           Dashboard metric with icon, number, label
TerminalBlock        Dark code block for displaying run IDs, commands
TheAppBar            Persistent top navigation bar
GridBackground       Reusable grid pattern with mouse-reactive spotlight
```

<br/>

---

<br/>

## 🔒 Security & Privacy

<br/>

### Local Processing Guarantee

```
┌──────────────────────────────────────────────────────────┐
│               WHAT STAYS LOCAL (ALWAYS)                  │
├──────────────────────────────────────────────────────────┤
│  ✅  Raw CSV data                                         │
│  ✅  Uploaded datasets                                    │
│  ✅  Model training and inference                         │
│  ✅  Fairness metric computation                          │
│  ✅  Feature importances                                  │
│  ✅  Row-level decision traces                            │
│  ✅  PDF report generation                               │
├──────────────────────────────────────────────────────────┤
│               WHAT CAN GO TO THE CLOUD                   │
│                (ONLY if explicitly configured)            │
├──────────────────────────────────────────────────────────┤
│  ☁️  Compact anonymised audit SUMMARY → Gemini API       │
│      (aggregate metrics only, no raw rows, no PII)       │
│  ☁️  Report metadata → Firestore (opt-in, auth-gated)    │
│  ☁️  Large trace JSON → Firebase Storage (opt-in)        │
└──────────────────────────────────────────────────────────┘
```

<br/>

### CORS Configuration

```python
# app/main.py
origins = os.getenv("CORS_ALLOWED_ORIGINS", "http://localhost:5050").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,       # Strictly controlled origin list
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

<br/>

### Uploaded Model Artifacts

```
⚠️  IMPORTANT: Pickle/joblib model upload is DISABLED by default

  Pickle deserialization is a known arbitrary code execution vector.
  Themis disables the endpoint in the UI and API unless:

  ENABLE_UPLOADED_MODEL_MODE=true   (in .env)

  Only enable this in trusted, air-gapped environments.
  For external models, use prediction CSV mode instead.
```

<br/>

---

<br/>

## 🔥 Firebase Integration

<br/>

### Authentication

Themis supports **two modes**:

```
Guest Mode     → Run audits without signing in. Results stored locally only.
                 No Firebase required.

Signed-In Mode → Google Sign-In via Firebase Auth.
                 Audit history saved to Firestore under user's account.
                 Access dashboard to view past audits.
```

<br/>

### Firestore Schema

```
Firestore Database
│
└── users/
    └── {userId}/                         # Auto-created on first sign-in
        ├── auditRuns/
        │   └── {auditId}/                # One doc per audit
        │       ├── auditId: string
        │       ├── createdAt: timestamp
        │       ├── datasetName: string
        │       ├── datasetSource: "upload" | "compas" | "adult" | "german"
        │       ├── rowCount: number
        │       ├── columnCount: number
        │       ├── protectedAttributes: string[]
        │       ├── outcomeColumn: string
        │       ├── overallSeverity: "LOW" | "MEDIUM" | "HIGH" | "CRITICAL"
        │       ├── preAuditSeverity: string
        │       ├── postAuditSeverity: string
        │       ├── modelUsed: string        # Best model name
        │       ├── llmReport: map           # Structured Gemini output
        │       ├── rawResults: map          # All metrics (no trace JSON)
        │       └── traceStorageUrl: string  # Firebase Storage URL
        │
        └── reports/
            └── {reportId}/               # PDF metadata
                ├── reportId: string
                ├── runId: string
                └── downloadUrl: string
```

<br/>

### Security Rules

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can only read/write their OWN data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }

    // No public access to any collection
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

<br/>

---

<br/>

## ⚙️ Environment Configuration

Full reference for every variable in `.env`:

<br/>

```bash
# ─────────────────────────────────────────────────────────────
# GEMINI (OPTIONAL — fallback to local report if not set)
# ─────────────────────────────────────────────────────────────
GEMINI_API_KEY=your_google_ai_studio_key
GEMINI_MODEL=gemini-2.5-flash            # default, change if needed

# ─────────────────────────────────────────────────────────────
# CORS (REQUIRED — must match your Flutter frontend URL)
# ─────────────────────────────────────────────────────────────
CORS_ALLOWED_ORIGINS=http://localhost:5050
# For production: CORS_ALLOWED_ORIGINS=https://your-app.web.app

# ─────────────────────────────────────────────────────────────
# FRONTEND URL (where FastAPI should redirect / and /audit)
# ─────────────────────────────────────────────────────────────
FRONTEND_URL=http://localhost:5050

# ─────────────────────────────────────────────────────────────
# FIREBASE (OPTIONAL — all can be omitted for local-only mode)
# ─────────────────────────────────────────────────────────────
FIREBASE_API_KEY=
FIREBASE_PROJECT_ID=
FIREBASE_APP_ID=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_AUTH_DOMAIN=
FIREBASE_STORAGE_BUCKET=

# ─────────────────────────────────────────────────────────────
# AUDIT BEHAVIOR
# ─────────────────────────────────────────────────────────────
REPORT_PERSISTENCE_MODE=anonymized_traces
# Options:
#   aggregate_only    → Only metrics/severity saved. No traces.
#   anonymized_traces → Traces saved with PII-adjacent fields dropped (default)
#   full_report       → Everything saved. Only for trusted local environments.

ENABLE_UPLOADED_MODEL_MODE=false
# Set to true ONLY in air-gapped, trusted environments.
# Enables pickle/joblib model upload endpoint.
```

<br/>

---

<br/>

## ✅ Current Status

<br/>

```
BACKEND
  ✅  FastAPI app with all endpoints implemented
  ✅  Demo dataset loading (COMPAS, UCI Adult, German Credit)
  ✅  Data pre-audit (representation, proxy detection, severity)
  ✅  Full audit (9 models, GridSearchCV, fairness metrics)
  ✅  Decision audit traces (local perturbation, no SHAP)
  ✅  Intersectional bias analysis
  ✅  Same-background fairness analysis
  ✅  Mitigation simulation
  ✅  PDF report generation (ReportLab)
  ✅  Gemini API integration (structured JSON output)
  ✅  Local audit history persistence
  ✅  CORS configuration
  ✅  Governance policy presets (5 policies)

FRONTEND
  ✅  Landing page (animated, glassmorphism, mouse-reactive grid)
  ✅  Audit page — Phase 1 (dataset selection)
  ✅  Audit page — Phase 2 (column configuration)
  ✅  Audit page — Phase 3 (7-tab results viewer)
  ✅  Custom charts (CustomPaint)
  ✅  Auth screen (Google Sign-In + email/password)
  ✅  Dashboard (Firestore StreamBuilder, shimmer loading, empty state)
  ✅  LLM report rendering (structured JSON → rich UI)
  ✅  Design system (AppTheme, all reusable widgets)

FIREBASE
  ✅  Firebase Auth (Google Sign-In + email/password)
  ✅  Firestore schema and security rules
  ✅  Firebase Hosting config (firebase.json, .firebaserc)
  ✅  AppConfig.dart with dart-define for API_URL
  ⚠️  Firestore rules deployment requires IAM permission fix (manual step)
  ⚠️  Firebase Storage upload for large trace JSON (wired, needs testing)

DEVOPS / MISC
  ✅  .gitignore (covers .venv, .env, __pycache__, .flutter-sdk)
  ✅  Dockerfile for backend deployment
  ✅  pyproject.toml (requires-python >=3.11,<3.14)
  ✅  requirements.txt (pinned)
  ✅  pytest test suite skeleton
  ⚠️  Git history: themis-frontend branch is 9 commits behind main
       (predates some commits — PR recommended as-is)
```

<br/>

---

<br/>

## 🛣️ Roadmap

<br/>

```
NEAR-TERM (v1.1)
  ◻  Regression fairness support
  ◻  Multiclass classification fairness
  ◻  Additional fairness metrics (individual fairness, counterfactual)
  ◻  Dataset visual EDA in Phase 1
  ◻  Better proxy variable explanations in UI

MEDIUM-TERM (v1.5)
  ◻  Batch audit processing (audit multiple models/datasets at once)
  ◻  Custom fairness thresholds per-run (override policy)
  ◻  Collaborative audit sharing (share run ID with teammate)
  ◻  More ML algorithms (XGBoost, LightGBM, CatBoost)
  ◻  ONNX model import support
  ◻  Time-series fairness (longitudinal analysis)

LONG-TERM (v2.0)
  ◻  Ranking/recommendation fairness
  ◻  LLM bias auditing (prompt sensitivity, demographic steering)
  ◻  Real-time monitoring dashboard (production model drift)
  ◻  Integration with MLflow, Weights & Biases
  ◻  Flutter iOS/Android app
  ◻  VS Code extension for in-IDE audit
  ◻  Jupyter notebook integration
```

<br/>

---

<br/>

## 🤝 Contributing

Contributions are warmly welcome. Themis is built for practitioners by practitioners — your domain expertise makes it better.

<br/>

```bash
# 1. Fork the repository on GitHub

# 2. Clone your fork
git clone https://github.com/YOUR_USERNAME/ai-bias-auditor.git
cd ai-bias-auditor

# 3. Create a feature branch
git checkout -b feature/your-feature-name

# 4. Make your changes

# 5. Ensure tests pass
source .venv/bin/activate
pytest tests/ -v

# 6. Commit with a descriptive message
git commit -m "feat: add equalized opportunity metric for multiclass"

# 7. Push and open a Pull Request against ai-bias-auditor-main
git push origin feature/your-feature-name
```

<br/>

**Good first contributions:**
- Add a new fairness metric to `audit.py`
- Add a new policy preset to `policies/`
- Improve PDF report layout in `report.py`
- Write tests in `tests/test_audit.py`
- Improve proxy variable detection accuracy
- Add a new demo dataset

**Please include** a short description in your PR and, where applicable, a test case in `tests/test_audit.py`.

<br/>

---

<br/>

## 📜 License

```
MIT License

Copyright (c) 2026 Themis Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

<br/>

---

<br/>

<div align="center">

```
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     "Fairness is not an emergent property of optimization.  ║
║      It must be designed, measured, and enforced."           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

<br/>

**Made with ❤️ for Google Solution Challenge '26**

[![GitHub](https://img.shields.io/badge/GitHub-R3ap3r7%2Fai--bias--auditor-7c3aed?style=flat-square&logo=github)](https://github.com/R3ap3r7/ai-bias-auditor)
[![Issues](https://img.shields.io/github/issues/R3ap3r7/ai-bias-auditor?style=flat-square&color=7c3aed)](https://github.com/R3ap3r7/ai-bias-auditor/issues)
[![PRs Welcome](https://img.shields.io/badge/PRs-Welcome-22c55e?style=flat-square)](https://github.com/R3ap3r7/ai-bias-auditor/pulls)

<br/>

*Themis — named after the Greek goddess of justice and law.*
*Because algorithms should be held to the same standard.*

</div>
