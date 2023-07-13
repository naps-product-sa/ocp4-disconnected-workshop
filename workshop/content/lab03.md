In this lab, we'll create an Air Gap in AWS.

1. Configure your AWS CLI with the credentials you received from RHDP:
   ```execute
   aws configure
   ```
2. Create a key pair and import it to AWS:
   ```execute
   ssh-keygen -f ./disco_key

   KEY_NAME=disco-key

   aws ec2 import-key-pair --key-name $KEY_NAME --public-key-material fileb://./disco_key.pub
   ```
   > Depending how you're running this workshop, you may receive the following error:
     ```bash
     An error occurred (AuthFailure) when calling the DescribeSubnets operation: AWS was not able to validate the provided access credentials
     ```
     This is likely due to your system's date being out of sync. You can confirm this by comparing the system's date to the current local time:
     ```execute
     date
     ```
     If the system date is too far behind, AWS will reject any requests to its API with a 405. If you're running `podman machine`, this can be fixed by running:
     ```bash
     podman machine ssh "sudo systemctl restart systemd-timesyncd.service"
     ```
3. Instantiate a CloudFormationTemplate:
   ```execute
   aws cloudformation create-stack --stack-name disco --template-body file://./cloudformation.yaml --capabilities CAPABILITY_IAM
   ```
4. We just created a VPC with 3 public subnets, which will serve as our Low Side, and 3 private subnets, which will serve as our High Side. You can view them by running the command below:
   ```execute
   aws ec2 describe-subnets | jq '[.Subnets[].Tags[] | select(.Key=="Name").Value] | sort'
   ```
   > This may take a minute or two while the resources in the stack are created.
   
   Example output:
   ```bash
   [
      "Private Subnet - disco",
      "Private Subnet 2 - disco",
      "Private Subnet 3 - disco",
      "Public Subnet - disco",
      "Public Subnet 2 - disco",
      "Public Subnet 3 - disco"
   ]
   ```