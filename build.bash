#!/bin/bash
# Build shell to go from basic linux build to running web server
# Refactors - 
# split our responsibilities into seperate scripts
# Take all security info and get script into a repo
# sort out the locigals for apps
# make uptime like a 1st class app rather then specific 
# deprecarte (?) heroku stuff

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

# "Include" the other scripts
. ./build-mongo.bash
. ./build-inspector.bash
. ./build-uptime.bash
. ./build-moonraker.bash
. ./build-mongo.bash



# -------------------------------------------------
# START - functions

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


function create-app-admin
{
	cd $APP_NAME
	node data/scripts/create-app-admin.js $2 $3
}


function stop-node
{
	stop-proc $APP_NAME-server.js
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


# ----------------------------------
# MAIN!  
set-env-local

# Call the function that matches the first parameters name
${1} $@
