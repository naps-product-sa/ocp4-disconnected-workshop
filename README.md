# OpenShift 4 Disconnected Workshop
This repository houses the lab guides for the Red Hat NAPS OpenShift 4 Disconnected workshop.

## Rendering the workshop

```bash
mkdir output
podman run -it --rm -v `pwd`:/showroom/repo --entrypoint antora -w /showroom/repo ghcr.io/rhpds/showroom-content:latest --to-dir=output default-site.yml
python3 -m http.server 8080 --dir output/
```
