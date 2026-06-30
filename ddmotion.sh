#!/usr/bin/env bash

# This variable controls the range of "perturbation" applied to each seek operation
# This is necessary to bypass some devices' internal read cache
# Default is ±0.1% of the device's total LBA, increase this if some seeks get cached, and set this to 0 for FDD
PERT_RANGE=0.001

# Check for root privileges
if [ $(id -u) -ne 0 ]
then
    echo -e "\e[31mThis script requires root privileges! Use 'sudo !!' to run as root.\e[0m"
    exit
fi

# Get terminal window width
COLS=$(tput cols)

# List block devices with some additional info
lsblk -d --output NAME,MODEL,SERIAL,SIZE
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

# Get device's sector size
SECTOR_SIZE=$(blockdev --getss "$DEV")
# Calculate device's total sector count
TOTAL_SECTORS=$(($(blockdev --getsize64 "$DEV")/SECTOR_SIZE))
# Calculate the LBA range for perturbations
MAX_OFFSET=$(awk -v ts="$TOTAL_SECTORS" -v pr="$PERT_RANGE" 'BEGIN {printf "%.0f", ts*pr}')

run_patt() {
    awk -v dev="$DEV" -v ss="$SECTOR_SIZE" -v ts="$TOTAL_SECTORS" -v mo="$MAX_OFFSET" -v cols="$COLS" '
    # Use dd to seek to a specified offset, with random "perturbation" applied as a work-around of read caching on some devices
    # Then print a # in the terminal to reflect current seek location
    function exec_seek(p) {
        # Get the new "perturbed" LBA offset
        lba=int(p*(ts-1))
        offset=int(rand()*(2*mo+1))-mo
        skip=lba+offset
        if (skip<0) skip=0
        if (skip>=ts) skip=ts-1

        # Read a single block matching the sector size using dd
        # Also bypass page cache, continue on errors, hide all outputs and error messages
        cmd="dd if=" dev " iflag=direct skip=" skip " of=/dev/null bs=" ss " count=1 conv=noerror status=none 2>/dev/null"
        system(cmd)

        # Print a #, adapted to the terminal width
        w=int(p*(cols-1))
        printf "%*s#\n", w, ""
    }

    # Generate the original patterns from hdmotion.cpp and execute seeks
    BEGIN {
        srand()
        pi=3.141592653589793

        # accelerating zigzag
        s=0.01
        f=0.0
        for (i=0; i<5; i++) {
            for (; f<1.0; f+=s) exec_seek(f)
            f-=s
            for (; f>0.0; f-=s) exec_seek(f)
            s+=0.0075
        }
        f+=s

        # tightening zigzag
        h=0.90
        l=0.10
        while (l<h) {
            for (; f<h; f+=s) exec_seek(f)
            for (; f>l; f-=s) exec_seek(f)
            h-=0.05
            l+=0.05
        }

        # widening sinusoid
        for (amp=0.05; amp<=0.50; amp+=0.05) {
            for (x=0; x<2*pi; x+=pi/32)
                exec_seek(sin(x)*amp+0.5)
        }

        # narrowing sinusoid
        for (amp=0.50; amp>0.0; amp-=0.05) {
            for (x=0; x<2*pi; x+=pi/32)
                exec_seek(sin(x)*amp+0.5)
        }

        # widening double-sinusoid
        for (amp=0.05; amp<=0.50; amp+=0.05) {
            for (x=0; x<2*pi; x+=pi/16) {
                f=sin(x)*amp+0.5
                exec_seek(f)
                exec_seek(1.0-f)
            }
        }

        # narrowing double-sinusoid
        for (amp=0.50; amp>0.0; amp-=0.05) {
            for (x=0; x<2*pi; x+=pi/16) {
                f=sin(x)*amp+0.5
                exec_seek(f)
                exec_seek(1.0-f)
            }
        }

        # buncha heads
        heads=2
        while (heads<7) {
            repeat=int(160/heads)
            for (i=0; i<repeat; i++)
                for (j=1; j<=heads; j++)
                    exec_seek(j/(heads+1))
            heads++
        }
        while (heads>0) {
            repeat=int(160/heads)
            for (i=0; i<repeat; i++)
                for (j=1; j<=heads; j++)
                    exec_seek(j/(heads+1))
            heads-=2
        }

        # noise
        for (i=0; i<600; i++)
            exec_seek(rand())
    }'
}

# Trap the process so it terminates when Ctrl+C is pressed
trap 'kill "$PID" 2>/dev/null; echo -e "\n\e[31mInterrupted! Exiting...\e[0m"; exit 0' INT

# Main loop
for ((i=0; LOOPS==0 || i<LOOPS; i++))
do
    run_patt &
    PID=$!
    wait "$PID"
    PID=""
done
