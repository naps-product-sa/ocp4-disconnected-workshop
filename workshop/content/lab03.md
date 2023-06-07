In this lab, we'll download required content on the Connected Side.

## Mirroring Images
Images used by operators and platform components must be mirrored from upstream sources into a container registry that is accessible by the disconnected side. You can use any registry you like for this as long as it supports Docker v2-2, such as:
* Red Hat Quay
* JFrog Artifactory
* Sonatype Nexus Repository
* Harbor

An OpenShift subscription includes access to the [mirror registry for Red Hat OpenShift](https://docs.openshift.com/container-platform/4.13/installing/disconnected_install/installing-mirroring-creating-registry.html#installing-mirroring-creating-registry), which is a small-scale container registry designed specifically for mirroring images in disconnected installations. We'll make use of this option in this lab.

### Creating a Mirror Host
We're going to start by creating a host to house our registry. According to the [documentation](https://docs.openshift.com/container-platform/latest/installing/disconnected_install/installing-mirroring-creating-registry.html#prerequisites_installing-mirroring-creating-registry), our host must have the following characteristics:
* Red Hat Enterprise Linux (RHEL) 8 and 9 with Podman 3.4.2 or later and OpenSSL installed.
* 2 vCPUs
* 8 GB RAM
* About 12 GB for OpenShift Container Platform 4.13 release images, or about 358 GB for OpenShift Container Platform 4.13 release images and OpenShift Container Platform 4.13 Red Hat Operator images. Up to 1 TB per stream or more is suggested.

> Note that storage requirements are relatively modest for a bare-bones install, but a more future-proof setup has greater capacity to accommodate mirroring update streams when it comes time to upgrade the cluster.

Mirroring all release and operator images can take awhile depending on the network bandwidth. For this lab, we're going to start with just the release images. We'll provide options along the way to mirror more content if you wish.

```bash
# TODO - create ec2 or have this pre-configured
```

### Creating a Mirror Registry
Next we're going to deploy the registry itself. SSH into your registry host 

### Mirroring Content

### About the oc-mirror plugin