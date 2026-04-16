classdef MockBehaviorBoxNoseWaitBlink < BehaviorBoxNose
    properties
        ReadyCueColorHistory double = zeros(0, 3)
        StableChoiceCallCount double = 0
    end

    methods
        function this = MockBehaviorBoxNoseWaitBlink(gui, app)
            this@BehaviorBoxNose(gui, app);
        end

        function setReadyCueColorSafe_(this, readyCueDot, color)
            this.ReadyCueColorHistory(end + 1, :) = double(color);
            setReadyCueColorSafe_@BehaviorBoxNose(this, readyCueDot, color);
        end

        function stable = Middle_StableChoice_StartTrial(this, checkDelay)
            this.StableChoiceCallCount = this.StableChoiceCallCount + 1;
            stable = Middle_StableChoice_StartTrial@BehaviorBoxNose(this, checkDelay);
        end
    end
end
