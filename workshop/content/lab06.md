In this lab, we'll make final preparations and execute the OpenShift Installer.

## Building install-config.yaml
1. Let's start by creating a workspace on the bastion to house our installation materials:
   ```execute
   mkdir /mnt/install
   cd /mnt/install
   ```
2. Then generate an SSH key pair for access to cluster nodes:
   ```execute
   ssh-keygen -f ~/.ssh/disco-openshift-key
   ```
3. Then generate `install-config.yaml`:
   ```execute
   /mnt/high-side/openshift-install create install-config --log-level=DEBUG
   ```

   The OpenShift installer will prompt you for a number of fields:
   * **SSH Public Key** - The SSH public key used to access all nodes within the cluster. Be sure to select the **disco-openshift-key** you just created.
   * **Platform** - The platform on which the cluster will run. Choose **aws**.
   * **Region** - The AWS region to be used for installation. Choose **us-east-1**.
   * **Base Domain** - The base domain of the cluster. All DNS records will be sub-domains of this base and will also include the cluster name. Select the **sandboxXXXX.opentlc.com** option shown.
   * **Cluster Name** - The name of the cluster. This will be used when generating sub-domains. Let's use **disco**.
   * **Pull Secret** - The container registry pull secret for this cluster, as a single line of JSON (e.g. `{"auths": {...}}`). You can get this secret from https://console.redhat.com/openshift/install/pull-secret.

   That's it! The installer will generate `install-config.yaml` and drop it in `/mnt/install` for you.
4. We need to make a couple changes to this config before we kick off the install:
   * Add the subnet IDs for your private subnets to `platform.aws.subnets`. Otherwise, the installer will create its own VPC and subnets. You can retrieve them by running this command from your workstation:
     ```execute
     aws ec2 describe-subnets | jq '[.Subnets[] | select(.Tags[].Value | contains ("Private")).SubnetId] | unique' -r
     ```
     Then add them to your `install-config.yaml` so that they look something like this:
     ```bash
     ...
     platform:
       aws:
         region: us-east-1
         subnets:
         - subnet-00f28bbc11d25d523
         - subnet-07b4de5ea3a39c0fd
         - subnet-07b4de5ea3a39c0fd
      ...
     ```
   * Modify the `machineNetwork` to match the IPv4 CIDR blocks from the private subnets. Otherwise your control plane and compute nodes will be assigned IP addresses that are out of range and break the install. You can retrieve them by running this command from your workstation:
     ```execute
     aws ec2 describe-subnets | jq '[.Subnets[] | select(.Tags[].Value | contains ("Private")).CidrBlock] | unique' -r
     ```
     Then add them to your `install-config.yaml` so that they look something like this:
     ```bash
     ...
     networking:
       clusterNetwork:
       - cidr: 10.128.0.0/14
       hostPrefix: 23
       machineNetwork:
       - cidr: 10.0.48.0/20
       - cidr: 10.0.64.0/20
       - cidr: 10.0.80.0/20
     ...
     ```
     > Note the `cidr: ` prefix in each array item.
   * Add mirror registry to pull secret
   * Add ICSP details (here or after creating manifests)
   * Add additionalTrustBundle from mirror registry
   * Change publish to Internal
5. Then make a backup of your `install-config.yaml` since the installer will consume (and delete) it:
   ```execute
   cp install-config.yaml install-config.yaml.bak
   ```

## Running the Installation
We're ready to run the install!
```execute
/mnt/high-side openshift-install create cluster --log-level=DEBUG
```



