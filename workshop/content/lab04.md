In this lab, we'll prepare the low side.

## Creating a Prep System
Let's start by creating a prep system so we can begin downloading content.

1. Collect the IDs for your VPC and public subnet:
   ```execute
   VPC_ID=$(aws ec2 describe-vpcs | jq '.Vpcs[] | select(.Tags[].Value=="disco").VpcId' -r)
   echo $VPC_ID

   PUBLIC_SUBNET=$(aws ec2 describe-subnets | jq '.Subnets[] | select(.Tags[].Value=="Public Subnet - disco").SubnetId' -r)
   echo $PUBLIC_SUBNET
   ```
2. Create a Security Group and collect its ID. We're going to use this for both the prep system, and later for the bastion server:
   ```execute
   aws ec2 create-security-group --group-name disco-sg --description disco-sg --vpc-id ${VPC_ID} --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=disco-sg}]"

   SG_ID=$(aws ec2 describe-security-groups --filters "Name=tag:Name,Values=disco-sg" | jq -r '.SecurityGroups[0].GroupId')
   echo $SG_ID
   ```
3. Open ports 22 and 8443 for our hosts. 22 is for SSH access, and 8443 is for mirror registry communication:
   ```execute
   aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
   aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 8443 --cidr 0.0.0.0/0
   ```
4. Next we'll specify an Amazon Machine Image (AMI) to use for our prep system. For this lab, we'll just use the [Marketplace AMI for RHEL 8](https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#ImageDetails:imageId=ami-06640050dc3f556bb) in `us-east-1`:
   ```execute
   AMI_ID="ami-06640050dc3f556bb"
   ```
5. Ready to launch! We'll use the `t2.micro` instance type, which offers 1GiB of RAM and 1vCPU, along with a 50GiB volume to ensure we have enough storage for mirrored content:
   ```execute
   PREP_SYSTEM_NAME="disco-prep-system"

   aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.micro --key-name $KEY_NAME --security-group-ids $SG_ID --subnet-id $PUBLIC_SUBNET --associate-public-ip-address --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$PREP_SYSTEM_NAME}]" --block-device-mappings "DeviceName=/dev/sdh,Ebs={VolumeSize=50}"
   ```

## Downloading Tooling
Now that our prep system is up, let's SSH into it and download the content we'll need to support our install on the high side.

1. Grab the IP address for the prep system and SSH into it using `disco_key`:
   ```execute
   PREP_SYSTEM_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$PREP_SYSTEM_NAME" | jq -r '.Reservations[0].Instances[0].PublicIpAddress')
   echo $PREP_SYSTEM_IP

   ssh -i disco_key ec2-user@$PREP_SYSTEM_IP
   ```
   > If your `ssh` command times out here, your prep system is likely still booting up. Give it a minute and try again.
2. Let's mount the EBS volume we attached so we can build our collection of stuff to ship to the high side:
   ```execute
   sudo mkfs -t xfs /dev/xvdh
   sudo mount /dev/xvdh /mnt
   sudo chown ec2-user:ec2-user /mnt

   mkdir /mnt/high-side
   ```
3. Let's grab the tools we'll need for the bastion server - we'll use some of them on the prep system too. Life's good on the low side; we can download these from the Internet and tuck them into our high side gift basket at `/mnt/high-side`:
   * `oc`: OpenShift CLI
      ```execute
      cd /mnt

      curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz -L -o oc.tar.gz
      tar -xzf oc.tar.gz
      rm -f oc.tar.gz kubectl
      cp oc /mnt/high-side
      sudo mv oc /usr/local/bin/
      ```
   * `oc-mirror`: oc plugin for mirorring release, operator, and helm content
     ```execute
     curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/oc-mirror.tar.gz -L -o oc-mirror.tar.gz
     tar -xzf oc-mirror.tar.gz
     rm -f oc-mirror.tar.gz
     chmod +x oc-mirror
     cp oc-mirror /mnt/high-side
     sudo mv oc-mirror /usr/local/bin/
     ```
   * `mirror-registry`: small-scale Quay registry designed for mirroring
     ```execute
     curl https://mirror.openshift.com/pub/openshift-v4/clients/mirror-registry/latest/mirror-registry.tar.gz -L -o mirror-registry.tar.gz
     tar -xzf mirror-registry.tar.gz
     rm -f mirror-registry.tar.gz
     mv -t /mnt/high-side/ mirror-registry image-archive.tar execution-environment.tar
     ```
   * `openshift-installer`: OpenShift Installer
     ```execute
     curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-install-linux.tar.gz -L -o openshift-installer.tar.gz
     tar -xzf openshift-installer.tar.gz
     rm -f openshift-installer.tar.gz
     mv openshift-install /mnt/high-side
     ```

## Mirroring Content to Disk
The `oc-mirror` plugin supports mirroring content directly from upstream sources to a mirror registry, but since there is an air gap between our low side and high side, that's not an option for this lab. Instead, we'll mirror content to a tarball on disk that we can then sneakernet into the bastion server on the high side. We'll then mirror from the tarball into the mirror registry from there.

1. We'll first need an OpenShift pull secret to authenticate to the Red Hat registries. Grab yours from the [Hybrid Cloud Console](https://console.redhat.com/openshift/install/pull-secret) and save it to `~/.docker/config.json` on your prep system.
2. Next, we need to generate an `ImageSetConfiguration` that describes the parameters of our mirror. You can generate one like this:
   ```execute
   oc mirror init > imageset-config.yaml
   ```
3. To save time and storage, we're going to remove the operator catalogs and mirror only the release images. So edit your `imageset-config.yaml` to look like this:
   ```bash
   # TODO: do like one operator here just to show it
   kind: ImageSetConfiguration
   apiVersion: mirror.openshift.io/v1alpha2
   storageConfig:
     local:
       path: ./
   mirror:
     platform:
       channels:
       - name: stable-4.13
         type: ocp
   ```
4. Now we're ready to kick off the mirror! This should take about 10 minutes, so grab a coffee while it's running, or start on the next lab in a new terminal.
   ```execute
   oc mirror --config imageset-config.yaml file:///mnt/high-side
   ```
