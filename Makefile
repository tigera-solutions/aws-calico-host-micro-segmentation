include config.mk

.DEFAULT_GOAL:=help

##@ Manage infra stacks.
.PHONY: test_infra
test_infra: ## Test infra stack.
	aws cloudformation validate-template --template-body file://cloudformation-infra.yaml

.PHONY: deploy_infra
deploy_infra: ## Deploy the infra stack. ex: make deploy_infra ENVNAME=calico-demo
	aws cloudformation deploy \
		--no-fail-on-empty-changeset \
		--capabilities CAPABILITY_NAMED_IAM \
		--template-file cloudformation-infra.yaml \
		--tags StackType="infra" \
		--stack-name $(ENVNAME) \
		--parameter-overrides \
			VpcCidrBlock=$(VPCCIDR) \
			CreatePrivateNetworks=$(PRIVATENETWORKING)

.PHONY: teardown_infra
teardown_infra: ## Teardown the infra stack. ex: make teardown_infra ENVNAME=calico-demo
	aws cloudformation delete-stack --stack-name $(ENVNAME)
	# Wait for the stack to be torn down.
	aws cloudformation wait stack-delete-complete --stack-name $(ENVNAME)

.PHONY: list_infra
list_infra: ## List the infra stacks.
	@aws cloudformation describe-stacks --query 'Stacks[].{Name: StackName, Tags: Tags[0]}[?Tags.Value==`infra`].Name' --output text

##@ Manage eks stacks.
.PHONY: test_eks
test_eks: ## Test eks stack.
	aws cloudformation validate-template --template-body file://cloudformation-eks.yaml

.PHONY: deploy_eks
deploy_eks: ## Deploy the eks stack. ex: make deploy_eks ENVNAME=calico-demo NAME=calico-demo-eks
	aws cloudformation deploy \
		--no-fail-on-empty-changeset \
		--capabilities CAPABILITY_NAMED_IAM \
		--template-file cloudformation-eks.yaml \
		--tags StackType="eks" \
		--stack-name $(NAME) \
		--parameter-overrides \
			EnvironmentName=$(ENVNAME) \
			KeyName=$(KEYNAME) \
			ImageId=$(EKSIMAGEID) \
			InstanceType=$(EKSINSTANCETYPE) \
			WorkerNodeCount=$(WORKERNODECOUNT) \
			KubernetesVersion=$(K8SVERSION)

.PHONY: teardown_eks
teardown_eks: ## Teardown the eks stack. ex: ex: make teardown_eks NAME=calico-demo-eks
	aws cloudformation delete-stack --stack-name $(NAME)
	# Wait for the stack to be torn down.
	aws cloudformation wait stack-delete-complete --stack-name $(NAME)

.PHONY: list_eks
list_eks: ## List the eks stacks.
	@aws cloudformation describe-stacks --query 'Stacks[].{Name: StackName, Tags: Tags[0]}[?Tags.Value==`eks`].Name' --output text

##@ Manage hms stacks.
.PHONY: test_hms
test_hms: ## Test hms stack.
	aws cloudformation validate-template --template-body file://cloudformation-hms.yaml

.PHONY: deploy_hms
deploy_hms: ## Deploy the hms stack. ex: make deploy_hms ENVNAME=calico-demo NAME=calico-demo-hms
	aws cloudformation deploy \
    --no-fail-on-empty-changeset \
    --capabilities CAPABILITY_NAMED_IAM \
    --template-file cloudformation-hms.yaml \
    --tags StackType="hms" \
    --stack-name $(NAME) \
    --parameter-overrides \
      EnvironmentName=$(ENVNAME) \
      KeyName=$(KEYNAME) \
      ImageId=$(HMSIMAGEID) \
      InstanceType=$(HMSINSTANCETYPE) \
      NodeCount=$(HMSNODECOUNT)

.PHONY: teardown_hms
teardown_hms: ## Teardown the hms stack. ex: ex: make teardown_hms NAME=calico-demo-hms
	aws cloudformation delete-stack --stack-name $(NAME)
	# Wait for the stack to be torn down.
	aws cloudformation wait stack-delete-complete --stack-name $(NAME)

.PHONY: list_hms
list_hms: ## List the hms stacks.
	@aws cloudformation describe-stacks --query 'Stacks[].{Name: StackName, Tags: Tags[0]}[?Tags.Value==`hms`].Name' --output text

##@ Help
.PHONY: help
help:  ## Type make followed by target you wish to run.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-z0-9A-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
