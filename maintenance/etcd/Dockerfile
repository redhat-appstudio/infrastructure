# First stage: Build etcdctl
FROM registry.access.redhat.com/ubi9/go-toolset:1.25@sha256:8c5aeac74b4b60dc2e5e44f6b639186b7ec2fec8f0eb9a36d4a32dcf8e255f52 AS builder

WORKDIR /opt/app-root/src

# Copy the Go Modules manifests
COPY build-deps/go.mod build-deps/go.sum ./

# Download dependencies and build
RUN go mod download && \
    go build -o etcdctl go.etcd.io/etcd/etcdctl/v3

# Second stage: Create the final image
FROM registry.redhat.io/ubi9:9.7-1775624009

COPY defrag.sh /opt/

# Copy etcdctl from builder
COPY --from=builder  /opt/app-root/src/etcdctl /usr/bin/etcdctl

# hadolint ignore=DL3041 # we basically always want the latest version on jq, even if it's bad practice to not pin dependencies
RUN dnf -y install jq && dnf clean all

CMD [ "/bin/sh" ]
