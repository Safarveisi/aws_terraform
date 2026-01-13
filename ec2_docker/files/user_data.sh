#!/bin/bash -xe
##################################################
# Install Docker
##################################################
export DEBIAN_FRONTEND=noninteractive

if ! command -v docker >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y docker.io
  systemctl enable --now docker
fi

usermod -aG docker ubuntu || true

# Create a marker file to confirm user_data execution
echo "user_data executed" > /var/log/user_data_executed.txt
