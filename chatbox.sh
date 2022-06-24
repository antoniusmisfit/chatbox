#!/data/data/com.termux/files/usr/bin/bash 
# change above to #!/usr/bin/env bash for regular Linux installations
[ -z "$channel" ] && channel="#linux"
[ -z "$server" ] && server="irc.libera.chat"
[ -z "$port" ] && port="6667" #Plain text port
[ -z "$user" ] && user="SomeUser" #IRC user name and nick
[ -z "$nick" ] && nick="$user"
TCPHANDLE="/dev/tcp/$server/$port"
logfile="$HOME/chat-$user-$channel.log"
exec 9<>"$TCPHANDLE"

#${string:start:length}

msgprint() #process client messages
{
read -r cmd ch mesg <<< "$1"

case "$cmd" in
	PRIVMSG) echo "$nick=> $mesg";;
	JOIN) echo "$nick has joined $ch.";;
	ACTION) echo "$nick $mesg";;
	PART|QUIT) echo "$nick has left $ch.";;
	*);;
esac
}

ircprint() #process server messages
{
read -r rawnick cmd ch mesg <<< "$1"

rnick=`cut -d '!' -f1 <<< "$rawnick"`

case "$cmd" in
        PRIVMSG) printf"$rnick=> $mesg\n";;
        JOIN) printf "$rnick has joined $ch.\n";;
        ACTION) echo "$rnick $mesg";;
        PART|QUIT) printf "$rnick has left $ch.\n";;
        *);;
esac
}

server_login()
{
	#login phase
	echo "USER $user 0 * :$user"
	echo "NICK $nick"
	echo "JOIN $channel"
	rm $logfile
}

irc_session ()
{
  # User input
  while read -r message; do
	read -r a args <<< "$message"
	case "$message" in
		":quit"*) echo "QUIT $args"|tee -a $logfile;break;;
		":join"*) echo "JOIN $args"|tee -a $logfile;;
		":nick"*) echo "NICK $args"|tee -a $logfile;nick="$args";;
		":msg"*) echo "PRIVMSG $a : $args"|tee -a $logfile;;
		":me"*) echo "ACTION $channel : $args"|tee -a $logfile;;
		":whois"*) echo "WHOIS $args"|tee -a $logfile;;
		":shrug"*) echo "PRIVMSG $channel :¯\_(ツ)_/¯"|tee -a $logfile;;
		*) echo "PRIVMSG $channel :$message"|tee -a $logfile;;
	esac
  done
}

irc_read()
{
  while read -ru 9 line; do
    if expr match "$line" "^PING" >/dev/null; then
      echo "PONG" >&9
    fi
    echo "$line"|tee -a $logfile  #keep a raw log of this chat session
    shopt -s checkwinsize; (:;:)
    printf "\e7\e[2J\e[999H"
    #printf "\e[2J\e[999H\e[3;%dr" "$((LINES-2))"
    tail -n 5 $logfile
    printf "\e8\n"
  done
}

finish() {
  exec 9>&-
  kill 0 > /dev/null
}

trap finish EXIT
server_login >&9
printf "\e[?1049h\e[2J\e[;r" #Switch to IRC "screen"
irc_read &
READ_PID=$!
irc_session <&1 >&9 & # Feed nc with user input
SESSION_PID=$!
wait
finish
printf "\e[2J\e[;r\e[?1049l" #Exit IRC "screen"
exit
