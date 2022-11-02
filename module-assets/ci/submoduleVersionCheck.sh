#!/bin/bash
set -e

function create_temp_submodule_folder() {
    rm -fr ../test
    mkdir ../test
    cp .gitmodules ../test
    cp -R .github ../test
    cp -R .git ../test
    cd ../test
}

function get_submodule_version() {
    git_status=$(git submodule status)
    git_status="${git_status:1}"
    echo "${git_status%%common-dev-assets*}"
}

function main() {
    # execute only if repo has submodules
    if [ -e "/.gitmodules" ]
        then
        create_temp_submodule_folder

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
                exit 1
            fi
        fi

        rm -fr ../test

    fi
}

main
