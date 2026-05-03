#!/usr/bin/env bash

####################################################################################################

# ddmotion.sh: a shell script recreation of MS-DOS program "hdmotion" using dd in GNU/Linux

# Authored by Gemma 4, enhanced by DeepSeek-V4, audited and improved by me <3
# Inspired by hdmotion by Jeremy Stanley (hdmotion.pingerthinger.com)
# And hdmotion-for-windows by 1157369 (github.com/II57369/hdmotion-for-windows)

# Released under GPLv3 license
# This script was vibe coded together just for fun and comes with NO WARRANTY

####################################################################################################

# This variable controls the range of "perturbation" applied to each seek operation
# This is necessary to bypass some devices' internal read cache
# Default is ±0.1% of the device's total LBA, increase this if some seeks get cached
PERT_RANGE=0.001

# Check for root privileges
if [ $(id -u) -ne 0 ]
then
    echo -e "\e[31mThis script requires root privileges! Use 'sudo !!' to run as root.\e[0m"
    exit
fi

# List block devices with some additional info
lsblk --output NAME,MODEL,SERIAL,SIZE
echo

while :
do
    read -rp "Enter target device (e.g. /dev/sda): " DEV
    if [ -b "$DEV" ]
    then
        break
    fi
    echo -e "\e[31mERROR: $DEV is not a block device!\e[0m"
done

while :
do
    read -rp "Enter the number of loops (0 = infinite): " LOOPS
    if [[ "$LOOPS" =~ ^[0-9]+$ ]]
    then
        break
    fi
    echo -e "\e[31mERROR: Please enter a non‑negative integer!\e[0m"
done

# Get device's parameters
SECTOR_SIZE=$(blockdev --getss "$DEV")
TOTAL_SECTORS=$(expr $(blockdev --getsize64 "$DEV") / $SECTOR_SIZE)

# Calculate the LBA range for perturbations
MAX_OFFSET=$(awk -v ts="$TOTAL_SECTORS" -v pr="$PERT_RANGE" 'BEGIN {printf "%.0f", ts*pr}')

# Use dd to seek to a specified offset, but apply some "perturbation" as a work-around of read caching on some devices
# Then print a # in the terminal to reflect the current seek position
exec_seek() {
    local skip_lba
    # Get the new "perturbed" LBA offset
    skip_lba=$(awk -v p="$1" -v t="$TOTAL_SECTORS" -v m="$MAX_OFFSET" -v s="$RANDOM" '
        BEGIN {
            srand(s)
            lba=int(p*(t-1))
            offset=int(rand()*(2*m+1))-m
            skip=lba+offset
            if (skip<0) skip=0
            if (skip>=t) skip=t-1
            printf "%d", skip
        }')
    # Read a single block matching device's sector size using dd
    # Also bypass OS's page cache, continue on errors, hide all outputs and error messages
    dd if="$DEV" iflag=direct skip="$skip_lba" of=/dev/null bs="$SECTOR_SIZE" count=1 conv=noerror status=none 2>/dev/null
    # Print a #, dynamically adapting to the current terminal width
    printf "%$(($(awk -v p="$1" -v w=$(tput cols) 'BEGIN {printf "%.0f", p*(w-1)}')))s#\n"""
}

export -f exec_seek

# Generate the original patterns from hdmotion.cpp and execute seeks
run_patt() {
    awk '
    BEGIN {
        pi=3.141592653589793

        # accelerating zigzag
        s=0.01
        f=0.0
        for (i=0; i<5; i++) {
            for (; f<1.0; f+=s) print f
            f-=s
            for (; f>0.0; f-=s) print f
            s+=0.0075
        }
        f+=s

        # tightening zigzag
        h=0.90
        l=0.10
        while (l<h) {
            for (; f<h; f+=s) print f
            for (; f>l; f-=s) print f
            h-=0.05
            l+=0.05
        }

        # widening sinusoid
        for (amp=0.05; amp<=0.50; amp+=0.05) {
            for (x=0; x<2*pi; x+=pi/32)
                print sin(x)*amp+0.5
        }

        # narrowing sinusoid
        for (amp=0.50; amp>0.0; amp-=0.05) {
            for (x=0; x<2*pi; x+=pi/32)
                print sin(x)*amp+0.5
        }

        # widening double-sinusoid
        for (amp=0.05; amp<=0.50; amp+=0.05) {
            for (x=0; x<2*pi; x+=pi/16) {
                f=sin(x)*amp+0.5
                print f
                print 1.0-f
            }
        }

        # narrowing double-sinusoid
        for (amp=0.50; amp>0.0; amp-=0.05) {
            for (x=0; x<2*pi; x+=pi/16) {
                f=sin(x)*amp+0.5
                print f
                print 1.0-f
            }
        }

        # buncha heads
        heads=2
        while (heads<7) {
            repeat=int(160/heads)
            for (i=0; i<repeat; i++)
                for (j=1; j<=heads; j++)
                    print j/(heads+1)
            heads++
        }
        while (heads>0) {
            repeat=int(160/heads)
            for (i=0; i<repeat; i++)
                for (j=1; j<=heads; j++)
                    print j/(heads+1)
            heads-=2
        }

        # noise
        for (i=0; i<600; i++)
            print rand()
    }' |
    while read -r p
    do
        exec_seek "$p"
    done
}

# Main loop
for ((i=0; LOOPS==0 || i<LOOPS; i++))
do
    run_patt
done
