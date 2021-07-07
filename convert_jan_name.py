'''

Usage:

    In script folder:
    $ python convert_jan_name.py path_to_files clustername

    In files folder:
    $ python path_to_script/convert_jan_name.py clustername

Convert January file names into standard corrected_xxxx.fits


'''
import numpy as np
from astropy.io import fits, ascii
from astropy.table import Table
# from photutils import MedianBackground, SExtractorBackground
from glob import glob
import sys
import subprocess

# The corresponding filter and locations
Dict = {'A': 'se', 'B': 'sw', 'C': 'ne', 'D': 'nw'}
counter = {'1ne':0, '1nw': 0, '1se': 0, '1sw': 0, '2ne': 0, '2nw': 0, '2se': 0, '2sw': 0}

if len(sys.argv) == 1:
    print(__doc__)
    sys.exit()


path = ''
if len(sys.argv) == 3:
    path = sys.argv[1]
    clustername = sys.argv[2]
    if path[-1] != '/':
        path = path + '/'
elif len(sys.argv) == 2:
    clustername = sys.argv[1]


files = glob(path + '*fits')

for i in range(len(files)):

    ABCD = files[i][0]
    filtnumber = files[i].split('_')[0][-1]
    loc = files[i].split('_')[1]
    filtnumber_loc = filtnumber + loc
    filt = 'asu' + filtnumber
    date = str(int(fits.getheader(files[i])['date'].split('-')[2].split('T')[0])-1)

    # Make sure A/B/C/D and location match
    if loc != Dict[ABCD]:
        print("Character A/B/C/D doesn't match filter location, check your file: {}".format(files[i]))
        sys.exit()

    # counter for this filter + 1, make it the number of the file in the end
    counter[filtnumber_loc] += 1
    serial_no = str(counter[filtnumber_loc])
    fits.setval(path + files[i], 'FILTER', value=filt.upper())

    subprocess.run(['mv', path + files[i], path + 'corrected_' + clustername + '_' + filt + '_' + loc + '_' + serial_no + '_jan' + date +'.fits'])
    print('Rename {} -> {}'.format(files[i], 'corrected_' + clustername + '_' + filt + '_' + loc + '_' + serial_no +  '_jan' + date +'.fits'))
