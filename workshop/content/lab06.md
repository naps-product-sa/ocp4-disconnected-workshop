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
3. Use the following Python code to minify your container registry pull secret:
   ```execute
   python3 -c $'import json\nimport sys\nwith open(sys.argv[1], "r") as f: print(json.dumps(json.load(f)))' /run/user/1000/containers/auth.json
   ```
   > For connected installations, you can get this secret from here: https://console.redhat.com/openshift/install/pull-secret.
4. Then generate `install-config.yaml`:
   ```execute
   /mnt/high-side/openshift-install create install-config --log-level=DEBUG
   ```

   The OpenShift installer will prompt you for a number of fields:
   * **SSH Public Key** - The SSH public key used to access all nodes within the cluster. Be sure to select the **disco-openshift-key** you just created.
   * **Platform** - The platform on which the cluster will run. Choose **aws**.
   * **AWS Access Key** and **Secret Access Key** - Enter your AWS credentials from RHDP.
   * **Region** - The AWS region to be used for installation. Choose **us-east-1**.
   * **Base Domain** - The base domain of the cluster. All DNS records will be sub-domains of this base and will also include the cluster name. Select the **sandboxXXXX.opentlc.com** option shown.
   * **Cluster Name** - The name of the cluster. This will be used when generating sub-domains. Let's use **disco**.
   * **Pull Secret** - The container registry pull secret for this cluster (minified in the previous step)

   That's it! The installer will generate `install-config.yaml` and drop it in `/mnt/install` for you.
5. We need to make a couple changes to this config before we kick off the install:
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
   * Add the `imageContentSources` that `oc mirror` produced to ensure image mappings happen correctly. You can find them by running this command:
     ```execute
     grep "mirror" -A 2 /mnt/high-side/oc-mirror-workspace/results-*/imageContentSourcePolicy.yaml
     ```
     Then add them to your `install-config.yaml` so that they look something like this:
     ```bash
     imageContentSources:
       - mirrors:
          - ip-10-0-51-206.ec2.internal:8443/openshift/release-images
          source: quay.io/openshift-release-dev/ocp-release
       - mirrors:
          - ip-10-0-51-206.ec2.internal:8443/openshift/release
          source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
     ```

     > Instead of adding this field to the `install-config.yaml` you could drop the `imageContentSourcePolicy.yaml` file in the manifests directory after running `openshift-install create manifests` to achieve the same result.

   * Add the root CA of our mirror registry (`/mnt/quay/quay-install/quay-rootCA/rootCA.pem`) to the trust bundle using the `additionalTrustBundle` field. It should look something like this:
     ```bash
     ...
     additionalTrustBundle: |
       -----BEGIN CERTIFICATE-----
       MIID2DCCAsCgAwIBAgIUbL/naWCJ48BEL28wJTvMhJEz/C8wDQYJKoZIhvcNAQEL
       BQAwdTELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAlZBMREwDwYDVQQHDAhOZXcgWW9y
       azENMAsGA1UECgwEUXVheTERMA8GA1UECwwIRGl2aXNpb24xJDAiBgNVBAMMG2lw
       LTEwLTAtNTEtMjA2LmVjMi5pbnRlcm5hbDAeFw0yMzA3MTExODIyMjNaFw0yNjA0
       MzAxODIyMjNaMHUxCzAJBgNVBAYTAlVTMQswCQYDVQQIDAJWQTERMA8GA1UEBwwI
       TmV3IFlvcmsxDTALBgNVBAoMBFF1YXkxETAPBgNVBAsMCERpdmlzaW9uMSQwIgYD
       VQQDDBtpcC0xMC0wLTUxLTIwNi5lYzIuaW50ZXJuYWwwggEiMA0GCSqGSIb3DQEB
       AQUAA4IBDwAwggEKAoIBAQDEz/8Pi4UYf/zanB4GHMlo4nbJYIJsyDWx+dPITTMd
       J3pdOo5BMkkUQL8rSFkc3RjY/grdk2jejVPQ8sVnSabsTl+ku7hT0t1w7E0uPY8d
       RTeGoa5QvdFOxWz6JsLo+C+JwVOWI088tYX1XZ86TD5FflOEeOwWvs5cmQX6L5O9
       QGO4PHBc9FWpmaHvFBiRJN3AQkMK4C9XB82G6mCp3c1cmVwFOo3vX7h5738PKXWg
       KYUTGXHxd/41DBhhY7BpgiwRF1idfLv4OE4bzsb42qaU4rKi1TY+xXIYZ/9DPzTN
       nQ2AHPWbVxI+m8DZa1DAfPvlZVxAm00E1qPPM30WrU4nAgMBAAGjYDBeMAsGA1Ud
       DwQEAwIC5DATBgNVHSUEDDAKBggrBgEFBQcDATAmBgNVHREEHzAdghtpcC0xMC0w
       LTUxLTIwNi5lYzIuaW50ZXJuYWwwEgYDVR0TAQH/BAgwBgEB/wIBATANBgkqhkiG
       9w0BAQsFAAOCAQEAkkV7/+YhWf1vq//N0Ms0td0WDJnqAlbZUgGkUu/6XiUToFtn
       OE58KCudP0cAQtvl0ISfw0c7X/Ve11H5YSsVE9afoa0whEO1yntdYQagR0RLJnyo
       Dj9xhQTEKAk5zXlHS4meIgALi734N2KRu+GJDyb6J0XeYS2V1yQ2Ip7AfCFLdwoY
       cLtooQugLZ8t+Kkqeopy4pt8l0/FqHDidww1FDoZ+v7PteoYQfx4+R5e8ko/vKAI
       OCALo9gecCXc9U63l5QL+8z0Y/CU9XYNDfZGNLSKyFTsbQFAqDxnCcIngdnYFbFp
       mRa1akgfPl+BvAo17AtOiWbhAjipf5kSBpmyJA==
       -----END CERTIFICATE-----
     ```
   * If you get x509 errors regarding the mirror registry root CA, try using `cat` or `echo` to append the `rootCA.pem` file to your `install-config.yaml`, as copy and paste can introduce subtle formatting errors
   * Change `publish` from **External** to **Internal**. We're using private subnets to house the cluster, so it won't be publicly accessible.
6. Then make a backup of your `install-config.yaml` since the installer will consume (and delete) it:
   ```execute
   cp install-config.yaml install-config.yaml.bak
   ```

## Running the Installation
We're ready to run the install! Let's create the installation manifests and kick off the cluster installation:
```execute
/mnt/high-side/openshift-install create manifests
/mnt/high-side/openshift-install create cluster --log-level=DEBUG
```
The installation process should take about 30 minutes. If you've done everything correctly, you should see something like this:
```bash
...
INFO Install complete!
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/home/myuser/install_dir/auth/kubeconfig'
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.mycluster.example.com
INFO Login to the console with user: "kubeadmin", and password: "password"
INFO Time elapsed: 30m49s
```
