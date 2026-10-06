FROM quay.io/openshift/origin-cli:4.22

# Install yq (mikefarah v4): verify SHA256 of the release binary before install (supply-chain).
# Hash is for https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 (linux/amd64).
ARG YQ_VERSION=v4.47.1
ARG YQ_SHA256=0fb28c6680193c41b364193d0c0fc4a03177aecde51cfc04d506b1517158c2fb

ARG EPEL_VERSION=9-7.el9
ARG GIT_VERSION=2.52.0-1.el9
ARG KUSTOMIZE_VERSION=5.8.1-1.el9

SHELL ["/bin/bash", "-o", "pipefail"]

RUN curl -fsSL -o /tmp/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
    && echo "${YQ_SHA256}  /tmp/yq" | sha256sum -c - \
    && mv /tmp/yq /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# Install git & kustomize (single layer)
# hadolint ignore=DL3033 # we're specifying the version, though hadolint doesn't recognize the pattern we're using
RUN yum install -y "epel-release-${EPEL_VERSION}" \
    && yum install -y "git-${GIT_VERSION}" "kustomize-${KUSTOMIZE_VERSION}" \
    && yum clean all

# Copy the sync script
WORKDIR /scripts

COPY sync-rover-groups.sh /scripts/sync-rover-groups.sh
RUN chmod +x /scripts/sync-rover-groups.sh

# Run the sync script
ENTRYPOINT ["/bin/bash", "/scripts/sync-rover-groups.sh"]
