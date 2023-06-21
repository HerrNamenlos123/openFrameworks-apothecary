#!/bin/bash

# Check if all required environment variables are set
if [ -z ${PLATFORM+x} ]; then echo "PLATFORM is unset"; exit 1; fi
if [ -z ${COMPILER_VERSION+x} ]; then echo "COMPILER_VERSION is unset"; exit 1; fi

echo building package ${PLATFORM} with compiler version ${COMPILER_VERSION}