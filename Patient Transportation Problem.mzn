% Model for the Patient Transportation Problem

include "cumulative.mzn";
include "minisearch.mzn";

%%%%%%%%%%%%%%%%%%
%%% Parameters %%%
%%%%%%%%%%%%%%%%%%

par int: numVehicles;
par int: numPatients; % Do I need this? Probably replace by request/activity
par int: numPlaces;

par int: R; % Number of requests

array[1..numVehicles] of int: vehicleCapacity;

array[1..numPlaces, 1..numPlaces] of int: distMatrix; % TODO - Do we need to replace int by float?

%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Decision Variables %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%

array[1..R] of var bool: S; % S[i] = 1 if request i is selected, 0 otherwise

%%%%%%%%%%%%%%%%%%%%
%%% Constraints %%%
%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%
%%% Goal %%%
%%%%%%%%%%%%

solve maximize sum(i in 1..R)(S[i]); % TODO - Experimentar substituir pelas equações 11 e/ou 12 ou fazer uma conjunção das 3