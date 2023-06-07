In this lab, we'll download required content to the Connected Side.

## Mirroring Images
Images used by operators and platform components must be mirrored from upstream sources into a container registry that is accessible by the disconnected side. To begin the mirroring process, you first need to deploy this registry.

### Creating a Mirror Host
We're going to start by creating a host on the connected side to house our registry. According to the [documentation](https://docs.openshift.com/container-platform/latest/installing/disconnected_install/installing-mirroring-creating-registry.html#prerequisites_installing-mirroring-creating-registry), our host must have the following characteristics:
* Red Hat Enterprise Linux (RHEL) 8 and 9 with Podman 3.4.2 or later and OpenSSL installed.
* 2 vCPUs
* 8 GB RAM
* About 12 GB for OpenShift Container Platform 4.13 release images, or about 358 GB for OpenShift Container Platform 4.13 release images and OpenShift Container Platform 4.13 Red Hat Operator images. Up to 1 TB per stream or more is suggested.

> Note that storage requirements are relatively modest for a bare-bones install, but a more future-proof setup has greater capacity to accommodate mirroring update streams when it comes time to upgrade the cluster.

Mirroring all release and operator images can take awhile depending on the network bandwidth. For this lab, we're going to start with just the release images. We'll provide options along the way to mirror more content if you wish.

```bash

```

### Creating a Mirror Registry

### Mirroring Content

### About the oc-mirror plugin