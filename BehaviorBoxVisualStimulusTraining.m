classdef BehaviorBoxVisualStimulusTraining
    %Display training stimulus 
    %====================================================================
    %This Class is called by the class BehaviorBoxSuper and creates a
    %single stimulus for training purposes. The stimulus is made up of
    %aligned lined segments with no background.
    %It can creates 4 different stimuli (contour, contour training, patch
    %and square) depending on what is being trained and is set by what is
    %passed into the constructor.
    %It creates a line or shape of line of aligned elements (adapted from
    %Wu Li/T Van Kerkoerle). 
    %The parameters (size, contrast, coarseness etc are obtained from the
    %GUI via BehaviorBoxSub1 and passed in here via DisplayOnScreen(), which
    %also shows the stimulus on screen. 
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
    properties(GetAccess = 'public', SetAccess = 'private')
%         l=7; %width of each lines %defaul 19
%         segments=9; %number of segments of contoru 5
%         dx=1;% this is the inital starting offset for the first line in each colum
%         dy=4; %and each rows. Every other column gets shifted to form interleaved pattern
%         cy=5;  %y start position of contour, from bottom
%         cx=4;%x start position of countour, from right edge
%         transparenttrigger=1; % if this is 1, make bar transpartent
%         linesy=11; %how many lines in y 7
%         linesx=17;%how many lines in x 11
%         zoomfactor = 1;
        winheight;
        winwidth;
        winx;
        winy;
        SolidLine;
        Spotlight;
        SpotlightToggle;
        FinishLine
        BetweenSpotlight
        LineShade;
        Levertype;
        Background;
        SegLength;
        SegThick;
        SegSpacing;
        ContLength = 5; % number of segments in the target
        PatchSize=7; % size of patch, pick uneven
        BinSize=8; %size of bins
        SegmJitter=0.3;% jitter of segments
        numDistractorsTable = [0,0 ; 1,0 ; 3,2 ; 5,4 ; 9,7 ; 13,10 ; 19 , 14 ; 35,30]; %Distractor side is first item, target is second item
    end
    properties(SetAccess = 'public', GetAccess = 'public')
        trialID;
        show;
        opacity;
        StimulusType;
        isLeftTrial;
        isCorrect;
        Orient;
    end
    methods
        %constructor
        function this = BehaviorBoxVisualStimulusTraining(Setting_Struct)
            if(nargin > 0)
                %background opacity
                this.StimulusType = Setting_Struct.TrainingChoices; %DIFFERENT THAN NON TRAINING
                this.Levertype = Setting_Struct.Input_type;
                this.winheight = Setting_Struct.Stimulussize_y;
                this.winwidth = Setting_Struct.Stimulussize_x;
                this.winx = Setting_Struct.Stimulusposition_x;
                this.winy = Setting_Struct.Stimulusposition_y;
                this.SpotlightToggle = Setting_Struct.SpotlightToggle;
                this.Spotlight = [Setting_Struct.Spotlight Setting_Struct.Spotlight Setting_Struct.Spotlight];
                this.BetweenSpotlight = Setting_Struct.BetweenSpotlight;
                this.LineShade = [Setting_Struct.LineShade Setting_Struct.LineShade Setting_Struct.LineShade];
                this.Background = [Setting_Struct.Background Setting_Struct.Background Setting_Struct.Background];
                this.SegLength = Setting_Struct.SegLength;
                this.SegThick = Setting_Struct.SegThick;
                this.SegSpacing = Setting_Struct.SegSpacing;
                this.Orient = Setting_Struct.Orientation;
                this.FinishLine = Setting_Struct.FinishLine;
                this.SolidLine = Setting_Struct.SolidLine;
            end
        end
        %interface
        function DisplayOnScreen(this, isLeftTrial, opacity)
%             winheight = Setting_Struct.Stimulussize_y;
%             winwidth = Setting_Struct.Stimulussize_x;
%             winx = Setting_Struct.Stimulusposition_x;
%             winy = Setting_Struct.Stimulusposition_y;
%             SpotlightToggle = Setting_Struct.SpotlightToggle;
%             Spotlight = Setting_Struct.Spotlight;
%             LineShade = Setting_Struct.LineShade;
%             Background = Setting_Struct.Background;
%             SegLength = Setting_Struct.SegLength;
%             SegThick = Setting_Struct.SegThick;
%             SegSpacing = Setting_Struct.SegSpacing;
%             FinishLine = Setting_Struct.FinishLine;
            if isLeftTrial == 1
                this.trialID = 0;
                this.isLeftTrial = 1;
            else
                this.trialID = 1;
                this.isLeftTrial = 0;
            end
            this.opacity = int8(opacity*10);
            switch this.StimulusType
                case 1
                    if this.Levertype==1
                        ShowStimulusOnePatch(this, this.trialID, this.opacity, display,winheight,winwidth,winx,winy,0,orientation)
                    else
                        ShowStimulusContour(this.trialID, this.opacity,display,winheight,winwidth,winx,winy, 0,orientation);
                    end
                case 2
                    if this.Levertype==1
                        ShowStimulusOnePatch(this, this.trialID, this.opacity, display,winheight,winwidth,winx,winy,1,orientation)
                    else
                        ShowStimulusContour(this.trialID, this.opacity,display,winheight,winwidth,winx,winy, 1,orientation);
                    end
                case 3
                    ShowStimulusSquare(this.trialID, this.opacity,display,winheight,winwidth,winx,winy, 0,orientation);
                case 4
                    ShowStimulusSquare(this.trialID, this.opacity,display,winheight,winwidth,winx,winy, 1,orientation);
                case 5
                    ShowStimulusContourTraining(this.trialID, display, winheight, winwidth, winx, winy, SolidLine, Orientation, SpotlightToggle, Spotlight, LineShade, Background, this.Levertype, SegLength, SegThick, SegSpacing);
                case 6
                    ShowStimulusContourTrainingWheelEarly(this);
                case 7
                    ShowStimulusContourTrainingWheelLate(this.trialID, display, winheight, winwidth, winx, winy, SolidLine, Orientation, SpotlightToggle, Spotlight, LineShade, Background, this.Levertype, SegLength, SegThick, SegSpacing, FinishLine);
                case 8
                    ShowStimulusBBNoseTraining1Density(this)
                case 9
                    ShowStimulusBBNoseTraining3Density(this)
                case 10
                    ShowStimulusBBNoseTraining3Density(this)
                case 11
                    ShowStimulusBBNoseTraining4Density(this)
            end
            positionfig=[this.winx this.winy this.winwidth this.winheight];
            set(groot,'CurrentFigure',100)
            set(gcf,'OuterPosition',positionfig); %move window here, also determines size
        end
    end
end
%display square stimulus
function ShowStimulusSquare(trialID, opacity, display, winheight,winwidth,winx,winy,crudetoggle,Orient)
fig1=figure(100);
%show yes or no
if display==1
    if crudetoggle==0
        %fine
        ContLength=3; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=11; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        this.SegLength=1.2; %length of sements
        BinSize=2; %size of bins
        this.SegThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    else
        %crude
        ContLength=3; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=9; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        this.SegLength=1.2; %length of sements
        BinSize=2; %size of bins
        this.SegThick=9; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    end
    Alpha=-25; %determines closeness of contour elements, set somewhere between [-30 30]
    %see Li & Gilbert 2002
    Alpha=(90+Alpha)/90;
    SegmX=zeros(2,PatchSize,PatchSize);
    SegmY=zeros(2,PatchSize,PatchSize);
    % make grid
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=i*BinSize;
            SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=j*BinSize;
        end
    end
    % turn grid around crossing with y-axis
    [SegmTheta,SegmRho] = cart2pol(zeros(2,PatchSize,PatchSize),SegmY);
    SegmTheta(SegmTheta>0)=SegmTheta(SegmTheta>0)/Alpha;
    SegmTheta(SegmTheta<0)=((SegmTheta(SegmTheta<0)+pi)/Alpha)-pi;
    [SegmXA,SegmY] = pol2cart(SegmTheta,SegmRho);
    SegmX=SegmX+SegmXA;
    % Draw background with the grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            angle=rand*180;
            if i==j  & i>-ContLengthHalf &i<ContLengthHalf %for contour segments (take center colum and then go along that)
                angle=45;
                X=[-this.SegLength*0.1 this.SegLength*0.9];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j-1  & i>-ContLengthHalf &i<ContLengthHalf %for contour segments (take center colum and then go along that)
                angle=45;
                X=[-this.SegLength*0.85 this.SegLength*0.15];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j+1  & i>-ContLengthHalf+1 &i<ContLengthHalf+1 %for contour segments (take center colum and then go along that)
                angle=45;
                % X=[-(this.SegLength*0.4)+this.SegLength (this.SegLength*0.6)+this.SegLength];
                X=[-(this.SegLength*0.8) (this.SegLength*0.2)];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-this.SegLength/2 this.SegLength/2]+JX;
                Y=[0 0]-JY;
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi;
                [X,Y] = pol2cart(Theta,Rho);
            end
            SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+X';
            SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+Y';
        end
    end
    %plot all line segments
    if trialID==1
        figu=subplot(1,2,2);
    else
        subplot(1,2,1);
    end
    set(gca,'color','black')
    set(gcf,'color','black')
    hold on;
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end
    hold on
    % Draw segments grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            if i==j  & i>-ContLengthHalf &i<ContLengthHalf & i~=ContLengthHalf %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick)
            elseif i==j-1  & i>-ContLengthHalf &i<ContLengthHalf %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick)
            elseif i==j+1  & i>-ContLengthHalf+1 &i<ContLengthHalf+1 %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick)
            end
        end
    end
    hold off
    %plot mask, upper and lower part separate
    NumPoints=100;
    Radius=(PatchSizeHalf-2)*BinSize;
    Theta=linspace(0,pi,NumPoints); %100 evenly spaced points between 0 and pi
    Rho=ones(1,NumPoints)*Radius; %Radius should be 1 for all 100 points
    [X,Y] = pol2cart(Theta,Rho);
    X(101)=-PatchSize*2;
    Y(101)=0;
    X(102)=-PatchSize*2;
    Y(102)=PatchSize*2;
    X(103)=PatchSize*2;
    Y(103)=PatchSize*2;
    X(104)=PatchSize*2;
    Y(104)=0;
    patch(X,Y,'k');
    Theta=linspace(0,-pi,NumPoints); %100 evenly spaced points between 0 and -pi
    [X,Y] = pol2cart(Theta,Rho);
    X(101)=-PatchSize*2;
    Y(101)=0;
    X(102)=-PatchSize*2;
    Y(102)=-PatchSize*2;
    X(103)=PatchSize*2;
    Y(103)=-PatchSize*2;
    X(104)=PatchSize*2;
    Y(104)=0;
    patch(X,Y,'k');
    axis tight; axis square
    view(-Orient/Alpha,90)
    xlim([-Radius*0.8 Radius*0.8])
    ylim([-Radius*0.8 Radius*0.8])
    % print -dbmp LiStim1
    % SECOND PART OF FOGURE%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    hold on
    % make grid
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=i*BinSize;
            SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=j*BinSize;
        end
    end
    % turn grid around crossing with y-axis
    [SegmTheta,SegmRho] = cart2pol(zeros(2,PatchSize,PatchSize),SegmY);
    SegmTheta(SegmTheta>0)=SegmTheta(SegmTheta>0)/Alpha;
    SegmTheta(SegmTheta<0)=((SegmTheta(SegmTheta<0)+pi)/Alpha)-pi;
    [SegmXA,SegmY] = pol2cart(SegmTheta,SegmRho);
    SegmX=SegmX+SegmXA;
    % Draw background with the grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            angle=rand*180;
            if i==j  & i>-ContLengthHalf &i<ContLengthHalf & i  %for contour segments (take center colum and then go along that)
                angle=45;
                X=[-this.SegLength*0.1 this.SegLength*0.9];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif  i==j  & i>-ContLengthHalf &i<ContLengthHalf %make sure the center of O is not randomly filling patch (avoid 45)
                angle=rand*155+75;
                JX=SegmJitter*2*(rand-0.7); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.4);
                X=[-this.SegLength*0.1 this.SegLength*0.9]+JX-0.17;
                Y=[0 0]-JY-0.4;
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j-1  & i>-ContLengthHalf &i<ContLengthHalf %for contour segments (take center colum and then go along that)
                angle=45;
                X=[-this.SegLength*0.85 this.SegLength*0.15];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j+1  & i>-ContLengthHalf+1 &i<ContLengthHalf+1 %for contour segments (take center colum and then go along that)
                angle=45;
                % X=[-(this.SegLength*0.4)+this.SegLength (this.SegLength*0.6)+this.SegLength];
                X=[-(this.SegLength*0.8) (this.SegLength*0.2)];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-this.SegLength/2 this.SegLength/2]+JX;
                Y=[0 0]-JY;
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi;
                [X,Y] = pol2cart(Theta,Rho);
            end
            SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+X';
            SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+Y';
        end
    end
    %plot all line segments
    if trialID==1
        figu=subplot(1,2,1);
    else
        subplot(1,2,2);
    end
    set(gca,'color','black')
    set(gcf,'color','black')
    hold on;
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end
    hold on
    % Draw segments grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            if i==j  & i>-ContLengthHalf &i<ContLengthHalf & i~=ContLengthHalf & i~=0%for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick)
            elseif i==j-1  & i>-ContLengthHalf &i<ContLengthHalf %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick)
            elseif i==j+1  & i>-ContLengthHalf+1 &i<ContLengthHalf+1 %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick)
            end
        end
    end
    hold off
    %plot mask, upper and lower part separate
    NumPoints=100;
    Radius=(PatchSizeHalf-2)*BinSize;
    Theta=linspace(0,pi,NumPoints); %100 evenly spaced points between 0 and pi
    Rho=ones(1,NumPoints)*Radius; %Radius should be 1 for all 100 points
    [X,Y] = pol2cart(Theta,Rho);
    X(101)=-PatchSize*2;
    Y(101)=0;
    X(102)=-PatchSize*2;
    Y(102)=PatchSize*2;
    X(103)=PatchSize*2;
    Y(103)=PatchSize*2;
    X(104)=PatchSize*2;
    Y(104)=0;
    patch(X,Y,'k');
    Theta=linspace(0,-pi,NumPoints); %100 evenly spaced points between 0 and -pi
    [X,Y] = pol2cart(Theta,Rho);
    X(101)=-PatchSize*2;
    Y(101)=0;
    X(102)=-PatchSize*2;
    Y(102)=-PatchSize*2;
    X(103)=PatchSize*2;
    Y(103)=-PatchSize*2;
    X(104)=PatchSize*2;
    Y(104)=0;
    patch(X,Y,'k');
    axis tight; axis square
    view(-Orient/Alpha,90)
    xlim([-Radius*0.8 Radius*0.8])
    ylim([-Radius*0.8 Radius*0.8])
    pause(0.001);
    positionfig=[winx winy winwidth winheight];
    set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
else
    close(fig1);
end
end
%display contour stimulus
function ShowStimulusContour(trialID, opacity, display, winheight,winwidth,winx,winy,crudetoggle,Orient)
fig1=figure(100);
if display==1
    if crudetoggle==0
        %fine
        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=9; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        this.SegLength=1.2; %length of sements
        BinSize=2; %size of bins
        this.SegThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    else
        %crude
        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=11; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        this.SegLength=1.2; %length of sements
        BinSize=2; %size of bins
        this.SegThick=9; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    end
    Alpha=-25; %determines closeness of contour elements, set somewhere between [-30 30]
    %see Li & Gilbert 2002
    Alpha=(90+Alpha)/90;
    SegmX=zeros(2,PatchSize,PatchSize);
    SegmY=zeros(2,PatchSize,PatchSize);
    % make grid
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=i*BinSize;
            SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=j*BinSize;
        end
    end
    % turn grid around crossing with y-axis
    [SegmTheta,SegmRho] = cart2pol(zeros(2,PatchSize,PatchSize),SegmY);
    SegmTheta(SegmTheta>0)=SegmTheta(SegmTheta>0)/Alpha;
    SegmTheta(SegmTheta<0)=((SegmTheta(SegmTheta<0)+pi)/Alpha)-pi;
    [SegmXA,SegmY] = pol2cart(SegmTheta,SegmRho);
    SegmX=SegmX+SegmXA;
    % Draw background with the grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            angle=rand*180;
            if i==j & i>-ContLengthHalf &i<ContLengthHalf %for contour segments
                angle=45;
                X=[-this.SegLength/2 this.SegLength/2];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-this.SegLength/2 this.SegLength/2]+JX;
                Y=[0 0]-JY;
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi;
                [X,Y] = pol2cart(Theta,Rho);
            end
            SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+X';
            SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+Y';
        end
    end
    %plot all line segments
    if trialID==1
        figu=subplot(1,2,2);
    else
        subplot(1,2,1);
    end
    set(gca,'color','black')
    set(gcf,'color','black')
    hold on;
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end
    hold on
    % Draw segments grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            if i==j & i>-ContLengthHalf &i<ContLengthHalf %for contour segments
                angle=45;
                X=[-this.SegLength/2 this.SegLength/2];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick)
            end
        end
    end
    hold off
    %plot mask, upper and lower part separate
    NumPoints=100;
    Radius=(PatchSizeHalf-2)*BinSize;
    Theta=linspace(0,pi,NumPoints); %100 evenly spaced points between 0 and pi
    Rho=ones(1,NumPoints)*Radius; %Radius should be 1 for all 100 points
    [X,Y] = pol2cart(Theta,Rho);
    X(101)=-PatchSize*2;
    Y(101)=0;
    X(102)=-PatchSize*2;
    Y(102)=PatchSize*2;
    X(103)=PatchSize*2;
    Y(103)=PatchSize*2;
    X(104)=PatchSize*2;
    Y(104)=0;
    patch(X,Y,'k');
    Theta=linspace(0,-pi,NumPoints); %100 evenly spaced points between 0 and -pi
    [X,Y] = pol2cart(Theta,Rho);
    X(101)=-PatchSize*2;
    Y(101)=0;
    X(102)=-PatchSize*2;
    Y(102)=-PatchSize*2;
    X(103)=PatchSize*2;
    Y(103)=-PatchSize*2;
    X(104)=PatchSize*2;
    Y(104)=0;
    patch(X,Y,'k');
    axis tight; axis square
    view(-Orient/Alpha,90)
    xlim([-Radius*0.8 Radius*0.8])
    ylim([-Radius*0.8 Radius*0.8])
    % print -dbmp LiStim1
    % SECOND PART OF FOGURE%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    hold on
    % make grid
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=i*BinSize;
            SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=j*BinSize;
        end
    end
    % turn grid around crossing with y-axis
    [SegmTheta,SegmRho] = cart2pol(zeros(2,PatchSize,PatchSize),SegmY);
    SegmTheta(SegmTheta>0)=SegmTheta(SegmTheta>0)/Alpha;
    SegmTheta(SegmTheta<0)=((SegmTheta(SegmTheta<0)+pi)/Alpha)-pi;
    [SegmXA,SegmY] = pol2cart(SegmTheta,SegmRho);
    SegmX=SegmX+SegmXA;
    % Draw background with the grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            angle=rand*180;
            JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
            JY=SegmJitter*2*(rand-0.5);
            X=[-this.SegLength/2 this.SegLength/2]+JX;
            Y=[0 0]-JY;
            [Theta,Rho] = cart2pol(X,Y);
            Theta=Theta+angle/180*pi;
            [X,Y] = pol2cart(Theta,Rho);
            SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+X';
            SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+Y';
        end
    end
    %plot all line segments
    if trialID==1
        subplot(1,2,1);
    else
        subplot(1,2,2);
    end
    set(gca,'color','black')
    set(gcf,'color','black')
    hold on;
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end
    hold on
    hold off
    %plot mask, upper and lower part separate
    NumPoints=100;
    Radius=(PatchSizeHalf-2)*BinSize;
    Theta=linspace(0,pi,NumPoints); %100 evenly spaced points between 0 and pi
    Rho=ones(1,NumPoints)*Radius; %Radius should be 1 for all 100 points
    [X,Y] = pol2cart(Theta,Rho);
    X(101)=-PatchSize*2;
    Y(101)=0;
    X(102)=-PatchSize*2;
    Y(102)=PatchSize*2;
    X(103)=PatchSize*2;
    Y(103)=PatchSize*2;
    X(104)=PatchSize*2;
    Y(104)=0;
    patch(X,Y,'k');
    Theta=linspace(0,-pi,NumPoints); %100 evenly spaced points between 0 and -pi
    [X,Y] = pol2cart(Theta,Rho);
    X(101)=-PatchSize*2;
    Y(101)=0;
    X(102)=-PatchSize*2;
    Y(102)=-PatchSize*2;
    X(103)=PatchSize*2;
    Y(103)=-PatchSize*2;
    X(104)=PatchSize*2;
    Y(104)=0;
    patch(X,Y,'k');
    hold off
    axis tight; axis square
    view(-Orient+45/Alpha,90)
    xlim([-Radius*0.8 Radius*0.8])
    ylim([-Radius*0.8 Radius*0.8])
    set(gcf,'MenuBar','none');
    positionfig=[winx winy winwidth winheight];
    %positionfig=[1600 50 500 450];
    set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
    %notusedyet=borderwidth;
else
    close(fig1);
end
end
%display contour stimulus
function ShowStimulusContourDistractor(trialID, opacity, display, winheight,winwidth,winx,winy,crudetoggle,Orient)
fig1=figure(100);
if display==1
    if crudetoggle==0
        %fine
        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=9; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        this.SegLength=1.2; %length of sements
        BinSize=2; %size of bins
        this.SegThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    else
        %crude
        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=11; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        this.SegLength=1.2; %length of sements
        BinSize=2; %size of bins
        this.SegThick=9; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    end
    Alpha=-25; %determines closeness of contour elements, set somewhere between [-30 30]
    %see Li & Gilbert 2002
    Alpha=(90+Alpha)/90;
    SegmX=zeros(2,PatchSize,PatchSize);
    SegmY=zeros(2,PatchSize,PatchSize);
    % make grid
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=i*BinSize;
            SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=j*BinSize;
        end
    end
    % turn grid around crossing with y-axis
    [SegmTheta,SegmRho] = cart2pol(zeros(2,PatchSize,PatchSize),SegmY);
    SegmTheta(SegmTheta>0)=SegmTheta(SegmTheta>0)/Alpha;
    SegmTheta(SegmTheta<0)=((SegmTheta(SegmTheta<0)+pi)/Alpha)-pi;
    [SegmXA,SegmY] = pol2cart(SegmTheta,SegmRho);
    SegmX=SegmX+SegmXA;
    % Draw background with the grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            angle=rand*180;
            if i==j & i>-ContLengthHalf &i<ContLengthHalf %for contour segments
                angle=45;
                X=[-this.SegLength/2 this.SegLength/2];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-this.SegLength/2 this.SegLength/2]+JX;
                Y=[0 0]-JY;
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi;
                [X,Y] = pol2cart(Theta,Rho);
            end
            SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+X';
            SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+Y';
        end
    end
    %plot all line segments
    if trialID==1
        figu=subplot(1,2,2);
    else
        subplot(1,2,1);
    end
    set(gca,'color','black')
    set(gcf,'color','black')
    hold on;
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
             if  floor(rand*11) < opacity
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick,'Color',[1*opacity 1*opacity 1*opacity])
             end
             end
    end
    hold on
    % Draw segments grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            if i==j & i>-ContLengthHalf &i<ContLengthHalf %for contour segments
                angle=45;
                X=[-this.SegLength/2 this.SegLength/2];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick)
            end
        end
    end
    hold off
    %plot mask, upper and lower part separate
    NumPoints=100;
    Radius=(PatchSizeHalf-2)*BinSize;
    Theta=linspace(0,pi,NumPoints); %100 evenly spaced points between 0 and pi
    Rho=ones(1,NumPoints)*Radius; %Radius should be 1 for all 100 points
    [X,Y] = pol2cart(Theta,Rho);
    X(101)=-PatchSize*2;
    Y(101)=0;
    X(102)=-PatchSize*2;
    Y(102)=PatchSize*2;
    X(103)=PatchSize*2;
    Y(103)=PatchSize*2;
    X(104)=PatchSize*2;
    Y(104)=0;
    patch(X,Y,'k');
    Theta=linspace(0,-pi,NumPoints); %100 evenly spaced points between 0 and -pi
    [X,Y] = pol2cart(Theta,Rho);
    X(101)=-PatchSize*2;
    Y(101)=0;
    X(102)=-PatchSize*2;
    Y(102)=-PatchSize*2;
    X(103)=PatchSize*2;
    Y(103)=-PatchSize*2;
    X(104)=PatchSize*2;
    Y(104)=0;
    patch(X,Y,'k');
    axis tight; axis square
    view(-Orient/Alpha,90)
    xlim([-Radius*0.8 Radius*0.8])
    ylim([-Radius*0.8 Radius*0.8])
    % print -dbmp LiStim1
    % SECOND PART OF FOGURE%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    hold on
    % make grid
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=i*BinSize;
            SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=j*BinSize;
        end
    end
    % turn grid around crossing with y-axis
    [SegmTheta,SegmRho] = cart2pol(zeros(2,PatchSize,PatchSize),SegmY);
    SegmTheta(SegmTheta>0)=SegmTheta(SegmTheta>0)/Alpha;
    SegmTheta(SegmTheta<0)=((SegmTheta(SegmTheta<0)+pi)/Alpha)-pi;
    [SegmXA,SegmY] = pol2cart(SegmTheta,SegmRho);
    SegmX=SegmX+SegmXA;
    % Draw background with the grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            angle=rand*180;
            JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
            JY=SegmJitter*2*(rand-0.5);
            X=[-this.SegLength/2 this.SegLength/2]+JX;
            Y=[0 0]-JY;
            [Theta,Rho] = cart2pol(X,Y);
            Theta=Theta+angle/180*pi;
            [X,Y] = pol2cart(Theta,Rho);
            
            SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+X';
            SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+Y';
        end
    end
    %plot all line segments
    if trialID==1
        subplot(1,2,1);
    else
        subplot(1,2,2);
    end
    set(gca,'color','black')
    set(gcf,'color','black')
    hold on;
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
             if  floor(rand*11) < opacity
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick,'Color',[1*opacity 1*opacity 1*opacity])
             end
        end
    end
    hold on
    hold off
    %plot mask, upper and lower part separate
    NumPoints=100;
    Radius=(PatchSizeHalf-2)*BinSize;
    Theta=linspace(0,pi,NumPoints); %100 evenly spaced points between 0 and pi
    Rho=ones(1,NumPoints)*Radius; %Radius should be 1 for all 100 points
    [X,Y] = pol2cart(Theta,Rho);
    X(101)=-PatchSize*2;
    Y(101)=0;
    X(102)=-PatchSize*2;
    Y(102)=PatchSize*2;
    X(103)=PatchSize*2;
    Y(103)=PatchSize*2;
    X(104)=PatchSize*2;
    Y(104)=0;
    patch(X,Y,'k');
    Theta=linspace(0,-pi,NumPoints); %100 evenly spaced points between 0 and -pi
    [X,Y] = pol2cart(Theta,Rho);
    X(101)=-PatchSize*2;
    Y(101)=0;
    X(102)=-PatchSize*2;
    Y(102)=-PatchSize*2;
    X(103)=PatchSize*2;
    Y(103)=-PatchSize*2;
    X(104)=PatchSize*2;
    Y(104)=0;
    patch(X,Y,'k');
    hold off
    axis tight; axis square
    view(-Orient+45/Alpha,90)
    xlim([-Radius*0.8 Radius*0.8])
    ylim([-Radius*0.8 Radius*0.8])
    set(gcf,'MenuBar','none');
    positionfig=[winx winy winwidth winheight];
    %positionfig=[1600 50 500 450];
    set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
    %notusedyet=borderwidth;
else
    close(fig1);
end
end
%display training stimulus
function ShowStimulusContourTraining(trialID, display, winheight, winwidth, winx, winy, SolidLine, Orient, SpotlightToggle, Spotlight, LineShade, Background, Levertype, SegLength, SegThick, SegSpacing)
    first = 1; %The right side is always plotted first. %trialID is if the stimulus is to be on the left
    %Distractor side is first item, target is second item
    numDistractorsTable = [0,0 ; 1,0 ; 3,2 ; 5,4 ; 9,7 ; 13,10 ; 19 , 14 ; 35,30];
    patchScale = 1.5; % This number sets the size of the patch on the screen by making the axis patchSacle * radius
    % segments density
    set(groot,'CurrentFigure',100)
    %fig1=figure(100);
    clf
    hold on
    set(gcf,'MenuBar','none');
    if this.Levertype == 7 % Go/No-Go task, so only one image is shown at a time
        if display==1
            if SolidLine==0
                %fine
                ContLength = 5; % number of segments in the target
                PatchSize=7; % size of patch, pick uneven
                this.SegLength=SegLength; %length of segments
                BinSize=8; %size of bins
                this.SegThick=SegThick; %line thickness
                SegmJitter=0.3;% jitter of segments
                this.SegSpacing = SegSpacing;
            else %crude
                ContLength = 5; % number of segments in the target
                PatchSize=7; % size of patch, pick uneven
                this.SegLength=SegLength; %length of segments
                BinSize=8; %size of bins
                this.SegThick=SegThick; %line thickness
                SegmJitter=0.3;% jitter of segments
                this.SegSpacing = SegSpacing;
            end
            if ~trialID %trial ID is isLeftTrial but for Go/No-Go it determines if contour or distractor
            %Go / Contour:
                targetDifficulty = numDistractorsTable(1,2);
                Radius = (PatchSize-2)*BinSize;
                [SegmX,SegmY] = createSegmentSpace(Radius);
                cosScale = abs(cosd(Orient*2))+(cosd(45)-cosd(45)*abs(cosd(Orient*2)));
                plotDistractors(Radius,targetDifficulty,SegmJitter,this.SegThick,this.SegLength,ContLength,trialID , SegmX, SegmY, PatchSize, BinSize, first, this.SegSpacing, SpotlightToggle, Spotlight, LineShade, Background, this.Levertype)
                view(-Orient,90)
                axis image; axis off
            else
            %No-Go / Distractor:
                distractorDifficulty = numDistractorsTable(1,1);
                Radius = (PatchSize-2)*BinSize;
                [SegmX,SegmY] = createSegmentSpace(Radius);
                cosScale = abs(cosd(Orient*2))+(cosd(45)-cosd(45)*abs(cosd(Orient*2)));
                plotDistractors(Radius,distractorDifficulty,SegmJitter,this.SegThick,this.SegLength,ContLength,trialID , SegmX, SegmY, PatchSize, BinSize, ~first, this.SegSpacing, SpotlightToggle, Spotlight, LineShade, Background, this.Levertype)
                view(-Orient,90)
                axis image; axis off
            end
            xlim([-(this.SegLength+this.SegSpacing+5)*ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*ContLength*0.5+100])
            ylim([-(this.SegLength+this.SegSpacing+5)*ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*ContLength*0.5+100])
            hold off
            positionfig=[winx winy winwidth winheight];
            set(gcf,'OuterPosition',positionfig); %move window here, also determines size
        else %display == 0
            clf%(fig1);
        end
    else %Every other input mode
        if display==1
            if SolidLine==0
                %fine
                ContLength = 5; % number of segments in the target
                PatchSize=7; % size of patch, pick uneven
                this.SegLength=SegLength; %length of segments
                BinSize=8; %size of bins
                this.SegThick=SegThick; %line thickness
                SegmJitter=0.3;% jitter of segments
                this.SegSpacing = SegSpacing;
            else %crude
                ContLength = 5; % number of segments in the target
                PatchSize=7; % size of patch, pick uneven
                this.SegLength=SegLength; %length of segments
                BinSize=8; %size of bins
                this.SegThick=SegThick; %line thickness
                SegmJitter=0.3;% jitter of segments
                this.SegSpacing = SegSpacing;
            end
    %         if difficultyLevel==0
    %             error('for this Stimulus density must be greater than zero')
    %         end
            distractorDifficulty = numDistractorsTable(1,1);
            targetDifficulty = numDistractorsTable(1,2);
            Radius = (PatchSize-2)*BinSize;
            [SegmX,SegmY] = createSegmentSpace(Radius);
            cosScale = abs(cosd(Orient*2))+(cosd(45)-cosd(45)*abs(cosd(Orient*2)));
            plotDistractors(Radius,targetDifficulty,SegmJitter,this.SegThick,this.SegLength,ContLength, trialID , SegmX, SegmY, PatchSize, BinSize, first, this.SegSpacing, SpotlightToggle, Spotlight, LineShade, Background, this.Levertype)
            view(-Orient,90)
            axis image; axis off
            if this.Levertype == 5 %Lick
    %             xlim([-(this.SegLength+this.SegSpacing+5)*ContLength*0.5 (this.SegLength+this.SegSpacing+5)*ContLength*0.5])
    %             ylim([-(this.SegLength+this.SegSpacing+5)*ContLength*0.5 (this.SegLength+this.SegSpacing+5)*ContLength*0.5])
                xlim([-(this.SegLength+this.SegSpacing+5)*ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*ContLength*0.5+100])
                ylim([-(this.SegLength+this.SegSpacing+5)*ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*ContLength*0.5+100])
            else %Nose
                xlim([-Radius*patchScale*cosScale Radius*patchScale*cosScale])
                ylim([-Radius*patchScale*cosScale Radius*patchScale*cosScale])
            end
            hold off
    %Second part of the figure is the distractor, and this axis is the active
    %one that is later cleared to display which was correct
    %         plotDistractors(Radius,distractorDifficulty,SegmJitter,this.SegThick,this.SegLength,ContLength,trialID , SegmX, SegmY, PatchSize, BinSize, ~first, this.SegSpacing, SpotlightToggle, Spotlight, LineShade, Background, this.Levertype)
    %         view(-Orient,90)
    %         axis image; axis off
    %         if this.Levertype == 5 %Lick
    % %             xlim([-(this.SegLength+this.SegSpacing+5)*ContLength*0.5 (this.SegLength+this.SegSpacing+5)*ContLength*0.5])
    % %             ylim([-(this.SegLength+this.SegSpacing+5)*ContLength*0.5 (this.SegLength+this.SegSpacing+5)*ContLength*0.5])
    %             xlim([-(this.SegLength+this.SegSpacing+5)*ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*ContLength*0.5+100])
    %             ylim([-(this.SegLength+this.SegSpacing+5)*ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*ContLength*0.5+100])
    %         else %Nose
    %             xlim([-Radius*patchScale*cosScale Radius*patchScale*cosScale])
    %             ylim([-Radius*patchScale*cosScale Radius*patchScale*cosScale])
    %         end
            hold off
            positionfig=[winx winy winwidth winheight];
            set(gcf,'OuterPosition',positionfig); %move window here, also determines size
        else
            clf%(fig1);
        end
    end
end
%NosePoke Training 1
function ShowStimulusBBNoseTraining1Density(this)
    set(groot,'CurrentFigure',100)
    hold on
    set(gcf,'MenuBar','none');
    plotDistractors(this, 1, this.isLeftTrial, 0) %Left Stim, 0 distractors
    view(-this.Orient,90)
    axis image; axis off
    if this.Levertype == 5 %Lick
        xlim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5+100])
        ylim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5+100])
    elseif this.Levertype == 3 %Nose
        xlim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5])
        ylim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5])
    elseif this.Levertype == 7 %Lick Go/No-Go

    elseif this.Levertype == 6 %Rotating wheel
    end
    hold off
%Make second stimulus, also correct
    plotDistractors(this, 0, ~this.isLeftTrial, 0) %Right Stim, 0 distractors
    view(-this.Orient,90)
    axis image; axis off
    if this.Levertype == 5 %Lick
        xlim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5+100])
        ylim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5+100])
    else %Nose
        xlim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5])
        ylim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5])
    end
    hold off
    positionfig=[this.winx this.winy this.winwidth this.winheight];
    set(gcf,'OuterPosition',positionfig); %move window here, also determines size
end
%NosePoke Training 2
function ShowStimulusBBNoseTraining2Density(this)
    set(groot,'CurrentFigure',100)
    hold on
    set(gcf,'MenuBar','none');
    plotDistractors(this, this.isLeftTrial, 1, 0)
    view(-this.Orient,90)
    axis image; axis off
    if this.Levertype == 5 %Lick
        xlim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5+100])
        ylim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5+100])
    elseif this.Levertype == 3 %Nose
        xlim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5])
        ylim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5])
    elseif this.Levertype == 7 %Lick Go/No-Go

    elseif this.Levertype == 6 %Rotating wheel
    end
    hold off
    positionfig=[this.winx this.winy this.winwidth this.winheight];
    set(gcf,'OuterPosition',positionfig); %move window here, also determines size
end
%NosePoke Training 3
function ShowStimulusBBNoseTraining3Density(this)
    %1 stimulus is shown. It randomly on left or right. It is randomly
    %correct or incorrect. If correct, long timeout and gives reward. If
    %incorrect, short timeout and gives airpuff
    set(groot,'CurrentFigure',100)
    hold on
    set(gcf,'MenuBar','none');
    plotDistractors(this, this.isLeftTrial, this.isCorrect, 0) 
    view(-this.Orient,90)
    axis image; axis off
    if this.Levertype == 5 %Lick
        xlim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5+100])
        ylim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5+100])
    elseif this.Levertype == 3 %Nose
        xlim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5])
        ylim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5])
    elseif this.Levertype == 7 %Lick Go/No-Go

    elseif this.Levertype == 6 %Rotating wheel
    end
    hold off
    positionfig=[this.winx this.winy this.winwidth this.winheight];
    set(gcf,'OuterPosition',positionfig); %move window here, also determines size
end
%NosePoke Training 3
function ShowStimulusBBNoseTraining4Density(this)
    %1 stimulus is shown. It randomly on left or right. It is randomly
    %correct or incorrect. If correct, long timeout and gives reward. If
    %incorrect, short timeout and gives airpuff
    %A few distractors will be added.
    set(groot,'CurrentFigure',100)
    hold on
    set(gcf,'MenuBar','none');
    distractors = this.numDistractorsTable(1:3,this.isCorrect+1)';
    numdistractors = distractors(randperm(numel(distractors),1));
    plotDistractors(this, this.isLeftTrial, this.isCorrect, numdistractors) 
    view(-this.Orient,90)
    axis image; axis off
    if this.Levertype == 5 %Lick
        xlim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5+100])
        ylim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5+100])
    elseif this.Levertype == 3 %Nose
        xlim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5])
        ylim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5])
    elseif this.Levertype == 7 %Lick Go/No-Go

    elseif this.Levertype == 6 %Rotating wheel
    end
    hold off
    positionfig=[this.winx this.winy this.winwidth this.winheight];
    set(gcf,'OuterPosition',positionfig); %move window here, also determines size
end
%Wheel Early, both sides are correct
function ShowStimulusContourTrainingWheelEarly(this)
%In this mode 2 correct stimuli are shown
    set(groot,'CurrentFigure',100)
    set(gcf,'MenuBar','none');
    hold on
    plotDistractors(this, 1, 1, 0) %Left = 1, Correct = 1, 0 distractors
    xlim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5])
    ylim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5])
    plotDistractors(this, 0, 1, 0) %Left = 0, Correct = 1, 0 distractors
    xlim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5])
    ylim([-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength*0.5])
    hold off
end
%Wheel Late, after the mouse spins wheel one way, that side is correct and a stimulus for that side is shown.
function ShowStimulusContourTrainingWheelLate(trialID, display, winheight, winwidth, winx, winy, SolidLine, Orient, SpotlightToggle, Spotlight, LineShade, Background, Levertype, SegLength, SegThick, SegSpacing, FinishLine)
    first = 1; %The right side is always plotted first. %trialID is if the stimulus is to be on the left
    %Distractor side is first item, target is second item
    numDistractorsTable = [0,0 ; 1,0 ; 3,2 ; 5,4 ; 9,7 ; 13,10 ; 19 , 14 ; 35,30];
    patchScale = 1.5; % This number sets the size of the patch on the screen by making the axis patchSacle * radius
    % segments density
    set(groot,'CurrentFigure',100)
    %fig1=figure(100);
    clf
    hold on
    set(groot,'CurrentFigure',100)
    set(gcf,'MenuBar','none');
    if this.Levertype == 7 % Go/No-Go task, so only one stimulus is shown at a time
        if display==1
            if SolidLine==0
                %fine
                ContLength = 5; % number of segments in the target
                PatchSize=7; % size of patch, pick uneven
                this.SegLength=SegLength; %length of segments
                BinSize=8; %size of bins
                this.SegThick=SegThick; %line thickness
                SegmJitter=0.3;% jitter of segments
                this.SegSpacing = SegSpacing;
            else %crude
                ContLength = 5; % number of segments in the target
                PatchSize=7; % size of patch, pick uneven
                this.SegLength=SegLength; %length of segments
                BinSize=8; %size of bins
                this.SegThick=SegThick; %line thickness
                SegmJitter=0.3;% jitter of segments
                this.SegSpacing = SegSpacing;
            end
            if ~trialID %trial ID is isLeftTrial but for Go/No-Go it determines if contour or distractor
            %Go / Contour:
                targetDifficulty = numDistractorsTable(1,2);
                Radius = (PatchSize-2)*BinSize;
                [SegmX,SegmY] = createSegmentSpace(Radius);
                cosScale = abs(cosd(Orient*2))+(cosd(45)-cosd(45)*abs(cosd(Orient*2)));
                plotDistractors(Radius,targetDifficulty,SegmJitter,this.SegThick,this.SegLength,ContLength,trialID , SegmX, SegmY, PatchSize, BinSize, first, this.SegSpacing, SpotlightToggle, Spotlight, LineShade, Background, this.Levertype)
                view(-Orient,90)
                axis image; axis off
            else
            %No-Go / Distractor:
                distractorDifficulty = numDistractorsTable(1,1);
                Radius = (PatchSize-2)*BinSize;
                [SegmX,SegmY] = createSegmentSpace(Radius);
                cosScale = abs(cosd(Orient*2))+(cosd(45)-cosd(45)*abs(cosd(Orient*2)));
                plotDistractors(Radius,distractorDifficulty,SegmJitter,this.SegThick,this.SegLength,ContLength,trialID , SegmX, SegmY, PatchSize, BinSize, ~first, this.SegSpacing, SpotlightToggle, Spotlight, LineShade, Background, this.Levertype)
                view(-Orient,90)
                axis image; axis off
            end
            xlim([-(this.SegLength+this.SegSpacing+5)*ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*ContLength*0.5+100])
            ylim([-(this.SegLength+this.SegSpacing+5)*ContLength*0.5-100 (this.SegLength+this.SegSpacing+5)*ContLength*0.5+100])
            hold off
            positionfig=[winx winy winwidth winheight];
            set(gcf,'OuterPosition',positionfig); %move window here, also determines size
        else %display == 0
            clf%(fig1);
        end
    else %Every other input mode
        if display==1
            if SolidLine==0
                %fine
                ContLength = 5; % number of segments in the target
                PatchSize=7; % size of patch, pick uneven
                this.SegLength=SegLength; %length of segments
                BinSize=8; %size of bins
                this.SegThick=SegThick; %line thickness
                SegmJitter=0.3;% jitter of segments
                this.SegSpacing = SegSpacing;
            else %crude
                ContLength = 5; % number of segments in the target
                PatchSize=7; % size of patch, pick uneven
                this.SegLength=SegLength; %length of segments
                BinSize=8; %size of bins
                this.SegThick=SegThick; %line thickness
                SegmJitter=0.3;% jitter of segments
                this.SegSpacing = SegSpacing;
            end
    %         if difficultyLevel==0
    %             error('for this Stimulus density must be greater than zero')
    %         end
            distractorDifficulty = numDistractorsTable(1,1);
            targetDifficulty = numDistractorsTable(1,2);
            Radius = (PatchSize-2)*BinSize;
            [SegmX,SegmY] = createSegmentSpace(Radius);
            cosScale = abs(cosd(Orient*2))+(cosd(45)-cosd(45)*abs(cosd(Orient*2)));
            plotDistractors(Radius,targetDifficulty,SegmJitter,this.SegThick,this.SegLength,ContLength, trialID , SegmX, SegmY, PatchSize, BinSize, first, this.SegSpacing, SpotlightToggle, Spotlight, LineShade, Background, this.Levertype, FinishLine)
            view(-Orient,90)
            axis image; axis off
            xlim([-(this.SegLength+this.SegSpacing+5)*ContLength*0.5 (this.SegLength+this.SegSpacing+5)*ContLength*0.5])
            ylim([-(this.SegLength+this.SegSpacing+5)*ContLength*0.5 (this.SegLength+this.SegSpacing+5)*ContLength*0.5])
            hold off
            positionfig=[winx winy winwidth winheight];
            set(gcf,'OuterPosition',positionfig); %move window here, also determines size
%             if FinishLine
%                 f = axes('Position', [0.45 0.15 0.1 0.1], 'Parent', gcf, 'Tag', 'FinishLine');
%                 hold(f,'on')
%                 p = nsidedpoly(3, 'Center', [0 ,0], 'SideLength', 1);
%                 tri = plot(p, 'Parent',f, 'FaceColor', [Spotlight Spotlight Spotlight], 'EdgeAlpha', 0, 'FaceAlpha', 1);
%                 axis image; axis off
%                 f2 = axes('Position', [0.45 0.75 0.1 0.1], 'Parent', gcf, 'Tag', 'FinishLine');
%                 hold(f2,'on')
%                 p2 = nsidedpoly(3, 'Center', [0 ,0], 'SideLength', 1);
%                 tri2 = plot(p2, 'Parent',f2, 'FaceColor', [Spotlight Spotlight Spotlight], 'EdgeAlpha', 0, 'FaceAlpha', 1);
%                 f2.YDir = 'reverse';
%                 axis image; axis off
%             end
        else
            clf%(fig1);
        end
    end
end
%display patch stimulus
function ShowStimulusOnePatch(this, trialID, opacity, display,winheight,winwidth,winx,winy,crudetoggle, Orient)
if crudetoggle==0
    %fine
    ContLength=7; % length of contour
    ContLengthHalf=ceil(ContLength/2); %half of the contour
    PatchSize=9; % size of patch, pick uneven
    PatchSizeHalf=floor(PatchSize/2); %half of the patch
    this.SegLength=1.2; %length of sements
    BinSize=2; %size of bins
    this.SegThick=7; %line thickness9
    SegmJitter= 0.3;% jitter of segments
else
    %crude
    ContLength=7; % length of contour
    ContLengthHalf=ceil(ContLength/2); %half of the contour
    PatchSize=11; % size of patch, pick uneven
    PatchSizeHalf=floor(PatchSize/2); %half of the patch
    this.SegLength=1.2; %length of sements
    BinSize=2; %size of bins
    this.SegThick=9; %line thickness9
    SegmJitter= 0.3;% jitter of segments
end
fig1=figure(100);
%show yes or no
if display==1
    Alpha=-25; %determines closeness of contour elements, set somewhere between [-30 30]
    %see Li & Gilbert 2002
    Alpha=(90+Alpha)/90;
    SegmX=zeros(2,PatchSize,PatchSize);
    SegmY=zeros(2,PatchSize,PatchSize);
    if trialID==1
        % make grid
        for i=-PatchSizeHalf:PatchSizeHalf
            for j=-PatchSizeHalf:PatchSizeHalf
                SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=i*BinSize;
                SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=j*BinSize;
            end
        end
        % turn grid around crossing with y-axis
        [SegmTheta,SegmRho] = cart2pol(zeros(2,PatchSize,PatchSize),SegmY);
        SegmTheta(SegmTheta>0)=SegmTheta(SegmTheta>0)/Alpha;
        SegmTheta(SegmTheta<0)=((SegmTheta(SegmTheta<0)+pi)/Alpha)-pi;
        [SegmXA,SegmY] = pol2cart(SegmTheta,SegmRho);
        SegmX=SegmX+SegmXA;
        % Draw background with the grid as center
        for i=-PatchSizeHalf:PatchSizeHalf
            for j=-PatchSizeHalf:PatchSizeHalf
                angle=rand*180;
                if i==j & i>-ContLengthHalf &i<ContLengthHalf %for contour segments
                    angle=45;
                    X=[-this.SegLength/2 this.SegLength/2];
                    Y=[0 0];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);
                else
                    JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                    JY=SegmJitter*2*(rand-0.5);
                    X=[-this.SegLength/2 this.SegLength/2]+JX;
                    Y=[0 0]-JY;
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi;
                    [X,Y] = pol2cart(Theta,Rho);
                end
                SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+X';
                SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+Y';
            end
        end
        %plot all line segments
        set(gca,'color','black')
        set(gcf,'color','black')
        hold on;
        for i=-PatchSizeHalf:PatchSizeHalf
            for j=-PatchSizeHalf:PatchSizeHalf
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick,'Color',[1*opacity 1*opacity 1*opacity])
            end
        end
        hold on
        % Draw segments grid as center
        for i=-PatchSizeHalf:PatchSizeHalf
            for j=-PatchSizeHalf:PatchSizeHalf
                if i==j & i>-ContLengthHalf &i<ContLengthHalf %for contour segments
                    angle=45;
                    X=[-this.SegLength/2 this.SegLength/2];
                    Y=[0 0];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);
                    plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick)
                end
            end
        end
        hold off
        %plot mask, upper and lower part separate
        NumPoints=100;
        Radius=(PatchSizeHalf-2)*BinSize;
        Theta=linspace(0,pi,NumPoints); %100 evenly spaced points between 0 and pi
        Rho=ones(1,NumPoints)*Radius; %Radius should be 1 for all 100 points
        [X,Y] = pol2cart(Theta,Rho);
        X(101)=-PatchSize*2;
        Y(101)=0;
        X(102)=-PatchSize*2;
        Y(102)=PatchSize*2;
        X(103)=PatchSize*2;
        Y(103)=PatchSize*2;
        X(104)=PatchSize*2;
        Y(104)=0;
        patch(X,Y,'k');
        Theta=linspace(0,-pi,NumPoints); %100 evenly spaced points between 0 and -pi
        [X,Y] = pol2cart(Theta,Rho);
        X(101)=-PatchSize*2;
        Y(101)=0;
        X(102)=-PatchSize*2;
        Y(102)=-PatchSize*2;
        X(103)=PatchSize*2;
        Y(103)=-PatchSize*2;
        X(104)=PatchSize*2;
        Y(104)=0;
        patch(X,Y,'k');
        axis tight; axis square
        view(-Orient/Alpha,90)
        xlim([-Radius*0.8 Radius*0.8])
        ylim([-Radius*0.8 Radius*0.8])
        % print -dbmp LiStim1
    else
        % SECOND PART OF FOGURE%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        hold on
        % make grid
        for i=-PatchSizeHalf:PatchSizeHalf
            for j=-PatchSizeHalf:PatchSizeHalf
                SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=i*BinSize;
                SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=j*BinSize;
            end
        end
        % turn grid around crossing with y-axis
        [SegmTheta,SegmRho] = cart2pol(zeros(2,PatchSize,PatchSize),SegmY);
        SegmTheta(SegmTheta>0)=SegmTheta(SegmTheta>0)/Alpha;
        SegmTheta(SegmTheta<0)=((SegmTheta(SegmTheta<0)+pi)/Alpha)-pi;
        [SegmXA,SegmY] = pol2cart(SegmTheta,SegmRho);
        SegmX=SegmX+SegmXA;
        % Draw background with the grid as center
        for i=-PatchSizeHalf:PatchSizeHalf
            for j=-PatchSizeHalf:PatchSizeHalf
                angle=rand*180;
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-this.SegLength/2 this.SegLength/2]+JX;
                Y=[0 0]-JY;
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi;
                [X,Y] = pol2cart(Theta,Rho);
                SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+X';
                SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)=SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1)+Y';
            end
        end
        %plot all line segments
        set(gca,'color','black')
        set(gcf,'color','black')
        hold on;
        for i=-PatchSizeHalf:PatchSizeHalf
            for j=-PatchSizeHalf:PatchSizeHalf
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',this.SegThick,'Color',[1*opacity 1*opacity 1*opacity])
            end
        end
        hold on
        hold off
        %plot mask, upper and lower part separate
        NumPoints=100;
        Radius=(PatchSizeHalf-2)*BinSize;
        Theta=linspace(0,pi,NumPoints); %100 evenly spaced points between 0 and pi
        Rho=ones(1,NumPoints)*Radius; %Radius should be 1 for all 100 points
        [X,Y] = pol2cart(Theta,Rho);
        X(101)=-PatchSize*2;
        Y(101)=0;
        X(102)=-PatchSize*2;
        Y(102)=PatchSize*2;
        X(103)=PatchSize*2;
        Y(103)=PatchSize*2;
        X(104)=PatchSize*2;
        Y(104)=0;
        patch(X,Y,'k');
        Theta=linspace(0,-pi,NumPoints); %100 evenly spaced points between 0 and -pi
        [X,Y] = pol2cart(Theta,Rho);
        X(101)=-PatchSize*2;
        Y(101)=0;
        X(102)=-PatchSize*2;
        Y(102)=-PatchSize*2;
        X(103)=PatchSize*2;
        Y(103)=-PatchSize*2;
        X(104)=PatchSize*2;
        Y(104)=0;
        patch(X,Y,'k');
        hold off
        axis tight; axis square
        view(-Orient+45/Alpha,90)
        xlim([-Radius*0.8 Radius*0.8])
        ylim([-Radius*0.8 Radius*0.8])
        set(gcf,'MenuBar','none');
        positionfig=[winx winy winwidth winheight];
        %positionfig=[1600 50 500 450];
        set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
        %notusedyet=borderwidth;
    end
else
    close(fig1);
end
end
function [SegmX,SegmY] = createSegmentSpace(Radius)
    [Y, X] = meshgrid(-(Radius):2:Radius);
    SegmX = NaN(2,Radius+1,Radius+1);
    SegmY = NaN(2,Radius+1,Radius+1);
    for i = 1:2
        SegmX(i,:,:) = X;
        SegmY(i,:,:) = Y;
    end
end
%Distractor plot by randomly permuting nodes from a set
function plotDistractors(this, LeftStim, isCorrect, numDistractors)    
% SANTI 10-1-2020
    %this.SegSpacing = 13;
    fig1 = set(groot,'CurrentFigure',100);
%     SpotlightShade = Spotlight;
%     LineColor = LineShade;
%   Left or Right side
%   Correct not
%   How many distractors
    if isCorrect
        tag = 'Correct';
    else
        tag = 'Incorrect';
    end
    if this.Levertype == 7
        a = subplot(1,1,1, 'Parent', fig1, 'Tag', 'Stimulus');
        getRect(this);
    elseif LeftStim %% FIRST=1 MEANS STIMULUS WITH TARGET
        c = subplot(1,5,[1 2], 'Parent', fig1, 'Tag', tag); %On left
        hold(c,'on')
        if this.SpotlightToggle %& this.Levertype == 5
            getRect(this);
        end
        if this.Levertype == 5
            pos = [0 0 0.5 1];
        else
            pos = [0.0 0 0.4 1];
        end
        set(c, 'Position', pos)
    elseif ~LeftStim %RightStim...
        b = subplot(1,5,[4 5], 'Parent', fig1, 'Tag', tag); %On right
        hold(b,'on')
        if this.SpotlightToggle %& this.Levertype == 5
            getRect(this);
        end
        if this.Levertype == 5
            pos = [0.5 0 0.5 1];
        else
            pos = [0.6 0 0.4 1];
        end
        set(b, 'Position', pos)
    end
gridWidth = (this.SegLength+this.SegSpacing)*this.ContLength;
maskRadius = gridWidth/2;
%Creates triangular grid
X = -(gridWidth):this.SegLength+this.SegSpacing:gridWidth ; 
Y = (-(gridWidth):this.SegLength+this.SegSpacing:gridWidth) .* (sqrt(3) / 2); %Since it's triangular, we need to correct some distances
[X,Y] = meshgrid(X,Y);
X(1:2:length(X),:) = X(1:2:length(X),:) + 0.5*(this.SegLength+this.SegSpacing); %Every other row gets displaced to the right
Mask = ( X.^2 + Y.^2) <= maskRadius^2; %Circular mask made with logical values
%Creates a 2 column list of all the grid nodes. Turns the grid 90°
listGridNodes = [Y(Mask) X(Mask)]; %By using X=Y and Y=X, we are effectively turning the grid 90°
if isCorrect %Plot the correct stim with 5 line segments:
    contourNodesIdx = logical(listGridNodes(:,1) == 0) & sqrt( listGridNodes(:,1).^2 + listGridNodes(:,2).^2) <= (this.SegLength+this.SegSpacing) * this.ContLength/2;
    contourNodes = listGridNodes(contourNodesIdx,:); %Contour nodes are those where X = 0 [this can be modified]
    nonContourNodes = listGridNodes(~contourNodesIdx,:); %Non contour nodes are those where X =/= 0 [this can be modified]
    for i = 1:size(contourNodes,1) %Creates the coordinates of the bar tip centered in [0,0]
        [Tip1X, Tip1Y] = pol2cart(deg2rad(90), this.SegLength/2);
        [Tip2X, Tip2Y] = pol2cart(deg2rad(90 + 180), this.SegLength/2);
        xCoordinates = [contourNodes(i,1) + Tip1X, contourNodes(i,1) + Tip2X];
        yCoordinates = [contourNodes(i,2) + Tip1Y, contourNodes(i,2) + Tip2Y];
        plot(xCoordinates, yCoordinates, 'Color', [this.LineShade], 'LineWidth',this.SegThick)
        hold on
    end
else
    nonContourNodes = listGridNodes; %If this is not the target figure, then nonContour = all nodes 
end
%Randomly selects a few (#nDistractors) nonContourNodes
selectedNodesIndex = randperm(length(nonContourNodes),numDistractors); 
selectedNodes = nonContourNodes(selectedNodesIndex,:); 
selectedAngle = randi(360,numDistractors); %Randomly selects angles for the bars
if numDistractors > 0
    for i = 1:numDistractors %Creates the coordinates of the bar tip centered in [0,0]
        [Tip1X, Tip1Y] = pol2cart(deg2rad(selectedAngle(i)), this.SegLength/2); %Creates coords of a semi bar starting from 0,0
        [Tip2X, Tip2Y] = pol2cart(deg2rad(selectedAngle(i) + 180), this.SegLength/2); %Creates the other half-bar
        xCoordinates = [selectedNodes(i,1) + Tip1X, selectedNodes(i,1) + Tip2X]; %Adds the coords from the nodes and half bars
        yCoordinates = [selectedNodes(i,2) + Tip1Y, selectedNodes(i,2) + Tip2Y];
        plot(xCoordinates, yCoordinates,'Color', [this.LineShade],'LineWidth',this.SegThick)
        hold on
    end
end
view(-this.Orient,90)
axis image; axis off
set(gca,'color','none')
set(gcf,'color',[this.Background])
end
function maskOff(PatchSize,BinSize,Orient,Alpha)
    % this function masks off, in black, all the pixels outside of the
    % circle with a radius of (PatchSizeHalf-2)*BinSize; 
    hold on;
    NumPoints=100;
    Radius=(floor(PatchSize/2)-PatchSize*.1)*BinSize;
    Theta=linspace(0,pi,NumPoints); %100 evenly spaced points between 0 and pi
    Rho=ones(1,NumPoints)*Radius; %Radius should be 1 for all 100 points
    [X,Y] = pol2cart(Theta,Rho);
    X(101)=-PatchSize*2;
    Y(101)=-1;
    X(102)=-PatchSize*2;
    Y(102)=PatchSize*2;
    X(103)=PatchSize*2;
    Y(103)=PatchSize*2;
    X(104)=PatchSize*2;
    Y(104)=-1;
    patch(X,Y,'k');
    Theta=linspace(0,-pi,NumPoints); %100 evenly spaced points between 0 and -pi
    [X,Y] = pol2cart(Theta,Rho);
    X(101)=-PatchSize*2;
    Y(101)=0;
    X(102)=-PatchSize*2;
    Y(102)=-PatchSize*2;
    X(103)=PatchSize*2;
    Y(103)=-PatchSize*2;
    X(104)=PatchSize*2;
    Y(104)=0;
    patch(X,Y,'k');
    color = [0 0 0];
    line([-Radius*1.2 -Radius*1.2],[-Radius*1.2 Radius*1.2],'Color',color,'LineWidth',7)
    line([-Radius*1.2 Radius*1.2],[Radius*1.2 Radius*1.2],'Color',color,'LineWidth',7)
    line([Radius*1.2 Radius*1.2],[Radius*1.2 -Radius*1.2],'Color',color,'LineWidth',7)
    line([-Radius*1.2 Radius*1.2],[-Radius*1.2 -Radius*1.2],'Color',color,'LineWidth',7)
    hold off
    axis tight; axis square; axis off
    xlim([-Radius*1.2 Radius*1.2])
    ylim([-Radius*1.2 Radius*1.2])
    view(-Orient/Alpha,90)
    hold off
    axis off
end
function getRect(this)
a = gca;
rectangle('Parent', a, 'Position', [-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 -(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength (this.SegLength+this.SegSpacing+5)*this.ContLength], 'Curvature', [1 1], 'FaceColor', [this.Spotlight], 'EdgeColor', 'none');
end