# odoo-backup-script

My backup script using google secret manager, copying the backup to a safe storage and logging the backup execution.

# Script configuration

I used a separate configuration file for script variables to make it simple to customize.

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

# curl

This part of the script pulls a backup of the database.

# Deleting old backups

Using the `find` command with special keys, the script deletes old backups.

# Copying a backup to a safe storage

This part of the script copies the last backup to a safe storage.

# Checking and comparing the hash

This part of the script checks the last backup in the backup directory and the safe directory by calculating and comparing the hash of the two files.

# Logging the copying process

The last part of the script is to keep a log file in order to describe the result of copying to the safe storage.
