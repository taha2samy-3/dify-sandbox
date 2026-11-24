# Dify Sandbox (Wolfi OS Edition)

Secure, zero-CVE, high-performance containerized execution environment for Dify code nodes, built on top of **Wolfi OS (Chainguard)** with **Docker Buildx Bake**, **Cosign Image Signing**, and **Remote Registry Caching**.

---

## 🌟 Key Architecture Highlights

1. **Wolfi OS Base (Zero CVEs + Glibc):**
   * Pinned digest: `cgr.dev/chainguard/wolfi-base@sha256:be019c1c74fe69204a42c4e10bc4d886a49bf5403ffa74374ef7baa408fc9a26`.
   * Built with standard `glibc` (unlike Alpine's `musl`), ensuring full native compatibility with Python scientific wheels (`numpy`, `pandas`) and Node.js C FFI (`koffi`).
2. **Pinned Upstream Stable Release:**
   * Built strictly from `langgenius/dify-sandbox` git tag **`0.2.15`** (no untracked branches or floating tags).
3. **Strict Tagging Policy (NO `latest`):**
   * All images are tagged explicitly with semantic versions (e.g., `0.2.15-v1.0.0` or git SHA `0.2.15-sha-abc1234`).
   * The `latest` tag is prohibited in CI.
4. **Remote Registry Caching:**
   * Configured with Buildx remote cache (`type=registry,ref=...:buildcache,mode=max`) for lightning-fast incremental builds.
5. **Supply Chain Security & Cosign Verification:**
   * Images are automatically signed in CI with Cosign (Keyless OIDC).
   * CI immediately verifies the signature against the repository identity.
   * SLSA Level 3 Build Provenance is attested.

---

## 📦 Passing Packages from Outside (Docker Bake)

You can customize the installed Python and Node.js packages in two ways:

### Method 1: Using the Requirements Files
Edit the requirements files in the repository:
* [packages/python-requirements.txt](file:///home/taha/Desktop/ourprojects/dify-sandbox/packages/python-requirements.txt)
* [packages/node-requirements.txt](file:///home/taha/Desktop/ourprojects/dify-sandbox/packages/node-requirements.txt)

### Method 2: Passing Packages Dynamically via Bake CLI
You can override or append packages directly from the command line:

```bash
docker buildx bake \
  --set *.args.PYTHON_PACKAGES="scipy scikit-learn polars" \
  --set *.args.NODE_PACKAGES="mathjs date-fns" \
  --set *.args.VERSION="0.2.15-custom-v1" \
  sandbox
```

---

## 🛠 Local Build & Testing

### 1. Build locally with Bake
```bash
docker buildx bake sandbox
```

### 2. Run local tests
```bash
chmod +x scripts/test-sandbox.sh
./scripts/test-sandbox.sh ghcr.io/pair-ai-platform/dify-sandbox:0.2.15-v1.0.0
```

### 3. Verify Image Signature
```bash
chmod +x scripts/verify-signature.sh
./scripts/verify-signature.sh ghcr.io/pair-ai-platform/dify-sandbox:0.2.15-v1.0.0
```
