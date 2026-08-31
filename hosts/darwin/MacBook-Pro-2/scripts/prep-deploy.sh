#!/usr/bin/env bash

service_name=$(basename -s .git `git config --get remote.origin.url`)
latest_tag=$(git describe --tags --abbrev=0)
echo "prepping $service_name $latest_tag for deploy"

publish_release_run_id=$(gh run list --json workflowName,databaseId,headBranch | jq --arg tag "$latest_tag" '.[] | select(.headBranch == $tag).databaseId')
publish_release_run_status=$(gh run view $publish_release_run_id --json status --jq '.status')

if [ $publish_release_run_status != "completed" ] ; then
  echo "Publish Release run currently in $publish_release_run_status status"
  exit
fi

# get pdev pr
pdev_pr_json=$(gh pr list -R moovfinancial/platform-dev -A "moov-bot" --json title,number,url | jq --arg tag "$latest_tag" --arg service_name "$service_name" '.[] | select(.title | contains ($tag) and contains ($service_name))')

# get infra prs
staging_pr_json=$(gh pr list -R moovfinancial/infra -A "moov-bot" --json title,number,url | jq --arg tag "$latest_tag" --arg service_name "$service_name" '.[] | select(.title | contains ($tag) and contains ($service_name) and contains ("staging"))')
production_pr_json=$(gh pr list -R moovfinancial/infra -A "moov-bot" --json title,number,url | jq --arg tag "$latest_tag" --arg service_name "$service_name" '.[] | select(.title | contains ($tag) and contains ($service_name) and contains ("production"))')

# mark the prs ready and tag platform cards as reviewer
pdev_pr_number=$(jq -r '.number' <<< "$pdev_pr_json")
gh pr edit -R moovfinancial/platform-dev $pdev_pr_number --add-reviewer moovfinancial/platform-cards
gh pr ready -R moovfinancial/platform-dev $pdev_pr_number

staging_pr_number=$(jq -r '.number' <<< "$staging_pr_json")
gh pr edit -R moovfinancial/infra $staging_pr_number --add-reviewer moovfinancial/platform-cards
gh pr ready -R moovfinancial/infra $staging_pr_number

production_pr_number=$(jq -r '.number' <<< "$production_pr_json")
gh pr edit -R moovfinancial/infra $production_pr_number --add-reviewer moovfinancial/platform-cards
gh pr ready -R moovfinancial/infra $production_pr_number

# format slack message
pdev_pr_url=$(jq -r '.url' <<< "$pdev_pr_json")
staging_pr_url=$(jq -r '.url' <<< "$staging_pr_json")
production_pr_url=$(jq -r '.url' <<< "$production_pr_json")

slack_message=":pr: $service_name,
- platform-dev: $pdev_pr_url
- staging: $staging_pr_url
- production: $production_pr_url"

echo "$slack_message" | pbcopy

echo "$service_name $latest_tag prepped for deploy, good luck :)"
