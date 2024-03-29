In this lab, we'll create an Air Gap in AWS.

1. Configure your AWS CLI with the credentials you received from RHDP.
   ```execute
   aws configure
   ```
2. Set the `region` and `output` to `us-east-1` and `json`, respectively:
   ```execute
   aws configure set region us-east-1
   aws configure set output json
   ```
3. Create a key pair and import it to AWS. We're going to use this to SSH into our **prep system** and **bastion server**:
   ```execute
   ssh-keygen -f ~/disco_key -q -N ""
   ```
   ```execute
   aws ec2 import-key-pair --key-name disco-key --public-key-material fileb://~/disco_key.pub
   ```
   > Depending how you're running this workshop, you may receive the following error:
   >
   >     An error occurred (AuthFailure) when calling the DescribeSubnets operation: AWS was not able to validate the provided access credentials
   > This is likely due to your system's date being out of sync. You can confirm this by comparing the system's date to the current local time:
   >
   >     date
   > If the system date is too far behind, AWS will reject any requests to its API with a 405. If you're running `podman machine`, this can be fixed by running:
   >
   >     podman machine ssh "sudo systemctl restart systemd-timesyncd.service"
4. Instantiate a CloudFormationTemplate. This creates a VPC that houses both sides of the air gap:
   ```execute
   # Grab the template file from the repo
   curl https://raw.githubusercontent.com/naps-product-sa/ocp4-disconnected-workshop/main/cloudformation.yaml -o cloudformation.yaml

   # Create the stack
   aws cloudformation create-stack --stack-name disco --template-body file://./cloudformation.yaml --capabilities CAPABILITY_NAMED_IAM --parameters "ParameterKey=KeyName,ParameterValue=disco-key"
   ```
5. We just created a VPC with 1 public subnet, which will serve as our Low Side, and 3 private subnets, which will serve as our High Side. You can view them by running the command below:
   ```execute
   aws ec2 describe-subnets | jq '[.Subnets[].Tags[] | select(.Key=="Name").Value] | sort'
   ```
   > This may take a minute or two while the resources in the stack are created.
   
   Example output:
   ```bash
   [
     "disco-private-us-east-1a",
     "disco-private-us-east-1b",
     "disco-private-us-east-1c",
     "disco-public"
   ]
   ```
   The high side protects outbound traffic with a [Squid proxy](http://www.squid-cache.org/) running in a NAT instance. The proxy prevents any egress traffic not listed in `/etc/squid/whitelist.txt` on that host. If you look at the template you'll notice our two entries are:
   * `.amazonaws.com`
   * `.cloudfront.net`
   * `.aws.ce.redhat.com`

   There may be situations where you wish to add more exceptions here, such as container or package repositories.

Now that our air gap is in place, let's start prepping the low side.
