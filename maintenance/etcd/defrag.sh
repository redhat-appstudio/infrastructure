#!/bin/sh

set -x

DEFRAG_RULE=${DEFRAG_RULE:-"dbQuotaUsage > 0.6 && ((dbSize - dbSizeInUse) * 100 / dbSize > 30 || dbSize - dbSizeInUse > 1024 * 1024 * 1024)"}

etcd-defrag \
  --endpoints "${ETCDCTL_ENDPOINTS}" \
  --compaction \
  --cluster \
  --continue-on-error \
  --wait-between-defrags "${WAIT_BETWEEN_DEFRAGS:-30s}" \
  --defrag-rule "${DEFRAG_RULE}" \
  "$@"
