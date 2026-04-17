# AI Bias Auditor

Local FastAPI MVP for auditing CSV datasets for representation imbalance, proxy variables, model bias, and likely bias sources.

## Run locally

```bash
uv venv --python 3.12
source .venv/bin/activate
uv pip install -r requirements.txt
python scripts/download_demos.py
uvicorn app.main:app --reload
```

Open `http://127.0.0.1:8000`.

Gemini is optional for local testing. Set `GEMINI_API_KEY` or `GOOGLE_API_KEY` to enable Gemini report generation. Without it, the app generates a deterministic local report from the audit metrics.

## Main flow

1. Upload a CSV or choose a demo dataset.
2. Select protected attributes.
3. Select the outcome column.
4. Choose Logistic Regression or Decision Tree.
5. Run the audit and export the report as PDF.

## Cloud Run

```bash
gcloud run deploy ai-bias-auditor \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```

If you use Gemini in Cloud Run, set `GEMINI_API_KEY` or `GOOGLE_API_KEY` as a service secret or environment variable.
