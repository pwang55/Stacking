#!/bin/bash

input1=$1
input2=$2


usage='

Usage:

        In script folder:
        $ ./make_list.sh [path_to_files] [cluster_name]

        In files folder:
        $ path_to_script/./make_list.sh [cluster_name]

This script creates list_1ne.txt, ....etc that can be used by individual_stack.sh. Cluster name has to be provided.

'

execute_dir=`pwd`
script_dir=$(cd `dirname $0` && pwd)


if [ -z "$input2" ]; then
	if [[ $input1 != *"/"* ]] && [[ $execute_dir != $script_dir ]]; then
		cluster_name=$1
		filepath=""
	else
		echo "$usage"
		exit 1
	fi
else
	filepath=$1
	cluster_name=$2
	if [ "${filepath: -1}" != "/" ]; then
		filepath=${filepath}/
	fi

fi



# If no argument was given at all, show docs and end the script.
if [ -z "$cluster_name" ]; then
        echo "$usage"
        exit 1
fi

files_all=$(ls ${filepath}science_*fits | grep ${cluster_name})

# If cluster name is not correct such that script can't find files, exit script
if [ "${#files_all}" == 0 ]; then
	echo "Check cluster name!"
	exit 1
fi


# Make sure every science_cluster_xxx.fits file have lowercase filenames
rename -f 'y/A-Z/a-z/' $(ls ${filepath}science_${cluster_name}*fits | grep -v wt | grep -v scamp_cal | grep -v resamp | grep -v lightstreak)



for filter in asu1 asu2 asu3 asu4; do
	for location in ne nw se sw; do
		if [ -n "$(ls ${filepath}science_${cluster_name}*fits | xargs -n 1 basename | grep ${filter} | grep ${location} | grep -v wt | grep -v scamp_cal | grep -v resamp | grep -v lightstreak)" ]; then
			ls ${filepath}science_${cluster_name}*${filter}*${location}*fits | grep -v wt | grep -v scamp_cal | grep -v resamp | grep -v lightstreak | xargs -n 1 basename> ${filepath}list_${filter: -1}${location}.txt
			echo -e "list_${filter: -1}${location}.txt:\n"
			cat ${filepath}list_${filter: -1}${location}.txt
			echo -e "\n"
		fi
		
	done
done



