#!/usr/bin/env bash
export PATH="${GOPATH:-$HOME/go}/bin:$PATH"

service_name=$(basename -s .git `git config --get remote.origin.url`)
short_sha=$(git rev-parse --short HEAD)

dry_run=""
if [ "$1" = "-c" ]; then
  dry_run="-n"
fi

bumper_output=$( (bump deploy $dry_run pdev $service_name:dev-$short_sha | sort; ) 2>&1 )

if [ -z "$dry_run" ]; then
  echo $(echo "$bumper_output" | grep "Created")
else
  branch_name=$(echo "$bumper_output" | grep "checkout -b"| rev | cut -d " " -f1 | rev)
  commit_msg=$(echo "$bumper_output" | grep "with message"| cut -d'"' -f 2)

  git -C $BUMPER_PD_PATH checkout -q -b $branch_name
  git -C $BUMPER_PD_PATH commit -am "$commit_msg" > /dev/null

  echo "Created branch $branch_name in platform-dev, add your configs and push :)"
fi
