import json
import sys



if __name__ == "__main__":
    input_file = sys.argv[1]
    output_file = sys.argv[2]

    try:
        with open(input_file, "r") as f:
            data = json.load(f)
    except FileNotFoundError:
        raise FileNotFoundError("Input file {} wasn't found", input_file)
    

    ### Instance specific constraints ###
    sameVehicleBackwards = data["sameVehicleBackwards"] # Boolean

    ### Instance specific structure ###
    places = []
    for place in data["places"]:
        places.append(place["id"]) # TODO - do we need to sort to match adjMatrix?

    vehicles = []
    for vehicle in data["vehicles"]:
        vehicles = vehicles.append(vehicle)

    start = []
    destination = []
    end = []
    appointmentStart = []
    appointmentDuration = []
    embarkDuration = []
    for patient in data["patients"]:
        s = patient["start"]
        d = patient["destination"]
        e = patient["end"]
        appStart = patient["rdvTime"]
        appDuration = patient["rdvDuration"]
        embar = patient("srvDuration")
        if (s == -1):
            # No forward activity for this request
            s = d
        if (e == -1):
            # No backward activity for this request
            e = d
        start.append(s)
        destination.append(d)
        end.append(e)
        appointmentStart.append(appStart)
        appointmentDuration.append(appDuration)
        embarkDuration.append(embar)

    adjMatrix = data["distMatrix"]


    ### Decision Variables ###
    # array R of binary (0-1) variables. R[i] = 1 means request i was selected
    # array A of activities (see Eq. 1) of (A_origin, A_destiny) - dividir em 2 arrays?


    # Do stuff

    with open(output_file, "w") as f:
        json.dump(data, f, indent=4) # TODO - ver que indent prefiro
    
    exit(0)
