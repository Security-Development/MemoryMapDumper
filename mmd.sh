#!/bin/bash

SCRIPT_PATH="$0"
target_pid=""

trap 'kill $!; exit' SIGINT

echo "MMB(Memory Map Dump)"
echo "$SCRIPT_PATH <device_name> <pid> <region_name>"

function show_progress() {
    while true; do
        printf "Dumping"
        for i in {1..5}; do
            printf "."
            sleep 0.5
        done
        printf "\r"
        tput el
    done
}

input_pid() {
    while true; do
        clear
        echo -ne "\rMatches: \n$matched_index\n\n\rPID > $target_pid" 
        while read -r pid pname; do
            pid_list+=("$pid")
            pname_list+=("$pname")
        done < <(adb -s "$target_device" shell ps | awk 'NR>1 {print $2, $9}')
        
        if read -rsn1 char; then  
            if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
                if [[ -n "$target_pid" ]]; then
                    target_pid="${target_pid%?}"
                fi
            elif [[ -z "$char" ]]; then 
                    if [[ ! "$target_pid" =~ ^[0-9]+$ ]]; then
                        echo
                        echo "Searching for PID of process: $target_pid"
                        target_pid="$(adb -s "$target_device" shell pidof "$target_pid")"
                        if [[ -z "$target_pid" ]]; then
                            echo "No process found with name: $target_pid"
                            exit 1
                        fi
                    fi
                break
            else
                target_pid+="$char"
            fi
 

            matched_index=""
            if [[ -n "$target_pid" ]]; then 
                for i in "${!pid_list[@]}"; do
                    if [[ "${pid_list[$i]}" == *"$target_pid"* || "${pname_list[$i]}" == *"$target_pid"* ]]; then
                        matched_index="$matched_index ${pid_list[$i]} : ${pname_list[$i]}\n"
                    fi
                done
            fi

            pid_list=()
            pname_list=()
        fi
    done
}

entry() {
    clear
    while true; do
        device_names=()
        device_statuses=()

        while read -r device_name device_status; do
            if [ "$device_name" != "List" ]; then
                device_names+=("$device_name")
                device_statuses+=("$device_status")
            fi
        done < <(adb devices)

        columns=3 
        for ((i = 0; i < ${#device_names[@]} - 1; i++)); do
            echo -n "[$i] (${device_names[$i]}, ${device_statuses[$i]})"
            
            if (( i == ${#device_names[@]} - 2 )); then
                echo
            else
                if (( (i + 1) % columns == 0 )); then
                    echo 
                else
                    echo -n " | " 
                fi
            fi
        done

        echo -n "Enter index > "
        read -r index

        if [ "${device_statuses[$index]}" != "device" ]; then
            echo ""Invalid index input.
            continue
        fi
        break
    done

    target_device=${device_names[$index]}
    echo "$target_device device can be attached!!!"

    echo "A getting the process list of device..."

    clear 
    input_pid
    
    echo
    echo "# Target PID = $target_pid"

    echo -ne "Target Region > "
    read -r target_region

    echo "# Target Region = $target_region"

    echo "# Start scanning /proc$target_pid/maps in $target_device..."

    count=0
    target_map_list=()
    temp_file=$(mktemp)

    echo "[ Map File Parse Task run ]"

    adb -s "$target_device" shell su -c "cat /proc/$target_pid/maps" | awk '{
        split($1, addr, "-");
        start_address = addr[1];
        end_address = addr[2];

        path = "";  
        if ($6 == "") {
            path = "N/A";
        } else {
            for (i = 6; i <= NF; i++) {
                path = path (i > 6 ? " " : "") $i; 
            }
        }

        print start_address, end_address, path;
    }' > "$temp_file"

    while read -r start_address end_address path; do
        if [ "$target_region" == "$path" ]; then
            start_address_decimal=$(printf "%d" 0x"$start_address")
            map_size=$((0x$end_address-0x$start_address))
            echo "--------[$target_region Found!!!]--------"
            target_map_list+=("$path,$start_address_decimal,$map_size")
        fi
    done < "$temp_file"

    rm "$temp_file"

    echo "[ Memory Dump Task run ]"

    for item in "${target_map_list[@]}"; do
        path=$(echo "$item" | cut -d',' -f1)
        address=$(echo "$item" | cut -d',' -f2)
        size=$(echo "$item" | cut -d',' -f3)
        echo "Path: ${path}"
        show_progress & 
        adb -s "${target_device}" shell su -c "dd if=/proc/${target_pid}/mem skip=${address} count=${size} bs=1" > "$(basename "$path")_${count}.bin"
        kill $!
        tput el
        echo "Done."
        count=$((count + 1)) 
    done
}

entry
