classdef BehaviorBoxSub2 < BehaviorBoxSub1
    %BehaviorBox Sub class 2 (Visual grating) 
    %====================================================================
    %Sub Class 2 for BehaviorBox Ver1.4
    %This Class runs the Orientation tuning loop and is called by the GUI BehaviorBox via
    %RunOrientationTraining(). It will display several gratings as entered 
    %in the GUI using parameters such as speed, size,contrast, frequency etc.
    %It interacts with class BehaviorBoxVisualGratingObject.m to create the
    %visual stimuli.
    %This is class inherits BehaviorBoxSub1 from which it overrides some
    %functions with added functionality.
    %Meyer 2015/5
    %THIS FILE IS PART OF A SET OF FILES CONTAINING (ALL NEEDED):
    %BehaviorBox.fig
    %BehaviorBox.m
    %BehaviorBoxData.m
    %BehaviorBoxSub1.m
    %BehaviorBoxSub2.m
    %BehaviorBoxSuper.m
    %BehaviorBoxVisualGratingObject.m
    %BehaviorBoxVisualStimulus.m
    %BehaviorBoxVisualStimulusTraining.m
    %====================================================================
    properties
        %all inherited from BehaviorBoxSuper
    end
    
    
    methods
        
        %constructor
        function this = BehaviorBoxSub2(GUI_handles)
            %call the constructor of the super group to initiale supergroup
            this = this@BehaviorBoxSub1(GUI_handles);
        end
        
        
        function  RunOrientationTuning(this)
            %overwrite DoLoop from super class
            this.DoLoop();
        end
        
        
        %overrides super function DoLoop
        function DoLoop(this) %=====MAIN LOOP===========================
            disp('- - - - -');
            dbstop if error
            
            %local variables
            stop_handle = this.Setting_Struct(1,1).GuiHandles.pushbutton2;
            message_handle = this.Setting_Struct(1,1).GuiHandles.text1;
            
            GUI_handle = gcf; %current GUI handle for save
            
            
            %sound objects
            if this.Setting_Struct(1,1).Play_sound
                Sound_start_Object = audioplayer(this.Variable_Struct(1,1).soundstart, 48000);
                Sound_correct_Object = audioplayer(this.Variable_Struct(1,1).soundcorrect, 48000);
            else
                %make dummy paramenter
                Sound_start_Object = 1;
                Sound_correct_Object = 1;
            end
            
            
            %overwritten below
            this.SetupBeforeLoop();
            
            %create stimulus object array of different orientations (also
            %overwritten below)
            [Stimuluslist, stringliststimuli_return] = this.createListOfStimuli(this);
            dispstring = ['Stim order: ',stringliststimuli_return];
            
            %print stim order for record keeping
            disp(dispstring);
            
            Current_Stim_Object = [];
            
            
            %wait for trigger to start experiment if set
            if this.Setting_Struct(1,1).Ext_trigger
                
                set(this.Setting_Struct(1,1).GuiHandles.text1,'String','Waiting for trigger to start..', 'BackgroundColor','blue');
                
                while ~ this.Variable_Struct.a.readDigitalPin(this.Setting_Struct(1,1).TriggerPin)
                    %check if abort button is pressed
                    if this.checkAbort(stop_handle,this.Setting_Struct(1,1).GuiHandles.text1)==1
                        %abort
                        break;
                    end
                    pause(0.001);
                end
                set(this.Setting_Struct(1,1).GuiHandles.text1, 'BackgroundColor',[0.94 0.94 0.94]);
            end
            
            
            %run loop repeats (blocks)
            isLeftTrial = 1;
            for i_r = 1:this.Setting_Struct(1,1).Ori_Repeats
                
                isLeftTrial = ~isLeftTrial;
             
                %run loop orientations
                for i = 1:size(Stimuluslist,2)
                    
                    %pick the current orientation stimulus object
                    Current_Stim_Object = Stimuluslist(i);
                    
                    %add stim start event
                    this.Data_Object.addStimEvent(isLeftTrial);
                    
                    %present stimulus
                    Stimuluslist(i).showStimu(this.Setting_Struct(1,1).Ori_Duration);
                    
                    this.Data_Object.addStimEvent(-1);
                    
                    %check if stop pressed, and do not plot data if aborted
                    if this.checkAbort(stop_handle,message_handle)
                        %abort
                        break;
                    end
                    
                    %wait interval
                    pause(this.Setting_Struct(1,1).Ori_Interval);
                    
                end %END loop orientations
                
                
            end %END block loop
            
            
            
            %save when done
            this.SaveAllData(this, GUI_handle, stringliststimuli_return);
            
            %clean up
            this.cleanUp(Current_Stim_Object, Sound_start_Object);
            
        end %=====END OF MAIN LOOP===========================
        
        
        
        
        
        
        %MEMBER FUNCTIONS====
        
        function SetupBeforeLoop(this)
            
            %update gui
            this.setGuiNumbers(this.Setting_Struct(1,1).GuiHandles, this.Setting_Struct(1,1).GUI_numbers);
            this.clearAxes(this.Setting_Struct(1,1).GuiHandles);
            
            %print start time
            disp_string = ['Start orientation Mouse ',this.Setting_Struct(1,1).Animal_ID, ' at ',datestr(now)];
            disp(disp_string);
            
        end
    end
    
    
    %STATIC FUNCTIONS====
    
    methods (Static = true)
        
        function SaveAllData(this, GUI_handle, stringliststimuli_return)
            
            %generate Save name
            saveasname = [datestr(this.Data_Object.start_time,'yymmdd_HHMMSS_'),this.Setting_Struct(1,1).Animal_ID,'_',num2str(this.Setting_Struct(1,1).File_Extension),'_ORIENTATION_TUNING_FIG','.jpg'];
            
            %show all orientations used in menu, in case they were random
            set(this.Setting_Struct(1,1).GuiHandles.text1,'String', stringliststimuli_return);
            pause(0.001);
            
            %save GUI as image
            set(GUI_handle,'PaperPositionMode','auto');
            set(gcf,'InvertHardcopy','off');
            print ('-dbmp', '-r400', saveasname);
            dispstring = ['Image saved as: ',  ];
            disp(dispstring);
            
            %save stim on left (11), stif on right (1), stim off (-1)
            [x_allStim, y_StimOnOff] = this.Data_Object.GetStimOnOff();
            
            %only save if data
            if ~isempty(x_allStim)
                
                %fill length of vector to match for concatenation
                x_all(numel(x_allStim)) = 0;
                y_activityCorrectWrong(numel(x_allStim)) = 0;
                y_Difficulty(numel(x_allStim)) = 0;
                
                BehaviorData = [x_all;y_activityCorrectWrong;y_Difficulty;x_allStim;y_StimOnOff];
                saveasname = [datestr(this.Data_Object.start_time,'yymmdd_HHMMSS_'),this.Setting_Struct(1,1).Animal_ID,'_',num2str(this.Setting_Struct(1,1).File_Extension),'_','_xtime-act-diff-xtime-stimevents_ORIENTATION'];
                save(saveasname,'BehaviorData');
                dispstring = ['Data saved as: ', saveasname];
                disp(dispstring);
                
            end
            
            
            %if autoincrement
            if this.Setting_Struct(1,1).Increment_file
                this.Setting_Struct(1,1).File_Extension = this.Setting_Struct(1,1).File_Extension+1;
                set(this.Setting_Struct(1,1).GuiHandles.edit31,'String', num2str(this.Setting_Struct(1,1).File_Extension));
            end
            
        end
        
        
        
        
        function [Stimuluslist, stringliststimuli_return] = createListOfStimuli(this)
            
            %set parameters for grating
            CONTRAST = 1;
            PHASE = 0.25;
            
            
            %make list of orienatations
            switch this.Setting_Struct(1,1).Ori_Orientations
                
                %if 4 orienations (2x total, for looking at both directions)
                case 1
                    
                    Orientation_Array = [0, 45, 90, 135, 180, 225, 270, 315];
                    
                    %if 8 orienations
                case 2
                    
                    Orientation_Array = [0, 22, 45, 67, 90, 112, 135, 157, 180, 202, 225, 247, 270, 292, 315, 337];
                    
            end
            
            
            %if random
            if this.Setting_Struct(1,1).Ori_Random == 1
                z = randperm(size(Orientation_Array,2));
                Orientation_Array = Orientation_Array(z);
            end
            
            
            
            %add the stimulus conditions to array using above index
            Stimuluslist=BehaviorBoxVisualGratingObject(this.Setting_Struct(1,1).Stimulussize_x, this.Setting_Struct(1,1).Ori_Bar_Size, Orientation_Array(1), PHASE, CONTRAST, this.Setting_Struct(1,1).Ori_Frequency);
            
            %add others
            for ors = 2:size(Orientation_Array, 2)
                Stimuluslist(end+1)=BehaviorBoxVisualGratingObject(this.Setting_Struct(1,1).Stimulussize_x, this.Setting_Struct(1,1).Ori_Bar_Size, Orientation_Array(ors), PHASE, CONTRAST, this.Setting_Struct(1,1).Ori_Frequency);
                
            end
            
            
            %add all orientations into a string array for display
            stringliststimuli_return(length(Stimuluslist),1)=0;
            for i = 1 :  length(Stimuluslist)
                stringliststimuli_return(i)=Stimuluslist(i).thet;
            end
            
            stringliststimuli_return=mat2str(stringliststimuli_return);
            
            
        end
        
        
        
    end
end
