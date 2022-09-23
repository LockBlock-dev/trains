TRAINS_DATA_FILE_PATH="trains.dta"

#######################################
# Check for a correct time format, eg '12h00'.
# Arguments:
#   Time to check
# Returns:
#   0 if the format is correct, else 1.
#######################################
function test_heure()
{
    
    if test $(echo $1 | grep -E "^([01]?[0-9]|2[0-3])h[0-5][0-9]$") # if string is a valid hour
    then
        return 0
    else
        return 1
    fi
}

#######################################
# Convert hours to minutes, eg '02h45' => 165.
# Arguments:
#   Time to convert
# Outputs:
#   Writes the minutes to STDOUT.
# Returns:
#   0 if the conversion was successful, else 1.
#######################################
function heure2min()
{
    if test $1
    then
        IFS="h"; read -a parsed <<< "$1" # split XXhXX at 'h' into an array

        hours=${parsed[0]}
        minutes=${parsed[1]}

        minutes=$((10#$minutes + 10#$hours * 60)) # arithmetic: minutes + hours * 60

        echo $minutes

        return 0
    else
        return 1
    fi
}

#######################################
# Compute the difference between 2 times, in minutes.
# Arguments:
#   First time
#   Second time
# Outputs:
#   Writes the result to STDOUT.
# Returns:
#   0 if the computation was successful, else 1.
#######################################
function diff_heure()
{
    if test $1 && test $2 # if we have 2 times
    then
        arg1=$(heure2min $1)
        arg2=$(heure2min $2)

        echo $(($arg2 - $arg1)) # difference hour2 - hour1 (in minutes)
        
        return 0
    else
        return 1
    fi
}

#######################################
# Sort trains by starting time from trains data file.
# Globals:
#   TRAINS_DATA_FILE_PATH
# Arguments:
#   Destination city, optional
# Outputs:
#   Writes the result to STDOUT.
# Returns:
#   0
#######################################
function tri_train()
{
    if test $1 # if we have a destination
    then
        # using ':' to avoid matching 'City-something-else' with 'City'
        grep "$1:" $TRAINS_DATA_FILE_PATH | sort -t ":" -k 2 # grep by destination and sort by starting time
    else
        grep "" $TRAINS_DATA_FILE_PATH | sort -t ":" -k 2 # grep all and sort by starting time
    fi

    return 0
}

#######################################
# Prompt user for a time.
# Arguments:
#   None
# Outputs:
#   Writes the time to STDOUT.
# Returns:
#   0 if the user input is correct, else 1.
#######################################
function saisir_heure()
{
    read -p "Entrez une heure : " input # await user input

    echo $input

    if $(test_heure $input) # if the time is in the correct format
    then
        return 0
    else
        return 1
    fi
}

#######################################
# Add a train from user inputs to the trains data file.
# Globals:
#   TRAINS_DATA_FILE_PATH
# Arguments:
#   None
# Outputs:
#   Writes the train data to the trains data file.
# Returns:
#   0 if user inputs are correct, else 1.
#######################################
function ajout_train()
{
    read -p "Destination : " destination # await user input

    starting_time=$(saisir_heure)
    start_check=$? # exit code of the previous function

    arriving_time=$(saisir_heure)
    arriving_check=$?

    if test $start_check -eq 1 || test $arriving_check -eq 1 # if one of the time is incorrect
    then
        echo "Une ou plusieurs heures saisies sont invalides !"

        return 1
    else
        echo "$destination:$starting_time:$arriving_time" >> $TRAINS_DATA_FILE_PATH # adding the train to the list

        return 0
    fi
}

#######################################
# Prompt the user for an index in the trains data file.
# Backup the older version of the file.
# Delete the train with this index from the file.
# Globals:
#   TRAINS_DATA_FILE_PATH
# Arguments:
#   None
# Outputs:
#   Removes the train from the trains data file.
#   Saves the older version of the file into a .bak.
# Returns:
#   0 if user input is correct, else 1.
#######################################
function suppr_train()
{
    count=$(wc -l $TRAINS_DATA_FILE_PATH | cut -d " " -f 1)

    cat -n $TRAINS_DATA_FILE_PATH

    read -p "Index du train à supprimer : " index # await user input

    if test $index -gt $count
    then
        echo "Impossible de supprimer le train à l'index $index ! La liste ne contient que $count éléments !"

        return 1
    else
        sed -i".bak" -e "$index d" $TRAINS_DATA_FILE_PATH # remove the train and backup the original list

        return 0
    fi
}

#######################################
# Find the next departing train for a destination based on the given time or system time.
# Arguments:
#   Destination city
#   Time, optional
# Outputs:
#   Writes the result to STDOUT.
# Returns:
#   0 if a city was provided, else 1.
#######################################
function prochain_train()
{
    if test $1  # if we have a destination
    then
        sorted=$(tri_train $1) # sort trains by destination
        search_time=$(date "+%H:%M") # default is system time, formatting hours and minutes
        search_time=$(echo $search_time | tr ":" "h") # converting system time to the correct format

        if test $2 # if we have a time
        then
            test_heure $2
            if test $? -eq 0 # if the time is valid
            then
                search_time=$2 # search time is the given time
            else
                echo "L'heure saisie est invalide ! Utilisation de l'heure système."
            fi
        fi

        while read -r line # for each line in the input
        do
            depart_time=$(echo $line | cut -d ":" -f 2) # take only the departing time
            diff_time=$(diff_heure $depart_time $search_time) # difference between our search time and the departing time
            found=false # flag to exit the loop

            if test $diff_time -lt 0 # time difference is > 0, means we have an available train
            then
                found=true
                echo $line
                break # we have a train available we can exit the loop
            fi

        done <<< "$sorted" # input the sorted trains to the 'read' loop

        if test $found == false # if we did'nt find any train
        then
            echo "Plus aucun train ne partira pour $1 aujourd'hui."
        fi

        return 0
    else
        return 1
    fi
}

#######################################
# Prompt user for an action.
# Arguments:
#   None
# Outputs:
#   Writes the action to STDOUT.
# Returns:
#   0
#######################################
function menu()
{
    menu_text="*************** TRAIN ****************
1. Prochain train pour une destination
2. Prochain train pour une destination à partir d'une heure donnée
3. Lister tous les trains pour une destination donnée
4. Ajouter un train
5. Supprimer un train
6. Quitter
**************************************
Choix ? "

    read -p "$menu_text" choice # await user input

    echo $choice

    return 0
}

function train()
{
    choice=$(menu)

    case $choice in 

    1)
        read -p "Saisissez une destination : " destination
        prochain_train $destination
        ;;

    2)
        read -p "Saisissez une destination : " destination
        read -p "Saisissez une heure minimum : " time
        prochain_train $destination $time
        ;;

    3)
        read -p "Saisissez une destination : " destination
        tri_train $destination
        ;;

    4)
        ajout_train
        ;;

    5)
        suppr_train
        ;;

    6)
        exit 0
        ;;

    *)
        echo "L'option $choice n'existe pas !"
        return 1
        ;;
    esac

    return 0
}

train
