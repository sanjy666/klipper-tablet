#!/bin/bash

CONFIG_PATH="$HOME/config"
GCODE_PATH="$HOME/gcode"

KLIPPER_REPO="https://github.com/KevinOConnor/klipper.git"
KLIPPER_PATH="$HOME/klipper"
KLIPPY_VENV_PATH="$HOME/venv/klippy"

MOONRAKER_REPO="https://github.com/Arksine/moonraker"
MOONRAKER_PATH="$HOME/moonraker"
MOONRAKER_VENV_PATH="$HOME/venv/moonraker"

CLIENT="fluidd"

apk add git unzip python2 python2-dev libffi-dev make\
gcc g++ ncurses-dev avrdude gcc-avr binutils-avr \
avr-libc python3 py3-virtualenv python3-dev \
freetype-dev fribidi-dev harfbuzz-dev jpeg-dev \
lcms2-dev openjpeg-dev tcl-dev tiff-dev tk-dev zlib-dev \
jq path curl caddy

case $CLIENT in
  fluidd)
    CLIENT_PATH="$HOME/fluidd"
    CLIENT_RELEASE_URL=`curl -s https://api.github.com/repos/cadriel/fluidd/releases | jq -r ".[0].assets[0].browser_download_url"`
    ;;
  mainsail)
    CLIENT_PATH="$HOME/mainsail"
    CLIENT_RELEASE_URL=`curl -s https://api.github.com/repos/meteyou/mainsail/releases | jq -r ".[0].assets[0].browser_download_url"`
    ;;
  *)
    echo "Unknown client $CLIENT (choose fluidd or mainsail)"
    exit 2
    ;;
esac

mkdir -p $CONFIG_PATH $GCODE_PATH

test -d $KLIPPER_PATH || git clone $KLIPPER_REPO $KLIPPER_PATH
test -d $KLIPPY_VENV_PATH || virtualenv -p python2 $KLIPPY_VENV_PATH
$KLIPPY_VENV_PATH/bin/python -m pip install --upgrade pip
$KLIPPY_VENV_PATH/bin/pip install -r $KLIPPER_PATH/scripts/klippy-requirements.txt

echo "$KLIPPER_PATH/klippy/klippy.py $CONFIG_PATH/printer.cfg -l /tmp/klippy.log -a /tmp/klippy_uds &" > /etc/rc.local

test -d $MOONRAKER_PATH || git clone $MOONRAKER_REPO $MOONRAKER_PATH
test -d $MOONRAKER_VENV_PATH || virtualenv -p python3 $MOONRAKER_VENV_PATH
$MOONRAKER_VENV_PATH/bin/python -m pip install --upgrade pip
$MOONRAKER_VENV_PATH/bin/pip install -r $MOONRAKER_PATH/scripts/moonraker-requirements.txt

echo "$MOONRAKER_VENV_PATH/bin/python $MOONRAKER_PATH/moonraker/moonraker.py &" >> /etc/rc.local

cat > $HOME/moonraker.conf <<EOF
[server]
host: 0.0.0.0
config_path: $CONFIG_PATH

[authorization]
enabled: false
trusted_clients:
    192.168.1.0/24
    127.0.0.1
EOF


tee /etc/caddy/Caddyfile <<EOF
:80

encode gzip

root * $CLIENT_PATH

@moonraker {
  path /server/* /websocket /printer/* /access/* /api/* /machine/*
}

route @moonraker {
  reverse_proxy localhost:7125
}

route /webcam {
  reverse_proxy localhost:8081
}

route {
  try_files {path} {path}/ /index.html
  file_server
}
EOF

test -d $CLIENT_PATH && rm -rf $CLIENT_PATH
mkdir -p $CLIENT_PATH
(cd $CLIENT_PATH && wget -q -O $CLIENT.zip $CLIENT_RELEASE_URL && unzip $CLIENT.zip && rm $CLIENT.zip)

echo "caddy &" >> /etc/rc.local

chmod +x /etc/rc.local

