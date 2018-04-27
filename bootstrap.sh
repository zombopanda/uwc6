#!/usr/bin/env bash

curl -sSL https://get.rvm.io | bash -s stable
source /usr/local/rvm/scripts/rvm
rvm mount -r https://rvm.io/binaries/ubuntu/14.04/x86_64/ruby-2.1.3.tar.bz2 --quiet-curl
rvm use 2.1.3 --default
cd /vagrant
bundle install
