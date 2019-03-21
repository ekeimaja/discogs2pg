#!/bin/bash
#set -xv

printf "\nUpdating package list...\n"
sudo apt-get update
sudo apt-get install build-essential -y

# BEGINNING OF POSTGRES INSTALLING
sudo apt-get install curl ca-certificates -y

curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

sudo sh -c 'printf "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

sudo apt-get update

sudo apt-get install postgresql-11 pgadmin4 -y

sudo apt-get install postgresql-server-dev-11 -y
# END FOR POSTGRES INSTALL

sudo apt-get install expat libexpat1-dev -y

printf "\nPlease create a password for user postgres via psql\nCreate a new server in PgAdmin\n"

sudo -u postgres -H -- psql

read -p "Now the Haskell stack will be installed. Press ENTER to continue"

printf "\nLoading and installing Haskell stack...\n"
curl -sSL https://get.haskellstack.org/ | sh

cd $HOME

#LOADING OF DISCOGS2PG FILES

read -p "Now files of discogs2pg will be loaded, press ENTER to continue"

printf "\nLoading discogs2pg...\n"

if [ ! -d "discogs2pg" ]; then
  wget https://github.com/ekeimaja/discogs2pg/archive/master.zip
  printf "\nExtracting..."
  unzip master.zip
  rm master.zip
  mv discogs2pg-master discogs2pg
fi

cd $HOME/discogs2pg/

pwd

stack install

cp $HOME/.local/bin/discogs2pg $HOME/discogs2pg/

#LOADING OF LATEST DUMPS OF DISCOGS DATA

read -p "Next the latest dumps of Discogs will be loaded, press ENTER to continue"

USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_2) AppleWebKit/534.51.22 (KHTML, like Gecko) Version/5.1.1 Safari/534.51.22"
ACCEPT="Accept-Encoding: gzip, deflate"
D_URL_LIST="http://discogs-data.s3-us-west-2.amazonaws.com/?delimiter=/&prefix=data/"$(date +"%Y")"/"
D_URL_DIR="http://discogs-data.s3-us-west-2.amazonaws.com/data/"$(date +"%Y")"/"
D_TMP=/tmp/discogs.urls
D_PATTERN="discogs_[0-9]{8}_(artists|labels|masters|releases).xml.gz"

TEST=""
[[ "$1" == '--test' ]] && TEST='--spider -S'

echo "" > $D_TMP

for f in `wget -c --user-agent="$USER_AGENT" --header="$ACCEPT" -qO- $D_URL_LIST | grep -Eio "$D_PATTERN" | sort | uniq | tail -n 4` ; do
	echo $D_URL_DIR$f >> $D_TMP
done

wget -c --user-agent="$USER_AGENT" --header="$ACCEPT" --no-clobber --input-file=$D_TMP $TEST --progress=bar

sudo su - postgres

cd $HOME/discogs2pg/

createdb discogs_current

psql discogs_current < sql/tables.sql

./discogs2pg -g -d 20190301 -c dbname=discogs_current

psql discogs_current < sql/indexes.sql

psql discogs_current < sql/separate_countries.sql

psql discogs_current < sql/release_year.sql
