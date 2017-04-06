INSTANCE_MAP="all_instances.json"
VOLUME_MAP="all_vols.json"
SNAPSHOT_MAP1="all_snapshots-1.json"
SNAPSHOT_MAP2="all_snapshots-2.json"
SNAPSHOT_LOG="snapshot1.log"
COPY_LOG="copy_snapshots1.log"
SNAPSHOT_DATA="migration_volume_ids.json"

IDS="IDS"


#aws --region us-west-1 ec2 describe-snapshots > $SNAPSHOT_MAP1
#aws --region us-west-2 ec2 describe-snapshots > $SNAPSHOT_MAP2

function create_snapshot () {
    # call:
    #  create_snapshot $VOL_ID "${DESCRIPTION}" ${REGION} ${NAME} ${INSTANCE} ${MAPPING}
    snap_id=$(aws --region "${1}" ec2 create-snapshot --volume-id "${2}" --description "${3}" | jq -r ".SnapshotId")
    while state=$(aws --region "${1}"  ec2 describe-snapshots --snapshot-ids "${snap_id}"  --query 'Snapshots[*].State' --output text); \
        echo $state; test "${state}" = "pending"; do \
            echo -n .; sleep 3
    done
    
    # Name tag the snapshot
    aws ec2 --region ${1} create-tags --resources ${snap_id} --tags Key=Name,Value="${4}"
    aws ec2 --region ${1} create-tags --resources ${snap_id} --tags Key=instance,Value="${5}"
    aws ec2 --region ${1} create-tags --resources ${snap_id} --tags Key=mapping,Value="${6}"

    # Output snapshot
    printf "Snapshot: %b\n" ${snap_id} | tee -a ${SNAPSHOT_LOG}
}

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
    printf "Snapshot: %b\n" ${snap_id} | tee -a ${COPY_LOG}
}

function is_snapshot (){
# Given i, v, d return 0 if its in account
# cat all_snapshots-1.json | jq '.Snapshots[] | if .SnapshotId == "snap-4acd1368" then .Tags[] else empty end | if .Key == "mapping" then if .Value == "/dev/sda1" then .Value else empty end else empty end'
    continue
}

# Find instances with "migration" tag
ids=(`cat ${INSTANCE_MAP} | jq -r '.[] | .[] | .Instances[] | if has("Tags") == true then if .Tags[].Key == "migration" then .InstanceId else empty end else empty end'`)

# Loop though instances and output a json data structure of all volumes needed for snapshoting and metadata
for id in ${!ids[*]}
do
    cat ${VOLUME_MAP} | jq -r --arg instID ${ids[$id]} '.[] | .[] | if
    has("Tags") == true and .Attachments[].InstanceId == "\($instID)" then {"v":
    .VolumeId,"i": .Attachments[].InstanceId, "a": .Attachments[].Device} else empty end' | tee -a ${SNAPSHOT_DATA}
    
done

# Parse data structure and create snapshots for each element
cat ${SNAPSHOT_DATA}  | jq -r '.v + " " + .i + " " + .a' | \
while read line
do
    Volume=$(echo $line | awk '{ print $1 }')
    Instance=$(echo $line | awk '{ print $2 }')
    Attachment=$(echo $line | awk '{ print $3 }')
 
    echo create_snapshot us-west-1 $Volume "Migration: $Volume" $Volume $Instance $Attachment   
done

# Copy to different region
for line in `cat snapshot.log | awk '{ print $2 }'` 
do 
    echo $line
done

#create_snapshot us-west-1 vol-2f1b392c "migration of vol-2f1b392c" vol-2f1b392c inst map

# Create snapshot code
#create_snapshot "us-west-1" "vol-2f1b392c" "migration of vol-2f1b392c2" "vol-2f1b392c" "i-1234" "/dev/sda1"
