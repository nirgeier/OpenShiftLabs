#!/bin/bash

# Check it runs
crc version

crc config set memory 16384   # 16 GB RAM
crc config set cpus 4         # Keep 4 CPUs for stability

crc config set disable-update-check true
crc config set enable-cluster-monitoring false

crc config set pull-secret-file ./pull-secret.json

crc setup
crc start

# Get the password
crc console --credentials

# # Create a password file
# htpasswd -c -B -b kubeadmin.htpasswd kubeadmin kubeadmin

# # Create a secret from the password
# oc create secret generic htpasswd-secret --from-file=htpasswd=kubeadmin.htpasswd -n openshift-config

# oc patch oauth cluster --type=merge -p '{"spec":{"identityProviders":[{"name":"local","mappingMethod":"claim","type":"HTPasswd","htpasswd":{"fileData":{"name":"htpasswd-secret"}}}]}}'
# oc adm policy add-cluster-role-to-user cluster-admin kubeadmin

# Use the 'oc' command line interface:
eval $(crc oc-env)
oc login -u developer https://api.crc.testing:6443

oc new-project codewizard-project
oc new-app rails-postgresql-example

##
## GUI
##
# https://console-openshift-console.apps-crc.testing/dashboards
