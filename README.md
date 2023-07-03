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

aws ec2 import-key-pair --key-name disco-key --public-key-material fileb://./disco_key.pub

# TODO: Do we need 3 public subnets? Docs suggest only one
aws cloudformation create-stack --stack-name ocpdd --template-body file://./cloudformation.yaml --capabilities CAPABILITY_IAM

# Look at subnets
aws ec2 describe-subnets | jq '[.Subnets[].Tags[] | select(.Key=="Name").Value] | sort'

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs | jq '.Vpcs[] | select(.Tags[].Value=="ocpdd").VpcId' -r)

# Get Subnet ID
PUBLIC_SUBNET=$(aws ec2 describe-subnets | jq '.Subnets[] | select(.Tags[].Value=="Public Subnet - ocpdd").SubnetId' -r)

## BASTION ##
# Create security group
TAG_SG="disco-bastion-sg"

aws ec2 create-security-group --group-name disco-bastion-sg --description disco-bastion-sg --vpc-id ${VPC_ID} --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$TAG_SG}]"

PublicSecurityGroupId=$(aws ec2 describe-security-groups --filters "Name=tag:Name,Values=disco-bastion-sg" | jq -r '.SecurityGroups[0].GroupId')
echo $PublicSecurityGroupId

aws ec2 authorize-security-group-ingress --group-id $PublicSecurityGroupId --protocol tcp --port 22 --cidr 0.0.0.0/0

TAG_VM="disco-bastion"
# set AMI ID (us-east-1 RHEL8)
AMI_ID="ami-06640050dc3f556bb"

# Create Prep Server
aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.micro --key-name disco-key --security-group-ids $PublicSecurityGroupId --subnet-id $PUBLIC_SUBNET --associate-public-ip-address --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_VM}]" --block-device-mappings "DeviceName=/dev/sdh,Ebs={VolumeSize=50}"

# Get bastion IP and check port 22
BASTION_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$TAG_VM" | jq -r '.Reservations[0].Instances[0].PublicIpAddress')
echo $BASTION_IP

nc -vz $BASTION_IP 22

# SSH to the server
ssh -i disco_key ec2-user@$BASTION_IP

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
```



