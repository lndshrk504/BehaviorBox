% MATLAB: Test Production Receiver
% In MATLAB. Start the deferred receiver first, for example:
%   cd("/home/wbs/Desktop/BehaviorBox/EyeTrack/Stream-DeepLabCut")
%   system("python run_eye_receiver_service.py --address tcp://127.0.0.1:5555 --api-port 8765 &")

cd("/home/wbs/Desktop/BehaviorBox")
run("startup.m")

setenv("BB_EYETRACK_ZMQ_ADDRESS", "tcp://127.0.0.1:5555")
setenv("BB_EYETRACK_RECEIVER_URL", "http://127.0.0.1:8765")

eye = BehaviorBoxEyeTrack( ...
    Address="tcp://127.0.0.1:5555", ...
    SourceMode="localhost", ...
    ReceiverUrl="http://127.0.0.1:8765", ...
    BridgeDir="/home/wbs/Desktop/BehaviorBox/EyeTrack/Stream-DeepLabCut", ...
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
