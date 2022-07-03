#!/bin/bash

# vars for config file
. /path/to/config_file.conf

# activate service account
gcloud auth activate-service-account ${SERVICE_ACCOUNT} --key-file=${ACCOUNT_KEY}

# access secret from gcp secret mamager
for SECRET in $(gcloud secrets versions access ${SECRET_VERSION} --secret=${SECRET_ID})
do
echo "$(date +%F.%T) secret received" >>  ${LOG_DIR}/${LOG_FILE}
done

# seve gpg secretin file from secret manager
echo "$(gcloud secrets versions access ${GPG_SECRET_VERSION} --project ${PROJECT_ID} --secret=${GPG_SECRET_ID})" > ${GPG_SECRET_KEY}

# create a backup directory
mkdir -p ${BACKUP_DIR}

# create a backup
curl -X POST \
     -F "master_pwd=$SECRET" \
     -F "name=${ODOO_DATABASE}" \
     -F "backup_format=zip" \
     -o ${BACKUP_DIR}/${ODOO_DATABASE}.$(date +%F.%T).zip \
     http://${DATABASE_IP}:${PORT}/web/database/backup
# encrypt backup and delete non-encrypt backup
find ${BACKUP_DIR} -type f -cmin ${TIME_LAP_COPY} -name "${ODOO_DATABASE}.*.zip" -exec gpg -e -f ${GPG_SECRET_KEY} '{}' \;

find ${BACKUP_DIR} -type f -cmin ${TIME_LAP_COPY} -name "${ODOO_DATABASE}.*.zip" -delete

# delete old backups
find ${BACKUP_DIR} -type f -mtime ${TIME_LAP_DEL_BD} -name "${ODOO_DATABASE}.*.*.gpg" -delete

find ${SAVE_BASE} -type f -mtime ${TIME_LAP_DEL_SB} -name "${ODOO_DATABASE}.*.*.gpg" -delete

# copy backup to save base
find ${BACKUP_DIR} -type f -cmin ${TIME_LAP_COPY} -name "${ODOO_DATABASE}.*.*.gpg" -exec cp '{}' ${SAVE_BASE} \;

# hashsum first backup varn
HASH_FIRST= find ${BACKUP_DIR} -type f -cmin ${TIME_LAP_HASH_BD} -name "${ODOO_DATABASE}.*.*.gpg" -exec md5sum '{}' \;

# hashsum copy backup varn
HASH_SECOND= find ${SAVE_BASE} -type f -cmin ${TIME_LAP_HASH_SB} -name "${ODOO_DATABASE}.*.*.gpg" -exec md5sum '{}' \;

# compare and log
if [ "$HASH_FIRST" = "$HASH_SECOND" ]; then
echo "$(date +%F.%T) backup was successfully saved" >> ${LOG_DIR}/${LOG_FILE}
find ${BACKUP_DIR} -type f -cmin ${TIME_LAP_HASH_BD} -name "${ODOO_DATABASE}.*.*.gpg" -delete
else
echo "$(date +%F.%T) backup was not successfully saved" >> ${LOG_DIR}/${LOG_FILE}
fi

# delete gpg secret file
rm ${GPG_SECRET_KEY}
