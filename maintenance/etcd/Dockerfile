# First stage: Build etcdctl
FROM registry.access.redhat.com/ubi9/go-toolset:1.25@sha256:056bf34402458b6de803ef8f7b5c47fe25385393caebef7125060e564b0e5069 AS builder

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
