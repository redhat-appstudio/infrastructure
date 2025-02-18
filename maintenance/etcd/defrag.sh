#!/bin/sh

set -x

first_endpoint=$(echo $ETCDCTL_ENDPOINTS | cut -d',' -f1)

echo $first_endpoint
reclaim_space=$(ETCDCTL_ENDPOINTS="${first_endpoint}" etcdctl endpoint status --write-out=json | jq -r '.[] | .Status.dbSize - .Status.dbSizeInUse')

echo "Reclaim Space is : ${reclaim_space}"

reclaim_space_in_megabytes=$(( ${reclaim_space} / 1024 / 1024 ))

if (( reclaim_space_in_megabytes >= 1024 )); then
    rev=$(ETCDCTL_ENDPOINTS="${first_endpoint}" etcdctl endpoint status --write-out="json" | egrep -o '"revision":[0-9]*' | egrep -o '[0-9]*')
    etcdctl compact $rev
    etcdctl defrag
else
    echo "We can not reclaim more than 1024 megabytes. No Compaction and Defragmentation needed"
fi
