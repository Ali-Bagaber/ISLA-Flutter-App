ISLA minimal migration notes

This folder contains only baseline contracts and models for the new local-first flow.

Planned flow:
Task -> Study Session Plan -> AI Checklist -> Pomodoro -> Review -> Analytics

What is intentionally not changed yet:
- Existing Provider-based UI screens
- Existing mock content in screens
- Existing login/register flow

Gemini runtime config:
- Pass API key at run time with --dart-define=GEMINI_API_KEY=...
- Optional model override with --dart-define=GEMINI_MODEL=...
