# GitLab Create Milestones

Bash script for creating milestones for multiple Gitlab projects

## Pre-requisite

- [jq](https://stedolan.github.io/jq/download/)
- Gitlab Access Token with read/write `api` scope

## How to Use

1. Clone the repo
2. Run `export GITLAB_API_TOKEN=<your access token>`
3. Specify project names (cass-sensitive) in script under line 55
4. Run `./create_milestone.sh <gitlab_server_url> '<sprint_number>' '<start_date_yyyy_mm_dd>' '<due_date_yyyy_mm_dd>'` <br> e.g. `./create_milestone.sh 'https://gitlab.repository.com' '17' '2022-11-24' '2022-12-07'`

## Credits

Thanks to [@weikangchia](https://github.com/weikangchia/) for reference.
