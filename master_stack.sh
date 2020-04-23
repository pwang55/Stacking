#!/bin/bash


usage='

Usage:

        In script folder:
        $ ./master_stack.sh path_to_files/masterlist.txt (-option1) (-option2) ...

        In files folder:
        $ path_to_script/./master_stack.sh masterlist.txt (-option1) (-option2) ...

This script create master_stack_(cluster).ft and wt.fits. You need to create masterlist.txt yourself, and it has to be the
the first argument. All others are interchangeable.

Optional arguments are (case insensitive):


        -doc | -h | -help               Print doc and exit.

        -scamp=true                     Run SCAMP, default

        -scamp=false                    Skip SCAMP

	-swarp=true			Run SWarp, default

	-swarp=false			Skip SWarp

        -SCAMP_CATALOG=ALLWISE          Catalog for first SCAMP SAME_CRVAL run, default is ALLWISE

        -combine_type=WEIGHTED          Stacking combine type. Default is weighted stack.

        -POS_MERR1=2.0                  Max position uncertainty for SCAMP 1st SAME_CRVAL (arcmin)

	-sextractor=quiet		No Source Extractor output on screen (default=NORMAL)

	-scamp=log			SCAMP output in the form of LOG (default: NORMAL)

	-swarp=quiet			No SWarp output on screen (default: NORMAL)

	-POS_MERR2=5.0                  Max position uncertainty for SCAMP 2nd SAME_CRVAL (arcmin) (deactivated now)

	-POS_MERR3=3.0                  Max position uncertainty for SCAMP 3rd SAME_CRVAL (arcmin) (deactivated now)



This script should not go crazy like individual_stack.sh with SCAMP sometimes, but just in case if that happens,
set -swarp=false, tweak until it runs fine, then set -scamp=false, -swarp=true to finally stack.

Noted that scamp output cannot be set to quiet. This is because it is important to see scamp running results.


'



#If no argument is given, print doc and exit
if (( "$#" == 0 )); then
        echo "$usage"
        exit 1
fi

# First argument is always list in
list_in=$1
shift

# Take other arguments in and convert all to lower case
ARGS=`echo "$@" | tr '[:upper:]' '[:lower:]'`


# Default variables
scamp_TF=true
swarp_TF=true
POS_MERR=2.0
POS_MERR2=5.0
POS_MERR3=3.0
SCAMP_CATALOG=ALLWISE
combine_type=WEIGHTED
SEX_VERBOSE=NORMAL
SCAMP_VERBOSE=NORMAL
SWARP_VERBOSE=NORMAL

# See if there are arguments given that overwrites default variables
for arg in $ARGS; do
        case $arg in
                -doc|-help|-h)
                        echo "$usage"
                        exit 1
                        ;;
                -scamp=true)
                        scamp_TF=true
                        shift
                        ;;
                -scamp=false)
                        scamp_TF=false
                        shift
                        ;;
                -swarp=true)
                        swarp_TF=true
                        shift
                        ;;
                -swarp=false)
                        swarp_TF=false
                        shift
                        ;;
                -scamp_catalog=*)
                        SCAMP_CATALOG="`echo ${arg#*=} | tr '[:lower:]' '[:upper:]'`"
                        shift
                        ;;
                -combine_type=*)
                        combine_type="`echo ${arg#*=} | tr '[:lower:]' '[:upper:]'`"
                        shift
                        ;;
                -pos_merr1=*)
                        POS_MERR="${arg#*=}"
                        shift
                        ;;
                -pos_merr2=*)
                        POS_MERR2="${arg#*=}"
                        shift
                        ;;
                -pos_merr3=*)
                        POS_MERR3="${arg#*=}"
                        shift
                        ;;
		-sextractor=quiet)
			SEX_VERBOSE=QUIET
			shift
			;;
		-scamp=log)
			SCAMP_VERBOSE=LOG
			shift
			;;
		-swarp=quiet)
			SWARP_VERBOSE=QUIET
			shift
			;;
        esac
done


# If there are at least 1 argument left then too much arguments, print doc and exit
leftover_arg_len="$#"
if (( $leftover_arg_len > 0 )); then
        echo "Too many unrecognized arguments:" "$@"
        echo "$usage"
        exit 1
fi


# First initialize path to empty
path=""

script_dir=$(cd `dirname $0` && pwd)
execute_dir=`pwd`


# If argument 1 is a full path to the list.txt, break it apart to path and list file
len_file=`echo $list_in | awk '{n=split($1,a,"/"); print n}'`
if (( $len_file > 1 )); then
        list_in0=$list_in
        all_len=${#list_in0}
        list_in=`echo $list_in0 | awk '{n=split($1,a,"/"); print a[n]}'`
        list_len=${#list_in}
        path_len=`echo "$(($all_len-$list_len))"`
        path=`echo ${list_in0:0:$path_len}`
fi


# If list in cannot be found, exit the script
if [ ! -e ${path}$list_in ]; then
	echo -e "File: \t $path$list_in \t can't be found. Check path or filename."
	exit 1
fi


# Print out variables before start
echo -e "\nList in:" ${list_in}
echo -e "Files path:" ${path}
echo -e "SCAMP =" $scamp_TF
echo -e "SWarp =" $swarp_TF
echo -e "SCAMP_CATALOG =" $SCAMP_CATALOG
echo -e "combine_type =" $combine_type
echo -e "SEX_VERBOSE =" $SEX_VERBOSE
echo -e "SCAMP_VERBOSE =" $SCAMP_VERBOSE
echo -e "SWARP_VERBOSE =" $SWARP_VERBOSE
echo -e "POS_MERR =" $POS_MERR
echo -e "POS_MERR2 =" $POS_MERR2
echo -e "POS_MERR3 =" $POS_MERR3
echo -e "\n"



###############################


# Create folder for sextractor created cats for scamp
if [ ! -d ${path}cats_for_scamp ]; then
	mkdir ${path}cats_for_scamp
fi
# Create a directory for scamp logs
if [ ! -d ${path}scamp_logs ]; then
        mkdir ${path}scamp_logs
fi


# Get some useful names
firstfilename=`head -1 ${path}$list_in`
firstfilebase=`echo $firstfilename | sed -e 's/\.fits//g'`
cluster_name=`echo $firstfilebase | awk '{split($1,a,"_"); print a[2]}'`	# Get cluster name
word_stack=`echo $firstfilebase | awk '{split($1,a,"_"); print a[1]}'`		# literally just the word "stack"
base2=`echo ${word_stack}_${cluster_name}`					# stack_(cluster) for later creating final file names

# Clear or create a file containing all cats_for_scamp.cat
:>${path}cats_for_scamp/${cluster_name}_cats_for_scamp_list.txt


for file1 in `cat ${path}$list_in`; do
        base=`echo $file1 | sed -e 's/\.fits//g'`
	if [ -e ${path}cats_for_scamp/${base}_for_scamp.cat ]; then
        	echo -e "\nFile:" $file1 ": SExtractor cat file already exist!! \n"
		ls ${path}cats_for_scamp/${base}_for_scamp.cat | xargs -n 1 basename >> ${path}cats_for_scamp/${cluster_name}_cats_for_scamp_list.txt
	else
		sex ${path}$file1 -c ${script_dir}/extra/get_cat_for_scamp.config -PARAMETERS_NAME ${script_dir}/extra/before_scamp.param -WEIGHT_IMAGE ${path}${base}.wt.fits -FILTER_NAME ${script_dir}/extra/gauss_2.5_5x5.conv -VERBOSE_TYPE $SEX_VERBOSE -CATALOG_NAME ${path}cats_for_scamp/${base}_temp.cat
        	conv_filter=$(python ${script_dir}/extra/fwhm.py ${path}cats_for_scamp/${base}_temp.cat 2>&1)
		echo '--------- Using ' $conv_filter ' ---------'
        	rm ${path}cats_for_scamp/${base}_temp.cat
		sex ${path}$file1 -c ${script_dir}/extra/get_cat_for_scamp.config -PARAMETERS_NAME ${script_dir}/extra/before_scamp.param -WEIGHT_IMAGE ${path}${base}.wt.fits -FILTER_NAME ${script_dir}/extra/$conv_filter -CATALOG_TYPE FITS_LDAC -VERBOSE_TYPE $SEX_VERBOSE -CATALOG_NAME ${path}cats_for_scamp/${base}_for_scamp.cat
		ls ${path}cats_for_scamp/${base}_for_scamp.cat | xargs -n 1 basename >> ${path}cats_for_scamp/${cluster_name}_cats_for_scamp_list.txt
	fi
done


if [ $scamp_TF == "true" ]; then
	for file1 in `cat ${path}cats_for_scamp/${cluster_name}_cats_for_scamp_list.txt`; do
		name=`echo $file1 | sed -e 's/\.cat//g'`
		name2=`echo $name | sed -e 's/_for_scamp//g'`
		scamp -MOSAIC_TYPE SAME_CRVAL -ASTREF_CATALOG $SCAMP_CATALOG -POSITION_MAXERR $POS_MERR -VERBOSE_TYPE $SCAMP_VERBOSE -HEADER_NAME ${path}${name}.head -c ${script_dir}/extra/default.scamp ${path}cats_for_scamp/$file1 2>&1 | tee ${path}scamp_logs/${name2}_scamp_log1.txt
#		mv ${name}.head ${name}.ahead
#		scamp -MOSAIC_TYPE SAME_CRVAL -ASTREF_CATALOG $SCAMP_CATALOG -POSITION_MAXERR $POS_MERR2 -c default.scamp $file
#		mv ${name}.head ${name}.ahead
#		scamp -MOSAIC_TYPE SAME_CRVAL -ASTREF_CATALOG $SCAMP_CATALOG -POSITION_MAXERR $POS_MERR3 -c default.scamp $file
		mv ${path}${name}.head ${path}${name2}.head
	done
elif [ $scamp_TF == "false" ]; then
	echo -e "SCAMP = FALSE, skip running SCAMP.\n"
#	fname=`head -1 ${path}cats_for_scamp/${cluster_name}_cats_for_scamp_list.txt`
#        name=`echo $fname | sed -e 's/\.cat//g'`
#        name2=`echo $name | sed -e 's/_for_scamp//g'`
fi



# If path is not empty i.e. if the script is not running in the files folder, a list containing each file's full path is needed for swarp
if [ -n $path ]; then
        :>${path}long_${list_in}
        for filename in `cat ${path}$list_in`; do
                ls ${path}$filename >> ${path}long_${list_in}
        done
        list_in=long_${list_in}
fi


if [ $swarp_TF == "true" ]; then
	swarp @${path}$list_in -c ${script_dir}/extra/default.swarp -IMAGEOUT_NAME ${path}master_${base2}.fits -WEIGHTOUT_NAME ${path}master_${base2}.wt.fits -COMBINE_TYPE $combine_type -VERBOSE_TYPE $SWARP_VERBOSE
elif [ $swarp_TF == "false" ]; then
        echo "SWarp = FALSE, skip running SWarp."
fi




