#!/bin/bash

# vars for config file
. /path/to/config_file.conf

# activate service account
gcloud auth activate-service-account ${SERVICE_ACCOUNT} --key-file=${ACCOUNT_KEY}

# access secret from gcp secret mamager
for secret in $(gcloud secrets versions access ${SECRET_VERSION} --secret=${SECRET_ID})
do
echo "$(date +%F.%T) secret received" >>  ${LOG_DIR}/${LOG_FILE}
done

# create a backup directory
mkdir -p ${BACKUP_DIR}

# create a backup
curl -X POST \
     -F "master_pwd=$secret" \
     -F "name=${ODOO_DATABASE}" \
     -F "backup_format=zip" \
     -o ${BACKUP_DIR}/${ODOO_DATABASE}.$(date +%F.%T).zip \
     http://${DATABASE_IP}:${PORT}/web/database/backup

# delete old backups
find ${BACKUP_DIR} -type f -mtime 1 -name "${ODOO_DATABASE}.*.zip" -delete

find ${SAVE_BASE} -type f -mtime 1 -name "${ODOO_DATABASE}.*.zip" -delete

# copy backup to save base
find ${BACKUP_DIR} -type f -cmin 1 -name "${ODOO_DATABASE}.*.zip" -exec cp '{}' ${SAVE_BASE} \;

# hashsum first backup varn
HASH_FIRST= find ${BACKUP_DIR} -type f -cmin 1 -name "${ODOO_DATABASE}.*.zip" -exec md5sum '{}' \;

# hashsum copy backup varn
HASH_SECOND= find ${SAVE_BASE} -type f -cmin 1 -name "${ODOO_DATABASE}.*.zip" -exec md5sum '{}' \;

# compare and log
if [ "$HASH_FIRST" = "$HASH_SECOND" ]; then
echo "$(date +%F.%T) backup was successfully saved" >> ${LOG_DIR}/${LOG_FILE}
else
echo "$(date +%F.%T) backup was not successfully saved" >> ${LOG_DIR}/${LOG_FILE}
fi
