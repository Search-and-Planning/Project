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
par int: maxWaitTime;

set of 1..numPatientCategories: categories;
par int: R; % Number of requests
int: numActivities = 2 * R; % Request = Forward Activity + Backwards Activity

%array[1..numVehicles] of record(int: capacity, set of categories: compatiblePatients): vehicle;
array[1..numVehicles] of int: capacity;
array[1..numVehicles] of set of categories: compatiblePatients;

array[1..numPlaces, 1..numPlaces] of int: distMatrix; % TODO - Do we need to replace int by float?

array[1..R] of categories: patientCategory; % category of the patient of the ith request


array[1..R] of int: rdvTime; % rdvTime[i] = starting time of appointment for request i. (ui in the literature)
array[1..R] of int: rdvDuration; % duration of the ith request's appointment. (di in the literature)
array[1..R] of int: srv; % embark/disembark time of the ith patient to a vehicle
array[1..R] of int: startLocation;
array[1..R] of int: destination;
array[1..R] of int: endLocation;
array[1..R] of int: load; % number of places taken by patient i in the vehicle (l[i] in the literature)

int: timeHorizon;

%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Decision Variables %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%

% Activity Variables %

%array[1..numActivities] of var 0..maxTime-maxWaitTime: s; % placeholder for the domain
%array[1..numActivities] of var min..max: e; % placeholders for the domain
array[1..numActivities] of var 0..timeHorizon: s;
array[1..numActivities] of var 0..timeHorizon: e;


% v[i] is the vehicle assigned to activity i
% 0 represents that no vehicle was selected
array[1..numActivities] of var 0..numVehicles: v;
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
    destination[n mod 2] % Backward Activity
  endif;
  
function int: activityEndLocation(int: n) =
  if (n mod 2) == 1 then
    destination[n mod 2] % Forward activity
  else
    endLocation[n mod 2] % Backward Activity
  endif;
  
function int: activityTimeLowerBound(int: n) =
  if (n mod 2) == 1 then
    0 % Forward activity
  else
    rdvTime[n] + rdvDuration[n] + maxWaitTime % Backward Activity
  endif;

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
); % Need both implications to make it an equivalence

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
    
    
% Patients must be at their destinations within certain time windows
% equation 14 in the literature
constraint
  forall(i in 1..R)(
    ( (0 <= s[nthForwardActivity(i)]) /\ (s[nthForwardActivity(i)] <= (rdvTime[i] - maxWaitTime) ) )
    /\
    ( ( (rdvTime[i] + rdvDuration[i] + maxWaitTime) <= s[nthBackwardActivity(i)]) /\ (s[nthBackwardActivity(i)] <= timeHorizon) )
);
    
% TODO - see if there is a change in performance by combining the e[] domain constraint
% and the s[] equivalent; Or see if the pruning improves by making it a unary constraint
% equation 14 in the literature
constraint
  forall(i in 1..R)(
    % Restrict domain for end of forward activities
    ( (0 <= e[nthForwardActivity(i)]) /\ (e[nthForwardActivity(i)] <= (rdvTime[i] - maxWaitTime)) )
    /\
    % Restrict domain for end of backward activities
    ( ( (rdvTime[i] + rdvDuration[i] + maxWaitTime) <= e[nthBackwardActivity(i)]) /\ (e[nthBackwardActivity(i)] <= timeHorizon) )
);  
    
    
% Instances restricting forward and backward activities to have the same vehicle
constraint
  if sameVehicleBackwards then
    forall(i in 1..R)
      (v[nthForwardActivity(i)] == v[nthBackwardActivity(i)])
  endif;
  

% If an activity isn't selected, the values for the assigned vehicle,
% starting time and end time should reflect that 
% We chose to assign them the lowest possible value
constraint
  forall(i in 1..numActivities)(
    ( (x[i] == 0) -> (v[i] = 0) )
    /\
    ( (x[i] == 0) -> (s[i] = 0) )
    /\
    ( (x[i] == 0) -> (e[i] = activityTimeLowerBound(i)) )
);


% Patients can only be taken by some vehicle categories
constraint
  forall(i in 1..R)(
    if v[nthForwardActivity(i)] != 0 then
      % Used let and in keywords to handle var opt type of v[]
      patientCategory[i] in compatiblePatients[v[nthForwardActivity(i)]]
    endif
    /\
    if v[nthBackwardActivity(i)] != 0 then
      patientCategory[i] in compatiblePatients[v[nthBackwardActivity(i)]]
    endif
); % TODO - Try replacing the if condition by x[] != 0 and see if the inference improves or worsens

    
% (Inter-Activity Time Travel Consistency) Equation 6 in the literature
constraint
  forall(i in 1..numActivities, j in i+1..numActivities)(
    if v[i] != 0 /\ v[j] != 0 then % if vehicles were selected for the activities
      (v[i] == v[j]) -> ( (s[j] - s[i] >= distMatrix[activityStartLocation(i), activityStartLocation(j)] + srv[i])
                      \/ ( s[i] - s[j] >= distMatrix[activityStartLocation(j), activityStartLocation(i)] + srv[j]) )
      /\
      (v[i] == v[j]) -> ( (s[j] - e[i] >= distMatrix[activityStartLocation(i), activityEndLocation(j)]) 
                      \/ ( e[i] - s[j] >= distMatrix[activityStartLocation(j), activityEndLocation(i)] + srv[j] + srv[i]) )
      /\
      (v[i] == v[j]) -> ( (e[j] - s[i] >= distMatrix[activityEndLocation(i), activityStartLocation(j)] + srv[i] + srv[j]) 
                      \/ ( s[i] - e[j] >= distMatrix[activityEndLocation(j), activityStartLocation(i)]) )
      /\
      (v[i] == v[j]) -> ( (e[j] - e[i] >= distMatrix[activityEndLocation(i), activityEndLocation(j)] + srv[j]) 
                      \/ ( e[i] - e[j] >= distMatrix[activityEndLocation(j), activityEndLocation(i)] + srv[i]) )
    endif
); % TODO - How to handle non-existent forward/backward activities??? (Maybe the if is enough to cover that)


% (Intra-Activity Time Travel Consistency) Equation 7 in the literature
% The duration of each activity cannot be lesser than the time required 
% to go from the origin to the destination
constraint
  forall(i in 1..numActivities)
    (duration(i) >= distMatrix[activityStartLocation(i), activityEndLocation(i)]);
    

% (Maximum Travel Time) Equation 8 in the literature
% Prevents situations where a patient stays too long in a vehicle
constraint
  forall(i in 1..numActivities)
    (duration(i) <= -100); % TODO - take care of the placeholder value
    
    
% maxWaitTime constraint? Ver enunciado


%%%%%%%%%%%%
%%% Goal %%%
%%%%%%%%%%%%

solve maximize sum(i in 1..R)(S[i]); % TODO - Experimentar substituir pelas equações 11 e/ou 12 ou fazer uma conjunção das 3