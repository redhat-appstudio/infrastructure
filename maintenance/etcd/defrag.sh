#!/bin/sh

set -x

diskUsageThreshold=${diskUsageThreshold:-60}
fragmentationThreshold=${fragmentationThreshold:-30}
reclaimSpaceThreshold=${reclaimSpaceThreshold:-1024}

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

diskUsage=$((${ondisk} * 100 / (8 * 1024 * 1024 * 1024)))
echo "Disk Usage: ${diskUsage}"

# Perform defragmentation if needed
if [ "$diskUsage" -lt "$diskUsageThreshold" ]; then
    echo "Disk usage is below threshold, no defragmentation needed."
    exit 0
fi

if [ "$fragmentedPercentage" -ge "$fragmentationThreshold" ] || [ "$fragmentedSpace" -ge "$reclaimSpaceThreshold" ]; then
    echo "Fragmentation is above threshold, performing defragmentation..."
    etcdctl defrag --command-timeout 60s
else
    echo "No defragmentation needed."
    exit 0
fi
