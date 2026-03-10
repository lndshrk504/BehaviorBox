classdef BehaviorBox_App < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        figure1                         matlab.ui.Figure
        GraphPopOut_2                   matlab.ui.control.Button
        GraphPopOut                     matlab.ui.control.Button
        Folder                          matlab.ui.control.Button
        Git                             matlab.ui.control.Button
        TabGroup                        matlab.ui.container.TabGroup
        SettingsTab                     matlab.ui.container.Tab
        One_ScanImage_File              matlab.ui.control.CheckBox
        InputControlPanel               matlab.ui.container.Panel
        TurnMag                         matlab.ui.control.NumericEditField
        TurnMagEditFieldLabel           matlab.ui.control.Label
        RoundUp                         matlab.ui.control.CheckBox
        RoundUpVal                      matlab.ui.control.NumericEditField
        RoundUpEditFieldLabel           matlab.ui.control.Label
        Stimulus_FinishLine             matlab.ui.control.CheckBox
        IntertrialMalCancel             matlab.ui.control.CheckBox
        IntertrialMalSec                matlab.ui.control.NumericEditField
        SkipWaitForInput                matlab.ui.control.CheckBox
        ConfirmChoice                   matlab.ui.control.CheckBox
        Input_Delay_Start               matlab.ui.control.NumericEditField
        Input_Delay_Respond             matlab.ui.control.NumericEditField
        Hold_Still_Thresh               matlab.ui.control.NumericEditField
        EditField_6Label                matlab.ui.control.Label
        DuringTrialEditFieldLabel       matlab.ui.control.Label
        StimulusvariablesPanel          matlab.ui.container.Panel
        WinPos                          matlab.ui.control.StateButton
        Stimulus_SegThick               matlab.ui.control.NumericEditField
        SegmentthicknessEditFieldLabel  matlab.ui.control.Label
        Stimulus_SegLength              matlab.ui.control.NumericEditField
        SegmentlengthEditFieldLabel     matlab.ui.control.Label
        Stimulus_SegSpacing             matlab.ui.control.NumericEditField
        SegmentSpacingEditFieldLabel    matlab.ui.control.Label
        Stimulus_SpotlightColor         matlab.ui.control.NumericEditField
        Stimulus_BetweenSpotlight       matlab.ui.control.NumericEditField
        Stimulus_LineColor              matlab.ui.control.NumericEditField
        LinebrightnessEditFieldLabel    matlab.ui.control.Label
        Stimulus_FlashColor             matlab.ui.control.NumericEditField
        EditField_5Label_2              matlab.ui.control.Label
        Stimulus_DimColor               matlab.ui.control.NumericEditField
        BackgroundEditFieldLabel_2      matlab.ui.control.Label
        Stimulus_BackgroundColor        matlab.ui.control.NumericEditField
        BackgroundEditFieldLabel        matlab.ui.control.Label
        ReadyCue_Color                  matlab.ui.control.NumericEditField
        ReadyCue_Size                   matlab.ui.control.NumericEditField
        EditField_2Label                matlab.ui.control.Label
        ReadyCuecolorLabel              matlab.ui.control.Label
        BetweenSpotlight_textlabel      matlab.ui.control.Label
        SpotlightbrightnessEditFieldLabel  matlab.ui.control.Label
        Stimulus_size_y                 matlab.ui.control.EditField
        Stimulus_size_x                 matlab.ui.control.EditField
        Stimulus_position_x             matlab.ui.control.EditField
        Stimulus_position_y             matlab.ui.control.EditField
        Arduino_Com                     matlab.ui.control.EditField
        Panel_2                         matlab.ui.container.Panel
        Stimulus_type                   matlab.ui.control.DropDown
        text65                          matlab.ui.control.Label
        Stimulus_FlashStim              matlab.ui.control.CheckBox
        EditField                       matlab.ui.control.NumericEditField
        Stimulus_RepFlashInitial        matlab.ui.control.EditField
        Stimulus_RepFlashAfterC         matlab.ui.control.EditField
        Stimulus_RepFlashAfterW         matlab.ui.control.EditField
        CorrectionoffsetEditFieldLabel  matlab.ui.control.Label
        Stimulus_ContTol                matlab.ui.control.NumericEditField
        ContangletolEditFieldLabel      matlab.ui.control.Label
        Stimulus_CorrectAngleAdj        matlab.ui.control.NumericEditField
        text122                         matlab.ui.control.Label
        text121                         matlab.ui.control.Label
        SubjectPanel                    matlab.ui.container.Panel
        Inv                             matlab.ui.control.EditField
        Strain                          matlab.ui.control.EditField
        WeightgEditField                matlab.ui.control.EditField
        StrainDropDown                  matlab.ui.control.DropDown
        DropDownLabel                   matlab.ui.control.Label
        Investigator                    matlab.ui.control.Label
        WeightgEditFieldLabel           matlab.ui.control.Label
        text13                          matlab.ui.control.Label
        text86                          matlab.ui.control.Label
        uipanel4                        matlab.ui.container.Panel
        LeftValveButton                 matlab.ui.control.Button
        RightValveButton                matlab.ui.control.Button
        Box_Lrewardtime                 matlab.ui.control.EditField
        Box_Rrewardtime                 matlab.ui.control.EditField
        Box_LeftPulse                   matlab.ui.control.NumericEditField
        Box_RightPulse                  matlab.ui.control.NumericEditField
        Box_SecBwPulse                  matlab.ui.control.NumericEditField
        secbwPulsesEditFieldLabel       matlab.ui.control.Label
        uipanel3                        matlab.ui.container.Panel
        text35                          matlab.ui.control.Label
        SideBiassEditField_2Label       matlab.ui.control.Label
        text12                          matlab.ui.control.Label
        EditField_5Label                matlab.ui.control.Label
        text10                          matlab.ui.control.Label
        text8                           matlab.ui.control.Label
        Input_ignored                   matlab.ui.control.CheckBox
        Pokes_ignored_time              matlab.ui.control.EditField
        Penalty_time                    matlab.ui.control.EditField
        Intertrial_time                 matlab.ui.control.EditField
        HoldStill                       matlab.ui.control.NumericEditField
        Box_Timeout_after_time          matlab.ui.control.EditField
        SideBiasInterval                matlab.ui.control.NumericEditField
        OnlyCorrect                     matlab.ui.control.CheckBox
        Box_OCPulse                     matlab.ui.control.NumericEditField
        Repeat_wrong                    matlab.ui.control.CheckBox
        Stimulus_PersistCorrect         matlab.ui.control.CheckBox
        Stimulus_PersistCorrectInterv   matlab.ui.control.NumericEditField
        Stimulus_PersistIncorrect       matlab.ui.control.CheckBox
        Stimulus_PersistIncorrectInterv  matlab.ui.control.NumericEditField
        Data_Sbin                       matlab.ui.control.EditField
        Data_Lbin                       matlab.ui.control.EditField
        uipanel1                        matlab.ui.container.Panel
        Box_Input_type                  matlab.ui.control.DropDown
        Stimulus_side                   matlab.ui.control.DropDown
        Side_delta                      matlab.ui.control.NumericEditField
        MinRandAlt                      matlab.ui.control.EditField
        MaxRandAlt                      matlab.ui.control.EditField
        Starting_opacity                matlab.ui.control.Spinner
        EasyTrials                      matlab.ui.control.CheckBox
        Level_EasyLvProb                matlab.ui.control.NumericEditField
        EasyLvProbLabel                 matlab.ui.control.Label
        Level_EasyLvList                matlab.ui.control.EditField
        Level_HardLvProb                matlab.ui.control.NumericEditField
        HighLvProbEditFieldLabel        matlab.ui.control.Label
        Level_HardLvList                matlab.ui.control.EditField
        DistractorsSpinnerLabel         matlab.ui.control.Label
        text119                         matlab.ui.control.Label
        text117                         matlab.ui.control.Label
        text89                          matlab.ui.control.Label
        text66                          matlab.ui.control.Label
        TemporaryTab                    matlab.ui.container.Tab
        AnimateStimulusPanel            matlab.ui.container.Panel
        Timekeeper                      matlab.ui.control.DropDown
        TimeDropDownLabel               matlab.ui.control.Label
        Animate_LineAngle               matlab.ui.control.NumericEditField
        LineAngleEditFieldLabel         matlab.ui.control.Label
        WhichStimulusButtonGroup        matlab.ui.container.ButtonGroup
        Animate_OnlyCorrectButton       matlab.ui.control.RadioButton
        Animate_BothButton              matlab.ui.control.RadioButton
        Animate_OnlyIncorrectButton     matlab.ui.control.RadioButton
        Animate_AlternateSide           matlab.ui.control.CheckBox
        Animate_CenteredStimulus        matlab.ui.control.CheckBox
        Animate_Rec                     matlab.ui.control.StateButton
        Animate_Flash                   matlab.ui.control.StateButton
        Animate_YPosition               matlab.ui.control.Slider
        YPositionSliderLabel            matlab.ui.control.Label
        Animate_Style                   matlab.ui.control.DropDown
        StyleDropDownLabel              matlab.ui.control.Label
        Animate_Show                    matlab.ui.control.StateButton
        Animate_XPosition               matlab.ui.control.Slider
        XPositionLabel                  matlab.ui.control.Label
        Animate_MimicTrial              matlab.ui.control.CheckBox
        Animate_Speed                   matlab.ui.control.NumericEditField
        SpeedEditFieldLabel             matlab.ui.control.Label
        Animate_End                     matlab.ui.control.StateButton
        Animate_Go                      matlab.ui.control.StateButton
        Animate_Side                    matlab.ui.control.DropDown
        SideDropDownLabel               matlab.ui.control.Label
        AutomaticDropWheelPanel         matlab.ui.container.Panel
        Auto_Msg                        matlab.ui.control.Label
        Auto_Animate                    matlab.ui.control.CheckBox
        Auto_Stop                       matlab.ui.control.StateButton
        Auto_Freq                       matlab.ui.control.NumericEditField
        FrequencyEditFieldLabel         matlab.ui.control.Label
        Auto_Go                         matlab.ui.control.StateButton
        ExpireAfterButtonGroup          matlab.ui.container.ButtonGroup
        TempOff_Temp                    matlab.ui.control.RadioButton
        PerformanceThreshold_Temp       matlab.ui.control.RadioButton
        TrialNumber_Temp                matlab.ui.control.RadioButton
        PerfThresh_Temp                 matlab.ui.control.NumericEditField
        TrialCount_Temp                 matlab.ui.control.NumericEditField
        TrialCountThreshold_Temp        matlab.ui.control.NumericEditField
        TrialsRemainingLabel            matlab.ui.control.Label
        InputControlPanel_2             matlab.ui.container.Panel
        Hold_Still_Thresh_Temp          matlab.ui.control.NumericEditField
        EditField_6Label_2              matlab.ui.control.Label
        IntertrialMalSec_Temp           matlab.ui.control.NumericEditField
        IntertrialMalCancel_Temp        matlab.ui.control.CheckBox
        uipanel3_2                      matlab.ui.container.Panel
        Input_ignored_Temp              matlab.ui.control.CheckBox
        Pokes_ignored_time_Temp         matlab.ui.control.EditField
        Penalty_time_Temp               matlab.ui.control.EditField
        Intertrial_time_Temp            matlab.ui.control.EditField
        HoldStill_Temp                  matlab.ui.control.NumericEditField
        OnlyCorrect_Temp                matlab.ui.control.CheckBox
        Box_OCPulse_Temp                matlab.ui.control.NumericEditField
        Repeat_wrong_Temp               matlab.ui.control.CheckBox
        EditField_5Label_3              matlab.ui.control.Label
        text10_2                        matlab.ui.control.Label
        text8_2                         matlab.ui.control.Label
        uipanel1_2                      matlab.ui.container.Panel
        prob_list_Temp                  matlab.ui.control.TextArea
        EasyTrials_Temp                 matlab.ui.control.CheckBox
        Starting_opacity_Temp           matlab.ui.control.Spinner
        DistractorsSpinnerLabel_2       matlab.ui.control.Label
        NotesTab                        matlab.ui.container.Tab
        NotesText                       matlab.ui.control.TextArea
        OutputTab                       matlab.ui.container.Tab
        MsgBox                          matlab.ui.control.TextArea
        PerformanceTab                  matlab.ui.container.Tab
        PerfGridLayout                  matlab.ui.container.GridLayout
        PerfPanel                       matlab.ui.container.Panel
        TimersTab                       matlab.ui.container.Tab
        GridLayout9                     matlab.ui.container.GridLayout
        TimersPanel                     matlab.ui.container.Panel
        AllTimeTab                      matlab.ui.container.Tab
        GridLayout5                     matlab.ui.container.GridLayout
        WeightWaterTab                  matlab.ui.container.Tab
        GridLayout6                     matlab.ui.container.GridLayout
        HistoryPanel                    matlab.ui.container.Panel
        OtherUnusedTab                  matlab.ui.container.Tab
        ArduinosDropDown                matlab.ui.control.DropDown
        ArduinosDropDownLabel           matlab.ui.control.Label
        EquipmentPanel                  matlab.ui.container.Panel
        BaseButton                      matlab.ui.control.Button
        VideoButton                     matlab.ui.control.Button
        Curtain                         matlab.ui.control.Button
        SaveCompButton                  matlab.ui.control.Button
        LoadCompButton                  matlab.ui.control.Button
        ResetAll                        matlab.ui.control.StateButton
        OpenBoth                        matlab.ui.control.StateButton
        OpenR                           matlab.ui.control.StateButton
        OpenL                           matlab.ui.control.StateButton
        Ext_trigger                     matlab.ui.control.CheckBox
        uipanel11                       matlab.ui.container.Panel
        Stimulus_Orient                 matlab.ui.control.EditField
        Ori_Frequency                   matlab.ui.control.EditField
        Ori_Bar_Size                    matlab.ui.control.EditField
        Ori_Random                      matlab.ui.control.CheckBox
        Ori_Interval                    matlab.ui.control.EditField
        Ori_Orientations                matlab.ui.control.DropDown
        Ori_Duration                    matlab.ui.control.EditField
        Ori_Repeats                     matlab.ui.control.EditField
        Orientation                     matlab.ui.control.Button
        text85                          matlab.ui.control.Label
        text84                          matlab.ui.control.Label
        text83                          matlab.ui.control.Label
        text82                          matlab.ui.control.Label
        text81                          matlab.ui.control.Label
        text79                          matlab.ui.control.Label
        DataViewerTab                   matlab.ui.container.Tab
        GridLayout7                     matlab.ui.container.GridLayout
        PerfHistPanel_Data              matlab.ui.container.Panel
        ControlsPanel                   matlab.ui.container.Panel
        GridLayout8                     matlab.ui.container.GridLayout
        Plot_Data                       matlab.ui.control.StateButton
        BigBin_Data                     matlab.ui.control.NumericEditField
        LargeBinLabel                   matlab.ui.control.Label
        SmallBin_Data                   matlab.ui.control.NumericEditField
        SmallBinLabel                   matlab.ui.control.Label
        Files_Data                      matlab.ui.control.DropDown
        FileDropDownLabel               matlab.ui.control.Label
        Next_Data                       matlab.ui.control.StateButton
        Back_Data                       matlab.ui.control.StateButton
        text17                          matlab.ui.control.Label
        text19                          matlab.ui.control.Label
        Subject                         matlab.ui.control.EditField
        LoadButton                      matlab.ui.control.Button
        ShowStim                        matlab.ui.control.Button
        ResetButton                     matlab.ui.control.Button
        Stop                            matlab.ui.control.StateButton
        Skip                            matlab.ui.control.StateButton
        Pause                           matlab.ui.control.StateButton
        FastForward                     matlab.ui.control.StateButton
        Start                           matlab.ui.control.Button
        Water                           matlab.ui.control.Button
        PrintSetup                      matlab.ui.control.Button
        text15                          matlab.ui.control.Label
        text16                          matlab.ui.control.Label
        text18                          matlab.ui.control.Label
        text20                          matlab.ui.control.Label
        text3                           matlab.ui.control.Label
        text2                           matlab.ui.control.Label
        text1                           matlab.ui.control.Label
    end

    properties (Access = public)
        ArduinoInfo = struct();
    end

    properties (Access = private)
        a % Handle to Arduino serial port object
        BB % Handle to BehaviorBox class
        L_ValveOpen logical = false
        L_ValveTimer
        R_ValveOpen logical = false
        R_ValveTimer
    end

    methods (Access = private)

        function previewStimulus(app)
            % Preview stimulus and display status or error messages.
            app.text1.Text = 'Previewing stimulus...';
            ALL_LEVELS = false;
            try
                if ALL_LEVELS
                    for Level = 1:20
                        app.Starting_opacity.Value = Level;
                        app.BB.getGUI();
                        app.BB.TestStimulus();
                    end
                else
                    app.BB.getGUI();
                    app.BB.TestStimulus();
                end
            catch err
                app.BB.unwrapError(err);
                app.BB.cleanUP();
                disp("Error during stimulus preview: " + getReport(err));
            end
        end

        function previewAllStimulus(app)
            % Preview stimulus and display status or error messages.
            app.text1.Text = 'Previewing stimulus...';
            try
                app.BB.getGUI();
                for Level = 1:20
                    app.BB.Setting_Struct.Starting_opacity = Level;
                    app.BB.TestStimulus();
                end
            catch err
                app.BB.unwrapError(err);
                app.BB.cleanUP();
                disp("Error during stimulus preview: " + getReport(err));
            end
        end

        function [COM, ID] = FindArduino(app, ~)
            arguments
                app
                ~
            end
            if ~isempty(app.Arduino_Com.Value)
                [devicesInfo, COM, ID] = arduinoServer('ArduinoInfo', app.ArduinoInfo, 'desiredIdentity', app.Arduino_Com.Value, 'FindExact', true);
                app.ArduinoInfo = devicesInfo;
                app.Arduino_Com.Value = ID;
                return
            else
                switch app.Box_Input_type.Value
                    case 'NosePoke' % Nose
                        [devicesInfo, COM, ID] = arduinoServer('desiredIdentity', 'Nose', 'FindFirst', false, 'FindAll', true);
                    case 'Wheel' % Wheel
                        [devicesInfo, COM, ID] = arduinoServer('desiredIdentity', 'Wheel', 'FindFirst', false, 'FindAll', true);
                    otherwise % Keyboard mode, no serial device connected
                end
                app.ArduinoInfo = devicesInfo;
                app.Arduino_Com.Value = ID;
                return
            end
        end

        function disconnectArduinos(app)
            % Hard teardown of serial objects so COM ports are released immediately.
            % Reset should not require physically unplugging USB devices.
            try
                if ~isempty(app.BB) && isvalid(app.BB)
                    % Behavior Arduino wrapper
                    try
                        if isprop(app.BB, 'a') && ~isempty(app.BB.a)
                            delete(app.BB.a);
                        end
                    catch
                    end
                    try
                        if isprop(app.BB, 'a')
                            app.BB.a = [];
                        end
                    catch
                    end

                    % Timestamp Arduino wrapper
                    try
                        if isprop(app.BB, 'Time') && ~isempty(app.BB.Time)
                            delete(app.BB.Time);
                        end
                    catch
                    end
                    try
                        if isprop(app.BB, 'Time')
                            app.BB.Time = [];
                        end
                    catch
                    end
                end
            catch
            end

            % Secondary guard: kill stray serialport objects that may have been kept alive
            % (e.g. by callbacks / reference cycles).
            try
                if exist('serialportfind', 'file') == 2
                    sp = serialportfind;
                    if ~isempty(sp)
                        delete(sp);
                    end
                end
            catch
            end

            pause(0.05); % allow OS time to release ports
        end


        function loadGuiInputAsStruct(app, handles, ~)
            BB = app.BB;
            %Read settings from interface:
            Sub = {app.Subject.Value};
            Invest = app.Inv.Value;
            Inp = app.Box_Input_type.Value;
            %Str = app.Strain.Value;
            BBData = BehaviorBoxData("Inv", Invest, "Inp", Inp, "Sub",Sub, find=1);
            if isempty(handles.Strain.String) || all(handles.Strain.String ~= string(BBData.Str))
                handles.Strain.String = BBData.Str; drawnow;
            end
            try
                if isempty(BBData.fds) || numel(BBData.fds.Files) == 0
                    disp('No saved settings found for current subject, using current values...');
                    return
                else
                    filename = BBData.fds.Files{end};
                    tree = split(filename, filesep);
                end
                %Set = BBData.loadedData{end,3}.Settings;
                Set = BBData.loadedData{end,8}; % Now settings structure is column 8
                Set = Set(1);
                handles.Strain.String = Set.Strain;
                BBData.Str = Set.Strain;
            catch
                msg = 'Problem loading, check files... using current values';
                disp(msg);
                app.text1.Text = msg;
            end
            try
                skipnames = {'Strain', 'Investigator', 'Weight','Subject','Arduino_Com','prob_list'};
                names = fieldnames(Set);
                namesREF = fieldnames(Set);
                names(contains(names, {'Box', 'Temp', 'position', 'size_', 'Arduino'}, "IgnoreCase",true)) = [];
                names(matches(names, skipnames)) = [];
                % Add back in all the temporary settings
                names = [names ; namesREF(contains(namesREF, 'Temp'))];
                for s = names'
                    try
                        if app.(s{:}).Type == "uieditfield"
                            if class(Set.(s{:})) == "double"
                                app.(s{:}).Value = num2str(Set.(s{:}));
                            else
                                app.(s{:}).Value = Set.(s{:});
                            end
                        elseif app.(s{:}).Type == "uidropdown"
                            app.(s{:}).Value = app.(s{:}).Items(Set.(s{:}));
                        elseif app.(s{:}).Type == "uicheckbox"
                            app.(s{:}).Value = Set.(s{:});
                        elseif app.(s{:}).Type == "uinumericeditfield"
                            app.(s{:}).Value = Set.(s{:});
                        elseif app.(s{:}).Type == "uispinner"
                            app.(s{:}).Value = Set.(s{:});
                        elseif app.(s{:}).Type == "uiradiobutton"
                            app.(s{:}).Value = Set.(s{:});
                        elseif app.(s{:}).Type == "uitextarea"
                            app.(s{:}).Value = Set.(s{:});
                        end
                    catch err
                        try
                            if class(Set.(s{:})) ~= "char"
                                handles.(s{:}).String = Set.(s{:});
                            end
                        catch
                            sprintf("Problem: "+s{:})
                        end
                    end
                end
            catch err
                % disp(err.message)
            end
            drawnow; pause(0.1);% Update GUI
            BB.getGUI();
            BB.Data_Object = BBData;
            % Populate dropdown list with filenames of data files
            List = BBData.fds.Files;
            LSp = split(List, filesep);
            if ispc
                IDX = 9;
            elseif isunix % mac and linux should be same
                IDX = 11;
            end
            if numel(List) > 1
                app.Files_Data.Items = LSp(:,IDX);
            else
                app.Files_Data.Items = LSp(end);
            end
            % Make blank graphs for DatazViewer
            graphFig = app.PerfHistPanel_Data;
            BBData.Axes = BBData.CreateDailyGraphs(graphFig);
            try
                BBData.AnalyzeAllData();
                tic
                % f = parfeval(backgroundPool, @(x) BBData.plotLvByDayOneAxis(LevDay=0, Sc=1, Training=1), 1) % Plot in packground, doesnt work
                Ax = BBData.plotLvByDayOneAxis(LevDay=0, Sc=1, Training=1);
                %Ax.PickableParts = "none";
                clo(app.AllTimeTab.Children)
                copyobj(Ax, app.AllTimeTab.Children)
                close(Ax.Parent.Parent)
                elapsedTime = toc;  % Stop timing
                fprintf('Plotted, time: %.6f seconds.\n', elapsedTime);
            catch
            end
            try
                Weights = cellfun(@(x) x.Weight, BBData.loadedData(:,8), 'UniformOutput', false);
                if ~all(cellfun('isempty', Weights))
                    t = BBData.PlotWeightAndWater();
                    %t.PickableParts = "none";
                    clo(app.WeightWaterTab.Children.Children)
                    copyobj(t, app.WeightWaterTab.Children.Children)
                    close(t.Parent)
                end
            catch err
                unwrapErr(err)
            end
            app.WeightgEditField.Value = '';
            %app.TrialNumber_Temp.Value = true;
            app.TempOff_Temp.Value = true;
            app.TrialCount_Temp.Value = 10;
            app.TrialCountThreshold_Temp.Value = 90;
            drawnow; pause(0.1); % Update GUI
            text = "Settings synced.";
            fprintf('%s\n',text)
            app.text1.Text = text;
            drawnow; pause(0.1); % Update GUI
            assignin("base", "BB", BB)
            assignin("base", "BBData", BBData)
        end

        function PlotDataViewer(app, options)
            arguments
                app
                options.Type char = 'Normal'
            end
            app.text1.Text = 'Getting data...';
            drawnow;
            % Reset buttons
            app.Next_Data.Value = false;
            app.Back_Data.Value = false;
            app.Plot_Data.Value = false;
            W = find(contains(app.BB.Data_Object.loadedData(:,1), app.Files_Data.Value));
            switch options.Type
                case "Next_Data"
                    % Advance the selection in the dropdown
                    W = W+1;
                    % Rollover if the end is hitapp.ShowStim
                    if W > numel(app.Files_Data.Items)
                        W = 1;
                    end
                    app.Files_Data.Value = app.Files_Data.Items{W};
                case "Back_Data"
                    W = W-1;
                    if W == 0 % Rollover if the end is hit
                        W = numel(app.Files_Data.Items);
                    end
                    app.Files_Data.Value = app.Files_Data.Items{W};
            end
            % Plot the performance graphs for the data file selected by the
            % dropbox
            Old_Dat = app.BB.Data_Object.loadedData{W,3};
            New = app.BB.Data_Object.current_data_struct;
            New = copytoStruct(New, Old_Dat);
            app.BB.Data_Object.current_data_struct = New;
            if size(New.TimeStamp,2) == 0
                app.text1.Text = 'No trials to plot in this data file';
                return
            end
            app.text1.Text = 'Plotting data...';
            drawnow;
            app.BB.Data_Object.current_data_struct = app.BB.Data_Object.CleanData();
            app.BB.Data_Object.PlotNewData("Type","DataViewer")

            DateIn = app.Files_Data.Items{W}(1:13);

            % Convert to datetime
            dt = string(datetime(DateIn, 'InputFormat', 'yyMMdd_HHmmss'));
            % Rest = strrep(app.Files_Data.Items{W}(15:end), '_', ' ');

            app.PerfHistPanel_Data.Title = dt;
        end

        function NewLoadGui(app, handles, ~)
            BB = app.BB;

            %Read settings from interface:
            Sub = {app.Subject.Value};
            Invest = app.Inv.Value;
            Inp = app.Box_Input_type.Value;
            STARTPATH = fullfile(GetFilePath("Data"), Invest, Inp);

            % Get directory contents
            contents = dir(STARTPATH);

            % Filter the results to only get folders
            folders = contents([contents.isdir]);

            % Remove '.' and '..' entries, which refer to the current and parent directories
            WHO = folders(~ismember({folders.name}, {'.', '..'}));

            app.StrainDropDown.Items = {WHO.name};

            %Load all the mouse data at once, then toggle through each
            %subject in a dropdown list to quickly plot their data

            % BBData = BehaviorBoxData("Inv", Invest, "Inp", Inp, "Str", app.StrainDropDown.Value, "Sub", {' - '});
        end

        function updateMsgBoxInBackground(app)
            try
                while isvalid(app)
                    % Read the current content of the diary file
                    diaryContent = fileread(app.BB.textdiary);
                    % Update the MsgBox with the current diary contents
                    app.MsgBox.Value = diaryContent;
                    drawnow; % Ensure GUI updates

                    % Pause before the next update to avoid excessive resource use
                    pause(2); % Set the pause duration as needed
                end
            catch err
                % Handle any errors gracefully
                app.BB.unwrapError(err);
            end
        end

        function LoadComputerSpecifics(app)
            % if ispc
            %     loadDir = fullfile(getenv('USERPROFILE'), 'Desktop', 'BehaviorBox');
            % elseif ismac
            %     loadDir = '/Users/willsnyder/Dropbox (Dropbox @RU)/Dropbox (Dropbox @RU)/Gilbert Lab/BehaviorBoxData/Data/';
            % elseif isunix
            %     loadDir = fullfile(getenv('HOME'), 'Desktop', 'BehaviorBox');
            % end
            loadDir = GetFilePath("Computer");
            saveFiles = dir(loadDir);
            COM = app.Arduino_Com.Value;
            if isempty(COM)
                COM = "NoArd";
            end
            wF = saveFiles(contains({saveFiles.name}, ['ComputerSettings' COM]));
            if isempty(wF) || numel(wF) > 1
                disp("Please check the Arduino Port and try again.")
                return
            end
            load(fullfile(wF.folder, wF.name), 'SavedComputerSpecifics')
            for f = fieldnames(SavedComputerSpecifics)'
                try
                    app.(f{:}).Value = SavedComputerSpecifics.(f{:});
                catch err % Fails for the Position property
                    1;
                end
            end
            app.figure1.Position = SavedComputerSpecifics.Position;
            drawnow; pause(0.1);
        end

        function SaveComputerSpecifics(app)
            %Settings will be specific to the COM number
            props = properties(app);
            SKIP = {'WinPos', 'ArduinoInfo'};
            props(contains(props, SKIP)) = [];
            names = cellfun(@(x)app.(x).Tag, props, 'UniformOutput', false, 'ErrorHandler', @errorFuncNaN);
            boxstuff = props(contains(names, 'box_','IgnoreCase',true));
            stimstuff = props(contains(names, 'stimulus_','IgnoreCase',true));
            allstuff = [boxstuff' stimstuff'];
            SavedComputerSpecifics = struct();
            for i = allstuff
                SavedComputerSpecifics.(i{:}) = app.(i{:}).Value;
            end
            SavedComputerSpecifics.Arduino_Com = app.Arduino_Com.Value;
            SavedComputerSpecifics.Position = app.figure1.Position;
            COM = app.Arduino_Com.Value;
            if isempty(COM)
                COM = "NoArd";
            end
            saveasname = fullfile(GetFilePath("Computer"), "ComputerSettings"+COM+".mat");
            save(saveasname, 'SavedComputerSpecifics')
            app.text1.Text = 'Computer settings saved.';
            fprintf('Computer settings saved.\n')
        end

        function printHardwareConnections(app, handles)
            current_selection_stimulus=get(handles.Box_Input_type,'Value');
            current_selection_input=get(handles.Box_Input_type,'Value');
            fprintf('------SET UP-------\n')
            switch current_selection_stimulus
                case 1
                    fprintf('Contour crude stimulus\n')
                case 2
                    fprintf('Contour fine stimulus\n')
                case 3
                    fprintf('Square Vs Open Box crude stimulus\n')
                case 4
                    fprintf('Square Vs Open Box fine stimulus\n')
                case 5
                    fprintf('Match Target stimulus\n')
                case 11
                    fprintf('Contour Density: Identify the dashed-line contour\n')
            end
            switch current_selection_input
                case 3
                    fprintf('Three Pokes Input\n')
                    fprintf('- connect Center Poke Input to Arduino pin D4\n')
                    fprintf('- connect Left Poke Input to Arduino pin D5\n')
                    fprintf('- connect Right Poke Input to Arduino pin D6\n')
                    fprintf('- connect left reward valve output to Arduino pin D7\n')
                    fprintf('- connect right reward valve output to Arduino pin D8\n')
                case 6
                    fprintf('Wheel Input: Accu-Coder Rotary Encoder \n')
                    fprintf('- connect Encoder Power (white wire) to Arduino +5V \n')
                    fprintf('- connect Encoder Ground (black wire) to Arduino GND \n')
                    fprintf('- connect A (brown wire) to Arduino pin D2 \n')
                    fprintf('- connect B (red wire) to Arduino pin D3 \n')
                    fprintf('- connect Water reward valve to Arduino pin D6\n')
            end
            fprintf('------------------\n');
        end

        function printWelcomeMsg(~)
            fprintf('_________________________________________________________________________________________________')
            fprintf('\n');
            fprintf("888888b.            888                        d8b                  888888b.                     ");
            fprintf('\n');
            fprintf('888  "88b           888                        Y8P                  888  "88b                    ');
            fprintf('\n');
            fprintf("888  .88P           888                                             888  .88P                    ");
            fprintf('\n');
            fprintf("8888888K.   .d88b.  88888b.   8888b.  888  888 888  .d88b.  888d888 8888888K.   .d88b.  888  888 ");
            fprintf('\n');
            fprintf('888  "Y88b d8P  Y8b 888 "88b     "88b 888  888 888 d88""88b 888P"   888  "Y88b d88""88b `Y8bd8P');
            fprintf('\n');
            fprintf('888    888 88888888 888  888 .d888888 Y88  88P 888 888  888 888     888    888 888  888   X88K   ');
            fprintf('\n');
            fprintf('888   d88P Y8b.     888  888 888  888  Y8bd8P  888 Y88..88P 888     888   d88P Y88..88P .d8""8b. ');
            fprintf('\n');
            fprintf('8888888P"   "Y8888  888  888 "Y888888   Y88P   888  "Y88P"  888     8888888P"   "Y88P"  888  888 ');
            fprintf('\n');
            fprintf('_________________________________________________________________________________________________')
            fprintf('\n');
        end

        function results = LvProbChange(~, In)
            results = 1-In;
        end


        function setupDiaryFile(app, fileName)
            % Ensure the log file is clean and start logging
            app.MsgBox.Value = '';
            drawnow;
            % WBS - PROBLEM: On 7/8/2025 the above line caused matlab to hang
            % indefinitely, repeatedly. Debugging never showed an error, until running
            % `clear all hidden classes` and continuing line by line an error appeared
            % in the console that a graphics timeout happened due to "graphics
            % handshaking." Etiology of the error remains unidentified.
            diary off;
            if exist(fileName, 'file') == 2
                delete(fileName);
            end
            diary(fileName);
        end

        function isValid = isValidComPort(app, comPort)
            % Validate Arduino COM port
            isValid = ~isempty(comPort) && contains(comPort, {'ACM', 'COM', 'arduino'}, 'IgnoreCase', true); % && isnumeric(comPort);
        end

        function configureBehaviorBox(app, handles)
            % Configure the behavior box based on input type
            app.text1.Text = 'Setting up...';
            fprintf('Setting up...\n');
            try
                app.MsgBox.Value = fileread('BBAppOutput.txt');
            end
            drawnow;

            if app.Box_Input_type.Value == "Wheel"
                BB = BehaviorBoxWheel(handles, app);
            else
                BB = BehaviorBoxNose(handles, app);
            end

            BB.ConfigureBox();

            % Assign the behavior box object to the base workspace and app
            assignin("base", "BB", BB);
            app.BB = BB;
        end

        function finalizeSetup(app)
            % Finalize the GUI setup and update the state to "Ready"
            app.text1.Text = 'Ready';
            fprintf('Ready\n');
            app.MsgBox.Value = fileread('BBAppOutput.txt');
            drawnow;
            diary off;

            % Enable interactive buttons
            app.BB.toggleButtonsOnOff(app.BB.Buttons, true);
        end

    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function BehaviorBox_OpeningFcn(app, Input)
            arguments
                app
                Input char = ''
            end

            % Initialize properties
            try
                % Explicitly tear down any existing serial objects so ports are released
                app.disconnectArduinos();
            catch
            end

            try
                app.ArduinoInfo = struct();
                app.a = [];
                evalin('base', 'clc; clear  BB')
            catch
            end

            % Create GUIDE-style callback arguments
            [hObject, ~, handles] = convertToGUIDECallbackArguments(app);

            % Opening function setup
            handles.output = hObject;

            % Handle scribeOverlay cleanup
            if isfield(handles, 'scribeOverlay') && isa(handles.scribeOverlay(1), 'matlab.graphics.shape.internal.AnnotationPane')
                delete(handles.scribeOverlay);
                handles = rmfield(handles, 'scribeOverlay');
            end

            % Update handles structure
            guidata(hObject, handles);

            if ~isempty(Input)
                % Set input method, if given
                switch true
                    case Input == "Nose"
                        app.Box_Input_type.Value = "NosePoke";
                    case Input == "Wheel"
                        app.Box_Input_type.Value = "Wheel";
                    otherwise
                        sprintf("Unrecognized Input method. Please specify either Nose or Wheel. Starting up as Nose...")
                        app.Box_Input_type.Value = "NosePoke";
                end
            end
            % Change to app's folder on Desktop
            % if ismac
            %     cd '/Users/willsnyder/Desktop/BehaviorBox/'
            % elseif isunix
            %     USER = getenv('USER');
            %     pathStr = fullfile('/home', USER, 'Desktop', 'BehaviorBox');
            %     cd(pathStr);
            % elseif ispc
            % end
            addpath("fcns/");
            % Configure application path

            % Setup log file
            %setupDiaryFile(app, "BBAppOutput "+string(datetime("now"))+".txt");
            setupDiaryFile(app, "BBAppOutput.txt"); %Overwrite every time

            % Print welcome message
            printWelcomeMsg(app);

            % % Initialize Arduino communication
            % if ~isValidComPort(app, app.Arduino_Com.Value)
            %     app.Arduino_Com.Value = '';
            % end

            % Try finding Arduino and load specifics
            try
                disp('- - - Checking all connected Arduinos - - -')
                [COM, ID] = app.FindArduino(handles);
                LoadComputerSpecifics(app);
            end

            % Print initial hardware connections
            app.printHardwareConnections(handles);

            % Configure behavior box
            configureBehaviorBox(app, handles);
            app.NewLoadGui()

            % Load GUI input if subject is specified
            % if app.Subject.Value ~= "w"
            %     loadGuiInputAsStruct(app, handles, false);
            % end

            % Finalize setup
            finalizeSetup(app);
        end

        % Button pushed function: Start
        function Start_Callback(app, event)
            % Create GUIDE-style callback args - Added by Migration Tool
            [hObject, eventdata, handles] = convertToGUIDECallbackArguments(app, event); %#ok<ASGLU>
            % hObject    handle to pushbutton1 (see GCBO)
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)
            %run regular trials
            %START BUTTON
            try
                SaveComputerSpecifics(app);
                evalin('base','clc')
                trialObject = app.BB;
                trialObject.RunTrials();
                SaveComputerSpecifics(app);
            catch err
                disp(err.message);
                trialObject.cleanUP();
                set(handles.text1,'String',err.message );
            end
        end

        % Callback function
        function Train_Callback(app, event)
            % Legacy wrapper: keep Train button as an alias of Start.
            Start_Callback(app, event);
        end

        % Button pushed function: PrintSetup
        function PrintSetup_Callback(app, event)
            % Create GUIDE-style callback args - Added by Migration Tool
            [hObject, eventdata, handles] = convertToGUIDECallbackArguments(app, event); %#ok<ASGLU>
            %PRINT CONNECTION AND PINS NEEDED
            % hObject    handle to pushbutton4 (see GCBO)
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)
            printHardwareConnections(app, handles)
        end

        % Button pushed function: ShowStim
        function ShowStim_Callback(app, event)
            % Create GUIDE-style callback args - Added by Migration Tool
            [hObject, eventdata, handles] = convertToGUIDECallbackArguments(app, event);
            % show PREVIEW STIMULUS BUTTON
            % hObject    handle to pushbutton10 (see GCBO)
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)
            app.ShowStim.Enable = 0; %Disable this when debugging...
            previewStimulus(app);
            app.ShowStim.Enable = 1; %Disable this when debugging...
            SaveComputerSpecifics(app);
        end

        % Button pushed function: LoadButton
        function LoadButton_Callback(app, event)
            % Create GUIDE-style callback args - Added by Migration Tool
            [hObject, eventdata, handles] = convertToGUIDECallbackArguments(app, event); %#ok<ASGLU>
            % LOAD SUBJECT SETTINGS
            % hObject    handle to pushbutton18 (see GCBO)
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)
            loadGuiInputAsStruct(app, handles, 0);
        end

        % Button pushed function: Orientation
        function Orientation_Callback(app, event)
            % Create GUIDE-style callback args - Added by Migration Tool
            [hObject, eventdata, handles] = convertToGUIDECallbackArguments(app, event); %#ok<ASGLU>
            % ORIENTATION TUNING ONLY
            % hObject    handle to pushbutton19 (see GCBO)
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)
            try
                %run orientationTuning
                ThisTrial = BehaviorBoxSub2(handles);
                ThisTrial.RunOrientationTuning();
            catch err
                disp(err.message);
                set(handles.text1,'String',err.message );
            end
        end

        % Button pushed function: Water
        function WaterPushed(app, event)
            %To test water output:
            [~, ~, handles] = convertToGUIDECallbackArguments(app, event);
            % TEST BOX
            try
                BB = app.BB;
                BB.TestBox();
                SaveComputerSpecifics(app)
            catch err
                disp(err.message);
                set(handles.text1,'String',err.message );
            end
        end

        % Button pushed function: LoadCompButton
        function LoadCompButtonPushed(app, event)
            % LOAD COMPUTER SETTINGS
            %To load the computer specific settings (such as window size
            %and position and water drop sizes)
            LoadComputerSpecifics(app);
        end

        % Button pushed function: SaveCompButton
        function SaveCompButtonPushed(app, event)
            % SAVE COMPUTER SETTINGS
            %To save the computer specific settings (such as window size
            %and position and water drop sizes) to a folder on the
            %desktop
            SaveComputerSpecifics(app);
        end

        % Close request function: figure1
        function figure1CloseRequest(app, event)
            % Ensure hardware ports are released before the app is destroyed.
            try
                app.disconnectArduinos();
            catch
            end
            evalin('base', 'clear a BB ');
            delete(findobj("Type", "figure", "Name", "Stimulus"))
            delete(app)
        end

        % Button pushed function: LeftValveButton
        function LeftValveButtonPushed(app, event)
            % L TEST WATER BUTTON
            % command to pulse valve
            app.BB.a.GiveReward("Side","L")
        end

        % Button pushed function: RightValveButton
        function RightValveButtonPushed(app, event)
            % R TEST WATER BUTTON
            % command to pulse valve
            app.BB.a.GiveReward("Side","R")
        end

        % Button pushed function: ResetButton
        function ResetButtonPushed(app, event)
            %RESET BUTTON
            BehaviorBox_OpeningFcn(app)
        end

        % Value changed function: OpenL
        function OpenLValueChanged(app, event)
            app.BB.a.GiveReward("Side","l");
            app.L_ValveOpen = ~app.L_ValveOpen;
            if ~app.L_ValveOpen
                stop(app.L_ValveTimer);
                delete(app.L_ValveTimer);
            end
            % Create a timer object
            app.L_ValveTimer = timer;
            % Set the timer properties
            app.L_ValveTimer.StartDelay = 10; % Delay in seconds before the timer executes
            app.L_ValveTimer.TimerFcn = @(~,~)closeValve(); % Function to call when the timer fires

            % Start the timer
            start(app.L_ValveTimer);

            % Function to close the valve
            function closeValve()
                % Assuming app.L_ValveOpen is a property that controls the valve state
                if app.L_ValveOpen == true % Close the valve
                    app.BB.a.GiveReward("Side","l")
                    app.L_ValveOpen = false;
                    disp('BBApp: Left valve closed after 10 seconds.');
                    event.Source.Value = false;
                    % Stop and delete the timer
                    stop(app.L_ValveTimer);
                    delete(app.L_ValveTimer);
                end
            end
        end

        % Value changed function: OpenR
        function OpenRValueChanged(app, event)
            app.BB.a.GiveReward("Side","r");
            app.R_ValveOpen = ~app.R_ValveOpen;
            if ~app.R_ValveOpen
                stop(app.R_ValveTimer);
                delete(app.R_ValveTimer);
            end
            % Create a timer object
            app.R_ValveTimer = timer;
            % Set the timer properties
            app.R_ValveTimer.StartDelay = 10; % Delay in seconds before the timer executes
            app.R_ValveTimer.TimerFcn = @(~,~)closeValve(); % Function to call when the timer fires

            % Start the timer
            start(app.R_ValveTimer);

            % Function to close the valve
            function closeValve()
                % Assuming app.L_ValveOpen is a property that controls the valve state
                if app.R_ValveOpen == true % Close the valve
                    app.BB.a.GiveReward("Side","r")
                    app.R_ValveOpen = false;
                    disp('BBApp: Right valve closed after 10 seconds.');
                    event.Source.Value = false;
                    % Stop and delete the timer
                    stop(app.R_ValveTimer);
                    delete(app.R_ValveTimer);
                end
            end
        end

        % Value changed function: OpenBoth
        function OpenBothValueChanged(app, event)
            app.BB.a.GiveReward("Side","l");
            app.BB.a.GiveReward("Side","r");
        end

        % Value changed function: ResetAll
        function RESETALLButtonPushed(app, event)
            app.ResetAll.Text = 'Resetting...';
            try
                app.disconnectArduinos();
            catch
            end
            evalin('base', 'clear all hidden classes;!reset');
            BehaviorBox_OpeningFcn(app)
            app.ResetAll.Value = 0;
            app.ResetAll.Text = 'Reset ALL!';
        end

        % Value changed function: Subject
        function SubjectValueChanged(app, event)
            [hObject, eventdata, handles] = convertToGUIDECallbackArguments(app, event); %#ok<ASGLU>
            loadGuiInputAsStruct(app, handles, 0);
        end

        % Button pushed function: Git
        function GitButtonPushed(app, event)
            evalin("base", "!git stash && git pull")
        end

        % Button pushed function: Folder
        function FolderButtonPushed(app, event)
            try
                if ispc
                    winopen(app.BB.Data_Object.filedir{:})
                end
            catch
            end
        end

        % Button pushed function: VideoButton
        function VideoButtonPushed(app, event)
            try
                viewDualCameras();
            catch
            end
        end

        % Button pushed function: Curtain
        function CurtainButtonPushed(app, event)
            try
                Stim = BehaviorBoxVisualStimulus();
                Stim.CurtainOn();
            catch
            end
        end

        % Value changed function: Level_EasyLvProb
        function Level_EasyLvProbValueChanged(app, event)
            app.Level_HardLvProb.Value = 1-app.Level_EasyLvProb.Value;
        end

        % Value changed function: Level_HardLvProb
        function Level_HardLvProbValueChanged(app, event)
            app.Level_EasyLvProb.Value = 1-app.Level_HardLvProb.Value;

        end

        % Button pushed function: GraphPopOut
        function GraphPopOutButtonPushed(app, event)
            try
                oldFig = app.AllTimeTab.Children.Children;
                if isempty(oldFig)
                    return
                end
                newFig = MakeAxis();
                H = copyobj(oldFig,newFig.Parent);
                assignin("base", "H", H)
            catch
            end
        end

        % Button pushed function: GraphPopOut_2
        function GraphPopOut_2ButtonPushed(app, event)
            try
                oldFig = app.PerformanceTab.Children.Children.Children;
                if isempty(oldFig)
                    return
                end
                newFig = MakeAxis();
                H = copyobj(oldFig,newFig.Parent);
                H.Title.String = join([app.BB.Data_Object.Sub, app.BB.Data_Object.Inp, string(datetime("now"))]);
                assignin("base", "H", H)
            catch
            end
        end

        % Button pushed function: BaseButton
        function BaseButtonPushed(app, event)
            %assignin("base", "BB", app.BB)
        end

        % Value changed function: Box_Lrewardtime, Box_Rrewardtime
        function RewardTimeChanged(app, event)
            if event.Source.Tag == "Box_Lrewardtime"
                valueL = app.Box_Lrewardtime.Value;
                app.BB.a.SetupReward("Which", "Left", "DurationLeft",valueL);
            elseif event.Source.Tag == "Box_Rrewardtime"
                valueR = app.Box_Rrewardtime.Value;
                app.BB.a.SetupReward("Which", "Right", "DurationRight",valueR);
            end
        end

        % Value changed function: Auto_Go
        function Auto_GoValueChanged(app, event)
            value = app.Auto_Go.Value;
            try
                trialObject = app.BB;
                app.Auto_Go.Enable = false;
                app.Auto_Stop.Enable = true;
                drawnow limitrate;
                trialObject.AnimateReward();
                app.Auto_Stop.Enable = false;
                app.Auto_Stop.Value = false;
                app.Auto_Go.Enable = true;
                drawnow limitrate;
                SaveComputerSpecifics(app);
            catch err
                disp(err.message);
                trialObject.cleanUP();
                set(handles.text1,'String',err.message );
            end
        end

        % Value changed function: Animate_Go, Animate_Rec
        function Animate_GoValueChanged(app, event)
            app.Animate_Go.Enable = false;
            app.Animate_Rec.Enable = false;
            app.Animate_Show.Enable = false;
            app.Animate_End.Enable = true;
            app.Animate_End.Value = false;
            drawnow limitrate;
            try
                app.BB.getGUI();
                app.BB.AnimateStimulus("Mode", event.Source.Text);
            catch err
                unwrapErr(err)
                app.BB.cleanUP()
            end
            app.Animate_Show.Enable = true;
            app.Animate_Show.Value = false;
            app.Animate_Go.Value = false;
            app.Animate_Go.Enable = true;
            app.Animate_End.Value = false;
            app.Animate_End.Enable = false;
            app.Animate_Flash.Value = false;
            app.Animate_Flash.Enable = true;
            app.Animate_Rec.Enable = true;
            app.Animate_Rec.Value = false;
            app.Stop.Value = false;
            drawnow limitrate;
        end

        % Value changed function: Animate_XPosition, Animate_YPosition
        function Animate_PositionValueChanged(app, event)
            try
                switch event.Source.Tag
                    case "Animate_YPosition"
                        value = app.Animate_YPosition.Value;
                        app.BB.AnimateStimulus("Mode", "YMove", "Value", value);
                    case "Animate_XPosition"
                        value = app.Animate_XPosition.Value;
                        app.BB.AnimateStimulus("Mode", "XMove", "Value", value);
                end
            end
        end

        % Value changed function: Animate_Flash
        function Animate_FlashValueChanged(app, event)
            value = app.Animate_Flash.Value;
            app.Animate_Flash.Enable = false;
            app.BB.AnimateStimulus("Mode", "Flash");

            %Clean up
            app.Animate_Show.Value = false;
            app.Animate_Show.Enable = true;
            app.Animate_Flash.Value = false;
            app.Animate_Flash.Enable = true;
            app.Animate_Rec.Enable = true;
            app.Animate_Rec.Value = false;
        end

        % Value changed function: Back_Data, Next_Data, Plot_Data
        function Plot_DataValueChanged(app, event)
            value = app.Plot_Data.Value;
            app.PlotDataViewer("Type", event.Source.Tag)
        end

        % Value changed function: Animate_Show
        function Animate_ShowValueChanged(app, event)
            value = app.Animate_Show.Value;
            value = app.Animate_Flash.Value;
            app.Animate_Flash.Enable = false;
            app.Animate_Show.Enable = false;
            app.BB.getGUI();
            app.BB.AnimateStimulus("Mode", "Show");

            %Clean up
            app.Animate_Show.Value = false;
            app.Animate_Show.Enable = true;
            app.Animate_Flash.Value = false;
            app.Animate_Flash.Enable = true;
        end

        % Callback function
        function Animate_RecValueChanged(app, event)
            value = app.Animate_Rec.Value;

        end

        % Value changed function: Box_Input_type
        function Box_Input_typeValueChanged(app, event)
            value = app.Box_Input_type.Value;
            app.Arduino_Com.Value = '';
        end

        % Value changed function: WinPos
        function WinPosValueChanged(app, event)
            value = app.WinPos.Value;
            app.WinPos.Enable = false;

            Fig = findobj('Name','Stimulus');
            P = Fig.Position;
            app.Stimulus_position_x.Value = num2str(P(1));
            app.Stimulus_position_y.Value = num2str(P(2));
            app.Stimulus_size_x.Value = num2str(P(3));
            app.Stimulus_size_y.Value = num2str(P(4));

            app.WinPos.Value = false;
            app.WinPos.Enable = true;
        end

        % Value changed function: BigBin_Data
        function BigBin_DataValueChanged(app, event)
            value = app.BigBin_Data.Value;

        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create figure1 and hide until all components are created
            app.figure1 = uifigure('Visible', 'off');
            colormap(app.figure1, 'colorcube');
            app.figure1.Position = [520 -65 895 435];
            app.figure1.Name = 'BehaviorBox';
            app.figure1.CloseRequestFcn = createCallbackFcn(app, @figure1CloseRequest, true);
            app.figure1.Scrollable = 'on';
            app.figure1.HandleVisibility = 'callback';
            app.figure1.Tag = 'figure1';

            % Create text1
            app.text1 = uilabel(app.figure1);
            app.text1.Tag = 'text1';
            app.text1.HorizontalAlignment = 'center';
            app.text1.VerticalAlignment = 'top';
            app.text1.FontSize = 14;
            app.text1.Position = [1 416 893 19];
            app.text1.Text = 'idle';

            % Create text2
            app.text2 = uilabel(app.figure1);
            app.text2.Tag = 'text2';
            app.text2.HorizontalAlignment = 'center';
            app.text2.VerticalAlignment = 'top';
            app.text2.FontSize = 11;
            app.text2.Position = [4 393 87 17];
            app.text2.Text = 'Time(min):';

            % Create text3
            app.text3 = uilabel(app.figure1);
            app.text3.Tag = 'text3';
            app.text3.HorizontalAlignment = 'right';
            app.text3.VerticalAlignment = 'top';
            app.text3.FontSize = 14;
            app.text3.Position = [91 392 110 18];
            app.text3.Text = '-';

            % Create text20
            app.text20 = uilabel(app.figure1);
            app.text20.Tag = 'text20';
            app.text20.HorizontalAlignment = 'center';
            app.text20.VerticalAlignment = 'top';
            app.text20.FontSize = 11;
            app.text20.Position = [699 392 49 15];
            app.text20.Text = 'choices';

            % Create text18
            app.text18 = uilabel(app.figure1);
            app.text18.Tag = 'text18';
            app.text18.HorizontalAlignment = 'center';
            app.text18.VerticalAlignment = 'top';
            app.text18.FontSize = 11;
            app.text18.Position = [758 393 49 15];
            app.text18.Text = 'difficulty';

            % Create text16
            app.text16 = uilabel(app.figure1);
            app.text16.Tag = 'text16';
            app.text16.BackgroundColor = [0.831372549019608 0.815686274509804 0.784313725490196];
            app.text16.HorizontalAlignment = 'center';
            app.text16.VerticalAlignment = 'top';
            app.text16.FontSize = 40;
            app.text16.Position = [817 370 71 52];
            app.text16.Text = '0';

            % Create text15
            app.text15 = uilabel(app.figure1);
            app.text15.Tag = 'text15';
            app.text15.HorizontalAlignment = 'center';
            app.text15.VerticalAlignment = 'top';
            app.text15.FontSize = 10;
            app.text15.Position = [822 411 63 22];
            app.text15.Text = 'Trial Number';

            % Create PrintSetup
            app.PrintSetup = uibutton(app.figure1, 'push');
            app.PrintSetup.ButtonPushedFcn = createCallbackFcn(app, @PrintSetup_Callback, true);
            app.PrintSetup.Tag = 'PrintSetup';
            app.PrintSetup.HorizontalAlignment = 'left';
            app.PrintSetup.FontSize = 10;
            app.PrintSetup.Tooltip = 'show all connections required in command window';
            app.PrintSetup.Position = [8 371 37 22];
            app.PrintSetup.Text = 'Setup';

            % Create Water
            app.Water = uibutton(app.figure1, 'push');
            app.Water.ButtonPushedFcn = createCallbackFcn(app, @WaterPushed, true);
            app.Water.Tag = 'Water';
            app.Water.BackgroundColor = [0.302 0.7451 0.9333];
            app.Water.FontWeight = 'bold';
            app.Water.Position = [50 371 63 22];
            app.Water.Text = 'Test Box';

            % Create Start
            app.Start = uibutton(app.figure1, 'push');
            app.Start.ButtonPushedFcn = createCallbackFcn(app, @Start_Callback, true);
            app.Start.Tag = 'Start';
            app.Start.BackgroundColor = [0 1 0];
            app.Start.FontSize = 11;
            app.Start.FontWeight = 'bold';
            app.Start.Tooltip = 'Start the complete training';
            app.Start.Position = [118 371 36 22];
            app.Start.Text = 'Start';

            % Create FastForward
            app.FastForward = uibutton(app.figure1, 'state');
            app.FastForward.Tag = 'FastForward';
            app.FastForward.Tooltip = {'Click this button to fast-forward through the current pause interval'};
            app.FastForward.Icon = fullfile(pathToMLAPP, 'imgs', 'Forward_font_awesome.svg.png');
            app.FastForward.Text = '';
            app.FastForward.BackgroundColor = [1 1 1];
            app.FastForward.Position = [191 371 27 22];

            % Create Pause
            app.Pause = uibutton(app.figure1, 'state');
            app.Pause.Tag = 'Pause';
            app.Pause.Icon = fullfile(pathToMLAPP, 'imgs', 'pause.png');
            app.Pause.Text = '';
            app.Pause.Position = [159 371 27 22];

            % Create Skip
            app.Skip = uibutton(app.figure1, 'state');
            app.Skip.Tag = 'Skip';
            app.Skip.Icon = fullfile(pathToMLAPP, 'imgs', 'skip.png');
            app.Skip.Text = '';
            app.Skip.Position = [223 371 27 22];

            % Create Stop
            app.Stop = uibutton(app.figure1, 'state');
            app.Stop.Tag = 'Stop';
            app.Stop.Tooltip = 'Stop all';
            app.Stop.Text = 'Stop';
            app.Stop.BackgroundColor = [1 0.4118 0.1608];
            app.Stop.FontSize = 11;
            app.Stop.FontWeight = 'bold';
            app.Stop.Position = [255 371 40 22];

            % Create ResetButton
            app.ResetButton = uibutton(app.figure1, 'push');
            app.ResetButton.ButtonPushedFcn = createCallbackFcn(app, @ResetButtonPushed, true);
            app.ResetButton.Tag = 'ResetButton';
            app.ResetButton.HorizontalAlignment = 'left';
            app.ResetButton.FontSize = 10;
            app.ResetButton.Tooltip = {'Click to clear memory and reconnect Arduino.'};
            app.ResetButton.Position = [300 371 37 22];
            app.ResetButton.Text = 'Reset';

            % Create ShowStim
            app.ShowStim = uibutton(app.figure1, 'push');
            app.ShowStim.ButtonPushedFcn = createCallbackFcn(app, @ShowStim_Callback, true);
            app.ShowStim.Tag = 'ShowStim';
            app.ShowStim.BackgroundColor = [0.501960784313725 0.501960784313725 0.501960784313725];
            app.ShowStim.FontSize = 9;
            app.ShowStim.Tooltip = {'Press to generate an example of the current level. May crash if the flash routine hasn''t finished.'};
            app.ShowStim.Position = [342 371 47 22];
            app.ShowStim.Text = 'Preview';

            % Create LoadButton
            app.LoadButton = uibutton(app.figure1, 'push');
            app.LoadButton.ButtonPushedFcn = createCallbackFcn(app, @LoadButton_Callback, true);
            app.LoadButton.Tag = 'LoadButton';
            app.LoadButton.BackgroundColor = [0.8 0.8 0.8];
            app.LoadButton.FontSize = 10;
            app.LoadButton.Tooltip = {'Open mouse''s folder'};
            app.LoadButton.Position = [546 372 48 22];
            app.LoadButton.Text = 'Subject:';

            % Create Subject
            app.Subject = uieditfield(app.figure1, 'text');
            app.Subject.ValueChangedFcn = createCallbackFcn(app, @SubjectValueChanged, true);
            app.Subject.Tag = 'Subject';
            app.Subject.Tooltip = 'Enter animal number here';
            app.Subject.Position = [603 372 83 22];
            app.Subject.Value = 'w';

            % Create text19
            app.text19 = uilabel(app.figure1);
            app.text19.Tag = 'text19';
            app.text19.BackgroundColor = [0.749019607843137 0.749019607843137 0];
            app.text19.HorizontalAlignment = 'center';
            app.text19.VerticalAlignment = 'top';
            app.text19.FontSize = 20;
            app.text19.Position = [696 370 55 26];
            app.text19.Text = '0';

            % Create text17
            app.text17 = uilabel(app.figure1);
            app.text17.Tag = 'text17';
            app.text17.BackgroundColor = [1 0 0];
            app.text17.HorizontalAlignment = 'center';
            app.text17.VerticalAlignment = 'top';
            app.text17.FontSize = 20;
            app.text17.Position = [755 370 55 26];
            app.text17.Text = '0';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.figure1);
            app.TabGroup.AutoResizeChildren = 'off';
            app.TabGroup.Position = [1 15 887 350];

            % Create SettingsTab
            app.SettingsTab = uitab(app.TabGroup);
            app.SettingsTab.AutoResizeChildren = 'off';
            app.SettingsTab.Title = 'Settings';

            % Create uipanel1
            app.uipanel1 = uipanel(app.SettingsTab);
            app.uipanel1.AutoResizeChildren = 'off';
            app.uipanel1.Title = 'Level & Side';
            app.uipanel1.Tag = 'uipanel1';
            app.uipanel1.FontSize = 10;
            app.uipanel1.Position = [11 150 178 172];

            % Create text66
            app.text66 = uilabel(app.uipanel1);
            app.text66.Tag = 'text66';
            app.text66.VerticalAlignment = 'top';
            app.text66.FontSize = 11;
            app.text66.Position = [7 134 38 16];
            app.text66.Text = 'Input:';

            % Create text89
            app.text89 = uilabel(app.uipanel1);
            app.text89.Tag = 'text89';
            app.text89.VerticalAlignment = 'top';
            app.text89.FontSize = 11;
            app.text89.Position = [7 113 36 16];
            app.text89.Text = 'Side:';

            % Create text117
            app.text117 = uilabel(app.uipanel1);
            app.text117.Tag = 'text117';
            app.text117.VerticalAlignment = 'bottom';
            app.text117.FontSize = 11;
            app.text117.Position = [7 95 64 19];
            app.text117.Text = 'Alt. Random:';

            % Create text119
            app.text119 = uilabel(app.uipanel1);
            app.text119.Tag = 'text119';
            app.text119.HorizontalAlignment = 'center';
            app.text119.VerticalAlignment = 'bottom';
            app.text119.FontSize = 11;
            app.text119.Position = [94 95 10 16];
            app.text119.Text = '<';

            % Create DistractorsSpinnerLabel
            app.DistractorsSpinnerLabel = uilabel(app.uipanel1);
            app.DistractorsSpinnerLabel.FontSize = 10;
            app.DistractorsSpinnerLabel.Position = [8 73 29 17];
            app.DistractorsSpinnerLabel.Text = 'Level';

            % Create Level_HardLvList
            app.Level_HardLvList = uieditfield(app.uipanel1, 'text');
            app.Level_HardLvList.Tag = 'Level_HardLvList';
            app.Level_HardLvList.FontSize = 10;
            app.Level_HardLvList.Position = [120 12 42 22];
            app.Level_HardLvList.Value = '2:6';

            % Create HighLvProbEditFieldLabel
            app.HighLvProbEditFieldLabel = uilabel(app.uipanel1);
            app.HighLvProbEditFieldLabel.HorizontalAlignment = 'right';
            app.HighLvProbEditFieldLabel.FontSize = 10;
            app.HighLvProbEditFieldLabel.Position = [16 12 65 22];
            app.HighLvProbEditFieldLabel.Text = 'High Lv. Prob';

            % Create Level_HardLvProb
            app.Level_HardLvProb = uieditfield(app.uipanel1, 'numeric');
            app.Level_HardLvProb.Limits = [0 1];
            app.Level_HardLvProb.ValueChangedFcn = createCallbackFcn(app, @Level_HardLvProbValueChanged, true);
            app.Level_HardLvProb.Tag = 'Level_HardLvProb';
            app.Level_HardLvProb.FontSize = 10;
            app.Level_HardLvProb.Position = [86 12 30 22];
            app.Level_HardLvProb.Value = 0.8;

            % Create Level_EasyLvList
            app.Level_EasyLvList = uieditfield(app.uipanel1, 'text');
            app.Level_EasyLvList.Tag = 'Level_EasyLvList';
            app.Level_EasyLvList.FontSize = 10;
            app.Level_EasyLvList.Position = [120 38 42 22];
            app.Level_EasyLvList.Value = '1';

            % Create EasyLvProbLabel
            app.EasyLvProbLabel = uilabel(app.uipanel1);
            app.EasyLvProbLabel.HorizontalAlignment = 'right';
            app.EasyLvProbLabel.FontSize = 10;
            app.EasyLvProbLabel.Position = [16 38 67 22];
            app.EasyLvProbLabel.Text = 'Easy Lv. Prob';

            % Create Level_EasyLvProb
            app.Level_EasyLvProb = uieditfield(app.uipanel1, 'numeric');
            app.Level_EasyLvProb.Limits = [0 1];
            app.Level_EasyLvProb.ValueChangedFcn = createCallbackFcn(app, @Level_EasyLvProbValueChanged, true);
            app.Level_EasyLvProb.Tag = 'Level_EasyLvProb';
            app.Level_EasyLvProb.FontSize = 10;
            app.Level_EasyLvProb.Position = [87 38 30 22];
            app.Level_EasyLvProb.Value = 0.2;

            % Create EasyTrials
            app.EasyTrials = uicheckbox(app.uipanel1);
            app.EasyTrials.Tag = 'EasyTrials';
            app.EasyTrials.Tooltip = 'Defines if easier trials should be shown or not';
            app.EasyTrials.Text = 'Easy %';
            app.EasyTrials.FontSize = 9;
            app.EasyTrials.Position = [103 70 53 22];

            % Create Starting_opacity
            app.Starting_opacity = uispinner(app.uipanel1);
            app.Starting_opacity.Limits = [1 20];
            app.Starting_opacity.Tag = 'Starting_opacity';
            app.Starting_opacity.FontSize = 10;
            app.Starting_opacity.Position = [36 73 49 17];
            app.Starting_opacity.Value = 1;

            % Create MaxRandAlt
            app.MaxRandAlt = uieditfield(app.uipanel1, 'text');
            app.MaxRandAlt.Tag = 'MaxRandAlt';
            app.MaxRandAlt.HorizontalAlignment = 'center';
            app.MaxRandAlt.FontSize = 11;
            app.MaxRandAlt.Tooltip = 'What the starting opacity is in complete training';
            app.MaxRandAlt.Position = [104 96 22 13];
            app.MaxRandAlt.Value = '4';

            % Create MinRandAlt
            app.MinRandAlt = uieditfield(app.uipanel1, 'text');
            app.MinRandAlt.Tag = 'MinRandAlt';
            app.MinRandAlt.HorizontalAlignment = 'center';
            app.MinRandAlt.FontSize = 11;
            app.MinRandAlt.Tooltip = 'What the starting opacity is in complete training';
            app.MinRandAlt.Position = [73 96 22 13];
            app.MinRandAlt.Value = '2';

            % Create Side_delta
            app.Side_delta = uieditfield(app.uipanel1, 'numeric');
            app.Side_delta.Tag = 'Side_delta';
            app.Side_delta.FontSize = 10;
            app.Side_delta.Position = [132 113 26 16];
            app.Side_delta.Value = 0.2;

            % Create Stimulus_side
            app.Stimulus_side = uidropdown(app.uipanel1);
            app.Stimulus_side.Items = {'Random', 'Left Only', 'Right Only', 'Keyboard', 'Repeat Wrong'};
            app.Stimulus_side.Tag = 'Stimulus_side';
            app.Stimulus_side.Tooltip = 'choose stimulus';
            app.Stimulus_side.FontSize = 9;
            app.Stimulus_side.Position = [47 112 79 18];
            app.Stimulus_side.Value = 'Random';

            % Create Box_Input_type
            app.Box_Input_type = uidropdown(app.uipanel1);
            app.Box_Input_type.Items = {'One Lever', 'Two Levers', 'NosePoke', 'Rotating Ball', 'Lick Sensor', 'Wheel', 'Lick Go/No-Go', 'Keyboard', 'ArduinoWheel', 'ArduinoNosePoke'};
            app.Box_Input_type.ValueChangedFcn = createCallbackFcn(app, @Box_Input_typeValueChanged, true);
            app.Box_Input_type.Tag = 'Box_Input_type';
            app.Box_Input_type.Tooltip = 'choose input';
            app.Box_Input_type.FontSize = 9;
            app.Box_Input_type.Position = [47 133 115 18];
            app.Box_Input_type.Value = 'NosePoke';

            % Create uipanel3
            app.uipanel3 = uipanel(app.SettingsTab);
            app.uipanel3.AutoResizeChildren = 'off';
            app.uipanel3.Title = 'Trial Intervals';
            app.uipanel3.Tag = 'uipanel3';
            app.uipanel3.FontSize = 10;
            app.uipanel3.Position = [199 28 147 294];

            % Create Data_Lbin
            app.Data_Lbin = uieditfield(app.uipanel3, 'text');
            app.Data_Lbin.Tag = 'Data_Lbin';
            app.Data_Lbin.HorizontalAlignment = 'center';
            app.Data_Lbin.FontSize = 11;
            app.Data_Lbin.Tooltip = {'How many small bins in a full bin'};
            app.Data_Lbin.Position = [95 38 20 18];
            app.Data_Lbin.Value = '2';

            % Create Data_Sbin
            app.Data_Sbin = uieditfield(app.uipanel3, 'text');
            app.Data_Sbin.Tag = 'Data_Sbin';
            app.Data_Sbin.HorizontalAlignment = 'center';
            app.Data_Sbin.FontSize = 11;
            app.Data_Sbin.Tooltip = {'How many trials in a small bin'};
            app.Data_Sbin.Position = [54 38 31 18];
            app.Data_Sbin.Value = '10';

            % Create Stimulus_PersistIncorrectInterv
            app.Stimulus_PersistIncorrectInterv = uieditfield(app.uipanel3, 'numeric');
            app.Stimulus_PersistIncorrectInterv.Limits = [0 60];
            app.Stimulus_PersistIncorrectInterv.Tag = 'Stimulus_PersistIncorrectInterv';
            app.Stimulus_PersistIncorrectInterv.HorizontalAlignment = 'center';
            app.Stimulus_PersistIncorrectInterv.FontSize = 10;
            app.Stimulus_PersistIncorrectInterv.Position = [100 60 25 15];
            app.Stimulus_PersistIncorrectInterv.Value = 1;

            % Create Stimulus_PersistIncorrect
            app.Stimulus_PersistIncorrect = uicheckbox(app.uipanel3);
            app.Stimulus_PersistIncorrect.Tag = 'Stimulus_PersistIncorrect';
            app.Stimulus_PersistIncorrect.Text = 'Persist incorrect?';
            app.Stimulus_PersistIncorrect.FontSize = 9;
            app.Stimulus_PersistIncorrect.Position = [5 59 89 16];

            % Create Stimulus_PersistCorrectInterv
            app.Stimulus_PersistCorrectInterv = uieditfield(app.uipanel3, 'numeric');
            app.Stimulus_PersistCorrectInterv.Limits = [0 60];
            app.Stimulus_PersistCorrectInterv.Tag = 'Stimulus_PersistCorrectInterv';
            app.Stimulus_PersistCorrectInterv.HorizontalAlignment = 'center';
            app.Stimulus_PersistCorrectInterv.FontSize = 10;
            app.Stimulus_PersistCorrectInterv.Position = [100 78 25 15];
            app.Stimulus_PersistCorrectInterv.Value = 1;

            % Create Stimulus_PersistCorrect
            app.Stimulus_PersistCorrect = uicheckbox(app.uipanel3);
            app.Stimulus_PersistCorrect.Tag = 'Stimulus_PersistCorrect';
            app.Stimulus_PersistCorrect.Text = 'Persist correct?';
            app.Stimulus_PersistCorrect.FontSize = 9;
            app.Stimulus_PersistCorrect.Position = [5 75 83 16];
            app.Stimulus_PersistCorrect.Value = true;

            % Create Repeat_wrong
            app.Repeat_wrong = uicheckbox(app.uipanel3);
            app.Repeat_wrong.Tag = 'Repeat_wrong';
            app.Repeat_wrong.Tooltip = 'repeat the same side if last one was wrong';
            app.Repeat_wrong.Text = 'repeat wrong';
            app.Repeat_wrong.FontSize = 10;
            app.Repeat_wrong.Position = [4 96 95 15];

            % Create Box_OCPulse
            app.Box_OCPulse = uieditfield(app.uipanel3, 'numeric');
            app.Box_OCPulse.Limits = [0 10];
            app.Box_OCPulse.Tag = 'Box_OCPulse';
            app.Box_OCPulse.FontSize = 10;
            app.Box_OCPulse.Tooltip = {'How many drops to give if using the Only Correct setting, where the mouse is able to answer correctly after a wrong choice.'};
            app.Box_OCPulse.Position = [96 113 25 22];
            app.Box_OCPulse.Value = 1;

            % Create OnlyCorrect
            app.OnlyCorrect = uicheckbox(app.uipanel3);
            app.OnlyCorrect.Tag = 'OnlyCorrect';
            app.OnlyCorrect.Text = 'Only Correct';
            app.OnlyCorrect.FontSize = 10;
            app.OnlyCorrect.Position = [9 115 78 22];

            % Create SideBiasInterval
            app.SideBiasInterval = uieditfield(app.uipanel3, 'numeric');
            app.SideBiasInterval.Limits = [0.05 0.5];
            app.SideBiasInterval.Tag = 'SideBiasInterval';
            app.SideBiasInterval.HorizontalAlignment = 'center';
            app.SideBiasInterval.FontSize = 10;
            app.SideBiasInterval.Position = [89 147 38 22];
            app.SideBiasInterval.Value = 0.25;

            % Create Box_Timeout_after_time
            app.Box_Timeout_after_time = uieditfield(app.uipanel3, 'text');
            app.Box_Timeout_after_time.Tag = 'Box_Timeout_after_time';
            app.Box_Timeout_after_time.HorizontalAlignment = 'center';
            app.Box_Timeout_after_time.FontSize = 10;
            app.Box_Timeout_after_time.Tooltip = 'trial times out and next one begins after how many seconds';
            app.Box_Timeout_after_time.Position = [89 168 38 22];
            app.Box_Timeout_after_time.Value = '0';

            % Create HoldStill
            app.HoldStill = uieditfield(app.uipanel3, 'numeric');
            app.HoldStill.Limits = [0 10];
            app.HoldStill.Tag = 'HoldStill';
            app.HoldStill.HorizontalAlignment = 'center';
            app.HoldStill.FontSize = 10;
            app.HoldStill.Tooltip = {'Hold the wheel still for this many seconds before a new trial starts. Timer will reset if the will is moved during this time.'};
            app.HoldStill.Position = [89 189 38 20];

            % Create Intertrial_time
            app.Intertrial_time = uieditfield(app.uipanel3, 'text');
            app.Intertrial_time.Tag = 'Intertrial_time';
            app.Intertrial_time.HorizontalAlignment = 'center';
            app.Intertrial_time.FontSize = 10;
            app.Intertrial_time.Tooltip = 'Interval between each trial in seconds';
            app.Intertrial_time.Position = [89 209 38 22];
            app.Intertrial_time.Value = '1';

            % Create Penalty_time
            app.Penalty_time = uieditfield(app.uipanel3, 'text');
            app.Penalty_time.Tag = 'Penalty_time';
            app.Penalty_time.HorizontalAlignment = 'center';
            app.Penalty_time.FontSize = 10;
            app.Penalty_time.Tooltip = 'penalty delay in seconds';
            app.Penalty_time.Position = [89 230 38 22];
            app.Penalty_time.Value = '1';

            % Create Pokes_ignored_time
            app.Pokes_ignored_time = uieditfield(app.uipanel3, 'text');
            app.Pokes_ignored_time.Tag = 'Pokes_ignored_time';
            app.Pokes_ignored_time.HorizontalAlignment = 'center';
            app.Pokes_ignored_time.FontSize = 10;
            app.Pokes_ignored_time.Tooltip = 'ignore all input for how many seconds after trial begin';
            app.Pokes_ignored_time.Position = [89 252 38 22];
            app.Pokes_ignored_time.Value = '2';

            % Create Input_ignored
            app.Input_ignored = uicheckbox(app.uipanel3);
            app.Input_ignored.Tag = 'Input_ignored';
            app.Input_ignored.Text = 'Input ignored';
            app.Input_ignored.FontSize = 10;
            app.Input_ignored.Position = [3 250 80 22];

            % Create text8
            app.text8 = uilabel(app.uipanel3);
            app.text8.Tag = 'text8';
            app.text8.HorizontalAlignment = 'right';
            app.text8.FontSize = 10;
            app.text8.Position = [23 235 53 12];
            app.text8.Text = 'Penalty(s)';

            % Create text10
            app.text10 = uilabel(app.uipanel3);
            app.text10.Tag = 'text10';
            app.text10.HorizontalAlignment = 'right';
            app.text10.FontSize = 10;
            app.text10.Position = [23 214 53 12];
            app.text10.Text = 'Intertrial (s)';

            % Create EditField_5Label
            app.EditField_5Label = uilabel(app.uipanel3);
            app.EditField_5Label.HorizontalAlignment = 'right';
            app.EditField_5Label.FontSize = 10;
            app.EditField_5Label.Tooltip = {'Hold the wheel still for this many seconds before a new trial starts. Timer will reset if the will is moved during this time.'};
            app.EditField_5Label.Position = [18 194 58 11];
            app.EditField_5Label.Text = 'Hold still (s):';

            % Create text12
            app.text12 = uilabel(app.uipanel3);
            app.text12.Tag = 'text12';
            app.text12.HorizontalAlignment = 'right';
            app.text12.FontSize = 10;
            app.text12.Position = [23 173 53 12];
            app.text12.Text = 'Timeout (s)';

            % Create SideBiassEditField_2Label
            app.SideBiassEditField_2Label = uilabel(app.uipanel3);
            app.SideBiassEditField_2Label.HorizontalAlignment = 'right';
            app.SideBiassEditField_2Label.FontSize = 10;
            app.SideBiassEditField_2Label.Position = [16 152 60 13];
            app.SideBiassEditField_2Label.Text = 'SideBias (s):';

            % Create text35
            app.text35 = uilabel(app.uipanel3);
            app.text35.Tag = 'text35';
            app.text35.HorizontalAlignment = 'center';
            app.text35.VerticalAlignment = 'top';
            app.text35.FontSize = 11;
            app.text35.Position = [15 39 38 15];
            app.text35.Text = 'binsize:';

            % Create uipanel4
            app.uipanel4 = uipanel(app.SettingsTab);
            app.uipanel4.AutoResizeChildren = 'off';
            app.uipanel4.Title = 'Reward / Penalty';
            app.uipanel4.Tag = 'uipanel4';
            app.uipanel4.FontSize = 11;
            app.uipanel4.Position = [355 245 154 77];

            % Create secbwPulsesEditFieldLabel
            app.secbwPulsesEditFieldLabel = uilabel(app.uipanel4);
            app.secbwPulsesEditFieldLabel.FontSize = 10;
            app.secbwPulsesEditFieldLabel.Position = [6 6 72 10];
            app.secbwPulsesEditFieldLabel.Text = 'sec b/w Pulses';

            % Create Box_SecBwPulse
            app.Box_SecBwPulse = uieditfield(app.uipanel4, 'numeric');
            app.Box_SecBwPulse.Tag = 'Box_SecBwPulse';
            app.Box_SecBwPulse.FontSize = 10;
            app.Box_SecBwPulse.Position = [80 3 26 15];
            app.Box_SecBwPulse.Value = 0.2;

            % Create Box_RightPulse
            app.Box_RightPulse = uieditfield(app.uipanel4, 'numeric');
            app.Box_RightPulse.Limits = [1 10];
            app.Box_RightPulse.Tag = 'Box_RightPulse';
            app.Box_RightPulse.HorizontalAlignment = 'center';
            app.Box_RightPulse.FontSize = 10;
            app.Box_RightPulse.Tooltip = {'How many pulses from the rightwater valve'};
            app.Box_RightPulse.Position = [68 21 25 14];
            app.Box_RightPulse.Value = 1;

            % Create Box_LeftPulse
            app.Box_LeftPulse = uieditfield(app.uipanel4, 'numeric');
            app.Box_LeftPulse.Limits = [1 10];
            app.Box_LeftPulse.Tag = 'Box_LeftPulse';
            app.Box_LeftPulse.HorizontalAlignment = 'center';
            app.Box_LeftPulse.FontSize = 10;
            app.Box_LeftPulse.Tooltip = {'How many pulses from the left water valve'};
            app.Box_LeftPulse.Position = [68 39 25 14];
            app.Box_LeftPulse.Value = 1;

            % Create Box_Rrewardtime
            app.Box_Rrewardtime = uieditfield(app.uipanel4, 'text');
            app.Box_Rrewardtime.ValueChangedFcn = createCallbackFcn(app, @RewardTimeChanged, true);
            app.Box_Rrewardtime.Tag = 'Box_Rrewardtime';
            app.Box_Rrewardtime.HorizontalAlignment = 'center';
            app.Box_Rrewardtime.FontSize = 11;
            app.Box_Rrewardtime.Tooltip = 'How long the vale is open in seconds';
            app.Box_Rrewardtime.Position = [26 21 38 14];
            app.Box_Rrewardtime.Value = '0.04';

            % Create Box_Lrewardtime
            app.Box_Lrewardtime = uieditfield(app.uipanel4, 'text');
            app.Box_Lrewardtime.ValueChangedFcn = createCallbackFcn(app, @RewardTimeChanged, true);
            app.Box_Lrewardtime.Tag = 'Box_Lrewardtime';
            app.Box_Lrewardtime.HorizontalAlignment = 'center';
            app.Box_Lrewardtime.FontSize = 11;
            app.Box_Lrewardtime.Tooltip = 'How long the vale is open in seconds';
            app.Box_Lrewardtime.Position = [26 39 38 14];
            app.Box_Lrewardtime.Value = '0.04';

            % Create RightValveButton
            app.RightValveButton = uibutton(app.uipanel4, 'push');
            app.RightValveButton.ButtonPushedFcn = createCallbackFcn(app, @RightValveButtonPushed, true);
            app.RightValveButton.Tag = 'RightValveButton';
            app.RightValveButton.VerticalAlignment = 'top';
            app.RightValveButton.BackgroundColor = [0 0 1];
            app.RightValveButton.FontSize = 11;
            app.RightValveButton.FontWeight = 'bold';
            app.RightValveButton.FontColor = [1 1 1];
            app.RightValveButton.Tooltip = {'Press to test Right water reward size'};
            app.RightValveButton.Position = [4 20 19 17];
            app.RightValveButton.Text = 'R';

            % Create LeftValveButton
            app.LeftValveButton = uibutton(app.uipanel4, 'push');
            app.LeftValveButton.ButtonPushedFcn = createCallbackFcn(app, @LeftValveButtonPushed, true);
            app.LeftValveButton.Tag = 'LeftValveButton';
            app.LeftValveButton.BackgroundColor = [0 0 1];
            app.LeftValveButton.FontSize = 11;
            app.LeftValveButton.FontWeight = 'bold';
            app.LeftValveButton.FontColor = [1 1 1];
            app.LeftValveButton.Tooltip = {'Press to test Left water reward size'};
            app.LeftValveButton.Position = [4 38 18 17];
            app.LeftValveButton.Text = 'L';

            % Create text86
            app.text86 = uilabel(app.SettingsTab);
            app.text86.Tag = 'text86';
            app.text86.HorizontalAlignment = 'center';
            app.text86.FontSize = 8;
            app.text86.Position = [12 7 169 22];
            app.text86.Text = 'WBS Jan. 2025';

            % Create SubjectPanel
            app.SubjectPanel = uipanel(app.SettingsTab);
            app.SubjectPanel.AutoResizeChildren = 'off';
            app.SubjectPanel.Title = 'Subject';
            app.SubjectPanel.Position = [11 28 178 118];

            % Create text13
            app.text13 = uilabel(app.SubjectPanel);
            app.text13.Tag = 'text13';
            app.text13.HorizontalAlignment = 'right';
            app.text13.Position = [-3 51 68 22];
            app.text13.Text = 'Strain';

            % Create WeightgEditFieldLabel
            app.WeightgEditFieldLabel = uilabel(app.SubjectPanel);
            app.WeightgEditFieldLabel.HorizontalAlignment = 'right';
            app.WeightgEditFieldLabel.Position = [-3 28 68 22];
            app.WeightgEditFieldLabel.Text = 'Weight';

            % Create Investigator
            app.Investigator = uilabel(app.SubjectPanel);
            app.Investigator.Tag = 'text128';
            app.Investigator.HorizontalAlignment = 'right';
            app.Investigator.Position = [-3 74 68 22];
            app.Investigator.Text = 'Investigator';

            % Create DropDownLabel
            app.DropDownLabel = uilabel(app.SubjectPanel);
            app.DropDownLabel.Tag = 'StrainDropDown';
            app.DropDownLabel.HorizontalAlignment = 'right';
            app.DropDownLabel.Position = [1 3 66 22];
            app.DropDownLabel.Text = 'Drop Down';

            % Create StrainDropDown
            app.StrainDropDown = uidropdown(app.SubjectPanel);
            app.StrainDropDown.Items = {'shank'};
            app.StrainDropDown.Tag = 'StrainDropDown';
            app.StrainDropDown.Position = [82 3 96 22];
            app.StrainDropDown.Value = 'shank';

            % Create WeightgEditField
            app.WeightgEditField = uieditfield(app.SubjectPanel, 'text');
            app.WeightgEditField.Tag = 'Weight';
            app.WeightgEditField.Tooltip = {'Enter the animal''s weight in grams'};
            app.WeightgEditField.Position = [69 28 57 22];

            % Create Strain
            app.Strain = uieditfield(app.SubjectPanel, 'text');
            app.Strain.Tag = 'Strain';
            app.Strain.HorizontalAlignment = 'center';
            app.Strain.Tooltip = 'Enter animal strain e.g. Shank3, 16b';
            app.Strain.Position = [69 51 57 22];
            app.Strain.Value = 'w';

            % Create Inv
            app.Inv = uieditfield(app.SubjectPanel, 'text');
            app.Inv.Tag = 'Investigator';
            app.Inv.HorizontalAlignment = 'center';
            app.Inv.Tooltip = 'Name of person conducting the training';
            app.Inv.Position = [69 74 57 22];
            app.Inv.Value = 'Will';

            % Create Panel_2
            app.Panel_2 = uipanel(app.SettingsTab);
            app.Panel_2.AutoResizeChildren = 'off';
            app.Panel_2.Title = 'Panel';
            app.Panel_2.Position = [355 7 333 102];

            % Create text121
            app.text121 = uilabel(app.Panel_2);
            app.text121.Tag = 'text121';
            app.text121.HorizontalAlignment = 'center';
            app.text121.VerticalAlignment = 'top';
            app.text121.FontSize = 11;
            app.text121.Position = [50 44 28 17];
            app.text121.Text = 'freq';

            % Create text122
            app.text122 = uilabel(app.Panel_2);
            app.text122.Tag = 'text122';
            app.text122.HorizontalAlignment = 'center';
            app.text122.VerticalAlignment = 'top';
            app.text122.FontSize = 11;
            app.text122.Position = [116 44 36 17];
            app.text122.Text = 'reps';

            % Create Stimulus_CorrectAngleAdj
            app.Stimulus_CorrectAngleAdj = uieditfield(app.Panel_2, 'numeric');
            app.Stimulus_CorrectAngleAdj.Tag = 'Stimulus_CorrectAngleAdj';
            app.Stimulus_CorrectAngleAdj.FontSize = 10;
            app.Stimulus_CorrectAngleAdj.Tooltip = {'When correcting the randomly oriented segments, lines are offset by a random angle between this and the tolerance.'};
            app.Stimulus_CorrectAngleAdj.Position = [274 31 26 22];
            app.Stimulus_CorrectAngleAdj.Value = 45;

            % Create ContangletolEditFieldLabel
            app.ContangletolEditFieldLabel = uilabel(app.Panel_2);
            app.ContangletolEditFieldLabel.HorizontalAlignment = 'right';
            app.ContangletolEditFieldLabel.FontSize = 10;
            app.ContangletolEditFieldLabel.Position = [199 56 72 22];
            app.ContangletolEditFieldLabel.Text = 'Cont. angle tol.';

            % Create Stimulus_ContTol
            app.Stimulus_ContTol = uieditfield(app.Panel_2, 'numeric');
            app.Stimulus_ContTol.Tag = 'Stimulus_ContTol';
            app.Stimulus_ContTol.FontSize = 10;
            app.Stimulus_ContTol.Tooltip = {'Stimuli are checked for accidental continuation and any angles below this threshold are adjusted'};
            app.Stimulus_ContTol.Position = [274 56 26 22];
            app.Stimulus_ContTol.Value = 10;

            % Create CorrectionoffsetEditFieldLabel
            app.CorrectionoffsetEditFieldLabel = uilabel(app.Panel_2);
            app.CorrectionoffsetEditFieldLabel.HorizontalAlignment = 'right';
            app.CorrectionoffsetEditFieldLabel.FontSize = 10;
            app.CorrectionoffsetEditFieldLabel.Position = [193 31 78 22];
            app.CorrectionoffsetEditFieldLabel.Text = 'Correction offset';

            % Create Stimulus_RepFlashAfterW
            app.Stimulus_RepFlashAfterW = uieditfield(app.Panel_2, 'text');
            app.Stimulus_RepFlashAfterW.Tag = 'Stimulus_RepFlashAfterW';
            app.Stimulus_RepFlashAfterW.FontSize = 11;
            app.Stimulus_RepFlashAfterW.Tooltip = 'Number of times (repetitions) that stimulus is flashed';
            app.Stimulus_RepFlashAfterW.Position = [176 24 22 18];
            app.Stimulus_RepFlashAfterW.Value = '1';

            % Create Stimulus_RepFlashAfterC
            app.Stimulus_RepFlashAfterC = uieditfield(app.Panel_2, 'text');
            app.Stimulus_RepFlashAfterC.Tag = 'Stimulus_RepFlashAfterC';
            app.Stimulus_RepFlashAfterC.FontSize = 11;
            app.Stimulus_RepFlashAfterC.Tooltip = 'Number of times (repetitions) that stimulus is flashed';
            app.Stimulus_RepFlashAfterC.Position = [147 24 22 18];
            app.Stimulus_RepFlashAfterC.Value = '1';

            % Create Stimulus_RepFlashInitial
            app.Stimulus_RepFlashInitial = uieditfield(app.Panel_2, 'text');
            app.Stimulus_RepFlashInitial.Tag = 'Stimulus_RepFlashInitial';
            app.Stimulus_RepFlashInitial.FontSize = 11;
            app.Stimulus_RepFlashInitial.Tooltip = 'Number of times (repetitions) that stimulus is flashed';
            app.Stimulus_RepFlashInitial.Position = [147 43 22 18];
            app.Stimulus_RepFlashInitial.Value = '1';

            % Create EditField
            app.EditField = uieditfield(app.Panel_2, 'numeric');
            app.EditField.Tag = 'Stimulus_FreqAnimation';
            app.EditField.HorizontalAlignment = 'left';
            app.EditField.FontSize = 10;
            app.EditField.Position = [78 37 36 22];
            app.EditField.Value = 50;

            % Create Stimulus_FlashStim
            app.Stimulus_FlashStim = uicheckbox(app.Panel_2);
            app.Stimulus_FlashStim.Tag = 'Stimulus_FlashStim';
            app.Stimulus_FlashStim.Text = 'flash';
            app.Stimulus_FlashStim.FontSize = 11;
            app.Stimulus_FlashStim.Position = [5 43 58 18];
            app.Stimulus_FlashStim.Value = true;

            % Create text65
            app.text65 = uilabel(app.Panel_2);
            app.text65.Tag = 'text65';
            app.text65.HorizontalAlignment = 'right';
            app.text65.VerticalAlignment = 'top';
            app.text65.FontSize = 11;
            app.text65.Position = [1 64 49 16];
            app.text65.Text = 'Stimulus:';

            % Create Stimulus_type
            app.Stimulus_type = uidropdown(app.Panel_2);
            app.Stimulus_type.Items = {'Contour crude', 'Contour fine ', 'Square Vs O crude', 'Square Vs O fine', 'unknown', 'XvsO', 'Two Task Contour', 'Cued Images', 'Distract Contour', 'Grating', 'Contour Density', 'BehaviorBox Practice'};
            app.Stimulus_type.Tag = 'Stimulus_type';
            app.Stimulus_type.Tooltip = 'choose stimulus';
            app.Stimulus_type.FontSize = 9;
            app.Stimulus_type.Position = [55 63 115 18];
            app.Stimulus_type.Value = 'Contour Density';

            % Create StimulusvariablesPanel
            app.StimulusvariablesPanel = uipanel(app.SettingsTab);
            app.StimulusvariablesPanel.AutoResizeChildren = 'off';
            app.StimulusvariablesPanel.Title = 'Stimulus variables';
            app.StimulusvariablesPanel.Position = [695 7 178 313];

            % Create Arduino_Com
            app.Arduino_Com = uieditfield(app.StimulusvariablesPanel, 'text');
            app.Arduino_Com.Tag = 'Arduino_Com';
            app.Arduino_Com.HorizontalAlignment = 'center';
            app.Arduino_Com.Tooltip = 'com port to use for arduino';
            app.Arduino_Com.Position = [23 7 59 22];

            % Create Stimulus_position_y
            app.Stimulus_position_y = uieditfield(app.StimulusvariablesPanel, 'text');
            app.Stimulus_position_y.Tag = 'Stimulus_position_y';
            app.Stimulus_position_y.HorizontalAlignment = 'center';
            app.Stimulus_position_y.FontSize = 11;
            app.Stimulus_position_y.Tooltip = {'Y position in pixels'};
            app.Stimulus_position_y.Position = [133 36 35 13];
            app.Stimulus_position_y.Value = '1';

            % Create Stimulus_position_x
            app.Stimulus_position_x = uieditfield(app.StimulusvariablesPanel, 'text');
            app.Stimulus_position_x.Tag = 'Stimulus_position_x';
            app.Stimulus_position_x.HorizontalAlignment = 'center';
            app.Stimulus_position_x.FontSize = 11;
            app.Stimulus_position_x.Tooltip = {'X position in pixels'};
            app.Stimulus_position_x.Position = [92 36 35 13];
            app.Stimulus_position_x.Value = '1';

            % Create Stimulus_size_x
            app.Stimulus_size_x = uieditfield(app.StimulusvariablesPanel, 'text');
            app.Stimulus_size_x.Tag = 'Stimulus_size_x';
            app.Stimulus_size_x.HorizontalAlignment = 'center';
            app.Stimulus_size_x.FontSize = 11;
            app.Stimulus_size_x.Tooltip = {'Width in pixels'};
            app.Stimulus_size_x.Position = [50 36 35 13];
            app.Stimulus_size_x.Value = '10';

            % Create Stimulus_size_y
            app.Stimulus_size_y = uieditfield(app.StimulusvariablesPanel, 'text');
            app.Stimulus_size_y.Tag = 'Stimulus_size_y';
            app.Stimulus_size_y.HorizontalAlignment = 'center';
            app.Stimulus_size_y.FontSize = 11;
            app.Stimulus_size_y.Tooltip = {'Height in pixels'};
            app.Stimulus_size_y.Position = [7 36 36 13];
            app.Stimulus_size_y.Value = '3';

            % Create SpotlightbrightnessEditFieldLabel
            app.SpotlightbrightnessEditFieldLabel = uilabel(app.StimulusvariablesPanel);
            app.SpotlightbrightnessEditFieldLabel.HorizontalAlignment = 'right';
            app.SpotlightbrightnessEditFieldLabel.FontSize = 10;
            app.SpotlightbrightnessEditFieldLabel.Position = [16 203 93 15];
            app.SpotlightbrightnessEditFieldLabel.Text = 'Spotlight brightness';

            % Create BetweenSpotlight_textlabel
            app.BetweenSpotlight_textlabel = uilabel(app.StimulusvariablesPanel);
            app.BetweenSpotlight_textlabel.HorizontalAlignment = 'right';
            app.BetweenSpotlight_textlabel.FontSize = 10;
            app.BetweenSpotlight_textlabel.Tooltip = {'Percentage of the screen space that is left blank between each spotlight'};
            app.BetweenSpotlight_textlabel.Position = [6 178 103 22];
            app.BetweenSpotlight_textlabel.Text = 'Between spotlight (%)';

            % Create ReadyCuecolorLabel
            app.ReadyCuecolorLabel = uilabel(app.StimulusvariablesPanel);
            app.ReadyCuecolorLabel.HorizontalAlignment = 'right';
            app.ReadyCuecolorLabel.FontSize = 10;
            app.ReadyCuecolorLabel.Position = [32 75 77 17];
            app.ReadyCuecolorLabel.Text = 'ReadyCue color';

            % Create EditField_2Label
            app.EditField_2Label = uilabel(app.StimulusvariablesPanel);
            app.EditField_2Label.HorizontalAlignment = 'right';
            app.EditField_2Label.FontSize = 10;
            app.EditField_2Label.Position = [36 52 73 22];
            app.EditField_2Label.Text = 'ReadyCue size';

            % Create ReadyCue_Size
            app.ReadyCue_Size = uieditfield(app.StimulusvariablesPanel, 'numeric');
            app.ReadyCue_Size.Limits = [1 Inf];
            app.ReadyCue_Size.Tag = 'ReadyCue_Size';
            app.ReadyCue_Size.FontSize = 10;
            app.ReadyCue_Size.Position = [119 52 44 22];
            app.ReadyCue_Size.Value = 12;

            % Create ReadyCue_Color
            app.ReadyCue_Color = uieditfield(app.StimulusvariablesPanel, 'numeric');
            app.ReadyCue_Color.Limits = [0 1];
            app.ReadyCue_Color.Tag = 'ReadyCue_Color';
            app.ReadyCue_Color.FontSize = 10;
            app.ReadyCue_Color.Position = [119 73 44 22];

            % Create BackgroundEditFieldLabel
            app.BackgroundEditFieldLabel = uilabel(app.StimulusvariablesPanel);
            app.BackgroundEditFieldLabel.HorizontalAlignment = 'right';
            app.BackgroundEditFieldLabel.FontSize = 10;
            app.BackgroundEditFieldLabel.Position = [36 98 73 15];
            app.BackgroundEditFieldLabel.Text = 'Background';

            % Create Stimulus_BackgroundColor
            app.Stimulus_BackgroundColor = uieditfield(app.StimulusvariablesPanel, 'numeric');
            app.Stimulus_BackgroundColor.Limits = [0 1];
            app.Stimulus_BackgroundColor.Tag = 'Stimulus_BackgroundColor';
            app.Stimulus_BackgroundColor.FontSize = 10;
            app.Stimulus_BackgroundColor.Tooltip = {'0 is black and 1 is white'};
            app.Stimulus_BackgroundColor.Position = [119 94 44 22];

            % Create BackgroundEditFieldLabel_2
            app.BackgroundEditFieldLabel_2 = uilabel(app.StimulusvariablesPanel);
            app.BackgroundEditFieldLabel_2.HorizontalAlignment = 'right';
            app.BackgroundEditFieldLabel_2.FontSize = 10;
            app.BackgroundEditFieldLabel_2.Position = [36 115 73 22];
            app.BackgroundEditFieldLabel_2.Text = 'Dim Color';

            % Create Stimulus_DimColor
            app.Stimulus_DimColor = uieditfield(app.StimulusvariablesPanel, 'numeric');
            app.Stimulus_DimColor.Limits = [0 1];
            app.Stimulus_DimColor.Tag = 'Stimulus_DimColor';
            app.Stimulus_DimColor.FontSize = 10;
            app.Stimulus_DimColor.Tooltip = {'0 is black and 1 is white'};
            app.Stimulus_DimColor.Position = [119 115 44 22];
            app.Stimulus_DimColor.Value = 0.1;

            % Create EditField_5Label_2
            app.EditField_5Label_2 = uilabel(app.StimulusvariablesPanel);
            app.EditField_5Label_2.HorizontalAlignment = 'right';
            app.EditField_5Label_2.FontSize = 10;
            app.EditField_5Label_2.Tooltip = {'The stimulus will alternate between this color and the regular brightness.'};
            app.EditField_5Label_2.Position = [52 136 57 22];
            app.EditField_5Label_2.Text = 'Flash Color';

            % Create Stimulus_FlashColor
            app.Stimulus_FlashColor = uieditfield(app.StimulusvariablesPanel, 'numeric');
            app.Stimulus_FlashColor.Limits = [0 1];
            app.Stimulus_FlashColor.Tag = 'Stimulus_FlashColor';
            app.Stimulus_FlashColor.FontSize = 10;
            app.Stimulus_FlashColor.Tooltip = {'The stimulus will alternate between this color and the regular brightness.'};
            app.Stimulus_FlashColor.Position = [119 136 44 22];
            app.Stimulus_FlashColor.Value = 1;

            % Create LinebrightnessEditFieldLabel
            app.LinebrightnessEditFieldLabel = uilabel(app.StimulusvariablesPanel);
            app.LinebrightnessEditFieldLabel.HorizontalAlignment = 'right';
            app.LinebrightnessEditFieldLabel.FontSize = 10;
            app.LinebrightnessEditFieldLabel.Position = [36 160 73 16];
            app.LinebrightnessEditFieldLabel.Text = 'Line brightness';

            % Create Stimulus_LineColor
            app.Stimulus_LineColor = uieditfield(app.StimulusvariablesPanel, 'numeric');
            app.Stimulus_LineColor.Limits = [0 1];
            app.Stimulus_LineColor.Tag = 'Stimulus_LineColor';
            app.Stimulus_LineColor.FontSize = 10;
            app.Stimulus_LineColor.Tooltip = {'0 is black and 1 is white'};
            app.Stimulus_LineColor.Position = [119 157 44 22];
            app.Stimulus_LineColor.Value = 0.6;

            % Create Stimulus_BetweenSpotlight
            app.Stimulus_BetweenSpotlight = uieditfield(app.StimulusvariablesPanel, 'numeric');
            app.Stimulus_BetweenSpotlight.Limits = [0 99];
            app.Stimulus_BetweenSpotlight.Tag = 'Stimulus_BetweenSpotlight';
            app.Stimulus_BetweenSpotlight.FontSize = 10;
            app.Stimulus_BetweenSpotlight.Tooltip = {'Percentage of the screen space that is left blank between each spotlight. 33% is the default for the nose poke, use a smaller value for the wheel.'};
            app.Stimulus_BetweenSpotlight.Position = [119 178 44 22];
            app.Stimulus_BetweenSpotlight.Value = 10;

            % Create Stimulus_SpotlightColor
            app.Stimulus_SpotlightColor = uieditfield(app.StimulusvariablesPanel, 'numeric');
            app.Stimulus_SpotlightColor.Limits = [0 1];
            app.Stimulus_SpotlightColor.Tag = 'Stimulus_SpotlightColor';
            app.Stimulus_SpotlightColor.FontSize = 10;
            app.Stimulus_SpotlightColor.Tooltip = {'0 is black and 1 is white'};
            app.Stimulus_SpotlightColor.Position = [119 199 44 22];

            % Create SegmentSpacingEditFieldLabel
            app.SegmentSpacingEditFieldLabel = uilabel(app.StimulusvariablesPanel);
            app.SegmentSpacingEditFieldLabel.HorizontalAlignment = 'right';
            app.SegmentSpacingEditFieldLabel.FontSize = 10;
            app.SegmentSpacingEditFieldLabel.Position = [25 224 84 15];
            app.SegmentSpacingEditFieldLabel.Text = 'Segment Spacing';

            % Create Stimulus_SegSpacing
            app.Stimulus_SegSpacing = uieditfield(app.StimulusvariablesPanel, 'numeric');
            app.Stimulus_SegSpacing.Tag = 'Stimulus_SegSpacing';
            app.Stimulus_SegSpacing.FontSize = 10;
            app.Stimulus_SegSpacing.Position = [119 220 44 22];
            app.Stimulus_SegSpacing.Value = 13;

            % Create SegmentlengthEditFieldLabel
            app.SegmentlengthEditFieldLabel = uilabel(app.StimulusvariablesPanel);
            app.SegmentlengthEditFieldLabel.HorizontalAlignment = 'right';
            app.SegmentlengthEditFieldLabel.FontSize = 10;
            app.SegmentlengthEditFieldLabel.Position = [36 245 73 15];
            app.SegmentlengthEditFieldLabel.Text = 'Segment length';

            % Create Stimulus_SegLength
            app.Stimulus_SegLength = uieditfield(app.StimulusvariablesPanel, 'numeric');
            app.Stimulus_SegLength.Tag = 'Stimulus_SegLength';
            app.Stimulus_SegLength.FontSize = 10;
            app.Stimulus_SegLength.Position = [119 241 44 22];
            app.Stimulus_SegLength.Value = 13;

            % Create SegmentthicknessEditFieldLabel
            app.SegmentthicknessEditFieldLabel = uilabel(app.StimulusvariablesPanel);
            app.SegmentthicknessEditFieldLabel.HorizontalAlignment = 'right';
            app.SegmentthicknessEditFieldLabel.FontSize = 10;
            app.SegmentthicknessEditFieldLabel.Position = [18 266 91 15];
            app.SegmentthicknessEditFieldLabel.Text = 'Segment thickness';

            % Create Stimulus_SegThick
            app.Stimulus_SegThick = uieditfield(app.StimulusvariablesPanel, 'numeric');
            app.Stimulus_SegThick.Tag = 'Stimulus_SegThick';
            app.Stimulus_SegThick.FontSize = 10;
            app.Stimulus_SegThick.Position = [119 262 44 22];
            app.Stimulus_SegThick.Value = 13;

            % Create WinPos
            app.WinPos = uibutton(app.StimulusvariablesPanel, 'state');
            app.WinPos.ValueChangedFcn = createCallbackFcn(app, @WinPosValueChanged, true);
            app.WinPos.Tag = 'WinPos';
            app.WinPos.Text = 'Get Size';
            app.WinPos.BackgroundColor = [0 0 0];
            app.WinPos.FontSize = 10;
            app.WinPos.FontWeight = 'bold';
            app.WinPos.FontColor = [1 1 1];
            app.WinPos.Position = [102 9 51 18];

            % Create InputControlPanel
            app.InputControlPanel = uipanel(app.SettingsTab);
            app.InputControlPanel.AutoResizeChildren = 'off';
            app.InputControlPanel.Title = 'Input Control';
            app.InputControlPanel.Position = [519 113 169 209];

            % Create DuringTrialEditFieldLabel
            app.DuringTrialEditFieldLabel = uilabel(app.InputControlPanel);
            app.DuringTrialEditFieldLabel.HorizontalAlignment = 'right';
            app.DuringTrialEditFieldLabel.FontSize = 10;
            app.DuringTrialEditFieldLabel.Position = [8 25 54 22];
            app.DuringTrialEditFieldLabel.Text = 'Input delay';

            % Create EditField_6Label
            app.EditField_6Label = uilabel(app.InputControlPanel);
            app.EditField_6Label.HorizontalAlignment = 'right';
            app.EditField_6Label.FontSize = 10;
            app.EditField_6Label.Position = [6 2 78 22];
            app.EditField_6Label.Text = 'Hold Still Thresh';

            % Create Hold_Still_Thresh
            app.Hold_Still_Thresh = uieditfield(app.InputControlPanel, 'numeric');
            app.Hold_Still_Thresh.Limits = [0 500];
            app.Hold_Still_Thresh.Tag = 'Hold_Still_Thresh';
            app.Hold_Still_Thresh.FontSize = 10;
            app.Hold_Still_Thresh.Tooltip = {'Speed mouse must keep wheel under during "Hold Still" interval before trial.'};
            app.Hold_Still_Thresh.Position = [106 2 44 22];
            app.Hold_Still_Thresh.Value = 10;

            % Create Input_Delay_Respond
            app.Input_Delay_Respond = uieditfield(app.InputControlPanel, 'numeric');
            app.Input_Delay_Respond.Limits = [0 200];
            app.Input_Delay_Respond.Tag = 'Input_Delay_Respond';
            app.Input_Delay_Respond.FontSize = 10;
            app.Input_Delay_Respond.Tooltip = {'Trial response delay. Mouse must hold their choice for this time before it is accepted.'};
            app.Input_Delay_Respond.Position = [116 25 44 22];
            app.Input_Delay_Respond.Value = 2;

            % Create Input_Delay_Start
            app.Input_Delay_Start = uieditfield(app.InputControlPanel, 'numeric');
            app.Input_Delay_Start.Limits = [0 200];
            app.Input_Delay_Start.Tag = 'Input_Delay_Start';
            app.Input_Delay_Start.FontSize = 10;
            app.Input_Delay_Start.Tooltip = {'Start a trial response delay. Mouse must hold their choice for this time before it is accepted.'};
            app.Input_Delay_Start.Position = [65 25 44 22];
            app.Input_Delay_Start.Value = 2;

            % Create ConfirmChoice
            app.ConfirmChoice = uicheckbox(app.InputControlPanel);
            app.ConfirmChoice.Tag = 'ConfirmChoice';
            app.ConfirmChoice.Tooltip = {'If the mouse stands in front of the correct choice during the Input Ignored interval, the 5-dashed line contour will blink to show the impatient mouse they are indeed going to be rewarded.'};
            app.ConfirmChoice.Text = 'Confirm choice';
            app.ConfirmChoice.FontSize = 10;
            app.ConfirmChoice.Position = [15 44 89 22];
            app.ConfirmChoice.Value = true;

            % Create SkipWaitForInput
            app.SkipWaitForInput = uicheckbox(app.InputControlPanel);
            app.SkipWaitForInput.Tag = 'SkipWaitForInput';
            app.SkipWaitForInput.Tooltip = {'Trials will begin without holding the middle choice'};
            app.SkipWaitForInput.Text = 'Skip WaitForInput';
            app.SkipWaitForInput.FontSize = 10;
            app.SkipWaitForInput.Position = [14 76 101 22];

            % Create IntertrialMalSec
            app.IntertrialMalSec = uieditfield(app.InputControlPanel, 'numeric');
            app.IntertrialMalSec.Tag = 'IntertrialMalSec';
            app.IntertrialMalSec.FontSize = 10;
            app.IntertrialMalSec.Tooltip = {'If the box is checked, a new trial will not begin until this many seconds after the mouse last poked Left or Right during the intertrial period. Once a new trial does begin, it will cancel if the mouse pokes anything but the center.'};
            app.IntertrialMalSec.Position = [109 104 44 22];
            app.IntertrialMalSec.Value = 1;

            % Create IntertrialMalCancel
            app.IntertrialMalCancel = uicheckbox(app.InputControlPanel);
            app.IntertrialMalCancel.Tag = 'IntertrialMalCancel';
            app.IntertrialMalCancel.Tooltip = {'Check this box to end the current trial if the mouse pokes left or right when the ready cue is up. Only a center poke will start the next trial.'};
            app.IntertrialMalCancel.Text = 'Intertrial Mal';
            app.IntertrialMalCancel.FontSize = 10;
            app.IntertrialMalCancel.Position = [24 104 73 22];
            app.IntertrialMalCancel.Value = true;

            % Create Stimulus_FinishLine
            app.Stimulus_FinishLine = uicheckbox(app.InputControlPanel);
            app.Stimulus_FinishLine.Tag = 'Stimulus_FinishLine';
            app.Stimulus_FinishLine.Tooltip = {'DIsplay a marker that will indicate how far the mouse has to turn the wheel to input a choice. Based on stimulus variables.'};
            app.Stimulus_FinishLine.Text = 'Finish line?';
            app.Stimulus_FinishLine.FontSize = 10;
            app.Stimulus_FinishLine.Position = [5 124 70 15];

            % Create RoundUpEditFieldLabel
            app.RoundUpEditFieldLabel = uilabel(app.InputControlPanel);
            app.RoundUpEditFieldLabel.HorizontalAlignment = 'right';
            app.RoundUpEditFieldLabel.FontSize = 10;
            app.RoundUpEditFieldLabel.Position = [26 134 69 22];
            app.RoundUpEditFieldLabel.Text = 'Round Up (%)';

            % Create RoundUpVal
            app.RoundUpVal = uieditfield(app.InputControlPanel, 'numeric');
            app.RoundUpVal.Limits = [0 110];
            app.RoundUpVal.Tag = 'RoundUpVal';
            app.RoundUpVal.FontSize = 10;
            app.RoundUpVal.Tooltip = {'Choose the percentage threshold to accept the mouse''s choice if they do not turn the wheel fully.'};
            app.RoundUpVal.Position = [102 134 54 22];
            app.RoundUpVal.Value = 95;

            % Create RoundUp
            app.RoundUp = uicheckbox(app.InputControlPanel);
            app.RoundUp.Tag = 'RoundUp';
            app.RoundUp.Tooltip = {'Choose to accept the mouse''s choice at timeout if they turn the wheel *almost* to the choice.'};
            app.RoundUp.Text = 'Round up choice';
            app.RoundUp.FontSize = 10;
            app.RoundUp.Position = [5 148 97 22];

            % Create TurnMagEditFieldLabel
            app.TurnMagEditFieldLabel = uilabel(app.InputControlPanel);
            app.TurnMagEditFieldLabel.HorizontalAlignment = 'right';
            app.TurnMagEditFieldLabel.FontSize = 9;
            app.TurnMagEditFieldLabel.Position = [6 165 46 22];
            app.TurnMagEditFieldLabel.Text = 'Turn Mag.';

            % Create TurnMag
            app.TurnMag = uieditfield(app.InputControlPanel, 'numeric');
            app.TurnMag.Tag = 'TurnMag';
            app.TurnMag.FontSize = 9;
            app.TurnMag.Position = [53 165 107 22];
            app.TurnMag.Value = 1000;

            % Create One_ScanImage_File
            app.One_ScanImage_File = uicheckbox(app.SettingsTab);
            app.One_ScanImage_File.Tag = 'One_ScanImage_File';
            app.One_ScanImage_File.Text = '1 Scanimage File';
            app.One_ScanImage_File.Position = [376 191 114 22];
            app.One_ScanImage_File.Value = true;

            % Create TemporaryTab
            app.TemporaryTab = uitab(app.TabGroup);
            app.TemporaryTab.AutoResizeChildren = 'off';
            app.TemporaryTab.Title = 'Temporary';

            % Create uipanel1_2
            app.uipanel1_2 = uipanel(app.TemporaryTab);
            app.uipanel1_2.AutoResizeChildren = 'off';
            app.uipanel1_2.Title = 'Level & Side';
            app.uipanel1_2.Tag = 'uipanel1';
            app.uipanel1_2.FontSize = 10;
            app.uipanel1_2.Position = [11 150 178 172];

            % Create DistractorsSpinnerLabel_2
            app.DistractorsSpinnerLabel_2 = uilabel(app.uipanel1_2);
            app.DistractorsSpinnerLabel_2.FontSize = 10;
            app.DistractorsSpinnerLabel_2.Position = [7 53 29 17];
            app.DistractorsSpinnerLabel_2.Text = 'Level';

            % Create Starting_opacity_Temp
            app.Starting_opacity_Temp = uispinner(app.uipanel1_2);
            app.Starting_opacity_Temp.Limits = [1 20];
            app.Starting_opacity_Temp.Tag = 'Starting_opacity_Temp';
            app.Starting_opacity_Temp.FontSize = 10;
            app.Starting_opacity_Temp.Position = [35 53 49 17];
            app.Starting_opacity_Temp.Value = 1;

            % Create EasyTrials_Temp
            app.EasyTrials_Temp = uicheckbox(app.uipanel1_2);
            app.EasyTrials_Temp.Tag = 'EasyTrials_Temp';
            app.EasyTrials_Temp.Tooltip = 'Defines if easier trials should be shown or not';
            app.EasyTrials_Temp.Text = 'Easy %';
            app.EasyTrials_Temp.FontSize = 9;
            app.EasyTrials_Temp.Position = [102 50 53 22];

            % Create prob_list_Temp
            app.prob_list_Temp = uitextarea(app.uipanel1_2);
            app.prob_list_Temp.Tag = 'prob_list_Temp';
            app.prob_list_Temp.Position = [7 6 155 42];

            % Create uipanel3_2
            app.uipanel3_2 = uipanel(app.TemporaryTab);
            app.uipanel3_2.AutoResizeChildren = 'off';
            app.uipanel3_2.Title = 'Trial Intervals';
            app.uipanel3_2.Tag = 'uipanel3';
            app.uipanel3_2.FontSize = 10;
            app.uipanel3_2.Position = [199 17 147 305];

            % Create text8_2
            app.text8_2 = uilabel(app.uipanel3_2);
            app.text8_2.Tag = 'text8';
            app.text8_2.HorizontalAlignment = 'right';
            app.text8_2.FontSize = 10;
            app.text8_2.Position = [23 246 53 12];
            app.text8_2.Text = 'Penalty(s)';

            % Create text10_2
            app.text10_2 = uilabel(app.uipanel3_2);
            app.text10_2.Tag = 'text10';
            app.text10_2.HorizontalAlignment = 'right';
            app.text10_2.FontSize = 10;
            app.text10_2.Position = [23 225 53 12];
            app.text10_2.Text = 'Intertrial (s)';

            % Create EditField_5Label_3
            app.EditField_5Label_3 = uilabel(app.uipanel3_2);
            app.EditField_5Label_3.HorizontalAlignment = 'right';
            app.EditField_5Label_3.FontSize = 10;
            app.EditField_5Label_3.Tooltip = {'Hold the wheel still for this many seconds before a new trial starts. Timer will reset if the will is moved during this time.'};
            app.EditField_5Label_3.Position = [18 205 58 11];
            app.EditField_5Label_3.Text = 'Hold still (s):';

            % Create Repeat_wrong_Temp
            app.Repeat_wrong_Temp = uicheckbox(app.uipanel3_2);
            app.Repeat_wrong_Temp.Tag = 'Repeat_wrong_Temp';
            app.Repeat_wrong_Temp.Tooltip = 'repeat the same side if last one was wrong';
            app.Repeat_wrong_Temp.Text = 'repeat wrong';
            app.Repeat_wrong_Temp.FontSize = 10;
            app.Repeat_wrong_Temp.Position = [4 107 95 15];

            % Create Box_OCPulse_Temp
            app.Box_OCPulse_Temp = uieditfield(app.uipanel3_2, 'numeric');
            app.Box_OCPulse_Temp.Limits = [0 10];
            app.Box_OCPulse_Temp.Tag = 'Box_OCPulse_Temp';
            app.Box_OCPulse_Temp.FontSize = 10;
            app.Box_OCPulse_Temp.Tooltip = {'How many drops to give if using the Only Correct setting, where the mouse is able to answer correctly after a wrong choice.'};
            app.Box_OCPulse_Temp.Position = [89 118 25 22];
            app.Box_OCPulse_Temp.Value = 1;

            % Create OnlyCorrect_Temp
            app.OnlyCorrect_Temp = uicheckbox(app.uipanel3_2);
            app.OnlyCorrect_Temp.Tag = 'OnlyCorrect_Temp';
            app.OnlyCorrect_Temp.Text = 'Only Correct';
            app.OnlyCorrect_Temp.FontSize = 10;
            app.OnlyCorrect_Temp.Position = [5 119 78 22];

            % Create HoldStill_Temp
            app.HoldStill_Temp = uieditfield(app.uipanel3_2, 'numeric');
            app.HoldStill_Temp.Limits = [0 10];
            app.HoldStill_Temp.Tag = 'HoldStill_Temp';
            app.HoldStill_Temp.HorizontalAlignment = 'center';
            app.HoldStill_Temp.FontSize = 10;
            app.HoldStill_Temp.Tooltip = {'Hold the wheel still for this many seconds before a new trial starts. Timer will reset if the will is moved during this time.'};
            app.HoldStill_Temp.Position = [89 200 38 20];

            % Create Intertrial_time_Temp
            app.Intertrial_time_Temp = uieditfield(app.uipanel3_2, 'text');
            app.Intertrial_time_Temp.Tag = 'Intertrial_time_Temp';
            app.Intertrial_time_Temp.HorizontalAlignment = 'center';
            app.Intertrial_time_Temp.FontSize = 10;
            app.Intertrial_time_Temp.Tooltip = 'Interval between each trial in seconds';
            app.Intertrial_time_Temp.Position = [89 220 38 22];
            app.Intertrial_time_Temp.Value = '1';

            % Create Penalty_time_Temp
            app.Penalty_time_Temp = uieditfield(app.uipanel3_2, 'text');
            app.Penalty_time_Temp.Tag = 'Penalty_time_Temp';
            app.Penalty_time_Temp.HorizontalAlignment = 'center';
            app.Penalty_time_Temp.FontSize = 10;
            app.Penalty_time_Temp.Tooltip = 'penalty delay in seconds';
            app.Penalty_time_Temp.Position = [89 241 38 22];
            app.Penalty_time_Temp.Value = '1';

            % Create Pokes_ignored_time_Temp
            app.Pokes_ignored_time_Temp = uieditfield(app.uipanel3_2, 'text');
            app.Pokes_ignored_time_Temp.Tag = 'Pokes_ignored_time_Temp';
            app.Pokes_ignored_time_Temp.HorizontalAlignment = 'center';
            app.Pokes_ignored_time_Temp.FontSize = 10;
            app.Pokes_ignored_time_Temp.Tooltip = 'ignore all input for how many seconds after trial begin';
            app.Pokes_ignored_time_Temp.Position = [89 263 38 22];
            app.Pokes_ignored_time_Temp.Value = '2';

            % Create Input_ignored_Temp
            app.Input_ignored_Temp = uicheckbox(app.uipanel3_2);
            app.Input_ignored_Temp.Tag = 'Input_ignored_Temp';
            app.Input_ignored_Temp.Text = 'Input ignored';
            app.Input_ignored_Temp.FontSize = 10;
            app.Input_ignored_Temp.Position = [3 261 80 22];

            % Create InputControlPanel_2
            app.InputControlPanel_2 = uipanel(app.TemporaryTab);
            app.InputControlPanel_2.AutoResizeChildren = 'off';
            app.InputControlPanel_2.Title = 'Input Control';
            app.InputControlPanel_2.Position = [349 217 169 105];

            % Create IntertrialMalCancel_Temp
            app.IntertrialMalCancel_Temp = uicheckbox(app.InputControlPanel_2);
            app.IntertrialMalCancel_Temp.Tag = 'IntertrialMalCancel_Temp';
            app.IntertrialMalCancel_Temp.Tooltip = {'Check this box to end the current trial if the mouse pokes left or right when the ready cue is up. Only a center poke will start the next trial.'};
            app.IntertrialMalCancel_Temp.Text = 'Intertrial Mal';
            app.IntertrialMalCancel_Temp.FontSize = 10;
            app.IntertrialMalCancel_Temp.Position = [23 24 73 22];
            app.IntertrialMalCancel_Temp.Value = true;

            % Create IntertrialMalSec_Temp
            app.IntertrialMalSec_Temp = uieditfield(app.InputControlPanel_2, 'numeric');
            app.IntertrialMalSec_Temp.Tag = 'IntertrialMalSec_Temp';
            app.IntertrialMalSec_Temp.FontSize = 10;
            app.IntertrialMalSec_Temp.Tooltip = {'If the box is checked, a new trial will not begin until this many seconds after the mouse last poked Left or Right during the intertrial period. Once a new trial does begin, it will cancel if the mouse pokes anything but the center.'};
            app.IntertrialMalSec_Temp.Position = [102 24 44 22];
            app.IntertrialMalSec_Temp.Value = 1;

            % Create EditField_6Label_2
            app.EditField_6Label_2 = uilabel(app.InputControlPanel_2);
            app.EditField_6Label_2.HorizontalAlignment = 'right';
            app.EditField_6Label_2.FontSize = 10;
            app.EditField_6Label_2.Position = [22 55 78 22];
            app.EditField_6Label_2.Text = 'Hold Still Thresh';

            % Create Hold_Still_Thresh_Temp
            app.Hold_Still_Thresh_Temp = uieditfield(app.InputControlPanel_2, 'numeric');
            app.Hold_Still_Thresh_Temp.Limits = [0 500];
            app.Hold_Still_Thresh_Temp.Tag = 'Hold_Still_Thresh_Temp';
            app.Hold_Still_Thresh_Temp.FontSize = 10;
            app.Hold_Still_Thresh_Temp.Tooltip = {'Speed mouse must keep wheel under during "Hold Still" interval before trial.'};
            app.Hold_Still_Thresh_Temp.Position = [107 55 44 22];
            app.Hold_Still_Thresh_Temp.Value = 10;

            % Create ExpireAfterButtonGroup
            app.ExpireAfterButtonGroup = uibuttongroup(app.TemporaryTab);
            app.ExpireAfterButtonGroup.AutoResizeChildren = 'off';
            app.ExpireAfterButtonGroup.Title = 'Expire After';
            app.ExpireAfterButtonGroup.Position = [12 17 177 125];

            % Create TrialsRemainingLabel
            app.TrialsRemainingLabel = uilabel(app.ExpireAfterButtonGroup);
            app.TrialsRemainingLabel.FontSize = 10;
            app.TrialsRemainingLabel.Position = [11 5 162 34];
            app.TrialsRemainingLabel.Text = '_ Trials Remaining';

            % Create TrialCountThreshold_Temp
            app.TrialCountThreshold_Temp = uieditfield(app.ExpireAfterButtonGroup, 'numeric');
            app.TrialCountThreshold_Temp.Tag = 'TrialCountThreshold_Temp';
            app.TrialCountThreshold_Temp.FontSize = 10;
            app.TrialCountThreshold_Temp.Tooltip = {'After so many correct responses the accuracy must be above this percentage threshold for Temporary settings to end'};
            app.TrialCountThreshold_Temp.Position = [138 35 38 22];
            app.TrialCountThreshold_Temp.Value = 90;

            % Create TrialCount_Temp
            app.TrialCount_Temp = uieditfield(app.ExpireAfterButtonGroup, 'numeric');
            app.TrialCount_Temp.Tag = 'TrialCount_Temp';
            app.TrialCount_Temp.FontSize = 10;
            app.TrialCount_Temp.Position = [95 35 38 22];
            app.TrialCount_Temp.Value = 10;

            % Create PerfThresh_Temp
            app.PerfThresh_Temp = uieditfield(app.ExpireAfterButtonGroup, 'numeric');
            app.PerfThresh_Temp.Tag = 'PerfThresh_Temp';
            app.PerfThresh_Temp.FontSize = 10;
            app.PerfThresh_Temp.Position = [94 59 38 22];

            % Create TrialNumber_Temp
            app.TrialNumber_Temp = uiradiobutton(app.ExpireAfterButtonGroup);
            app.TrialNumber_Temp.Tag = 'TrialNumber_Temp';
            app.TrialNumber_Temp.Text = 'Correct Resp.';
            app.TrialNumber_Temp.FontSize = 10;
            app.TrialNumber_Temp.Position = [11 35 84 22];

            % Create PerformanceThreshold_Temp
            app.PerformanceThreshold_Temp = uiradiobutton(app.ExpireAfterButtonGroup);
            app.PerformanceThreshold_Temp.Tag = 'PerformanceThreshold_Temp';
            app.PerformanceThreshold_Temp.Tooltip = {'Temporary settings will persist until performance at Level 1 crosses the threshold'};
            app.PerformanceThreshold_Temp.Text = 'Performance';
            app.PerformanceThreshold_Temp.FontSize = 10;
            app.PerformanceThreshold_Temp.Position = [11 59 79 22];

            % Create TempOff_Temp
            app.TempOff_Temp = uiradiobutton(app.ExpireAfterButtonGroup);
            app.TempOff_Temp.Tag = 'TempOff_Temp';
            app.TempOff_Temp.Text = 'Off';
            app.TempOff_Temp.FontSize = 10;
            app.TempOff_Temp.Position = [11 80 35 22];
            app.TempOff_Temp.Value = true;

            % Create AutomaticDropWheelPanel
            app.AutomaticDropWheelPanel = uipanel(app.TemporaryTab);
            app.AutomaticDropWheelPanel.Title = 'Automatic Drop – Wheel';
            app.AutomaticDropWheelPanel.Position = [355 17 154 193];

            % Create Auto_Go
            app.Auto_Go = uibutton(app.AutomaticDropWheelPanel, 'state');
            app.Auto_Go.ValueChangedFcn = createCallbackFcn(app, @Auto_GoValueChanged, true);
            app.Auto_Go.Tag = 'Auto_Go';
            app.Auto_Go.Text = 'Go';
            app.Auto_Go.BackgroundColor = [0 1 0];
            app.Auto_Go.FontWeight = 'bold';
            app.Auto_Go.Position = [19 132 32 23];

            % Create FrequencyEditFieldLabel
            app.FrequencyEditFieldLabel = uilabel(app.AutomaticDropWheelPanel);
            app.FrequencyEditFieldLabel.HorizontalAlignment = 'right';
            app.FrequencyEditFieldLabel.Position = [11 97 61 22];
            app.FrequencyEditFieldLabel.Text = 'Frequency';

            % Create Auto_Freq
            app.Auto_Freq = uieditfield(app.AutomaticDropWheelPanel, 'numeric');
            app.Auto_Freq.Tag = 'Auto_Freq';
            app.Auto_Freq.Tooltip = {'Give a reward every _ seconds'};
            app.Auto_Freq.Position = [80 97 39 22];
            app.Auto_Freq.Value = 2;

            % Create Auto_Stop
            app.Auto_Stop = uibutton(app.AutomaticDropWheelPanel, 'state');
            app.Auto_Stop.Tag = 'Auto_Stop';
            app.Auto_Stop.Enable = 'off';
            app.Auto_Stop.Text = 'Stop';
            app.Auto_Stop.BackgroundColor = [1 0.4118 0.1608];
            app.Auto_Stop.FontWeight = 'bold';
            app.Auto_Stop.Position = [92 131 43 23];

            % Create Auto_Animate
            app.Auto_Animate = uicheckbox(app.AutomaticDropWheelPanel);
            app.Auto_Animate.Tag = 'Auto_Animate';
            app.Auto_Animate.Tooltip = {'Animate a Lv 1 stimulus moving across the screen to condition the mouse on what a correct trial looks like.'};
            app.Auto_Animate.Text = 'Animate';
            app.Auto_Animate.Position = [14 65 66 22];

            % Create Auto_Msg
            app.Auto_Msg = uilabel(app.AutomaticDropWheelPanel);
            app.Auto_Msg.Tag = 'Auto_Msg';
            app.Auto_Msg.VerticalAlignment = 'top';
            app.Auto_Msg.Position = [10 11 125 51];
            app.Auto_Msg.Text = '__ Rewards given';

            % Create AnimateStimulusPanel
            app.AnimateStimulusPanel = uipanel(app.TemporaryTab);
            app.AnimateStimulusPanel.Title = 'Animate Stimulus';
            app.AnimateStimulusPanel.Position = [531 7 343 314];

            % Create SideDropDownLabel
            app.SideDropDownLabel = uilabel(app.AnimateStimulusPanel);
            app.SideDropDownLabel.HorizontalAlignment = 'right';
            app.SideDropDownLabel.Position = [30 226 29 22];
            app.SideDropDownLabel.Text = 'Side';

            % Create Animate_Side
            app.Animate_Side = uidropdown(app.AnimateStimulusPanel);
            app.Animate_Side.Items = {'Left', 'Random', 'Right'};
            app.Animate_Side.Tag = 'Animate_Side';
            app.Animate_Side.Position = [74 226 79 22];
            app.Animate_Side.Value = 'Left';

            % Create Animate_Go
            app.Animate_Go = uibutton(app.AnimateStimulusPanel, 'state');
            app.Animate_Go.ValueChangedFcn = createCallbackFcn(app, @Animate_GoValueChanged, true);
            app.Animate_Go.Tag = 'Animate_Go';
            app.Animate_Go.Text = 'Go';
            app.Animate_Go.BackgroundColor = [0 1 0];
            app.Animate_Go.FontWeight = 'bold';
            app.Animate_Go.Position = [6 193 28 23];

            % Create Animate_End
            app.Animate_End = uibutton(app.AnimateStimulusPanel, 'state');
            app.Animate_End.Tag = 'Animate_End';
            app.Animate_End.Enable = 'off';
            app.Animate_End.Text = 'End';
            app.Animate_End.BackgroundColor = [1 0.4118 0.1608];
            app.Animate_End.FontWeight = 'bold';
            app.Animate_End.Position = [140 193 33 23];

            % Create SpeedEditFieldLabel
            app.SpeedEditFieldLabel = uilabel(app.AnimateStimulusPanel);
            app.SpeedEditFieldLabel.HorizontalAlignment = 'right';
            app.SpeedEditFieldLabel.Position = [4 159 40 22];
            app.SpeedEditFieldLabel.Text = 'Speed';

            % Create Animate_Speed
            app.Animate_Speed = uieditfield(app.AnimateStimulusPanel, 'numeric');
            app.Animate_Speed.Tag = 'Animate_Speed';
            app.Animate_Speed.Position = [53 159 35 22];
            app.Animate_Speed.Value = 0.01;

            % Create Animate_MimicTrial
            app.Animate_MimicTrial = uicheckbox(app.AnimateStimulusPanel);
            app.Animate_MimicTrial.Tag = 'Animate_MimicTrial';
            app.Animate_MimicTrial.Text = 'Mimic trial';
            app.Animate_MimicTrial.Position = [17 132 77 22];

            % Create XPositionLabel
            app.XPositionLabel = uilabel(app.AnimateStimulusPanel);
            app.XPositionLabel.HorizontalAlignment = 'right';
            app.XPositionLabel.FontSize = 10;
            app.XPositionLabel.Position = [66 103 51 22];
            app.XPositionLabel.Text = 'X-Position';

            % Create Animate_XPosition
            app.Animate_XPosition = uislider(app.AnimateStimulusPanel);
            app.Animate_XPosition.Limits = [0 1];
            app.Animate_XPosition.ValueChangedFcn = createCallbackFcn(app, @Animate_PositionValueChanged, true);
            app.Animate_XPosition.FontSize = 10;
            app.Animate_XPosition.Tag = 'Animate_XPosition';
            app.Animate_XPosition.Position = [12 101 158 3];

            % Create Animate_Show
            app.Animate_Show = uibutton(app.AnimateStimulusPanel, 'state');
            app.Animate_Show.ValueChangedFcn = createCallbackFcn(app, @Animate_ShowValueChanged, true);
            app.Animate_Show.Tag = 'Animate_Show';
            app.Animate_Show.Text = 'Show';
            app.Animate_Show.Position = [44 193 39 23];

            % Create StyleDropDownLabel
            app.StyleDropDownLabel = uilabel(app.AnimateStimulusPanel);
            app.StyleDropDownLabel.HorizontalAlignment = 'right';
            app.StyleDropDownLabel.Position = [33 259 32 22];
            app.StyleDropDownLabel.Text = 'Style';

            % Create Animate_Style
            app.Animate_Style = uidropdown(app.AnimateStimulusPanel);
            app.Animate_Style.Items = {'Y-Line', 'X-Line', 'Bar', 'Stimulus', 'Dot', 'Map-FlashContourX', 'Map-SweepLine', 'Map-LoomingStimulus'};
            app.Animate_Style.Tag = 'Animate_Style';
            app.Animate_Style.Position = [79 259 106 22];
            app.Animate_Style.Value = 'Y-Line';

            % Create YPositionSliderLabel
            app.YPositionSliderLabel = uilabel(app.AnimateStimulusPanel);
            app.YPositionSliderLabel.HorizontalAlignment = 'right';
            app.YPositionSliderLabel.FontSize = 10;
            app.YPositionSliderLabel.Position = [66 52 50 22];
            app.YPositionSliderLabel.Text = 'Y-Position';

            % Create Animate_YPosition
            app.Animate_YPosition = uislider(app.AnimateStimulusPanel);
            app.Animate_YPosition.Limits = [0 1];
            app.Animate_YPosition.ValueChangedFcn = createCallbackFcn(app, @Animate_PositionValueChanged, true);
            app.Animate_YPosition.FontSize = 10;
            app.Animate_YPosition.Tag = 'Animate_YPosition';
            app.Animate_YPosition.Position = [12 50 158 3];

            % Create Animate_Flash
            app.Animate_Flash = uibutton(app.AnimateStimulusPanel, 'state');
            app.Animate_Flash.ValueChangedFcn = createCallbackFcn(app, @Animate_FlashValueChanged, true);
            app.Animate_Flash.Tag = 'Animate_Flash';
            app.Animate_Flash.Text = 'Flash';
            app.Animate_Flash.Position = [93 193 37 23];

            % Create Animate_Rec
            app.Animate_Rec = uibutton(app.AnimateStimulusPanel, 'state');
            app.Animate_Rec.ValueChangedFcn = createCallbackFcn(app, @Animate_GoValueChanged, true);
            app.Animate_Rec.Tag = 'Animate_Rec';
            app.Animate_Rec.Text = 'Rec';
            app.Animate_Rec.BackgroundColor = [0 1 0];
            app.Animate_Rec.FontWeight = 'bold';
            app.Animate_Rec.FontColor = [1 1 1];
            app.Animate_Rec.Position = [117 157 39 23];

            % Create Animate_CenteredStimulus
            app.Animate_CenteredStimulus = uicheckbox(app.AnimateStimulusPanel);
            app.Animate_CenteredStimulus.Tag = 'Animate_CenteredStimulus';
            app.Animate_CenteredStimulus.Text = 'Centered Stimulus';
            app.Animate_CenteredStimulus.Position = [216 265 121 22];

            % Create Animate_AlternateSide
            app.Animate_AlternateSide = uicheckbox(app.AnimateStimulusPanel);
            app.Animate_AlternateSide.Tag = 'Animate_AlternateSide';
            app.Animate_AlternateSide.Text = 'Alternate Side';
            app.Animate_AlternateSide.Position = [216 244 98 22];

            % Create WhichStimulusButtonGroup
            app.WhichStimulusButtonGroup = uibuttongroup(app.AnimateStimulusPanel);
            app.WhichStimulusButtonGroup.Title = 'Which Stimulus';
            app.WhichStimulusButtonGroup.Position = [207 11 123 106];

            % Create Animate_OnlyIncorrectButton
            app.Animate_OnlyIncorrectButton = uiradiobutton(app.WhichStimulusButtonGroup);
            app.Animate_OnlyIncorrectButton.Tag = 'Animate_OnlyIncorrectButton';
            app.Animate_OnlyIncorrectButton.Text = 'Only Incorrect';
            app.Animate_OnlyIncorrectButton.Position = [11 60 97 22];
            app.Animate_OnlyIncorrectButton.Value = true;

            % Create Animate_BothButton
            app.Animate_BothButton = uiradiobutton(app.WhichStimulusButtonGroup);
            app.Animate_BothButton.Tag = 'Animate_BothButton';
            app.Animate_BothButton.Text = 'Both';
            app.Animate_BothButton.Position = [11 38 48 22];

            % Create Animate_OnlyCorrectButton
            app.Animate_OnlyCorrectButton = uiradiobutton(app.WhichStimulusButtonGroup);
            app.Animate_OnlyCorrectButton.Tag = 'Animate_OnlyCorrectButton';
            app.Animate_OnlyCorrectButton.Text = 'Only Correct';
            app.Animate_OnlyCorrectButton.Position = [11 16 90 22];

            % Create LineAngleEditFieldLabel
            app.LineAngleEditFieldLabel = uilabel(app.AnimateStimulusPanel);
            app.LineAngleEditFieldLabel.HorizontalAlignment = 'right';
            app.LineAngleEditFieldLabel.Position = [209 124 61 22];
            app.LineAngleEditFieldLabel.Text = 'Line Angle';

            % Create Animate_LineAngle
            app.Animate_LineAngle = uieditfield(app.AnimateStimulusPanel, 'numeric');
            app.Animate_LineAngle.Tag = 'Animate_LineAngle';
            app.Animate_LineAngle.Position = [279 124 44 22];

            % Create TimeDropDownLabel
            app.TimeDropDownLabel = uilabel(app.AnimateStimulusPanel);
            app.TimeDropDownLabel.HorizontalAlignment = 'right';
            app.TimeDropDownLabel.Position = [184 157 31 22];
            app.TimeDropDownLabel.Text = 'Time';

            % Create Timekeeper
            app.Timekeeper = uidropdown(app.AnimateStimulusPanel);
            app.Timekeeper.Tag = 'Timekeeper';
            app.Timekeeper.Position = [230 157 100 22];

            % Create NotesTab
            app.NotesTab = uitab(app.TabGroup);
            app.NotesTab.Tooltip = {'Write notes from today''s training session to be saved in the data file.'};
            app.NotesTab.Title = 'Notes';
            app.NotesTab.Tag = 'INO';

            % Create NotesText
            app.NotesText = uitextarea(app.NotesTab);
            app.NotesText.Tag = 'NotesText';
            app.NotesText.Tooltip = {'Write notes from today''s training session to be saved in the data file.'};
            app.NotesText.Position = [10 1 821 319];

            % Create OutputTab
            app.OutputTab = uitab(app.TabGroup);
            app.OutputTab.Title = 'Output';

            % Create MsgBox
            app.MsgBox = uitextarea(app.OutputTab);
            app.MsgBox.Tag = 'MsgBox';
            app.MsgBox.Position = [4 1 880 319];

            % Create PerformanceTab
            app.PerformanceTab = uitab(app.TabGroup);
            app.PerformanceTab.AutoResizeChildren = 'off';
            app.PerformanceTab.Title = 'Performance';
            app.PerformanceTab.Tag = 'PerfTab';

            % Create PerfGridLayout
            app.PerfGridLayout = uigridlayout(app.PerformanceTab);
            app.PerfGridLayout.ColumnWidth = {'1x'};
            app.PerfGridLayout.RowHeight = {'1x'};
            app.PerfGridLayout.Padding = [0 0 0 0];
            app.PerfGridLayout.Tag = 'PerfGridLayout';

            % Create PerfPanel
            app.PerfPanel = uipanel(app.PerfGridLayout);
            app.PerfPanel.Title = 'Performance';
            app.PerfPanel.Tag = 'PerfPanel';
            app.PerfPanel.Layout.Row = 1;
            app.PerfPanel.Layout.Column = 1;

            % Create TimersTab
            app.TimersTab = uitab(app.TabGroup);
            app.TimersTab.AutoResizeChildren = 'off';
            app.TimersTab.Title = 'Timers';

            % Create GridLayout9
            app.GridLayout9 = uigridlayout(app.TimersTab);
            app.GridLayout9.ColumnWidth = {'1x'};
            app.GridLayout9.RowHeight = {'1x'};
            app.GridLayout9.Padding = [0 0 0 0];
            app.GridLayout9.Tag = 'TimeGridLayout';

            % Create TimersPanel
            app.TimersPanel = uipanel(app.GridLayout9);
            app.TimersPanel.Title = 'Timers';
            app.TimersPanel.Tag = 'TimePanel';
            app.TimersPanel.Layout.Row = 1;
            app.TimersPanel.Layout.Column = 1;

            % Create AllTimeTab
            app.AllTimeTab = uitab(app.TabGroup);
            app.AllTimeTab.AutoResizeChildren = 'off';
            app.AllTimeTab.Title = 'All Time';

            % Create GridLayout5
            app.GridLayout5 = uigridlayout(app.AllTimeTab);
            app.GridLayout5.ColumnWidth = {'1x'};
            app.GridLayout5.RowHeight = {'1x'};
            app.GridLayout5.Padding = [0 0 0 0];

            % Create WeightWaterTab
            app.WeightWaterTab = uitab(app.TabGroup);
            app.WeightWaterTab.AutoResizeChildren = 'off';
            app.WeightWaterTab.Title = 'Weight/Water';

            % Create GridLayout6
            app.GridLayout6 = uigridlayout(app.WeightWaterTab);
            app.GridLayout6.ColumnWidth = {'1x'};
            app.GridLayout6.RowHeight = {'1x'};
            app.GridLayout6.Padding = [0 0 0 0];

            % Create HistoryPanel
            app.HistoryPanel = uipanel(app.GridLayout6);
            app.HistoryPanel.Title = 'History';
            app.HistoryPanel.Layout.Row = 1;
            app.HistoryPanel.Layout.Column = 1;

            % Create OtherUnusedTab
            app.OtherUnusedTab = uitab(app.TabGroup);
            app.OtherUnusedTab.AutoResizeChildren = 'off';
            app.OtherUnusedTab.Title = 'Other / Unused';

            % Create uipanel11
            app.uipanel11 = uipanel(app.OtherUnusedTab);
            app.uipanel11.AutoResizeChildren = 'off';
            app.uipanel11.Title = 'Orientation Tuning';
            app.uipanel11.Tag = 'uipanel11';
            app.uipanel11.FontSize = 11;
            app.uipanel11.Position = [4 251 510 68];

            % Create text79
            app.text79 = uilabel(app.uipanel11);
            app.text79.Tag = 'text79';
            app.text79.HorizontalAlignment = 'center';
            app.text79.VerticalAlignment = 'top';
            app.text79.FontSize = 11;
            app.text79.Position = [127 28 51 17];
            app.text79.Text = 'Repeats:';

            % Create text81
            app.text81 = uilabel(app.uipanel11);
            app.text81.Tag = 'text81';
            app.text81.HorizontalAlignment = 'center';
            app.text81.VerticalAlignment = 'top';
            app.text81.FontSize = 11;
            app.text81.Position = [175 28 51 17];
            app.text81.Text = 'Duration:';

            % Create text82
            app.text82 = uilabel(app.uipanel11);
            app.text82.Tag = 'text82';
            app.text82.HorizontalAlignment = 'center';
            app.text82.VerticalAlignment = 'top';
            app.text82.FontSize = 11;
            app.text82.Position = [271 28 64 17];
            app.text82.Text = 'Orientations:';

            % Create text83
            app.text83 = uilabel(app.uipanel11);
            app.text83.Tag = 'text83';
            app.text83.HorizontalAlignment = 'center';
            app.text83.VerticalAlignment = 'top';
            app.text83.FontSize = 11;
            app.text83.Position = [222 28 51 17];
            app.text83.Text = 'Interval:';

            % Create text84
            app.text84 = uilabel(app.uipanel11);
            app.text84.Tag = 'text84';
            app.text84.HorizontalAlignment = 'center';
            app.text84.VerticalAlignment = 'top';
            app.text84.FontSize = 11;
            app.text84.Position = [336 28 51 17];
            app.text84.Text = 'Bar size:';

            % Create text85
            app.text85 = uilabel(app.uipanel11);
            app.text85.Tag = 'text85';
            app.text85.HorizontalAlignment = 'center';
            app.text85.VerticalAlignment = 'top';
            app.text85.FontSize = 11;
            app.text85.Position = [388 28 62 17];
            app.text85.Text = 'Frequency:';

            % Create Orientation
            app.Orientation = uibutton(app.uipanel11, 'push');
            app.Orientation.ButtonPushedFcn = createCallbackFcn(app, @Orientation_Callback, true);
            app.Orientation.Tag = 'Orientation';
            app.Orientation.FontSize = 11;
            app.Orientation.Tooltip = 'show orientation tuning only (no input required)';
            app.Orientation.Position = [8 7 120 23];
            app.Orientation.Text = 'Orientation Tuning Only';

            % Create Ori_Repeats
            app.Ori_Repeats = uieditfield(app.uipanel11, 'text');
            app.Ori_Repeats.Tag = 'Ori_Repeats';
            app.Ori_Repeats.HorizontalAlignment = 'center';
            app.Ori_Repeats.FontSize = 11;
            app.Ori_Repeats.Tooltip = 'how many repeats of all orientations';
            app.Ori_Repeats.Position = [139 6 27 18];
            app.Ori_Repeats.Value = '2';

            % Create Ori_Duration
            app.Ori_Duration = uieditfield(app.uipanel11, 'text');
            app.Ori_Duration.Tag = 'Ori_Duration';
            app.Ori_Duration.HorizontalAlignment = 'center';
            app.Ori_Duration.FontSize = 11;
            app.Ori_Duration.Tooltip = 'how long to show each orientation';
            app.Ori_Duration.Position = [186 6 27 18];
            app.Ori_Duration.Value = '2';

            % Create Ori_Orientations
            app.Ori_Orientations = uidropdown(app.uipanel11);
            app.Ori_Orientations.Items = {'4', '8', '16'};
            app.Ori_Orientations.Tag = 'Ori_Orientations';
            app.Ori_Orientations.Tooltip = 'total number of equally spaced orientations';
            app.Ori_Orientations.FontSize = 11;
            app.Ori_Orientations.Position = [276 8 53 18];
            app.Ori_Orientations.Value = '8';

            % Create Ori_Interval
            app.Ori_Interval = uieditfield(app.uipanel11, 'text');
            app.Ori_Interval.Tag = 'Ori_Interval';
            app.Ori_Interval.HorizontalAlignment = 'center';
            app.Ori_Interval.FontSize = 11;
            app.Ori_Interval.Tooltip = 'interval between each orientation';
            app.Ori_Interval.Position = [233 6 27 18];
            app.Ori_Interval.Value = '2';

            % Create Ori_Random
            app.Ori_Random = uicheckbox(app.uipanel11);
            app.Ori_Random.Tag = 'Ori_Random';
            app.Ori_Random.Tooltip = 'randomize orientations';
            app.Ori_Random.Text = 'random';
            app.Ori_Random.FontSize = 11;
            app.Ori_Random.Position = [441 5 64 18];

            % Create Ori_Bar_Size
            app.Ori_Bar_Size = uieditfield(app.uipanel11, 'text');
            app.Ori_Bar_Size.Tag = 'Ori_Bar_Size';
            app.Ori_Bar_Size.HorizontalAlignment = 'center';
            app.Ori_Bar_Size.FontSize = 11;
            app.Ori_Bar_Size.Tooltip = 'size gratings';
            app.Ori_Bar_Size.Position = [342 5 27 18];
            app.Ori_Bar_Size.Value = '170';

            % Create Ori_Frequency
            app.Ori_Frequency = uieditfield(app.uipanel11, 'text');
            app.Ori_Frequency.Tag = 'Ori_Frequency';
            app.Ori_Frequency.HorizontalAlignment = 'center';
            app.Ori_Frequency.FontSize = 11;
            app.Ori_Frequency.Tooltip = 'temporal frequency of grating';
            app.Ori_Frequency.Position = [404 6 27 18];
            app.Ori_Frequency.Value = '0.5';

            % Create Stimulus_Orient
            app.Stimulus_Orient = uieditfield(app.uipanel11, 'text');
            app.Stimulus_Orient.Tag = 'Stimulus_Orient';
            app.Stimulus_Orient.HorizontalAlignment = 'center';
            app.Stimulus_Orient.FontSize = 11;
            app.Stimulus_Orient.Tooltip = {'Orientation of stimulus in degrees'};
            app.Stimulus_Orient.Position = [376 5 25 18];
            app.Stimulus_Orient.Value = '0';

            % Create Ext_trigger
            app.Ext_trigger = uicheckbox(app.OtherUnusedTab);
            app.Ext_trigger.Tag = 'Ext_trigger';
            app.Ext_trigger.Tooltip = 'start experiment by an external trigger';
            app.Ext_trigger.Text = 'ext trigger';
            app.Ext_trigger.Position = [565 294 75 22];

            % Create EquipmentPanel
            app.EquipmentPanel = uipanel(app.OtherUnusedTab);
            app.EquipmentPanel.AutoResizeChildren = 'off';
            app.EquipmentPanel.Title = 'Equipment';
            app.EquipmentPanel.Position = [695 65 185 251];

            % Create OpenL
            app.OpenL = uibutton(app.EquipmentPanel, 'state');
            app.OpenL.ValueChangedFcn = createCallbackFcn(app, @OpenLValueChanged, true);
            app.OpenL.Tag = 'OpenL';
            app.OpenL.Text = 'Open L';
            app.OpenL.Position = [11 200 100 23];

            % Create OpenR
            app.OpenR = uibutton(app.EquipmentPanel, 'state');
            app.OpenR.ValueChangedFcn = createCallbackFcn(app, @OpenRValueChanged, true);
            app.OpenR.Tag = 'OpenR';
            app.OpenR.Text = 'Open R';
            app.OpenR.Position = [12 168 100 23];

            % Create OpenBoth
            app.OpenBoth = uibutton(app.EquipmentPanel, 'state');
            app.OpenBoth.ValueChangedFcn = createCallbackFcn(app, @OpenBothValueChanged, true);
            app.OpenBoth.Tag = 'OpenBoth';
            app.OpenBoth.Text = 'Open Both';
            app.OpenBoth.Position = [9 135 100 23];

            % Create ResetAll
            app.ResetAll = uibutton(app.EquipmentPanel, 'state');
            app.ResetAll.ValueChangedFcn = createCallbackFcn(app, @RESETALLButtonPushed, true);
            app.ResetAll.Tag = 'ResetAll';
            app.ResetAll.Text = 'RESET ALL';
            app.ResetAll.Position = [10 101 100 23];

            % Create LoadCompButton
            app.LoadCompButton = uibutton(app.EquipmentPanel, 'push');
            app.LoadCompButton.ButtonPushedFcn = createCallbackFcn(app, @LoadCompButtonPushed, true);
            app.LoadCompButton.Tag = 'LoadCompButton';
            app.LoadCompButton.BackgroundColor = [0.8 0.8 0.8];
            app.LoadCompButton.FontSize = 10;
            app.LoadCompButton.Position = [11 73 123 18];
            app.LoadCompButton.Text = 'Load Computer Settings';

            % Create SaveCompButton
            app.SaveCompButton = uibutton(app.EquipmentPanel, 'push');
            app.SaveCompButton.ButtonPushedFcn = createCallbackFcn(app, @SaveCompButtonPushed, true);
            app.SaveCompButton.Tag = 'SaveCompButton';
            app.SaveCompButton.BackgroundColor = [0.3098 0.3098 0.3098];
            app.SaveCompButton.FontSize = 10;
            app.SaveCompButton.FontColor = [1 1 1];
            app.SaveCompButton.Position = [11 51 123 17];
            app.SaveCompButton.Text = 'Save Computer Settings';

            % Create Curtain
            app.Curtain = uibutton(app.EquipmentPanel, 'push');
            app.Curtain.ButtonPushedFcn = createCallbackFcn(app, @CurtainButtonPushed, true);
            app.Curtain.Tag = 'Curtain';
            app.Curtain.Icon = fullfile(pathToMLAPP, 'imgs', 'curtain.png');
            app.Curtain.Tooltip = {'Display a solid color, to use as a light'};
            app.Curtain.Position = [11 9 32 30];
            app.Curtain.Text = '';

            % Create VideoButton
            app.VideoButton = uibutton(app.EquipmentPanel, 'push');
            app.VideoButton.ButtonPushedFcn = createCallbackFcn(app, @VideoButtonPushed, true);
            app.VideoButton.Tag = 'VideoButton';
            app.VideoButton.Icon = fullfile(pathToMLAPP, 'imgs', 'video.png');
            app.VideoButton.Tooltip = {'Click to open up to 2 video feeds'};
            app.VideoButton.Position = [48 9 32 30];
            app.VideoButton.Text = '';

            % Create BaseButton
            app.BaseButton = uibutton(app.EquipmentPanel, 'push');
            app.BaseButton.ButtonPushedFcn = createCallbackFcn(app, @BaseButtonPushed, true);
            app.BaseButton.Tag = 'BaseButton';
            app.BaseButton.Position = [85 13 40 23];
            app.BaseButton.Text = 'Base';

            % Create ArduinosDropDownLabel
            app.ArduinosDropDownLabel = uilabel(app.OtherUnusedTab);
            app.ArduinosDropDownLabel.HorizontalAlignment = 'right';
            app.ArduinosDropDownLabel.Position = [504 193 64 22];
            app.ArduinosDropDownLabel.Text = 'Arduino(s):';

            % Create ArduinosDropDown
            app.ArduinosDropDown = uidropdown(app.OtherUnusedTab);
            app.ArduinosDropDown.Tag = 'ArduinosDropDown';
            app.ArduinosDropDown.Position = [583 193 100 22];

            % Create DataViewerTab
            app.DataViewerTab = uitab(app.TabGroup);
            app.DataViewerTab.Title = 'Data Viewer';
            app.DataViewerTab.Tag = 'Data';

            % Create GridLayout7
            app.GridLayout7 = uigridlayout(app.DataViewerTab);
            app.GridLayout7.ColumnWidth = {'1x'};
            app.GridLayout7.RowHeight = {55, '6x'};
            app.GridLayout7.ColumnSpacing = 0;

            % Create ControlsPanel
            app.ControlsPanel = uipanel(app.GridLayout7);
            app.ControlsPanel.Title = 'Controls';
            app.ControlsPanel.Layout.Row = 1;
            app.ControlsPanel.Layout.Column = 1;

            % Create GridLayout8
            app.GridLayout8 = uigridlayout(app.ControlsPanel);
            app.GridLayout8.ColumnWidth = {'fit', 'fit', 'fit', 250, 37, 'fit', 30, 'fit', 30};
            app.GridLayout8.RowHeight = {23};
            app.GridLayout8.Padding = [10 5 10 5];

            % Create Back_Data
            app.Back_Data = uibutton(app.GridLayout8, 'state');
            app.Back_Data.ValueChangedFcn = createCallbackFcn(app, @Plot_DataValueChanged, true);
            app.Back_Data.Tag = 'Back_Data';
            app.Back_Data.Text = 'Back';
            app.Back_Data.Layout.Row = 1;
            app.Back_Data.Layout.Column = 1;

            % Create Next_Data
            app.Next_Data = uibutton(app.GridLayout8, 'state');
            app.Next_Data.ValueChangedFcn = createCallbackFcn(app, @Plot_DataValueChanged, true);
            app.Next_Data.Tag = 'Next_Data';
            app.Next_Data.Text = 'Next';
            app.Next_Data.Layout.Row = 1;
            app.Next_Data.Layout.Column = 2;

            % Create FileDropDownLabel
            app.FileDropDownLabel = uilabel(app.GridLayout8);
            app.FileDropDownLabel.Tag = 'FileText';
            app.FileDropDownLabel.HorizontalAlignment = 'right';
            app.FileDropDownLabel.Layout.Row = 1;
            app.FileDropDownLabel.Layout.Column = 3;
            app.FileDropDownLabel.Text = 'File';

            % Create Files_Data
            app.Files_Data = uidropdown(app.GridLayout8);
            app.Files_Data.Tag = 'Files_Data';
            app.Files_Data.Layout.Row = 1;
            app.Files_Data.Layout.Column = 4;

            % Create SmallBinLabel
            app.SmallBinLabel = uilabel(app.GridLayout8);
            app.SmallBinLabel.Tag = 'SmallBinText';
            app.SmallBinLabel.Layout.Row = 1;
            app.SmallBinLabel.Layout.Column = 6;
            app.SmallBinLabel.Text = 'Small Bin';

            % Create SmallBin_Data
            app.SmallBin_Data = uieditfield(app.GridLayout8, 'numeric');
            app.SmallBin_Data.Tag = 'SmallBin_Data';
            app.SmallBin_Data.Layout.Row = 1;
            app.SmallBin_Data.Layout.Column = 7;

            % Create LargeBinLabel
            app.LargeBinLabel = uilabel(app.GridLayout8);
            app.LargeBinLabel.Tag = 'LargeBinText';
            app.LargeBinLabel.Layout.Row = 1;
            app.LargeBinLabel.Layout.Column = 8;
            app.LargeBinLabel.Text = 'Large Bin';

            % Create BigBin_Data
            app.BigBin_Data = uieditfield(app.GridLayout8, 'numeric');
            app.BigBin_Data.ValueChangedFcn = createCallbackFcn(app, @BigBin_DataValueChanged, true);
            app.BigBin_Data.Tag = 'BigBin_Data';
            app.BigBin_Data.Layout.Row = 1;
            app.BigBin_Data.Layout.Column = 9;

            % Create Plot_Data
            app.Plot_Data = uibutton(app.GridLayout8, 'state');
            app.Plot_Data.ValueChangedFcn = createCallbackFcn(app, @Plot_DataValueChanged, true);
            app.Plot_Data.Tag = 'Plot_Data';
            app.Plot_Data.IconAlignment = 'center';
            app.Plot_Data.Text = 'Plot';
            app.Plot_Data.BackgroundColor = [0.4941 0.1843 0.5569];
            app.Plot_Data.FontColor = [1 1 1];
            app.Plot_Data.Layout.Row = 1;
            app.Plot_Data.Layout.Column = 5;

            % Create PerfHistPanel_Data
            app.PerfHistPanel_Data = uipanel(app.GridLayout7);
            app.PerfHistPanel_Data.Title = 'Performance - History';
            app.PerfHistPanel_Data.Tag = 'PerfHistPanel_Data';
            app.PerfHistPanel_Data.Layout.Row = 2;
            app.PerfHistPanel_Data.Layout.Column = 1;

            % Create Git
            app.Git = uibutton(app.figure1, 'push');
            app.Git.ButtonPushedFcn = createCallbackFcn(app, @GitButtonPushed, true);
            app.Git.Tag = 'Git';
            app.Git.Icon = fullfile(pathToMLAPP, 'imgs', 'git.png');
            app.Git.WordWrap = 'on';
            app.Git.FontSize = 10;
            app.Git.Tooltip = {'Update this App by pulling from stable Git repo'};
            app.Git.Position = [509 369 32 30];
            app.Git.Text = '';

            % Create Folder
            app.Folder = uibutton(app.figure1, 'push');
            app.Folder.ButtonPushedFcn = createCallbackFcn(app, @FolderButtonPushed, true);
            app.Folder.Tag = 'Folder';
            app.Folder.Icon = fullfile(pathToMLAPP, 'imgs', 'folder.png');
            app.Folder.Tooltip = {'Open mouse''s folder to see files'};
            app.Folder.Position = [475 369 32 30];
            app.Folder.Text = '';

            % Create GraphPopOut
            app.GraphPopOut = uibutton(app.figure1, 'push');
            app.GraphPopOut.ButtonPushedFcn = createCallbackFcn(app, @GraphPopOutButtonPushed, true);
            app.GraphPopOut.Tag = 'GraphPopOut';
            app.GraphPopOut.Icon = fullfile(pathToMLAPP, 'imgs', 'popout.png');
            app.GraphPopOut.Tooltip = {'Pop out the All Time Graph'};
            app.GraphPopOut.Position = [438 369 32 30];
            app.GraphPopOut.Text = '';

            % Create GraphPopOut_2
            app.GraphPopOut_2 = uibutton(app.figure1, 'push');
            app.GraphPopOut_2.ButtonPushedFcn = createCallbackFcn(app, @GraphPopOut_2ButtonPushed, true);
            app.GraphPopOut_2.Tag = 'GraphPopOut_2';
            app.GraphPopOut_2.Icon = fullfile(pathToMLAPP, 'imgs', 'popout.png');
            app.GraphPopOut_2.Tooltip = {'Pop out Today''s Performance graph'};
            app.GraphPopOut_2.Position = [402 369 32 30];
            app.GraphPopOut_2.Text = '';

            % Show the figure after all components are created
            app.figure1.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = BehaviorBox_App(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.figure1)

            % Execute the startup function
            runStartupFcn(app, @(app)BehaviorBox_OpeningFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.figure1)
        end
    end
end
