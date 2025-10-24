## Quick orientation for AI coding agents

This repo is a Talos+Flux GitOps cluster template (single-node variant). The goal of this file is to help AI agents be productive quickly by surfacing the project's key workflows, files, conventions and concrete examples.

### Big picture
- Purpose: generate Talos and Kubernetes manifests from templates, bootstrap Talos nodes, install core infra (Cilium, cert-manager, Flux, cloudflared) and let Flux manage the cluster from this repo.
- GitOps: Flux lives in `kubernetes/flux-system` and the repo is the single source-of-truth. Changes are applied by Flux (or `task reconcile`).
- Templating: `makejinja`-style templating is used; sample inputs live at root (`cluster.yaml`, `nodes.yaml`) and templates under `templates/` produce the generated `kubernetes/` and `talos/` config.

### Where to look (essential files)
- `README.md` — high-level workflow and the canonical CLI/task examples.
- `Taskfile.yaml` — primary developer entrypoint (`task` targets). Examples used across README: `task init`, `task configure`, `task bootstrap:talos`, `task bootstrap:apps`, `task reconcile`, `task talos:reset`.
- `scripts/bootstrap-apps.sh` — the canonical script used during `bootstrap:apps`; shows how CRDs, SOPS secrets, and Helm releases are applied. Useful to reproduce or debug bootstrapping logic.
- `scripts/lib/common.sh` — logging, env and CLI checks used by shell scripts. Use it as the canonical logging/exit pattern when editing/adding scripts.
- `bootstrap/helmfile.d/00-crds.yaml` and `01-apps.yaml` — helmfile definitions for CRDs and apps; `bootstrap-apps.sh` renders and applies these.
- `bootstrap/*.sops.yaml` and `kubernetes/components/common/sops/` — encrypted secrets (SOPS). The repo expects `age.key` and `SOPS_AGE_KEY_FILE` for decryption.
- `talos/clusterconfig/talosconfig` and `talos/` — Talos-specific generated configs (used by `task talos:*` targets).

### Developer workflows & exact commands (extractable from repo)
- Install toolchain (recommended via `mise` per README):
  - `mise install` (installs required CLIs like `kubectl`, `helmfile`, `kustomize`, `sops`, `talhelper`, `yq`, `flux`)
- Typical bootstrap flow:
  1. `task init` — render templates from `cluster.yaml`/`nodes.yaml`.
  2. edit `cluster.yaml` and `nodes.yaml` (samples show comments and required fields).
 3. `task configure` — render/validate generated configs.
 4. `task bootstrap:talos` — install Talos onto nodes.
 5. `task bootstrap:apps` — runs `scripts/bootstrap-apps.sh` to apply namespaces, SOPS secrets, CRDs, and Helm releases.
 6. `task reconcile` or `flux --namespace flux-system reconcile kustomization flux-system --with-source` to force Flux to sync.

### Project-specific conventions and patterns
- Template inputs: root `cluster.yaml` and `nodes.yaml` are authoritative for templating; do not edit generated `kubernetes/` or `talos/` outputs directly — update the inputs.
- Secrets: files ending with `.sops.yaml` are encrypted. Agent actions that touch secrets must preserve SOPS encryption (decrypt locally only when necessary and re-encrypt). Key files: `age.key` and `github-deploy.key(.pub)` live at repo root.
- Deploy keys: `github-deploy.key` + `github-deploy.key.pub` are used by Flux/bootstrapping. Don't accidentally publish private key content in PRs.
- Scripts: `scripts/*.sh` source `scripts/lib/common.sh`. Follow the `log` & `check_env` / `check_cli` patterns when adding scripts.
- Helm/CRD flow: CRDs are rendered from `bootstrap/helmfile.d/00-crds.yaml`; they are applied server-side before Helm releases (`01-apps.yaml`) — maintain that ordering.

### Integration points / external dependencies
- Cloudflare: `cloudflared` + `cloudflare_token` in `cluster.yaml` are required for external gateway setup. See README Cloudflare section.
- GitHub: repository deploy key and `github-push-token.txt` are used for flux/webhook and push-based reconciliation.
- SOPS/age: repo uses `sops` with age keys (`age.key`) — `SOPS_AGE_KEY_FILE` env var expected in scripts / Taskfile (default in `Taskfile.yaml`).
- Flux, helmfile, talhelper: scripts expect these CLIs (`scripts/lib/common.sh` enforces via `check_cli`).

### Small contract for modifications (inputs/outputs, error modes)
- Inputs: edits should target `cluster.yaml`, `nodes.yaml`, or files under `templates/` for generated output. Avoid editing generated files under `kubernetes/` or `talos/` unless intentionally committing generated output.
- Outputs: `task configure`/`task init` will regenerate config. `task bootstrap:apps` will change cluster state via `kubectl` and `helmfile`.
- Error conditions: scripts exit if required env vars or CLIs are missing (see `check_env` / `check_cli`). Respect existing logging and exit conventions.

### Quick examples to include in PR text or agent suggestions
- To render templates locally: `task init` then `ls kubernetes/` to inspect outputs.
- To bootstrap CRDs and apps (what CI/agent should run): `task bootstrap:apps` (this runs `scripts/bootstrap-apps.sh`).
- To verify Flux: `flux check` and `flux get ks -A`.

### Where to add further automation safely
- Add small, idempotent `scripts/` helpers that follow `log` and `check_*` helpers.
- If adding CI steps, prefer calling `task` targets rather than reimplementing bootstrap logic; this keeps behaviour consistent with local dev flows.

If any of these sections are unclear or you'd like me to extend examples (e.g., sample PR checklist, safe editing recipe for templates, or a short CI job), tell me which area to expand and I'll iterate.
