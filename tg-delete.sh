#!/bin/sh
# TopGit - A different patch queue manager
# (c) Petr Baudis <pasky@suse.cz>  2008
# GPLv2

force= # Whether to delete non-empty branch, or branch where only the base is left.
name=


## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	-f)
		force=1;;
	-*)
		echo "Usage: tg [...] delete [-f] NAME" >&2
		exit 1;;
	*)
		[ -z "$name" ] || die "name already specified ($name)"
		name="$arg";;
	esac
done


## Sanity checks

[ -n "$name" ] || die "no branch name specified"
branchrev="$(git rev-parse --verify "$name" 2>/dev/null)" ||
	if [ -n "$force" ]; then
		info "invalid branch name: $name; assuming it has been deleted already"
	else
		die "invalid branch name: $name"
	fi
baserev="$(git rev-parse --verify "refs/top-bases/$name" 2>/dev/null)" ||
	die "not a TopGit topic branch: $name"
! git symbolic-ref HEAD >/dev/null || [ "$(git symbolic-ref HEAD)" != "refs/heads/$name" ] ||
	die "cannot delete your current branch"

[ -z "$force" ] && { branch_empty "$name" || die "branch is non-empty: $name"; }

tg summary --deps | while read _branch _deps; do
	case "$name" in
		" $_deps " )
			_to_update="$_to_update $_branch"
		;;
	esac
	[ "$_branch" = "$name" ] && { _deps_to_push="$(echo "$_deps" | tr ' ' '\n')"; break; }
done

for _b in $(tg summary -t 2> /dev/null); do
	case "_b" in
		" $_to_update " )
			:
		;;
		* )
			continue
		;;
	esac
	git checkout $_b || die "Can't checkout $_b"

	cat .topdeps | while read _dep; do
		[ $_dep = $name ] && echo "$_deps_to_push" || echo "$_dep"
	done > /tmp/temp-topgit
	mv /tmp/temp-topgit .topdeps
	git add .topdeps
	git commit -m "TopGIT: updating dependecies from $name to $_deps_to_push"
	tg update || die "Update of $_b failed; fix it manually"
done

# Quick'n'dirty check whether branch is required
#[ -z "$force" ] && { tg summary --deps | cut -d' ' -f2- | tr ' ' '\n' | fgrep -xq -- "$name" && die "some branch depends on $name"; }

## Wipe out

git update-ref -d "refs/top-bases/$name" "$baserev"
[ -z "$branchrev" ] || git update-ref -d "refs/heads/$name" "$branchrev"

# vim:noet
