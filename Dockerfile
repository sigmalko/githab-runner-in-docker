# syntax=docker/dockerfile:1
ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}
ARG RUNNER_VERSION=2.337.0
ARG RUNNER_ARCH=x64
ARG RUNNER_SHA256=70920811a4f8ad4328818682bca5c6469c1c942fab52448868071d0063816613
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive RUNNER_ALLOW_RUNASROOT=1
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git gh maven openjdk-21-jdk-headless python3 python3-pip docker.io docker-buildx docker-compose-v2 unzip zip tini \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/actions-runner
RUN case "${TARGETARCH}:${RUNNER_ARCH}" in amd64:x64|arm64:arm64) ;; *) echo 'Set RUNNER_ARCH and RUNNER_SHA256 for the target architecture.' >&2; exit 1 ;; esac \
    && curl --fail --location --retry 3 "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" -o /tmp/runner.tar.gz \
    && echo "${RUNNER_SHA256}  /tmp/runner.tar.gz" | sha256sum --check --strict \
    && tar -xzf /tmp/runner.tar.gz && rm /tmp/runner.tar.gz \
    && ./bin/installdependencies.sh && rm -rf /var/lib/apt/lists/*
COPY --chmod=755 entrypoint.sh /usr/local/bin/runner-entrypoint
WORKDIR /runner
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/runner-entrypoint"]
