classdef MockApp < matlab.mixin.SetGet
    properties
        Stop
        Skip
        FastForward
        Pause
        Auto_Go
        Auto_Stop
        Animate_Go
        Animate_End
        Animate_Show
        text1
        text16
        text19
        text17
        text3
        MsgBox
        NotesText
        Stimulus_type
        Box_Input_type
        Subject
        Strain
        Level_HardLvList
        Level_EasyLvList
        Level_EasyLvProb
        Level_HardLvProb
        One_ScanImage_File
    end

    methods
        function this = MockApp()
            this.Stop = MockControl("uibutton", "Stop", false);
            this.Skip = MockControl("uibutton", "Skip", false);
            this.FastForward = MockControl("uibutton", "FastForward", false);
            this.Pause = MockControl("uibutton", "Pause", false);
            this.Auto_Go = MockControl("uibutton", "Auto_Go", false);
            this.Auto_Stop = MockControl("uibutton", "Auto_Stop", false);
            this.Animate_Go = MockControl("uibutton", "Animate_Go", false);
            this.Animate_End = MockControl("uibutton", "Animate_End", false);
            this.Animate_Show = MockControl("uibutton", "Animate_Show", false);

            this.text1 = MockControl("uilabel", "text1", "");
            this.text16 = MockControl("uilabel", "text16", "");
            this.text19 = MockControl("uilabel", "text19", "");
            this.text17 = MockControl("uilabel", "text17", "");
            this.text3 = MockControl("uilabel", "text3", "");
            this.MsgBox = MockControl("uilabel", "MsgBox", "");
            this.NotesText = MockControl("uilabel", "NotesText", "");

            this.Stimulus_type = MockControl("uieditfield", "Stimulus_type", "Contour");
            this.Box_Input_type = MockControl("uieditfield", "Box_Input_type", "Wheel");
            this.Subject = MockControl("uieditfield", "Subject", "999999");
            this.Strain = MockControl("uieditfield", "Strain", "New");
            this.Level_HardLvList = MockControl("uieditfield", "Level_HardLvList", "1");
            this.Level_EasyLvList = MockControl("uieditfield", "Level_EasyLvList", "1");
            this.Level_EasyLvProb = MockControl("uieditfield", "Level_EasyLvProb", "1");
            this.Level_HardLvProb = MockControl("uieditfield", "Level_HardLvProb", "0");
            this.One_ScanImage_File = MockControl("uicheckbox", "One_ScanImage_File", false);
        end
    end
end
