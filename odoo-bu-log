#!/bin/bash

# vars
BACKUP_DIR=/your/dir/
SAVE_BASE=/your/dir1/
ODOO_DATABASE=db1
ADMIN_PASSWORD=your_admin_passwd
LOG_DIR=/var/log/
LOG_FILE=odoo-backup-sb.log

# create a backup directory
mkdir -p ${BACKUP_DIR}

# create a backup
curl -X POST \
     -F "master_pwd=${ADMIN_PASSWORD}" \
     -F "name=${ODOO_DATABASE}" \
     -F "backup_format=zip" \
     -o ${BACKUP_DIR}/${ODOO_DATABASE}.$(date +%F.%T).zip \
     http://localhost:8069/web/database/backup

# delete old backups
find ${BACKUP_DIR} -type f -mtime 1 -name "${ODOO_DATABASE}.*.zip" -delete

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
