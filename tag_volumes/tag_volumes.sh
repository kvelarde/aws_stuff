#!/bin/bash

########################################################
# Searches for untagged volumes and generates them 
# from attached instance
########################################################

function get_tags_from_vol () {
    # Takes an InstanceID and returns its tags for jq input
    cat ${INSTANCE_FILE} | jq --arg inst $1 '.Reservations[].Instances[] | if .InstanceId == $inst then .Tags[] else empty end'
}

# Global Vars
REPLAY_LOG="volume_replay.log1"
REGION="us-west-1"

# Store json hash tables
INSTANCE_FILE="all_instances.json1"
VOLUME_FILE="all_vols.json1"
UNTAGGED_VOLS="untagged_vols.json1"

## Pull to reduce api lookups datasets 
aws --region ${REGION} ec2 --output json describe-instances > ${INSTANCE_FILE}
aws --region ${REGION} ec2 --output json describe-volumes > ${VOLUME_FILE}

# Create tmp file of untagged volumes
cat ${VOLUME_FILE} | jq -r '.[] | .[] | if has("Tags") == false then {"v": .VolumeId,"i": .Attachments[].InstanceId} else empty end' > ${UNTAGGED_VOLS}

# interate though untagged volumes data structure and tag that volume
cat ${UNTAGGED_VOLS} | jq -r '"\(.v) \(.i)"' | while read line; \
    do
        array=($line); VOL_ID=${array[0]}; INST_ID=${array[1]} 
        # Output to REPLAY log to run / verify later
        get_tags_from_vol ${INST_ID} | jq -r --arg vol ${VOL_ID} --arg region ${REGION} \
             '"aws ec2 --region \($region) create-tags --resources \($vol) --tags Key=_\(.Key),Value=\"\(.Value)\""' >> ${REPLAY_LOG}
    done

# 
# move for next run if need
mv ${REPLAY_LOG} ${REPLAY_LOG}.bck

