# AI Bias Auditor

Local FastAPI MVP for auditing CSV datasets for representation imbalance, proxy variables, model bias, conditional fairness, and row-level decision traces.

## Run locally

```bash
uv venv --python 3.12
source .venv/bin/activate
uv pip install -r requirements.txt
python scripts/download_demos.py
uvicorn app.main:app --reload
```

Open `http://127.0.0.1:8000`.

Gemini is optional for local testing and is used only for the plain-English analysis report. Set `GEMINI_API_KEY` or `GOOGLE_API_KEY` to enable it. The default analysis model is `gemini-2.5-flash`; override it with `GEMINI_MODEL`. Without a key, the app generates a deterministic local analysis report.

## Main flow

1. Upload a CSV or choose a demo dataset.
2. Select protected attributes.
3. Select the outcome column.
4. Run the data-only pre-audit to inspect representation, validation, and proxy risks.
5. Choose a post-audit model source:
   - Compare all tuned local models and let the auditor recommend the best balance of balanced accuracy and fairness risk.
   - Train one tuned local model: Logistic Regression, Decision Tree, Random Forest, Extra Trees, Gradient Boosting, AdaBoost, Linear SVM, K-Nearest Neighbors, or Gaussian Naive Bayes.
   - Upload a trusted `.joblib`, `.pkl`, or `.pickle` sklearn-compatible model with `predict(...)`.
6. Review aggregate fairness, same-background cohorts, intersectional groups, and the decision audit trace.
7. Export the report as PDF.

The decision audit trace records run ID, dataset hash, model fingerprint, risky row IDs, predictions, actual labels, protected attributes, and the top local feature contributions. Contributions are generated with a local baseline-perturbation explainer so the trace still works for models that do not expose coefficients.

Uploaded model files are loaded in memory only and are not persisted. Pickle/joblib files can execute code when loaded, so only upload trusted artifacts.
Demo datasets are expected to be real downloaded CSV files in `data/demos`. If they are missing, run `python scripts/download_demos.py`; the app no longer generates synthetic fallback data.

## Cloud Run

```bash
gcloud run deploy ai-bias-auditor \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```

If you use Gemini in Cloud Run, set `GEMINI_API_KEY` or `GOOGLE_API_KEY` as a service secret or environment variable.
