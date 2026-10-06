# Paste this into the Opus 5.5 session (opened in this folder)

Read `CLAUDE.md` then `PLAN.md` fully before touching anything. Build Quitter exactly as specified,
phase by phase, in order. Each phase ends with a verification gate; do not start the next phase
until the gate passes with real evidence (command output, `pgrep`, screenshot). Commit after each
passed gate. Do not ask me design questions: every decision is in the plan, and where it says
"fallback" use the primary first and only fall back on a real failure you can quote. When all
phases pass, install to /Applications, launch it, and write `docs/VERIFICATION.md` with what you
ran and saw.
