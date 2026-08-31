#!/usr/bin/env bash
service_dir=$(docker ps -q | head -n 1 | xargs -I{} docker inspect {} --format '{{ index .Config.Labels "com.docker.compose.project.working_dir"}}')

make -C "$service_dir" teardown

make setup
