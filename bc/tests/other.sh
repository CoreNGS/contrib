#! /bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2018-2021 Gavin D. Howard and contributors.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

set -e

script="$0"
testdir=$(dirname "$script")

. "$testdir/../scripts/functions.sh"

# Command-line processing.
if [ "$#" -ge 2 ]; then

	d="$1"
	shift

	extra_math="$1"
	shift

else
	err_exit "usage: $script dir extra_math [exec args...]" 1
fi

if [ "$#" -lt 1 ]; then
	exe="$testdir/../bin/$d"
else
	exe="$1"
	shift
fi

if [ "$d" = "bc" ]; then
	halt="quit"
else
	halt="q"
fi

# For tests later.
num=100000000000000000000000000000000000000000000000000000000000000000000000000000
numres="$num"
num70="10000000000000000000000000000000000000000000000000000000000000000000\\
0000000000"

# Set stuff for the correct calculator.
if [ "$d" = "bc" ]; then
	halt="halt"
	opt="x"
	lopt="extended-register"
	line_var="BC_LINE_LENGTH"
else
	halt="q"
	opt="l"
	lopt="mathlib"
	line_var="DC_LINE_LENGTH"
	num="$num pR"
fi

# I use these, so unset them to make the tests work.
unset BC_ENV_ARGS
unset BC_LINE_LENGTH
unset DC_ENV_ARGS
unset DC_LINE_LENGTH

set +e

printf '\nRunning %s quit test...' "$d"

printf '%s\n' "$halt" | "$exe" "$@" > /dev/null 2>&1

checktest_retcode "$d" "$?" "quit"

# bc has two halt or quit commands, so test the second as well.
if [ "$d" = bc ]; then

	printf '%s\n' "quit" | "$exe" "$@" > /dev/null 2>&1

	checktest_retcode "$d" "$?" quit

	two=$("$exe" "$@" -e 1+1 -e quit)

	checktest_retcode "$d" "$?" quit

	if [ "$two" != "2" ]; then
		err_exit "$d failed test quit" 1
	fi
fi

printf 'pass\n'

base=$(basename "$exe")

printf 'Running %s environment var tests...' "$d"

if [ "$d" = "bc" ]; then

	export BC_ENV_ARGS=" '-l' '' -q"

	printf 's(.02893)\n' | "$exe" "$@" > /dev/null

	checktest_retcode "$d" "$?" "environment var"

	"$exe" "$@" -e 4 > /dev/null

	err="$?"
	checktest_retcode "$d" "$?" "environment var"

	printf 'pass\n'

	printf 'Running keyword redefinition test...'

	unset BC_ENV_ARGS

	redefine_res="$testdir/bc_outputs/redefine.txt"
	redefine_out="$testdir/bc_outputs/redefine_results.txt"

	outdir=$(dirname "$easter_out")

	if [ ! -d "$outdir" ]; then
		mkdir -p "$outdir"
	fi

	printf '5\n0\n' > "$redefine_res"

	"$exe" "$@" --redefine=print -e 'define print(x) { x }' -e 'print(5)' > "$redefine_out"

	checktest "$d" "$err" "keyword redefinition" "$redefine_res" "$redefine_out"

	"$exe" "$@" -r "abs" -r "else" -e 'abs = 5;else = 0' -e 'abs;else' > "$redefine_out"

	checktest "$d" "$err" "keyword redefinition" "$redefine_res" "$redefine_out"

	if [ "$extra_math" -ne 0 ]; then

		"$exe" "$@" -lr abs -e "perm(5, 1)" -e "0" > "$redefine_out"

		checktest "$d" "$err" "keyword not redefined in builtin library" "$redefine_res" "$redefine_out"

	fi

	"$exe" "$@" -r "break" -e 'define break(x) { x }' 2> "$redefine_out"
	err="$?"

	checkerrtest "$d" "$err" "keyword redefinition error" "$redefine_out" "$d"

	"$exe" "$@" -e 'define read(x) { x }' 2> "$redefine_out"
	err="$?"

	checkerrtest "$d" "$err" "Keyword redefinition error without BC_REDEFINE_KEYWORDS" "$redefine_out" "$d"

	printf 'pass\n'

else

	export DC_ENV_ARGS="'-x'"
	export DC_EXPR_EXIT="1"

	printf '4s stuff\n' | "$exe" "$@" > /dev/null

	checktest_retcode "$d" "$?" "environment var"

	"$exe" "$@" -e 4pR > /dev/null

	checktest_retcode "$d" "$?" "environment var"

	printf 'pass\n'

	set +e

	# dc has an extra test for a case that someone found running this easter.dc
	# script. It went into an infinite loop, so we want to check that we did not
	# regress.
	printf 'three\n' | cut -c1-3 > /dev/null
	err=$?

	if [ "$err" -eq 0 ]; then

		printf 'Running dc Easter script...'

		easter_res="$testdir/dc_outputs/easter.txt"
		easter_out="$testdir/dc_outputs/easter_results.txt"

		outdir=$(dirname "$easter_out")

		if [ ! -d "$outdir" ]; then
			mkdir -p "$outdir"
		fi

		printf '4 April 2021\n' > "$easter_res"

		"$testdir/dc/scripts/easter.sh" "$exe" 2021 "$@" | cut -c1-12 > "$easter_out"
		err="$?"

		checktest "$d" "$err" "Easter script" "$easter_res" "$easter_out"

		printf 'pass\n'
	fi

fi

out1="$testdir/../.log_$d.txt"
out2="$testdir/../.log_${d}_test.txt"

printf 'Running %s line length tests...' "$d"

printf '%s\n' "$numres" > "$out1"

export "$line_var"=80
printf '%s\n' "$num" | "$exe" "$@" > "$out2"

checktest "$d" "$?" "environment var" "$out1" "$out2"

printf '%s\n' "$num70" > "$out1"

export "$line_var"=2147483647
printf '%s\n' "$num" | "$exe" "$@" > "$out2"

checktest "$d" "$?" "environment var" "$out1" "$out2"

printf 'pass\n'

printf 'Running %s arg tests...' "$d"

f="$testdir/$d/add.txt"
exprs=$(cat "$f")
results=$(cat "$testdir/$d/add_results.txt")

printf '%s\n%s\n%s\n%s\n' "$results" "$results" "$results" "$results" > "$out1"

"$exe" "$@" -e "$exprs" -f "$f" --expression "$exprs" --file "$f" -e "$halt" > "$out2"

checktest "$d" "$?" "arg" "$out1" "$out2"

printf '%s\n' "$halt" | "$exe" "$@" -- "$f" "$f" "$f" "$f" > "$out2"

checktest "$d" "$?" "arg" "$out1" "$out2"

if [ "$d" = "bc" ]; then
	printf '%s\n' "$halt" | "$exe" "$@" -i > /dev/null 2>&1
fi

printf '%s\n' "$halt" | "$exe" "$@" -h > /dev/null
checktest_retcode "$d" "$?" "arg"
printf '%s\n' "$halt" | "$exe" "$@" -P > /dev/null
checktest_retcode "$d" "$?" "arg"
printf '%s\n' "$halt" | "$exe" "$@" -R > /dev/null
checktest_retcode "$d" "$?" "arg"
printf '%s\n' "$halt" | "$exe" "$@" -v > /dev/null
checktest_retcode "$d" "$?" "arg"
printf '%s\n' "$halt" | "$exe" "$@" -V > /dev/null
checktest_retcode "$d" "$?" "arg"

"$exe" "$@" -f "saotehasotnehasthistohntnsahxstnhalcrgxgrlpyasxtsaosysxsatnhoy.txt" > /dev/null 2> "$out2"
err="$?"

checkerrtest "$d" "$err" "invalid file argument" "$out2" "$d"

"$exe" "$@" "-$opt" -e "$exprs" > /dev/null 2> "$out2"
err="$?"

checkerrtest "$d" "$err" "invalid option argument" "$out2" "$d"

"$exe" "$@" "--$lopt" -e "$exprs" > /dev/null 2> "$out2"
err="$?"

checkerrtest "$d" "$err" "invalid long option argument" "$out2" "$d"

"$exe" "$@" "-u" -e "$exprs" > /dev/null 2> "$out2"
err="$?"

checkerrtest "$d" "$err" "unrecognized option argument" "$out2" "$d"

"$exe" "$@" "--uniform" -e "$exprs" > /dev/null 2> "$out2"
err="$?"

checkerrtest "$d" "$err" "unrecognized long option argument" "$out2" "$d"

"$exe" "$@" -f > /dev/null 2> "$out2"
err="$?"

checkerrtest "$d" "$err" "missing required argument to short option" "$out2" "$d"

"$exe" "$@" --file > /dev/null 2> "$out2"
err="$?"

checkerrtest "$d" "$err" "missing required argument to long option" "$out2" "$d"

"$exe" "$@" --version=5 > /dev/null 2> "$out2"
err="$?"

checkerrtest "$d" "$err" "given argument to long option with no argument" "$out2" "$d"

"$exe" "$@" -: > /dev/null 2> "$out2"
err="$?"

checkerrtest "$d" "$err" "colon short option" "$out2" "$d"

"$exe" "$@" --: > /dev/null 2> "$out2"
err="$?"

checkerrtest "$d" "$err" "colon long option" "$out2" "$d"

printf 'pass\n'

printf 'Running %s directory test...' "$d"

"$exe" "$@" "$testdir" > /dev/null 2> "$out2"
err="$?"

checkerrtest "$d" "$err" "directory" "$out2" "$d"

printf 'pass\n'

printf 'Running %s binary file test...' "$d"

bin="/bin/sh"

"$exe" "$@" "$bin" > /dev/null 2> "$out2"
err="$?"

checkerrtest "$d" "$err" "binary file" "$out2" "$d"

printf 'pass\n'

printf 'Running %s binary stdin test...' "$d"

cat "$bin" | "$exe" "$@" > /dev/null 2> "$out2"
err="$?"

checkerrtest "$d" "$err" "binary stdin" "$out2" "$d"

printf 'pass\n'

if [ "$d" = "bc" ]; then

	printf 'Running %s limits tests...' "$d"
	printf 'limits\n' | "$exe" "$@" > "$out2" /dev/null 2>&1

	checktest_retcode "$d" "$?" "limits"

	if [ ! -s "$out2" ]; then
		err_exit "$d did not produce output on the limits test" 1
	fi

	exec printf 'pass\n'

fi
