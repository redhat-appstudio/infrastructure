FROM registry.redhat.io/ubi9:9.5 AS build

WORKDIR /root

RUN dnf -y install git go && dnf clean all
RUN git clone -b v3.5.18 https://github.com/etcd-io/etcd.git && \
    cd etcd && \
    ./build.sh && \
    export PATH="$PATH:`pwd`/bin" && \
    cp -rf /root/etcd/bin/etcdctl /usr/bin/etcdctl
    
# Second stage: Create the final image
FROM registry.redhat.io/ubi9:9.5
ADD defrag.sh /opt/

RUN dnf -y install jq && dnf clean all

# Copy etcdctl from builder
COPY --from=build /usr/bin/etcdctl /usr/bin/etcdctl

CMD [ "/bin/sh" ]
