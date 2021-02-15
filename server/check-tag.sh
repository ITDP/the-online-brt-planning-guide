major=0 
minor=0

#Checks if $0 is greater than cur major/minor
function compare_versions()
{	
	#eliminate "v" char; on zsh string index starts @1!
	local cur_substr=${1:1}
	local cur_major=${cur_substr%.*}
	local cur_minor=${cur_substr#*.}
	local ret=""
	
	if [[ cur_major -gt major ]]
		then major=$cur_major ; minor=$cur_minor
	elif [[ cur_major -eq major ]] && [[ cur_minor -gt minor ]]
		then major=$cur_major ; minor=$cur_minor
	fi

	return 0	
}

#null string or 0
if [[ ${#ROBRT_IS_PR} -eq 0 ]] || [[ $ROBRT_IS_PR -eq 0 ]]
	then for t in $(git tag --list 'v*.*') 
	do 
	if [[ "$t" =~ ^[v\d+\.\d+]  ]]
		then compare_versions $t
	fi
	done
fi

if [[ major -gt 0 ]] || [[ minor -gt 0 ]]
	then TAG=v$major.$minor
else
	TAG=""
fi
export TAG=$TAG
