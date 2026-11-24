variable "REGISTRY" {
  default = "ghcr.io/taha2samy-3"
}

variable "IMAGE_NAME" {
  default = "dify-sandbox"
}

# Target Dify Sandbox upstream version (Pinned stable tag)
variable "DIFY_SANDBOX_VERSION" {
  default = "0.2.15"
}

# Image release tag (e.g. 0.2.15-v1.0.0 or commit sha) - STRICT: NO latest tag!
variable "VERSION" {
  default = "0.2.15-v1.0.0"
}

variable "GOLANG_IMAGE" {
  default = "golang:1.24.0-bookworm"
}

variable "WOLFI_IMAGE" {
  default = "cgr.dev/chainguard/wolfi-base@sha256:be019c1c74fe69204a42c4e10bc4d886a49bf5403ffa74374ef7baa408fc9a26"
}

# External packages passed from outside
# Example: docker buildx bake --set *.args.PYTHON_PACKAGES="pandas numpy scipy"
variable "PYTHON_PACKAGES" {
  default = ""
}

variable "NODE_PACKAGES" {
  default = ""
}

group "default" {
  targets = ["sandbox"]
}

target "sandbox" {
  context    = "."
  dockerfile = "Dockerfile"
  platforms  = ["linux/amd64"]
  args = {
    DIFY_SANDBOX_VERSION = "${DIFY_SANDBOX_VERSION}"
    GOLANG_IMAGE         = "${GOLANG_IMAGE}"
    WOLFI_IMAGE          = "${WOLFI_IMAGE}"
    PYTHON_PACKAGES      = "${PYTHON_PACKAGES}"
    NODE_PACKAGES        = "${NODE_PACKAGES}"
  }
  # Strict requirement: Explicit version tags, NO latest!
  tags = [
    "${REGISTRY}/${IMAGE_NAME}:${VERSION}",
    "${REGISTRY}/${IMAGE_NAME}:${DIFY_SANDBOX_VERSION}"
  ]
  # Native GitHub Actions cache configuration
  cache-from = [
    "type=gha"
  ]
  cache-to = [
    "type=gha,mode=max"
  ]
}

# Variant target: Data Science package bundle
target "sandbox-datascience" {
  inherits = ["sandbox"]
  args = {
    PYTHON_PACKAGES = "scipy scikit-learn seaborn matplotlib tabulate"
    NODE_PACKAGES   = "mathjs chart.js"
  }
  tags = [
    "${REGISTRY}/${IMAGE_NAME}:${VERSION}-datascience",
    "${REGISTRY}/${IMAGE_NAME}:${DIFY_SANDBOX_VERSION}-datascience"
  ]
}
