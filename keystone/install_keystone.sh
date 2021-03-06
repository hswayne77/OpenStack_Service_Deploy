#!/usr/bin/env bash
# author: Derrick Yang

# enable trace
set -x 

DATABASE_HOST=localhost
DATABASE_USER=root
DATABASE_PASSWORD=root
DATABASE=keystone

SERVICE_USER=keystone
SERVICE_PASSWORD=keystone
SERVICE_PUBLIC_PORT=5000
SERVICE_INTERNAL_PORT=5000
SERVICE_ADMIN_PORT=35357
API_VERSION=v2.0
SERVICE_CONFIG_PATH=/etc/${SERVICE_USER}/${SERVICE_USER}.conf

CONTROLLER_IP=localhost
ENDPOINT_PUBLIC_URL=http://${CONTROLLER_IP}:${SERVICE_PUBLIC_PORT}/${API_VERSION}
ENDPOINT_INTERNAL_URL=http://${CONTROLLER_IP}:${SERVICE_INTERNAL_PORT}/${API_VERSION}
ENDPOINT_ADMIN_URL=http://${CONTROLLER_IP}:${SERVICE_ADMIN_PORT}/${API_VERSION}
ENDPOINT_REGION=RegionOne

ADMIN_TENANT=admin
ADMIN_USER=admin
ADMIN_PASSWORD=admin


# ===============
# Create database
# ===============
mysql -h ${DATABASE_HOST} -u ${DATABASE_USER} -p${DATABASE_PASSWORD} \
      -e "DROP DATABASE IF EXISTS ${DATABASE};"\
"CREATE DATABASE ${DATABASE};"\
"GRANT ALL PRIVILEGES ON ${DATABASE}.* TO '${SERVICE_USER}'@'localhost' IDENTIFIED BY '${SERVICE_PASSWORD}';"\
"GRANT ALL PRIVILEGES ON ${DATABASE}.* TO '${SERVICE_USER}'@'%' IDENTIFIED BY '${SERVICE_PASSWORD}';"

# ================
# Install Packages
# ================
apt-get install -y keystone python-keystoneclient


# ======================
# Update Identity Config
# ======================
cp ${SERVICE_CONFIG_PATH} ${SERVICE_CONFIG_PATH}.sample
# generate admin token
ADMIN_TOKEN=$(openssl rand -hex $((${RANDOM}/100)))
if [ -f ${SERVICE_CONFIG_PATH} ];then
    sed -i -r "s|^(#? *)(admin_token)( *= *)(.*)|admin_token=${ADMIN_TOKEN}" ${SERVICE_CONFIG_PATH}
    sed -i -r "s|^(#? *)(connection)( *= *)(.*)|connection=mysql://${SERVICE_USER}:${SERVICE_PASSWORD}@${DATABASE_HOST}/${DATABASE}" ${SERVICE_CONFIG_PATH}

fi

# sync the 'keystone' database
keystone-manage db_sync

# restart keystone
service keystone restart

sleep 5

export OS_SERVICE_TOKEN=${ADMIN_TOKEN}
export OS_SERVICE_ENDPOINT=${ENDPOINT_ADMIN_URL}

# Create the admin tenant
keystone tenant-create --name ${ADMIN_TENANT} --description "Admin Tenant"
# Create the admin user
keystone user-create --name ${ADMIN_USER}  --pass ${ADMIN_PASSWORD}
# Create the admin role
keystone role-create --name admin
# Add the admin role to the admin tenant and user
keystone user-role-add --user ${ADMIN_USER} --tenant ${ADMIN_TENANT} --role admin

# Create Tenant
keystone tenant-create --name service --description "Service Tenant"


# Create the service entity for the identity service:
keystone service-create --name ${SERVICE_USER} --type identity \
--description "OpenStack Identity"

keystone endpoint-create \
--service-id $(keystone service-list | awk '/identity/{print $2}') \
--publicurl ${ENDPOINT_PUBLIC_URL} \
--internalurl ${ENDPOINT_INTERNAL_URL} \
--adminurl ${ENDPOINT_ADMIN_URL} \
--region ${ENDPOINT_REGION}
