#!/bin/bash
# v2ray proxy in wea

# Usage
# chmod +x ./v2ray.sh && sudo ./v2ray.sh

CONFIG_FILE="/usr/local/etc/v2ray/config.json"
SERVICE_FILE="/etc/systemd/system/v2ray.service"
PORT="45535"

installV2ray() {
    rm -rf /tmp/v2ray
    mkdir -p /tmp/v2ray
    DOWNLOAD_LINK="https://github.com/v2fly/v2ray-core/releases/download/v5.12.1/v2ray-linux-64.zip"
    curl -L -H "Cache-Control: no-cache" -o /tmp/v2ray/v2ray.zip ${DOWNLOAD_LINK}
    if [ $? != 0 ];then
        echo "Download Failed"
        exit 1
    fi

    mkdir -p '/usr/local/etc/v2ray' '/var/log/v2ray'
    touch /var/log/v2ray/access.log
    touch /var/log/v2ray/error.log
    unzip /tmp/v2ray/v2ray.zip -d /tmp/v2ray
    cp /tmp/v2ray/v2ray /usr/local/bin/v2ray
    chmod +x '/usr/local/bin/v2ray' || {
    echo "V2ray installation failed"
    exit 1
    } 

    cat > $SERVICE_FILE <<-EOF
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/v2ray run -config /usr/local/etc/v2ray/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable v2ray
}

vmessConfig() {
    local uuid="$(cat '/proc/sys/kernel/random/uuid')"
    cat > $CONFIG_FILE<<-EOF
{
    "log": {
        "access": "/var/log/v2ray/access.log",
        "error": "/var/log/v2ray/error.log",
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $PORT,
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "security": "auto"
                    }
                ]
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF
}

start() {
    
    systemctl restart v2ray
    sleep 2
    port=`grep port $CONFIG_FILE| head -n 1| cut -d: -f2| tr -d \",' '`
    # grep port /usr/local/etc/v2ray/config.json | head -n 1| cut -d: -f2| tr -d \",' '
    res=`ss -nutlp| grep ${port} | grep -i v2ray`
    if [[ "$res" = "" ]]; then
        echo "v2ray failed to start, please check the log or see if the port is occupied!"
    else
        echo "v2ray started successfully"
    fi
}

stop() {
    systemctl stop v2ray
    echo "v2ray stopped successfully"
}

restart() {
    stop
    start
}

install() {
    apt install -y unzip curl
    echo "install V2ray..."
    installV2ray
    vmessConfig
    start
}

install