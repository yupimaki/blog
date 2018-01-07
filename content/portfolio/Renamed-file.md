---
title: Avoid Netflix Geofencing
author: ~
date: '2017-02-01'
slug: ''
categories: []
tags: []
subtitle: "No longer works for Netflix :("
image: "img/portfolio/avoid-netflix-geofencing/netflix.jpg"
description: "Not actually about Netflix anymore... How to avoid geofencing!"
---

# Watch Netflix from another IP using `ssh`

_DISCLAIMER: This has been written for educational purposes of learning about routing net traffic. I am not responsible for how you use this information._

## Introduction

Avoiding geofencing can be done using a VPN. When using streaming services, however, it is often useful not to have that extra layer of encryption a VPN imposes for speed purposes.  A SOCKS5 proxy allows us to forward traffic through another machine, using only `ssh`.

This article will outline the steps to set up a `SOCKS5` proxy over `ssh` on an Amazon Web Services instance in the US. The instance will be used to forward internet traffic from a machine with a foreign IP address to the host machine. 

When I wrote this, Netflix had not yet blanket blacklisted AWS ip address, however this article is still useful for education on some networking.

When we're done here, running the command `netflix-XXX` in a terminal will launch a browser, where "what's my ip" will return a US address.

## Cost

The service can be run at zero cost providing

 - The instance set up is eligible for the AWS free tier 
 - No other machines are run on the account
 - The instance runs for less than 750 hours a month 
   - You would only exceed this with more than 1 machine
 - You are in the first year of your AWS account
   - You can simply set up another account after a year
 - The instance must always be on (counter-intuitive, I know)
   - This is because elastic IPs are free when the instance attached to them is running

## Outline

The basic steps, assuming a Linux/Mac host machine, are outlined below

 - Sign up for an AWS account and launch a Ubuntu box in the US
   - `16.04` was the LTS at the time of writing
 - Provision an elastic IP through the AWS console
 - configure the `~/.ssh/config` file
 - Add aliases to
   - Set up a background `ssh` tunnel using the proxy instance
   - Launch a browser configured to connect to the web through the proxy
   - Kill background `ssh` tunnel

You'll then be able to confirm the physical location of the IP address through "what's my IP". Note that a bug in Chrome means that to launch a Chrome session using the proxy, no other Chrome sessions can be open.

## AWS Account Set Up

AWS have servers in several different countries for several reasons, i.e., so applications can route traffic more effectively. We're going to exploit this by borrowing an IP address from a different country.

This means that any service sending web traffic to our borrowed IP address, sends it to a US address. Thus the traffic is geofenced to the US. From our home country, we can then read the data off the foreign machine, i.e., we 'forward' the traffic to the UK.

 - Sign up to AWS [here](https://aws.amazon.com/console/)
 - Follow the wizard to launch a free EC2 instance in some [US] region
 - Set up an elastic IP address through the AWS console (Just a couple of clicks)
 - Associate the instance we just set up with it (a few more clicks)

AWS is fairly generous with marking out exactly which options are free. Now, if you're familiar with `ssh` keys, feel free to continue on to the next section

### `SSH` keys

 - Generate a `.pem` key to set the instance up with and download it
 - Generate an ssh keypair on your host
   - If you alreadu have a keypair, feel free to use these
   - A short guide to do this for the first time is [here](http://www.linuxproblem.org/art_9.html)
   - TL;DR, you'll have a public and private key.  The public key can safely go anywhere, but keep your private key safe as safe as you would your ID!
 - `ssh` into the AWS instance 
   - The `ssh` command syntax is `ssh -i /path/to/pem user@host`
   - `host` refers to the public IP address of the machine. This is found by clicking the instance in the AWS console and finding 'Public IP' in the details
   - The default amazon `user` is `ubuntu`
   - Hence an example command is `ssh -i ~/Downloads/key.pem ubuntu@54.192.170.23`
 - Place your generated public key in `~/.ssh/authorized_keys` on the instance 
 - Using an authorized key skips manually routing to the `.pem` to login, which is minorly more convienient to me.

## On the Host (assuming a Ubuntu host)

We add an `ssh` alias for ease of using `ssh`. Instead of the lengthy command that
was necessary previously, after adding an alias, we can log on to our remote
machine through `ssh` simply by typing `ssh <alias>`.  Aliases are added by
adding new hosts (and configuring them) to the `~/.ssh/config` file. Copy and paste
the below block into the host terminal, with the URL you chose for your remote
machine through the DDNS.

```
# Add an ssh alias on host
# XXX should be a country code of the jumpbox's location
# The public IP address should be in the form xx.xx.xxx.xxx or similar
cat <<EOF>> ~/.ssh/config
Host XXX-Jumpbox
  Hostname public-ip-address
  User ubuntu
  IdentityFile /path/to/public/key 
EOF
```

This will set up an `ssh` alias such that `ssh XXX-Jumpbox` is all that is needed to open an `ssh` pipe to the jumpbox. The alias will also work with tab completion.

## Final Aliases on Host

_NOTE: If your host machine isn't running linux, 1) wot r u doin, 2) please
refer to the link in the references to crack these last steps on other OSes_

We now need a way to set up our `ssh` tunnel to the proxy server, and launch a browser which is configured to connect to the web through the proxy server.

I added some functions to my `~/.bashrc` file to achieve this.  

```
# Kill a process running on a port by name
port-kill () {
   # Find offending process's port
   {
      # Truthy hack to handle error if no process with that name is found
      ps -C $1 -o pid= &> /dev/null && port=$(ps -C $1 -o pid=)
   } || {
      echo "No process found with name $1"
      return
   }

   # Get process name by port ID
   process_name=$(ps -p ${port} -o comm=)

   # Option to kill found process
   read -r -p "Are you sure you want to kill ${process_name}? [y/N] " response
   response=${response,,}    # tolower
   if [[ $response =~ ^(yes|y)$ ]]
   then
      kill ${port}
   fi
}

# Access the web via a proxy server
#
# Must not have a google-chrome session open.
# Seems to be a bug in chrome that you can't force start with a new session

alias netflix-XXX="ssh -D 1089 -f -C -q -N XXX-Jumpbox && google-chrome --proxy-server='socks5://localhost:1089'"
```

Breaking down the final aliases, `netflix-XXX` is composed of two statements.

```
ssh -D 1089 -f -C -q -N XXX-Jumpbox
```

We already know what `ssh US-Jumpbox` does. Explaining the other flags;
 - `-D 1089` sets up [D]ynamic port forwarding on the local port `1089` through
 `ssh`
 - `-f` [f]orks the process and runs it in the background
 - `-C` [C]ompresses the data before sending it through the `ssh` pipe
 - `-q` sends all `STDOUT` and `STDERR` messages to `/dev/null`, i.e. it is
 [q]uiet

The final command is

```
google-chrome --proxy-server='socks5://localhost:1089'"
```

This command simply starts google chrome, however specifies that it connects to the web through a proxy server.  We specify the `SOCKS5` endpoint as `localhost` at port `1089`, which we know is dynamically routing our web traffic through some other country.

Now all you have to do to is to run the command `XXX-netflix` in the terminal to launch a web browser, geofenced to another country. When done, tear down the tunnel using `port-kill ssh`, or simply leave it running.

Thanks for reading,

Akhil

## Note

Unfortunately there seems to be a small bug in `google-chrome`, where you cannot force the browser to run in a new session, so for the routing to work, `chrome` cannot already be open. To get around this, use one browser reading traffic through the proxy, and other for general surfing.

## References
- Route traffic using SOCKS tunnel https://www.digitalocean.com/community/tutorials/how-to-route-web-traffic-securely-without-a-vpn-using-a-socks-tunnel