% MATLAB: Test Production Receiver
%  In MATLAB:

cd("/home/wbs/Desktop/BehaviorBox")
run("startup.m")

setenv("BB_EYETRACK_PYTHON", "/home/wbs/miniforge3/envs/dlclivegui/bin/python")
setenv("BB_EYETRACK_ZMQ_ADDRESS", "tcp://127.0.0.1:5555")

eye = BehaviorBoxEyeTrack( ...
    Address="tcp://127.0.0.1:5555", ...
    SourceMode="localhost", ...
    BridgeDir="/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/ToMatlab", ...
    PythonExecutable="/home/wbs/miniforge3/envs/dlclivegui/bin/python", ...
    StartTimerOnStart=false);

eye.setSessionClock(tic, datetime("now"));
eye.markTrial(0);

ok = eye.start()
pause(2)
n = eye.pollAvailable()

record = eye.getRecord();
meta = eye.getMeta();

height(record)
meta.IsReady
meta.MessagesReceived
meta.SamplesReceived
record(end, ["trial", "frame_id", "sample_status", "valid_points", "center_x", "center_y", "diameter_px", "RVpupil_x", "RVpupil_y",
    "RVpupil_likelihood"])