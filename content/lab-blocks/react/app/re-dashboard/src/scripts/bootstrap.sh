#!/bin/bash
# Link the dependencies baked into the sandbox image (the sandbox has no
# network, so there is no npm install). Safe to run repeatedly; the platform
# runs it at session start and before every grading run.
cd "$(dirname "$0")/.." || exit 1
ln -sfn /opt/scaffold/react-app/node_modules node_modules
