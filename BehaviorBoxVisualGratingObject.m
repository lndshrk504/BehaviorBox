classdef BehaviorBoxVisualGratingObject < handle
    %Display visual grating  
    %====================================================================
    %This Class is called by the class BehaviorBoxSub2 and creates one visual
    %gratings that get displayed on the screen. The parameters (size,
    %contrast, frequency etc are obtained from the GUI via BehaviorBoxSub2
    %and passed in here via the constructor. During the experiment several
    %of these objects are used with different parameters.
    %To display the grating on the screen, showStimu() is used.
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
    
%object variables 
%     properties(GetAccess = 'private', SetAccess = 'private')
     properties(GetAccess = 'public', SetAccess = 'public')
        %input parameters
        showing_now=0;
        size=400;
        lamd=10;
        thet=90;
        phas=0.25;
        contras=1;
        tempFre=0.5;
        %calculated parameters
        grating=0;
        phaseRad = 0;
        XYf = 0;
        freq = 0;
        %for garbor patch
        sigm=10;
        trim=0.005;
    end
    methods
        %Constructor
        function ConstructedOobject = BehaviorBoxVisualGratingObject(size_in, lamd_in, thet_in, phas_in, contrast_in, tempFre_in)
            ConstructedOobject.size=size_in;
            ConstructedOobject.lamd=lamd_in;
            ConstructedOobject.thet=thet_in;
            ConstructedOobject.phas=phas_in;
            ConstructedOobject.contras=contrast_in;
            ConstructedOobject.tempFre=tempFre_in;
            ConstructedOobject.showing_now = 0;
            generate_stimulus_parameters(ConstructedOobject);
        end
        %destructor
        function delete(ConstructedOobject)
            %disp('deleted');
        end
        %display on screen for the amount of seconds as parameter
        function showStimu(VisualGratingObject_in, lengthofshow)
            fig1=figure(100);
            %set window in position
            positionfig=[1 1 VisualGratingObject_in.size VisualGratingObject_in.size];
            set(fig1,'OuterPosition',positionfig)
            set(gca,'pos', [0 0 1 1]);               % remove borders from plot
            set(gcf, 'menu', 'none', 'Color',[.5 .5 .5]); % without background
            colormap gray(256);                     % use gray colormap (0: black, 1: white)
            axis off; axis image;    % use gray colormap
            %show grating
            tempFreUse=VisualGratingObject_in.tempFre./2.5;
            %move the grating
            starttime=clock;
            for t=1:tempFreUse:10000
                drawnow
                VisualGratingObject_in.grating = (sin( (VisualGratingObject_in.XYf+t) + VisualGratingObject_in.phaseRad))*VisualGratingObject_in.contras;
                fig1=imagesc( VisualGratingObject_in.grating, [-1 1] );
                pause (0.05)
                if etime(clock,starttime)>lengthofshow
                    break;
                end
            end
            %hide window 
            fig1=imagesc( VisualGratingObject_in.grating, [-100 1000] );
        end
        function generate_stimulus_parameters(VisualGratingObject_in)
            %create all parameters necessary to display stimulus
            X = 1:VisualGratingObject_in.size;                           % vis.X is a vector from 1 to imagevis.size
            X0 = (X / VisualGratingObject_in.size) - .5;                 % rescale vis.X -> -.5 to .5
            VisualGratingObject_in.freq = VisualGratingObject_in.size/VisualGratingObject_in.lamd;                    % compute frequency from wavelength
            [Xm Ym] = meshgrid(X0, X0);             % 2D matrices
            Xf = (Xm * VisualGratingObject_in.freq * 2*pi);
            thetaRad = ((VisualGratingObject_in.thet / 360) * 2*pi);        % convert theta (orientation) to radians
            Xt = Xm * cos(thetaRad);                % compute proportion of Xm for given orientation
            Yt = Ym * sin(thetaRad);                % compute proportion of Ym for given orientation
            XYt = [ Xt + Yt ];                      % sum vis.X and Y components
            %these are the stimulus parameters used to display and saved for each
            %object
            VisualGratingObject_in.grating = sin( Xf + VisualGratingObject_in.phaseRad);          % make 2D sinewave
            VisualGratingObject_in.phaseRad = (VisualGratingObject_in.phas * 2* pi);             % convert to radians: 0 -> 2*pi
            VisualGratingObject_in.XYf = XYt * VisualGratingObject_in.freq * 2*pi;                % convert to radians and scale by frequency
        end
    end
end

