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

To mitigate this, we'll use a handy SSH/DNS utility called `sshuttle` to setup an SSH tunnel to the prep system.

> You'll need administrative privileges on your laptop to achieve this.

1. First, you'll need to install sshuttle following the instructions for your operating system [here](https://github.com/sshuttle/sshuttle#obtaining-sshuttle).
2. Then setup an SSH tunnel to the prep system. This must be run from a terminal directly on your laptop:
   ```bash
   $PREP_SYSTEM_IP=<your prep system's public IP>

   sshuttle --ssh-cmd 'ssh -i ~/.ssh/disco_key' -r ec2-user@$PREP_SYSTEM_IP 10.0.0.0/16 --dns
   ```
3. Now you should be able to access the console in your browser:
   ```execute
   oc whoami --show-console
   ```
   ![console](images/console.png)<br/>
   Success!

Now the cluster's up and we can successfully access it. But what comes next?