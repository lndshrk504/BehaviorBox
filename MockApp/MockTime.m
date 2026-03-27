classdef MockTime < matlab.mixin.SetGet
    properties
        RawLog string = string.empty(0, 1)
        ParsedLog table = table()
        Log string = string.empty(0, 1)
        Ard = 1
    end

    methods
        function Reset(this)
            this.RawLog = string.empty(0, 1);
            this.ParsedLog = table();
            this.Log = string.empty(0, 1);
        end

        function LogEvent(this, eventName, fields)
            if nargin < 3
                fields = struct();
            end

            tUs = NaN;
            trial = NaN;
            scanImageFile = NaN;
            if isfield(fields, 't_us')
                tUs = double(fields.t_us);
            end
            if isfield(fields, 'trial')
                trial = double(fields.trial);
            end
            if isfield(fields, 'scanImageFile')
                scanImageFile = double(fields.scanImageFile);
            end

            this.RawLog(end + 1, 1) = string(eventName);
            row = table( ...
                repmat("annotation", 1, 1), ...
                string(eventName), ...
                tUs, ...
                trial, ...
                scanImageFile, ...
                'VariableNames', {'kind', 'event', 't_us', 'trial', 'scanImageFile'});

            if isempty(this.ParsedLog) || height(this.ParsedLog) == 0
                this.ParsedLog = row;
            else
                this.ParsedLog = [this.ParsedLog; row];
            end
            this.Log = this.RawLog;
        end
    end
end
