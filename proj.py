import json
import sys
from itertools import count as count
from minizinc import Instance, Model, Solver
from time import sleep

# TODO - Output


###################################
###                             ###
###     Auxiliary Classes       ###
###                             ###
###################################


class Vehicle:

    # Some vehicles may have multiple non continous time intervals where they are
    # available. To represent this in minizinc, we duplicate the vehicle for each
    # interval. This counter corresponds to how that shift will be identified
    # in minizinc
    minizinc_id = count(1)

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

    minizinc_id = count(1)

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
    

class VehicleOutput:

    class VehicleOutputEncoder(json.JSONEncoder):
        """Class used to serialize profiles into a JSON string"""
        def default(self, o):
            return o.__dict__

    class Trip:
        def __init__(self, origin, destination, arrival, patients) -> None:
            self.origin = origin
            self.destination = destination
            self.arrival = arrival
            self.patients = patients


        def __str__(self) -> str:
            return "Trip from " + str(self.origin) + " to " + str(self.destination) + \
                " arriving at " + str(self.arrival) + " with patients " + str(self.patients)

    def __init__(self, id, trips):
        self.id = id
        self.trips = trips

    def __eq__(self, __value: object) -> bool:
        return self.id == __value.id


class Output():
    
        class OutputEncoder(json.JSONEncoder):
            """Class used to serialize profiles into a JSON string"""
            def default(self, o):
                return o.__dict__
    
        def __init__(self, vehicles, requests):
            self.requests = requests
            self.vehicles = vehicles


###################################
###                             ###
###     Auxiliary Functions     ###
###                             ###
###################################
        

def time_to_minutes(time: str) -> int:
    """Converts a time in the format HHhMM to minutes"""

    time = time.split('h')
    return int(time[0]) * 60 + int(time[1])


def minutes_to_time(minutes: int) -> str:
    """Converts a time in minutes to the format HHhMM"""

    hours = minutes // 60
    minutes = minutes % 60
    return str(hours) + "h" + str(minutes)


def flatten(l: list) -> list:
    """Flattens a list of sets into a single list"""

    return [item for subset in l for item in subset]


def matching_vehicles(mini_zinc_vehicle, vehicle):
    return mini_zinc_vehicle == vehicle.minizinc_id



def assign_instance_parameters(instance, r, capacity, categories, compatiblePatients, distMatrix,
                             endLocation, load, maxWaitTime,
                            minCategory, maxCategory, numPlaces, numVehicles, patientCategory,
                            rdvDuration, rdvTime, srv, sameVehicleBackwards,
                            startLocation, timeHorizon, vehicleEndLocation, vehicleEndTime,
                            vehicleStartLocation, vehicleStartTime):
    """Assigns the instance parameters to the minizinc instance"""

    instance["R"] = r
    instance["capacity"] = capacity
    # instance["categories"] = categories
    instance["compatiblePatients"] = compatiblePatients
    #instance["destination"] = destination
    instance["distMatrix"] = distMatrix
    instance["endLocation"] = endLocation
    instance["load"] = load
    instance["maxWaitTime"] = maxWaitTime
    instance["minCategory"] = minCategory
    instance["maxCategory"] = maxCategory
    instance["numPlaces"] = numPlaces
    instance["numVehicles"] = numVehicles
    instance["patientCategory"] = patientCategory
    instance["rdvDuration"] = rdvDuration
    instance["rdvTime"] = rdvTime
    instance["srv"] = srv
    instance["sameVehicleBackwards"] = sameVehicleBackwards
    instance["startLocation"] = startLocation
    instance["timeHorizon"] = timeHorizon
    instance["vehicleEndLocation"] = vehicleEndLocation
    instance["vehicleEndTime"] = vehicleEndTime
    instance["vehicleStartLocation"] = vehicleStartLocation
    instance["vehicleStartTime"] = vehicleStartTime


def print_instance_parameters(r, capacity, categories, compatiblePatients,distMatrix, endLocation,
                             load, maxWaitTime,
                            minCategory, maxCategory, numPlaces, numVehicles, patientCategory,
                            rdvDuration, rdvTime, srv, sameVehicleBackwards,
                            startLocation, timeHorizon, vehicleEndLocation, vehicleEndTime,
                            vehicleStartLocation, vehicleStartTime):
    """Prints the instance parameters"""
    print("R: ", r)
    print("capacity: ", capacity)
    # print("categories: ", categories)
    print("compatiblePatients: ", compatiblePatients)
    # print("destination: ", destination)
    #print("0 in destination: ", 0 in destination)
    print("distMatrix: ", distMatrix)
    print("endLocation: ", endLocation)
    #print("0 in endLocation: ", 0 in endLocation)
    print("load: ", load)
    print("maxWaitTime: ", maxWaitTime)
    print("minCategory: ", minCategory)
    print("maxCategory: ", maxCategory)
    print("numPlaces: ", numPlaces)
    print("numVehicles: ", numVehicles)
    print("patientCategory: ", patientCategory)
    print("rdvDuration: ", rdvDuration)
    print("rdvTime: ", rdvTime)
    print("srv: ", srv)
    print("sameVehicleBackwards: ", sameVehicleBackwards)
    print("startLocation: ", startLocation)
    print("0 in startLocation: ", 0 in startLocation)
    print("timeHorizon: ", timeHorizon)
    print("vehicleEndLocation: ", vehicleEndLocation)
    print("vehicleEndTime: ", vehicleEndTime)
    print("vehicleStartLocation: ", vehicleStartLocation)
    print("vehicleStartTime: ", vehicleStartTime)



def increment_matrix(matrix):
    """Increments all values in a matrix by 1"""

    for i in range(len(matrix)):
        for j in range(len(matrix[i])):
            matrix[i][j] += 1


def forwardActivity(n):
    """Returns true if the activity is a forward activity, false otherwise"""

    return (n % 2) == 0


def terminate_unsatisfiable(vehicles):
    """Prints an error message and exits the program if the model is unsatisfiable"""

    print("Model is unsatisfiable!")
    vehicleOutputs = []
    for vehicle in vehicles:
        tmpOutput = VehicleOutput(vehicle.real_id, [])
        if not tmpOutput in vehicleOutputs:
            vehicleOutputs.append(tmpOutput)

    output = Output(vehicleOutputs, 0)
    json.dump(output, open("output.json", "w"), indent=4, cls=Output.OutputEncoder)
    exit(1)


###################################
###                             ###
###   Main Function Execution   ###
###                             ###
###################################


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
    sameVehicleBackwards = data["sameVehicleBackward"] # Boolean
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
    flattenedCategories = []
    vehicleStartTime = []
    vehicleEndTime = []
    timeHorizon = 0
    numVehicles = 0
    for vehicle in data["vehicles"]:
        availabilities = vehicle["availability"]

        for availability in availabilities:
            # Handle vehicles with multiple availabilities
            tempVar = availability.split(':')
            startTime = time_to_minutes(tempVar[0])
            endTime = time_to_minutes(tempVar[1])
            if (endTime > timeHorizon):
                timeHorizon = endTime

            vehicleStartLocation.append(vehicle["start"] + 1)
            vehicleEndLocation.append(vehicle["end"] + 1)
            capacity.append(vehicle["capacity"])
            categories.append(set(vehicle["canTake"]))
            flattenedCategories += [i for i in vehicle["canTake"] if not i in flattenedCategories]
            vehicleStartTime.append(startTime)
            vehicleEndTime.append(endTime)

            vehicles.append(Vehicle(vehicle["id"], startTime, endTime, vehicle["start"], 
                                    vehicle["end"], vehicle["canTake"],
                                    vehicle["capacity"]))
            
            # Each availability is a different vehicle in the minizinc model
            numVehicles += 1


    start = []
    # destination = []
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
        d1 = patient["destination"]
        d2 = d1
        e = patient["end"]
        l = patient["load"]
        c = patient["category"]
        appStart = time_to_minutes(patient["rdvTime"])
        appDuration = time_to_minutes(patient["rdvDuration"])
        embar = time_to_minutes(patient["srvDuration"])
        patients.append(Patient(patient["id"], l, c, s, d1, e, appStart, appDuration, embar))
        if (s == -1):
            # No forward activity for this request
            s -=  1
            d1 = s
        # Forward Activity
        start.append(s + 1) # minizinc model starts at 1
        end.append(d1 + 1)

        if (e == -1):
            # No backward activity for this request
            e -= 1
            d2 = e
        if (not c in flattenedCategories):
            flattenedCategories.append(c)

        # Backward Activity
        start.append(d2 + 1)
        end.append(e + 1)


        appointmentStart.append(appStart)
        appointmentDuration.append(appDuration)
        embarkDuration.append(embar)
        load.append(l)
        patientCategory.append(c)

        numRequests += 1

    adjMatrix = data["distMatrix"]


    #################################
    ###                          ####
    ###   Call Minizinc Model    ####
    ###                          ####
    #################################

    # Load PTP model from file
    patientTransportation = Model("./PatientTransportationProblem.mzn")

    # Get a solver
    #solver = Solver.lookup("gecode")
    solver = Solver.lookup("chuffed")


    # Create an Instance of the PTP model for the solver to solve
    instance = Instance(solver, patientTransportation)

    # Assign instance parameters
    # assign_instance_parameters(instance, numRequests, capacity, categories, categories,
    #                         destination, adjMatrix, end, load, maxWaitTime,
    #                         min(flattenedCategories), max(flattenedCategories), numPlaces, numVehicles, patientCategory,
    #                         appointmentDuration, appointmentStart, embarkDuration, sameVehicleBackwards,
    #                         start, timeHorizon, vehicleEndLocation, vehicleEndTime,
    #                         vehicleStartLocation, vehicleStartTime)
    assign_instance_parameters(instance, numRequests, capacity, categories, categories, adjMatrix, end, load, maxWaitTime,
                            min(flattenedCategories), max(flattenedCategories), numPlaces, numVehicles, patientCategory,
                            appointmentDuration, appointmentStart, embarkDuration, sameVehicleBackwards,
                            start, timeHorizon, vehicleEndLocation, vehicleEndTime,
                            vehicleStartLocation, vehicleStartTime)    

    # Solve the instance
    # print_instance_parameters(numRequests, capacity, categories, categories,
    #                         destination, adjMatrix, end, load, maxWaitTime,
    #                         min(flattenedCategories), max(flattenedCategories), numPlaces, numVehicles, patientCategory,
    #                         appointmentDuration, appointmentStart, embarkDuration, sameVehicleBackwards,
    #                         start, timeHorizon, vehicleEndLocation, vehicleEndTime,
    #                         vehicleStartLocation, vehicleStartTime)
    print_instance_parameters(numRequests, capacity, categories, categories, adjMatrix, end, load, maxWaitTime,
                            min(flattenedCategories), max(flattenedCategories), numPlaces, numVehicles, patientCategory,
                            appointmentDuration, appointmentStart, embarkDuration, sameVehicleBackwards,
                            start, timeHorizon, vehicleEndLocation, vehicleEndTime,
                            vehicleStartLocation, vehicleStartTime)
    print("Solving...")
    result = instance.solve()
    print("Search Complete!")
    print("type(result):", type(result))
    print("result.status:", result.status)
    print("result:", result)
    #print("result[0]:", result[0])
    # print("v:", result["v"])
    try:
        objective = result["objective"]
    except KeyError:
        terminate_unsatisfiable(vehicles)

    v = result["v"]
    x = result["x"]
    s = [minutes_to_time(m) for m in result["s"]]
    e = [minutes_to_time(m) for m in result["e"]]
    outputVehicles = []
    for vehicle in vehicles:
        #activityNum = 0
        trips = []
        patientOutput = []
        last_location = vehicle.shift_start_location
        last_time = 0
        for activityNum in range(len(s)):
            if x[activityNum] == 0 or not matching_vehicles(v[activityNum], vehicle):
                # Activity wasn't selected
                continue
            else:
                # Activity was selected
                patient = activityNum // 2
                assigned_vehicle = v[activityNum]
                # print("activity num:", activityNum)
                # print("patient:", patient)
                # print("patients[patient]:", patients[patient])
                # print("patients[patient].real_id:", patients[patient].real_id)
                origin = start[activityNum] - 1
                dest = end[activityNum] - 1

                # Go to pick up location
                if (last_location != origin):
                    trips.append(VehicleOutput.Trip(last_location, origin, s[activityNum], patientOutput))

                # Board patient
                # print("origin == dest:", origin == dest)
                # print("activityNum:", activityNum)
                patientOutput += [p for p in patientOutput] + [patients[patient].real_id]

                # Go to drop off point
                trips.append(VehicleOutput.Trip(origin, dest, e[activityNum], [p for p in patientOutput]))

                # Remove patient from vehicle
                patientOutput.remove(patients[patient].real_id)
                last_location = dest
                last_time = e[activityNum]
        
        if (last_location != vehicle.shift_end_location):
            dest = vehicle.shift_end_location
            dropoff_time = minutes_to_time(time_to_minutes(last_time) + adjMatrix[last_location][dest])
            trips.append(VehicleOutput.Trip(last_location, dest, dropoff_time, []))
        outputVehicles.append(VehicleOutput(vehicle.real_id, trips))
    
    output = Output(outputVehicles, objective)

    json.dump(output, open("output.json", "w"), indent=4, cls=Output.OutputEncoder)



    
    #################################
    ###                          ####
    ###   Process Output Json    ####
    ###                          ####
    #################################



    # Do stuff

    with open(output_file, "w") as f:
        json.dump(data, f, indent=4) # TODO - ver que indent prefiro
    
    exit(0)
