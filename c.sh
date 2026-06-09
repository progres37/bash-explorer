c() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		echo " W / S - Navigate up/down"
		echo "     D - Switch between directories and files"
		echo "     A - Toggle visibility of hidden items"
		echo " ENTER - Select"
		return
	fi
	
	local showing_all="false"
	local active_col="dirs"
	local selection=0
	local dirs=()
	local files=()
	local previous_ui_line_count=0
	local current_dir=$(pwd)
	local exit_requested="false"
	
	update_dirs() {
		dirs=()
		for item in *; do
			[ -e "$item" ] || break
			if [ -d "$item" ]; then
				dirs+=("$item")
			fi
		done

		if [ "$showing_all" = "true" ]; then
			for item in .*; do
				[ -e "$item" ] || break
				if [ "$item" != "." ] && [ "$item" != ".." ] && [ -d "$item" ]; then
					dirs+=("$item")
				fi
			done
		fi
		
		dirs+=(".")
		if [ ! "$(pwd)" = "/" ]; then
			dirs+=("..")
		fi
	}
	
	update_files() {
		files=()
		for item in *; do
			[ -e "$item" ] || break
			if [ -f "$item" ]; then
				files+=("$item")
			fi
		done
		
		if [ "$showing_all" = "true" ]; then
			for item in .*; do
				[ -e "$item" ] || break
				if [ -f "$item" ]; then
					files+=("$item")
				fi
			done
		fi
	}
	
	update_lists() {
		update_dirs
		update_files
	}
	
	print_ui() {		
		local total_rows=0
		if [ ${#dirs[@]} -gt ${#files[@]} ]; then
			total_rows="${#dirs[@]}"
		else
			total_rows="${#files[@]}"
		fi
		
		local max_dir_len=0
		for dir in "${dirs[@]}"; do
			if [ ${#dir} -gt $max_dir_len ]; then
				max_dir_len=${#dir}
			fi
		done
		local max_file_len=0
		for file in "${files[@]}"; do
			if [ ${#file} -gt $max_file_len ]; then
				max_file_len=${#file}
			fi
		done
		
		local dir_header=""
		local file_header=""
		if [ "$showing_all" = "false" ]; then
			dir_header="Dirs      "
			file_header="Files      "
		else
			dir_header="Dirs (all)"
			file_header="Files (all)"
		fi
		
		local dir_col_width=0
		if [ "$max_dir_len" -gt "${#dir_header}" ]; then
			dir_col_width="$max_dir_len"
		else
			dir_col_width="$((${#dir_header} + 1))"
		fi
		local file_col_width=0
		if [ "$max_file_len" -gt "${#file_header}" ]; then
			file_col_width="$max_file_len"
		else
			file_col_width="$((${#file_header} + 1))"
		fi
		
		echo "Current directory: $current_dir"
		printf "    %-$((dir_col_width))s   %-$((file_col_width))s\n" "$dir_header" "$file_header"
		
		if [ $active_col = "dirs" ]; then
			for ((i=0; i<total_rows; i++)); do
				local dir="${dirs[$i]:-}"
				local file="${files[$i]:-}"
				
				if [ "$i" -eq "$selection" ]; then
					printf " > %-$((dir_col_width))s   %-$((file_col_width))s\n" "$dir" "$file"
				else
					printf "   %-$((dir_col_width))s   %-$((file_col_width))s\n" "$dir" "$file"
				fi
			done
		else
			for ((i=0; i<total_rows; i++)); do
				local dir="${dirs[$i]:-}"
				local file="${files[$i]:-}"
				
				if [ "$i" -eq "$selection" ]; then
					printf "   %-$((dir_col_width))s > %-$((file_col_width))s\n" "$dir" "$file"
				else
					printf "   %-$((dir_col_width))s   %-$((file_col_width))s\n" "$dir" "$file"
				fi
			done
		fi
		
		previous_ui_line_count=$((total_rows + 2))
	}
	
	clear_ui() {
		printf "\e[%dA\e[J" "$previous_ui_line_count"
	}
	
	get_active_col_len() {
		local active_col_len=0
		if [ "$active_col" = "dirs" ]; then
			active_col_len=${#dirs[@]}
		else
			active_col_len=${#files[@]}
		fi
		echo "$active_col_len"
	}
	
	navigate() {
		local direction="$1"
		
		local active_col_len=$(get_active_col_len)
		
		if [ "$direction" = "up" ]; then
			((selection--))
			if [ "$selection" -lt 0 ]; then
				selection=$(($selection + $active_col_len))
			fi
		else
			((selection++))
			if [ "$selection" -gt $(($active_col_len - 1)) ]; then
				selection=$(($selection - $active_col_len))
			fi
		fi
	}
	
	toggle_showing_all() {
		if [ "$showing_all" = "true" ]; then
			showing_all="false"
			update_lists
			
			if [ "${#files[@]}" -eq 0 ]; then
				active_col="dirs"
			fi
			
			local active_col_len=$(get_active_col_len)
			
			if [ "$selection" -gt $(($active_col_len - 1)) ]; then
				selection=$(($active_col_len - 1))
			fi
		else
			showing_all="true"
			update_lists
		fi
	}
	
	switch_active_col() {
		if [ "$active_col" = "dirs" ]; then
			if [ ${#files[@]} -gt 0 ]; then
				active_col="files"
			fi
		else
			active_col="dirs"
		fi
		
		local active_col_len=$(get_active_col_len)
		
		if [ "$selection" -gt $(($active_col_len - 1)) ]; then
			selection=0
		fi
	}
	
	confirm_selection() {
		if [ "$active_col" = "files" ]; then
			echo "Opening ${files[$selection]}..."
			open "${files[$selection]}"
			printf "\e[%dA\e[J" "1"
			echo "${files[$selection]} opened"
		else
			if [ "${dirs[$selection]}" = "." ]; then
				exit_requested="true"
				return
			fi
			cd "${dirs[$selection]}"
			current_dir=$(pwd)
			update_lists
			selection=0
		fi
	}
	
	update_lists
	
	trap 'printf "\e[%dA\e[J" "$previous_ui_line_count"; tput cnorm; return' INT
	tput civis
	
	print_ui
	
	while true; do
		local key=""
		read -s -n 1 key
		
		case "$key" in
			[wW])
				clear_ui
				navigate up
				print_ui
				;;
			[sS])
				clear_ui
				navigate down
				print_ui
				;;
			[aA])
				clear_ui
				toggle_showing_all
				print_ui
				;;
			[dD])
				clear_ui
				switch_active_col
				print_ui
				;;
			"")
				clear_ui
				confirm_selection
				if [ "$exit_requested" = "true" ]; then
					break
				else
					print_ui
				fi
				;;
		esac
	done
	
	tput cnorm
	trap - INT
}
