#!/usr/bin/env bash

source /etc/os-release

if [[ $UBUNTU_CODENAME == "focal" ]]; then
    # NOTE: Cloud Init may set a wrong default route. This is repaired manually here.
    # FIXME: Find better/prettier solution for it.
    ip route del default via 192.168.32.1 || exit 0
    ip route add default via 192.168.16.1 || exit 0
fi

# NOTE: Because DNS queries don't always work directly at the beginning a
#       retry for APT.
echo "APT::Acquire::Retries \"3\";" > /etc/apt/apt.conf.d/80-retries

echo '* libraries/restart-without-asking boolean true' | debconf-set-selections

if [[ $UBUNTU_CODENAME == "bionic" ]]; then

    # NOTE: Script is only needed for Bionic, the cloud-init on Focal initializes
    #       all NICs.
    apt-get install --yes python3-netifaces
    python3 /root/configure-network-devices.py

    # NOTE: Ansible PPA is currently only needed on Bionic. At the moment Focal
    #       delivers a current enough Ansible.
    add-apt-repository --yes ppa:ansible/ansible
else
    apt-get update
fi

apt-get install --yes ansible ifupdown

chown -R ubuntu:ubuntu /home/ubuntu/.ssh

ansible-galaxy install git+https://github.com/osism/ansible-docker

# FIXME: With Ansible 2.10 it is possible to install collections via Git directly.
git clone https://github.com/osism/ansible-collection-commons.git /tmp/ansible-collection-commons
( cd /tmp/ansible-collection-commons; ansible-galaxy collection build; ansible-galaxy collection install -v -f -p /usr/share/ansible/collections osism-commons-*.tar.gz; )
rm -rf /tmp/ansible-collection-commons

# FIXME: With Ansible 2.10 it is possible to install collections via Git directly.
git clone https://github.com/osism/ansible-collection-services.git /tmp/ansible-collection-services
( cd /tmp/ansible-collection-services; ansible-galaxy collection build; ansible-galaxy collection install -v -f -p /usr/share/ansible/collections osism-services-*.tar.gz; )
rm -rf /tmp/ansible-collection-services

chmod -R +r /usr/share/ansible/collections/ansible_collections

ansible-playbook -i localhost, /opt/node.yml
