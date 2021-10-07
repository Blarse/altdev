#!/bin/bash -uef

. altdev-sh-functions.sh

profile="default"

branch=
target=
remote=
verbose=
repo_url=
package=
inst_pkgs=

subcmd="build"

while [[ "$#" > 0 ]] ; do
    case "$1" in
		# overide branch:
		s)
			[ "$profile" = "default" -a -f "$PROFILES/$1" ] \
				&& profile="$1" || branch="Sisyphus"
			;;
		p9|p10)
			[ "$profile" = "default" -a -f "$PROFILES/$1" ] \
				&& profile="$1" || branch="$1/branch"
			;;
		# overide target:
		x86_64|64)
			[ "$profile" = "default" -a -f "$PROFILES/$1" ] \
				&& profile="$1" || target="x86_64"
			;;
		i586|32)
			[ "$profile" = "default" -a -f "$PROFILES/$1" ] \
				&& profile="$1" || target="i586"
			;;
		ppc64le|ppc)
			[ "$profile" = "default" -a -f "$PROFILES/$1" ] \
				&& profile="$1" || target="ppc64el"
			;;
		aarch64|a64)
			[ "$profile" = "default" -a -f "$PROFILES/$1" ] \
				&& profile="$1" || target="aarch64"
			;;
		armh|a32)
			[ "$profile" = "default" -a -f "$PROFILES/$1" ] \
				&& profile="$1" || target="armh"
			;;
		
		-v|--verbose)
			verbose=-v
			;;
		-q|--quiet)
			verbose=-q
			;;
		
# select subcmd:
		cl|clean)
			[ "$subcmd" = "clean" ] && profile="$1" || subcmd="clean"
			;;
		sh|shell)
			[ "$subcmd" = "shell" ] && profile="$1" || subcmd="shell"
			;;
		re|rebuild)
			[ "$subcmd" = "rebuild" ] && profile="$1" || subcmd="rebuild"
			;;
		in|inst|install)
			subcmd="install"
			shift
			[ "$subcmd" = "install" ] && inst_pkgs="$@"
			break
			;;
		*)
			[ -f "$PROFILES/$1" ] && profile="$1" || \
					echo "Warning: unknown argument \"$1\"" 1>&2
			;;
    esac
    shift
done

build(){
    echo "Start build..."

	CUR_PKG="$PKGS/$package"
	rm -rf $CUR_PKG
	mkdir -p $CUR_PKG
	
    cat > $CUR_PKG/apt.conf <<-EOF
	Dir::Etc::main "/dev/null";
	Dir::Etc::parts "/var/empty";
	Dir::Etc::sourceparts "/var/empty";
	Dir::Etc::sourcelist "$CUR_PKG/sources.list";
	APT::Cache-Limit "1073741824";
	EOF

    cat > $CUR_PKG/sources.list <<-EOF
	rpm $repo_url $branch/$target classic
	rpm $repo_url $branch/noarch classic
	EOF

    [ $target = "x86_64" ] && \
		echo "rpm $repo_url $branch/x86_64-i586 classic" >> $CUR_PKG/sources.list

    gear --zstd \
		 --commit \
		 $verbose \
		 $CUR_PKG/pkg.tar 2>&1 | tee $CUR_PKG/gear.log | tee -a $CUR_PKG/build.log

    if [ -z "$remote" ]; then
		if [ "$1" = "0" ]; then
			hsh --with-stuff \
				--apt-config=$CUR_PKG/apt.conf \
				--lazy-cleanup \
				--no-sisyphus-check \
				--repo=$CUR_PKG/out \
				--target=$target \
				--wait-lock \
				$verbose \
				$HASHERDIR \
				$CUR_PKG/pkg.tar 2>&1 | tee $CUR_PKG/hsh.log | tee -a $CUR_PKG/build.log
		else
			hsh-rebuild --with-stuff \
						--no-sisyphus-check \
						--repo=$CUR_PKG/out \
						--target=$target \
						--wait-lock \
						$verbose \
						$HASHERDIR \
						$CUR_PKG/pkg.tar 2>&1 | tee $CUR_PKG/hsh.log | tee -a $CUR_PKG/build.log
		fi
    else
		ssh $remote rm -rf $CUR_PKG
		ssh $remote mkdir -pv $CUR_PKG
		ssh $remote mkdir -pv $HASHERDIR

		scp $CUR_PKG/pkg.tar $remote:$CUR_PKG/pkg.tar
		scp $CUR_PKG/apt.conf $remote:$CUR_PKG/apt.conf
		scp $CUR_PKG/sources.list $remote:$CUR_PKG/sources.list

		if [ "$1" = "0" ]; then
			#build
			ssh $remote <<-EOF 2>&1 | tee $CUR_PKG/hsh.log | tee -a $CUR_PKG/build.log
			hsh --with-stuff \
				--apt-config=$CUR_PKG/apt.conf \
				--lazy-cleanup \
				--no-sisyphus-check \
				--repo=$CUR_PKG/out \
				--target=$target \
				--wait-lock \
				$verbose \
				$HASHERDIR \
				$CUR_PKG/pkg.tar
			EOF
		else
			#rebuild
			ssh $remote <<-EOF 2>&1 | tee $CUR_PKG/hsh.log | tee -a $CUR_PKG/build.log
			hsh-rebuild --with-stuff \
						--no-sisyphus-check \
						--repo=$CUR_PKG/out \
						--target=$target \
						--wait-lock \
						$verbose \
						$HASHERDIR \
						$CUR_PKG/pkg.tar
			EOF
		fi
		
		ssh $remote mkdir -p $REPODIR
		ssh $remote cp -r $CUR_PKG/out/* $REPODIR

		scp -r $remote:$CUR_PKG/out $CUR_PKG/out
    fi

	mkdir -p ./out/{bin,debug,src}
	find $CUR_PKG/out -type f -name "*.rpm" \
		 -and -not -name "*.src.rpm" \
		 -and -not -name "*debuginfo*" \
		 -exec cp "{}" ./out/bin \;

	find $CUR_PKG/out -type f -name "*.src.rpm" \
		 -exec cp "{}" ./out/src \;

	find $CUR_PKG/out -type f -name "*debuginfo*" \
		 -exec cp "{}" ./out/debug \;

	mkdir -p $REPODIR
	set +f
	cp -r $CUR_PKG/out/* $REPODIR
	set -f
}

load_var() {
	if [ -n "${1:-}" ]; then
		echo "$(grep $1 $PROFILES/$profile | tail -n 1 | cut -d'=' -f2)"
	fi
}

[ -f "$PROFILES/$profile" ] || fatal "Profile \"$profile\" doesn't exist"

[ -z "$remote" ] && remote="$(load_var remote)"
[ -z "$verbose" ] && verbose="$(load_var verbose)"

case "$subcmd" in
    shell)
		[ -n "$remote" ] || TERM=xterm hsh-shell $HASHERDIR
		[ -n "$remote" ] && TERM=xterm ssh -t $remote hsh-shell $HASHERDIR
		exit 0
		;;
    clean)
		[ -n "$remote" ] || hsh --cleanup-only $verbose $HASHERDIR
		[ -n "$remote" ] && ssh $remote hsh --cleanup-only $verbose $HASHERDIR
		exit 0
		;;
	install)
		[ -n "$remote" ] || hsh-install $verbose $HASHERDIR $inst_pkgs
		[ -n "$remote" ] && ssh $remote hsh-install $verbose $HASHERDIR $inst_pkgs
		exit 0
		;;
esac

[ -z "$target" ] && target="$(load_var target)"
[ -z "$branch" ] && branch="$(load_var branch)"
[ -z "$repo_url" ] && repo_url="$(load_var repo_url)"

package=$(get_package)
[ -n "$package" ] || fatal "no package to build"

echo "Subcmd:" $subcmd
echo "Package:" $package
echo "Profile:" $profile
echo "Branch:" $branch
echo "Target:" $target
echo "Remote:" $remote
echo "apt-repo:" "rpm $repo_url $branch/$target classic"
echo "Verbose:" "$verbose"

case "$subcmd" in
	build) build 0
		;;
	rebuild) build 1
		;;
esac

exit 0
