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
par int: numPatients; % Do I need this? Probably replace by request/activity
par int: numPlaces;
par int: numPatientCategories;

set of 1..numPatientCategories: categories;
par int: R; % Number of requests
int: numActivities = 2 * R; % Request = Forward Activity + Backwards Activity

array[1..numVehicles] of record(int: capacity, set of categories: compatiblePatients): vehicle;

array[1..numPlaces, 1..numPlaces] of int: distMatrix; % TODO - Do we need to replace int by float?

array[1..numActivities] of categories: patientCategory; % category of the patient of the ith activity


%array[1..R] of record(int: start, int: duration): appointment;
array[1..R] of int: appointmentTime; % appointmentTime[i] = starting time of appointment for request i. (ui in the literature)
array[1..R] of int: appointmentDuration; % duration of the ith request's appointment. (di in the literature)

int: max; % placeholder (H time Horizon in the literature)
int: min; % placeholder
int: maxTime; % placeholder

%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Decision Variables %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%

array[1..numActivities] of var 1..numVehicles: assignedVehicle; % assignedVehicle[i] is the vehicle assigned to activity i

% location[i] = some place
% if i % 2 == 0: Then location[i] is the origin location of activity i
% else: it is the destination location of activity i
% TODO - handling requests without return activity?
array[1..numActivities] of var 1..numPlaces: locations;

array[1..R] of var bool: S; % S[i] = 1 if request i is selected, 0 otherwise
array[1..numActivities] of var 0..maxTime: start; % placeholder for the domain
array[1..numActivities] of var min..max: end; % placeholders for the domain


% TODO - pensar em como representar a "load" de um veiculo num dado instante, porque não podemos exceder a capacidade


%%%%%%%%%%%%%%%%%%%
%%% Constraints %%%
%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%
%%% Goal %%%
%%%%%%%%%%%%

solve maximize sum(i in 1..R)(S[i]); % TODO - Experimentar substituir pelas equações 11 e/ou 12 ou fazer uma conjunção das 3