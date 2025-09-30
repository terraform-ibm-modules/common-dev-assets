#!/bin/bash

set -o errexit
set -o pipefail

# Place binaries in /usr/local/bin unless $CUSTOM_DIRECTORY defined
if [[ -z "${CUSTOM_DIRECTORY}" ]]; then
  DIRECTORY="/usr/local/bin"
else
  DIRECTORY="${CUSTOM_DIRECTORY}"
  mkdir -p "${DIRECTORY}"
fi

# Determine OS type and arch
if [[ $OSTYPE == 'darwin'* ]]; then
  OS="darwin"
  # Determine OS arch
  mac_arch="$(sysctl -a | grep machdep.cpu.brand_string)"
  if [[ "${mac_arch}" == 'machdep.cpu.brand_string: Intel'* ]]; then
    # macOS on Intel architecture
    ARCH="amd64"
  else
    # macOS on M1 architecture
    ARCH="arm64"
  fi
else
  OS="linux"
  ARCH="amd64"
fi

# Function to download files
function download {

  binary=$1
  version=$2
  url=$3
  file=$4
  sumfile=$5
  tmp_dir=$6

  echo "Downloading ${binary} ${version}..."
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
  echo "${checksum}  ${tmp_dir}/${file}" | ${SHA256_CMD} -c

}

# Function to verify checksum of download file (when binary name not in sumfile)
function verify_alternative {

  file=$1
  sumfile=$2
  tmp_dir=$3

  echo "Verifying.."
  checksum=$(cat "${tmp_dir}/${sumfile}")
  echo "${checksum}  ${tmp_dir}/${file}" | ${SHA256_CMD} -c

}

# Function to copy and replace binary in $DIRECTORY
function copy_replace_binary {

  binary=$1
  tmp_dir=$2

  echo "Placing ${binary} binary in ${DIRECTORY} and making executable.."
  arg=""
  if ! [ -w "${DIRECTORY}" ]; then
    echo "No write permission to ${DIRECTORY}. Attempting to run with sudo..."
    arg=sudo
  fi
  # Need to delete if exists already in case it is a symlink which cannot be overwritten using cp -r
  ${arg} rm -f "${DIRECTORY}/${binary}"
  ${arg} cp -r "${tmp_dir}/${binary}" "${DIRECTORY}"
  ${arg} chmod +x "${DIRECTORY}/${binary}"

}

# Cleanup function
function clean {

  tmp_dir=$1

  echo "Deleting tmp dir: ${tmp_dir}"
  rm -rf "${tmp_dir}"
  echo "COMPLETE"
  echo
}

#######################################
# sha256sum
#######################################

# Determine which sha256 command to use
SHA256_CMD=""
if command -v sha256sum &> /dev/null; then
  # Check if it's the GNU version by looking for "GNU coreutils" in version output
  if sha256sum --version 2>&1 | grep -q "GNU coreutils"; then
    SHA256_CMD="sha256sum"
  elif command -v gsha256sum &> /dev/null; then
    # GNU version available via coreutils
    SHA256_CMD="gsha256sum"
  elif command -v shasum &> /dev/null; then
    # Fall back to BSD shasum
    SHA256_CMD="shasum -a 256"
  else
    echo "No suitable SHA256 command found"
    exit 1
  fi
elif command -v gsha256sum &> /dev/null; then
  # GNU version installed via coreutils on macOS
  SHA256_CMD="gsha256sum"
elif command -v shasum &> /dev/null; then
  # BSD version (macOS default)
  SHA256_CMD="shasum -a 256"
else
  # Need to install appropriate tool
  if [ "$OS" == "darwin" ]; then
    echo
    echo "-- Installing coreutils..."
    brew install coreutils
    SHA256_CMD="gsha256sum"
  else
    echo "sha256sum must be installed to verify downloads. Please install and retry."
    exit 1
  fi
fi

echo "Using SHA256 command: ${SHA256_CMD}"

#######################################
# python
#######################################

if python3 --version &> /dev/null; then
  PYTHON=python3
elif python --version &> /dev/null; then
  PYTHON=python
else
  echo "python or python3 not detected. Please install python, ensure it is on your \$PATH, and retry."
  exit 1
fi

#######################################
# golang
#######################################

if ! go version &> /dev/null; then
  echo "golang (go) not detected. Please install golang, ensure it is on your \$PATH, and retry."
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
# pipx
#######################################
 # renovate: datasource=github-tags depName=pypa/pipx
PIPX_VERSION=1.7.1
PACKAGE=pipx
set +e
INSTALLED_PIPX_VERSION="$(${PYTHON} -m pipx --version)"
set -e
echo
if [[ "$INSTALLED_PIPX_VERSION" != "$PIPX_VERSION" ]]; then
  echo "-- Installing ${PACKAGE}..."
  ${PYTHON} -m pip install -q --upgrade ${PACKAGE}
  echo "COMPLETE"
else
 echo "${PACKAGE} ${PIPX_VERSION} already installed - skipping install"
fi

#######################################
# pre-commit
#######################################

 # renovate: datasource=github-tags depName=pre-commit/pre-commit
PRE_COMMIT_VERSION=v4.3.0
PACKAGE=pre-commit
set +e
INSTALLED_PRE_COMMIT_VERSION="$(${PYTHON} -m pipx list | grep "package $PACKAGE " | sed -E "s/^.*package $PACKAGE ([^,]+),.*/\1/")"
set -e
if [[ "$INSTALLED_PRE_COMMIT_VERSION" == "" ]]; then

  echo
  echo "-- Installing ${PACKAGE} ${PRE_COMMIT_VERSION}..."

    ${PYTHON} -m pipx install -q ${PACKAGE}==${PRE_COMMIT_VERSION}
  echo "COMPLETE"
elif [[ "$PRE_COMMIT_VERSION" != "v$INSTALLED_PRE_COMMIT_VERSION" ]]; then
  echo
  echo "-- Upgrading ${PACKAGE} ${PRE_COMMIT_VERSION}..."
  ${PYTHON} -m pipx uninstall -q $PACKAGE
  ${PYTHON} -m pipx install -q "${PACKAGE}==${PRE_COMMIT_VERSION}"
  echo "COMPLETE"
else
 echo "${PACKAGE} ${PRE_COMMIT_VERSION} already installed - skipping install"
fi

#######################################
# detect-secrets
#######################################

 # renovate: datasource=github-tags depName=ibm/detect-secrets versioning="regex:^(?<compatibility>.*)-?(?<major>\\d+)\\.(?<minor>\\d+)\\+ibm\\.(?<patch>\\d+)\\.dss$"
DETECT_SECRETS_VERSION=0.13.1+ibm.62.dss
PACKAGE=detect-secrets
set +e
INSTALLED_DETECT_SECRETS="$(${PYTHON} -m pipx show detect-secrets | grep Version: | cut -d' ' -f2)"
set -e
if [[ "$DETECT_SECRETS_VERSION" != "$INSTALLED_DETECT_SECRETS" ]]; then

  echo
  echo "-- Installing ${PACKAGE} ${DETECT_SECRETS_VERSION}..."

  ${PYTHON} -m pipx upgrade -q --install "git+https://github.com/ibm/detect-secrets.git@${DETECT_SECRETS_VERSION}#egg=detect-secrets"
  echo "COMPLETE"
else
 echo "${PACKAGE} ${DETECT_SECRETS_VERSION} already installed - skipping install"
fi

#######################################
# terraform-switcher
#######################################

 # renovate: datasource=github-releases depName=warrensbox/terraform-switcher
TFSWITCH_VERSION=v1.6.0
BINARY=tfswitch
set +e
INSTALLED_TFSWITCH_VERSION="$(tfswitch --version | grep Version | awk '{ print $2 }')"
set -e
if [[ "$TFSWITCH_VERSION" != "$INSTALLED_TFSWITCH_VERSION" ]]; then
  FILE_NAME="terraform-switcher_${TFSWITCH_VERSION}_${OS}_${ARCH}.tar.gz"
  URL="https://github.com/warrensbox/terraform-switcher/releases/download/${TFSWITCH_VERSION}"
  SUMFILE="terraform-switcher_${TFSWITCH_VERSION}_checksums.txt"
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${TFSWITCH_VERSION}..."

  download ${BINARY} "${TFSWITCH_VERSION}" "${URL}" "${FILE_NAME}" "${SUMFILE}" "${TMP_DIR}"
  verify "${FILE_NAME}" "${SUMFILE}" "${TMP_DIR}"
  tar -xzf "${TMP_DIR}/${FILE_NAME}" -C "${TMP_DIR}"
  copy_replace_binary ${BINARY} "${TMP_DIR}"
  clean "${TMP_DIR}"
else
  echo "${BINARY} ${TFSWITCH_VERSION} already installed - skipping install"
fi

#######################################
# terraform
#######################################

# Locking into the latest version that Schematics supports currently
TERRAFORM_VERSION=v1.10.5
BINARY=terraform

set +e
INSTALLED_TERRAFORM_VERSION="$(terraform --version | head -1 | cut -d' ' -f2)"
set -e
if [[ "$TERRAFORM_VERSION" != "$INSTALLED_TERRAFORM_VERSION" ]]; then
  # 'v' prefix required for renovate to query github.com for new release, but needs to be removed to pull from hashicorp.com
  TERRAFORM_VERSION="${TERRAFORM_VERSION:1}"
  FILE_NAME="terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip"
  URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}"
  SUMFILE="terraform_${TERRAFORM_VERSION}_SHA256SUMS"
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${TERRAFORM_VERSION}..."

  download ${BINARY} "${TERRAFORM_VERSION}" "${URL}" "${FILE_NAME}" "${SUMFILE}" "${TMP_DIR}"
  verify "${FILE_NAME}" "${SUMFILE}" "${TMP_DIR}"
  unzip "${TMP_DIR}/${FILE_NAME}" -d "${TMP_DIR}" > /dev/null
  copy_replace_binary ${BINARY} "${TMP_DIR}"
  clean "${TMP_DIR}"
else
  echo "${BINARY} ${TERRAFORM_VERSION} already installed - skipping install"
fi

#######################################
# terraform-docs
#######################################

 # renovate: datasource=github-releases depName=terraform-docs/terraform-docs
TERRAFORM_DOCS_VERSION=v0.20.0
BINARY=terraform-docs
set +e
INSTALLED_TERRADOCS_VERSION="$(terraform-docs --version | head -1 | cut -d' ' -f3)"
set -e
if [[ "$TERRAFORM_DOCS_VERSION" != "$INSTALLED_TERRADOCS_VERSION" ]]; then
  FILE_NAME="terraform-docs-${TERRAFORM_DOCS_VERSION}-${OS}-${ARCH}.tar.gz"
  URL="https://github.com/terraform-docs/terraform-docs/releases/download/${TERRAFORM_DOCS_VERSION}"
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
  echo "${BINARY} ${TERRAFORM_DOCS_VERSION} already installed - skipping install"
fi

#######################################
# tflint
#######################################
 # renovate: datasource=github-releases depName=terraform-linters/tflint
TFLINT_VERSION=v0.59.1
BINARY=tflint
set +e
INSTALLED_TFLINT_VERSION="$(tflint --version | grep "TFLint version " |cut -d' ' -f3)"
set -e
if [[ "$TFLINT_VERSION" != "v$INSTALLED_TFLINT_VERSION" ]]; then
  FILE_NAME="tflint_${OS}_${ARCH}.zip"
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
  echo "${BINARY} ${TFLINT_VERSION} already installed - skipping install"
fi

#######################################
# trivy
#######################################

TRIVY_OS="Linux"
TRIVY_ARCH="64bit"
if [[ $OSTYPE == 'darwin'* ]]; then
  TRIVY_OS="macOS"
  if [[ "${ARCH}" == "arm64" ]]; then
    TRIVY_ARCH="ARM64"
  fi
fi

# renovate: datasource=github-releases depName=aquasecurity/trivy
TRIVY_VERSION=v0.66.0
BINARY=trivy
set +e
INSTALLED_TRIVY_VERSION="$(trivy version | grep "Version:" | cut -d' ' -f2)"
set -e
if [[ "$TRIVY_VERSION" != "v${INSTALLED_TRIVY_VERSION}" ]]; then
  FILE_NAME="trivy_${TRIVY_VERSION:1}_${TRIVY_OS}-${TRIVY_ARCH}.tar.gz"
  URL="https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VERSION}"
  SUMFILE="trivy_${TRIVY_VERSION:1}_checksums.txt"
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${TRIVY_VERSION}..."

  download ${BINARY} ${TRIVY_VERSION} ${URL} "${FILE_NAME}" "${SUMFILE}" "${TMP_DIR}"
  verify "${FILE_NAME}" "${SUMFILE}" "${TMP_DIR}"
  tar -xzf "${TMP_DIR}/${FILE_NAME}" -C "${TMP_DIR}"
  copy_replace_binary ${BINARY} "${TMP_DIR}"
  clean "${TMP_DIR}"
else
  echo "${BINARY} ${TRIVY_VERSION} already installed - skipping install"
fi

#######################################
# golangci-lint
#######################################

 # renovate: datasource=github-releases depName=golangci/golangci-lint
GOLANGCI_LINT_VERSION=v2.4.0
BINARY=golangci-lint
set +e
INSTALLED_GOLANGCI_LINT_VERSION="$(golangci-lint --version | head -1 | cut -d' ' -f4)"
set -e
if [[ "$GOLANGCI_LINT_VERSION" != "v$INSTALLED_GOLANGCI_LINT_VERSION" ]]; then
  FILE_NAME="golangci-lint-${GOLANGCI_LINT_VERSION//v/}-${OS}-${ARCH}.tar.gz"
  URL="https://github.com/golangci/golangci-lint/releases/download/${GOLANGCI_LINT_VERSION}"
  SUMFILE="${BINARY}-${GOLANGCI_LINT_VERSION//v/}-checksums.txt"
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${GOLANGCI_LINT_VERSION}..."

  download ${BINARY} ${GOLANGCI_LINT_VERSION} ${URL} "${FILE_NAME}" "${SUMFILE}" "${TMP_DIR}"
  verify "${FILE_NAME}" "${SUMFILE}" "${TMP_DIR}"
  tar -xzf "${TMP_DIR}/${FILE_NAME}" -C "${TMP_DIR}"
  copy_replace_binary ${BINARY} "${TMP_DIR}/golangci-lint-${GOLANGCI_LINT_VERSION//v/}-${OS}-${ARCH}"
  clean "${TMP_DIR}"
else
  echo "${BINARY} ${GOLANGCI_LINT_VERSION} already installed - skipping install"
fi

#######################################
# Rust
#######################################

# renovate: datasource=github-releases depName=rust-lang/rust
RUST_VERSION=1.83.0
BINARY=rustc
set +e
INSTALLED_RUST_VERSION="$(rustc --version 2>/dev/null | cut -d' ' -f2)"
set -e
if [[ "$RUST_VERSION" != "$INSTALLED_RUST_VERSION" ]]; then
  echo
  echo "-- Installing Rust ${RUST_VERSION}..."

  # Download rustup installer
  TMP_DIR=$(mktemp -d /tmp/rust-XXXXX)
  RUSTUP_INIT="rustup-init.sh"

  if [[ $OSTYPE == 'darwin'* ]]; then
    if [[ "${ARCH}" == "arm64" ]]; then
      RUSTUP_TARGET="aarch64-apple-darwin"
    else
      RUSTUP_TARGET="x86_64-apple-darwin"
    fi
  else
    RUSTUP_TARGET="x86_64-unknown-linux-gnu"
  fi

  # Use the standard rustup installer
  curl --retry 3 -fLsS "https://sh.rustup.rs" --output "${TMP_DIR}/${RUSTUP_INIT}"

  # Install rust with specific version
  chmod +x "${TMP_DIR}/${RUSTUP_INIT}"

  # Install rustup and rust toolchain
  echo "Installing Rust toolchain ${RUST_VERSION}..."

  # Set RUSTUP_HOME and CARGO_HOME if not set
  export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
  export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"

  # Install rustup non-interactively
  "${TMP_DIR}/${RUSTUP_INIT}" -y --default-toolchain "${RUST_VERSION}" --target "${RUSTUP_TARGET}"

  # Add cargo bin to PATH for this session
  export PATH="${CARGO_HOME}/bin:$PATH"

  # Create symlinks in DIRECTORY if different from default cargo location
  if [[ "${DIRECTORY}" != "${CARGO_HOME}/bin" ]]; then
    echo "Creating symlinks in ${DIRECTORY}..."
    arg=""
    if ! [ -w "${DIRECTORY}" ]; then
      echo "No write permission to ${DIRECTORY}. Attempting to run with sudo..."
      arg=sudo
    fi

    # Create symlinks for main rust tools
    for rust_binary in rustc cargo rustup; do
      ${arg} rm -f "${DIRECTORY}/${rust_binary}"
      ${arg} ln -sf "${CARGO_HOME}/bin/${rust_binary}" "${DIRECTORY}/${rust_binary}"
    done
  fi

  echo "Deleting tmp dir: ${TMP_DIR}"
  rm -rf "${TMP_DIR}"
  echo "COMPLETE"
else
  echo "Rust ${RUST_VERSION} already installed - skipping install"
fi

#######################################
# Shellcheck
#######################################

 # renovate: datasource=github-releases depName=koalaman/shellcheck
SHELLCHECK_VERSION=v0.11.0
BINARY=shellcheck
set +e
INSTALLED_SHELLCHECK_VERSION="$(shellcheck --version | grep "version:" | cut -d' ' -f2)"
set -e
if [[ "$SHELLCHECK_VERSION" != "v$INSTALLED_SHELLCHECK_VERSION" ]]; then
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
  echo "${BINARY} ${SHELLCHECK_VERSION} already installed - skipping install"
fi

#######################################
# hadolint
#######################################

 # renovate: datasource=github-releases depName=hadolint/hadolint
HADOLINT_VERSION=v2.13.1
BINARY=hadolint
set +e
INSTALLED_HADOLINT_VERSION="$(hadolint --version | head -1 | cut -d' ' -f4)"
set -e
if [[ "$HADOLINT_VERSION" != "v$INSTALLED_HADOLINT_VERSION" ]]; then
  # Handle architecture properly
  HADOLINT_ARCH="x86_64"
  if [[ "$ARCH" == "arm64" ]]; then
    HADOLINT_ARCH="arm64"
  fi

  URL="https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}"
  SUMFILE=""
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${HADOLINT_VERSION}..."

  # Try hadolint's current naming convention first (macos), then fall back to darwin
  DOWNLOAD_SUCCESS=false

  if [[ "$OS" == "darwin" ]]; then
    # Try macos naming first
    FILE_NAME="hadolint-macos-${HADOLINT_ARCH}"
    echo "Attempting download with macos naming: ${FILE_NAME}"
    if curl --retry 3 -fLsS "${URL}/${FILE_NAME}" --output "${TMP_DIR}/${FILE_NAME}" 2>/dev/null; then
      DOWNLOAD_SUCCESS=true
      echo "Downloaded successfully"
    else
      echo "macos naming failed, trying darwin naming..."
      # Fall back to darwin naming
      FILE_NAME="hadolint-darwin-${HADOLINT_ARCH}"
      echo "Attempting download with darwin naming: ${FILE_NAME}"
      if curl --retry 3 -fLsS "${URL}/${FILE_NAME}" --output "${TMP_DIR}/${FILE_NAME}" 2>/dev/null; then
        DOWNLOAD_SUCCESS=true
        echo "Downloaded successfully"
      fi
    fi
  else
    # For Linux, use standard naming
    FILE_NAME="hadolint-${OS}-${HADOLINT_ARCH}"
    download ${BINARY} ${HADOLINT_VERSION} ${URL} ${FILE_NAME} "${SUMFILE}" "${TMP_DIR}"
    DOWNLOAD_SUCCESS=true
  fi

  if [[ "$DOWNLOAD_SUCCESS" == "true" ]]; then
    ## rename binary to hadolint
    mv "${TMP_DIR}/${FILE_NAME}" "${TMP_DIR}/${BINARY}"
    copy_replace_binary ${BINARY} "${TMP_DIR}"
    clean "${TMP_DIR}"
  else
    echo "Failed to download ${BINARY} ${HADOLINT_VERSION} with both naming conventions"
    clean "${TMP_DIR}"
    exit 1
  fi
else
  echo "${BINARY} ${HADOLINT_VERSION} already installed - skipping install"
fi

#######################################
# helm
#######################################

 # renovate: datasource=github-releases depName=helm/helm
HELM_VERSION=v3.19.0
BINARY=helm
set +e
INSTALLED_HELM_VERSION="$(helm version | cut -d':' -f2 | cut -d'"' -f2)"
set -e
if [[ "$HELM_VERSION" != "$INSTALLED_HELM_VERSION" ]]; then
  FILE_NAME="helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz"
  URL="https://get.helm.sh"
  SUMFILE="helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz.sha256"
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${HELM_VERSION}..."

  download ${BINARY} ${HELM_VERSION} ${URL} ${FILE_NAME} "${SUMFILE}" "${TMP_DIR}"
  verify_alternative ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  tar -xzf "${TMP_DIR}/${FILE_NAME}" -C "${TMP_DIR}"
  copy_replace_binary ${BINARY} "${TMP_DIR}/${OS}-${ARCH}"
  clean "${TMP_DIR}"
else
  echo "${BINARY} ${HELM_VERSION} already installed - skipping install"
fi
#######################################
# kubectl
#######################################

 # renovate: datasource=github-releases depName=kubernetes/kubernetes
KUBECTL_VERSION=v1.34.1
BINARY=kubectl
set +e
INSTALLED_KUBECTL_VERSION="$(kubectl version --output yaml --client | grep "gitVersion" | cut -d' ' -f4)"
set -e
if [[ "$KUBECTL_VERSION" != "$INSTALLED_KUBECTL_VERSION" ]]; then
  FILE_NAME="kubectl"
  URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}"
  SUMFILE="kubectl.sha256"
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${KUBECTL_VERSION}..."

  download ${BINARY} ${KUBECTL_VERSION} ${URL} ${FILE_NAME} "${SUMFILE}" "${TMP_DIR}"
  verify_alternative ${FILE_NAME} ${SUMFILE} "${TMP_DIR}"
  copy_replace_binary ${BINARY} "${TMP_DIR}"
  clean "${TMP_DIR}"
else
  echo "${BINARY} ${KUBECTL_VERSION} already installed - skipping install"
fi

#######################################
# oc
#######################################

OC_OS=${OS}
if [[ $OSTYPE == 'darwin'* ]]; then
  OC_OS="mac"
fi

# OC cli version must be maintained manually, as there is no supported renovate datasource to find newer versions.
OC_VERSION=4.11.9
BINARY=oc
set +e
INSTALLED_OC_VERSION="$(oc version --client | grep "Client Version:" | cut -d' ' -f3)"
set -e
if [[ "$OC_VERSION" != "$INSTALLED_OC_VERSION" ]]; then
  FILE_NAME="openshift-client-${OC_OS}-${OC_VERSION}.tar.gz"
  URL="https://mirror.openshift.com/pub/openshift-v4/${ARCH}/clients/ocp/${OC_VERSION}"
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
  echo "${BINARY} cli ${OC_VERSION} already installed - skipping install"
fi

#######################################
# jq
#######################################

JQ_OS=${OS}
if [[ $OSTYPE == 'darwin'* ]]; then
  JQ_OS="macos"
fi

 # renovate: datasource=github-releases depName=jqlang/jq
JQ_VERSION=1.7.1
BINARY=jq
set +e
INSTALLED_JQ_VERSION="$(jq --version | cut -c4-)"
set -e
if [[ "$JQ_VERSION" != "$INSTALLED_JQ_VERSION" ]]; then
  FILE_NAME="jq-${JQ_OS}-${ARCH}"
  URL="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}"
  SUMFILE=""
  TMP_DIR=$(mktemp -d /tmp/${BINARY}-XXXXX)

  echo
  echo "-- Installing ${BINARY} ${JQ_VERSION}..."

  download ${BINARY} ${JQ_VERSION} ${URL} ${FILE_NAME} "${SUMFILE}" "${TMP_DIR}"
  # rename binary to jq
  mv "${TMP_DIR}/${FILE_NAME}" "${TMP_DIR}/${BINARY}"
  copy_replace_binary ${BINARY} "${TMP_DIR}"
  clean "${TMP_DIR}"
else
  echo "${BINARY} ${JQ_VERSION} already installed - skipping install"
fi
