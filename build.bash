#!/bin/bash
# Build shell to go from basic linux build to running web server
# Refactors - 
# split our responsibilities into seperate scripts
# Take all security info and get script into a repo
# sort out the locigals for apps
# make uptime like a 1st class app rather then specific 
# deprecarte (?) heroku stuff

# Constants
# Debug
declare -i DB_TRACE=4
declare -i DB_DEBUG=3
declare -i DB_INFO=2
declare -i DB_OFF=0
declare -i DEBUG_LEVEL=$DB_TRACE

# Generic logicals
declare TRUE=1
declare FALSE=0

# Locations
declare ROOT_LOC=`pwd`
declare MONGO_ROOT=mongo
declare NODE_DEBUG=node-debug
declare DB_BACKUP=backups
declare SOURCE_ROOT=./source
declare HAS_COMMON=$FALSE
declare MOONRAKER_LOC=$ROOT_LOC/moonraker



#REFACTOR uptime should be an app like grub,durc etc not a aspecial casei
declare MONGO_DATA_UPTIME=uptime-data/db
declare UPTIME_LOC=./uptime

# MongoDB distribution (bit messey to support OSX and Linux
OS=`uname | sed 's/Darwin/osx/' | sed 's/Linux/linux/'`
MONGO_DOWN_ROOT=https://fastdl.mongodb.org/
MONGO_VERSION=mongodb-$OS-x86_64-3.2.0
MONGO_DOWN_FMT=.tgz

# Chrome Driver distribution (use OS from above)
declare CHROME_DRIVER_LOC=http://chromedriver.storage.googleapis.com/2.21
if [ $OS = 'osx' ]
then
	declare CHROME_DRIVER=chromedriver_mac32.zip
elif [ $OS = 'linux' ]
then
	declare CHROME_DRIVER=chromedriver_linux64.zip
fi
declare CHROME_DRIVER_DIST=$CHROME_DRIVER_LOC/$CHROME_DRIVER

# -------------------------------------------------
# START - functions
function debug
{
	db_level_set=$1
	shift # shift off the firt parameter, the level requred so tha subsequent calls can be $*
	if [ $DEBUG_LEVEL -ge $db_level_set ]
	then
		echo $*	
	fi
}


function copy-content
{

	# copy the source to the server
	cp -r $SOURCE_ROOT/$APP_NAME/* $ROOT_LOC/$APP_NAME/.

}

function clean 
{

	# If the location is set and exists remove it 
	# avoid unexpected disappointment if location is unset
	if [ $APP_NAME ] && [ -d $APP_NAME ]
	then
		debug $DB_INFO "Removing $APP_NAME"
		rm -fr $APP_NAME
	else
		echo "APP_NAME not set or $APP_NAME doesn not exist"
	fi
}

function cycle-node
{
	stop-node
	copy-content
	start-node
}

function start-node
{
	cd $APP_NAME
	node $APP_NAME-server.js &
}

function build-common
{
	# Make the app dir and copy the package.json
	mkdir $1

	# Copy the pagkage.json to the app
	cp $SOURCE_ROOT/$1/package.json $1

	# Install the node packages
	cd $1
	npm install

}

function build-app-local
{

	# Do the build that's common  to all apps
	build-common $APP_NAME

	#make the public dir and copy the bootstrap dist
	mkdir public
	
	# if the app required bootstrap copy the distrinution
	if [ -d node_modules/bootstrap/dist ]
	then
		cp -r node_modules/bootstrap/dist public/.
	fi
}

function clean-heroku
{
	heroku apps:destroy --app durc --confirm durc

}

function build-app-heroku
{

	# create the app
	heroku apps:create durc --region eu
	# ..the mpngolab add on
	heroku addons:create mongolab --app durc

	# set it in heroku
	heroku config:set DB_URL_APP=$DB_URL_APP --app durc #set the DB_URL_APP

	# push the code 
	cd $SOURCE_ROOT/$APP_NAME
	git push heroku master 

	# create the admin user note params differ for local and heroku so 
	# #nastyhack dummy
	cd $ROOT_LOC
	create-app-admin dummy julie@durc content-admin
	create-app-admin dummy trudy@durc contact-admin
	create-app-admin dummy julie@durc secret

	# insert the content
	insert-content
	
	# Show config 
	heroku apps:info --app durc

	cd $ROOT_LOC

}

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
        	#$MONGO_ROOT/bin/mongo $DB_APP -u $MONGO_APP_USER -p $MONGO_APP_PASS \
		#	source/data/scripts/remove-app-content.js
	fi
}

function insert-content
{
	if [ $ENV = 'prod' ]
	then
		echo "WARNING DO NOT RUN IN PRODUCTION"
	else
		cd $ROOT_LOC
		$MONGO_ROOT/bin/mongo $DB_APP -u $MONGO_APP_USER -p $MONGO_APP_PASS \
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
function create-app-admin
{
	cd $APP_NAME
	node data/scripts/create-app-admin.js $2 $3
}

function install-uptime
{
	git clone git://github.com/fzaninotto/uptime.git
	cd $UPTIME_LOC
	npm install

	# Copy over the install
	echo "copying uptime config"
	cp $SOURCE_ROOT/$APP_NAME/config/defaul-uptime.yaml $UPTIME_LOC/config/default.yaml
	
}

function create-uptime-user
{

	cd $ROOT_LOC

	# Stop the mongo instance and wait for the lock to be released
	stop-proc "mongod.*27019"

	wait-for-mongo-to-stop

	# Start the mongo instance without auth
	#start-mongo $MONGO_UPTIME_PORT $MONGO_ROOT/$MONGO_DATA_UPTIME mongo-uptime.log 
	start-uptime-mongo-noauth


	# Run in the DB admin user
	$MONGO_ROOT/bin/mongo admin --port 27019 \
               source/data/scripts/create-uptime-admin.js	

	# Set the authentication method to MONGODB-CR
	./durc-db/bin/mongo admin --port 27019 ./source/data/scripts/alterAuthMethod.js 
	#$MONGO_ROOT/bin/mongo admin --port 27019 \
        #       source/data/scripts/alterAuthMethod.js

	# Run in the uptime user
	$MONGO_ROOT/bin/mongo uptime --port 27019 \
		source/data/scripts/create-uptime-user.js 

	# Stop the mongo instance
	stop-proc "mongod.*27019"

	wait-for-mongo-to-stop

	# Start the mongo instance with auth
	start-mongo $MONGO_U0PTIME_PORT $MONGO_ROOT/$MONGO_DATA_UPTIME mongo-uptime.log --setParameter authenticationMechanisms=MONGODB-CR --auth

}

function start-uptime-mongo-noauth
{
	start-mongo $MONGO_UPTIME_PORT $MONGO_ROOT/$MONGO_DATA_UPTIME mongo-uptime.log 
}

function wait-for-mongo-to-stop
{
	echo "Waiting for mongo to stop"
	pid=`cat $MONGO_ROOT/$MONGO_DATA_UPTIME/mongod.lock | awk '{print $1}'`
	while [ $pid ]
	do
		pid=`cat $MONGO_ROOT/$MONGO_DATA_UPTIME/mongod.lock | awk '{print $1}'`
	done
	echo "... stopped"
}

function start-mongo-all
{

	declare MONGO_DURC_PORT=27017
	# The application mongo instance
	start-mongo-1 $MONGO_DURC_PORT $MONGO_ROOT/$MONGO_DATA_DURC mongo-durc.log
	
	# The uptime mongo instance
	declare MONGO_UPTIME_PORT=27019
	start-mongo-1 $MONGO_UPTIME_PORT $MONGO_ROOT/$MONGO_DATA_UPTIME mongo-uptime.log --setParameter authenticationMechanisms=MONGODB-CR --auth

	#ps -ef | egrep -i mongod | egrep -v egrep 
}

function start-mongo-1
{
	# HACK work out how manay params there are rather than assume
	# Expect $1: port $2 dbpath $3 log $4,5 (if set) any other options
	echo "Starting Mongo... $*"
	$MONGO_ROOT/bin/mongod --port $1 \
		--rest \
		--dbpath $2 $4 $5 $6 > $3 2>&1 &

}

function start-mongo
{
	$MONGO_ROOT/bin/mongod --port $MONGO_PORT \
		--rest \
		--dbpath $MONGO_ROOT/$MONGO_DATA_LOC $4 $5 $6 \
		> mongo-$APP_NAME.log  2>&1 &

}

function stop-node
{
	stop-proc $APP_NAME-server.js
}

function stop-mongo
{
	stop-proc mongod
}

function stop-all
{
	stop-proc node
	stop-proc mongo
}

function stop-proc
{
	# find the  pid of the named process, excluding this script 
	# incase the name matches the requested name
	pid=`ps -ef | egrep -i $1 | egrep -v $$ | egrep -v egrep | awk '{print $2}'`
	kill -15 $pid
}

function help
{
	echo $0 "<function>"
	grep -i "^function" $0 | egrep -v "^_" | sed 's/function //' | sort
}


function set-env-local
{
	echo "... setting environment as local" 
	set-env-common
}

function set-mongo-env
{

	# components 
	export DB_APP=localhost:$MONGO_PORT/$APP_NAME
	export DB_NAME=$APP_NAME
	export DB_URL_APP=mongodb://$MONGO_APP_USER:$MONGO_APP_PASS@$DB_APP
	export ENV=dev
}

# grub locigals
declare UPTIME_LOC=./uptime
declare MONGO_UPTIME_PORT=27019

function set-app-durc
{
	export PORT=8080
	export APP_NAME='durc'
        export MONGO_APP_USER=durc
        export MONGO_APP_PASS=durc
	export MONGO_PORT=27017
	export MONGO_DATA_LOC=durc-data/db
	set-mongo-env
}

function set-app-auth
{
	export PORT=8082
	export APP_NAME='auth'
        export MONGO_APP_USER=auth
        export MONGO_APP_PASS=auth
	export MONGO_PORT=27018
	export MONGO_DATA_LOC=auth-data/db
	set-mongo-env
}

function set-app-emco
{
	export PORT=8081
	export APP_NAME='emco'
	export MONGO_APP_USER=emco
        export MONGO_APP_PASS=emco
        export MONGO_PORT=27021
        export MONGO_DATA_LOC=emco-data/db
	set-mongo-env
}


function set-app-lrma
{

	export PORT=8084
	export APP_NAME='lrma'
}

function set-app-esss
{

	export PORT=8085
	export APP_NAME='esss'
}

function set-app-grub
{
	export PORT=8083
	export APP_NAME='grub'
	export MONGO_APP_USER=grub
        export MONGO_APP_PASS=grub
        export MONGO_PORT=27020
        export MONGO_DATA_LOC=grub-data/db
	set-mongo-env
}

function set-app-common
{
	# Place holder to put configuration shared between apps
	# function must have content!
	show-config
}

function set-env-heroku
{
       # get the mongo URI
        export DB_URL_APP=`heroku config --app durc | \
                        grep MONGOLAB_URI | \
                        sed 's/.*mongodb:/mongodb:/'`

	# Then parse it into compoents:
	export MONGO_APP_USER=`echo $DB_URL_APP | \
			sed 's/mongodb:\/\///' | \
			sed 's/:.*//'`
	# Bit hacky but on heroku/mongolab the user and db name is the same

	export DB_NAME=$MONGO_APP_USER

	export MONGO_APP_PASS=`echo $DB_URL_APP | \
			sed 's/mongodb:\/\///' | \
			sed -E 's/[^:]*//' | \
			sed 's/://' | \
			sed 's/@.*//'`

#	export DB_HOST=`echo $DB_URL_APP | \
#			sed 's/.*@//' | \
#			sed 's/:.*//'
#
	export ENV=prod
	set-env-common
}

function set-env-common
{
	export MONGO_ROOT=mongo
	export DB_APP=`echo $DB_URL_APP | sed 's/.*@//'`
	export DB_HOST=`echo $DB_APP | sed 's/:.*//'`
	export DB_PORT=`echo $DB_APP | sed 's/.*://' | sed 's/\/.*//'`

	
}

function show-config
{
	for var in APP_NAME DB_URL_APP DB_NAME MONGO_APP_USER MONGO_APP_PASS DB_HOST DB_PORT
	do
		eval val=\$$var
		if [ ! -z $val ]
		then
			echo "$var $val"
		fi
	done
}

function install-uptime
{
	git clone git://github.com/fzaninotto/uptime.git	
	cd $UPTIME_LOC
	npm install

}

function install-inspector
{
	mkdir $NODE_DEBUG
	cd $NODE_DEBUG
	npm install node-debug
	#mv ./node_modules/node-debug/* .
	# node-inspector might be a dependency
	
}

function stop-debug
{
	stop-proc node-debug.js
	stop-proc node-inspector
}

function cycle-debug
{
	stop-debug	
	copy-content
	cd $APP_NAME
	# adjust the applications port so it doesn't collide with node-debug
	export PORT=8090
	# Path hack... 
	../node-debug/node_modules/node-debug/bin/node-debug.js grub_server.js  & 	
}

function clean-test-rig
{
	rm -r $ROOT_LOC/moonraker
}

function make-test-rig
{
	#install moonraker
	mkdir $MOONRAKER_LOC
	cp $SOURCE_ROOT/$APP_NAME/tests/package.json $MOONRAKER_LOC/.
	cd $MOONRAKER_LOC
	npm install

	# Get the chrome driver and put it on the path
	curl $CHROME_DRIVER_DIST > $CHROME_DRIVER
	unzip $CHROME_DRIVER
	cd $ROOT_LOC
}

function run-tests
{

	# Check moonraker installed
	if [ ! -d $MOONRAKER_LOC ]
	then
		make-test-rig
	fi
	#copy the tests to the moonraker install
	cp -r $SOURCE_ROOT/$APP_NAME/* $MOONRAKER_LOC/.
	cd $MOONRAKER_LOC
	mv ./tests/config.json .

	# Put the chrome driver on the path
	PATH=$PATH:$MOONRAKER_LOC/$CHROME_DRIVER
	node node_modules/moonraker/bin/moonraker.js 

	cd $ROOT_LOC

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

# ----------------------------------
# MAIN!  
set-env-local
#set-env-heroku

# Call the function that matches the first parameters name
${1} $@
