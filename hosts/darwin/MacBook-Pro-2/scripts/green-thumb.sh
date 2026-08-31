#!/usr/bin/env bash

# updates all goland workspace.xml files to use the latest GOROOT path

go_root_url="file://$(go env GOROOT)"

path_pattern='*/.idea/workspace.xml'
replacement_pattern='s|name="GOROOT" url="[^"]*"|name="GOROOT" url="'"$go_root_url"'"|g'

find ~/Projects -path "$path_pattern" -exec sed -i.bak "$replacement_pattern" {} +
