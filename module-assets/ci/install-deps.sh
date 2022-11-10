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
set +e
INSTALLED_PRE_COMMIT_VERSION="$(${PYTHON} -m pip show pre-commit | grep Version: | cut -d' ' -f2)"
set -e
if [[ "$PRE_COMMIT_VERSION" != "v$INSTALLED_PRE_COMMIT_VERSION" ]]; then
  PACKAGE=pre-commit

  echo
  echo "-- Installing ${PACKAGE} ${PRE_COMMIT_VERSION}..."

  ${PYTHON} -m pip install -q --upgrade ${PACKAGE}==${PRE_COMMIT_VERSION}
  echo "COMPLETE"
else
 echo "Pre-commit ${PRE_COMMIT_VERSION} already installed skipping install"
fi

#######################################
# detect-secrets
#######################################

 # renovate: datasource=github-tags depName=ibm/detect-secrets versioning="regex:^(?<compatibility>.*)-?(?<major>\\d+)\\.(?<minor>\\d+)\\+ibm\\.(?<patch>\\d+)\\.dss$"
DETECT_SECRETS_VERSION=0.13.1+ibm.55.dss
set +e
INSTALLED_DECTECT_SECRETS="$(${PYTHON} -m pip show detect-secrets | grep Version: | cut -d' ' -f2)"
set -e
if [[ "$DETECT_SECRETS_VERSION" != "$INSTALLED_DECTECT_SECRETS" ]]; then
  PACKAGE=detect-secrets

  echo
  echo "-- Installing ${PACKAGE} ${DETECT_SECRETS_VERSION}..."

  ${PYTHON} -m pip install -q --upgrade "git+https://github.com/ibm/detect-secrets.git@${DETECT_SECRETS_VERSION}#egg=detect-secrets"
  echo "COMPLETE"
else
 echo "Detect secrets ${DETECT_SECRETS_VERSION} already installed skipping install"
fi

#######################################
# terraform
#######################################

# Locking into v1.2.9 until https://github.ibm.com/GoldenEye/issues/issues/2858 is complete
TERRAFORM_VERSION=v1.2.9
set +e
INSTALLED_TERRAFORM_VERSION="$(terraform --version | head -1 | cut -d' ' -f2)"
set -e
if [[ "$TERRAFORM_VERSION" != "$INSTALLED_TERRAFORM_VERSION" ]]; then
  # 'v' prefix required for renovate to query github.com for new release, but needs to be removed to pull from hashicorp.com
  TERRAFORM_VERSION="${TERRAFORM_VERSION:1}"
  BINARY=terraform
  FILE_NAME="terraform_${TERRAFORM_VERSION}_${OS}_amd64.zip"
  URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}"
  SUMFILE="terraform_${TERRAFORM_VERSION}_SHA256SUMS"
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${TERRAFORM_VERSION}..."

  download ${BINARY} ${TERRAFORM_VERSION} "${URL}" ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  verify ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  unzip "${TMP_DIR}/${FILE_NAME}" -d "${TMP_DIR}" > /dev/null
  copy_replace_binary ${BINARY} "${TMP_DIR}"
  clean "${TMP_DIR}"
else
  echo "Terraform ${TERRAFORM_VERSION} already installed skipping install"
fi

#######################################
# terragrunt
#######################################

 # renovate: datasource=github-releases depName=gruntwork-io/terragrunt
TERRAGRUNT_VERSION=v0.40.1
set +e
INSTALLED_TERRAGRUNT_VERSION="$(terragrunt --version | head -1 | cut -d' ' -f3)"
set -e
if [[ "$TERRAGRUNT_VERSION" != "$INSTALLED_TERRAGRUNT_VERSION" ]]; then
  BINARY=terragrunt
  FILE_NAME="terragrunt_${OS}_amd64"
  URL="https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}"
  SUMFILE=SHA256SUMS
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${TERRAGRUNT_VERSION}..."

  download ${BINARY} ${TERRAGRUNT_VERSION} ${URL} ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  verify ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  # rename binary to terragrunt
  mv "${TMP_DIR}/${FILE_NAME}" "${TMP_DIR}/${BINARY}"
  copy_replace_binary ${BINARY} "${TMP_DIR}"
  clean "${TMP_DIR}"
else
  echo "Terragrunt ${TERRAGRUNT_VERSION} already installed skipping install"
fi
#######################################
# terraform-docs
#######################################

 # renovate: datasource=github-releases depName=terraform-docs/terraform-docs
TERRAFORM_DOCS_VERSION=v0.16.0
set +e
INSTALLED_TERRADOCS_VERSION="$(terraform-docs --version | head -1 | cut -d' ' -f3)"
set -e
if [[ "$TERRAFORM_DOCS_VERSION" != "$INSTALLED_TERRADOCS_VERSION" ]]; then
  BINARY=terraform-docs
  FILE_NAME="terraform-docs-${TERRAFORM_DOCS_VERSION}-${OS}-amd64.tar.gz"
  URL="https://terraform-docs.io/dl/${TERRAFORM_DOCS_VERSION}"
  SUMFILE="terraform-docs-${TERRAFORM_DOCS_VERSION}.sha256sum"
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${TERRAFORM_DOCS_VERSION}..."

  download ${BINARY} ${TERRAFORM_DOCS_VERSION} ${URL} ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  verify ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  tar -xzf "${TMP_DIR}/${FILE_NAME}" -C "${TMP_DIR}"
  copy_replace_binary ${BINARY} "${TMP_DIR}"
  clean "${TMP_DIR}"
else
  echo "Terradocs ${TERRAFORM_DOCS_VERSION} already installed skipping install"
fi

#######################################
# tflint
#######################################
 # renovate: datasource=github-releases depName=terraform-linters/tflint
TFLINT_VERSION=v0.42.2
set +e
INSTALLED_TFLINT_VERSION="$(tflint --version | grep "TFLint version " |cut -d' ' -f3)"
set -e
if [[ "$TFLINT_VERSION" != "v$INSTALLED_TFLINT_VERSION" ]]; then
  BINARY=tflint
  FILE_NAME="tflint_${OS}_amd64.zip"
  URL="https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}"
  SUMFILE="checksums.txt"
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${TFLINT_VERSION}..."

  download ${BINARY} ${TFLINT_VERSION} ${URL} ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  verify ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  unzip "${TMP_DIR}/${FILE_NAME}" -d "${TMP_DIR}" > /dev/null
  copy_replace_binary ${BINARY} "${TMP_DIR}"
  clean "${TMP_DIR}"
else
  echo "Tflint ${TFLINT_VERSION} already installed skipping install"
fi

#######################################
# tfsec
#######################################

 # renovate: datasource=github-releases depName=aquasecurity/tfsec
TFSEC_VERSION=v1.28.1
set +e
INSTALLED_TFSEC_VERSION="$(tfsec --version)"
set -e
if [[ "$TFSEC_VERSION" != "$INSTALLED_TFSEC_VERSION" ]]; then
  BINARY=tfsec
  FILE_NAME="tfsec-${OS}-amd64"
  URL="https://github.com/aquasecurity/tfsec/releases/download/${TFSEC_VERSION}"
  SUMFILE="tfsec_checksums.txt"
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${TFSEC_VERSION}..."

  download ${BINARY} ${TFSEC_VERSION} ${URL} ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  verify ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  # rename binary to tfsec
  mv "${TMP_DIR}/${FILE_NAME}" "${TMP_DIR}/${BINARY}"
  copy_replace_binary ${BINARY} "${TMP_DIR}"
  clean "${TMP_DIR}"
else
  echo "Tfsec ${TFSEC_VERSION} already installed skipping install"
fi

#######################################
# golangci-lint
#######################################

 # renovate: datasource=github-releases depName=golangci/golangci-lint
GOLANGCI_LINT_VERSION=v1.50.1
set +e
INSTALLED_GOLANGCI_LINT_VERSION="$(golangci-lint --version | head -1 | cut -d' ' -f4)"
set -e
if [[ "$GOLANGCI_LINT_VERSION" != "v$INSTALLED_GOLANGCI_LINT_VERSION" ]]; then
  BINARY=golangci-lint
  FILE_NAME="golangci-lint-${GOLANGCI_LINT_VERSION//v/}-${OS}-amd64.tar.gz"
  URL="https://github.com/golangci/golangci-lint/releases/download/${GOLANGCI_LINT_VERSION}"
  SUMFILE="${BINARY}-${GOLANGCI_LINT_VERSION//v/}-checksums.txt"
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${GOLANGCI_LINT_VERSION}..."

  download ${BINARY} ${GOLANGCI_LINT_VERSION} ${URL} ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  verify ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  tar -xzf "${TMP_DIR}/${FILE_NAME}" -C "${TMP_DIR}"
  copy_replace_binary ${BINARY} "${TMP_DIR}/golangci-lint-${GOLANGCI_LINT_VERSION//v/}-${OS}-amd64"
  clean "${TMP_DIR}"
else
  echo "golangci-lint ${GOLANGCI_LINT_VERSION} already installed skipping install"
fi

#######################################
# Shellcheck
#######################################

 # renovate: datasource=github-releases depName=koalaman/shellcheck
SHELLCHECK_VERSION=v0.8.0
set +e
INSTALLED_SHELLCHECK_VERSION="$(shellcheck --version | grep "version:" | cut -d' ' -f2)"
set -e
if [[ "$SHELLCHECK_VERSION" != "v$INSTALLED_SHELLCHECK_VERSION" ]]; then
  BINARY=shellcheck
  FILE_NAME="shellcheck-${SHELLCHECK_VERSION}.${OS}.x86_64.tar.xz"
  URL="https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_VERSION}"
  SUMFILE=""
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${SHELLCHECK_VERSION}..."

  download ${BINARY} ${SHELLCHECK_VERSION} ${URL} ${FILE_NAME} "${SUMFILE}" "${TMP_DIR}"
  tar -xf "${TMP_DIR}/${FILE_NAME}" -C "${TMP_DIR}"
  copy_replace_binary ${BINARY} "${TMP_DIR}/${BINARY}-${SHELLCHECK_VERSION}"
  clean "${TMP_DIR}"
else
  echo "Shellcheck ${SHELLCHECK_VERSION} already installed skipping install"
fi

#######################################
# hadolint
#######################################

 # renovate: datasource=github-releases depName=hadolint/hadolint
HADOLINT_VERSION=v2.12.0
set +e
INSTALLED_HADOLINT_VERSION="$(hadolint --version | head -1 | cut -d' ' -f4)"
set -e
if [[ "$HADOLINT_VERSION" != "v$INSTALLED_HADOLINT_VERSION" ]]; then
  BINARY=hadolint
  FILE_NAME="hadolint-${OS}-x86_64"
  URL="https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}"
  SUMFILE=""
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${HADOLINT_VERSION}..."

  download ${BINARY} ${HADOLINT_VERSION} ${URL} ${FILE_NAME} "${SUMFILE}" "${TMP_DIR}"
  ## rename binary to hadolint
  mv "${TMP_DIR}/${FILE_NAME}" "${TMP_DIR}/${BINARY}"
  copy_replace_binary ${BINARY} "${TMP_DIR}"
  clean "${TMP_DIR}"
else
  echo "Hadolint ${HADOLINT_VERSION} already installed skipping install"
fi

#######################################
# helm
#######################################

 # renovate: datasource=github-releases depName=helm/helm
HELM_VERSION=v3.10.1
set +e
INSTALLED_HELM_VERSION="$(helm version | cut -d':' -f2 | cut -d'"' -f2)"
set -e
if [[ "$HELM_VERSION" != "$INSTALLED_HELM_VERSION" ]]; then
  BINARY=helm
  FILE_NAME="helm-${HELM_VERSION}-${OS}-amd64.tar.gz"
  URL="https://get.helm.sh"
  SUMFILE="helm-${HELM_VERSION}-${OS}-amd64.tar.gz.sha256"
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${HELM_VERSION}..."

  download ${BINARY} ${HELM_VERSION} ${URL} ${FILE_NAME} "${SUMFILE}" "${TMP_DIR}"
  verify_alternative ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  tar -xzf "${TMP_DIR}/${FILE_NAME}" -C "${TMP_DIR}"
  copy_replace_binary ${BINARY} "${TMP_DIR}/${OS}-amd64"
  clean "${TMP_DIR}"
else
  echo "Helm ${HELM_VERSION} already installed skipping install"
fi
#######################################
# kubectl
#######################################

 # renovate: datasource=github-releases depName=kubernetes/kubernetes
KUBECTL_VERSION=v1.25.3
set +e
INSTALLED_KUBECTL_VERSION="$(kubectl version --output yaml --client | grep "gitVersion" | cut -d' ' -f4)"
set -e
if [[ "$KUBECTL_VERSION" != "$INSTALLED_KUBECTL_VERSION" ]]; then
  BINARY=kubectl
  FILE_NAME="kubectl"
  URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/amd64"
  SUMFILE="kubectl.sha256"
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${KUBECTL_VERSION}..."

  download ${BINARY} ${KUBECTL_VERSION} ${URL} ${FILE_NAME} "${SUMFILE}" "${TMP_DIR}"
  verify_alternative ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  copy_replace_binary ${BINARY} "${TMP_DIR}"
  clean "${TMP_DIR}"
else
  echo "Kubectl ${KUBECTL_VERSION} already installed skipping install"
fi

#######################################
# oc
#######################################

OC_OS=${OS}
if [[ $OSTYPE == 'darwin'* ]]; then
  OC_OS="mac"
fi

# OC cli version must be maintained manually, as there is no supported renovate datasource to find newer versions.
OC_VERSION=4.9.18
set +e
INSTALLED_OC_VERSION="$(oc version --client | grep "Client Version:" | cut -d' ' -f3)"
set -e
if [[ "$OC_VERSION" != "$INSTALLED_OC_VERSION" ]]; then
  BINARY=oc
  FILE_NAME="openshift-client-${OC_OS}-${OC_VERSION}.tar.gz"
  URL="https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OC_VERSION}"
  SUMFILE="sha256sum.txt"
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${OC_VERSION}..."

  download ${BINARY} ${OC_VERSION} ${URL} ${FILE_NAME} "${SUMFILE}" "${TMP_DIR}"
  verify ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  tar -xzf "${TMP_DIR}/${FILE_NAME}" -C "${TMP_DIR}"
  copy_replace_binary ${BINARY} "${TMP_DIR}"
  clean "${TMP_DIR}"
else
  echo "oc cli ${OC_VERSION} already installed skipping install"
fi
#######################################
# terraform config inspect
#######################################

 # renovate: datasource=github-releases depName=IBM-Cloud/terraform-config-inspect
TERRAFORM_CONFIG_INSPECT_VERSION=v1.0.0-beta3
# Not possible to check the version of this yet https://github.com/hashicorp/terraform-config-inspect/issues/88
TERRAFORM_CONFIG_INSPECT_VERSION_NUMBER="${TERRAFORM_CONFIG_INSPECT_VERSION:1}"
BINARY=terraform-config-inspect
FILE_NAME="terraform-config-inspect_${TERRAFORM_CONFIG_INSPECT_VERSION_NUMBER}_${OS}_amd64.zip"
URL="https://github.com/IBM-Cloud/terraform-config-inspect/releases/download/${TERRAFORM_CONFIG_INSPECT_VERSION}"
SUMFILE="terraform-config-inspect_${TERRAFORM_CONFIG_INSPECT_VERSION_NUMBER}_checksums.txt"
TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

echo
echo "-- Installing ${BINARY} ${TERRAFORM_CONFIG_INSPECT_VERSION}..."

download ${BINARY} ${TERRAFORM_CONFIG_INSPECT_VERSION} ${URL} ${FILE_NAME} "${SUMFILE}" "${TMP_DIR}"
verify ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
unzip "${TMP_DIR}/${FILE_NAME}" -d "${TMP_DIR}" > /dev/null
copy_replace_binary ${BINARY} "${TMP_DIR}"
clean "${TMP_DIR}"
