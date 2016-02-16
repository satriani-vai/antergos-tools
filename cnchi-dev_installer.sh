#!/usr/bin/sh
DIR="$(pwd)"
chmod +x $0
(( EUID != 0 )) && exec sudo -- "./$0" "./$@"
if [ $EUID -ne 0 ]; then
  echo "You must have a root permissions" 2>&1
  exit 1
fi

doWork() {
current_build="$(cat /etc/lsb-release | grep "DISTRIB_RELEASE=" | cut -d= -f2)"
hdd_dev=$(fdisk -l | grep 'Disk /dev/s' | awk '{print $2}' | sed -e 's/://g')
pool="$(zpool list -H | awk '{print $1}')"
reboot=0

# Check the internet connection
wget -q --tries=10 --timeout=20 --spider http://google.com
if [ $? -eq 0 ]; then
  echo "Internet connection is established..." &
  wait
else
  echo -e "You are offline!\nAn Internet connection is required.\nPlease connect to the Internet and retry."
  exit 1
fi

# Warning about losing of data
read -r -p "ATTENTION: This script will delete your data on $hdd_dev
Continue anyway? [y/n]: " response
case $response in
  [yYjJsS])
    echo "Let's go!"
	;;
  *)
    echo "Goodbye!"
    exit 0
    ;;
esac

# Check build for update
latest_build="$(wget -O- -q https://raw.githubusercontent.com/Antergos/antergos-iso/master/configs/antergos/root-image/etc/lsb-release | grep "DISTRIB_RELEASE=" | cut -d= -f2)"
if [ "$latest_build" != "$current_build" ]; then
  read -r -p "This is not a latest build!
Please download the latest build and try again, otherwise issues may occur during installation.
Continue anyway? [y/n]: " response
  case $response in
    [yYjJsS])
      echo -e "Current build: ${current_build}\nNote: Issues may occur during installation!"
      ;;
    *)
      echo "Please download the latest build here: http://build.antergos.com/browse/testing and try again."
      exit 0
      ;;
  esac
else
  echo "Current build: ${current_build}"
fi

# Destroy pool if existing
if [ ! "$(zpool list | grep 'no pools available')" ]; then
  echo "Destroy existing pools..."
  zpool destroy -f $pool
  reboot=1
else
  echo "no pools available"
fi

if [ "$(wipefs $hdd_dev)" ]; then
  echo "Wipe a flie system on \"$hdd_dev\""
  wipefs -a $hdd_dev
  reboot=1
  sleep 3
else
  echo "No file system available"
fi

if [ "$reboot" -eq 1 ]; then
  read -r -p "You must reboot, otherwise issues may occur. Performing a restart? [y/n]: " response
  case $response in
    [yYjJ])
      reboot
      ;;
    *)
      echo -e "Skip rebot...\nATTENTION: Issues may occur during installation!"
      ;;
  esac
fi

# Clone and run Cnchi
if [ -d Cnchi ]; then
  cd Cnchi
  if git checkout master &&
     git fetch origin master &&
     [ `git rev-list HEAD...origin/master --count` != 0 ] &&
     git merge origin/master
  then
    echo 'Updated!'
	./run
  else
    echo 'Not updated.'
	./run
  fi
else
  echo "Clone and run Cnchi..."
  git clone https://github.com/Antergos/Cnchi.git
  cd Cnchi
  ./run
fi
}

DATE=`date +%Y-%m-%d:%H:%M:%S`

doWork | tee -a logfile_$DATE.txt

exit 0
