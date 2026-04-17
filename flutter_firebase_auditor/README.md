# AI Bias Auditor Flutter/Firebase

This folder is a separate Flutter web front end for the existing FastAPI audit engine. It keeps the Python ML pipeline intact and adds Firebase Hosting plus Firestore audit history.

## Architecture

- Flutter web: upload/configuration dashboard and audit results UI.
- FastAPI backend: CSV ingestion, pre-model audit, model training/uploaded-model audit, Gemini analysis, PDF export.
- Firebase Auth: anonymous sign-in for hackathon demo history.
- Cloud Firestore: `auditRuns` audit metadata and `auditRuns/{auditId}/traceRecords` row-level trace previews.
- Firebase Hosting: serves the Flutter web build.

Datasets are not stored in Firebase. Firestore stores governance metadata, severity, model summary, report source, and trace previews.

## Local Setup

Install Flutter first if it is not available:

```bash
brew install --cask flutter
flutter doctor
```

Install Firebase tooling or use `npx`:

```bash
npm install -g firebase-tools
firebase login
```

Create or select a Firebase project, then enable:

- Firebase Hosting
- Cloud Firestore
- Anonymous Authentication

Copy `.firebaserc.example` to `.firebaserc` and set your Firebase project id.

## Run locally

Start the existing backend from the repository root:

```bash
uvicorn app.main:app --reload
```

Run Flutter web from this folder:

```bash
flutter pub get
flutter run -d chrome \
  --web-port 5000 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=FIREBASE_PROJECT_ID=your-project-id \
  --dart-define=FIREBASE_API_KEY=your-web-api-key \
  --dart-define=FIREBASE_APP_ID=your-web-app-id \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your-sender-id \
  --dart-define=FIREBASE_AUTH_DOMAIN=your-project-id.firebaseapp.com \
  --dart-define=FIREBASE_STORAGE_BUCKET=your-project-id.appspot.com
```

If the Firebase values are omitted, the app still runs against the backend, but audit history is disabled.

## Deploy

Build Flutter web:

```bash
flutter build web \
  --dart-define=API_BASE_URL=https://your-cloud-run-url \
  --dart-define=FIREBASE_PROJECT_ID=your-project-id \
  --dart-define=FIREBASE_API_KEY=your-web-api-key \
  --dart-define=FIREBASE_APP_ID=your-web-app-id \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your-sender-id \
  --dart-define=FIREBASE_AUTH_DOMAIN=your-project-id.firebaseapp.com \
  --dart-define=FIREBASE_STORAGE_BUCKET=your-project-id.appspot.com
```

Deploy rules and hosting:

```bash
firebase deploy --only firestore:rules,firestore:indexes,hosting
```

Set the backend CORS allowlist before deploying FastAPI to Cloud Run:

```bash
CORS_ALLOWED_ORIGINS=https://your-project-id.web.app,https://your-project-id.firebaseapp.com
```

## Current Scope

The Flutter app covers the hackathon governance flow:

- Upload CSV or load demo dataset
- Select protected attributes and outcome column
- Train a tuned model family or upload a trusted pickle/joblib model
- Run pre-model and full post-model audits separately
- View model comparison, conditional fairness, row-level audit trace, and Gemini analysis
- Save audit summaries and trace previews to Firestore

The existing FastAPI UI is unchanged and can still be used independently.
