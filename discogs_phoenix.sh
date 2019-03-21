#!/bin/bash
#set -xv

cd $HOME

printf "\nUpdating package list and installing dependencies...\n"
sudo apt-get update
sudo apt-get install build-essential -y
sudo apt-get install curl ca-certificates -y
sudo apt-get install g++ gcc libc6-dev libffi-dev libgmp-dev make xz-utils zlib1g-dev git gnupg -y
sudo apt-get install expat libexpat1-dev -y

#######################
# POSTGRES INSTALLING #
#######################
printf "\nInstalling PostgreSQL and PgAdmin4...\n"
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
sudo apt-get update
sudo apt-get install postgresql-11 pgadmin4 -y
sudo apt-get install postgresql-server-dev-11 -y

##############################
# PASSWORD FOR POSTGRES USER #
##############################

printf "\nPlease set a password for postgres user\n"
sudo -u postgres psql --command '\password postgres'
read -p  "Create a connection to your server in PgAdmin. Press ENTER to continue"

############################
# HASKELL STACK INSTALLING #
############################

printf "\nDownloading and installing Haskell stack...\n"
curl -sSL https://get.haskellstack.org/ | sh

###################################
# DOWNLOADING OF DISCOGS2PG FILES #
###################################

if [ ! -d "discogs2pg" ]; then
	printf "\nLoading discogs2pg files...\n"
	wget https://github.com/ekeimaja/discogs2pg/archive/master.zip
	printf "\nExtracting...\n"
	unzip master.zip
	rm master.zip
	mv discogs2pg-master discogs2pg
fi

cd $HOME/discogs2pg/
echo "Compiling..."
stack install
# cp $HOME/.local/bin/discogs2pg $HOME/discogs2pg/	THIS OPERATION IS DEPENDING OF TRAVIS-FILE

###########################################
# LOADING OF LATEST DUMPS OF DISCOGS DATA #
###########################################

D_PATTERN="discogs_[0-9]{8}_(artists|labels|masters|releases).xml.gz"

if [ ! -f "$D_PATTERN" ]; then
	USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_2) AppleWebKit/534.51.22 (KHTML, like Gecko) Version/5.1.1 Safari/534.51.22"
	ACCEPT="Accept-Encoding: gzip, deflate"
	D_URL_LIST="http://discogs-data.s3-us-west-2.amazonaws.com/?delimiter=/&prefix=data/"$(date +"%Y")"/"
	D_URL_DIR="http://discogs-data.s3-us-west-2.amazonaws.com/data/"$(date +"%Y")"/"
	D_TMP=/tmp/discogs.urls

	TEST=""
	[[ "$1" == '--test' ]] && TEST='--spider -S'

	echo "" > $D_TMP

	for f in `wget -c --user-agent="$USER_AGENT" --header="$ACCEPT" -qO- $D_URL_LIST | grep -Eio "$D_PATTERN" | sort | uniq | tail -n 4` ; do
		echo $D_URL_DIR$f >> $D_TMP
	done

	wget -c --user-agent="$USER_AGENT" --header="$ACCEPT" --no-clobber --input-file=$D_TMP $TEST --progress=bar
fi

######################################
# UPLOADING OF DUMPS AND OTHER STUFF #
######################################

cd /home/$USER/discogs2pg/

sudo -u postgres createdb discogs_current
sudo -u postgres psql discogs_current < sql/tables.sql
printf "\nThis will take several hours. Go and keep a long break :)\n"
sudo -u postgres ./discogs2pg -g -d 20190301 -c dbname=discogs_current
wait
sudo -u postgres psql discogs_current < sql/indexes.sql
sudo -u postgres psql discogs_current < sql/separate_countries.sql
sudo -u postgres psql discogs_current < sql/release_year.sql

echo "DONE"
