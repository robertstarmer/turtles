#!/usr/bin/env bash
cat $1 | sed -e 's/git@github\.com:/git:\/\/github.com\//g' > /tmp/fixed-gitmodules
mv /tmp/fixed-gitmodules $1
