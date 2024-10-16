#!/bin/bash

SO_FIXER=/Volumes/case_sensitive/tools/SoFixer64
USAGE_SLEEP_TIME=1.5
target_pid=""
target_device=""


trap 'kill $!; exit' SIGINT

usage() {
    clear
    echo "       MMB(Memory Map Dump)      "
    echo "|-------------------------------|"
    echo "| 1) Memory Dump Task Run       |"
    echo "| 2) Merge Task Run             |"
    echo "| 3) SO FIX                     |"
    echo "| 4) usage                      |"
    echo "|-------------------------------|"
}

show_progress() {
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
                            return
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

dump_task() {
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
            echo "Found $target_region !!!"
            target_map_list+=("$path,$start_address_decimal,$map_size")
        fi
    done < "$temp_file"

    rm "$temp_file"

    dumped_files=()

    for item in "${target_map_list[@]}"; do
        path=$(echo "$item" | cut -d',' -f1)
        base_name=$(basename "$path")
        address=$(echo "$item" | cut -d',' -f2)
        size=$(echo "$item" | cut -d',' -f3)
        echo "Path: ${path}"
        show_progress & 
        disown
        adb -s "${target_device}" shell su -c "dd if=/proc/${target_pid}/mem skip=${address} count=${size} bs=1" > "${base_name}_${count}.bin"
        kill $!
        tput el 
        echo "Done."
        dumped_files+=("${base_name}_${count}.bin")
        count=$((count + 1)) 
    done
    sleep $USAGE_SLEEP_TIME
    usage
    target_pid=""
    target_device=""
}

merge_task() {
    merge_target_files=()

    echo "To merge [app_process64_0.so, app_process64_1.so], please enter app_process64:"
    echo -n "Input Path > "
    read -r target_name

    echo "# Files to be merged"
    echo "----------------------------"
    for file in "${target_name}_"[0-9]*.bin; do
        if [[ -e $file ]]; then
            echo "+ $file"
            merge_target_files+=("$file")
        fi
    done

    if [ ! ${#merge_target_files[@]} -gt 0 ]; then
        echo " (Not Found)"
    fi
    echo "----------------------------"


    if [ ${#merge_target_files[@]} -gt 0 ]; then
        base_name="${target_name}_merged"
        echo "Merging files: [ ${merge_target_files[*]} ]"
        cat "${merge_target_files[@]}" > "${base_name}.bin"
        echo "Merged into ${base_name}.bin"
    else
        echo "No matching files found"
    fi

    sleep $USAGE_SLEEP_TIME
    usage
}

so_fix_task() {
    echo -n "Input path > "
    read -r target_path

    if [ -e "$target_path" ]; then
        echo -n "Input page size > "
        read -r page_size

        if [[ "$page_size" =~ ^0x[0-9a-fA-F]+$ ]]; then
            page_size=$((page_size))
        elif [[ ! "$page_size" =~ ^[0-9]+$ ]]; then
            echo "Error: Page size must be a number (decimal or hexadecimal)."
            return
        fi

        echo "Starting SO fix process for '$target_path' with page size: $page_size..."
        $SO_FIXER -s "$target_path" -o "fixed_$target_path" -m 0x0 -d -a "$page_size"

    else
        echo "Error: File not found."
    fi
    
    sleep $USAGE_SLEEP_TIME
    usage
}

entry() {
    usage
    while true;do 
        echo -n " > "
        read -r option
        if [ "$option" == "1" ];then 
            dump_task
        elif [ "$option" == "2" ];then
            merge_task
        elif [ "$option" == "3" ];then
            so_fix_task
        elif [ "$option" == "4" ];then
            usage
        fi

    done
}

entry