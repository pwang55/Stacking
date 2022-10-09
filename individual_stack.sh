#!/bin/bash


usage='

Usage:

        In script folder:
	$ ./individual_stack.sh path_to_files/list_1ne.txt (-option1) (-option2) ...

        In script folder running for loop, path_to_file needs to be provided
        $ for files in `cat path_to_file/listoflist.txt`; do
	> ./individual_stack.sh $files [path_to_file] (-option1) (-option2) ...
        > done

        In files folder:
        $ path_to_script/./individual_stack.sh list_1ne.txt (-option1) (-option2) ...

This script stack files listed in the input list (ex: list_1ne.txt). 
The list file (ex: list_1ne.txt) has to be the first argument. All others are interchangeable.

Optional arguments and their default values are (case insensitive):


	-doc | -h | -help		Print doc and exit.

	-scamp=true			Run SCAMP (false will skip SExtractor and SCAMP)

	-swarp=true			Run SWarp (false will skip SWarp)

	-SCAMP_CATALOG_AHEAD=ALLWISE	Catalog for first SCAMP LOOSE type run

	-SCAMP_CATALOG=ALLWISE		Catalog for first SCAMP SAME_CRVAL run

	-combine_type=WEIGHTED		Stacking combine type

	-sextractor=quiet		No Source Extractor output on screen, can be normal or quiet

	-scamp=normal			SCAMP output type, can be NORMAL or LOG

	-swarp=normal			SWarp output on screen, can be normal or quiet

	-POS_MERR_AHEAD=5.0		Max position uncertainty for SCAMP LOOSE (arcmin)

	-POS_MERR1=10.0			Max position uncertainty for SCAMP 1st SAME_CRVAL (arcmin)

	-POS_MERR2=5.0			Max position uncertainty for SCAMP 2nd SAME_CRVAL (arcmin)

	-POS_MERR3=3.0			Max position uncertainty for SCAMP 3rd SAME_CRVAL (arcmin)

	-subtractbackground=Y		SWarp will subtract background (N will not)

	-SWARP_BACKSIZE=128		SWarp BACK_SIZE

	-SWARP_BACKFILTERSIZE=3		SWarp BACK_FILTERSIZE


IMPORTANT:
Sometime SCAMP goes crazy and cannot find astrometry solution, and will expand the image so large that the disk would be
full if SWarp is executed. In that case, set swarp=false, tweak SCAMP setting until it produces good .head files, then
set scamp=false and swarp=true to finish stacking.


'

#If no argument is given, print doc and exit
if (( "$#" == 0 )); then
	echo "$usage"
	exit 1
fi


# First argument is always the list file
list_in=$1
shift

# Take other arguments in and convert all to lower case
ARGS=`echo "$@" | tr '[:upper:]' '[:lower:]'`



# Default variables

scamp_TF=true
swarp_TF=true

POS_MERR_AHEAD=5.0
POS_MERR=10.0
POS_MERR2=5.0
POS_MERR3=3.0
SCAMP_CATALOG_AHEAD=ALLWISE
SCAMP_CATALOG=ALLWISE
combine_type=WEIGHTED
SEX_VERBOSE=QUIET
SCAMP_VERBOSE=NORMAL
SWARP_VERBOSE=NORMAL
SUBTRACT_BACKGROUND=Y
SWARP_BACKSIZE=128
SWARP_BACKFILTERSIZE=3

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
		-scamp_catalog_ahead=*)
			SCAMP_CATALOG_AHEAD="`echo ${arg#*=} | tr '[:lower:]' '[:upper:]'`"
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
		-pos_merr_ahead=*)
			POS_MERR_AHEAD="${arg#*=}"
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
		-subtractbackground=n)
			SUBTRACT_BACKGROUND=N
			shift
			;;
		-subtractbackground=y)
			SUBTRACT_BACKGROUND=Y
			shift
			;;
		-swarp_backsize=*)
			SWARP_BACKSIZE="${arg#*=}"
			shift
			;;
		-swarp_backfiltersize=*)
			SWARP_BACKFILTERSIZE="${arg#*=}"
			shift
			;;            
	esac
done

# If there are more than 1 argument left then too much arguments, print doc and exit
leftover_arg_len="$#"
if (( $leftover_arg_len > 1 )); then
	echo "Too many unrecognized arguments:" "$@" 
	echo "$usage"
	exit 1
fi



# First set path to empty
path0=""


# If there is exactly 1 argument left, and splitting it with "/" results in len > 1, it should be the path (when running for loop path need to be given)
if (( $leftover_arg_len == 1 )); then
	arg_left="$@"
	arg_left_len=`echo ${arg_left} | awk '{n=split($1,a,"/"); print n}'`
	if (( $arg_left_len > 1 )); then
		path0=$arg_left
	else
		echo "Unrecognized argument!"
		exit 1
	fi
fi



script_dir=$(cd `dirname $0` && pwd)
execute_dir=`pwd`



# If argument path is found from above and doesn't end with /, add it; otherwise just use it as path
# If above doesn't find a path, then path will be empty
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
        echo -e "File: \t $path$list_in \t can't be found, path argument may be needed, or filename is incorrect. Script end."
        exit 1
# If path/file doesn't exist and path is given, filename or path might be incorrect, end the script
elif [ ! -e $path$list_in ]; then
        echo -e "File: \t $path$list_in \t can't be found, check the file name or path, Script end."
        exit 1
fi



# Print out variables before start
echo -e "\nList in:" ${list_in}
echo -e "Files path:" ${path}
echo -e "SCAMP =" $scamp_TF
echo -e "SWarp =" $swarp_TF
echo -e "SCAMP_CATALOG_AHEAD =" $SCAMP_CATALOG_AHEAD
echo -e "SCAMP_CATALOG =" $SCAMP_CATALOG
echo -e "combine_type =" $combine_type
echo -e "SEX_VERBOSE =" $SEX_VERBOSE
echo -e "SCAMP_VERBOSE =" $SCAMP_VERBOSE
echo -e "SWARP_VERBOSE =" $SWARP_VERBOSE
echo -e "POS_MERR_AHEAD =" $POS_MERR_AHEAD
echo -e "POS_MERR =" $POS_MERR
echo -e "POS_MERR2 =" $POS_MERR2
echo -e "POS_MERR3 =" $POS_MERR3
echo -e "SUBTRACT_BACKGROUND =" $SUBTRACT_BACKGROUND
echo -e "SWARP_BACKSIZE =" $SWARP_BACKSIZE
echo -e "SWARP_BACKFILTERSIZE =" $SWARP_BACKFILTERSIZE
echo -e "\n"




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
		sex ${path}$file1 -c ${script_dir}/extra/get_cat_for_scamp.config -PARAMETERS_NAME ${script_dir}/extra/before_scamp.param -WEIGHT_IMAGE ${path}${base}.wt.fits -FILTER_NAME ${script_dir}/extra/gauss_2.5_5x5.conv -VERBOSE_TYPE $SEX_VERBOSE -CATALOG_NAME ${path}cats_for_scamp/${base}_temp.cat
		# Run fwhm.py to determine which filter to use in sextractor
        	conv_filter=$(python ${script_dir}/extra/fwhm.py ${path}cats_for_scamp/${base}_temp.cat 2>&1)
		echo '--------- Using ' $conv_filter ' ---------'
        	rm ${path}cats_for_scamp/${base}_temp.cat
		# Run sextractor second time and save cat as FITS_LDAC for scamp
		sex ${path}$file1 -c ${script_dir}/extra/get_cat_for_scamp.config -PARAMETERS_NAME ${script_dir}/extra/before_scamp.param -WEIGHT_IMAGE ${path}${base}.wt.fits -FILTER_NAME ${script_dir}/extra/$conv_filter -VERBOSE_TYPE $SEX_VERBOSE -CATALOG_TYPE FITS_LDAC -CATALOG_NAME ${path}cats_for_scamp/${base}_for_scamp.cat
		ls ${path}cats_for_scamp/${base}_for_scamp.cat | xargs -n 1 basename >> ${path}cats_for_scamp/${cluster_name}_${filter_location}_cats_for_scamp_list.txt
	fi
done



if [ $scamp_TF == "true" ]; then
	for file1 in `cat ${path}cats_for_scamp/${cluster_name}_${filter_location}_cats_for_scamp_list.txt`; do
		name=`echo $file1 | sed -e 's/\.cat//g'`
		name2=`echo $name | sed -e 's/_for_scamp//g'`
		scamp -DISTORT_DEGREES 1 -ASTREF_CATALOG $SCAMP_CATALOG_AHEAD -MOSAIC_TYPE LOOSE -HEADER_TYPE FOCAL_PLANE -POSITION_MAXERR $POS_MERR_AHEAD -VERBOSE_TYPE $SCAMP_VERBOSE -HEADER_NAME ${path}${name}.head -c ${script_dir}/extra/default.scamp ${path}cats_for_scamp/$file1 2>&1 | tee ${path}scamp_logs/${name2}_scamp_log1.txt
		mv ${path}${name}.head ${path}${name}.ahead
		scamp -MOSAIC_TYPE SAME_CRVAL -ASTREF_CATALOG $SCAMP_CATALOG -POSITION_MAXERR $POS_MERR -AHEADER_NAME ${path}${name}.ahead -VERBOSE_TYPE $SCAMP_VERBOSE -HEADER_NAME ${path}${name}.head -c ${script_dir}/extra/default.scamp ${path}cats_for_scamp/$file1 2>&1 | tee ${path}scamp_logs/${name2}_scamp_log2.txt
		mv ${path}${name}.head ${path}${name}.ahead
		scamp -MOSAIC_TYPE SAME_CRVAL -ASTREF_CATALOG $SCAMP_CATALOG -POSITION_MAXERR $POS_MERR2 -AHEADER_NAME ${path}${name}.ahead -VERBOSE_TYPE $SCAMP_VERBOSE -HEADER_NAME ${path}${name}.head -c ${script_dir}/extra/default.scamp ${path}cats_for_scamp/$file1 2>&1 | tee ${path}scamp_logs/${name2}_scamp_log3.txt
#		mv ${path}${name}.head ${path}${name}.ahead
#		scamp -MOSAIC_TYPE SAME_CRVAL -ASTREF_CATALOG $SCAMP_CATALOG -POSITION_MAXERR $POS_MERR3 -c ${script_dir}/extra/default.scamp ${path}$file
		mv ${path}${name}.head ${path}${name2}.head
	done
elif [ $scamp_TF == "false" ]; then
	echo -e "SCAMP = FALSE, skip running SCAMP.\n"
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


if [ $swarp_TF == "true" ]; then
	swarp @${path}$list_in -c ${script_dir}/extra/default.swarp -IMAGEOUT_NAME ${path}stacked_results/stack_${cluster_name}_${filter_location}.fits -WEIGHTOUT_NAME ${path}stacked_results/stack_${cluster_name}_${filter_location}.wt.fits -GAIN_DEFAULT $ave_gain -SUBTRACT_BACK $SUBTRACT_BACKGROUND -VERBOSE_TYPE $SWARP_VERBOSE -COMBINE_TYPE $combine_type -BACK_SIZE $BACK_SIZE -BACK_FILTERSIZE $BACK_FILTERSIZE
elif [ $swarp_TF == "false" ]; then
	echo "SWarp = FALSE, skip running SWarp."
fi

if [ -n $path ]; then
        rm ${path}${list_in}
fi

