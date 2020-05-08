#!/usr/bin/env bash

KEY="$1";

NIC="$2";
RATE="$3";
HOST="$4";

function help {
        echo;
        echo "Shaper - it's small and simple wrapper for utility tc (traffic control)";
        echo;
        echo "Usage:";
        echo "  $0 [option]";
        echo "  $0 [option] [network interface]";
        echo "  $0 [option] [network interface] [rate limit in Kbit/s] [IP-address of remote host]";
        echo;
        echo "Example:";
        echo "  $0 --help";
        echo "  $0 --flush eth0";
        echo "  $0 --status eth0";
        echo "  $0 --append eth0 3000 192.168.0.1";
        echo;
        echo "Options:";
        echo "  --help - print this message and exit";
        echo "  --flush - flsuh all limits for interface";
        echo "  --status - show status about limits for interface";
        echo "  --append - specify name of NIC, rate limit and IP-address of remote host";
        echo;
}

function flush {
        tc qdisc del dev "$NIC" root;
}

function status {
        tc class show dev "$NIC";
}

function append {
        tc qdisc add dev "$NIC" root handle 1: htb;
        tc class add dev "$NIC" parent 1: classid 1:1 htb rate "$RATE"kbit;
        tc class add dev "$NIC" parent 1: classid 1:2 htb rate "$RATE"kbit;
        tc filter add dev "$NIC" protocol ip parent 1:0 prio 1 u32 match ip dst "$HOST"/32 flowid 1:1;
        tc filter add dev "$NIC" protocol ip parent 1:0 prio 1 u32 match ip src "$HOST"/32 flowid 1:2;
}

case $KEY in
        --help) help;;
        --flush) flush;;
        --status) status;;
        --append) append;;
        *) help;;
esac
