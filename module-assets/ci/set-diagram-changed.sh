#!/bin/bash
set -e

# if the following diagram inside README.md has been changed then save 'true' inside 'check-git-status-hook.txt' file. Value is later used by 'replace-diagram-permlink' hook
# reference-architectures/vpc.drawio.svg
# reference-architectures/vsi-vsi.drawio.svg
# reference-architectures/roks.drawio.svg
# .docs/images/mixed.png
rm -f check-git-status-hook.txt
echo true > check-git-status-hook.txt
