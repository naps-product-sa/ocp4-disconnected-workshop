In this lab, we'll create an Air Gap in AWS.

1. Configure your AWS CLI with the credentials you received from RHDP:
   ```bash
   aws configure
   ```
2. Create a key pair and import it to AWS:
   ```bash
   ssh-keygen -f ./disco_key

   $KEY_NAME=disco-key

   aws ec2 import-key-pair --key-name $KEY_NAME --public-key-material fileb://./disco_key.pub
   ```
3. Instantiate a CloudFormationTemplate:
   ```bash
   aws cloudformation create-stack --stack-name disco --template-body file://./cloudformation.yaml --capabilities CAPABILITY_IAM
   ```
4. We just created a VPC with 3 public subnets, which will serve as our Low Side, and 3 private subnets, which will serve as our High Side. You can view them by running the command below:
   ```bash
   aws ec2 describe-subnets | jq '[.Subnets[].Tags[] | select(.Key=="Name").Value] | sort'
   ```
5. Set an environment variable for the VPC ID that we'll use in later labs:
   ```bash
   VPC_ID=$(aws ec2 describe-vpcs | jq '.Vpcs[] | select(.Tags[].Value=="disco").VpcId' -r)
   ```
