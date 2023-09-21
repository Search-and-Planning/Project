% Model for the Patient Transportation Problem
%
% Implementation based on:
% Cappart, Quentin ; Thomas, Charles ; Schaus, Pierre ; Rousseau, Louis-Martin. A Constraint Programming
% Approach for Solving Patient Transportation Problems.CP: International Conference on Principles and
% Practice of Constraint Programming (Lille, du 27/08/2018 au 31/08/2018). In: Lecture Notes in Computer
% Science : Principles and Practice of Constraint Programming, John Hooker2018, p. 490-506 http://
% hdl.handle.net/2078.1/202079 -- DOI : 10.1007/978-3-319-98334-9_32

include "cumulative.mzn";
%include "minisearch.mzn";

%%%%%%%%%%%%%%%%%%
%%% Parameters %%%
%%%%%%%%%%%%%%%%%%

par int: numVehicles;
par int: numPlaces;
par int: numPatientCategories;
par bool: sameVehicleBackwards;

set of 1..numPatientCategories: categories;
par int: R; % Number of requests
int: numActivities = 2 * R; % Request = Forward Activity + Backwards Activity

array[1..numVehicles] of record(int: capacity, set of categories: compatiblePatients): vehicle;

array[1..numPlaces, 1..numPlaces] of int: distMatrix; % TODO - Do we need to replace int by float?

array[1..numActivities] of categories: patientCategory; % category of the patient of the ith activity


% TODO - replace by record type?
array[1..R] of int: appointmentTime; % appointmentTime[i] = starting time of appointment for request i. (ui in the literature)
array[1..R] of int: appointmentDuration; % duration of the ith request's appointment. (di in the literature)
array[1..R] of int: startLocation;
array[1..R] of int: destination;
array[1..R] of int: endLocation;

int: max; % placeholder (H time Horizon in the literature)
int: min; % placeholder -> menor dos tempos de início de consulta + menor duração
int: maxTime; % placeholder  -> maior dos tempos de início de consulta

%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Decision Variables %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%

% Activity Variables %

% s, e and v are optional types, because they only matter if the activity
% has been selected
array[1..numActivities] of var opt 0..maxTime: s; % placeholder for the domain
array[1..numActivities] of var opt min..max: e; % placeholders for the domain
array[1..numActivities] of var opt 1..numVehicles: v; % assignedVehicle[i] is the vehicle assigned to activity i
array[1..numActivities] of var bool: x;

% Request Variable %
array[1..R] of var bool: S; % S[i] = 1 if request i is selected, 0 otherwise


%%%%%%%%%%%%%%%%%%
%%%  Functions %%%
%%%    and     %%%
%%% Predicates %%%
%%%%%%%%%%%%%%%%%%

function int: nthForwardActivity(int: n) = (2 * n) - 1;

function int: nthBackwardActivity(int: n) = 2 * n;

% TODO - does this work? returning var int seems strange
function var int: duration(int: activity) = e[activity] - s[activity];

%%%%%%%%%%%%%%%%%%%
%%% Constraints %%%
%%%%%%%%%%%%%%%%%%%

% (Empty Locations) Equation 17 in the literature
% Selecting a Request is equivalent to selecting the corresponding
% at least the forward or backward activity
% TODO - still need to ensure that the activities that required both types (i think it's done?)
% have them match
constraint
  forall(i in 1..R)(
    ( S[i] == 1 -> (x[nthForwardActivity(i)] == 1 \/ x[nthBackwardActivity(i)] == 1) )
    /\
    ( (x[nthForwardActivity(i)] == 1 \/ x[nthBackwardActivity(i)] == 1) -> S[i] == 1 )
);

% Don't select forward activity if the request doesn't have one
% TODO - Check if we really need this one
constraint
  forall(i in 1..R)
    (startLocation[i] == -1 -> x[nthForwardActivity(i)] == 0);

% Don't select backward activity if the request doesn't have one
% TODO - Check if we really need this one
constraint
  forall(i in 1..R)
    (endLocation[i] == -1 -> x[nthBackwardActivity(i)] == 0);
    
    
% Instances restricting forward and backward activities to have the same vehicle
constraint
  if sameVehicleBackwards then
    forall(i in 1..R)
      (v[nthForwardActivity(i)] == v[nthBackwardActivity(i)])
  endif;

    
% (Inter-Activity Time Travel Consistency) Equation 6 in the literature
% TODO - finish distMatrix part of inequalities
constraint
  forall(i in 1..numActivities, j in i+1..numActivities)(
    (v[i] == v[j]) -> ( (s[j] - s[i] >= distMatrix[,]) \/ ( s[i] - s[j] >= distMatrix[,]) )
    /\
    (v[i] == v[j]) -> ( (s[j] - s[i] >= distMatrix[,]) \/ ( s[i] - s[j] >= distMatrix[,]) )
    /\
    (v[i] == v[j]) -> ( (s[j] - s[i] >= distMatrix[,]) \/ ( s[i] - s[j] >= distMatrix[,]) )
    /\
    (v[i] == v[j]) -> ( (s[j] - s[i] >= distMatrix[,]) \/ ( s[i] - s[j] >= distMatrix[,]) )
); % TODO - How to handle non-existent forward/backward activities???
  

% TODO - add constraints for start and end time when forward/backward activity isn't selected?

% (Forward and Backward Selection) Equation 5 in the literature
% If a forward activity is selected, the corresponding backward activity
% must be aswell
%constraint
%  forall(i in 1..R)(x[(2 * i) - 1] == x[2 * i]);

%%%%%%%%%%%%
%%% Goal %%%
%%%%%%%%%%%%

solve maximize sum(i in 1..R)(S[i]); % TODO - Experimentar substituir pelas equações 11 e/ou 12 ou fazer uma conjunção das 3