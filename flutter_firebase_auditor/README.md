# AI Bias Auditor Flutter/Firebase

This folder is a separate Flutter web front end for the existing FastAPI audit engine. It keeps the Python ML pipeline intact and adds Firebase Hosting plus Firestore audit history.

## Architecture

- Flutter web: upload/configuration dashboard and audit results UI.
- FastAPI backend: CSV ingestion, pre-model audit, model training/uploaded-model audit, Gemini analysis, PDF export.
- Firebase Auth: Google sign-in for audit ownership.
- Cloud Firestore: `users`, `auditRuns`, and `auditRuns/{auditId}/traceRecords` row-level trace previews.
- Firebase Hosting: serves the Flutter web build.

Datasets are not stored in Firebase. Firestore stores user profiles, governance metadata, severity, model summary, report source, and trace previews.

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
  --web-port 5000 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Firebase web configuration is generated in `lib/firebase_options.dart`.

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

## Firebase Console Step

Google sign-in must be enabled once in the Firebase Console:

1. Open `https://console.firebase.google.com/project/ai-bias-auditor-2604171603/authentication/providers`.
2. Click **Get started** if Authentication is not initialized yet.
3. Open **Google** under sign-in providers.
4. Enable it, set the support email, and save.

The CLI deployed Firestore and Hosting, but Firebase's public REST API cannot initialize the free Firebase Authentication console state; the REST initialization endpoint requires billing-backed Identity Platform.

## Current Scope

The Flutter app covers the hackathon governance flow:

- Upload CSV or load demo dataset
- Select protected attributes and outcome column
- Train a tuned model family or upload a trusted pickle/joblib model
- Run pre-model and full post-model audits separately
- View model comparison, conditional fairness, row-level audit trace, and Gemini analysis
- Sign in with Google
- Save user profiles, audit summaries, and trace previews to Firestore

The existing FastAPI UI is unchanged and can still be used independently.
