#!/bin/sh

set -x

first_endpoint=$(echo $ETCDCTL_ENDPOINTS | cut -d',' -f1)

echo $first_endpoint

diff=$(ETCDCTL_ENDPOINTS="${first_endpoint}" etcdctl endpoint status --write-out=json | jq -r '.[] | .Status.dbSize - .Status.dbSizeInUse')
ondisk=$(ETCDCTL_ENDPOINTS="${first_endpoint}" etcdctl endpoint status --write-out=json | jq -r '.[] | .Status.dbSize')

# Calculate fragmented percentage
fragmentedPercentage=$(( ${diff} * 100 / ${ondisk} ))
echo "Fragmented Percentage: ${fragmentedPercentage}%"

if (( fragmentedPercentage >= 30 )); then
    etcdctl defrag --command-timeout 30s
fi

# Calculate fragmented space in megabytes
fragmentedSpace=$(( ${diff} / 1024 / 1024 ))
echo "Fragmented Space: ${fragmentedSpace} MB"

# Perform defragmentation and compaction if needed
if [ "$fragmentedPercentage" -ge 30 ] || [ "$fragmentedSpace" -ge 1024 ]; then
    if [ "$fragmentedSpace" -ge 1024 ]; then
        rev=$(ETCDCTL_ENDPOINTS="${first_endpoint}" etcdctl endpoint status --write-out="json" | egrep -o '"revision":[0-9]*' | egrep -o '[0-9]*')
        etcdctl compact $rev
        etcdctl defrag --command-timeout 30s
    else
        echo "Fragmentation is above threshold, performing defragmentation..."
    fi
    etcdctl defrag --command-timeout 30s
else
    echo "No compaction and defragmentation needed."
fi
