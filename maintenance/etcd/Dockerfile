# First stage: Build etcdctl
FROM registry.access.redhat.com/ubi9/go-toolset:1.25.9-1777537863@sha256:634d5f68245449c0427cfb1e9a1ec629e24ffe61dfb9e450f8ce9e8376d05904 AS builder

WORKDIR /opt/app-root/src

# Copy the Go Modules manifests
COPY build-deps/go.mod build-deps/go.sum ./

# Download dependencies
RUN go mod download

# Build etcdctl
RUN go build -o etcdctl go.etcd.io/etcd/etcdctl/v3

# Second stage: Create the final image
FROM registry.redhat.io/ubi9:9.7-1775624009

COPY defrag.sh /opt/

RUN dnf -y install jq && dnf clean all

# Copy etcdctl from builder
COPY --from=builder  /opt/app-root/src/etcdctl /usr/bin/etcdctl

CMD [ "/bin/sh" ]
