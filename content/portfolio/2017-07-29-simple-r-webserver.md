---
title: Simple R Webserver
author: ~
date: '2017-07-29'
slug: simple-r-webserver
categories: []
tags: []
subtitle: "#nonewfriends"
image: "img/portfolio/simpleRWebserver/porter.jpg"
description: "He's a portR, okay."
---

After having deployed a few websites with Nginx and understanding how to use it
fairly well, I thought it might be useful to ask a question to my colleague
Vergil which he found pretty funny.

> 'So... what actually is a webserver?'

I've found with a few programs with especially clean interfaces (such as git), I
end up being able to use a program effectively without understanding it, so I
can mindlessly follow instructures and proceedures I've done before, but I can't
create anything.  Nginx was particularly funny to me, because I had no idea what
a webserver actually did.

After spending about 2 hours of Vergil's time trying to work out what a
webserver, socket, connection and other networking definitions actually were
(and him prematurely breaking out wireshark) I thought I'd just try and hook
together something super simple.

Turns out the whole endevour is way too easy in python.  The `socket` library is
absurdly elegant (Ruslan Spivak goes to town on this topic [here](https://ruslanspivak.com/lsbaws-part1/) in a fantastic series) and I
imagine `rstudio/httpuv` offers similar functionality.  I thought I'd keep it
simple and only use `base::socketConnection` for the whole thing.    

Before I start, some definitions I don't want to forget:

 - **Port** - A virtual identifier defining an endpoint (to a service)
 - **Endpoint** - A location by which a service interacts, such as a
 `host`:`port` combination
 - **Socket** - An endpoint instance in the context of a (TCP) connection,
 defined by a host and port
 - **Connection** - Identified by a socket pair (two endpoints)

The above have all been taken from this stackoverflow [answer](https://stackoverflow.com/questions/152457/what-is-the-difference-between-a-port-and-a-socket).

## Simple server

First we'll look at the main new function which seems to encapsulate any and all
confusing functionality.

### `socketConnection`

Start by defining a short script which sets up a listener.  

```
while (TRUE) {

  print('Open TCP listener')

  # Annoyingly named as this doesn't seem to set up a _connection_
  con = socketConnection(
    host = 'localhost',
    port = 8888,
    blocking = TRUE,
    server = TRUE,  # The socket is defined as the server
    open = 'r+'
  )
}

```

This causes me endless confusion as the function name implies that the socket is
somehow the connection which seems to be bollocks. We can confirm this by using
`netstat`.

```
akhil@Sleek:~/example/rserver$ Rscript socketConnection.R &
[1] 13629
[1] "Open TCP listener"

akhil@Sleek:~/example/rserver$ netstat -ant
Active Internet connections (servers and established)
Proto Recv-Q Send-Q Local Address           Foreign Address         State         
tcp        0      0 0.0.0.0:8888            0.0.0.0:*               LISTEN     
tcp        0      0 192.168.1.122:41528     198.252.206.25:443      ESTABLISHED
```

We can see that a listening endpoint has been set up, accepting incoming
connections from anywhere on the host machine.  This is in contrast to the
connection below it which has been established between a local and remote
socket.

### Communication via telnet

So let's edit our simple script such that it will read in a single line of
incoming data and hand a modified response back to the client.

```
host = 'localhost'
port = 6011

while (TRUE) {

  writeLines(paste('Listening on port', port))
  con = socketConnection(
    host = host,
    port = port,
    blocking = TRUE,
    server = TRUE,  # The socket is defined as the server
    open = 'r+'
  )

  # Read the data sent to the connection
  data = readLines(con, n = 1L)

  print(paste('Read', data))

  response <- toupper(data)
  writeLines(response, con)

  close(con)

}
```

Connecting to this via a browser doesn't seem to yield much, probably because
there is no `HTTP` header in the response, as bluntly pointed out by
`ERR_INVALID_HTTP_RESPONSE`.  Our listening socket still manages to print the
read in data though.

```
akhil@Sleek:~/example/rserver/git ((telnet))$ Rscript server.R
Serving HTTP on port 6011
[1] "Read GET / HTTP/1.1"
```

The browser request pushes through a `GET` request to the listening socket,
over the protocol which is `HTTP/1.1`.  Something like nginx might know how to
route requests to the URI ('/' in this case).  Given the response we send back
does not have a valid `HTTP` header, the browser simply reports an error.

```
akhil@Sleek:~/example/rserver $ telnet localhost 6011
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
Hello!
HELLO!
Connection closed by foreign host.
```

Telnet makes it easier to see that our operation to modify the data was
successful as it doesn't care about the protocol. It's just reading and handing
over bytes in a connection.

### Communication via a defined client
It's pretty annoying we can only send a single message and we don't know why
we're doing that though. We can define a short client program to sort these
issues out and clean things up a bit for our end user.  

Importantly, I found it made me feel like a real `vim` programmer at this point
to use `byobu`, have my client and server terminals open in a the lower
quadrants to the terminal, and split screen `vim` to have both scripts open
above them. Editing my `server.R` and defining a new `client.R`.

__server.R__
```
host = 'localhost'
port = 6011

while (TRUE) {

  writeLines(paste('Serving HTTP on port', port))
  con = socketConnection(
    host = host,
    port = port,
    blocking = TRUE,
    server = TRUE,
    open = 'r+'
  )

  # Read the data sent to the connection
  data = readLines(con, 1)

  print(paste('Read', data))

  response <- toupper(data)

  # Optional sleep here

  writeLines(response, con)
  print(paste('Imma send', response, 'back'))

  close(con)

}
```

__client.R__
```
host = 'localhost'
port = 6011

writeLines('Upper casing program')

while (TRUE) {

  con = socketConnection(
    host = host,
    port = port,
    blocking = TRUE,
    server = FALSE,  # Because client
    open = 'r+'
  )

  # Define an input method
  f = file("stdin")

  open(f)  # Open the file
  cat("Enter text to upper case\n")
  read_input = readLines(f, n = 1L)  # Read an input line

  # Define a way to exit the client
  if (tolower(read_input) == "q") break

  # Write the client data to the server
  writeLines(read_input, con)

  # The response should be served pretty quickly
  server_resp = readLines(con, n = 1L)

  print(server_resp)

  close(con)

}
```

From the simple couple of scripts above we get a connection that can pass,
modify and return data.  This is admittedly _far_ nicer to look at in python.
Our program so far, starting the client (with the server running ofc)

```
akhil@Sleek:~/example/rserver/ $ Rscript client.R
Upper casing program
Enter text to upper case
Please upper case me :(
```

In the server we see
```
Serving HTTP on port 6011
[1] "Read Please upper case me :("
[1] "Imma send PLEASE UPPER CASE ME :( back"
```

And the client recieves
```
│[1] "PLEASE UPPER CASE ME :("
```
where an optional sleep can be added to make expicit the order of events.

## Simple HTTP server

To be continued...
