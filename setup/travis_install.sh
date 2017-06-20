#!/bin/bash -xe
#
# A script to setup the Travis build environment with Miniconda
# and install the LSST stack into it.
#
# Arguments: one or more additional conda packages to install
#

if [[ -z $1 ]]; then
	echo "usage: $0 <package_to_install> [package [...]]"
	exit -1
fi

MINICONDA_VERSION=${MINICONDA_VERSION:-3.19.0}			# you can use "latest" if you don't care
CHANNEL=${CHANNEL:-"http://conda.lsst.codes/sims/2.3.5"}	# the URL to the conda channel where LSST conda packages reside

########################################################################################################

CACHE_DIR="$HOME/miniconda.tarball"
CACHE_DIR_TMP="$CACHE_DIR.tmp"
CACHE_TARBALL_NAME="miniconda.tar.gz"
CACHE_TARBALL_PATH="$CACHE_DIR/$CACHE_TARBALL_NAME"



# Store a record of what's in the cached tarball
# This record allows us to automatically regenerate the tarball if the installed packages change.
rm -f "$HOME/info.txt"
cat > "$HOME/info.txt" <<-EOT
	# -- cache information; autogenerated by ci/install.sh
	MINICONDA_VERSION=$MINICONDA_VERSION
	CHANNEL=$CHANNEL
	PACKAGES=$@
EOT
cat "$HOME/info.txt"



if [[ -f "$CACHE_TARBALL_PATH" ]] && cmp "$HOME/info.txt" "$CACHE_DIR/info.txt"; then
	#
	# Restore from cached tarball
	#
	tar xzf "$CACHE_TARBALL_PATH" -C "$HOME" 
	ls -l "$HOME"
else
	#
	# Miniconda install
	#
	# Install Python 2.7 Miniconda
	rm -rf "$HOME/miniconda"
	curl -L -O "https://repo.continuum.io/miniconda/Miniconda2-$MINICONDA_VERSION-Linux-x86_64.sh"
	bash "Miniconda2-$MINICONDA_VERSION-Linux-x86_64.sh" -b -p "$HOME/miniconda"
	export PATH="$HOME/miniconda/bin:$PATH"

	#
	# Disable MKL. The stack doesn't play nice with it (symbol collisions)
	#
	conda install --yes nomkl

	#
	# Stack install
	#
	conda config --add channels "$CHANNEL"
	conda install -q --yes "$@"			# -q is needed, otherwise TravisCI kills the job due too much output in the log (4MB)

	# Minimize our on-disk footprint
	conda clean -iltp --yes

	#
	# Pack for caching. We pack here as Travis tends to time out if it can't pack
	# the whole directory in ~180 seconds.
	#
	rm -rf "$CACHE_DIR" "$CACHE_DIR_TMP"

	mkdir "$CACHE_DIR_TMP"
	tar czf "$CACHE_DIR_TMP/$CACHE_TARBALL_NAME" -C "$HOME" miniconda
	mv "$HOME/info.txt" "$CACHE_DIR_TMP"

	mv "$CACHE_DIR_TMP" "$CACHE_DIR"	# Atomic rename
	ls -l "$CACHE_DIR"
fi
