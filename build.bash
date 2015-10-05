#!/bin/bash
# Build shell to go from basic linux build to running web server

# Constants
# Debug
declare -i DB_TRACE=4
declare -i DB_DEBUG=3
declare -i DB_INFO=2
declare -i DB_OFF=0
declare -i DEBUG_LEVEL=$DB_TRACE

# Locations
declare ROOT_LOC=`pwd`
declare MONGO_ROOT=durc-db
declare NODE_DEBUG=node-debug
declare DB_BACKUP=backups
declare MONGO_DATA_APP=app-data/db
declare MONGO_DATA_UPTIME=uptime-data/db
declare SOURCE_ROOT=./source
declare UPTIME_LOC=./uptime
declare MONGO_DURC_PORT=27017
declare MONGO_UPTIME_PORT=27019

# Registration Service config
declare SVC_REGISTRATION_NAME=svc-registration

# Names
declare MONGO=mongodb-osx-x86_64-3.0.3
#declare MONGO=mongodb-osx-x86_64-2.6.10

declare MONGO_DIST=$MONGO.tgz

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

	for loc in $APP_NAME $MONGO_ROOT $UPTIME_LOC $SVC_REGISTRATION_NAME $NODE_DEBUG
	do
		# If the location is set and exists remove it (avoid unexpected disappointment if location is unset
		if [ $loc ] && [ -d $loc ]
		then
			
			debug $DB_INFO "Removing $loc"
			rm -fr $loc
		fi 
	done
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
	curl https://fastdl.mongodb.org/osx/$MONGO_DIST > $MONGO_DIST 
	tar -zxvf $MONGO_DIST

	# Move to the mongo root and tidy up
	mv -n $MONGO/* .
	rmdir $MONGO

	mkdir -p $MONGO_DATA_APP
	mkdir -p $MONGO_DATA_UPTIME
	cd $ROOT_LOC

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
        	#$MONGO_ROOT/bin/mongo $DB_APP -u $DB_APP_USER -p $DB_APP_PASS \
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
		$MONGO_ROOT/bin/mongo $DB_APP -u $DB_APP_USER -p $DB_APP_PASS \
			$APP_NAME/data/scripts/create-app-content-home.js
		$MONGO_ROOT/bin/mongo $DB_APP -u $DB_APP_USER -p $DB_APP_PASS \
			$APP_NAME/data/scripts/create-app-content-events.js
		$MONGO_ROOT/bin/mongo $DB_APP -u $DB_APP_USER -p $DB_APP_PASS \
			$APP_NAME/data/scripts/create-app-content-community.js
		$MONGO_ROOT/bin/mongo $DB_APP -u $DB_APP_USER -p $DB_APP_PASS \
			$APP_NAME/data/scripts/create-app-content-vision.js
		$MONGO_ROOT/bin/mongo $DB_APP -u $DB_APP_USER -p $DB_APP_PASS \
			$APP_NAME/data/scripts/create-app-content-types.js
		$MONGO_ROOT/bin/mongo $DB_APP -u $DB_APP_USER -p $DB_APP_PASS \
			$APP_NAME/data/scripts/create-app-content-hire.js
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

	# The application mongo instance
	start-mongo $MONGO_DURC_PORT $MONGO_ROOT/$MONGO_DATA_APP mongo-durc.log
	
	# The uptime mongo instance
	start-mongo $MONGO_UPTIME_PORT $MONGO_ROOT/$MONGO_DATA_UPTIME mongo-uptime.log --setParameter authenticationMechanisms=MONGODB-CR --auth

	#ps -ef | egrep -i mongod | egrep -v egrep 
}

function start-mongo
{
	# HACK work out how manay params there are rather than assume
	# Expect $1: port $2 dbpath $3 log $4,5 (if set) any other options
	echo "Starting Mongo... $*"
	$MONGO_ROOT/bin/mongod --port $1 \
		--rest \
		--dbpath $2 $4 $5 $6 > $3 2>&1 &

}

function stop-node
{
	stop-proc $APP_NAME-server.js
}

function stop-mongo
{
	stop-proc mongod
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
	echo "... environment is local" 
	# components 
	export DB_APP=localhost:27017/durc-db
	export DB_APP_USER=durc
	export DB_APP_PASS=durc
	export DB_NAME=durc-db
	export DB_URL_APP=mongodb://$DB_APP_USER:$DB_APP_PASS@$DB_APP
	export ENV=dev
	set-env-common
}

function set-app-durc
{
	export PORT=8080
	export APP_NAME='durc'
}

function set-app-auth
{
	export PORT=8082
	export APP_NAME='auth'
}

function set-app-regi
{
	export PORT=8081
	export APP_NAME='regi'
}

function set-app-grub
{
	export PORT=8083
	export APP_NAME='grub'
}

function set-env-heroku
{
       # get the mongo URI
        export DB_URL_APP=`heroku config --app durc | \
                        grep MONGOLAB_URI | \
                        sed 's/.*mongodb:/mongodb:/'`

	# Then parse it into compoents:
	export DB_APP_USER=`echo $DB_URL_APP | \
			sed 's/mongodb:\/\///' | \
			sed 's/:.*//'`
	# Bit hacky but on heroku/mongolab the user and db name is the same

	export DB_NAME=$DB_APP_USER

	export DB_APP_PASS=`echo $DB_URL_APP | \
			sed 's/mongodb:\/\///' | \
			sed -E 's/[^:]*//' | \
			sed 's/://' | \
			sed 's/@.*//'`
	export ENV=prod
	set-env-common
}

function set-env-common
{
	export DB_APP=`echo $DB_URL_APP | sed 's/.*@//'`
	export DB_HOST=`echo $DB_APP | sed 's/:.*//'`
	export DB_PORT=`echo $DB_APP | sed 's/.*://' | sed 's/\/.*//'`

	echo "DB_URL_APP:" $DB_URL_APP
	echo "DB_NAME:" $DB_NAME
	echo "DB_APP_USER:" $DB_APP_USER
	echo "DB_APP_PASS:" $DB_APP_PASS
	echo "DB_HOST:" $DB_HOST
	echo "DB_PORT:" $DB_PORT
	
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
	cd $ROOT_LOC
	cd $APP_NAME
	# adjust the applications port si it doesn't collide with node-debug
	export PORT=8090
	../node-debug/node_modules/node-inspector/bin/node-debug.js server.js  & 	
}

function backup-mongo
{
	echo "Backing up data..."
	DATE=`date +"%Y%m%d%H%m"`
	for collection in contacts content contenttypes
	do
		$MONGO_ROOT/bin/mongoexport -h $DB_HOST:$DB_PORT -d $DB_NAME  -c $collection -u $DB_APP_USER -p $DB_APP_PASS --out $DB_BACKUP/$ENV/$DATE/$collection.json
	done

}


# main!
# Call the function that matches the first parameters name
#set-env-local
#set-env-heroku
# Check that an environemnt (local|heroku) is set 
# as is an APP to build (durc-app|svc-registration
if [ -z $APP_NAME ] || [ -z $DB_URL_APP ]
then
	echo "APP_NAME and DB_URL_APP unset, defaulting to local durc-app"
	set-env-local
	set-app-durc
fi
${1} $@
echo "Operation completed on $APP_NAME"
