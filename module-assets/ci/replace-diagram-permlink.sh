#!/bin/bash
set -e

if [ -e check-git-status-hook.txt ]; then
    file_changed=$(<check-git-status-hook.txt)
    rm -f check-git-status-hook.txt

    if [ "$file_changed" == true ]; then
        # Get the hash of the current commit
        commit_hash=$(git rev-parse HEAD)

        # Get the remote origin URL
        remote_url=$(git config --get remote.origin.url)

        # Check if the URL uses the https or ssh format
        if [[ $remote_url == http* ]]; then
            # If the URL is in the form https://domain.com/user/repo.git
            domain=$(echo $remote_url | cut -d'/' -f3)
            user=$(echo $remote_url | cut -d'/' -f4)
            repo=$(echo $remote_url | cut -d'/' -f5 | cut -d'.' -f1)
        else
            # If the URL is in the form git@domain.com:user/repo.git
            domain=$(echo $remote_url | cut -d'@' -f2 | cut -d':' -f1)
            user=$(echo $remote_url | cut -d':' -f2 | cut -d'/' -f1)
            repo=$(echo $remote_url | cut -d'/' -f2 | cut -d'.' -f1)
        fi

        # Generate the base URL for the image in your markdown files
        base_url="https://$domain/$user/$repo/blob/"

        # A regex pattern that matches any commit hash
        commit_pattern="[0-9a-f]\{40\}"

        # Relative path to the image files
        image_paths=("reference-architectures/vpc.drawio.svg" "reference-architectures/vsi-vsi.drawio.svg" "reference-architectures/roks.drawio.svg" ".docs/images/mixed.png")

        # README file
        file="./README.md"

        # Update link for all images
        for image_path in "${image_paths[@]}"
        do
            if grep -q "$base_url$commit_pattern/$image_path" "$file"; then
                sed -i --backup "s%\($base_url\)$commit_pattern\(/$image_path\)%\1$commit_hash\2%g" "$file"
                # remove backup
                rm -f ./README.md--backup
            fi
        done

        # Stage README.md
        git add ./README.md

        # Create a new commit with the updated files
        git commit --no-verify --amend --no-edit
    fi
fi
