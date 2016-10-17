set -e

ok=0
fail=1
exts=$(cat .gitattributes | grep 'filter=lfs' | sed -e 's/^\*\.\([^ ]\+\).\+/\1/')

function check_for_lfs_files_on_working_tree()
{
	ret=$ok
	for ext in $exts
	do
		find . -name \*.$ext -type f -exec file {} \; | grep -v 'ASCII text' \
			&& echo "[31mERROR: rogue $ext files found[0m" && ret=$fail \
			|| echo "Ok: no rogue $ext files found"
	done
	return $ret
}

range=${TRAVIS_COMMIT_RANGE/.../..}
if [ "$range" = "" ]
then
	commits=$TRAVIS_COMMIT
else
	commits=$(git rev-list $range)
fi

if [ "$TRAVIS_PULL_REQUEST" != "false" ]
then
	echo "[34mLooking at the merged working tree[0m"
	check_for_lfs_files_on_working_tree
	status=$?
else
	status=$ok
fi

echo "Looking at commits"
echo $commits
echo "(in reverse chrnological order)"
# TODO fetch all commits or handle missing commits from initial shallow clone

for rev in $commits
do
	echo "[34mChecking commit $rev[0m"
	git checkout --quiet $rev
	check_for_lfs_files_on_working_tree
	if [ "$?" -ne "$ok" ]
	then
		status=$fail
	fi

done

exit $status

