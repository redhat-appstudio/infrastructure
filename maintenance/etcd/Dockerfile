FROM registry.redhat.io/openshift4/ose-etcd-rhel9:v4.17.0

ADD defrag.sh /opt/

RUN dnf -y install jq && dnf clean all

CMD [ "/bin/sh" ]
