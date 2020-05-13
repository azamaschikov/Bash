#!/usr/bin/env bash

MYSQL_USER="root"
MYSQL_PASS="password"

OAUTH_TOKEN="token"

BACKUP_COUNT="3"
BACKUP_DIR=("/etc" "/srv" "/var/named" "/var/spool/cron")

ENCRYPT="1"
ENCRYPT_KEY="key"

TEMP_DIR="/tmp/backup"
JOURNAL_FILE="/var/log/backup.log"

TIMESTAMP=$(date '+%d-%m-%Y')

function event {
	echo "[$(date '+%a %b %d %T %Y')] - $1" >> $JOURNAL_FILE
}

function getlistbase {
	mysql -NB -u$MYSQL_USER -p$MYSQL_PASS -e "SHOW DATABASES" | egrep -v "[[:alpha:]]_schema$" | egrep -v "^mysql$"
}

function getuploadurl {
	URL="https://cloud-api.yandex.net/v1/disk/resources/upload/?path=app:/$FILE&overwrite=true"
	curl -sX GET -H "Authorization: OAuth $OAUTH_TOKEN" "$URL" | jq -r ".href"
}

function getlistbackup {
	URL="https://cloud-api.yandex.net/v1/disk/resources?path=app:/&sort=created"
	curl -sX GET -H "Authorization: OAuth $OAUTH_TOKEN" "$URL" | jq -r "._embedded.items[].name"
}

function uploadbackup {
	curl -sX PUT -T $1 $(getuploadurl)
}

function deletebackup {
	URL="https://cloud-api.yandex.net/v1/disk/resources?path=app:/$FILE&permanently=true"
	curl -sX DELETE -H "Authorization: OAuth $OAUTH_TOKEN" "$URL"
}

if [[ ! -f "$JOURNAL_FILE" ]]
	then
		touch $JOURNAL_FILE;
		event "Создан лог-файл: $JOURNAL_FILE"
fi

if [[ ! -d "$TEMP_DIR" ]]
	then
		mkdir -p $TEMP_DIR
		event "Создан временный каталог: $TEMP_DIR"
fi

for FILE in $(getlistbase)
       do
               mysqldump --single-transaction --max-allowed-packet=1073741824 $FILE > $TEMP_DIR/$TIMESTAMP.$FILE.sql
               find $TEMP_DIR -name "$TIMESTAMP.$FILE.sql" -execdir tar --remove-files --absolute-names -rf $TEMP_DIR/$TIMESTAMP.mysql.tar {} \;
               event "Снят и архивирован дамп базы данных: $FILE"
       done

gzip -f $TEMP_DIR/$TIMESTAMP.mysql.tar
       
for FILE in ${BACKUP_DIR[@]}
       do
               tar --absolute-names -rf $TEMP_DIR/$TIMESTAMP.files.tar $FILE
               event "Добавлена в архив директория: $FILE"
       done

gzip -f $TEMP_DIR/$TIMESTAMP.files.tar

if [[ $ENCRYPT == "1" ]]
	then
		for FILE in $(find $TEMP_DIR -type f)
			do
				openssl enc -aes-256-cbc -salt -in $FILE -out $FILE.enc -k $ENCRYPT_KEY
				event "Зашифрован файл: $FILE.enc"
				rm -f $FILE
			done
fi

for FILE in $(getlistbackup | grep $(date '+%d-%m-%Y' --date="$BACKUP_COUNT days ago"))
	do
		deletebackup
		event "Удаляется файл: $FILE"
	done

for FILE in $(find $TEMP_DIR -type f -printf '%f\n')
	do
		uploadbackup $(echo $TEMP_DIR/$FILE)
		event "Загружается файл: $FILE"
	done

find $TEMP_DIR -type f -exec rm -rf {} \;
event "Каталог временных файлов $TEMP_DIR очищен"
