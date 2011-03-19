#!/bin/sh
# TopGit - A different patch queue manager
# (c) Petr Baudis <pasky@suse.cz>  2008
# GPLv2

force= # Whether to delete non-empty branch, or branch where only the base is left.
name= # Branch to delete
to_update= # Branches that depend on $name and need dependencies adjusted
deps_to_push= # Dependencies from deleted brach
current= # Branch we are currently on


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

current="$(git symbolic-ref HEAD 2>/dev/null | sed 's#^refs/\(heads\|top-bases\)/##')"
[ -n "$current" ] || die "cannot return to detached tree; switch to another branch"

! git symbolic-ref HEAD >/dev/null || [ "$(git symbolic-ref HEAD)" != "refs/heads/$name" ] ||
	die "cannot delete your current branch"

[ -z "$force" ] && { branch_empty "$name" || die "branch is non-empty: $name"; }

depsfile="$(get_temp tg-delete-deps)"
tg summary --deps > "$depsfile" 2>/dev/null

while read branch deps; do
	case " $deps " in
		*" $name "* )
			to_update="$to_update $branch"
		;;
	esac
	[ "$branch" = "$name" ] && deps_to_push="$deps_to_push $branch"
done < "$depsfile"

deps_to_push="$(echo "$deps_to_push" | tr ' ' '\n') | sort -u"

for b in $(tg summary -t 2> /dev/null); do
	case " $to_update " in
		*" $b "* )
			:
		;;
		* )
			continue
		;;
	esac
	git checkout -q "$b" || die "Can't checkout $b"

	cat .topdeps | while read dep; do
		[ $dep = $name ] && echo "$deps_to_push" || echo "$dep"
	done > "$depsfile"
	cat "$depsfile" > .topdeps
	git add .topdeps
	git commit -m "TopGIT: updating dependecies from $name to $deps_to_push"
	tg update || die "Update of $b failed; fix it manually"
done

git checkout -q "$current" || die "failed to return to $current"

# Quick'n'dirty check whether branch is required
#[ -z "$force" ] && { tg summary --deps | cut -d' ' -f2- | tr ' ' '\n' | fgrep -xq -- "$name" && die "some branch depends on $name"; }

## Wipe out

git update-ref -d "refs/top-bases/$name" "$baserev"
[ -z "$branchrev" ] || git update-ref -d "refs/heads/$name" "$branchrev"

# vim:noet
