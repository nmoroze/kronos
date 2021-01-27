#!/usr/bin/env bash

curl -sSL https://get.haskellstack.org/ | sh

git clone https://github.com/zachjs/sv2v.git
cd sv2v
make
stack install
