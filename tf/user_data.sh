#!/bin/bash

curl https://github.com/jbarratt.keys >> ~ec2-user/.ssh/authorized_keys
yum update -y
yum -y install tmux htop mosh jq
amazon-linux-extras install docker
sudo service docker start
sudo usermod -a -G docker ec2-user

REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq .region -r)
echo $REGION
INSTANCE=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq .instanceId -r)
echo $INSTANCE
VOLUME=$(aws ec2 describe-volumes --region $REGION --filters Name=tag:Name,Values=WorkspaceVol --query "Volumes[*].{ID:VolumeId}" --output=text)
echo $VOLUME

# This will error if already attached
aws ec2 attach-volume --region $REGION --volume-id $VOLUME --instance-id $INSTANCE --device /dev/sdf

# Make sure udev sets up the device
sleep 3

DEVICE=$(readlink /dev/sdf)
echo "/dev/sdf found at /dev/$DEVICE"

FSCHECK=$(file -s /dev/$DEVICE)
# Check if it's unformatted
if [[ "$FSCHECK" == *data ]]
then
        mkfs -t xfs /dev/$DEVICE
else
        echo "already formatted, not wiping"
fi

mkdir /workspace
chown ec2-user:ec2-user /workspace
mount /dev/$DEVICE /workspace
