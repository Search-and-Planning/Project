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
    for place in data["places"]:
        pass

    for vehicle in data["vehicles"]:
        pass

    for patient in data["patients"]:
        pass

    adjMatrix = data["distMatrix"]

    # Do stuff

    with open(output_file, "w") as f:
        json.dump(data, f, indent=4) # TODO - ver que indent prefiro
    
    exit(0)