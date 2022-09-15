# -*- mode:makefile; coding:utf-8 -*-

CONFIG_ENV:= common-dev-assets/module-assets/config.env
COMMON_DEV_ASSETS_CONFIG_ENV:= module-assets/config.env
ifneq ("$(wildcard $(CONFIG_ENV))","")
	include $(CONFIG_ENV)
else
ifneq ("$(wildcard $(COMMON_DEV_ASSETS_CONFIG_ENV))","")
	include $(COMMON_DEV_ASSETS_CONFIG_ENV)
endif
endif
export

# explicitly tell Make these commands not associated with files
.PHONY: all dependency-install-darwin-linux dependency-pre-commit docker-pull docker-run pre-commit pre-commit-no-terraform go-mod-tidy run-tests run-tests-local run-go-module-tests renovate-sweeper sem-release netrc ghe-netrc

#
# simply expanded variables
#

IMAGE := ${IMAGE_NAME}:stable

ifeq ($(OS),Windows_NT)     # is Windows_NT on XP, 2000, 7, Vista, 10...
    detected_OS := Windows
else
    detected_OS := $(shell uname)  # same as "uname -s"
endif

.DEFAULT_GOAL = dependency-pre-commit
ifneq (,$(filter $(detected_OS), Darwin Linux))
	.DEFAULT_GOAL = all
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

ifndef CONTAINER_RUNTIME
	CONTAINER_RUNTIME := 'docker'
endif

ifneq (,$(findstring github.ibm.com,$(shell git config --get remote.origin.url)))
	GHE := 'true'
endif

#
# install dependencies
#

all: dependency-install-darwin-linux dependency-pre-commit

dependency-install-darwin-linux:
	./ci/install-deps.sh
	brew bundle install

dependency-pre-commit:
	pre-commit install
	pre-commit install --hook-type commit-msg

#
# docker
#

docker-pull:
	${CONTAINER_RUNTIME} pull "${DOCKER_REGISTRY}/$(IMAGE)"

docker-run:
	${CONTAINER_RUNTIME} run -it -v $$(pwd):/mnt \
		-v ~/.ssh:/root/.ssh \
		-v ~/.netrc:/root/.netrc \
		-v ~/.gitconfig:/root/.gitconfig \
		${DOCKER_REGISTRY}/$(IMAGE) bash

#
# pre-commit
#

# pre-commit for repos with terraform code
# (in container approach, not directly mounting ~/.ssh because we will be changing the permissions, so creating backup and mounting that instead)
pre-commit:
ifdef GHE
ifndef GH_TOKEN
	$(error Error: GH_TOKEN is undefined)
endif
endif
	@run_cmd="make ghe-netrc && \
			terraform init && \
			terragrunt run-all init || echo 'Ignoring failure incase this is a non terragrunt project' && \
			pre-commit run --all-files" && \
	if [ "$${NO_CONTAINER}" = "true" ]; \
	then \
		bash -c "$${run_cmd}"; \
	else \
		cp -r ~/.ssh /tmp && \
		${CONTAINER_RUNTIME} run -it -v $$(pwd):/mnt \
			-v /tmp/.ssh:/root/.ssh \
			-e GH_TOKEN \
			${DOCKER_REGISTRY}/$(IMAGE) \
			bash -c "chown -R root /root/.ssh && \
				chgrp -R root /root/.ssh && \
				$${run_cmd}"; \
		exitCode=$$?; \
		sudo rm -rf /tmp/.ssh; \
		exit $${exitCode}; \
	fi

# pre-commit for non-terraform repos
# (in container approach, not directly mounting ~/.ssh because we will be changing the permissions, so creating backup and mounting that instead)
pre-commit-no-terraform:
	@run_cmd="pre-commit run --all-files" && \
	if [ "$${NO_CONTAINER}" = "true" ]; \
	then \
		bash -c "$${run_cmd}"; \
	else \
		cp -r ~/.ssh /tmp && \
		${CONTAINER_RUNTIME} run -it -v $$(pwd):/mnt \
			-v /tmp/.ssh:/root/.ssh \
			${DOCKER_REGISTRY}/$(IMAGE) \
			bash -c "chown -R root /root/.ssh && \
				$${run_cmd}"; \
		exitCode=$$?; \
		sudo rm -rf /tmp/.ssh; \
		exit $${exitCode}; \
	fi

# run pre-commit checks against renovate PRs, and commit back any changes to the PR (e.g. doc updates, secrets baseline etc)
# (in container approach, not directly mounting ~/.ssh because we will be changing the permissions, so creating backup and mounting that instead)
renovate-sweeper:
    ifndef GH_TOKEN
	   $(error Error: GH_TOKEN is undefined)
    endif
	@run_cmd="make ghe-netrc && \
		ci/renovate-sweeper.sh" && \
	if [ "$${NO_CONTAINER}" = "true" ]; \
	then \
		bash -c "$${run_cmd}"; \
	else \
		cp -r ~/.ssh /tmp && \
		${CONTAINER_RUNTIME} run -it -v $$(pwd):/mnt \
			-v /tmp/.ssh:/root/.ssh \
			-e TRAVIS \
			-e TRAVIS_PULL_REQUEST \
			-e TRAVIS_PULL_REQUEST_BRANCH \
			-e GH_TOKEN \
			${DOCKER_REGISTRY}/$(IMAGE) \
			bash -c "chown -R root /root/.ssh && \
				chgrp -R root /root/.ssh && \
				$${run_cmd}"; \
		exitCode=$$?; \
		sudo rm -rf /tmp/.ssh; \
		exit $${exitCode}; \
	fi

#
# tests
#

# run tests for terraform repos (pipeline execution only - not for local usage)
# (in container approach, not directly mounting ~/.ssh because we will be changing the permissions, so creating backup and mounting that instead)
run-tests: SHELL:=/bin/bash
run-tests:
	@if [ -z "$${TF_VAR_ibmcloud_api_key}" ]; then echo "Error: TF_VAR_ibmcloud_api_key is undefined"; exit 1; fi

ifdef GHE
ifndef GH_TOKEN
	$(error Error: GH_TOKEN is undefined)
endif
endif

	@run_cmd="make ghe-netrc && \
		ci/run-tests.sh" && \
	if [ "$${NO_CONTAINER}" == "true" ]; \
	then \
		bash -c "$${run_cmd}"; \
	else \
		cp -r ~/.ssh /tmp && \
		${CONTAINER_RUNTIME} run -it -v $$(pwd):/mnt \
			-v /tmp/.ssh:/root/.ssh \
			-e IC_API_KEY="$${TF_VAR_ibmcloud_api_key}" \
			-e GOPROXY \
			-e GONOSUMDB \
			-e FORCE_TEST_REGION \
			-e GH_TOKEN \
			--env-file <(env| grep 'TRAVIS\|GH_TOKEN\|TF_VAR_' | cut -f1 -d=) \
			--env-file ${DOCKER_ENV} \
			${DOCKER_REGISTRY}/$(IMAGE) \
			bash -c "chown -R root /root/.ssh && \
				chgrp -R root /root/.ssh && \
				$${run_cmd}"; \
		exitCode=$$?; \
		sudo rm -rf /tmp/.ssh; \
		exit $${exitCode}; \
	fi

# run tests for terraform repos locally
# (optionally set RUN env var to a regular expression that matches the test(s) name that you only want to run. e.g. `make run-tests-local RUN=TestRunApplyTest`)
run-tests-local:
	@if [ -z "$${TF_VAR_ibmcloud_api_key}" ]; then echo "Error: TF_VAR_ibmcloud_api_key is undefined"; exit 1; fi
	cd ${GO_TEST_DIR} && go test -run ${RUN} -count=1 -v -timeout 300m

# run unit tests for golang projects
run-go-module-tests:
	@run_cmd="go test \$$(go list ./... | grep -v /common-dev-assets/) -count=1 -v -timeout 5m" && \
	if [ "$${NO_CONTAINER}" = "true" ]; \
	then \
		bash -c "$${run_cmd}"; \
	else \
	${CONTAINER_RUNTIME} run -it -v $$(pwd):/mnt \
		-e GOPROXY \
		-e GONOSUMDB \
		${DOCKER_REGISTRY}/$(IMAGE) \
		bash -c "$${run_cmd}"; \
	fi

# go mod tidy
go-mod-tidy:
	@cd ${GO_MOD_DIR}; go mod tidy -v ${GO_MOD_ARGS}

#
# release
#

sem-release:
ifdef GHE
ifndef GH_TOKEN
	$(error Error: GH_TOKEN is undefined)
endif
endif
	@run_cmd="mv -t /mnt /tmp/node_modules /tmp/package-lock.json && \
		npx semantic-release --no-ci" && \
	if [ "$${NO_CONTAINER}" = "true" ]; \
	then \
		bash -c "$${run_cmd}"; \
	else \
	${CONTAINER_RUNTIME} run -it -v $$(pwd):/mnt \
		-v ~/.ssh:/root/.ssh \
		-e GH_TOKEN \
		-e CATALOG_TEKTON_WEBHOOK_URL \
		-e CATALOG_TEKTON_WEBHOOK_TOKEN \
		${DOCKER_REGISTRY}/$(IMAGE) \
		bash -c "$${run_cmd}"; \
	fi

#
# netrc
#

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
ifdef GHE
ifndef GH_TOKEN
	$(error Error: GH_TOKEN is undefined)
endif
	@touch ~/.netrc
	@if ! grep -q "machine github.ibm.com" ~/.netrc; then \
		echo -e "machine github.ibm.com\n  login $$GH_TOKEN" >> ~/.netrc; \
	else \
		echo "Found entry already exists in ~/.netrc for github.ibm.com. Taking no action."; \
	fi
else
	@echo "Not in GHE skipping ghe-netrc modification"
endif
