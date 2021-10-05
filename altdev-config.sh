#!/bin/bash -uef

export ALT_USER=egori

export ALTDEVDIR=$HOME/.altdev

# Alt dev user files
export ALTDIR=$HOME/alt

# Alt dev work dir
export WORKDIR=$TMP/altdev

export PROFILES=$ALTDEVDIR/profiles

export HASHERDIR=$WORKDIR/hasher
export REPODIR=$HASHERDIR/repo
export PKGS=$WORKDIR/pkgs

export GEARS=$ALTDIR/gears

#===============================
MKIMAGEDIR=
IMAGES=$ALTDIR/images

KERNELWORKDIR=
KERNELS=$ALTDIR/kernels
