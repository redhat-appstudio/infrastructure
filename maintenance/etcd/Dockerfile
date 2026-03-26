# First stage: Build etcdctl
FROM registry.access.redhat.com/ubi9/go-toolset:9.7-1774499506 AS build

WORKDIR /build

# Copy the Go Modules manifests
COPY build-deps/go.mod build-deps/go.sum ./

# Download dependencies
RUN go mod download

# Build etcdctl
RUN go build -o etcdctl go.etcd.io/etcd/etcdctl/v3

# Second stage: Create the final image
FROM registry.redhat.io/ubi9:9.7-1762180182

ADD defrag.sh /opt/

RUN dnf -y install jq && dnf clean all

# Copy etcdctl from builder
COPY --from=build /build/etcdctl /usr/bin/etcdctl

CMD [ "/bin/sh" ]
