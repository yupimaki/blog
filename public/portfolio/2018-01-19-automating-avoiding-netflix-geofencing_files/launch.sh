#!/bin/bash

# Open a chrome browser using a proxy server as the internet connection and background the process
# Open an active ssh tunnel with dyanamic port forwarding such that it is easy to kill

msg() {
    printf "\033[1;32m :: %s\n\033[0m" "$1"
}

msg "Opening active SSH tunnel and launching browser"
(google-chrome --proxy-server='socks5://localhost:1089' &) && ssh -D 1089 -C -N ubuntu@`cat ip_address`
