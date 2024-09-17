% ` or `ReadRight()`), set up callbacks for these events. This would minimize the continuous checks for hardware status.
% 
% 2. **Avoid Excessive Use of Global GUI Updates**:
%    - Frequent updates to GUI elements like `message_handle.Text` or figure color rendering can significantly reduce performance when executed repeatedly in tight loops. Instead, batch certain updates.
% 
% 3. **Async or Timer-based Execution**:
%    - Where suitable, employ `matlab.ui.internal.Timer` or the built-in `timer` function to handle periodic tasks without blocking the main execution thread. This can especially help improve responsiveness during time-waiting intervals.
% 
% 4. **Data Storage Efficiency**:
%    - When storing large objects like `StimHistory`, `wheelchoice`, or `Data_Object`, optimize memory usage by using more efficient data containers, such as MATLAB cell arrays or even sparse matrices when appropriate. Also, reduce unnecessary pre-allocation of large arrays (e.g., in `wheelchoice`), using `dynamic arrays` or appending data only when needed.
% 
% 5. **Concurrency with Parallel Computing**:
%    - If there are independent parts of the behavior loop that perform heavy computations (e.g., analysis, data saving/logging), consider leveraging MATLAB's parallel computing facilities (`parfor`, `spmd`) to run them concurrently without blocking the main loop. This is especially useful for I/O-bound operations like saving experimental data.
% 
% ---
% Benefits of the callback/event-based approach:
% 
% Lower Latency: Callbacks are triggered instantly if their events occur, avoiding the polling delay.
% Efficient CPU Usage: Unlike busy-waiting loops, callbacks keep CPU resources available to other tasks when no event occurs.
% Scalability: You can easily manage multiple input/output devices/events without cluttering the main logic loop, improving maintainability.
% 
% 
% ### Example Utilization of Callbacks for Arduino Events:
% 
% In instrumentation-heavy systems (like the one interfacing with Arduinos here), constantly polling pins for state changes (i.e., `ReadLeft`, `ReadRight`, `ReadMiddle`) significantly degrades performance due to high polling overheads.
% 
% A better approach would be to utilize event-based callbacks provided by MATLAB’s `serialport` or `matlab.io` functionality.
% 
% Here’s a conceptual illustration of this strategy applied to handle events like reward dispensing or lever pulling events quickly:

matlab
% Set up callback for serial data-available event
function setupArduinoCallback(this)
    configureCallback(this.Ard, "terminator", @(src, evt) processSerialEvent(this, src, evt));
end

% Callback that gets triggered upon serial communication event
function processSerialEvent(this, src, evt)
    data = readline(src);    % Capture the incoming serial message
    
    switch data
        case 'L'
            this.handleLeftAction();
        case 'R'
            this.handleRightAction();
        case 'M'
            this.handleMiddleAction();
        otherwise
            disp(['Unknown serial input: ', data]);  % Fallback handling for unexpected inputs
    end
end

% Handle left lever action
function handleLeftAction(this)
    if this.isLeftTrial
        this.WhatDecision = 'left correct';
        this.giveReward();
    else
        this.WhatDecision = 'left wrong';
        this.penaltyAction();
    end
end

% Handle right lever action
function handleRightAction(this)
    if ~this.isLeftTrial
        this.WhatDecision = 'right correct';
        this.giveReward();
    else
        this.WhatDecision = 'right wrong';
        this.penaltyAction();
    end
end

% Handle middle button/lever action if applicable
function handleMiddleAction(this)
    disp('Middle action triggered');
    % Implement appropriate action for the middle response
end

function setupRewardTimer(this)
    t = timer('TimerFcn', @(~,~) dispenseReward(this), ...
              'StartDelay', this.RewardDelay, ...
              'ExecutionMode', 'singleShot');
    start(t);  
end

function dispenseReward(this)
    % Logic for managing reward dispensing in parallel.
    this.GiveReward();
end
