In this lab, we'll prepare the High Side. Recall from our architecture diagram that our bastion server on the high side will host our mirror registry. To do this we're interested in using `podman`, since it simplifies operation of the registry to run it within a container. 

However, we have a dilemma: the AMI we used for the prep system does not have `podman` installed! Unfortunately, `podman` cannot be sneakernetted into the bastion server as we're doing with other tools, because the installation requires a number of dependencies.

To solve this problem, most customers either *build a custom RHEL image* with `podman` pre-installed, **or** create a firewall exception in the high side to enable access to a content repository, like [RHUI](https://access.redhat.com/articles/4720861) (Red Hat Update Infrastructure). Recall from [Lab 2](lab02.md) that RHUI is part of our squid proxy's allowed list, so we'll be opting for the latter approach here.

## Creating a Bastion Server
Let's start by creating the bastion server. Your mirror may still be running from lab 4, so run these commands in a new terminal.

1. Grab the ID of a private subnet from the high side of our VPC as well as our Security Group ID:
   ```execute-2
   PRIVATE_SUBNET=$(aws ec2 describe-subnets | jq '.Subnets[] | select(.Tags[].Value=="disco-private-us-east-1a").SubnetId' -r)
   echo $PRIVATE_SUBNET

   SG_ID=$(aws ec2 describe-security-groups --filters "Name=tag:Name,Values=disco-sg" | jq -r '.SecurityGroups[0].GroupId')
   echo $SG_ID
   ```
2. Set an environment variable for your AMI_ID. We'll use the same one as we did for the prep system.
   ```execute-2
   AMI_ID="ami-0fe630eb857a6ec83"
   ```
3. Then spin up your EC2 instance. We're going to use a `t3.large` instance type which provides 2vCPU and 8GiB of RAM, along with a 50GiB volume to meet our storage requirements:
   ```execute-2
   BASTION_NAME="disco-bastion-server"
   
   aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t3.large --key-name disco-key --security-group-ids $SG_ID --subnet-id $PRIVATE_SUBNET --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$BASTION_NAME}]" --block-device-mappings "DeviceName=/dev/sdh,Ebs={VolumeSize=50}"
   ```

## Accessing the High Side
Now we need to access our bastion server on the high side. In real customer environments, this might entail use of a VPN, or physical access to a workstation in a secure facility such as a SCIF. To make things a bit simpler for our lab, we're going to restrict access to our bastion to its *private IP address*. So we'll use the prep system as a sort of bastion-to-the-bastion.

1. Start by grabbing the bastion's private IP:
   ```execute-2
   HIGHSIDE_BASTION_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$BASTION_NAME" | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
   echo $HIGHSIDE_BASTION_IP
   ```
2. Then let's `scp` our private key to the prep system so that we can SSH to the bastion from there. You may have to wait a minute for the VM to finish initializing:
   ```execute-2
   PREP_SYSTEM_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=disco-prep-system" | jq -r '.Reservations[0].Instances[0].PublicIpAddress')

   scp -i ~/disco_key disco_key ec2-user@$PREP_SYSTEM_IP:/home/ec2-user/disco_key
   ```
3. Then set an environment variable on the prep system so that we can preserve the bastion's IP:
   ```execute-2
   ssh -i ~/disco_key ec2-user@$PREP_SYSTEM_IP "echo HIGHSIDE_BASTION_IP=$(echo $HIGHSIDE_BASTION_IP) > /home/ec2-user/highside.env"
   ```
4. On your first terminal window, SSH from the prep system over to the bastion server. If your mirror is still running for some reason, you'll need to wait for it to complete before you continue:
   ```execute
   source ~/highside.env
   ssh -i ~/disco_key ec2-user@$HIGHSIDE_BASTION_IP
   ```
5. We're in! While we're on the bastion, let's go ahead and install `podman` and `jq`, which will come in handy for later:
   ```execute
   sudo yum install -y jq podman
   ```
   
6. Once that completes, let's confirm that `podman` installed successfully:
   ```execute
   podman version
   ```
   Example output:
   ```bash
   [ec2-user@ip-10-0-52-68 ~]$ podman version
   Client:       Podman Engine
   Version:      4.4.1
   API Version:  4.4.1
   Go Version:   go1.19.6
   Built:        Thu Jun 15 14:39:56 2023
   OS/Arch:      linux/amd64
   ```

   Nice! And come to think of it, let's also check that we have no Internet access:
   ```execute
   curl google.com
   ```

   Your output will contain something like this:
   ```html
   ...
   <blockquote id="error">
   <p><b>Access Denied.</b></p>
   </blockquote>

   <p>Access control configuration prevents your request from being allowed at this time. Please contact your service provider if you feel this is incorrect.</p>

   <p>Your cache administrator is <a href="mailto:root?subject=CacheErrorInfo%20-%20ERR_ACCESS_DENIED&amp;body=CacheHost%3A%20squid%0D%0AErrPage%3A%20ERR_ACCESS_DENIED%0D%0AErr%3A%20%5Bnone%5D%0D%0ATimeStamp%3A%20Thu,%2006%20Jul%202023%2013%3A45%3A11%20GMT%0D%0A%0D%0AClientIP%3A%2010.0.52.68%0D%0A%0D%0AHTTP%20Request%3A%0D%0AGET%20%2F%20HTTP%2F1.1%0AUser-Agent%3A%20curl%2F7.61.1%0D%0AAccept%3A%20*%2F*%0D%0AHost%3A%20google.com%0D%0A%0D%0A%0D%0A">root</a>.</p>
   <br>
   ...
   ```
   This response comes from the squid proxy in the NAT server, and it's blocking the request because google.com is not part of the allowed list.

## Sneakernetting Content to the High Side
We'll now deliver the high side gift basket to the bastion server.

1. Start by mounting our EBS volume on the bastion server to ensure that we don't run out of space:
   ```execute
   sudo mkfs -t xfs /dev/nvme1n1
   sudo mkdir /mnt/high-side
   sudo mount /dev/nvme1n1 /mnt/high-side
   sudo chown ec2-user:ec2-user /mnt/high-side
   ```
2. Then exit your SSH session on the bastion to return to the prep system:
   ```execute
   exit
   ```
3. Now we're back at the prep system. Let's send over our gift basket at `/mnt/high-side`:
   ```execute
   rsync -avP -e "ssh -i ~/disco_key" /mnt/high-side ec2-user@$HIGHSIDE_BASTION_IP:/mnt
   ```

## Creating a Mirror Registry
Images used by operators and platform components must be mirrored from upstream sources into a container registry that is accessible by the high side. You can use any registry you like for this as long as it supports Docker v2-2, such as:
* Red Hat Quay
* JFrog Artifactory
* Sonatype Nexus Repository
* Harbor

An OpenShift subscription includes access to the [mirror registry for Red Hat OpenShift](https://docs.openshift.com/container-platform/4.13/installing/disconnected_install/installing-mirroring-creating-registry.html#installing-mirroring-creating-registry), which is a small-scale container registry designed specifically for mirroring images in disconnected installations. We'll make use of this option in this lab.

Mirroring all release and operator images can take awhile depending on the network bandwidth. For this lab, recall that we're going to mirror just the release images to save time and resources.

We should have the `mirror-registry` binary along with the required container images available on the bastion in `/mnt/high-side`. The 50GB /mnt we created should be enough to hold our mirror (without operators) and binaries. 

First, let's SSH back into the bastion from the prep system:
```execute
ssh -i ~/disco_key ec2-user@$HIGHSIDE_BASTION_IP
```
And kick off our install:
```execute
cd /mnt/high-side
./mirror-registry install --quayHostname $(hostname) --quayRoot /mnt/high-side/quay/quay-install --quayStorage /mnt/high-side/quay/quay-storage --pgStorage /mnt/high-side/quay/pg-data --initPassword discopass
```

If all goes well, you should see something like:
```bash
INFO[2023-07-06 15:43:41] Quay installed successfully, config data is stored in /mnt/quay/quay-install 
INFO[2023-07-06 15:43:41] Quay is available at https://ip-10-0-51-47.ec2.internal:8443 with credentials (init, discopass) 
```

Login to the registry with `podman`. This will generate an auth file at `/run/user/1000/containers/auth.json`:
```execute
podman login -u init -p discopass --tls-verify=false $(hostname):8443
```
> We pass `--tls-verify=false` here for simplicity, but you can optionally add `/mnt/high-side/quay/quay-install/quay-rootCA/rootCA.pem` to the system trust store by following the guide in the Quay documentation [here](https://access.redhat.com/documentation/en-us/red_hat_quay/3/html/manage_red_hat_quay/using-ssl-to-protect-quay?extIdCarryOver=true&sc_cid=701f2000001OH74AAG#configuring_the_system_to_trust_the_certificate_authority).

## Mirroring Content
Now we're ready to mirror images from disk into the registry. Let's add `oc` and `oc-mirror` to the path:
```execute
sudo mv /mnt/high-side/oc /usr/local/bin/
sudo mv /mnt/high-side/oc-mirror /usr/local/bin/
```

And fire up the mirror! Let's send it to the background with `nohup` so we can get to work on the installation prep while this is running:
```execute
nohup oc mirror --from=/mnt/high-side/mirror_seq1_000000.tar --dest-skip-tls docker://$(hostname):8443 &
```
Press `ENTER` once more to get your prompt back. The log output will be streamed to a file called `nohup.out`, and your shell will notify you when the process has been completed after 10 minutes or so.

With the final mirror now running, there are only a few steps left to prepare the cluster installation. Let's get to it!
