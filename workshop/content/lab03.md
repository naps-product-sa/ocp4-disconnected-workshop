In this lab, we'll download required content on the Low Side.

## Creating the High Side and the Low Side
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
3. Instantiate a CloudFormationTemplate

## Creating a Prep System
We'll start this lab by creating a VM on the Low Side that we can load up with content and tooling that will eventually be transferred over to the High Side.

### 