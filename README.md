# OpenShift 4 Disconnected Workshop
This repository houses the lab guides for the Red Hat NAPS OpenShift 4 Disconnected workshop.

## Run this workshop
First, ensure you have access to an AWS account with admin privileges. Our preferred method for this is to use the [AWS Blank Open Environment](https://demo.redhat.com/catalog?item=babylon-catalog-test/sandboxes-gpte.sandbox-open.test&utm_source=webapp&utm_medium=share-link) from the Red Hat Demo Platform. After a few minutes, you'll receive an email with an AWS Access Key/Secret Key pair for you to use in the exercises.

### Using Podman and OpenShift Homeroom
The lab guides for this workshop are built using [OpenShift Homeroom](https://github.com/openshift-homeroom) to provide a super slick in-browser experience. The smoothest way to run the workshop is via a container in `podman`:

```bash
podman pull quay.io/akrohg/ocp4-disconnected-workshop-dashboard:latest
podman run -d --name disco-dashboard -e TERMINAL_TAB=split -p 8080:10080 quay.io/akrohg/ocp4-disconnected-workshop-dashboard:latest
```

Then open http://localhost:8080 in your browser.
![homeroom](workshop/content/images/homeroom.png)

### Using standard markdown
Alternatively, you can run the exercises directly out of github by navigating to the first lab [here](workshop/content/lab01.md).





