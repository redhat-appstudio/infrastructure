# First stage: Build etcdctl
FROM registry.access.redhat.com/ubi9/go-toolset:1.26.10-1792671270@sha256:edb9452603fa48e9882063f001ecd7d322add20f1564a4f05f38f6683be5ea94 AS builder

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
