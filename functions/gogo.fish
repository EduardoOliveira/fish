function gogo -d "Go places with repos" -a repo -a action
    test -n "$basedir"; or set basedir ~/repos
    test -d $basedir; or begin
        echo "bad base dir $basedir"
        return 1
    end

    if test -z "$repo"; or test -z "$action"
        # find git repos from $basedir, trim prefix and .git
        set -l picked (
            # ESC clears before leaving; match fields 1..2; custom prompt
            set fzfopt --bind esc:cancel -n 1..2 --prompt='where what? '
            
            # pre-select current repo if it's under "basedir"
            if string match -q "$basedir*" (pwd)
                set -l pwd (pwd)
                for a in (seq 3)
                    set -l repo (string sub --start (string length "$basedir//") $pwd)
                    if test -d $basedir/$repo/.git
                        # top repo dir
                        set fzfopt $fzfopt "--query=$repo"
                        break
                    end

                    # not at the top repo dir, go up
                    set pwd (realpath $pwd/..)
                end
            end

            # fancy preview
            set -l preview "set d $basedir/(echo {} | awk '{print \$1}')"
            set -l preview "$preview; printf '%s\n---\n' \$d"
            set -l preview "$preview; git -C \$d status"
            set -l preview "$preview; printf '---\n'"
            set -l preview "$preview; ls -l --color \$d"
            set -l preview "$preview; printf '---\n'"
            set -l preview "$preview; test -r README.md; and cat README.md"
            set fzfopt $fzfopt --preview="$preview"

            # find all .git dirs under current,
            # add actions for each
            for dir in (find $basedir -mindepth 1 -maxdepth 3 -type d -name .git)
                set -l dir (dirname $dir) # remove ".git"
                set -l repo (echo $dir | string sub --start (echo "$basedir/" | wc -c)) # remove "basedir/"

                echo "$repo cd → Change directory to repo base"
                echo "$repo cd-tab → Opens a new tmux tab in the repo base"
                echo "$repo edit → Edits the repo in Neovim"

                set -l branch (git -C $dir rev-parse --abbrev-ref HEAD 2>/dev/null)
                set -l issue (string match -r 'ONE-\d+' $branch)
                if test -n "$issue"
                    echo "$repo jira-issue → Open issue $issue in Jira"
                end

                set -l remote (git -C $dir config --get remote.origin.url 2>/dev/null)
                if string match -q '*gitlab.com*' "$remote"
                    echo "$repo gitlab-home → Open Gitlab's home for the project"
                    echo "$repo gitlab-pipelines → Open Gitlab's pipelines"
                    echo "$repo gitlab-ci-cd-vars → Open Gitlab's CI/CD config"
                    echo "$repo gitlab-merge-requests → Open Gitlab's merge requests"
                    echo "$repo gitlab-tags → Open Gitlab's tags"
                end

                for env in prod staging
                    set -l tf_fn $dir/infrastructure/$env.tfvar
                    test -r $tf_fn; or continue
                    for proj in {migrate-,}$env
                        echo "$repo aws-$proj-logs → Open AWS Cloudwatch logs in $proj"
                        echo "$repo aws-$proj-livetail → Open AWS Cloudwatch livetail in $proj"
                        echo "$repo aws-$proj-lambda → Open AWS lambda in $proj"
                    end
                    set -l name (grep -E 'project_name\s*=' $tf_fn | cut -d'"' -f2 | head -1)
                    if string match -q '*-subscriber' $name
                        echo "$repo aws-$proj-sqs → Open AWS SQS queue in $proj"
                    end
            end
            end 2>/dev/null | fzf $fzfopt
        )
        
        test -n "$picked"; or return 1
        echo "[picked:$picked]"
        set repo (echo "$picked" | awk '{print $1}')
        set action (echo "$picked" | awk '{print $2}')
        echo "gogo $repo $action" >&2
    end

    set -l dir $basedir/$repo
    test -d $dir; or begin
        echo "bad dir: $dir" >&2
        return 1
    end

    switch $action
    case cd
        echo "---> cd $dir" >&2
        cd $dir

    case jira-issue
        set -l issue (string match -r 'ONE-\d+' (git -C $dir rev-parse --abbrev-ref HEAD))
        set url "https://axofinance.atlassian.net/browse/$issue"

    case cd-tab
        echo "---> cdt $dir" >&2
        cdt $dir

    case edit
        set -l fish_trace 1
        nvim $dir

    case "gitlab-*"
        set -l gitlab_path (git -C $dir config --get remote.origin.url | string replace -r '^.*:(.*)\.git' '$1')
        set -l gitlab_base "https://gitlab.com/$gitlab_path"

        switch $action
        case gitlab-home; set url $gitlab_base/
        case gitlab-pipelines; set url "$gitlab_base/-/pipelines?ref=main"
        case gitlab-ci-cd-vars; set url $gitlab_base/-/settings/ci_cd
        case gitlab-merge-requests; set url $gitlab_base/-/merge_requests
        case gitlab-tags; set url $gitlab_base/-/tags
        end

    case "aws-*"
        set -l tf_fn $dir/infrastructure/(echo "$action" | cut -d- -f2).tfvar
        set -l proj (grep -E 'project_name\s*=' $tf_fn | cut -d'"' -f2 | head -1)
        string match -q '*-migrate-*' $action; and set -l proj "migrate-$proj"
        
        set -l region eu-north-1
        set -l awsbase "https://$region.console.aws.amazon.com"
        switch $action
        case "*-sqs"
            set app sqs/v3
            set fragment "/queues/https%3A%2F%2Fsqs.$region.amazonaws.com%2F562900684595%2F"$proj"_queue.fifo"

        case "*-logs"
            set app cloudwatch
            set fragment (printf 'logsV2:log-groups/log-group/$252Faws$252Flambda$252F%s/log-events' $proj)
            
        case "*-livetail"
            set app cloudwatch
            set fragment (printf 'logsV2:live-tail$3FlogGroupArns$3D~(~\'arn*3aaws*3alogs*3a%s*3a562900684595*3alog-group*3a*2faws*2flambda*2f%s)' $region $proj)
        
        case "*-lambda"
            set app lambda
            set fragment "/functions/$proj?tab=code"
        end

        set url "$awsbase/$app/home?region=$region#$fragment"
    end

    if test -n "$url"
        set -l fish_trace 1
        open $url
    end
end
