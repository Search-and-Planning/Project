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

    for patient in data["patients"]:
        pass

    adjMatrix = data["distMatrix"]


    ### Decision Variables ###
    # array R of binary (0-1) variables. R[i] = 1 means request i was selected
    # array A of activities (see Eq. 1) of (A_origin, A_destiny) - dividir em 2 arrays?


    # Do stuff

    with open(output_file, "w") as f:
        json.dump(data, f, indent=4) # TODO - ver que indent prefiro
    
    exit(0)
