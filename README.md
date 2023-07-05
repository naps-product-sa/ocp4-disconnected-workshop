# OpenShift 4 Disconnected Workshop
This repository houses the labguides for the Red Hat NAPS OpenShift 4 Disconnected workshop.

## Deploy me
Run this container with `podman`:
```bash
podman run --rm -it -p 8080:10080 quay.io/akrohg/ocp4-disconnected-workshop-dashboard:latest
```

Then open http://localhost:8080 in your browser

## Raw Lab
```bash
# ( Download AWS CLI )

ssh-keygen -f ./disco_key

KEY_NAME=

aws ec2 import-key-pair --key-name $KEY_NAME --public-key-material fileb://./disco_key.pub

# TODO: Do we need 3 public subnets? Docs suggest only one
aws cloudformation create-stack --stack-name ocpdd --template-body file://./cloudformation.yaml --capabilities CAPABILITY_IAM

# Look at subnets
aws ec2 describe-subnets | jq '[.Subnets[].Tags[] | select(.Key=="Name").Value] | sort'

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs | jq '.Vpcs[] | select(.Tags[].Value=="ocpdd").VpcId' -r)

### LOW SIDE ###

# Get Subnet ID
PUBLIC_SUBNET=$(aws ec2 describe-subnets | jq '.Subnets[] | select(.Tags[].Value=="Public Subnet - ocpdd").SubnetId' -r)

## BASTION ##
# Create security group
TAG_SG="disco-bastion-sg"

aws ec2 create-security-group --group-name disco-bastion-sg --description disco-bastion-sg --vpc-id ${VPC_ID} --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$TAG_SG}]"

PublicSecurityGroupId=$(aws ec2 describe-security-groups --filters "Name=tag:Name,Values=disco-bastion-sg" | jq -r '.SecurityGroups[0].GroupId')
echo $PublicSecurityGroupId

aws ec2 authorize-security-group-ingress --group-id $PublicSecurityGroupId --protocol tcp --port 22 --cidr 0.0.0.0/0

PREP_SYSTEM_NAME="disco-prep-system"
# set AMI ID (us-east-1 RHEL8)
AMI_ID="ami-06640050dc3f556bb"

# Create Prep Server
aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.micro --key-name $KEY_NAME --security-group-ids $PublicSecurityGroupId --subnet-id $PUBLIC_SUBNET --associate-public-ip-address --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$PREP_SYSTEM_NAME}]" --block-device-mappings "DeviceName=/dev/sdh,Ebs={VolumeSize=50}"

# Get prep system IP and check port 22
PREP_SYSTEM_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$PREP_SYSTEM_NAME" | jq -r '.Reservations[0].Instances[0].PublicIpAddress')
echo $PREP_SYSTEM_IP

nc -vz $PREP_SYSTEM_IP 22

# SSH to the server
ssh -i disco_key ec2-user@$PREP_SYSTEM_IP

# Mount volume
sudo mkfs -t xfs /dev/xvdh
sudo mount /dev/xvdh /mnt
sudo chown ec2-user:ec2-user /mnt

#get oc
curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz -L -o oc.tar.gz
tar -xzf oc.tar.gz
sudo mv oc /usr/local/bin/

#get openshift-installer
curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-install-linux.tar.gz -L -o openshift-installer.tar.gz
tar -xzf openshift-installer.tar.gz

#get oc-mirror
curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/oc-mirror.tar.gz -L -o oc-mirror.tar.gz
tar -xzf oc-mirror.tar.gz
chmod +x oc-mirror
sudo mv oc-mirror /usr/local/bin/

# setup your pull secret
# Grab it from here: https://console.redhat.com/openshift/install/pull-secret
# Then save it to ~/.docker/config.json

#create the image set
oc mirror init > imageset-config.yaml
# remove operators, man. Takes too long.

# run the sync (~10 minutes, grab a coffee)
oc mirror --config imageset-config.yaml file:///mnt

### HIGH SIDE ###
# Get Private Subnet ID
PRIVATE_SUBNET=$(aws ec2 describe-subnets | jq '.Subnets[] | select(.Tags[].Value=="Private Subnet - ocpdd").SubnetId' -r)

## BASTION ##
BASTION_NAME="disco-bastion-high"
# set AMI ID (us-east-1 RHEL8)
AMI_ID="ami-0f8f9d60f5a31cb15"

# Create Bastion Server
# Need to install podman but there's no internet! Let's use Image Builder:
# https://console.redhat.com/insights/image-builder
# Be sure to install podman and git

aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.large --key-name $KEY_NAME --security-group-ids $PublicSecurityGroupId --subnet-id $PRIVATE_SUBNET --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$BASTION_NAME}]" --block-device-mappings "DeviceName=/dev/sdh,Ebs={VolumeSize=50}"

# Get bastion IP and check port 22
BASTION_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$BASTION_NAME" | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
echo $BASTION_IP

# SSH to the server to prep system and then to bastion
# TODO: Is there a better way to simulate this?
scp -i disco_key disco_key ec2-user@$PREP_SYSTEM_IP:/home/ec2-user/disco_key 
ssh -i disco_key ec2-user@$BASTION_IP

# Mount volume
sudo mkfs -t xfs /dev/xvdh
sudo mount /dev/xvdh /mnt
sudo chown ec2-user:ec2-user /mnt

# Copy mirror tarball from prep system to bastion
# TODO: Dynamically get the IP for the bastion
scp -i disco_key /mnt/mirror_seq1_000000.tar ec2-user@10.0.51.231:/mnt/

# While that's running, install podman and git
# TODO: Need another way to do this since we can't install packages on the high side!!
# TODO: Change storage path for podman to use /mnt due to storage issues
sudo yum install -y podman git

# Get mirror registry
cd /mnt
curl https://mirror.openshift.com/pub/openshift-v4/clients/mirror-registry/latest/mirror-registry.tar.gz -L -o mirror-registry.tar.gz
tar -xzf mirror-registry.tar.gz

# Careful for issues running out of space
# Start registry
# TODO: dynamically get internal hostname
./mirror-registry install --quayHostname ip-10-0-51-231.ec2.internal --quayRoot /mnt/quay

# get oc and oc-mirror to the PATH on the bastion first, then mirror from disk to reg
# TODO: use quay root CA from /mnt/quay/quay-rootCA
podman login --tls-verify=false https://ip-10-0-59-47.ec2.internal:8443
oc mirror --from=./mirror_seq1_000000.tar --dest-skip-tls docker://ip-10-0-59-47.ec2.internal:8443


```



