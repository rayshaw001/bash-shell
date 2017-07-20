#!/bin/bash					#specific sh version ,default is dash
OLD_BUILD_ID=$BUILD_ID				#BUILD_id
echo $BUILD_ID
BUILD_ID=dontKillMe
sudo su
cd /opt/suitectl
echo "#!/bin/bash" > build.sh			#specify which type sh to use
svs=($services)					#services is an array
tags=($serviceImageTags)
locations=($serviceImageLocations)
svs_length=${#svs[@]}				#this and below is length
tags_length=${#tags[@]}		
locations_length=${#locations[@]}
while (( $tags_length < $svs_length ))		#fill versions
do
sn=${svs[$tags_length]}    			#service name
tags[$tags_length]=`./suitectl list | grep -w $sn | awk -v sn=$sn '{if($1==sn){print $2}}'`
tags_length=$tags_length+1
done
while (( $locations_length < $svs_length ))	#fill urls : where to get image
do
locations[$locations_length]=$installerImgLocation
locations_length=$locations_length+1
done
echo ${stage} >> /opt/suitectl/tmp.log
echo ${installertag} >> /opt/suitectl/tmp.log
echo "./suitectl deploy -c ${revert} ${env} -i ${installerImgLocation} -t ${installertag} -s \"${services}\" -r \"${locations[*]}\" --controllerimgtags \"${tags[*]}\"" >> build.sh
chmod +x build.sh
cat build.sh
./build.sh
echo $BUILD_ID >> /opt/suitectl/tmp.log
BUILD_ID=$OLD_BUILD_ID
echo $BUILD_ID >> /opt/suitectl/tmp.log
