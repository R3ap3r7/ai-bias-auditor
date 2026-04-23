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
  --web-port 5050 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=FIREBASE_API_KEY=your-firebase-web-api-key
```

Firebase web configuration is read from build-time `--dart-define` values. The Firebase web API key is not committed to source.

## Deploy

Build Flutter web:

```bash
flutter build web \
  --dart-define=API_BASE_URL=https://your-cloud-run-url \
  --dart-define=FIREBASE_API_KEY=your-firebase-web-api-key
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

Google sign-in is wired through `FirebaseAuth.signInWithPopup(...)`. Local testing should use `http://localhost:5050`; `http://127.0.0.1:5050` must be added to Firebase Authentication authorized domains if you want to use that exact origin.

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
