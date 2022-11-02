#!/bin/bash
set -e

function create_temp_submodule_folder() {
    path="$1"
    rm -fr "${path}"
    mkdir "${path}"
    cp .gitmodules "${path}"
    cp -R .github "${path}"
    cp -R .git "${path}"
}

function remove_temp_submodule_folder() {
    cd ..
    rm -fr "${temp_dir}"
}

function get_submodule_version() {
    git_status=$(git submodule status)
    git_status="${git_status:1}"
    echo "${git_status%%common-dev-assets*}"
}

function main() {
    # execute only if repo has submodules
    if [ -e ".gitmodules" ]
    then
        temp_dir="submodule_version_check_temp"
        create_temp_submodule_folder "${temp_dir}"
        cd "${temp_dir}"

        # current local submodule version
        submodule_version_current=$(get_submodule_version)

        # rebase local submodule version with master branch
        git submodule update --rebase
        submodule_version_master_branch=$(get_submodule_version)

        if [ "${submodule_version_current}" != "${submodule_version_master_branch}" ]; then
            # update local submodule version with remote
            git submodule update --remote --merge
            submodule_version_remote=$(get_submodule_version)

            if [ "${submodule_version_current}" != "${submodule_version_remote}" ]; then
                printf "\nDetected local common-dev-assets git submodule commit ID is older than the one in primary branch. Run the following command to sync with primary branch: git submodule update --rebase"
                remove_temp_submodule_folder
                exit 1
            fi
        fi
        remove_temp_submodule_folder
    fi
}

main
