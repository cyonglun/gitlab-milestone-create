#!/bin/bash

################################################################################
# Help                                                                         #
################################################################################
help(){
	echo
	echo
	echo "█ █▀▄▀█ █▀█ █▀█ █▀█ ▀█▀ ▄▀█ █▄░█ ▀█▀"
	echo "█ █░▀░█ █▀▀ █▄█ █▀▄ ░█░ █▀█ █░▀█ ░█░"
	echo
	echo " - Ensure access token with read/write API access is set to \$GITLAB_API_TOKEN"
	echo " - Declared project names are case sensitive (YourProject != yourProject)"
	echo
	echo "█▀█ ▄▀█ █▀█ ▄▀█ █▀▄▀█ █▀▀ ▀█▀ █▀▀ █▀█ █▀"
	echo "█▀▀ █▀█ █▀▄ █▀█ █░▀░█ ██▄ ░█░ ██▄ █▀▄ ▄█"
	echo
	echo " - \$server: Gitlab Server URL"
	echo " - \$sprint: Sprint number. Milestone title will be 'Sprint {\$sprint}'"
	echo " - \$from: Start date of sprint in YYYY-MM-DD format"
	echo " - \$to: Due date of sprint in YYYY-MM-DD format"
	echo
	echo "Example: ./create_milestone.sh 'https://gitlab.repository.com' '17' '2022-11-24' '2022-12-07'"
	echo
}

################################################################################
################################################################################
# Main program                                                                 #
################################################################################
################################################################################
main() {
	# Help function
	if [[ ("$1" == "-h" ) || ( "$1" == "--help" ) ]];
	then
		help
		exit
	fi

	server=$1 	# Gitlab server url
	sprint=$2 	# Sprint number
	from=$3 	# sprint start_date in yyyy-mm-dd
	to=$4 		# sprint due_date in yyyy-mm-dd


	echo
	echo "█▀▀ █▀█ █▀▀ ▄▀█ ▀█▀ █▀▀   █▀▀ █ ▀█▀ █░░ ▄▀█ █▄▄   █▀▄▀█ █ █░░ █▀▀ █▀ ▀█▀ █▀█ █▄░█ █▀▀ █▀"
	echo "█▄▄ █▀▄ ██▄ █▀█ ░█░ ██▄   █▄█ █ ░█░ █▄▄ █▀█ █▄█   █░▀░█ █ █▄▄ ██▄ ▄█ ░█░ █▄█ █░▀█ ██▄ ▄█"
	echo

	milestone_title="Sprint $sprint"

	oldIFS="$IFS"

	projects_names=('')

	check_variables

	gitlab_graphql_url=$server/api/graphql

	check_variables

	echo "Starting Milestone creation for:"
	echo "[$(IFS=,; echo "${projects_names[*]}")]"

	IFS=$'\n'

	for project_name in "${projects_names[@]}"; do
		echo
		echo "** $project_name **"

		project_response=$(curl -s --location --request POST $server'/api/graphql' \
			--header 'Authorization: Bearer '$GITLAB_API_TOKEN \
			--header 'Content-Type: application/json' \
			-d '{"query":"query { projects(search: \"'$project_name'\") { nodes{ name id fullPath milestones(sort: DUE_DATE_DESC, first: 2) { nodes{ title startDate dueDate }}}\t}}","variables":{}}')

		#echo $project_response | jq '.'

		project_nodes=$(echo "$project_response" | jq -r '.data.projects.nodes')
		target_node=$(echo "$project_nodes" | jq -r '.[] | select(.name=="'$project_name'")')

		if [ -z "$target_node" ];
		then
			echo "ERROR: Failed to find Project with name $project_name (case-sensitive)"
			continue
		fi

		project_id=$(echo "$target_node" |jq -r '.id' | sed 's/gid:\/\/gitlab\/Project\///')
		milestone_nodes=$(echo "$target_node" | jq -r '.milestones.nodes')

		to_create_milestone=0

		titles=($(echo $milestone_nodes | jq -r '.[] | .title'))
		startDates=($(echo $milestone_nodes | jq -r '.[] | .startDate'))
		dueDates=($(echo $milestone_nodes | jq -r '.[] | .dueDate'))
		for ((i = 0; i<${#titles[@]}; i++)); do
			if (is_valid_milestone $i)
			then
				break
			else
				to_create_milestone=1
			fi
		done

		if [[ $to_create_milestone -eq 1 ]];
		then
			create_milestone $project_name $project_id $milestone_title $from $to
		fi
	done

	echo
	echo "█▀▀ █▄░█ █▀▄"
	echo "██▄ █░▀█ █▄▀"
	echo

	IFS="$oldIFS"
}

check_variables() {
	if test -z "$server"
	then
		echo "ERROR: \$server was not defined"
		exit
	fi

	if test -z "$GITLAB_API_TOKEN"
	then
		echo "ERROR: \$GITLAB_API_TOKEN was not defined"
		exit
	fi

	if test -z "$projects_names"
	then
		echo "ERROR: \$projects_names is empty"
		exit
	fi

	if [ -z "$from" ] || [ -z "$to" ]
	then
		echo "ERROR: \$from or \$to was not defined"
		exit
	fi

	if (is_valid_date_format $from)
	then
		echo "ERROR: \$from '$from' is NOT a valid YYYY-MM-DD date"
		exit
	fi

	if (is_valid_date_format $to)
	then
		echo "ERROR: \$to '$to' is NOT a valid YYYY-MM-DD date"
		exit
	fi
	
	if expr "$from" ">=" "$to" >/dev/null
	then
		echo "ERROR: \$from cannot be greater than \$to"
		exit
	fi
}

is_valid_date_format() {
	if [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] 
	then
		return 1
	else
		return 0
	fi
}

is_valid_milestone() {	
	from_ge_start=`expr "${startDates[$1]}" ">=" "$from"`
	to_ge_due=`expr "${dueDates[$1]}" ">=" "$to"`

	if [[ "$from_ge_start" -eq 1 ]] || [[ "$to_ge_due" -eq 1 ]];
	then
		echo "Failed to create Milestone from $from to $to due to conflict with start/due dates of ${titles[$1]}"
		return 0
	fi

	# Check title
	if [[ $milestone_title == ${titles[$1]} ]]
	then
		echo "Failed to create Milestone with title '$milestone_title' as it already exists"
		return 0
	fi

	return 1
}

create_milestone() {
	name=$1
	id=$2
	title=$3
	start_date=`echo "$4" | sed 's/-//g'` # remove hypen
	due_date=`echo "$5" | sed 's/-//g'` # remove hypen

	http_response=$(curl -s -w %{http_code} --location --request POST $server'/api/v4/projects/'$id'/milestones' \
		--header 'Authorization: Bearer '$GITLAB_API_TOKEN \
		--form 'title="'$title'"' \
		--form 'start_date="'$start_date'"' \
		--form 'due_date="'$due_date'"')
	
	http_body=${http_response%???}
	http_code=${http_response: -3} # http_code is last 3 digits

	if (($http_code == 201)) || (($http_code == 200));
	then
		echo "Http $http_code: Created $name Milestone '$title' starting $start_date and ending $due_date"
		web_url=$(echo "$http_body" | jq -r '.web_url')
		echo $web_url
	else
		echo "Http $http_code: Failed to create $name Milestone"
		echo $http_body
	fi
}

main $1 $2 $3 $4
