#!/bin/bash -uef

usage()
{
	cat <<-EOF
	alt <subcmd> [options]...
	EOF
	exit 0
}

run()
{
    echo "Running: '$@'"
    "$@" 2>&1
}

warn()
{
    echo "warning: $@"
}

fatal()
{
    echo "fatal: $@"
    exit 1
}

canon_path()
{
    echo "$(readlink -m $1)"
}

get_package()
{
    local pkg_name=
	local pkg_dir="${1:-}"
	
	[ -d "$pkg_dir" ] && pushd $pkg_dir &>/dev/null
	
    pkg_name="$(gear --describe 2>/dev/null | cut -d' ' -f1)"
    [ -n "$pkg_name" ] || \
		pkg_name="$(basename $(git rev-parse --show-toplevel 2>/dev/null) 2>/dev/null)"
	
	[ -d "$pkg_dir" ] && popd &>/dev/null
	
    echo "$pkg_name"
}

check_url()
{
    [ "$(curl -L -s -o /dev/null -I -w "%{http_code}" $1)" = "200" ] && echo "1"
}
