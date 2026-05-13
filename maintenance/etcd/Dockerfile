# First stage: Build etcdctl
FROM registry.access.redhat.com/ubi9/go-toolset:9.7-1778675823@sha256:90a36bc2013b3fcb28e2a4b082c9b895d7c2c679e58b95aed9721970f3339d0e AS builder

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
