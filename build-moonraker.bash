#!/bin/bash
# Build to go from basic linux build to a working moonraker installation

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



