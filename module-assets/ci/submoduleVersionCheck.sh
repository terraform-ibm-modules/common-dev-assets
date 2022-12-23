#!/bin/bash
set -e

# Script checks if commit id of the git submodule in a PR branch is older than the one in a main branch or remote.
# If commit id is older then error is thrown.
# pseudocode:
#   if local_commit_id == main_branch_commit_id
#   then OK
#   else check remote submodule id
#       if local_commit_id == remote_commit_id
#       then OK
#       else throw Error


function get_submodule_version() {
    git_submodule_name=$1
    IFS=$'\n'
    git_submodules=$(git submodule status)
    for item in $git_submodules
    do
       if [[ $item == *"${git_submodule_name}"* ]]; then
            submodule="${item:1}"
            submodule_id="${submodule%%common-dev-assets*}"
            break
        fi
    done
    echo "${submodule_id}"
}

function submodule_exists(){
    git_submodule_name=$1
    git_submodules=$(git submodule status)
    exists=false
    if [ -e ".gitmodules" ]
    then
        while IFS= read -r line ; do
            if [[ $line == *"${git_submodule_name}"* ]]; then
                exists=true
                break
            fi
        done <<< "${git_submodules}"
    fi
    echo "${exists}"
}

function main() {
    # execute only if repo has common-dev-assets submodule
    git_submodule_name="common-dev-assets"
    git_submodule_exists=$(submodule_exists ${git_submodule_name})

    if [ "${git_submodule_exists}" = true  ]
    then
        # current submodule version
        submodule_version_current=$(get_submodule_version ${git_submodule_name})

        # get git remote url which is needed for a repo clone
        git_remote_url=$(git config --get remote.origin.url)

        # create temp folder and clone a repo
        temp_dir=$(mktemp -d)
        cd "${temp_dir}"
        git clone "${git_remote_url}"
        cd "$(ls)"

        # get primary branch submodule version
        git submodule update --init
        submodule_version_main_branch=$(get_submodule_version ${git_submodule_name})

        if [ "${submodule_version_current}" != "${submodule_version_main_branch}" ]; then
            # update submodule version with remote
            git submodule update --remote --merge
            submodule_version_remote=$(get_submodule_version ${git_submodule_name})

            if [ "${submodule_version_current}" != "${submodule_version_remote}" ]; then
                printf "\nDetected common-dev-assets git submodule commit ID is older than the one in primary branch. Make sure your branch is rebased with remote primary branch and run the following command to sync with primary branch: git submodule update --rebase."
                rm -fr "${temp_dir}"
                exit 1
            fi
        fi
        rm -fr "${temp_dir}"
    fi
}

main
