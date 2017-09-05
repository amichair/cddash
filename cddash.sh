# cddash ver 0.1
#
# Maintains a running history of last 10 visited dirs and allows quick naviation.
# Adds the following commands:
# cd-? shows list
# cd-1 cd to last dir (just like "cd -")
# cd-2 cd to 2nd to last dir 
# cd-9 cd to 9th to last dir

# To install, add the following line to your .bashrc
# source cddash.sh

#####################################################

###
#TODO
# add color to cd-?
# Create script for other shells / cross shell compatibilty


### 
# "Private" functions and data

# holds the directory history
_CDD_log=()

_CDD_docd() {
	cd "${_CDD_log[$1]}";
}

_CDD_newdirpwd() {
	[[ $PWD == ${_CDD_log[0]} ]] && return 

	local -i i
	for ((i=10-1; i>0; i--)); do
		_CDD_log[i]=${_CDD_log[$i-1]}
	done
	_CDD_log[0]=$PWD
}

_CDD_listlog() {
	local -i i
	for ((i=1; i<10; i++)); do
		if [ "x${_CDD_log[$i]}" != "x" ]; then
			echo cd-$i : ${_CDD_log[$i]}
		fi
	done
}

#####
# Setup the hook (i.e how the shell notifys the code that a new dir has been reached)
# there several options:

# can substitue cd. either with an alias or like below.
# pros: code runs only at cds. cons: doesnt get other ways of cding like pushd etc
#function cd () { builtin cd "$@" && _CDD_newdirpwd; }

# can hook the prompt.
# pros: captures any change in dir. con (or feature): if many cds happen in the same command, they won't be _CDD_logged. (example: cd aaa; cd bbb; cd-2;) also runs every prompt
export PROMPT_COMMAND=_CDD_newdirpwd;$PROMPT_COMMAND

# in TCSH there is cwdcmd. in zch there is cmpwd()

#####
# Setup public function (i.e the used shell commands)
cd-?() { _CDD_listlog; }
cd-0() { _CDD_docd 0; } # doesn't do anything. For completetion
cd-1() { _CDD_docd 1; }
cd-2() { _CDD_docd 2; }
cd-3() { _CDD_docd 3; }
cd-4() { _CDD_docd 4; }
cd-5() { _CDD_docd 5; }
cd-6() { _CDD_docd 6; }
cd-7() { _CDD_docd 7; }
cd-8() { _CDD_docd 8; }
cd-9() { _CDD_docd 9; }


### Startup

# start off with PWD
_CDD_newdirpwd;
