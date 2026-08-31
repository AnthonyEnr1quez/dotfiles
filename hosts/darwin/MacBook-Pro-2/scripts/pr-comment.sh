#!/usr/bin/env bash
# get all short shas from pr to json array
short_shas_json=$(gh pr view --json commits --jq '[.commits[].oid.[0:7]]')

# get pdev pr info
pdev_pr_json=$(gh pr list -R moovfinancial/platform-dev -A "@me" --json headRefName,number,title,url | jq --argjson ss "$short_shas_json" '.[] | select(any( .title; contains( $ss[] )))')

## get pdev pr files url
pdev_pr_files_url=$(jq -r '.url += "/files" | .url' <<< "$pdev_pr_json")

## get latest run url
pdev_branch_name=$(jq -r '.headRefName' <<< "$pdev_pr_json")
pdev_pr_latest_run_url=$(gh run list -b $pdev_branch_name -R moovfinancial/platform-dev -L 1 --json url --jq '.[].url')

## get pr number of current branch
pr_number=$(gh pr view --json number --jq '.number')

pr_comment="passed p-dev
- changes: $pdev_pr_files_url
- run: $pdev_pr_latest_run_url"

# print if dry run, or send the comment :)
if [ "$1" = "-d" ]; then
  echo "$pr_comment"
else
  gh pr comment $pr_number -b "$pr_comment"
  gh pr close -R moovfinancial/platform-dev -d $(jq -r '.number' <<< "$pdev_pr_json")
fi
