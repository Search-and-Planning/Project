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

array[1..R] of categories: patientCategory; % category of the patient of the ith request


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

function int: activityStartLocation(int: n) = 
  if (n mod 2) == 1 then
    startLocation[n mod 2] % Forward activity
  else
    destinationLocation[n mod 2] % Backward Activity
  endif;
  
function int: activityEndLocation(int: n) =
  if (n mod 2) == 1 then
    destinationLocation[n mod 2] % Forward activity
  else
    endLocation[n mod 2] % Backward Activity
  endif;

% TODO - does this work? returning var int seems strange
function var int: duration(int: activity) = e[activity] - s[activity];

%%%%%%%%%%%%%%%%%%%
%%% Constraints %%%
%%%%%%%%%%%%%%%%%%%

% (Empty Locations) Equation 17 in the literature
% Selecting a Request is equivalent to selecting the corresponding
% forward or backward activity
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
  

% If an activity isn't selected, the values for the assigned vehicle,
% starting time and end time should be absent
constraint
  forall(i in 1..numActivities)(
    ( (x[i] == 0) -> (v[i] = <>) )
    /\
    ( (x[i] == 0) -> (s[i] = <>) )
    /\
    ( (x[i] == 0) -> (e[i] = <>) )
);


% Patients can only be taken by some vehicle categories
constraint
  forall(i in 1..R)(
    member(vehicle[v[nthForwardActivity(i)]].compatiblePatients, patientCategory[i])
    /\
    member(vehicle[v[nthBackwardActivity(i)]].compatiblePatients, patientCategory[i])
); % TODO - handle option types;

    
% (Inter-Activity Time Travel Consistency) Equation 6 in the literature
constraint
  forall(i in 1..numActivities, j in i+1..numActivities)(
    if occurs(v[i]) then % if optional value isn't absent
      (v[i] == v[j]) -> ( (s[j] - s[i] >= distMatrix[activityStartLocation(i), activityStartLocation(j)])
                      \/ ( s[i] - s[j] >= distMatrix[activityStartLocation(j), activityStartLocation(i)]) )
      /\
      (v[i] == v[j]) -> ( (s[j] - e[i] >= distMatrix[activityStartLocation(i), activityEndLocation(j)]) 
                      \/ ( e[i] - s[j] >= distMatrix[activityStartLocation(j), activityEndLocation(i)]) )
      /\
      (v[i] == v[j]) -> ( (e[j] - s[i] >= distMatrix[activityEndLocation(i), activityStartLocation(j)]) 
                      \/ ( s[i] - e[j] >= distMatrix[activityEndLocation(j), activityStartLocation(i)]) )
      /\
      (v[i] == v[j]) -> ( (e[j] - e[i] >= distMatrix[activityEndLocation(i), activityEndLocation(j)]) 
                      \/ ( e[i] - e[j] >= distMatrix[activityEndLocation(j), activityEndLocation(i)]) )
    endif
); % TODO - How to handle non-existent forward/backward activities??? (Maybe the if is enough to cover that)
% TODO - need to take into account embark time (ver email do David)


% (Intra-Activity Time Travel Consistency) Equation 7 in the literature
% The duration of each activity cannot be lesser than the time required 
% to go from the origin to the destination
constraint
  forall(i in 1..numActivities)
    (duration(i) >= distMatrix[activityStartLocation(i), activityEndLocation(i)]);
    

% (Maximum Travel Time) Equation 8 in the literature
% Prevents situations where a patient stays too long in a vehicle
constraint true; % TODO - Implement


%%%%%%%%%%%%
%%% Goal %%%
%%%%%%%%%%%%

solve maximize sum(i in 1..R)(S[i]); % TODO - Experimentar substituir pelas equações 11 e/ou 12 ou fazer uma conjunção das 3