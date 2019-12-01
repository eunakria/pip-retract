#!/bin/bash

# PiP window name. May change based on your system language and PiP-delivering
# application. For Chromium/Spanish:
PIP_NAME='Imagen en imagen'

# Allowed heights for a PiP window, in pixels.
ALLOWED_SIZES=(288 384 480)
DEFAULT_SIZE=$ALLOWED_SIZES[2]

# X and Y padding, and padding on each side of the screen.
X_PAD=32
Y_PAD=32
:;      TOP_PAD=00
:; LT_PAD=00; RT_PAD=00
:;      BOT_PAD=32

getscr () {
	[[ -n $disp_x ]] && return
	read -r disp_x disp_y <<< `xrandr | \
		grep 'Screen 0' | \
		awk '{print $8 " " ($10 + 0) }'`
}

getwin () {
	local xwi=`xwininfo -name "$PIP_NAME"`
	win_info=`echo "$xwi" | grep -- '-geometry' | cut -d' ' -f4`

	read -r win_x win_y <<< $(echo "$xwi" | \
		grep 'Absolute' | \
		cut -d' ' -f7 | \
		tr '\n' ' ')

	#read -r width height <<< $(echo "$win_info" | \
	#	sed 's/[-+]/x/g' | \
	#	awk -F 'x' '{print $1 " " $2}')
	read -r width height <<< $(echo "$win_info" | \
		sed 's/[-+x]/ /g' | \
		cut -d' ' -f1,2)

	getscr
	[[ $win_x -lt 0 || $(( win_x + width )) -gt $disp_x ]] &&
		hidden=-hidden
	[[ $(( win_x + width )) -ge $(( disp_x - X_PAD - RT_PAD )) ]] &&
		xside=east ||
		xside=west
	[[ $(( win_y + height )) -ge $(( disp_y - Y_PAD - BOT_PAD )) ]] &&
		yside=south ||
		yside=north
	align=$yside$xside$hidden

	id=`echo "$xwi" | grep 'Window id' | cut -d' ' -f4`
}

shrink () {
	getwin
	size=1
	while [[ ${ALLOWED_SIZES[$size]} -lt $height && $size -lt ${#ALLOWED_SIZES[@]} ]]; do
		: $(( size ++ ))
	done
	[[ size -ne 0 ]] && : $(( size -- ))
	size=${ALLOWED_SIZES[$size]}
	xdotool windowsize "$id" "$size" "$size"
	$(echo "$align" | sed 's/-/ /')
}

enlarge () {
	getwin
	size=$(( ${#ALLOWED_SIZES[@]} - 1 ))
	while [[ ${ALLOWED_SIZES[$size]} -gt $height && $size -gt 0 ]]; do
		: $(( size -- ))
	done
	[[ size -lt $(( ${#ALLOWED_SIZES[@]} - 1 )) ]] && : $(( size ++ ))
	size=${ALLOWED_SIZES[$size]}
	xdotool windowsize "$id" "$size" "$size"
	$(echo "$align" | sed 's/-/ /')
}

northwest () {
	getwin
	[[ $1 == hidden ]] && hide=$width
	xdotool windowmove "$id" \
		$(( LT_PAD + X_PAD - hide )) \
		$(( TOP_PAD + Y_PAD ))
}

northeast () {
	getwin
	[[ $1 == hidden ]] && hide=$width
	xdotool windowmove "$id" \
		$(( disp_x - width - RT_PAD - X_PAD + hide )) \
		$(( TOP_PAD + Y_PAD ))
}

southwest () {
	getwin
	[[ $1 == hidden ]] && hide=$width
	xdotool windowmove "$id" \
		$(( LT_PAD + X_PAD - hide)) \
		$(( disp_y - height - BOT_PAD - Y_PAD ))
}

southeast () {
	getwin
	[[ $1 == hidden ]] && hide=$width
	xdotool windowmove "$id" \
		$(( disp_x - width - RT_PAD - X_PAD + hide)) \
		$(( disp_y - height - BOT_PAD - Y_PAD ))
}

show () {
	getwin
	${align%-**}
}

hide () {
	getwin
	${align%-**} hidden
}

shift-cw () {
	getwin

	# Test if currently hidden
	case $align in
	*hidden*) hidden=hidden
	esac

	case $align in
	northwest*) northeast $hidden ;;
	northeast*) southeast $hidden ;;
	southeast*) southwest $hidden ;;
	southwest*) northwest $hidden ;;
	esac
}

shift-ccw () {
	getwin

	case $align in
	*hidden*) hidden=hidden
	esac

	case $align in
	northwest*) southwest $hidden ;;
	southwest*) southeast $hidden ;;
	southeast*) northeast $hidden ;;
	northeast*) northwest $hidden ;;
	esac
}

toggle-vis () {
	getwin
	case $align in
	*hidden*) show ;;
	*) hide ;;
	esac
}

ver () {
	[[ -z $2 || $2 == hidden ]] || usage
}

usage () {
A=$'\e[1;33;93m'
B=$'\e[1;31;91m'
C=$'\e[1;35;95m'
D=$'\e[1;32;92m'
E=$'\e[1;37;97m'
X=$'\e[1m'
Z=$'\e[0m'
cat >&2 << EOF
pip-retract.sh
(c) 2019 McBoat

${X}Usage:$Z
   $A shrink     shr $Z Shrink the PiP window to the next smaller size.
   $A enlarge    en $Z  Enlarge the PiP window to the next larger size.
   $B northwest  nw $Z  Move the PiP window to the northwest of the screen.
   $B northeast  ne $Z  Move the PiP window to the northeast of the screen.
   $B southwest  sw $Z  Move the PiP window to the southwest of the screen.
   $B southeast  se $Z  Move the PiP window to the southeast of the screen.
   $C show       s $Z   Show the PiP window.
   $C hide       h $Z   Hide the PiP window.
   $D shift-cw   cw $Z  Move the PiP window to the next space clockwise.
                    For example, northeast -> southeast.
   $D shift-ccw  ccw $Z Move the PiP window to the next space counterclockwise.
                    For example, northeast -> northwest.
   $D toggle-vis tv $Z  Either show or hide the PiP window.

northwest, northeast, southwest and southeast all accept a second parameter,
hidden, to make invocation more concise. For example,

    ${X}pip-retract.sh$Z nw hidden

will position the PiP window at the northwest and hide it.
EOF
}

case $1 in
getwin) getwin; echo $align ;;
shrink|shr)    shrink ;;
enlarge|en)    enlarge ;;
northwest|nw)  ver $2 && northwest $2 ;;
northeast|ne)  ver $2 && northeast $2 ;;
southwest|sw)  ver $2 && southwest $2 ;;
southeast|se)  ver $2 && southeast $2 ;;
show|s)        show ;;
hide|h)        hide ;;
shift-cw|cw)   shift-cw ;;
shift-ccw|ccw) shift-ccw ;;
toggle-vis|tv) toggle-vis ;;
*)             usage ;;
esac
