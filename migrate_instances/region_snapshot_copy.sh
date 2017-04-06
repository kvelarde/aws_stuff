#!/bin/bash

WhoAmI=$(basename $0)
Usage=$( cat <<EOF
   ${WhoAmI} 
EOF
)
function copy_snapshot () {
    # call:
    #  copy_snapshot source-region dest-region snapshot-id descriptiong
    
    snap_id=$(aws --region ${1} ec2 copy-snapshot --source-region ${2} \
        --source-snapshot-id "${3}" --description "${4}" --output text) 
    echo ${snap_id} 
    while state=$(aws --region "${1}" ec2 describe-snapshots --snapshot-ids ${snap_id} --query 'Snapshots[*].State' --output text); \
        echo $state; test "${state}" = "pending"; do \
#            echo "waiting for snapshot: ${snap_id}"
            echo -n .; sleep 3
    done
    
    # Name tag the snapshot
    aws ec2 --region ${1} create-tags --resources ${snap_id} --tags Key=Name,Value="${4}"

    # Output snapshot
    printf "Snapshot: %b\n" ${snap_id}
}

while getopts ":s:d:i:D:" opt; do
    case $opt in
        s)
            SOURCE=$OPTARG
            ;;
        d) 
            DEST=$OPTARG
            ;;
        i)
            SNAPID=$OPTARG
            ;;
        D)
            DESC=$OPTARG
            ;;
        \?)
            echo "invalid character" >&2
            ;;
    esac
done

copy_snapshot ${SOURCE} ${DEST} ${SNAPID}  "${DESC}"
