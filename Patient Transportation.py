import json
import sys
from itertools import count as count

# TODO - Output


class Vehicle:

    # Some vehicles may have multiple non continous time intervals where they are
    # available. To represent this in minizinc, we duplicate the vehicle for each
    # interval. This counter corresponds to how that shift will be identified
    # in minizinc
    minizinc_id = count()

    def __init__(self, real_id, shift_start_time, shift_end_time, 
                shift_start_location, shift_end_location, patient_categories,
                capacity) -> None:
        self.real_id = real_id
        self.shift_start_time = shift_start_time
        self.shift_end_time = shift_end_time
        self.shift_start_location = shift_start_location
        self.shift_end_location = shift_end_location
        self.patient_categories = patient_categories
        self.minizinc_id = next(Vehicle.minizinc_id)
        self.capacity = capacity


    def __eq__(self, __value: object) -> bool:
        """Compares if two vehicles are equal. In this context, equal means that they
        add some kind of variable symmetry to the Patient Transportation Problem (eg: 
        same interval of availability, same start/end location, same set of 
        compatible patient categories and same load capacity)."""

        if not isinstance(__value, Vehicle):
            return NotImplemented
        
        return self.shift_start_time == __value.shift_start_time and \
            self.shift_end_time == __value.shift_end_time and \
            self.shift_start_location == __value.shift_start_location and \
            self.shift_end_location == __value.shift_end_location and \
            self.patient_categories == __value.patient_categories and \
            self.capacity == __value.capacity
    

    def __str__(self) -> str:
        return "Vehicle nº " + str(self.real_id) + \
        "shift start time: " + str(self.shift_start_time) + \
        "shift end time: " + str(self.shift_end_time) + \
        "shift start location: " + str(self.shift_start_location) + \
        "shift end location: " + str(self.shift_end_location) + \
        "compatible patient categories: " + str(self.patient_categories)
    

class Patient:

    minizinc_id = count()

    def __init__(self, real_id, load, category, start, destination, end,
                 rdvTime, rdvDuration, srvDuration) -> None:
        self.real_id = real_id
        self.minizinc_id = next(Vehicle.minizinc_id)
        self.load = load
        self.category = category
        self.start = start
        self.destination = destination
        self.end = end
        self.rdvTime = rdvTime
        self.rdvDuration = rdvDuration
        self.srvDuration = srvDuration
    

    def __str__(self) -> str:
        return "Patient nº " + str(self.real_id) + \
        "load: " + str(self.load) + \
        "category: " + str(self.category) + \
        "start: " + str(self.start) + \
        "destination: " + str(self.destination) + \
        "end: " + str(self.end) + \
        "rdvTime: " + str(self.rdvTime) + \
        "rdvDuration: " + str(self.rdvDuration) + \
        "srvDuration: " + str(self.srvDuration)

        

def time_to_minutes(time: str) -> int:
    """Converts a time in the format HHhMM to minutes"""

    time = time.split('h')
    return int(time[0]) * 60 + int(time[1])


def flatten(l: list) -> list:
    """Flattens a list of sets into a single list"""

    return [item for subset in l for item in subset]


if __name__ == "__main__":
    input_file = sys.argv[1]
    output_file = sys.argv[2]

    try:
        with open(input_file, "r") as f:
            data = json.load(f)
    except FileNotFoundError:
        raise FileNotFoundError("Input file {} wasn't found", input_file)
    

    #######################################
    ###                                ####
    ### Process Input and Create Model ####
    ###                                ####
    #######################################


    ### Instance specific constraints ###
    sameVehicleBackwards = data["sameVehicleBackwards"] # Boolean
    maxWaitTime = time_to_minutes(data["maxWaitTime"]) # Integer

    ### Instance specific structure ###
    places = []
    numPlaces = 0
    for place in data["places"]:
        numPlaces += 1
        places.append(place["id"]) # TODO - do we need to sort to match adjMatrix?

    vehicles = []
    vehicleStartLocation = []
    vehicleEndLocation = []
    capacity = []
    categories = []
    vehicleStartTime = []
    vehicleEndTime = []
    timeHorizon = 0
    numVehicles = 0
    for vehicle in data["vehicles"]:
        numVehicles += 1
        availabilities = vehicle["availabilities"]

        for availability in availabilities:
            # Handle vehicles with multiple availabilities
            tempVar = availability['availability'].split(':')
            startTime = time_to_minutes(tempVar[0])
            endTime = time_to_minutes(tempVar[1])
            if (endTime > timeHorizon):
                timeHorizon = endTime

            vehicleStartLocation.append(vehicle["start"])
            vehicleEndLocation.append(vehicle["end"])
            capacity.append(vehicle["capacity"])
            categories.append(set(vehicle["canTake"]))
            vehicleStartTime.append(startTime)
            vehicleEndTime.append(endTime)

            vehicles.append(Vehicle(vehicle["id"], startTime, endTime, vehicle["start"], 
                                    vehicle["end"], vehicle["canTake"],
                                    vehicle["capacity"]))
    flattenedCategories = flatten(categories)


    start = []
    destination = []
    end = []
    load = []
    patientCategory = []
    appointmentStart = []
    appointmentDuration = []
    embarkDuration = []
    numRequests = 0
    patients = []
    for patient in data["patients"]:
        s = patient["start"]
        d = patient["destination"]
        e = patient["end"]
        l = patient["load"]
        c = patient["category"]
        appStart = time_to_minutes(patient["rdvTime"])
        appDuration = time_to_minutes(patient["rdvDuration"])
        embar = time_to_minutes(patient("srvDuration"))
        if (s == -1):
            # No forward activity for this request
            s = d
        if (e == -1):
            # No backward activity for this request
            e = d
        if (not c in flattenedCategories):
            flattenedCategories.append(c)
        start.append(s)
        destination.append(d)
        end.append(e)
        appointmentStart.append(appStart)
        appointmentDuration.append(appDuration)
        embarkDuration.append(embar)
        load.append(l)
        patientCategory.append(c)
        patients.append(Patient(patient["id"], l, c, s, d, e, appStart, appDuration, embar))

        numRequests += 1

    adjMatrix = data["distMatrix"]


    #################################
    ###                          ####
    ###   Call Minizinc Model    ####
    ###                          ####
    #################################


    # Do stuff

    with open(output_file, "w") as f:
        json.dump(data, f, indent=4) # TODO - ver que indent prefiro
    
    exit(0)
