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
par bool: sameVehicleBackwards;
par int: maxWaitTime;
par int: minCategory;
par int: maxCategory;
par int: R; % Number of requests
int: numActivities = 2 * R; % Request = Forward Activity + Backwards Activity

array[1..numPlaces, 1..numPlaces] of int: distMatrix; % TODO - Do we need to replace int by float?
int: timeHorizon;

%%% Vehicle Parameters %%%

array[1..numVehicles] of int: vehicleStartLocation; % Starting position of each vehicle
array[1..numVehicles] of int: vehicleEndLocation; % Final location of each vehicle after shift has ended
array[1..numVehicles] of int: vehicleStartTime; % Starting time of each vehicle's shift
array[1..numVehicles] of int: vehicleEndTime; % End of each vehicle's shift
array[1..numVehicles] of int: capacity;
array[1..numVehicles] of set of minCategory..maxCategory: compatiblePatients;


%%% Patient/Request parameters %%%

array[1..R] of minCategory..maxCategory: patientCategory; % category of the patient of the ith request
array[1..R] of int: rdvTime; % rdvTime[i] = starting time of appointment for request i. (ui in the literature)
array[1..R] of int: rdvDuration; % duration of the ith request's appointment. (di in the literature)
array[1..R] of int: srv; % embark/disembark time of the ith patient to a vehicle
array[1..R] of int: startLocation;
array[1..R] of int: destination;
array[1..R] of int: endLocation;
array[1..R] of int: load; % number of places taken by patient i in the vehicle (l[i] in the literature)


%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Decision Variables %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Activity Variables %%%

array[1..numActivities] of var 0..timeHorizon: s;
array[1..numActivities] of var 0..timeHorizon: e;
array[1..numActivities] of var 0..maxWaitTime: d;

% v[i] is the vehicle assigned to activity i
% 0 represents that no vehicle was selected
array[1..numActivities] of var 0..numVehicles: v;
array[1..numActivities] of var bool: x;

%%% Request Variable %%%
array[1..R] of var bool: S; % S[i] = 1 if request i is selected, 0 otherwise


%%%%%%%%%%%%%%%%%%
%%%  Functions %%%
%%%    and     %%%
%%% Predicates %%%
%%%%%%%%%%%%%%%%%%
% TODO - review computation (acho que está bem)
function int: nthForwardActivity(int: n) = (2 * n) - 1;

% TODO - review computation (acho que está bem)
function int: nthBackwardActivity(int: n) = 2 * n;

function int: activityToRequest(int: n) = 
  if (n mod 2) == 1 then
    (n div 2) + 1 % Forward activity
  else
    n div 2 % Backward Activity
  endif;

function int: activityStartLocation(int: n) = 
  if (n mod 2) == 1 then
    startLocation[(n div 2) + 1] % Forward activity
  else
    destination[n div 2] % Backward Activity
  endif;
  
function int: activityEndLocation(int: n) =
  if (n mod 2) == 1 then
    destination[(n div 2) + 1] % Forward activity
  else
    endLocation[n div 2] % Backward Activity
  endif;

% TODO - review indices on the else branch (Should be good now?)
function int: activityTimeLowerBound(int: n) =
  if (n mod 2) == 1 then
    0 % Forward activity
  else
    rdvTime[n div 2] + rdvDuration[n div 2] + maxWaitTime % Backward Activity
  endif;


%%%%%%%%%%%%%%%%%%%
%%% Constraints %%%
%%%%%%%%%%%%%%%%%%%

% (Empty Locations) Equation 17 in the literature
% Selecting a Request is equivalent to selecting the corresponding
% forward or backward activity
constraint
  forall(i in 1..R)(
    ( S[i] == 1 -> (x[nthForwardActivity(i)] == 1 \/ x[nthBackwardActivity(i)] == 1) )
    /\
    ( (x[nthForwardActivity(i)] == 1 \/ x[nthBackwardActivity(i)] == 1) -> S[i] == 1 )
); % Need both implications to make it an equivalence


% Don't select forward activity if the request doesn't have one
constraint
  forall(i in 1..R)
    (startLocation[i] == -1 -> x[nthForwardActivity(i)] == 0);

% Don't select backward activity if the request doesn't have one
constraint
  forall(i in 1..R)
    (endLocation[i] == -1 -> x[nthBackwardActivity(i)] == 0);

% If request has both kind of activities, they must either both be selected
% or neither is selected
constraint
  forall(i in 1..R)(
    (startLocation[i] != -1 /\ endLocation[i] != -1) -> 
    (x[nthForwardActivity(i)] == x[nthBackwardActivity(i)])
);

    
% Patients must be at their destinations within certain time windows
% equation 14 in the literature (starting times)
constraint
  forall(i in 1..R)(
    ( (0 <= s[nthForwardActivity(i)]) /\ (s[nthForwardActivity(i)] <= (rdvTime[i] - maxWaitTime) ) )
    /\
    ( ( (rdvTime[i] + rdvDuration[i] + maxWaitTime) <= s[nthBackwardActivity(i)]) /\ (s[nthBackwardActivity(i)] <= timeHorizon) )
);
    

% and the s[] equivalent; Or see if the pruning improves by making it a unary constraint
% equation 14 in the literature (ending times)
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
  sameVehicleBackwards -> forall(i in 1..R)(
    v[nthForwardActivity(i)] == v[nthBackwardActivity(i)]
);
  

% If an activity isn't selected, the values for the assigned vehicle,
% starting time and end time should reflect that 
% We chose to assign them the lowest possible value
constraint
  forall(i in 1..numActivities)(
    ( (not x[i]) -> (v[i] = 0) )
    /\
    ( (v[i] == 0) -> (not x[i]) )
    /\
    ( (not x[i]) -> (s[i] = activityTimeLowerBound(i)) )
    /\
    ( (not x[i]) -> (e[i] = activityTimeLowerBound(i)) )
);

% If an activity was selected, a vehicle must be assigned to it
constraint
  forall(i in 1..numActivities)(
    x[i] -> (v[i] != 0)
);


% Patients can only be taken by some vehicle categories
% TODO - split into two constraints and see if propagation improves
constraint
  forall(i in 1..R)(
    ((v[nthForwardActivity(i)] != 0) -> (
      % if the forward activity is selected, the vehicle must be compatible with the patient
      patientCategory[i] in compatiblePatients[v[nthForwardActivity(i)]]
    ))
    /\
    ((v[nthBackwardActivity(i)] != 0) -> (
      % if the backward activity is selected, the vehicle must be compatible with the patient
      patientCategory[i] in compatiblePatients[v[nthBackwardActivity(i)]]
    ))
); % TODO - Try replacing the if condition by x[] != 0 and see if the inference improves or worsens

    
% (Inter-Activity Time Travel Consistency) Equation 6 in the literature
constraint
  forall(i in 1..numActivities, j in i+1..numActivities)(
    if v[i] != 0 then % if vehicles were selected for the activities
      (v[i] == v[j]) -> ( (s[j] - s[i] >= distMatrix[activityStartLocation(i), activityStartLocation(j)] + srv[activityToRequest(i)])
                      \/ ( s[i] - s[j] >= distMatrix[activityStartLocation(j), activityStartLocation(i)] + srv[activityToRequest(j)]) )
      /\
      (v[i] == v[j]) -> ( (s[j] - e[i] >= distMatrix[activityStartLocation(i), activityEndLocation(j)]) 
                      \/ ( e[i] - s[j] >= distMatrix[activityEndLocation(j), activityStartLocation(i)] + srv[activityToRequest(j)] + srv[activityToRequest(i)]) )
      /\
      (v[i] == v[j]) -> ( (e[j] - s[i] >= distMatrix[activityEndLocation(i), activityStartLocation(j)] + srv[activityToRequest(i)] + srv[activityToRequest(j)]) 
                      \/ ( s[i] - e[j] >= distMatrix[activityStartLocation(j), activityEndLocation(i)]) )
      /\
      (v[i] == v[j]) -> ( (e[j] - e[i] >= distMatrix[activityEndLocation(i), activityEndLocation(j)] + srv[activityToRequest(j)]) 
                      \/ ( e[i] - e[j] >= distMatrix[activityEndLocation(j), activityEndLocation(i)] + srv[activityToRequest(i)]) )
    endif
);


% (Intra-Activity Time Travel Consistency) Equation 7 in the literature
% The duration of each activity cannot be lesser than the time required 
% to go from the origin to the destination
constraint
  forall(i in 1..numActivities)
    (d[i] >= distMatrix[activityStartLocation(i), activityEndLocation(i)] + 2 * srv[activityToRequest(i)]);
    % (duration(i) >= distMatrix[activityStartLocation(i), activityEndLocation(i)]);


% Activity duration can't be negative
% Redundant with Intra-Activity Time Travel Consistency constraint
% constraint
%   forall(i in 1..numActivities)(
%     e[i] >= s[i]
% );

constraint 
  forall(i in 1..numActivities)(
    d[i] = (e[i] - s[i])
);


% (Vehicle Availability) Equation 15 in the literature
% Vehicles have intervals where they are available to handle requests and
% those time windows may be non continuous
constraint
  forall(i in 1..numActivities)(
    x[i] -> (
      s[i] >= vehicleStartTime[v[i]] + distMatrix[vehicleStartLocation[v[i]], activityStartLocation(i)] 
      /\
      e[i] <= vehicleEndTime[v[i]] - distMatrix[activityEndLocation(i), vehicleEndLocation[v[i]]]
    )
);
% TODO - should this take into account embark time?


% (Cumulative Resource) Equation 9 in the literature
% At any moment, the number of places occupied by patients
% in a same vehicle j cannot exceed its capacity (capacity[j])
constraint
  forall(j in 1..numVehicles)( % For each vehicle
    cumulative(
    [s[i] * bool2int(j == v[i])| i in 1..numActivities], % starting times for activities assigned to vehicle j
    % [duration(i) * bool2int(j == v[i])| i in 1..numActivities],
    [d[i] * bool2int(j == v[i])| i in 1..numActivities], % durations of those activities
    [load[activityToRequest(i)] * bool2int(j == v[i])| i in 1..numActivities], % resource consumption of those activities
    capacity[j]
    )
);
% Note: MiniZinc's implementation for the Cumulative Global Constraint requires
% index_set(s[]) = index_set(duration[]) = index_set(load[]). Since we wanted to iterate
% over the capacity of each vehicle, we had to "trim down" those three arrays
% (to avoid restricting vehicles with capacities and/or activities that don't belong to them).
% MiniZinc 2.7.6 (version used) can't figure out the size of variable length arrays
% (our case, because the tasks assigned per vehicle vary), turning them all into
% array[int] of var opt int (which the Cumulative Global Constraint can't handle), 
% so the solution was to create fixed size arrays and pad them with 0s for 
% the activities not assigned to vehicle j


%%%%%%%%%%%%
%%% Goal %%%
%%%%%%%%%%%%
% TODO - Experimentar substituir pelas equações 11 e/ou 12 ou fazer uma conjunção das 3

solve maximize sum(i in 1..R)(S[i]) ::bool_search(S, first_fail, indomain_max)
          ::int_search(s, first_fail, indomain_min)
          ::int_search(e, first_fail, indomain_min)
          ::int_search(v, first_fail, indomain_random)
;