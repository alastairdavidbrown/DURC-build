#!/bin/bash
# Build to go from basic linux build to a working node inspector  installation


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


