#!/bin/bash
# Build to go from basic linux build to a working mongo installation


# MongoDB distribution (bit messey to support OSX and Linux
OS=`uname | sed 's/Darwin/osx/' | sed 's/Linux/linux/'`
MONGO_DOWN_ROOT=https://fastdl.mongodb.org/
MONGO_VERSION=mongodb-$OS-x86_64-3.2.0
MONGO_DOWN_FMT=.tgz

function install-mongo-local
{
	# Make the location
	mkdir $MONGO_ROOT
	cd $MONGO_ROOT

	# Download the distribution and untar it
	curl $MONGO_DOWN_ROOT$OS/$MONGO_VERSION$MONGO_DOWN_FMT > $MONGO_VERSION$MONGO_DOWN_FMT
	tar -zxvf $MONGO_VERSION$MONGO_DOWN_FMT

	# Move to the mongo root and tidy up
	mv -n $MONGO_VERSION/* .
	rmdir $MONGO_VERSION

	cd $ROOT_LOC

}

function create-mongo-db
{
	cd $MONGO_ROOT
	mkdir -p $MONGO_DATA_LOC
}


function create-app-user
{

	cd $ROOT_LOC
	$MONGO_ROOT/bin/mongo $DB_APP $SOURCE_ROOT/$APP_NAME/data/scripts/create-app-user.js
}

function remove-content
{

	if [ $ENV = 'prod' ]
	then
		echo "WARNING DO NOT RUN IN PRODUCTION"
	else
		cd $ROOT_LOC
		$MONGO_ROOT/bin/mongo $DB_APP 	-u $MONGO_APP_USER -\
						p $MONGO_APP_PASS \
		   source/data/scripts/remove-app-content.js
	fi
}

function insert-content
{
	if [ $ENV = 'prod' ]
	then
		echo "WARNING DO NOT RUN IN PRODUCTION"
	else
		cd $ROOT_LOC
		$MONGO_ROOT/bin/mongo $DB_APP -u $MONGO_APP_USER \
						-p $MONGO_APP_PASS \
			source/$APP_NAME/data/scripts/create-app-content-home.js
				$MONGO_ROOT/bin/mongo $DB_APP -u $MONGO_APP_USER -p $MONGO_APP_PASS \
						source/$APP_NAME/data/scripts/create-app-content-events.js
				$MONGO_ROOT/bin/mongo $DB_APP -u $MONGO_APP_USER -p $MONGO_APP_PASS \
						source/$APP_NAME/data/scripts/create-app-content-community.js
				$MONGO_ROOT/bin/mongo $DB_APP -u $MONGO_APP_USER -p $MONGO_APP_PASS \
						source/$APP_NAME/data/scripts/create-app-content-vision.js
				$MONGO_ROOT/bin/mongo $DB_APP -u $MONGO_APP_USER -p $MONGO_APP_PASS \
						source/$APP_NAME/data/scripts/create-app-content-types.js
				$MONGO_ROOT/bin/mongo $DB_APP -u $MONGO_APP_USER -p $MONGO_APP_PASS \
						source/$APP_NAME/data/scripts/create-app-content-hire.js
		fi

}


function start-mongo
{
	$MONGO_ROOT/bin/mongod --port $MONGO_PORT \
			--rest \
			--dbpath $MONGO_ROOT/$MONGO_DATA_LOC $4 $5 $6 \
			> mongo-$APP_NAME.log  2>&1 &

}

function stop-mongo
{
	stop-proc mongod
}

function backup-mongo
{
	echo "Backing up data..."
	DATE=`date +"%Y%m%d%H%m"`
	for collection in contacts content contenttypes
	do	  
			$MONGO_ROOT/bin/mongoexport -h $DB_HOST:$DB_PORT -d $DB_NAME  -c $collection -u $MONGO_APP_USER -p $MONGO_APP_PASS --out $DB_BACKUP/$ENV/$DATE/$collection.json
	done
		
}

