# AI Bias Auditor Flutter/Firebase

This folder is the supported user-facing frontend for AI Bias Auditor. It keeps the Python/FastAPI ML pipeline as the backend API and owns authentication, audit configuration, results review, PDF access, and user-scoped Firestore history.

## Architecture

- Flutter web: upload/configuration dashboard and audit results UI.
- FastAPI backend: CSV ingestion, pre-model audit, model training, prediction CSV audit, advisory Gemini analysis, PDF export.
- Firebase Auth: Google sign-in for audit ownership.
- Cloud Firestore: user profiles plus user-scoped `users/{uid}/auditRuns`, `users/{uid}/reports`, and `users/{uid}/auditRuns/{auditId}/traceRecords`.
- Firebase Hosting: serves the Flutter web build.

Datasets and uploaded model artifacts are not stored in Firebase. Firestore stores user profiles, governance metadata, severity, model summary, report source, report JSON, and capped trace previews scoped to the authenticated Google account.

Current Firebase project: `ai-bias-auditor-2604171603`

Hosted URL: `https://ai-bias-auditor-2604171603.web.app`

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
- Firebase Authentication with Google provider

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
  --web-port 5050 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Firebase web configuration defaults to the existing project `ai-bias-auditor-2604171603`. You can still override any value with `--dart-define=FIREBASE_*` for another Firebase project.

## Deploy

Build Flutter web:

```bash
flutter build web \
  --dart-define=API_BASE_URL=https://your-cloud-run-url
```

Deploy rules and hosting:

```bash
firebase deploy --only firestore:rules,firestore:indexes,hosting
```

Set the backend CORS allowlist before deploying FastAPI to Cloud Run:

```bash
CORS_ALLOWED_ORIGINS=https://your-project-id.web.app,https://your-project-id.firebaseapp.com
```

Cloud Run's free tier still requires billing to be enabled on the Google Cloud project. Without billing, Google blocks `run.googleapis.com`, `cloudbuild.googleapis.com`, and `artifactregistry.googleapis.com`, so Firebase Hosting can be deployed but the hosted Flutter app will not have a cloud API endpoint.

## Firebase Console Step

Google sign-in must be enabled once in the Firebase Console:

1. Open `https://console.firebase.google.com/project/ai-bias-auditor-2604171603/authentication/providers`.
2. Click **Get started** if Authentication is not initialized yet.
3. Open **Google** under sign-in providers.
4. Enable it, set the support email, and save.

Google sign-in is wired through `FirebaseAuth.signInWithPopup(...)` with redirect fallback for blocked popups. Local testing should use `http://localhost:5050`; `http://127.0.0.1:5050` must be added to Firebase Authentication authorized domains if you want to use that exact origin.

## Current Scope

The Flutter app covers the hackathon governance flow:

- Upload CSV or load demo dataset
- Select protected attributes and outcome column
- Choose policy, report template, model-selection priority, and same-background controls
- Train a tuned model family or upload a prediction CSV with optional row-id matching and score/probability metadata
- Run pre-model and full post-model audits separately
- View model comparison, conditional fairness, row-level audit trace, and Gemini analysis
- Download backend-generated PDF reports
- Sign in with Google
- Save user profiles, audit summaries, report JSON, and trace previews to user-scoped Firestore paths

Uploaded pickle/joblib model artifacts are disabled by default in the current UI because prediction CSV mode is safer for third-party model reviews. Gemini summaries are advisory and cannot certify model safety. The legacy FastAPI HTML pages are no longer a separate UI path; FastAPI serves the API and redirects user-facing routes to Flutter through `FRONTEND_URL`.
