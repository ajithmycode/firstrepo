#!/bin/bash

date=$(date +%Y%m%d)

hostname=$(hostname)

hostname2=$(hostname -A | cut -d "-" -f1)

#backup the db

mongodb-consistent-backup --config /root/backup_scripts/backup.yaml

/usr/bin/mongodump --host=127.0.0.1 --port=27017 --username=backup --pass='4vFwZpNEjTBG' --authenticationDatabase=admin --gzip   --oplog -j=4 --out /db_backup/${hostname2}/



#change2207
sh /root/backup_scripts/encrypt22.sh /db_backup/$hostname/latest/rs0.tar /db_backup/$hostname/latest/

#remove backup yesterday

rm -f /db_backup/$hostname/previous/*.tar.enc

#activate service account

gcloud auth activate-service-account --key-file /root/backup_scripts/dba-sa.json

#mount gcs

gcsfuse --key-file=/root/backup_scripts/dba-sa.json mongo-rbackup-bucket /backup

#Check directory available, if not create it

dirname=/backup/$hostname


if [ ! -d "$dirname" ]

then

    echo "Directory doesn't exist. Creating now"

    mkdir -p $dirname

    echo "Dir created"

else

    echo "Dir exists"

fi


#copy backup file to gcs
#temporary2207
gsutil cp /db_backup/$hostname/latest/$date.tar.enc gs://mongo-rbackup-bucket/$hostname/$date/
gsutil cp /db_backup/$hostname/latest/$date.tar.sha1 gs://mongo-rbackup-bucket/$hostname/$date/
gsutil cp /db_backup/$hostname/latest/$date.tar.key gs://mongo-rbackup-bucket/$hostname/$date/

#umount gcs

fusermount -u /backup/

file="/db_backup/$hostname/latest/$date.tar.enc"

if [ ! -f "$file" ]

then
    #cho "Failed"
    psql -U backupmon -h 172.24.54.23 -d backup_monitoring -c "insert into backup_result (dbname,description,created_at,db_type) values ('$hostname','Failed',now(),'mongo');"

else
    #cho "Success"
    psql -U backupmon -h 172.24.54.23 -d backup_monitoring -c "insert into backup_result (dbname,description,created_at,db_type) values ('$hostname','Success',now(),'mongo');"

    #remove backup not encrypted

    rm -f /db_backup/$hostname/latest/rs0.tar
#    rm -f /db_backup/$hostname/latest/$date.tar*
fi
