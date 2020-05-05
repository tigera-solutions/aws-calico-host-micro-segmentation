-include local-config.mk

ACCOUNT_ID ?= $(shell aws sts get-caller-identity --output text --query 'Account')
AWS_ACCESS_KEY_ID ?= $(shell aws configure get default.aws_access_key_id)
AWS_SECRET_ACCESS_KEY ?= $(shell aws configure get default.aws_secret_access_key)
