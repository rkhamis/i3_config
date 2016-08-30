#!/usr/bin/env bash


##
## Generate JSON for i3bar
## A replacement for i3status written in bash
## kalterfive
##
## Dependencies:
## mpd, mpc, deadbeef
## skb -- get language
## sensors -- get heating cpu
## acpi -- get battery state
##


#	{{{ Error codes

E_UE=6 # unhandeled event

#	}}}


#	{{{ Colors

color_white='#FFFFFF'
color_green='#00CC00'

color_std='#CCCCCC'
color_waring='#CCCC00'
color_danger='#CC0000'

icon_color='"icon_color":"'$color_white'"'

#	}}}


function iconbyname() {
	local icon=$1
	echo '"icon":"'$HOME/.config/i3/icons/$icon'.xbm"'
}


##
## Fattest processes
##

#function init_topmem() {
#}

function toJson() {
	for process in "$@"; do
		echo '{"full_text":"'$process'","color":"'$color_std'"},'
	done
}

function get_topmem() {
	local count=5
	local proc=(`ps -eo pmem,cmd\
			| sort -k 1 -nr\
			| awk '{print($2);}'\
			| head -$count\
			| sed 's/\/.*\/.*\///g'`)

	topmem=`toJson ${proc[@]}`
}


##
## Kernel version
##

function init_kernel() {
	## JSON output
	local full_text='"full_text":"'`uname -r`'"'
	local color='"color":"'$color_std'"'
	local icon_kernel=`iconbyname arch`
	kernel='{'$full_text','$color','$icon_kernel','$icon_color'},'
}

#function get_kernel() {
#}


##
## State of MPD || DeaDBeeF
##

function init_music() {
	icon_play=`iconbyname play`
	icon_pause=`iconbyname pause`
	icon_stop=`iconbyname stop`
}

function get_music() {
	local color='"color":"'$color_std'"'
	local full_text
	local icon

	state=`deadbeef --nowplaying "%e" | grep ":"`
	if [[ ! "$state" ]]; then
		state=`mpc | grep "-"`
		if [[ ! "$state" ]]; then
#			full_text='"full_text":"OFF"'
#			icon=$icon_stop
			unset music
			return
		else
			state=`mpc | grep "\[..*\]"`
			elapsed=`echo "$state" | awk -F\/ '{print($2);}' | sed 's/.* //'`
			full_text='"full_text":"'$elapsed'"'
			state=`echo "$state" | sed 's/\].*//;s/\[//'`
			case "$state" in
				playing)
					icon=$icon_play
				;;

				paused)
					icon=$icon_pause
				;;
			esac
		fi
	else
		full_text='"full_text":"'$state'"'
		icon=$icon_play
	fi

	music='{'$full_text','$color','$icon','$icon_color'},'
}


##
## Keyboard
##

function init_language() {
	icon_language=`iconbyname kbd`
}

function get_language() {
	language=`skb noloop\
			| head -c 2\
			| tr a-z A-Z`

	## JSON output
	local full_text='"full_text":"'$language'"'
	local color='"color":"'$color_std'"'
	language='{'$full_text','$color','$icon_language','$icon_color'},'
}


##
## Signal Strength
##

function init_csq() {
	# csqd, yes...
	sudo killall csqd
	sudo $HOME/bin/csqd "/dev/ttyUSB2" &

	icon_csq=`iconbyname csq`
}

function get_csq() {
	csq=`cat /tmp/csq.txt`

	## JSON output
	local full_text='"full_text":"'$csq'%"'
	local color='"color":"'$color_std'"'
	csq='{'$full_text','$color','$icon_csq','$icon_color'},'
}


##
## Num Lock state
##

function init_numlock() {
	icon_numlock=`iconbyname numlock`
}

function get_numlock() {
	numlock=`xset q\
			| grep "Num Lock:"\
			| awk '{print($8)}'\
			| tr a-z A-Z`

	## JSON output
	local full_text='"full_text":"'$numlock'"'
	local color='"color":"'$color_std'"'
	numlock='{'$full_text','$color','$icon_numlock','$icon_color'},'
}


##
## Caps Lock state
##

function init_capslock() {
	icon_capslock=`iconbyname capslock`
}

function get_capslock_color() {
	local capslock=$1
	local color0
	local color1

	case "$capslock" in
		"ON")
			color0='"color":"'$color_waring'"'      # text
			color1='"icon_color":"'$color_waring'"' # icon
		;;

		"OFF")
			color0='"color":"'$color_std'"'
			color1='"icon_color":"'$color_white'"'
		;;

		*)
			exit $E_UE
		;;
	esac

	echo "$color0,$color1"
}

function get_capslock() {
	capslock=`xset q\
			| grep "Caps Lock:"\
			| awk '{print($4)}'\
			| tr a-z A-Z`

	## JSON output
	local full_text='"full_text":"'$capslock'"'
	local color=`get_capslock_color $capslock`
	capslock='{'$full_text','$color','$icon_capslock'},'
}


##
## Heating CPU
##

function init_heating_cpu() {
	icon_cpu=`iconbyname cpu`
}

function get_heating() {
	local sensors=`sensors\
			| grep Core\
			| sed 's/\..*//g;s/.*+//g'`

	local heating_cpu=0
	local kernels=0
	for core in $sensors; do
		$((heating_cpu += core))
		$((kernels++))
	done
	$((heating_cpu /= kernels))

	echo "$heating_cpu"
}

function get_heating_color() {
	local heating_cpu=$1
	local color0
	local color1

	case "$heating_cpu" in
		7[0-9])
			color0='"color":"'$color_waring'"'      # text
			color1='"icon_color":"'$color_waring'"' # icon
		;;

		8[0-9] | 9[0-9] | 10[0-5])
			color0='"color":"'$color_danger'"'
			color1='"icon_color":"'$color_danger'"'
		;;

		*)
			color0='"color":"'$color_std'"'
			color1='"icon_color":"'$color_white'"'
		;;
	esac

	echo "$color0,$color1"
}

function get_heating_cpu() {
	heating_cpu=`get_heating`

	## JSON output
	local full_text='"full_text":"'$heating_cpu'°C"'
	local color=`get_heating_color $heating_cpu`
	heating_cpu='{'$full_text','$color','$icon_cpu'},'
}


##
## Brightness level
##

function init_brightness() {
	icon_brightness=`iconbyname sun`
	brightness_path="/sys/class/backlight/intel_backlight"
}

function get_brightness() {
	local brg=`cat $brightness_path/brightness`
	local max_brg=`cat $brightness_path/max_brightness`
	local brightness_level=`echo "scale = 2; $brg * 100 / $max_brg"\
			 | bc`

	## JSON output
	local full_text='"full_text":"'$brightness_level'%"'
	local color='"color":"'$color_std'"'
	brightness='{'$full_text','$color','$icon_brightness','$icon_color'},'
}


##
## Sound state (level and mute)
##

function init_sound() {
	icon_sound_on=`iconbyname sound_on`
	icon_sound_off=`iconbyname sound_off`
}

function get_sound_icon() {
	local sound_state=`amixer get Master\
			| grep 'Mono:'\
			| awk '{print($6);}'`

	case "$sound_state" in
		"[on]")
			echo "$icon_sound_on"
		;;

		"[off]")
			echo "$icon_sound_off"
		;;

		*)
			exit $E_UE
		;;
	esac
}

function get_sound() {
	local sound_level=`amixer get Master\
			| grep 'Mono:'\
			| sed 's/\].*//;s/.*\[//'`
	
	## JSON output
	local full_text='"full_text":"'$sound_level'"'
	local color='"color":"'$color_std'"'
	local icon=`get_sound_icon`
	sound='{'$full_text','$color','$icon','$icon_color'},'
}


##
## Battery level
##

function init_battery_level() {
	icon_battery_charging=`iconbyname "battery/battery_charging"`
	for ((i=0; i <= 100; i++)); do
		local var="icon_battery_$i"
		local full_path=`iconbyname "battery/battery_$i"`
		declare -g "$var=$full_path"
	done
}

function get_battery_color() {
	local battery_level=$1
	local color0
	local color1

	case "$battery_level" in
		[0-9] | 10)
			color0='"color":"'$color_danger'"'      # text
			color1='"icon_color":"'$color_danger'"' # icon
		;;

		1[1-9] | 2[0-5])
			color0='"color":"'$color_waring'"'
			color1='"icon_color":"'$color_waring'"'
		;;

		9[5-9] | 100)
			local state=`cat /sys/class/power_supply/BAT0/status`
			if [[ "$state" == "Charging" ]]; then
				color0='"color":"'$color_green'"'
				color1='"icon_color":"'$color_green'"'
			else
				color0='"color":"'$color_std'"'
				color1='"icon_color":"'$color_white'"'
			fi
		;;

		*)
			color0='"color":"'$color_std'"'
			color1='"icon_color":"'$color_white'"'
		;;
	esac

	echo "$color0,$color1"
}

function get_battery_icon() {
	local battery_level=$1
	local state=`acpi\
			| awk '{print($3);}'\
			| sed 's/,//g'`

	case "$state" in
		Discharging)
			case "$battery_level" in
				[0-5])           echo "$icon_battery_0"   ;;
				[6-9] | 1[0-5])  echo "$icon_battery_10"  ;;
				1[6-9] | 2[0-5]) echo "$icon_battery_20"  ;;
				2[6-9] | 3[0-5]) echo "$icon_battery_30"  ;;
				3[6-9] | 4[0-5]) echo "$icon_battery_40"  ;;
				4[6-9] | 5[0-5]) echo "$icon_battery_50"  ;;
				5[6-9] | 6[0-5]) echo "$icon_battery_60"  ;;
				6[6-9] | 7[0-5]) echo "$icon_battery_70"  ;;
				7[6-9] | 8[0-5]) echo "$icon_battery_80"  ;;
				8[6-9] | 9[0-5]) echo "$icon_battery_90"  ;;
				9[6-9] | 100)    echo "$icon_battery_100" ;;
			esac
		;;

		Charging)
			echo "$icon_battery_charging"
		;;

		*)
			exit $E_UE
		;;
	esac
}

function get_battery_level() {
#	battery_level=`cat /sys/class/power_supply/BAT0/capacity`
	battery_level=`acpi\
			| sed 's/%,.*//g;s/.*\s//g'`

	## JSON output
	local full_text='"full_text":"'$battery_level'%"'
	local color=`get_battery_color $battery_level`
	local icon_battery=`get_battery_icon $battery_level`
	battery_level='{'$full_text','$color','$icon_battery'},'
}


##
## Date and time
##

function init_date() {
	icon_date=`iconbyname cal`
}

function get_date() {
	date=`date +%a\ %d.%m.%Y\
			| tr a-z A-Z`

	## JSON output
	local full_text='"full_text":"'$date'"'
	local color='"color":"'$color_std'"'
	date='{'$full_text','$color','$icon_date','$icon_color'},'
}

## The last block
function get_time() {
	time=`date +%H:%M:%S`

	# JSON output
	local full_text='"full_text":"'$time' "'
	local color='"color":"'$color_std'"'
	time='{'$full_text','$color'}'
}


blocks=(
#	[0]=topmem
	[10]=kernel
	[20]=music
	[30]=language
	[40]=numlock
#	[50]=capslock
#	[60]=csq
	[70]=heating_cpu
#	[80]=brightness
	[90]=sound
	[100]=battery_level
	[110]=date
	[120]=time
)

unset func_list
bar='['
for block in ${blocks[@]}; do
	init_$block 2> /dev/null
	func_list+=" get_$block"
	bar+='${'$block':-}'
done
bar+="],"

echo '{"version":1}['
while [ 1 ]; do
	for func in $func_list; do
		$func 2> /dev/null
	done
	eval echo -e \"${bar//\\/\\\\}\" || exit

	sleep 0.5
done
