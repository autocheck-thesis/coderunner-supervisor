#!/usr/bin/env bash

cd ..

cp coderunner-supervisor/.dockerignore .dockerignore

docker build -t autocheck-coderunner -f coderunner-supervisor/Dockerfile .

rm .dockerignore