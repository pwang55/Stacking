#!/bin/bash

list_in=$1
path0=$2

# TRUE for running SCAMP, FALSE for skipping SCAMP
SCAMP_REDO=TRUE
# TRUE for running stacking, FALSE for just running sextractor and scamp but don't stack yet (useful if scamp is problematic)
DO_STACKING=TRUE

POS_MERR_AHEAD=5.0
POS_MERR=10.0
POS_MERR2=5.0
POS_MERR3=3.0
SCAMP_CATALOG_AHEAD=ALLWISE
SCAMP_CATALOG=ALLWISE
combine_type=WEIGHTED


script_dir=$(cd `dirname $0` && pwd)
execute_dir=`pwd`


usage='

Usage:

	In script folder:
	$ ./individual_stack.sh path_to_files/list_1ne.txt

	In script folder running for loop, path_to_file needs to be provided
	$ for files in `cat path_to_file/listoflist.txt`; do
	> ./individual_stack.sh $files [path_to_file]
	> done

	In files folder:
	$ path_to_script/./individual_stack.sh list_1ne.txt

This script stack files listed in the input list (ex: list_1ne.txt).

IMPORTANT:
Sometime SCAMP goes crazy and cannot find astrometry solution, and will expand the image so large that the disk would be
full if SWarp is executed. In that case, disable SWarp, tweak SCAMP setting until it produces good .head files, then
set SCAMP_REDO=FALSE and DO_STACKING=TRUE to finish stacking.


'

# If no argument was given at all, show docs and end the script.
if [ -z "$list_in" ] && [ -z "$path0" ]
then
        echo "$usage"
        exit 1
fi

# Get the absolute directory path of this script so that it can find extra/files
script_dir=$(cd `dirname $0` && pwd)

# If argument 2 is provided and doesn't end with /, add it; otherwise just use it as path
# If argument 2 is not given, path would just be empty
if [ -n "$path0" ] && [ "${path0: -1}" != "/" ]; then
        path=$path0/
else
        path=$path0
fi
# If argument 1 is a full path to the list.txt, ignore 2nd argument and split listname from path
len_file=`echo $list_in | awk '{n=split($1,a,"/"); print n}'`
if (( $len_file > 1 )); then
	list_in0=$list_in
	all_len=${#list_in0}
	list_in=`echo $list_in0 | awk '{n=split($1,a,"/"); print a[n]}'`
	list_len=${#list_in}
	path_len=`echo "$(($all_len-$list_len))"`
	path=`echo ${list_in0:0:$path_len}`
fi


# If path/file doesn't exist and path is not given, end the script
if [ ! -e $path$list_in ] && [ -z $path0 ] && (( $len_file == 1 )); then
        echo -e "File: \t $file \t can't be found, path argument may be needed, or filename is incorrect. Script end."
        exit 1
# If path/file doesn't exist and path is given, filename or path might be incorrect, end the script
elif [ ! -e $path$list_in ]; then
        echo -e "File: \t $path$list_in \t can't be found, check the file name or path, Script end."
        exit 1
fi




##################################

# Create a directory for cats for scamp created by sextractor
if [ ! -d ${path}cats_for_scamp ]; then
	mkdir ${path}cats_for_scamp
fi
# Create a directory for scamp logs
if [ ! -d ${path}scamp_logs ]; then
	mkdir ${path}scamp_logs
fi
# Create a directory for stacked results
if [ ! -d ${path}stacked_results ]; then
	mkdir ${path}stacked_results
fi



# Get some names useful for later
filter_location=`echo $list_in | awk '{print substr($1,6,3)}'`
firstfilename=`head -1 ${path}$list_in`
firstfilebase=`echo $firstfilename | sed -e 's/\.fits//g'`
cluster_name=`echo $firstfilebase | awk '{split($1,a,"_"); print a[2]}'`         # Get cluster name
filter_num=`echo $filter_location | awk '{print substr($1,1,1)}'`       	# Number of filter: 1, 2, 3, 4
location=`echo $filter_location | awk '{print substr($1,2,2)}'`         	# ne, nw, se, sw



# Clear or create the list containing for_scamp.cat everytime this script is being re-run
:>${path}cats_for_scamp/${cluster_name}_${filter_location}_cats_for_scamp_list.txt


for file1 in `cat ${path}$list_in`; do
        base=`echo $file1 | sed -e 's/\.fits//g'`			# Get the basename of this science frame
	if [ -e ${path}cats_for_scamp/${base}_for_scamp.cat ]; then	# If the science frame already have the cat for scamp, skip doing sextractor
        	echo -e "\nFile:" $file1 ": SExtractor cat file for scamp already exist. \n"
		ls ${path}cats_for_scamp/${base}_for_scamp.cat | xargs -n 1 basename >> ${path}cats_for_scamp/${cluster_name}_${filter_location}_cats_for_scamp_list.txt
	else
		# Run sextractor first time to create a temp cat to determine fwhm
		sex ${path}$file1 -c ${script_dir}/extra/get_cat_for_scamp.config -PARAMETERS_NAME ${script_dir}/extra/before_scamp.param -WEIGHT_IMAGE ${path}${base}.wt.fits -FILTER_NAME ${script_dir}/extra/gauss_2.5_5x5.conv -CATALOG_NAME ${path}cats_for_scamp/${base}_temp.cat
		# Run fwhm.py to determine which filter to use in sextractor
        	conv_filter=$(python ${script_dir}/extra/fwhm.py ${path}cats_for_scamp/${base}_temp.cat 2>&1)
		echo '--------- Using ' $conv_filter ' ---------'
        	rm ${path}cats_for_scamp/${base}_temp.cat
		# Run sextractor second time and save cat as FITS_LDAC for scamp
		sex ${path}$file1 -c ${script_dir}/extra/get_cat_for_scamp.config -PARAMETERS_NAME ${script_dir}/extra/before_scamp.param -WEIGHT_IMAGE ${path}${base}.wt.fits -FILTER_NAME ${script_dir}/extra/$conv_filter -CATALOG_TYPE FITS_LDAC -CATALOG_NAME ${path}cats_for_scamp/${base}_for_scamp.cat
		ls ${path}cats_for_scamp/${base}_for_scamp.cat | xargs -n 1 basename >> ${path}cats_for_scamp/${cluster_name}_${filter_location}_cats_for_scamp_list.txt
	fi
done



if [ $SCAMP_REDO == "TRUE" ]; then
	for file1 in `cat ${path}cats_for_scamp/${cluster_name}_${filter_location}_cats_for_scamp_list.txt`; do
		name=`echo $file1 | sed -e 's/\.cat//g'`
		name2=`echo $name | sed -e 's/_for_scamp//g'`
		scamp -DISTORT_DEGREES 1 -ASTREF_CATALOG $SCAMP_CATALOG_AHEAD -MOSAIC_TYPE LOOSE -HEADER_TYPE FOCAL_PLANE -POSITION_MAXERR $POS_MERR_AHEAD -HEADER_NAME ${path}${name}.head -c ${script_dir}/extra/default.scamp ${path}cats_for_scamp/$file1 2>&1 | tee ${path}scamp_logs/${name2}_scamp_log1.txt
		mv ${path}${name}.head ${path}${name}.ahead
		scamp -MOSAIC_TYPE SAME_CRVAL -ASTREF_CATALOG $SCAMP_CATALOG -POSITION_MAXERR $POS_MERR -AHEADER_NAME ${path}${name}.ahead -HEADER_NAME ${path}${name}.head -c ${script_dir}/extra/default.scamp ${path}cats_for_scamp/$file1 2>&1 | tee ${path}scamp_logs/${name2}_scamp_log2.txt
		mv ${path}${name}.head ${path}${name}.ahead
		scamp -MOSAIC_TYPE SAME_CRVAL -ASTREF_CATALOG $SCAMP_CATALOG -POSITION_MAXERR $POS_MERR2 -AHEADER_NAME ${path}${name}.ahead -HEADER_NAME ${path}${name}.head -c ${script_dir}/extra/default.scamp ${path}cats_for_scamp/$file1 2>&1 | tee ${path}scamp_logs/${name2}_scamp_log3.txt
#		mv ${path}${name}.head ${path}${name}.ahead
#		scamp -MOSAIC_TYPE SAME_CRVAL -ASTREF_CATALOG $SCAMP_CATALOG -POSITION_MAXERR $POS_MERR3 -c ${script_dir}/extra/default.scamp ${path}$file
		mv ${path}${name}.head ${path}${name2}.head
	done
elif [ $SCAMP_REDO == "FALSE" ]; then
	echo -e "SCAMP_REDO = FALSE, skip running SCAMP.\n"
	fname=`head -1 ${path}cats_for_scamp/${cluster_name}_${filter_location}_cats_for_scamp_list.txt`
	name=`echo $fname | sed -e 's/\.cat//g'`
	name2=`echo $name | sed -e 's/_for_scamp//g'`
fi


ave_gain=`gethead gain1 gain2 gain3 gain4 gain5 gain6 gain7 gain8 gain9 gain10 gain11 gain12 gain13 gain14 gain15 gain16 ${path}${name2}.fits| awk '{print ($1+$2+$3+$4+$5+$6+$7+$8+$9+$10+$11+$12+$13+$14+$15+$16)/16.0}'`




# If path is not empty i.e. if the script is not running in the files folder, a list containing each file's full path is needed for swarp
if [ -n $path ]; then
        :>${path}long_${list_in}
        for filename in `cat ${path}$list_in`; do
                ls ${path}$filename >> ${path}long_${list_in}
        done
	list_in=long_${list_in}
fi


if [ $DO_STACKING == "TRUE" ]; then
	swarp @${path}$list_in -c ${script_dir}/extra/default.swarp -IMAGEOUT_NAME ${path}stacked_results/stack_${cluster_name}_${filter_location}.fits -WEIGHTOUT_NAME ${path}stacked_results/stack_${cluster_name}_${filter_location}.wt.fits -GAIN_DEFAULT $ave_gain -COMBINE_TYPE $combine_type
elif [ $DO_STACKING == "FALSE" ]; then
	echo "DO_STACKING = FALSE, skip running SWarp."
#	echo "DO_STACKING = FALSE, skip running SWarp. Variables saved to file"
#	:>${path}stacking_variables.txt
#	echo "path="${path} >> ${path}stacking_variables.txt
#	echo "list_in="${list_in} >> ${path}stacking_variables.txt
#	echo "cluster_name="${cluster_name} >> ${path}stacking_variables.txt
#	echo "script_dir="${script_dir} >> ${path}stacking_variables.txt
#	echo "filter_location="${filter_location} >> ${path}stacking_variables.txt
#	echo "ave_gain="${ave_gain} >> ${path}stacking_variables.txt
#	echo "combine_type="${combine_type} >> ${path}stacking_variables.txt
fi


#mv ${path}*${filter_num}*${location}*head ${path}scamp_heads



