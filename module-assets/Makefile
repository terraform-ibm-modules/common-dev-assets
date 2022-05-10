# -*- mode:makefile; coding:utf-8 -*-
include common-dev-assets/module-assets/config.env
export

.PHONY: dependency-install-darwin-linux dependency-pre-commit

ifeq ($(OS),Windows_NT)     # is Windows_NT on XP, 2000, 7, Vista, 10...
    detected_OS := Windows
else
    detected_OS := $(shell uname)  # same as "uname -s"
endif

ifndef DOCKER_ENV
	DOCKER_ENV := common-dev-assets/module-assets/docker.env
endif

ifndef GO_TEST_DIR
	GO_TEST_DIR := tests
endif

ifndef GO_MOD_DIR
	GO_MOD_DIR := tests
endif

ifndef RUN
	RUN := ''
endif

VERSION := $(shell git describe --tags 2> /dev/null || echo unknown)
.DEFAULT_GOAL = dependency-pre-commit
IMAGE := ${IMAGE_NAME}:stable

ifneq (,$(filter $(detected_OS), Darwin Linux))
	.DEFAULT_GOAL = all
endif

all: dependency-install-darwin-linux dependency-pre-commit

dependency-install-darwin-linux:
	./ci/install-deps.sh
	brew bundle install

dependency-pre-commit:
	pre-commit install
	pre-commit install --hook-type commit-msg

#
# Docker
#

docker-pull:
	docker pull "${DOCKER_REGISTRY}/$(IMAGE)"

docker-run:
	docker run -it -v $$(pwd):/mnt -v ~/.ssh:/root/.ssh ${DOCKER_REGISTRY}/$(IMAGE) bash

# pre-commit for repos with terraform code
pre-commit:
	@if [ -z "$${TF_VAR_ibmcloud_api_key}" ]; then echo "Error: TF_VAR_ibmcloud_api_key is undefined"; exit 1; fi
	@if [ -z "$${GH_TOKEN}" ]; then echo "Error: GH_TOKEN is undefined"; exit 1; fi
	# Not directly mounting ~/.ssh because we will be changing the permissions, so creating backup and mounting that.
	cp -r ~/.ssh /tmp
	docker run -it -v $$(pwd):/mnt \
		-v /tmp/.ssh:/root/.ssh \
		-e TF_VAR_ibmcloud_api_key \
		-e GH_TOKEN \
		${DOCKER_REGISTRY}/$(IMAGE) \
		bash -c "chown -R root /root/.ssh && \
			chgrp -R root /root/.ssh && \
			make ghe-netrc && \
			terraform init && \
			terragrunt run-all init || echo 'Ignoring failure incase this is a non terragrunt project' && \
			pre-commit run --all-files"
	# Cleanup after (must use sudo as dir now owned by root)
	sudo rm -rf /tmp/.ssh

# pre-commit for non-terraform repos
pre-commit-no-terraform:
	# Not directly mounting ~/.ssh because we will be changing the permissions, so creating backup and mounting that.
	cp -r ~/.ssh /tmp
	docker run -it -v $$(pwd):/mnt \
		-v /tmp/.ssh:/root/.ssh \
		${DOCKER_REGISTRY}/$(IMAGE) \
		bash -c "chown -R root /root/.ssh && \
			pre-commit run --all-files"
	# Cleanup after (must use sudo as dir now owned by root)
	sudo rm -rf /tmp/.ssh

# go mod tidy
go-mod-tidy:
	@cd ${GO_MOD_DIR}; go mod tidy -v ${GO_MOD_ARGS}

# run tests for terraform repos
run-tests: SHELL:=/bin/bash
run-tests:
	@if [ -z "$${TF_VAR_ibmcloud_api_key}" ]; then echo "Error: TF_VAR_ibmcloud_api_key is undefined"; exit 1; fi
	@if [ -z "$${GH_TOKEN}" ]; then echo "Error: GH_TOKEN is undefined"; exit 1; fi
	# Not directly mounting ~/.ssh because we will be changing the permissions, so creating backup and mounting that.
	cp -r ~/.ssh /tmp
	docker run -it -v $$(pwd):/mnt \
		-v /tmp/.ssh:/root/.ssh \
		-e IC_API_KEY="$${TF_VAR_ibmcloud_api_key}" \
		-e GOPROXY \
		-e GONOSUMDB \
		-e FORCE_TEST_REGION \
		-e GH_TOKEN \
		--env-file <(env| grep 'TRAVIS_\|GH_TOKEN\|TF_VAR_' | cut -f1 -d=) \
		--env-file ${DOCKER_ENV} \
		${DOCKER_REGISTRY}/$(IMAGE) \
		bash -c "chown -R root /root/.ssh && \
			chgrp -R root /root/.ssh && \
			make ghe-netrc && \
			ci/run-tests.sh"

# run tests for terraform repos locally (optionally set RUN env var to a regular expression that matches the test(s) name that you only want to run. e.g. `make run-tests-local RUN=TestRunApplyTest`)
run-tests-local:
	@if [ -z "$${TF_VAR_ibmcloud_api_key}" ]; then echo "Error: TF_VAR_ibmcloud_api_key is undefined"; exit 1; fi
	cd ${GO_TEST_DIR} && go test -run ${RUN} -count=1 -v -timeout 300m

# run unit tests for golang
run-go-module-tests:
	@if [ -z "$${GH_TOKEN}" ]; then echo "Error: GH_TOKEN is undefined"; exit 1; fi
	docker run -it -v $$(pwd):/mnt \
		-e GOPROXY \
		-e GONOSUMDB \
		-e GH_TOKEN \
		${DOCKER_REGISTRY}/$(IMAGE) \
		bash -c "go test ./... -count=1 -v -timeout 5m"

doc-sweeper:
# Only used in Travis if needed in GH Actions just run ci/doc-sweeper.sh directly
	@if [ -z "$${TF_VAR_ibmcloud_api_key}" ]; then echo "Error: TF_VAR_ibmcloud_api_key is undefined"; exit 1; fi
	@if [ -z "$${GH_TOKEN}" ]; then echo "Error: GH_TOKEN is undefined"; exit 1; fi
	# Not directly mounting ~/.ssh because we will be changing the permissions, so creating backup and mounting that.
	cp -r ~/.ssh /tmp
	docker run -it -v $$(pwd):/mnt \
		-v /tmp/.ssh:/root/.ssh \
		-e TRAVIS_PULL_REQUEST \
		-e TRAVIS_PULL_REQUEST_BRANCH \
		-e TF_VAR_ibmcloud_api_key \
		-e GH_TOKEN \
		${DOCKER_REGISTRY}/$(IMAGE) \
		bash -c "chown -R root /root/.ssh && \
			chgrp -R root /root/.ssh && \
			make ghe-netrc && \
			ci/doc-sweeper.sh"
	# Cleanup after (must use sudo as dir now owned by root)
	sudo rm -rf /tmp/.ssh

sem-release:
	@if [ -z "$${GH_TOKEN}" ]; then echo "Error: GH_TOKEN is undefined"; exit 1; fi
	docker run -it -v $$(pwd):/mnt \
		-v ~/.ssh:/root/.ssh \
		-e GH_TOKEN \
		-e CATALOG_TEKTON_WEBHOOK_URL \
		-e CATALOG_TEKTON_WEBHOOK_TOKEN \
		${DOCKER_REGISTRY}/$(IMAGE) \
		bash -c "mv -t /mnt /tmp/node_modules /tmp/package-lock.json && \
			npx semantic-release --no-ci"

# Create entry in ~/.netrc for cm.globalcatalog.cloud.ibm.com using IAM bearer token
netrc:
	@if [ -z "$${TF_VAR_ibmcloud_api_key}" ]; then echo "Error: TF_VAR_ibmcloud_api_key is undefined"; exit 1; fi
	ibmcloud login --no-region --apikey "$$TF_VAR_ibmcloud_api_key"
	while true ; do \
	    ibmcloud catalog netrc ; \
	    echo "refreshed netrc" ; \
	    sleep 10m ; \
	done & \
	sleep 5

# Create entry in ~/.netrc for github.ibm.com using $GH_TOKEN
ghe-netrc:
	@if [ -z "$${GH_TOKEN}" ]; then echo "Error: GH_TOKEN is undefined"; exit 1; fi
	@touch ~/.netrc
	@if ! grep -q "machine github.ibm.com" ~/.netrc; then \
		echo -e "machine github.ibm.com\n  login $$GH_TOKEN" >> ~/.netrc; \
	else \
		echo "Found entry already exists in ~/.netrc for github.ibm.com. Taking no action."; \
	fi
