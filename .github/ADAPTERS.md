# GitHub And Copilot Adapters

This document is intentionally named `ADAPTERS.md`: GitHub prioritizes a README in
`.github/` over the root README, which owns the Sophia repository landing page.

Use this folder for repository automation, issue templates, pull-request templates, workflow files, and GitHub Copilot adapters.

- Copilot agents: `.github/agents/*.agent.md`
- Copilot skills: `.github/skills/<skill>/SKILL.md`
- GitHub Actions: `.github/workflows/`

Copilot adapters are generated from `.agents/roles/` and `.agents/skills/` by `scripts/generate-ai-adapters.ps1`.
