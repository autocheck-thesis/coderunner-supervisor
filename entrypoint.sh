#!/usr/bin/env bash

echo $@

bin/coderunner_supervisor test_suite "$@"