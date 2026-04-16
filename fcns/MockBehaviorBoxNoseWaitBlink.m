classdef MockBehaviorBoxNoseWaitBlink < BehaviorBoxNose
    properties
        ReadyCueColorHistory double = zeros(0, 3)
    end

    methods
        function this = MockBehaviorBoxNoseWaitBlink(gui, app)
            this@BehaviorBoxNose(gui, app);
        end

        function setReadyCueColorSafe_(this, readyCueDot, color)
            this.ReadyCueColorHistory(end + 1, :) = double(color);
            setReadyCueColorSafe_@BehaviorBoxNose(this, readyCueDot, color);
        end
    end
end
