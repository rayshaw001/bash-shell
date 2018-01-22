#! /usr/bin/bash
function remoteCmd(){
        sshpass -p $passwd ssh $uname@$node -- $cmd
        echo "remote command: sshpass -p $passwd ssh $uname@$node -- $cmd complete"
}
if [ $# > 3 ]; then
node=$1
uname=$2
passwd=$3
cmd=$4
remoteCmd $node $uname $passwd $cmd
else
echo -e 'missing one or more of following argument(s):' \
        '\n node        ------  hostname or ip'  \
        '\n uname       ------  username '  \
        '\n passwd      ------  password '  \
        '\n cmd         ------  command that you want to run on remote host\n';
fi


# pre Requirements：
# ssh & sshpass
