# syntax=docker/dockerfile:1.7
ARG GOLANG_IMAGE=golang:1.24.0-bookworm
ARG WOLFI_IMAGE=cgr.dev/chainguard/wolfi-base@sha256:be019c1c74fe69204a42c4e10bc4d886a49bf5403ffa74374ef7baa408fc9a26

# ==============================================================
# Stage 1: Builder (Compile Go source, Seccomp CGO & Libs)
# ==============================================================
FROM ${GOLANG_IMAGE} AS builder

# Pinned Dify Sandbox stable release tag (default 0.2.15)
ARG DIFY_SANDBOX_VERSION=0.2.15
ARG NODE_PACKAGES=""

RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    gcc \
    git \
    libseccomp-dev \
    ca-certificates \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Clone specific stable tag (never latest or uncontrolled branches)
RUN git clone --depth 1 --branch ${DIFY_SANDBOX_VERSION} https://github.com/langgenius/dify-sandbox.git .

# Pre-install Node.js packages into dependens before Go compilation
# This embeds all packages inside the main binary for automatic sandbox extraction
COPY packages/node-requirements.txt /tmp/node-requirements.txt
RUN cd internal/core/runner/nodejs/dependens/node_temp && \
    if [ -s /tmp/node-requirements.txt ]; then \
      grep -v '^[[:space:]]*#' /tmp/node-requirements.txt | grep -v '^[[:space:]]*$' | xargs -r npm install --save; \
    fi && \
    if [ -n "${NODE_PACKAGES}" ]; then \
      npm install --save ${NODE_PACKAGES}; \
    fi && \
    rm -f /tmp/node-requirements.txt

ENV CGO_ENABLED=1
ENV GOOS=linux
ENV GOARCH=amd64
ENV GOTOOLCHAIN=auto

RUN go mod edit -go=1.24 && \
    go get -u golang.org/x/crypto@latest golang.org/x/net@latest golang.org/x/sys@latest google.golang.org/protobuf@latest && \
    go mod tidy && \
    # 1. Compile Python Seccomp C-shared library
    go build -o internal/core/runner/python/python.so -buildmode=c-shared -ldflags="-s -w" cmd/lib/python/main.go && \
    # 2. Compile Node.js Seccomp C-shared library
    go build -o internal/core/runner/nodejs/nodejs.so -buildmode=c-shared -ldflags="-s -w" cmd/lib/nodejs/main.go && \
    # 3. Compile main API server (embeds python.so and nodejs.so automatically)
    go build -o main -ldflags="-s -w" cmd/server/main.go && \
    # 4. Compile env discovery binary
    go build -o env -ldflags="-s -w" cmd/dependencies/init.go

# ==============================================================
# Stage 2: Runtime on Wolfi OS (Zero-CVE, glibc-based container)
# ==============================================================
FROM ${WOLFI_IMAGE}

ARG DIFY_SANDBOX_VERSION=0.2.15
# External packages injected via buildx bake
ARG PYTHON_PACKAGES=""
ARG NODE_PACKAGES=""

USER root
WORKDIR /

# 1. Install base utilities and runtimes from Wolfi APK repository
RUN apk update && apk add --no-cache \
    bash \
    curl \
    ca-certificates \
    tzdata \
    shadow \
    libseccomp \
    python-3.12 \
    py3-pip \
    nodejs-22 \
    npm && \
    useradd -u 65537 sandbox

# 2. Set global NODE_PATH and install Node.js packages
ENV NODE_PATH="/usr/lib/node_modules:/usr/local/lib/node_modules"

COPY packages/node-requirements.txt /tmp/node-requirements.txt
RUN if [ -s /tmp/node-requirements.txt ]; then \
      grep -v '^[[:space:]]*#' /tmp/node-requirements.txt | grep -v '^[[:space:]]*$' | xargs -r npm install -g; \
    fi && \
    if [ -n "${NODE_PACKAGES}" ]; then \
      npm install -g ${NODE_PACKAGES}; \
    fi && \
    rm -f /tmp/node-requirements.txt && \
    mkdir -p /usr/lib/node_modules && \
    ln -sf /usr/lib/node_modules /node_modules

# 3. Install Python packages
COPY packages/python-requirements.txt /tmp/python-requirements.txt
RUN if [ -s /tmp/python-requirements.txt ]; then \
      pip install --no-cache-dir --break-system-packages -r /tmp/python-requirements.txt; \
    fi && \
    if [ -n "${PYTHON_PACKAGES}" ]; then \
      pip install --no-cache-dir --break-system-packages ${PYTHON_PACKAGES}; \
    fi && \
    rm -f /tmp/python-requirements.txt

# 4. Copy compiled binaries and configurations from builder
COPY --from=builder /app/main /main
COPY --from=builder /app/env /env
COPY --from=builder /app/dependencies/python-requirements.txt /dependencies/python-requirements.txt

# 5. Create directories & copy configuration
RUN mkdir -p /conf /var/sandbox/sandbox-python /var/sandbox/sandbox-nodejs /logs && \
    chmod 777 /logs && \
    chmod +x /main /env

COPY conf/config.yaml /conf/config.yaml

# 6. Initialize python dependencies environment and clean up setup binary
RUN /env && rm -f /env && chmod -R 755 /var/sandbox

EXPOSE 8194

ENTRYPOINT ["/main"]
