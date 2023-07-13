In this lab, we'll make final preparations and execute the OpenShift Installer.

## Building install-config.yaml
1. Let's start by creating a workspace on the bastion to house our installation materials:
   ```execute
   mkdir /mnt/install
   cd /mnt/install
   ```
2. Then generate an SSH key pair for access to cluster nodes:
   ```execute
   ssh-keygen -f disco-openshift-key
   ```
3. Then generate `install-config.yaml`:
   ```execute
   /mnt/high-side/openshift-install create install-config --log-level=DEBUG
   ```

   The OpenShift installer will prompt you for a number of fields:
   * **SSH Public Key** - The SSH public key used to access all nodes within the cluster.
   * **Platform** - The platform on which the cluster will run. Choose **aws**.
   * **Region** - The AWS region to be used for installation. Choose **us-east-1**.
   * **Base Domain** - The base domain of the cluster. All DNS records will be sub-domains of this base and will also include the cluster name. Select the **sandboxXXXX.opentlc.com** option shown.
     > TODO: More commentary needed on DNS here or elsewhere
   * **Cluster Name** - The name of the cluster. This will be used when generating sub-domains. Let's use **disco**.
   * **Pull Secret** - The container registry pull secret for this cluster, as a single line of JSON (e.g. `{"auths": {...}}`). You can get this secret from https://console.redhat.com/openshift/install/pull-secret.

   That's it! The installer will generate `install-config.yaml` and drop it in `/mnt/install` for you.
4. We need to make a couple changes to this config before we kick off the install:
   * Add subnets to `platform.aws.networking`
   * Add hosted zone
   * Add mirror registry to pull secret
   * Add ICSP (here or after creating manifests)
   * Add additionalTrustBundle from mirror registry
   * Change publish to Internal
5. Then make a backup of your `install-config.yaml` since the installer will consume it:
   ```execute
   cp install-config.yaml install-config.yaml.bak
   ```

## Running the Installation
We're ready to run the install!
```execute
```

