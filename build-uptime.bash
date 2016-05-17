#!/bin/bash
# Build to go from basic linux build to a working uptime installation

#REFACTOR uptime should be an app like grub,durc etc not a aspecial casei
declare MONGO_DATA_UPTIME=uptime-data/db
declare UPTIME_LOC=./uptime
declare MONGO_UPTIME_PORT=27019

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

function install-uptime
{
        git clone git://github.com/fzaninotto/uptime.git
        cd $UPTIME_LOC
        npm install

}
