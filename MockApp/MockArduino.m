classdef MockArduino < matlab.mixin.SetGet
    properties
        AcquisitionCalls string = string.empty(0, 1)
    end

    methods
        function Acquisition(this, mode)
            this.AcquisitionCalls(end + 1, 1) = string(mode);
        end
    end
end
