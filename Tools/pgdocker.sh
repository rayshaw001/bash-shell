#/bin/bash

function start(){
mkdir /opt/data
mkdir /opt/pgsql-9.5
mkdir /tmp/pgdocker
for v in $names;
do
port=`cat /tmp/pgdocker/.port`
if [[ $port -lt 5000 ]] then
port=5399
fi
port=$[port + 1]
echo $port > /tmp/pgdocker/.port
mkdir /opt/data/$v
mkdir /opt/pgsql-9.5/$v
docker run --name postgres-$v -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres -v /opt/data/$v/:/var/lib/postgresql/data/ -v /opt/pgsql-9.5/$v/:/usr/pgsql-9.5/ -d -p $port:5432 postgres
done
echo "start All DONE."
}

function stop(){
for name in $names;
do
docker stop postgres-$name
docker rm postgres-$name
done
echo "stop All DONE."
}

function printHelp(){
echo "usage ----"
echo -e "\tstart\tstart All containers that you specified"
echo -e "\tstop\tstop All containers that you specified"
}

command=$1
shift
names=$@
case "$command" in
start) start;;
stop) stop;;
*) printHelp;;
esac
