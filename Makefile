# Simple Makefile for OCP4 Disconnected Workshop CloudFormation Deployment

# Variables
STACK_NAME ?= ocp4-disconnected-workshop
REGION ?= us-east-2
TEMPLATE_FILE = cloudformation.yaml

# Required Parameters - These must be provided
PASSWORD ?=
PULL_SECRET_FILE ?= pull-secret.txt

# AWS credentials from configuration
ACCESS_KEY := $(shell aws configure get aws_access_key_id)
SECRET_KEY := $(shell aws configure get aws_secret_access_key)

# Pull secret from file (base64 encoded)
PULL_SECRET := $(shell cat $(PULL_SECRET_FILE) 2>/dev/null | base64 -w 0 || echo "")

# Optional Parameters with defaults
VPC_CIDR ?= 10.0.0.0/16
NAT_INSTANCE_TYPE ?= m5a.large
JUMP_INSTANCE_TYPE ?= m5a.large
HIGHSIDE_INSTANCE_TYPE ?= m5a.large
JUMP_INSTANCE_DATA_VOLUME_SIZE ?= 100
HIGHSIDE_INSTANCE_DATA_VOLUME_SIZE ?= 500
S3_TRANSFER_BUCKET_NAME ?= autogenerate

.PHONY: help create delete status instances

help: ## Display this help message
	@echo "OCP4 Disconnected Workshop CloudFormation Deployment"
	@echo ""
	@echo "Usage: make [target] PASSWORD=xxx [PULL_SECRET_FILE=path/to/pull-secret.txt]"
	@echo ""
	@echo "Targets:"
	@echo "  create    - Create the CloudFormation stack with Debug flag enabled"
	@echo "  delete    - Delete the CloudFormation stack"
	@echo "  status    - Show stack status and outputs"
	@echo "  instances - Show summary of instances with internal and external IPs"

create: ## Create the CloudFormation stack
	@test -n "$(PASSWORD)" || (echo "Error: PASSWORD is required" && exit 1)
	@test -n "$(ACCESS_KEY)" || (echo "Error: AWS credentials not configured. Run 'aws configure'" && exit 1)
	@test -n "$(SECRET_KEY)" || (echo "Error: AWS credentials not configured. Run 'aws configure'" && exit 1)
	@test -f "$(PULL_SECRET_FILE)" || (echo "Error: Pull secret file $(PULL_SECRET_FILE) not found" && exit 1)
	@test -n "$(PULL_SECRET)" || (echo "Error: Pull secret file $(PULL_SECRET_FILE) is empty" && exit 1)
	@echo "Creating CloudFormation stack: $(STACK_NAME)"
	aws cloudformation create-stack \
		--stack-name $(STACK_NAME) \
		--template-body file://$(TEMPLATE_FILE) \
		--parameters \
			ParameterKey=Debug,ParameterValue=true \
			ParameterKey=VpcCidr,ParameterValue=$(VPC_CIDR) \
			ParameterKey=Password,ParameterValue=$(PASSWORD) \
			ParameterKey=S3TransferBucketName,ParameterValue=$(S3_TRANSFER_BUCKET_NAME) \
			ParameterKey=NatInstanceType,ParameterValue=$(NAT_INSTANCE_TYPE) \
			ParameterKey=JumpInstanceType,ParameterValue=$(JUMP_INSTANCE_TYPE) \
			ParameterKey=HighSideInstanceType,ParameterValue=$(HIGHSIDE_INSTANCE_TYPE) \
			ParameterKey=JumpInstanceDataVolumeSize,ParameterValue=$(JUMP_INSTANCE_DATA_VOLUME_SIZE) \
			ParameterKey=HighSideInstanceDataVolumeSize,ParameterValue=$(HIGHSIDE_INSTANCE_DATA_VOLUME_SIZE) \
			ParameterKey=AccessKey,ParameterValue=$(ACCESS_KEY) \
			ParameterKey=SecretKey,ParameterValue=$(SECRET_KEY) \
			ParameterKey=PullSecret,ParameterValue=$(PULL_SECRET) \
		--capabilities CAPABILITY_NAMED_IAM \
		--region $(REGION)
	@echo "Stack creation initiated. Use 'make status' to check progress."

delete: ## Delete the CloudFormation stack
	@echo "Deleting CloudFormation stack: $(STACK_NAME)"
	aws cloudformation delete-stack \
		--stack-name $(STACK_NAME) \
		--region $(REGION)
	@echo "Stack deletion initiated."

status: ## Show stack status and outputs
	@echo "Stack Status:"
	@aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].[StackName,StackStatus]' \
		--output table 2>/dev/null || echo "Stack $(STACK_NAME) not found"
	@echo ""
	@echo "Stack Outputs:"
	@aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
		--output table 2>/dev/null || echo "No outputs available"
	@echo ""
	@echo "Stack Details:"; \
	echo "$(STACK_NAME) | Region: $(REGION)"; \
	echo ""; \
	aws cloudformation describe-stack-resources \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--output json 2>/dev/null | \
	jq -r '["RESOURCE", "TYPE", "STATUS"], (.StackResources | sort_by(.ResourceStatus) | .[] | [.LogicalResourceId, .ResourceType, .ResourceStatus]) | @tsv' | \
	column -t -s$$'\t' || \
	(echo "Stack $(STACK_NAME) not found or error occurred")

instances: ## Show summary of instances with internal and external IPs
	@echo "Instance Summary for Stack: $(STACK_NAME) in Region: $(REGION)"
	@echo "================================================================"
	@aws ec2 describe-instances \
		--region $(REGION) \
		--filters "Name=tag:aws:cloudformation:stack-name,Values=$(STACK_NAME)" "Name=instance-state-name,Values=running,stopped,pending,stopping" \
		--query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,State.Name,PrivateIpAddress,PublicIpAddress,InstanceType]' \
		--output json 2>/dev/null | \
	jq -r '["NAME", "INSTANCE_ID", "STATE", "PRIVATE_IP", "PUBLIC_IP", "TYPE"], (.[] | [.[0] // "N/A", .[1] // "N/A", .[2] // "N/A", .[3] // "N/A", .[4] // "N/A", .[5] // "N/A"]) | @tsv' | \
	column -t -s$$'\t' 2>/dev/null || \
	echo "Stack $(STACK_NAME) not found or no instances available"
