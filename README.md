

**`make_list.sh`** makes the lists containing science frames to be stacked (ex: list_1ne.txt)

**`individual_stack.sh`** takes list created from above (ex: list_1ne.txt) and make stacked image.
Output format will be stack_(clustername)_1ne.fits and it's weight image.

**`master_stack.sh`** takes masterlist.txt containing all stacked image, create a master stacked image.
The master stacked image is crucial for photometry analysis.

**`convert_jan_name.py`** converts January file names into standard corrected_xxxx.fits.

**`jan_individual_stack.sh`** works like individual_stack.sh but works on January files

---------------------------------------------------------------

Each Usage:

**masterlist.sh:**

In script folder:

`$ ./make_list.sh [path_to_files] [cluster_name]`

In files folder:

`$ path_to_script/./make_list.sh [cluster_name]`

---------------------------------------------------------------

**individual_stack.sh:**

In script folder:

`$ ./individual_stack.sh path_to_files/list_1ne.txt (-option1) (-option2) ...`

In script folder running for loop, path_to_file needs to be provided

```
$ for files in `cat path_to_file/listoflist.txt`; do
> ./individual_stack.sh $files [path_to_file] (-option1) (-option2) ...
> done
```

In files folder:

`$ path_to_script/./individual_stack.sh list_1ne.txt (-option1) (-option2) ...`

Options(case insensitive):

```
	-doc | -h | -help		Print doc and exit.

	-scamp=true			Run SCAMP (false will skip SExtractor and SCAMP)

	-swarp=true			Run SWarp (false will skip SWarp)

	-SCAMP_CATALOG_AHEAD=ALLWISE	Catalog for first SCAMP LOOSE type run

	-SCAMP_CATALOG=ALLWISE		Catalog for first SCAMP SAME_CRVAL run

	-combine_type=WEIGHTED		Stacking combine type

        -sextractor=quiet               No Source Extractor output on screen, can be normal or quiet

        -scamp=normal                   SCAMP output type, can be NORMAL or LOG

        -swarp=normal                   SWarp output on screen, can be normal or quiet

	-POS_MERR_AHEAD=5.0		Max position uncertainty for SCAMP LOOSE (arcmin)

	-POS_MERR1=10.0			Max position uncertainty for SCAMP 1st SAME_CRVAL (arcmin)

        -POS_MERR2=5.0			Max position uncertainty for SCAMP 2nd SAME_CRVAL (arcmin)

        -POS_MERR3=3.0			Max position uncertainty for SCAMP 3rd SAME_CRVAL (arcmin)

	-subtractbackground=Y		SWarp will not subtract background (N will not)
```

---------------------------------------------------------------

**master_stack.sh:**

In script folder:

`$ ./master_stack.sh path_to_files/masterlist.txt (-option1) (-option2) ...`

In files folder:

`$ path_to_script/./master_stack.sh masterlist.txt (-option1) (-option2) ...`

You need to create masterlist.txt yourself.

Options (case insensitive):

```
        -doc | -h | -help               Print doc and exit.

        -scamp=true                     Run SCAMP

        -scamp=false                    Skip SCAMP (Will also skip sextractor), default

	-swarp=true			Run SWarp, default

	-swarp=false			Skip SWarp

        -SCAMP_CATALOG=ALLWISE          Catalog for first SCAMP SAME_CRVAL run, default is ALLWISE

        -combine_type=WEIGHTED          Stacking combine type. Default is weighted stack.

        -POS_MERR1=2.0                  Max position uncertainty for SCAMP 1st SAME_CRVAL (arcmin)

	-sextractor=quiet		No Source Extractor output on screen (default=NORMAL)

	-scamp=log			SCAMP output in the form of LOG (default: NORMAL)

	-swarp=quiet			No SWarp output on screen (default: NORMAL)

	-subtractbackground=Y           SWarp will subtract background (N will not). Default Y

	-POS_MERR2=5.0                  Max position uncertainty for SCAMP 2nd SAME_CRVAL (arcmin) (deactivated now)

	-POS_MERR3=3.0                  Max position uncertainty for SCAMP 3rd SAME_CRVAL (arcmin) (deactivated now)
```


---------------------------------------------------------------

**convert_jan_name.py**

In script folder:

`$ python convert_jan_name.py path_to_files clustername`

In files folder:

`$ python path_to_script/convert_jan_name.py clustername`


---------------------------------------------------------------

**jan_individual_stack.sh**

In script folder:

`$ ./individual_stack.sh path_to_files/list_1ne.txt (-option1) (-option2) ...`

In script folder running for loop, path_to_file needs to be provided

```
$ for files in `cat path_to_file/listoflist.txt`; do
> ./individual_stack.sh $files [path_to_file] (-option1) (-option2) ...
> done
```

In files folder:

`$ path_to_script/./individual_stack.sh list_1ne.txt (-option1) (-option2) ...`


