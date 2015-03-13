!/bin/sh
set -x
set -e
export DIR=${PWD#}

. $DIR/versions.sh

if [ "$OPENROV_GIT" = "" ]; then
	export OPENROV_GIT=git://github.com/OpenROV/openrov-software.git
fi
if [ "$OPENROV_BRANCH" = "" ]; then
	export OPENROV_BRANCH=master
fi
export OPENROV_PACKAGE_DIR=$DIR/work/step_03/openrov

if [ ! "$1" = "" ];
then
	STEP_03_IMAGE=$1
fi

if [ "$2" = "--local-cockpit-source" ];
then
	export LOCAL_COCKPIT_SOURCE=$3
fi

if [ "$STEP_03_IMAGE" = "" ] || [ ! -f "$STEP_03_IMAGE" ];
then
	echo "Please pass the name the Step 3 image in the environment variable STEP_03_IMAGE"
	exit 1
fi

. $DIR/lib/libtools.sh
. $DIR/lib/libmount.sh

function onerror() {
  cd $DIR
  sleep 2
  chroot_umount
  sleep 2
  chroot_umount
  unmount_image
  sleep 2
  unmount_image
  echo There was a problem with the script!
  exit 1
}

checkroot

mount_image $STEP_03_IMAGE
chroot_mount

export ROOT=${PWD#}/root


cd $ROOT/opt
rm openrov -rf
if [ "$LOCAL_COCKPIT_SOURCE" = "" ];
then
	git clone $OPENROV_GIT openrov
	cd openrov
	git pull origin
	git checkout $OPENROV_BRANCH
else
	cp -r "$LOCAL_COCKPIT_SOURCE" openrov
	cd openrov
fi
npm install --production --arch=armhf || onerror
git clean -d -x -f -e node_modules

cd src/static
npm install --production
npm run bower

cat > $ROOT/tmp/build_cockpit.sh << __EOF__
#!/bin/bash
set -x
set -e
#install nodejs
apt-get install -y nodejs npm
update-alternatives --install /usr/bin/node node /usr/bin/nodejs 10

cd /opt/openrov
npm rebuild

__EOF__

chmod +x $ROOT/tmp/build_cockpit.sh
chroot $ROOT /tmp/build_cockpit.sh

rm -rf $OPENROV_PACKAGE_DIR/opt

mkdir -p $OPENROV_PACKAGE_DIR/opt/openrov

cp -r $ROOT/opt/openrov $OPENROV_PACKAGE_DIR/opt

cd $DIR

sync
sleep 2
chroot_umount
sleep 2
chroot_umount
unmount_image
sleep 2
unmount_image


cd $DIR/work/packages/
fpm -f -m info@openrov.com -s dir -t deb -a armhf \
	-n openrov-cockpit \
	-v $COCKPIT_VERSION \
	--before-install=$DIR/steps/step_03/openrov-cockpit-beforeinstall.sh \
	--after-install=$DIR/steps/step_03/openrov-cockpit-afterinstall.sh \
	--before-remove=$DIR/steps/step_03/openrov-cockpit-beforeremove.sh \
	--description "OpenROV Cockpit and Dashboard" \
	-C $OPENROV_PACKAGE_DIR/opt/openrov .=/opt/openrov/cockpit
