% Model for the Patient Transportation Problem

include "cumulative.mzn";
include "minisearch.mzn";

%%% Parameters %%%

par int: numVehicles;
par int: numPatients; % Do I need this?
par int: numPlaces;

par int: R; % Number of requests

array[1..numVehicles] of int: vehicleCapacity;

array[1..numPlaces, 1..numPlaces] of int: distMatrix; % TODO - Do we need to replace int by float?


%%% Decision Variables %%%

array[1..R] of var bool: Request;


%%% Constraints %%%

%%% Goal %%%
