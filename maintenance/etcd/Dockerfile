# First stage: Build etcdctl
FROM registry.access.redhat.com/ubi9/go-toolset:1.25.8-1776962329@sha256:75ecb48dfaec6655bd589091902e3b9328c300befba34cb06fc5e7323099e17d AS builder

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
