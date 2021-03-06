#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

# Determine OS type
if [[ $OSTYPE == 'darwin'* ]]; then
  OS="darwin"
else
  OS="linux"
fi

# Function to download files
function download {

  binary=$1
  version=$2
  url=$3
  file=$4
  sumfile=$5
  tmp_dir=$6

  echo
  echo "-- Downloading ${binary} ${version}..."
  curl --retry 3 -fLsS "${url}/${file}" --output "${tmp_dir}/${file}"

  if [ "${sumfile}" != "" ]; then
    curl --retry 3 -fLsS "${url}/${sumfile}" --output "${tmp_dir}/${sumfile}"
  else
    echo "No checksum file passed, skipping verification."
  fi

}

# Function to verify checksum of download file
function verify {

  file=$1
  sumfile=$2
  tmp_dir=$3

  echo "Verifying.."
  checksum=$(< "${tmp_dir}/${sumfile}" grep "${file}" | awk '{ print $1 }')
  echo "${checksum} ${tmp_dir}/${file}" | sha256sum -c

}

# Function to verify checksum of download file (when binary name not in sumfile)
function verify_alternative {

  file=$1
  sumfile=$2
  tmp_dir=$3

  echo "Verifying.."
  checksum=$(cat "${tmp_dir}/${sumfile}")
  echo "${checksum} ${tmp_dir}/${file}" | sha256sum -c

}

# Function to copy and replace binary in /usr/local/bin
function copy_replace_binary {

  binary=$1
  tmp_dir=$2
  dir=/usr/local/bin

  echo "Placing ${binary} binary in ${dir} and making executable.."
  arg=""
  if ! [ -w "${dir}" ]; then
    echo "No write permission to $dir. Attempting to run with sudo..."
    arg=sudo
  fi
  # Need to delete if exists already in case it is a symlink which cannot be overwritten using cp -r
  ${arg} rm -f "${dir}/${binary}"
  ${arg} cp -r "${tmp_dir}/${binary}" "${dir}"
  ${arg} chmod +x "${dir}/${binary}"

}

# Cleanup function
function clean {

  tmp_dir=$1

  echo "Deleting tmp dir: ${tmp_dir}"
  rm -rf "${tmp_dir}"
  echo "COMPLETE"

}

#######################################
# sha256sum
#######################################

if ! sha256sum --version &> /dev/null; then
  # If sha256sum not detected on mac, install coreutils
  if [ "$OS" == "darwin" ]; then
    echo
    echo "-- Installing coreutils..."
    brew install coreutils
  else
    echo "sha256sum must be installed to verify downloads. Please install and retry."
    exit 1
  fi
fi

#######################################
# python
#######################################

if python3 --version &> /dev/null; then
  PYTHON=python3
elif python --version &> /dev/null; then
  PYTHON=python3
else
  echo "python or python3 not detected. Please install python, ensure it is on your \$PATH, and retry."
  exit 1
fi

#######################################
# pip
#######################################

if ! ${PYTHON} -m pip &> /dev/null; then
  echo "Unable to detect pip after running: ${PYTHON} -m pip. Please ensure pip is installed and try again."
  exit 1
fi

#######################################
# pre-commit
#######################################

 # renovate: datasource=github-tags depName=pre-commit/pre-commit
PRE_COMMIT_VERSION=v2.20.0
PACKAGE=pre-commit
echo
echo "-- Installing ${PACKAGE} ${PRE_COMMIT_VERSION}..."
${PYTHON} -m pip install -q --upgrade ${PACKAGE}==${PRE_COMMIT_VERSION}
echo "COMPLETE"

#######################################
# detect-secrets
#######################################

 # renovate: datasource=github-tags depName=ibm/detect-secrets versioning="regex:^(?<compatibility>.*)-?(?<major>\\d+)\\.(?<minor>\\d+)\\+ibm\\.(?<patch>\\d+)\\.dss$"
DETECT_SECRETS_VERSION=0.13.1+ibm.50.dss
# '.dss' suffix required for renovate to query git tags, but needs to be removed to install with pip
DETECT_SECRETS_VERSION="$(echo ${DETECT_SECRETS_VERSION} | rev | cut -c5- | rev)"

PACKAGE=detect-secrets
echo
echo "-- Installing ${PACKAGE} ${DETECT_SECRETS_VERSION}..."
${PYTHON} -m pip install -q --upgrade "git+https://github.com/ibm/detect-secrets.git@${DETECT_SECRETS_VERSION}.dss#egg=detect-secrets"
echo "COMPLETE"

#######################################
# terraform
#######################################

 # renovate: datasource=github-releases depName=hashicorp/terraform
TERRAFORM_VERSION=v1.2.6
# 'v' prefix required for renovate to query github.com for new release, but needs to be removed to pull from hashicorp.com
TERRAFORM_VERSION="${TERRAFORM_VERSION:1}"
BINARY=terraform
FILE_NAME="terraform_${TERRAFORM_VERSION}_${OS}_amd64.zip"
URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}"
SUMFILE="terraform_${TERRAFORM_VERSION}_SHA256SUMS"
TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

download ${BINARY} ${TERRAFORM_VERSION} "${URL}" ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
verify ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
unzip "${TMP_DIR}/${FILE_NAME}" -d "${TMP_DIR}" > /dev/null
copy_replace_binary ${BINARY} "${TMP_DIR}"
clean "${TMP_DIR}"

#######################################
# terragrunt
#######################################

 # renovate: datasource=github-releases depName=gruntwork-io/terragrunt
TERRAGRUNT_VERSION=v0.38.6
BINARY=terragrunt
FILE_NAME="terragrunt_${OS}_amd64"
URL="https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}"
SUMFILE=SHA256SUMS
TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

download ${BINARY} ${TERRAGRUNT_VERSION} ${URL} ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
verify ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
# rename binary to terragrunt
mv "${TMP_DIR}/${FILE_NAME}" "${TMP_DIR}/${BINARY}"
copy_replace_binary ${BINARY} "${TMP_DIR}"
clean "${TMP_DIR}"

#######################################
# terraform-docs
#######################################

 # renovate: datasource=github-releases depName=terraform-docs/terraform-docs
TERRAFORM_DOCS_VERSION=v0.16.0
BINARY=terraform-docs
FILE_NAME="terraform-docs-${TERRAFORM_DOCS_VERSION}-${OS}-amd64.tar.gz"
URL="https://terraform-docs.io/dl/${TERRAFORM_DOCS_VERSION}"
SUMFILE="terraform-docs-${TERRAFORM_DOCS_VERSION}.sha256sum"
TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

download ${BINARY} ${TERRAFORM_DOCS_VERSION} ${URL} ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
verify ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
tar -xzf "${TMP_DIR}/${FILE_NAME}" -C "${TMP_DIR}"
copy_replace_binary ${BINARY} "${TMP_DIR}"
clean "${TMP_DIR}"

#######################################
# tflint
#######################################

 # renovate: datasource=github-releases depName=terraform-linters/tflint
TFLINT_VERSION=v0.39.0
BINARY=tflint
FILE_NAME="tflint_${OS}_amd64.zip"
URL="https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}"
SUMFILE="checksums.txt"
TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

download ${BINARY} ${TFLINT_VERSION} ${URL} ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
verify ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
unzip "${TMP_DIR}/${FILE_NAME}" -d "${TMP_DIR}" > /dev/null
copy_replace_binary ${BINARY} "${TMP_DIR}"
clean "${TMP_DIR}"

#######################################
# tfsec
#######################################

 # renovate: datasource=github-releases depName=aquasecurity/tfsec
TFSEC_VERSION=v1.26.3
BINARY=tfsec
FILE_NAME="tfsec-${OS}-amd64"
URL="https://github.com/aquasecurity/tfsec/releases/download/${TFSEC_VERSION}"
SUMFILE="tfsec_checksums.txt"
TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

download ${BINARY} ${TFSEC_VERSION} ${URL} ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
verify ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
# rename binary to tfsec
mv "${TMP_DIR}/${FILE_NAME}" "${TMP_DIR}/${BINARY}"
copy_replace_binary ${BINARY} "${TMP_DIR}"
clean "${TMP_DIR}"

#######################################
# golangci-lint
#######################################

 # renovate: datasource=github-releases depName=golangci/golangci-lint
GOLANGCI_LINT_VERSION=v1.47.2
BINARY=golangci-lint
FILE_NAME="golangci-lint-${GOLANGCI_LINT_VERSION//v/}-${OS}-amd64.tar.gz"
URL="https://github.com/golangci/golangci-lint/releases/download/${GOLANGCI_LINT_VERSION}"
SUMFILE="${BINARY}-${GOLANGCI_LINT_VERSION//v/}-checksums.txt"
TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

download ${BINARY} ${GOLANGCI_LINT_VERSION} ${URL} ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
verify ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
tar -xzf "${TMP_DIR}/${FILE_NAME}" -C "${TMP_DIR}"
copy_replace_binary ${BINARY} "${TMP_DIR}/golangci-lint-${GOLANGCI_LINT_VERSION//v/}-${OS}-amd64"
clean "${TMP_DIR}"

#######################################
# Shellcheck
#######################################

 # renovate: datasource=github-releases depName=koalaman/shellcheck
SHELLCHECK_VERSION=v0.8.0
BINARY=shellcheck
FILE_NAME="shellcheck-${SHELLCHECK_VERSION}.${OS}.x86_64.tar.xz"
URL="https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_VERSION}"
SUMFILE=""
TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

download ${BINARY} ${SHELLCHECK_VERSION} ${URL} ${FILE_NAME} "${SUMFILE}" "${TMP_DIR}"
tar -xf "${TMP_DIR}/${FILE_NAME}" -C "${TMP_DIR}"
copy_replace_binary ${BINARY} "${TMP_DIR}/${BINARY}-${SHELLCHECK_VERSION}"
clean "${TMP_DIR}"

#######################################
# hadolint
#######################################

 # renovate: datasource=github-releases depName=hadolint/hadolint
HADOLINT_VERSION=v2.10.0
BINARY=hadolint
FILE_NAME="hadolint-${OS}-x86_64"
URL="https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}"
SUMFILE=""
TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

download ${BINARY} ${HADOLINT_VERSION} ${URL} ${FILE_NAME} "${SUMFILE}" "${TMP_DIR}"
## rename binary to hadolint
mv "${TMP_DIR}/${FILE_NAME}" "${TMP_DIR}/${BINARY}"
copy_replace_binary ${BINARY} "${TMP_DIR}"
clean "${TMP_DIR}"

#######################################
# helm
#######################################

 # renovate: datasource=github-releases depName=helm/helm
HELM_VERSION=v3.9.2
BINARY=helm
FILE_NAME="helm-${HELM_VERSION}-${OS}-amd64.tar.gz"
URL="https://get.helm.sh"
SUMFILE="helm-${HELM_VERSION}-${OS}-amd64.tar.gz.sha256"
TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

download ${BINARY} ${HELM_VERSION} ${URL} ${FILE_NAME} "${SUMFILE}" "${TMP_DIR}"
verify_alternative ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
tar -xzf "${TMP_DIR}/${FILE_NAME}" -C "${TMP_DIR}"
copy_replace_binary ${BINARY} "${TMP_DIR}/${OS}-amd64"
clean "${TMP_DIR}"

#######################################
# kubectl
#######################################

 # renovate: datasource=github-releases depName=kubernetes/kubernetes
KUBECTL_VERSION=v1.24.3
BINARY=kubectl
FILE_NAME="kubectl"
URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/amd64"
SUMFILE="kubectl.sha256"
TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

download ${BINARY} ${KUBECTL_VERSION} ${URL} ${FILE_NAME} "${SUMFILE}" "${TMP_DIR}"
verify_alternative ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
copy_replace_binary ${BINARY} "${TMP_DIR}"
clean "${TMP_DIR}"

#######################################
# oc
#######################################

OC_OS=${OS}
if [[ $OSTYPE == 'darwin'* ]]; then
  OC_OS="mac"
fi

# OC cli version must be maintained manually, as there is no supported renovate datasource to find newer versions.
OC_VERSION=4.9.18
BINARY=oc
FILE_NAME="openshift-client-${OC_OS}-${OC_VERSION}.tar.gz"
URL="https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OC_VERSION}"
SUMFILE="sha256sum.txt"
TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

download ${BINARY} ${OC_VERSION} ${URL} ${FILE_NAME} "${SUMFILE}" "${TMP_DIR}"
verify ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
tar -xzf "${TMP_DIR}/${FILE_NAME}" -C "${TMP_DIR}"
copy_replace_binary ${BINARY} "${TMP_DIR}"
clean "${TMP_DIR}"
