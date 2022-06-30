# odoo-backup-script

My backup and encryption scrip using google secret manager, copying the backup to secure storage and logging the backup execution.

# Script configuration

I used a separate configuration file for script variables to make it simple to customize.

1.Database configuration.  Used to create backup in script comand.

```
DATABASE_IP=your_database_ip                                               # -database ip or web page address
PORT=8069                                                                  # -database port
ODOO_DATABASE=db1                                                          # -database name
```
2.Backup and save dir. Used to create, copy, delete backup in script comand.

```
BACKUP_DIR=/path/to/odoo-backup/                                           # -backup directory
SAVE_BASE=/path/to/sevebase/                                               # -safe directory in which backups are copied
```
3.Log directory and log file.

```
LOG_DIR=/path/to/                                                          # -log directory
LOG_FILE=name.log                                                          # -log file
```
4.Service account and key. To activate a service account.

```
SERVICE_ACCOUNT=your_service_account@your_projectid.iam.gserviceaccount.com # -service account mail
ACCOUNT_KEY=/path/to/key.json                                               # -service account key
PROJECT_ID=your-project-id                                                  # -gcp project id (For a more accurate identification of the secrete)
```
5.Secret from secret manager. To get the database password from the secret manager.

```
SECRET_VERSION=latest                                                       # -secret version (If there are many versions, use the right one)
SECRET_ID=your_secretid                                                     # -use secret name
```
6.GPG secret from secret manager. To obtain a key for encrypting backups.

```
GPG_SECRET_VERSION=latest                                                   # -secret version (If there are many versions, use the right one)
GPG_SECRET_ID=your_gpg_secretid                                             # -use secret name
GPG_SECRET_KEY=/path/to/public.key                                          # -file for create gpg key
```
7.Time lap for function delete, copy, hashsum.

```
TIME_LAP_DEL_BD=1                                                           # -file deletion time in the backup directory
TIME_LAP_DEL_SB=1                                                           # -file deletion time in the safe directory
TIME_LAP_COPY=1                                                             # -file copy time to the sefe directory
TIME_LAP_HASH_BD=1                                                          # -to check the hash sum of the last backup in the backup directory
TIME_LAP_HASH_SB=1                                                          # -to check the hash sum of the last backup in the safe directory
```

# Gogle Cloud Secret Manager

I used the Google Secret Manager to store my database password there.

1.To use the Google Cloud Secret Manager, you need to install Google Cloud CLI. https://cloud.google.com/sdk/docs/install-sdk?hl=en_US

2.After you install the gcloud CLI, perform initial setup tasks by running: `gcloud init`.

3.Activate or create a service account.

If you already have a service account with the necessary rights, activate it: `gcloud auth activate-service-account --key-file [KEY_FILE]`
using the key that you received when you created this account in the Google Cloud Console, or create a new service account and its key t with a command line. 
For this I used the next commands:

Create a new service account:
`gcloud iam service-accounts create some-account-name --display-name="My Service Account"`

Create a key for a service account:
`gcloud iam service-accounts keys create key.json --iam-account=my-iam-account@my-project.iam.gserviceaccount.com`

You also need to set an iam policy for this account. This can be done by Google Cloud Console or with a command:
`gcloud iam service-accounts set-iam-policy my-iam-account@my-project.iam.gserviceaccount.com policy.json`

More information on this: https://cloud.google.com/sdk/gcloud/reference/iam?hl=en_US

4.Using or creating a new secret.You can use the secret created through the Google Cloud Console or create it through the command line.
For this I used the next commands:

Create a new secret named 'my-secret' with an automatic replication policy and data from a file:
`gcloud secrets create my-secret --data-file=/tmp/secret`

Now we can view the contents of our secret using the next command:
`gcloud secrets versions access latest --secret=my-secret`

More information on this: https://cloud.google.com/sdk/gcloud/reference/secrets?hl=en_US

Now we have everything we need to use the gcloud cli in the script.For the script to work correct it needs to log in as a service account and see the secret.To do this I gave the next commands to the script:
```Bash
gcloud auth activate-service-account ${SERVICE_ACCOUNT} --key-file=${ACCOUNT_KEY}

for secret in $(gcloud secrets versions access ${SECRET_VERSION} --secret=${SECRET_ID})
do
echo "$secret"
done
```
The first one authorizes the script using the variables аccount service ID and its key, the second outputs the value of the secret.

I also use the secret manager to obtain the encryption key.More details about encryption are described below.

# Encryption with gpg
I use asymmetric encryption with a public key file to encrypt backups with gpg.
it looks like this:
```Bash
gpg -e -f public-key-file encryption-file
```
But the public key file is in the secret manager, if you try to read it with `gcloud secrets versions access` we get the value, so I read the value of the secret with `gcloud secrets versions access` and put it in the file.
```Bash
echo "$(gcloud secrets versions access ${GPG_SECRET_VERSION} --project ${PROJECT_ID} --secret=${GPG_SECRET_ID})" > ${GPG_SECRET_KEY}
```
Also at the end of the script there is a command to delete this file.
```Bash
rm ${GPG_SECRET_KEY}
```
Now that we have the public key file and can encrypt the files, we write the command to encrypt the just-created backup and delete its non-encrypted version:
```Bash
find ${BACKUP_DIR} -type f -cmin ${TIME_LAP_COPY} -name "${ODOO_DATABASE}.*.zip" -exec gpg -e -f ${GPG_SECRET_KEY} '{}' \;

find ${BACKUP_DIR} -type f -cmin ${TIME_LAP_COPY} -name "${ODOO_DATABASE}.*.zip" -delete
```
# Сreate a backup

This part of the script pulls a backup of the database.
To do this, I use the curl:
```Bash
curl -X POST \
     -F "master_pwd=$SECRET" \
     -F "name=${ODOO_DATABASE}" \
     -F "backup_format=zip" \
     -o ${BACKUP_DIR}/${ODOO_DATABASE}.$(date +%F.%T).zip \
     http://${DATABASE_IP}:${PORT}/web/database/backup
```
# Deleting old backups

Using the `find` command with special keys, the script deletes old backups.
```Bash
find ${BACKUP_DIR} -type f -mtime ${TIME_LAP_DEL_BD} -name "${ODOO_DATABASE}.*.*.gpg" -delete

find ${SAVE_BASE} -type f -mtime ${TIME_LAP_DEL_SB} -name "${ODOO_DATABASE}.*.*.gpg" -delete
```

# Copying a backup to a safe storage

This part of the script copies the last backup to a safe storage.
Also using a `find`:
```Bash
find ${BACKUP_DIR} -type f -cmin ${TIME_LAP_COPY} -name "${ODOO_DATABASE}.*.*.gpg" -exec cp '{}' ${SAVE_BASE} \;
```

# Checking and comparing the hash

This part of the script checks the last backup in the backup directory and the safe directory by calculating and comparing the hash of the two files.
Also using a `find` in the variable:
```Bash
HASH_FIRST= find ${BACKUP_DIR} -type f -cmin ${TIME_LAP_HASH_BD} -name "${ODOO_DATABASE}.*.*.gpg" -exec md5sum '{}' \;

HASH_SECOND= find ${SAVE_BASE} -type f -cmin ${TIME_LAP_HASH_SB} -name "${ODOO_DATABASE}.*.*.gpg" -exec md5sum '{}' \;
```
# Logging the copying process

The last part of the script is to keep a log file in order to describe the result of copying to the safe storage.
Use the `if` operator:
```Bash
if [ "$HASH_FIRST" = "$HASH_SECOND" ]; then
echo "$(date +%F.%T) backup was successfully saved" >> ${LOG_DIR}/${LOG_FILE}
else
echo "$(date +%F.%T) backup was not successfully saved" >> ${LOG_DIR}/${LOG_FILE}
fi
```
