#!/bin/bash -e

install-package wget

cd /tmp

gpg --keyserver hkps://keys.openpgp.org --recv-keys 41539BBD4020945DB378F98B2DF45277AEF09A2F

wget --no-cache -q -O box.phar "https://github.com/box-project/box/releases/download/4.7.0/box.phar"
wget --no-cache -q -O box.phar.asc "https://github.com/box-project/box/releases/download/4.7.0/box.phar.asc"

gpg --verify box.phar.asc box.phar

rm box.phar.asc
chmod +x box.phar
mv box.phar /usr/local/bin/box
