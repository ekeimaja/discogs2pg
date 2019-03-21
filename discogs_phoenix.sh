#!/bin/bash
#set -xv

##########################################################
# NOTE: This is pre-alpha version, so use with care!
#       Fixes and other improvements are welcome
##########################################################

cd $HOME

printf "\nUpdating package list...\n"
sudo apt-get update
sudo apt-get install build-essential -y
sudo apt-get install curl ca-certificates -y

####################################
# BEGINNING OF POSTGRES INSTALLING #
####################################

curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

sudo sh -c 'printf "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

sudo apt-get update

sudo apt-get install postgresql-11 pgadmin4 -y

sudo apt-get install postgresql-server-dev-11 -y

###########################
# END OF POSTGRES INSTALL #
###########################

sudo apt-get install expat libexpat1-dev -y

printf "\nPlease set a password for user postgres"

sudo -u postgres psql --command '\password postgres'

read -p  "Create now connection to server in PgAdmin. Press ENTER to continue"

printf "\nDownloading and installing Haskell stack...\n"
curl -sSL https://get.haskellstack.org/ | sh

###################################
# DOWNLOADING OF DISCOGS2PG FILES #
###################################

echo

read -p "Now the files of discogs2pg will be downloaded, press ENTER to continue"

printf "\nLoading discogs2pg...\n"

if [ ! -d "discogs2pg" ]; then
  wget https://github.com/ekeimaja/discogs2pg/archive/master.zip
printf "\nExtracting...\n"
  unzip master.zip
  rm master.zip
  mv discogs2pg-master discogs2pg
fi

cd $HOME/discogs2pg/

stack install

cp $HOME/.local/bin/discogs2pg $HOME/discogs2pg/

###########################################
# LOADING OF LATEST DUMPS OF DISCOGS DATA #
###########################################

read -p "The latest XML dumps of Discogs will be loaded, press ENTER to continue"

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

######################################
# UPLOADING OF DUMPS AND OTHER STUFF #
######################################

cd /home/$USER/discogs2pg/

sudo -u postgres createdb discogs_current
sudo -u postgres psql discogs_current < sql/tables.sql
sudo -u postgres ./discogs2pg -g -d 20190301 -c dbname=discogs_current
sudo -u postgrespsql discogs_current < sql/indexes.sql
sudo -u postgres psql discogs_current < sql/separate_countries.sql
sudo -u postgres psql discogs_current < sql/release_year.sql

exit
