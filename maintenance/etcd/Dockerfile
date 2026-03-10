FROM registry.access.redhat.com/ubi9/go-toolset:1.24 AS build

WORKDIR /build

COPY etcd-defrag/ ./

RUN go build -o etcd-defrag .

FROM registry.redhat.io/ubi9/ubi-minimal:9.7

COPY --from=build /build/etcd-defrag /usr/local/bin/etcd-defrag

ADD defrag.sh /opt/

USER 1001

CMD ["/bin/sh", "/opt/defrag.sh"]
