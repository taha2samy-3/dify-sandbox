# Changelog

All notable changes to the **Dify Sandbox (Wolfi OS Edition)** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.2.15-v1.0.0] - 2026-11-24

### 🚀 Added
- **Independent Wolfi OS Distribution:**
  - Fully decoupled, standalone multi-stage Docker build using `cgr.dev/chainguard/wolfi-base` (Zero-CVE, glibc-based container OS).
  - Pinned exact base image digest: `cgr.dev/chainguard/wolfi-base@sha256:be019c1c74fe69204a42c4e10bc4d886a49bf5403ffa74374ef7baa408fc9a26`.
- **Docker Buildx Bake Integration:**
  - Added [docker-bake.hcl](file:///home/taha/Desktop/ourprojects/dify-sandbox/docker-bake.hcl) to manage targets, remote caching, and dynamic external package passing.
  - Supported dynamic package injection via CLI: `--set *.args.PYTHON_PACKAGES="..."` and `--set *.args.NODE_PACKAGES="..."`.
  - Provided dedicated variant target `sandbox-datascience` for heavier data-science workloads (scipy, scikit-learn, etc.).
- **Dynamic Node.js Package Extensibility:**
  - Added [packages/node-requirements.txt](file:///home/taha/Desktop/ourprojects/dify-sandbox/packages/node-requirements.txt) with core pre-installed libraries: `axios`, `lodash`, `moment`, `dayjs`, `crypto-js`, and `bignumber.js`.
  - Configured global root `/node_modules` symlink and `allowed_env_vars` in `conf/config.yaml` to ensure any nested sandbox directory can seamlessly `require()` installed Node.js modules.
- **Python Scientific Ecosystem:**
  - Added [packages/python-requirements.txt](file:///home/taha/Desktop/ourprojects/dify-sandbox/packages/python-requirements.txt) with pre-compiled wheels for `pandas`, `numpy`, `requests`, `httpx`, `jinja2`, `openpyxl`, `tiktoken`, and `cryptography`.
- **CI/CD Pipeline & Supply Chain Security:**
  - Added [.github/workflows/ci.yml](file:///home/taha/Desktop/ourprojects/dify-sandbox/.github/workflows/ci.yml) featuring:
    - Automated Buildx Bake compilation.
    - Remote Registry Cache (`ghcr.io/pair-ai-platform/dify-sandbox:buildcache`).
    - Keyless signing with **Cosign** (Sigstore) via GitHub Actions OIDC.
    - Immediate in-pipeline signature verification (`cosign verify`).
    - SLSA Level 3 Build Provenance attestation via `actions/attest-build-provenance@v2`.
- **Testing & Verification Suite:**
  - Added [docker-compose.yml](file:///home/taha/Desktop/ourprojects/dify-sandbox/docker-compose.yml) for local development and orchestration testing.
  - Added [scripts/test-sandbox.sh](file:///home/taha/Desktop/ourprojects/dify-sandbox/scripts/test-sandbox.sh) for automated health and multi-language execution tests.
  - Added [scripts/verify-signature.sh](file:///home/taha/Desktop/ourprojects/dify-sandbox/scripts/verify-signature.sh) for verification of image signatures prior to cluster deployments.

### 🔒 Security & Compliance
- **Strict Tagging Policy:** Prohibited the use of the mutable `latest` tag in both build steps and CI deployment rules. All published artifacts require explicit version tags (`0.2.15-v*` or `0.2.15-sha-*`).
- **Pinned Upstream Stable Release:** Locked to upstream `langgenius/dify-sandbox` release tag **`0.2.15`** (commit `5631afef06ec88f80c28129aec7fd22a30006b14`).
- **Least-Privilege Linux Capabilities:** Documented and verified container capability requirements: `SYS_CHROOT`, `CHOWN`, `SETUID`, `SETGID`.
