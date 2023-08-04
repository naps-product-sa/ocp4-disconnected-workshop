If you made it here, congratulations! You have officially stood up a disconnected cluster!

You should be able to access the API server from the bastion by leveraging the `kubeconfig` file the installer creates for you:
```execute
export KUBECONFIG=/mnt/install/auth/kubeconfig
oc status
```
Example output:
```bash
[ec2-user@ip-10-0-51-206 install]$ oc status
In project default on server https://api.disco.sandbox2099.opentlc.com:6443

svc/openshift - kubernetes.default.svc.cluster.local
svc/kubernetes - 172.30.0.1:443 -> 6443

View details with 'oc describe <resource>/<name>' or list resources with 'oc get all'.
```

## Accessing the Web Console
Hitting the web console is a little bit trickier. Our cluster not only lacks direct *egress* to the Internet, but because it lives in a private subnet, we don't have *ingress* either. Notice that if you try to navigate to the address shown by running `oc whoami --show-console` in your laptop's browser, the request will fail.

To mitigate this, we'll use our prep system as a **jump host**.

> You'll need administrative privileges on your laptop to achieve this.

1. First, we'll need to add some entries to your laptop's `/etc/hosts` file. Set an environment variable with your cluster domain:
   ```bash
   # e.g. disco.sandbox2099.opentlc.com
   CLUSTER_DOMAIN=disco.<YOUR DOMAIN>
   ```
   Then add hostfile entries for the API server, console URL, and oauth endpoint. The password prompt here is for your local laptop password:
   ```execute
   sudo echo 127.0.0.1 api.$CLUSTER_DOMAIN >> /etc/hosts
   sudo echo 127.0.0.1 console-openshift-console.apps.$CLUSTER_DOMAIN >> /etc/hosts
   sudo echo 127.0.0.1 oauth-openshift.apps.$CLUSTER_DOMAIN >> /etc/hosts
   ```
2. Then setup an SSH tunnel to the prep system:
   ```execute
   sudo ssh -i disco_key \
     -L 6443:api.$CLUSTER_DOMAIN:6443 \
     -L 443:console-openshift-console.apps.$CLUSTER_DOMAIN:443 \
     -L 80:console-openshift-console.apps.$CLUSTER_DOMAIN:80 \
     ec2-user@$PREP_SYSTEM_IP
   ```
3. Now you should be able to access the console in your browser:
   ```execute
   echo https://console-openshift-console.apps.$CLUSTER_DOMAIN
   ```
   ![console](images/console.png)<br/>
   Success!

Now the cluster's up and we can successfully access it. But what comes next?