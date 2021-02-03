#!/bin/bash
SLEEP_INTERVAL=10
PENDING_HUP=0
SLEEP_PID=-1
FILE_NAME=$0
COOKIES=$(mktemp -t boun_cookie)
login()
{
    curl 'https://registration.boun.edu.tr/scripts/stuinflogin.asp' -X POST -d "user_name=$1&user_pass=$2" -c "$COOKIES" -sS &>/dev/null
}
get_grades()
{
    curl 'http://registration.boun.edu.tr/scripts/stuinfgs.asp?donem=2014/2015-1' -b "$COOKIES" -sS -L 2>/dev/null
}
handle_hup()
{
    PENDING_HUP=1
    if [ $SLEEP_PID -gt 0 ];
    then
        kill -1 $SLEEP_PID
    fi
}
post_hup()
{
    PENDING_HUP=0
    echo 
    echo "Received HUP" 
    echo "Reloading"
    source $FILE_NAME
    exec main
}
get-grade-hashed()
{
    local grades=$(get_grades)
    if [ $? -eq 0 ];
    then
        echo $grades | md5
    else
        false
    fi
}
full-compare-hashed()
{
    local h1=$1
    local h2=
    false
    while [ $? -ne 0 ];
    do
        login $USER $PASS
    done

    false
    while [ $? -ne 0 ];
    do
        h2=$(get-grade-hashed)
    done
    test h1 -eq h2
}
rest()
{
    sleep $1 &
    SLEEP_PID=$!
    wait $SLEEP_PID
    SLEEP_PID=-1

}
main()
{
    trap 'handle_hup' 1
    local breaking=0
    while true; do
        if [ $breaking -eq 1 ];
        then
            break
        fi
        echo -ne Logging in...
        false
        while [ $? -ne 0 ]; do
            login $USER $PASS && echo -ne Ok\\n || echo -ne Fail\\n
        done

        local org_hash=
        false
        while [ $? -ne 0 ]; do
           org_hash=$(get-grade-hashed)
        done
        echo Current hash $org_hash
        while true; do
            if [ $PENDING_HUP -eq 1 ];
            then
                post_hup
                breaking=1
                break
            fi
            local grade_hash=$(get-grade-hashed)
            if [ $? -ne 0 ];
            then
                echo
                echo Error getting grades, restarting in $SLEEP_INTERVAL seconds
            else
                echo -ne Last Checked `date`\\r
                if [ $grade_hash != $org_hash ];
                then
                    echo 
                    echo "Hash has changed, double checking to make sure it's the grades"
                    full-compare-hashed $org_hash
                    if [ $? -eq 0 ];
                    then
                        echo Grades updated | growlnotify -p 100 -s
                    else
                        echo "Grades haven't changed"
                    fi
                fi
            fi
        rest $SLEEP_INTERVAL
    done
    done
}
main
