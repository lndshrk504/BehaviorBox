classdef MockArduino < matlab.mixin.SetGet
    properties
        AcquisitionCalls string = string.empty(0, 1)
        KeyboardInput logical = false
        ReadingChar char = '-'
        TokenScript char = ''
        ReadCount double = 0
        RewardCalls string = string.empty(0, 1)
        RewardReadCounts double = []
        FastForwardAtRead double = Inf
        FastForwardAfterRewards double = Inf
        FastForwardControl = []
        WheelScript double = 0
        WheelReadCount double = 0
    end

    methods
        function Acquisition(this, mode)
            this.AcquisitionCalls(end + 1, 1) = string(mode);
        end

        function setTokenScript(this, tokens)
            this.TokenScript = char(tokens);
            this.ReadCount = 0;
            this.ReadingChar = '-';
            this.RewardCalls = string.empty(0, 1);
            this.RewardReadCounts = [];
            this.FastForwardAtRead = Inf;
            this.FastForwardAfterRewards = Inf;
            this.FastForwardControl = [];
        end

        function setWheelScript(this, values)
            if isempty(values)
                values = 0;
            end
            this.WheelScript = double(values);
            this.WheelReadCount = 0;
        end

        function value = ReadWheel(this)
            this.WheelReadCount = this.WheelReadCount + 1;
            idx = min(this.WheelReadCount, numel(this.WheelScript));
            value = this.WheelScript(idx);
        end

        function Reset(this)
            this.WheelReadCount = 0;
        end

        function GiveReward(this, opts)
            arguments
                this
                opts.Side = 'R'
            end
            this.RewardCalls(end + 1, 1) = string(opts.Side);
            this.RewardReadCounts(end + 1, 1) = this.ReadCount;
            if numel(this.RewardCalls) >= this.FastForwardAfterRewards && ~isempty(this.FastForwardControl)
                this.FastForwardControl.Value = true;
            end
        end

        function LeftRead = ReadLeft(this)
            this.advanceToken();
            LeftRead = this.ReadingChar == 'L';
        end

        function RightRead = ReadRight(this)
            this.advanceToken();
            RightRead = this.ReadingChar == 'R';
        end

        function MiddleRead = ReadMiddle(this)
            MiddleRead = this.ReadingChar == 'M';
        end

        function NoneRead = ReadNone(this)
            NoneRead = this.ReadingChar ~= '-';
        end

        function advanceToken(this)
            this.ReadCount = this.ReadCount + 1;
            if isempty(this.TokenScript)
                return
            end
            idx = min(this.ReadCount, numel(this.TokenScript));
            this.ReadingChar = this.TokenScript(idx);
            if this.ReadCount >= this.FastForwardAtRead && ~isempty(this.FastForwardControl)
                this.FastForwardControl.Value = true;
            end
        end
    end
end
