#!/bin/sh

set -x

maxFragmentedPercentage=${maxFragmentedPercentage:-50}
minDefragMB=${minDefragMB:-120}
first_endpoint=$(echo $ETCDCTL_ENDPOINTS | cut -d',' -f1)

echo $first_endpoint

rev=$(ETCDCTL_ENDPOINTS="${first_endpoint}" etcdctl endpoint status --write-out="json" | egrep -o '"revision":[0-9]*' | egrep -o '[0-9]*')
etcdctl compact --command-timeout 60s --physical $rev

diff=$(ETCDCTL_ENDPOINTS="${first_endpoint}" etcdctl endpoint status --write-out=json | jq -r '.[] | .Status.dbSize - .Status.dbSizeInUse')
ondisk=$(ETCDCTL_ENDPOINTS="${first_endpoint}" etcdctl endpoint status --write-out=json | jq -r '.[] | .Status.dbSize')

# Calculate fragmented percentage
fragmentedPercentage=$(( ${diff} * 100 / ${ondisk} ))
echo "Fragmented Percentage: ${fragmentedPercentage}%"

# Calculate fragmented space in megabytes
fragmentedSpace=$(( ${diff} / 1024 / 1024 ))
echo "Fragmented Space: ${fragmentedSpace} MB"

if [ "$fragmentedPercentage" -ge "$maxFragmentedPercentage" ] && [ "$fragmentedSpace" -ge "$minDefragMB" ]; then
    echo "Fragmentation is above threshold, performing defragmentation..."
    etcdctl defrag --command-timeout 60s
else
    echo "No defragmentation needed."
    exit 0
fi
