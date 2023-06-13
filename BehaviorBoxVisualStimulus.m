classdef BehaviorBoxVisualStimulus
    properties(GetAccess = 'public', SetAccess = 'public')
        type;
        numDistractorsTable = [0,0 ; 1,0 ; 2,0 ; 3,0 ; 4,0 ; 5,0 ; 6,1 ; 7,2 ; 8,3 ; 9,4 ; 10,5 ; 11,6 ; 12,7 ; 13,8 ; 14,9 ; 15,10 ; 16,11 ; 17,12 ; 18,13 ; 19,14]; %Distractor side is first item, target is second item
        fig;
        position_x;
        position_y;
        size_x = 10;
        size_y = 6.5;
        figpos = [1 1 9.5 7]; % Hard coded in INCHES and matlab will adjust automatically
        LStimAx; %Axis that contains the left stimulus plot
        RStimAx; %Axis that contains the left stimulus plot
        FLAx; %Axis that contains the 2 finish line triangles
        ChoiceAx; %Axis to plot the wheel choice
        SpotlightColor = [0 0 0];
        SpotlightToggle = 1;
        FinishLine = 1;
        BetweenSpotlight = 10;
        LineColor = [0.6 0.6 0.6];
        FlashColor = [0.7 0.7 0.7];
        DimColor = [0.3 0.3 0.3];
        Levertype;
        BackgroundColor = [0 0 0];
        SegLength = 15;
        SegThick = 10;
        SegSpacing = 13;
        ContLength = 5; % number of segments in the target
        ContourNodes;
        PatchSize=7; % size of patch, pick uneven
        BinSize=8; %size of bins
        SegmJitter=0.3;% jitter of segments
        Orient = 0;
        InputType;
    end
    properties(SetAccess = 'public', GetAccess = 'public')
        % Properties of the stimulus that change each trial (level, which side)
        trialID;
        show;
        Level;
        isLeftTrial;
    end
    methods % methods, including the constructor are defined in this block
        % Constructor:
        function [this] = BehaviorBoxVisualStimulus(StimStruct, options)
            arguments
                StimStruct = struct();
                options.Preview logical = false
            end
            if nargin == 0
                return
            end
            if ~options.Preview
                delete(findobj("Type", "figure", "Name", "Stimulus"))
            end
            this = this.updateProps(StimStruct);
            this.figpos = [this.position_x this.position_y this.size_x this.size_y];
            this.ContourNodes = this.SetupHexGrid();
            try
                this = this.findfigs();
                if isempty(this.LStimAx)
                    this.setUpFigure();
                    this = this.findfigs();
                end
            end
        end
        function this = updateProps(this, StimStruct)
            arguments
                this
                StimStruct = struct
            end
            try
                for f = fieldnames(StimStruct)'
                    try
                        this.(f{:}) = StimStruct.(f{:});
                    catch err
                        err;
                    end
                end
                this.fig.Color = this.BackgroundColor;
                this.fig.Position = [this.position_x this.position_y this.size_x this.size_y];
                [this.fig.findobj('Tag','Spotlight').FaceColor] = deal(this.SpotlightColor);
                [this.fig.findobj('Type','Line').Color] = deal(this.LineColor);
                [this.fig.findobj('Type','Polygon').FaceColor] = deal(this.LineColor);
            end
        end
        function [fig, LStimAx, RStimAx, FLAx, ChoiceAx] = setUpFigure(this, options)
            arguments
                this
                options.StimHist logical = false %If this is on, we're plotting the record into a SUBPLOT
                options.T
            end
            if isvalid(this.fig) & isvalid(this.LStimAx) & isvalid(this.RStimAx)
                fig = this.fig;
                LStimAx = this.LStimAx;
                RStimAx = this.RStimAx;
                FLAx = this.FLAx;
                ChoiceAx = this.ChoiceAx;
                return
            end
            % https://www.mathworks.com/help/matlab/creating_guis/update-app-figure-and-containers.html
            %Move this to a new function...
            %stimWidth = abs(100-this.BetweenSpotlight)/200;
            stimWidth = 0.5;
            ChoiceAx = [];
            RStimAx = [];
            LStimAx = [];
            fig = [];
            if options.StimHist
                T = options.T;
                fig = T.Parent;
                LStimAx = nexttile(T); hold(LStimAx,'on');
                axis image;
                RStimAx = nexttile(T); hold(RStimAx,'on');
                axis image;
                LStimAx.Tag = 'Left';
                RStimAx.Tag = 'Right';
                if this.InputType == 5
                    ChoiceAx = nexttile(T); hold(ChoiceAx,'on');
                    %axis image;
                    ChoiceAx.Tag = 'Choice';
                end
                if this.SpotlightToggle
                    this.getRect(RStimAx); this.getRect(LStimAx);
                end
                [T.Children(:).Color] = deal(this.BackgroundColor);
                [T.Children(:).YTick] = deal([]);
                [T.Children(:).XTick] = deal([]);
                [T.Children(:).Box] = deal('off');
            else
                fig = figure('NumberTitle', 'off',"Name", "Stimulus", "MenuBar","none", "HandleVisibility","on"); fig.Renderer = "painters";
                %fig.WindowStyle = "alwaysontop";
                fig.Units = "inches";
                fig.Position = this.figpos;
                fig.GraphicsSmoothing = 'off'; % Should help prevent graphics errors
                this.fig = fig;
                clf(fig);
                fig.Color = this.BackgroundColor;
                LStimAx = axes('Parent', fig, ...
                    'Tag', 'Left', ...
                    'Color', 'none', ...
                    'Position', [0 0 stimWidth 1], ...
                    'Visible','off', 'PickableParts','none');
                hold(LStimAx,'on');
                LStimAx.Toolbar.Visible = 'off';
                axis image;
                RStimAx = axes('Parent', fig, ...
                    'Tag', 'Right', ...
                    'Color', 'none', ...
                    'Position', [1-stimWidth 0 stimWidth 1], ...
                    'Visible','off', 'PickableParts','none');
                hold(RStimAx,'on');
                RStimAx.Toolbar.Visible = 'off';
                axis image;
                if this.SpotlightToggle
                    this.getRect(RStimAx); this.getRect(LStimAx);
                end
                ch = [fig.Children.Children];
                [ch(:).Visible] = deal(0);
            end
            this.fig = fig;
            this.LStimAx = LStimAx;
            this.RStimAx = RStimAx;
            FLAx = this.finishLine();
            this.FLAx = FLAx;
        end
        function getRect(this, ax)
            rectangle('Parent', ax, ...
                'Position', [-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 -(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength (this.SegLength+this.SegSpacing+5)*this.ContLength], ...
                'Curvature', [1 1], 'FaceColor', [this.SpotlightColor], 'EdgeColor', 'none', 'Tag', 'Spotlight');
        end
        function FLAx = finishLine(this)
            FLAx = [];
            if ~this.FinishLine
                return
            end
            width = 0.1;
            X = 0.5-(width/2);
            p = nsidedpoly(3, 'Center', [0 ,0], ...
                'SideLength', 1);
            f = axes('Position', [X 0.1 width width], 'Parent', this.fig, 'Tag', 'FinishLine', 'color', 'none');axis off; f.Toolbar.Visible = 'off';
            hold(f,'on')
            t1 = plot(p, 'Parent',f, 'FaceColor', this.LineColor, 'EdgeAlpha', 0, 'FaceAlpha', 1, 'Tag','FinishLine');
            f2 = axes('Position', [X 0.8 width width], 'Parent', this.fig, 'Tag', 'FinishLine', 'color', 'none', 'YDir', 'reverse');axis off; f2.Toolbar.Visible = 'off';
            hold(f2,'on')
            t2 = plot(p, 'Parent',f2, 'FaceColor', this.LineColor, 'EdgeAlpha', 0, 'FaceAlpha', 1, 'Tag','FinishLine');
            FLAx = [f f2];
        end
        function [L,R] = DisplayOnScreen(this, isLeftTrial, Level)
            this = findfigs(this);
            delete(findobj([this.fig], "Type", "Line"))
            this.LStimAx.Position(1) = 0;
            this.RStimAx.Position(1) = 0.5;
            try
                [this.FLAx.FaceColor] = deal(this.LineColor);
            end
            L = []; R = L;
            if isLeftTrial == 1
                this.isLeftTrial = 1;
            else
                this.isLeftTrial = 0;
            end
            this.Level = int8(Level); %Difficulty used to be from 0.1:1, it is now 1:20
            switch this.type
                case 11
                    [L,R] = this.ShowStimulusContour_Density();
                    %[L,R] = ShowStimulusContour_Density(this);
                case -2
                    ShowStimulusTwoTaskCircleCUE(this.trialID, this.Level, display,winheight,winwidth,winx,winy,1,orientation)
                case -1
                    ShowStimulusTwoTaskContourCUE(this.trialID, this.Level, display,winheight,winwidth,winx,winy,1,orientation)
                case 0
                    ShowStimulusImageCUE(this.trialID, this.Level, display,winheight,winwidth,winx,winy,1,orientation)
                case 1
                    if this.Levertype==1
                        ShowStimulusOnePatchContour(this.trialID, this.Level, display,winheight,winwidth,winx,winy,0,orientation)
                    else
                        ShowStimulusContour(this.trialID, this.Level,display,winheight,winwidth,winx,winy, 0,orientation);
                    end
                case 2
                    if this.Levertype==1
                        ShowStimulusOnePatchContour(this.trialID, this.Level, display,winheight,winwidth,winx,winy,1,orientation)
                    else
                        ShowStimulusContour(this.trialID, this.Level,display,winheight,winwidth,winx,winy, 1,orientation);
                    end
                case 3
                    ShowStimulusSquare(this.trialID, this.Level,display,winheight,winwidth,winx,winy, 1,orientation);
                case 4
                    ShowStimulusSquare(this.trialID, this.Level,display,winheight,winwidth,winx,winy, 0,orientation);
                case 5
                    ShowStimulusContourDistractor(this.trialID, this.Level,display,winheight,winwidth,winx,winy, 1,orientation);
                case 6
                    ShowStimulusTwoTaskCircle(this.trialID,this.Level,display,winheight,winwidth,winx,winy,1,orientation);
                case 7
                    ShowStimulusTwoTaskContour(this.trialID,this.Level,display,winheight,winwidth,winx,winy,1,orientation);
                case 8
                    ShowStimulusImage(this.trialID,this.Level,display,winheight,winwidth,winx,winy,1,orientation)
                case 9
                    ShowStimulusPsychometricContour(this.trialID,this.Level,display,winheight,winwidth,winx,winy,1,orientation)
                case 10
                    ShowStimulusGrating(this.trialID,this.Level,display,winheight,winwidth,winx,winy,1,orientation)
                case 12
                    ShowStimulusBBTrainingDensity(this)
            end
            o = findobj(this.fig.Children);
            %[o(:).Visible] = deal(0);
        end
        function this = findfigs(this)
            try
                this.fig = findobj("Name", "Stimulus");
            end
            try
                ch = [this.fig(end).Children];
                if ch.Type == "tiledlayout"
                    ch = ch.Children;
                end
            end
            try
                this.LStimAx = ch(contains({ch.Tag}, "Left"));
                this.RStimAx = ch(contains({ch.Tag}, "Right"));
                this.ChoiceAx = ch(contains({ch.Tag}, "Choice"));
                t = ch(contains({ch.Tag}, "FinishLine"));
                this.FLAx = t.findobj('Type', 'Polygon');
            end
        end
        function ContourNodes = SetupHexGrid(this)
            % Vars:
            % # of Dashes in correct contour: ContLength
            % Length of dash: SegLength
            % Space between dashes: SegSpacing
            gridWidth = (this.SegLength+this.SegSpacing)*this.ContLength;
            maskRadius = gridWidth/2;
            %Creates triangular grid
            X = -(gridWidth):this.SegLength+this.SegSpacing:gridWidth ;
            Y = (-(gridWidth):this.SegLength+this.SegSpacing:gridWidth) .* (sqrt(3) / 2); %Since it's triangular, we need to correct some distances
            [X,Y] = meshgrid(X,Y);
            X(1:2:length(X),:) = X(1:2:length(X),:) + 0.5*(this.SegLength+this.SegSpacing); %Every other row gets displaced to the right
            Mask = ( X.^2 + Y.^2) <= maskRadius^2; %Circular mask made with logical values
            %Creates a 2 column list of all the grid nodes. Turns the grid 90°
            ContourNodes = sortrows([Y(Mask) X(Mask)]); %By using X=Y and Y=X, we are effectively turning the grid 90°
        end
        % This is the most used one, currently WBS
        function [L,R,Lrej,Rrej] = ShowStimulusContour_Density(this, options)
            arguments
                this
                options.SH
            end
            % in this stimulus instead of training by gradual increase between line
            % segments contrast with background we use gradual increase of line quantity
            if ~isfield(options,'SH')
                [Ldist, LTags, Lrej] = this.CheckDistractors(1);
                [Rdist, RTags, Rrej] = this.CheckDistractors(0);
            else
                % 1 TrialNum
                % 2 Level
                % 3 Left Stim
                % 4 Right Stim
                % 5 Outcome
                % 6 & 7 are wheel position & time
                Tnum = options.SH{2};
                Lev = options.SH{3};
                Ldist = options.SH{5};
                LTags = [];
                RTags = [];
                Rdist = options.SH{6};
                outcome = options.SH{7};
                try
                    choiceY = options.SH{8};
                    choiceX = options.SH{9};
                    CH = plot(choiceX, choiceY, 'Parent', this.ChoiceAx);
                    this.ChoiceAx.YLim = [-1.1*max(abs(choiceY)) 1.1*max(abs(choiceY))];
                    text(0,0.8,outcome,"Color",'w', 'Units','normalized');
                    text(1,0.8,"L"+string(Lev),"Color",'w', "Parent",this.LStimAx, 'Units','normalized');
                    text(1,0.8,"t"+string(Tnum),"Color",'w', "Parent",this.RStimAx, 'Units','normalized');
                end
            end
            if ~isempty(Ldist)
                this.plotDistractors3(this.LStimAx, Ldist, LTags)
                %this.plotDistractors3(this.LStimAx, Lrej{:}, LTags)
                view(-this.Orient,90)
            end
            if ~isempty(Rdist)
                this.plotDistractors3(this.RStimAx, Rdist, RTags)
                %this.plotDistractors3(this.RStimAx, Rrej{:}, RTags)
                view(-this.Orient,90)
            end
            L = Ldist; R = Rdist;
        end
        function [DISTS, Tags, REJ] = CheckDistractors(this, isLeftStim)
            REJ = {};
            [DISTS, Tags, isCorrect] = this.chooseDistractors(isLeftStim);
            [approve, newAngles] = this.SerialcheckAllDistractors(DISTS);
            if ~approve
                REJ{end+1} = DISTS;
                DISTS(:,3) = newAngles;
            end
        end
        function [DISTS, Tags, isCorrect] = chooseDistractors(this, isLeftStim)
            %This fcn randomly picks the locations and angles of the distractors indicated by the current level
            if this.isLeftTrial && isLeftStim
                isCorrect = 1;
                this.LStimAx.Tag = 'Left Correct';
                this.RStimAx.Tag = 'Right Inorrect';
            elseif ~this.isLeftTrial && ~isLeftStim
                isCorrect = 1;
                this.RStimAx.Tag = 'Right Correct';
                this.LStimAx.Tag = 'Left InCorrect';
            else
                isCorrect = 0;
            end
            if isCorrect
                W = 2;
            else
                W = 1;
            end
            numDs = this.numDistractorsTable(this.Level,W);
            if isCorrect %Plot the correct stim with 5 line segments:
                contourNodesIdx = logical(this.ContourNodes(:,1) == 0);
                contourNodes = this.ContourNodes(contourNodesIdx,:); %Contour nodes are those where X = 0 [this can be modified]
                nonContourNodes = this.ContourNodes(~contourNodesIdx,:); %Non contour nodes are those where X =/= 0 [this can be modified]
            else % incorrect side
                nonContourNodes = this.ContourNodes; %If this is not the target figure, then nonContour = all nodes
            end
            %Randomly selects a few (#nDistractors) nonContourNodes
            selectedNodesIndex = randperm(length(nonContourNodes),numDs);
            selectedNodes = nonContourNodes(selectedNodesIndex,:);
            selectedAngle = randi(180,numDs,1); %Randomly selects angles for the bars %Use 180 because of symmetry
            Tags = repmat("Distractor",numDs,1);
            if isCorrect
                randomLines = [selectedNodes selectedAngle];
                CONTOUR = [contourNodes repmat(90, 5, 1)];
                Tags = [Tags ; repmat("Contour",5,1)];
                Dist = [sortrows(randomLines) ; CONTOUR];
            else % incorrect side
                Dist = sortrows([selectedNodes selectedAngle]);
            end
            DISTS = Dist;
        end
        function plotDistractors3(this, theAxis, Dists, Tags, options)
            arguments
                this
                theAxis
                Dists
                Tags
                options.OrdPair logical = false
            end
            if isempty(Tags)
                Tags = strings(size(Dists,1),1);
            end
            try
                [theAxis.Children(:).Visible] = deal(1);
                dc = 0;
                for D = Dists' %Creates the coordinates of the bar tip centered in [0,0]
                    dc = dc+1;
                    [Tip1X, Tip1Y] = pol2cart(deg2rad(D(3)), this.SegLength/2); %Creates coords of a semi bar starting from 0,0
                    [Tip2X, Tip2Y] = pol2cart(deg2rad(D(3) + 180), this.SegLength/2); %Creates the other half-bar
                    xCoordinates = [D(1) + Tip1X, D(1) + Tip2X]; %Adds the coords from the nodes and half bars
                    yCoordinates = [D(2) + Tip1Y, D(2) + Tip2Y];
                    plot(xCoordinates, yCoordinates,'Color', [this.LineColor],'LineWidth',this.SegThick, 'Parent', theAxis, 'Tag', Tags(dc))
                    if options.OrdPair
                        TXT = "["+D(1)+","+D(2)+"]";
                        text(D(1), D(2), TXT,"Color","w", 'Parent', theAxis, "HorizontalAlignment","center", "VerticalAlignment","middle")
                    end
                end
            catch err
                err;
            end
        end
        function [A, newAngles] = SerialcheckAllDistractors(this, In, tol)
            arguments
                this
                In
                tol = 20
            end
            In(:,[1 2]) = round(In(:,[1 2]),0);
            A = 1;
            newAngles = In(:,3);
            %return
    %Check for visual continuity:
        %Lines of 5:
            CenterColIdx = [0,52;0,26;0,0;0,-26;0,-52];
            LDiagIdx = [-45,26;-23,13;0,0;23,-13;45,-26];
            RDiagIdx = LDiagIdx.*-1;
        %Lines of 4:
            Q1 = [-23,39;0,26;23,13;45,0];
            Q2 = [45,0;23,-13;0,-26;-23,-39];
            Q3 = Q1 .* -1;
            Q4 = Q2 .* -1;
            L4 = [-23,39;-23,13;-23,-13;-23,-39];
            R4 = L4 .* -1;
        %Lines of 3:
            Rtop = [0,52;23,39;45,26];
            Rmiddle = [45,26;45,0;45,-26];
            Rbottom = [45,-26;23,-39;0,-52];
            Ltop = Rbottom .* -1;
            Lmiddle = Rmiddle .* -1;
            Lbottom = Rtop .* -1;
            ic = 0;
            %Positive angles are in the counter-clockwise rotation direction
            c = 0;
            AngTbl = [-60, 60, 30, 30, 60, 30, 60, 30, 60, 30, 90, 90, 90, 90, 90]; %if the line's angle is within tol of any of these remake that angle
            for i = {Rtop, Rbottom, Ltop, Lbottom, Q1, Q2 ,Q3 , Q4, LDiagIdx, RDiagIdx, Rmiddle, Lmiddle, L4, R4, CenterColIdx} %order is important
                ic = ic+1;
                w = ismember(In(:,[1 2]), i{:}, 'rows');
                Angs = newAngles(w);
                Idxs = In(w,[1 2]);
                if all(Angs == 90)
                    continue
                end
                for a = 1:(length(Angs)-1)
                    if Angs(a) == 90 %To avoid messing with the correct line segment just skip any that are 90
                        continue
                    end
                    if abs(Angs(a+1)-Angs(a))<=tol %check 2nd away
                        c = c+1;
                        if A == 1;A = 0;end
                        wAng = ismember(In(:,[1 2]), Idxs(a,[1 2]), 'rows');
                        randomSign = randi([1,2]); % Randomly make adjustment offset + or -
                        if randomSign == 2
                            randomSign = -1;
                        end
                        offset = randomSign*(tol+floor((45-tol)*rand));
                        newAngles(wAng) = newAngles(wAng)+offset;
                    end
                    Angs = newAngles(w); %Update to make sure algorithm is considering the newly adjusted angles
                end
            end
            %fprintf('Corrected %d\n',c)
        end
    end
end
% This is the most used one, currently WBS
function [L,R] = ShowStimulusContour_Density(this)
% in this stimulus instead of training by gradual increase between line
% segments contrast with background we use gradual increase of line
%     set(groot,'CurrentFigure',100)
%     set(gcf,'MenuBar','none');
distractorsTable = this.numDistractorsTable(this.Level,:);
if this.isLeftTrial
    whichDistractor = 2;
else
    whichDistractor = 1;
end
Ldist = chooseDistractors(this, 1);
plotDistractors3(this, this.LStimAx, Ldist)
%L = plotDistractors2(this, 1, this.isLeftTrial, distractorsTable(whichDistractor));
view(-this.Orient,90)
%Make second stimulus
if this.isLeftTrial %OPPOSITE from above, bc other side
    whichDistractor = 1;
else
    whichDistractor = 2;
end
Rdist = chooseDistractors(this, 0);
plotDistractors3(this, this.RStimAx, Rdist)
%R = plotDistractors2(this, 0, ~this.isLeftTrial, distractorsTable(whichDistractor)); %Right Stim, 0 distractors
view(-this.Orient,90)
%set(this.fig,'OuterPosition',this.figpos); %move window here, also determines size
L = Ldist; R = Rdist;
end
function DISTS = chooseDistractors(this, isLeftStim)
%This fcn randomly picks the locations and angles of the distractors indicated by the current level
if this.isLeftTrial && isLeftStim
    W = 2;
else
    W = 1;
end
numDs = this.numDistractorsTable(this.Level,W);
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
if W == 2 %Plot the correct stim with 5 line segments:
    contourNodesIdx = logical(listGridNodes(:,1) == 0) & sqrt( listGridNodes(:,1).^2 + listGridNodes(:,2).^2) <= (this.SegLength+this.SegSpacing) * this.ContLength/2;
    contourNodes = listGridNodes(contourNodesIdx,:); %Contour nodes are those where X = 0 [this can be modified]
    nonContourNodes = listGridNodes(~contourNodesIdx,:); %Non contour nodes are those where X =/= 0 [this can be modified]
    for i = 1:size(contourNodes,1) %Creates the coordinates of the bar tip centered in [0,0]
        [Tip1X, Tip1Y] = pol2cart(deg2rad(90), this.SegLength/2);
        [Tip2X, Tip2Y] = pol2cart(deg2rad(90 + 180), this.SegLength/2);
        xCoordinates = [contourNodes(i,1) + Tip1X, contourNodes(i,1) + Tip2X];
        yCoordinates = [contourNodes(i,2) + Tip1Y, contourNodes(i,2) + Tip2Y];
        %plot(xCoordinates, yCoordinates, 'Color', [this.LineColor], 'LineWidth',this.SegThick, 'Parent', theAxis, 'Tag', 'Contour')
    end
else
    nonContourNodes = listGridNodes; %If this is not the target figure, then nonContour = all nodes
end
%Randomly selects a few (#nDistractors) nonContourNodes
selectedNodesIndex = randperm(length(nonContourNodes),numDs);
selectedNodes = nonContourNodes(selectedNodesIndex,:);
selectedAngle = randi(180,numDs,1); %Randomly selects angles for the bars %Use 180 because of symmetry
if W == 2
    selectedNodes = [selectedNodes ; contourNodes];
    Dist = [selectedNodes [selectedAngle ; repmat(90, 5, 1)] ];
else
    Dist = [selectedNodes selectedAngle];
end
DISTS = Dist;
end
function plotDistractors3(this, theAxis, Dists)
[theAxis.Children.Visible] = deal(1);
for D = Dists' %Creates the coordinates of the bar tip centered in [0,0]
    [Tip1X, Tip1Y] = pol2cart(deg2rad(D(3)), this.SegLength/2); %Creates coords of a semi bar starting from 0,0
    [Tip2X, Tip2Y] = pol2cart(deg2rad(D(3) + 180), this.SegLength/2); %Creates the other half-bar
    xCoordinates = [D(1) + Tip1X, D(1) + Tip2X]; %Adds the coords from the nodes and half bars
    yCoordinates = [D(2) + Tip1Y, D(2) + Tip2Y];
    plot(xCoordinates, yCoordinates,'Color', [this.LineColor],'LineWidth',this.SegThick, 'Parent', theAxis, 'Tag', 'Distractor')
end
end
function [Dist] = plotDistractors2(this, LeftStim, isCorrect, numDistractors)
% SANTI 10-1-2020
%Setup:
if isCorrect
    tag = 'Correct';
else
    tag = 'Incorrect';
end
if LeftStim
    theAxis = this.LStimAx;
    side = 'Left';
else
    theAxis = this.RStimAx;
    side = 'Right';
end
theAxis.Tag = [side ' ' tag];
[theAxis.Children.Visible] = deal(1);
%Creates triangular grid
gridWidth = (this.SegLength+this.SegSpacing)*this.ContLength;
maskRadius = gridWidth/2;
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
        plot(xCoordinates, yCoordinates, 'Color', [this.LineColor], 'LineWidth',this.SegThick, 'Parent', theAxis, 'Tag', 'Contour')
        hold on
    end
else
    nonContourNodes = listGridNodes; %If this is not the target figure, then nonContour = all nodes
end
%Randomly selects a few (#nDistractors) nonContourNodes
selectedNodesIndex = randperm(length(nonContourNodes),numDistractors);
selectedNodes = nonContourNodes(selectedNodesIndex,:);
selectedAngle = randi(180,numDistractors,1); %Randomly selects angles for the bars %Use 180 because of symmetry
if numDistractors > 0
    for i = 1:numDistractors %Creates the coordinates of the bar tip centered in [0,0]
        [Tip1X, Tip1Y] = pol2cart(deg2rad(selectedAngle(i)), this.SegLength/2); %Creates coords of a semi bar starting from 0,0
        [Tip2X, Tip2Y] = pol2cart(deg2rad(selectedAngle(i) + 180), this.SegLength/2); %Creates the other half-bar
        xCoordinates = [selectedNodes(i,1) + Tip1X, selectedNodes(i,1) + Tip2X]; %Adds the coords from the nodes and half bars
        yCoordinates = [selectedNodes(i,2) + Tip1Y, selectedNodes(i,2) + Tip2Y];
        plot(xCoordinates, yCoordinates,'Color', [this.LineColor],'LineWidth',this.SegThick, 'Parent', theAxis, 'Tag', 'Distractor')
        hold on
    end
end
view(-this.Orient,90)
if isCorrect
    selectedNodes = [selectedNodes ; contourNodes];
    Dist = [selectedNodes [selectedAngle ; repmat(90, 5, 1)] ];
else
    Dist = [selectedNodes selectedAngle];
end
end
function getRect(this, ax)
rectangle('Parent', ax, ...
    'Position', [-(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 -(this.SegLength+this.SegSpacing+5)*this.ContLength*0.5 (this.SegLength+this.SegSpacing+5)*this.ContLength (this.SegLength+this.SegSpacing+5)*this.ContLength], ...
    'Curvature', [1 1], 'FaceColor', [this.SpotlightColor], 'EdgeColor', 'none', 'Tag', 'Spotlight');
end
%Functions below here are not updated and may have bugs
function ShowStimulusSquare(trialID, opacity, display, winheight,winwidth,winx,winy,crudetoggle,Orient)
fig1=figure(100);
%show yes or no
if display==1
    if crudetoggle==0
        %fine
        %         ContLength=3; % length of contour
        %         ContLengthHalf=ceil(ContLength/2); %half of the contour
        %         PatchSize=11; % size of patch, pick uneven
        %         PatchSizeHalf=floor(PatchSize/2); %half of the patch
        %         SegmLength=1.2; %length of sements
        %         BinSize=2; %size of bins
        %         SegmThick=7; %line thickness9
        %         SegmJitter= 0.3;% jitter of segments
        ContLength=3; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=9; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=9; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    else
        %crude
        ContLength=3; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=9; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=9; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    end
    Alpha=-25; %determines closeness of contour elements, set somewhere between [-30 30]
    %see Li && Gilbert 2002
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
            if i==j  && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments (take center colum and then go along that)
                angle=45;
                X=[-SegmLength*0.1 SegmLength*0.9];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j-1  && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments (take center colum and then go along that)
                angle=45;
                X=[-SegmLength*0.85 SegmLength*0.15];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j+1  && i>-ContLengthHalf+1 &&i<ContLengthHalf+1 %for contour segments (take center colum and then go along that)
                angle=45;
                % X=[-(SegmLength*0.4)+SegmLength (SegmLength*0.6)+SegmLength];
                X=[-(SegmLength*0.8) (SegmLength*0.2)];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-SegmLength/2 SegmLength/2]+JX;
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
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end
    hold on

    % Draw segments grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            if i==j  && i>-ContLengthHalf &&i<ContLengthHalf && i~=ContLengthHalf %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            elseif i==j-1  && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            elseif i==j+1  && i>-ContLengthHalf+1 &&i<ContLengthHalf+1 %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
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

    %
    % if trialID==1
    % view(-Orient/Alpha,90)
    % else
    %     view(-Orient+45/Alpha,90)
    % end
    view(-Orient/Alpha,90)
    %     xlim([-Radius*0.8 Radius*0.8])
    %     ylim([-Radius*0.8 Radius*0.8])
    xlim([-Radius Radius])
    ylim([-Radius Radius])
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
            if i==j  && i>-ContLengthHalf &&i<ContLengthHalf && i  %for contour segments (take center colum and then go along that)
                angle=45;
                X=[-SegmLength*0.1 SegmLength*0.9];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif  i==j  && i>-ContLengthHalf &&i<ContLengthHalf %make sure the center of O is not randomly filling patch (avoid 45)
                angle=rand*155+75;
                JX=SegmJitter*2*(rand-0.7); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.4);
                X=[-SegmLength*0.1 SegmLength*0.9]+JX-0.17;
                Y=[0 0]-JY-0.4;
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j-1  && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments (take center colum and then go along that)
                angle=45;
                X=[-SegmLength*0.85 SegmLength*0.15];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j+1  && i>-ContLengthHalf+1 &&i<ContLengthHalf+1 %for contour segments (take center colum and then go along that)
                angle=45;
                % X=[-(SegmLength*0.4)+SegmLength (SegmLength*0.6)+SegmLength];
                X=[-(SegmLength*0.8) (SegmLength*0.2)];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-SegmLength/2 SegmLength/2]+JX;
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
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end
    hold on

    % Draw segments grid as center

    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            if i==j  && i>-ContLengthHalf &&i<ContLengthHalf && i~=ContLengthHalf && i~=0%for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            elseif i==j-1  && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            elseif i==j+1  && i>-ContLengthHalf+1 &&i<ContLengthHalf+1 %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
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

    %
    % if trialID==1
    % view(-Orient/Alpha,90)
    % else
    %     view(-Orient+45/Alpha,90)
    % end
    view(-Orient/Alpha,90)

    %     xlim([-Radius*0.8 Radius*0.8])
    %     ylim([-Radius*0.8 Radius*0.8])

    xlim([-Radius Radius])
    ylim([-Radius Radius])

    pause(0.001);

    positionfig=[winx winy winwidth winheight];

    set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
else
    close(fig1);
end
end
function ShowStimulusContour(trialID, opacity, display, winheight,winwidth,winx,winy,crudetoggle,Orient)
fig1=figure(100);
if display==1
    if crudetoggle==0
        %fine
        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=9; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.5; %length of sements
        BinSize=2; %size of bins
        SegmThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    else
        %crude
        ContLength=6; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=11; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of segments
        BinSize=2; %size of bins
        SegmThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    end
    Alpha=-25; %determines closeness of contour elements, set somewhere between [-30 30]
    %see Li && Gilbert 2002
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
    %     Draw background with the grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            angle=rand*180;
            if i==j && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments
                angle=45;
                X=[-SegmLength/2 SegmLength/2];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-SegmLength/2 SegmLength/2]+JX;
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
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end
    hold on
    % Draw segments grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf

            if i==j && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments
                angle=45;
                X=[-SegmLength/2 SegmLength/2];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
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
    axis tight; axis square; axis off
    view(-Orient/Alpha,90)
    %     xlim([-Radius*0.8 Radius*0.8])
    %     ylim([-Radius*0.8 Radius*0.8])
    xlim([-Radius Radius])
    ylim([-Radius Radius])
    % print -dbmp LiStim1
    % SECOND PART OF FIGURE%
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
            X=[-SegmLength/2 SegmLength/2]+JX;
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
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end
    hold on
    hold off
    %     plot mask, upper and lower part separate
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
    view(-Orient/Alpha,90)
    %     xlim([-Radius*0.8 Radius*0.8])
    %     ylim([-Radius*0.8 Radius*0.8])
    xlim([-Radius Radius])
    ylim([-Radius Radius])
    set(gcf,'MenuBar','none');
    axis off
    positionfig=[winx winy winwidth winheight];
    %positionfig=[1600 50 500 450];
    set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
    %notusedyet=borderwidth;
else
    close(fig1);
end
end
function ShowStimulusBBTrainingDensity(this)
% in this stimulus instead of training by gradual increase between line
% segments contrast with background we use gradual increase of line
set(groot,'CurrentFigure',100)
hold on
set(gcf,'MenuBar','none');
distractorsTable = this.numDistractorsTable(this.opacity,:);
if this.isLeftTrial
    whichDistractor = 2;
else
    whichDistractor = 1;
end
%plotDistractors2(this, LeftStim, isCorrect, numDistractors)
plotDistractors2(this, this.isLeftTrial, 1, distractorsTable(whichDistractor))
view(-this.Orient,90)
set(groot,'CurrentFigure',100)
hold off
positionfig=[this.winx this.winy this.winwidth this.winheight];
set(groot,'CurrentFigure',100)
set(gcf,'OuterPosition',positionfig); %move window here, also determines size
end
function ShowStimulusPsychometricContour(trialID, opacity, display, winheight,winwidth,winx,winy,crudetoggle,Orient)
fig1=figure(100);
if display==1


    if crudetoggle==0
        %fine

        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=9; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments

    else
        %crude

        ContLength=9-(opacity*20)-1; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=11; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=9; %line thickness9
        SegmJitter= 0.3;% jitter of segments

    end

    opacity = 1;

    Alpha=-25; %determines closeness of contour elements, set somewhere between [-30 30]
    %see Li && Gilbert 2002
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
            if i==j && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments
                angle=45;
                X=[-SegmLength/2 SegmLength/2];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-SegmLength/2 SegmLength/2]+JX;
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
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end

    hold on

    % Draw segments grid as center

    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf

            if i==j && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments
                angle=45;
                X=[-SegmLength/2 SegmLength/2];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            end
        end

    end




    maskOff(PatchSize,PatchSizeHalf,BinSize,Orient,Alpha)

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
            X=[-SegmLength/2 SegmLength/2]+JX;
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
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end


    maskOff(PatchSize,PatchSizeHalf,BinSize,Orient,Alpha)
    set(gcf,'MenuBar','none');
    positionfig=[winx winy winwidth winheight];

    set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
    %notusedyet=borderwidth;
else

    close(fig1);

end

end
function ShowStimulusContourDistractor(trialID, opacity, display, winheight,winwidth,winx,winy,crudetoggle,Orient)
fig1=figure(100);
if display==1


    diffic = opacity*10;
    opacity = 1;

    if crudetoggle==0
        %fine

        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=9; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments

    else
        %crude

        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=11; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=9; %line thickness9
        SegmJitter= 0.3;% jitter of segments

    end





    Alpha=-25; %determines closeness of contour elements, set somewhere between [-30 30]
    %see Li && Gilbert 2002
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
            if i==j && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments
                angle=45;
                X=[-SegmLength/2 SegmLength/2];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-SegmLength/2 SegmLength/2]+JX;
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
            if  floor(rand*10) < diffic
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
            end
        end
    end

    hold on

    % Draw segments grid as center

    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf

            if i==j && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments
                angle=45;
                X=[-SegmLength/2 SegmLength/2];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            end
        end

    end


    maskOff(PatchSize,PatchSizeHalf,BinSize,Orient,Alpha)
    %     hold off
    %
    %
    %
    %     %plot mask, upper and lower part separate
    %     NumPoints=100;
    %     Radius=(PatchSizeHalf-2)*BinSize;
    %     Theta=linspace(0,pi,NumPoints); %100 evenly spaced points between 0 and pi
    %     Rho=ones(1,NumPoints)*Radius; %Radius should be 1 for all 100 points
    %     [X,Y] = pol2cart(Theta,Rho);
    %     X(101)=-PatchSize*2;
    %     Y(101)=0;
    %     X(102)=-PatchSize*2;
    %     Y(102)=PatchSize*2;
    %     X(103)=PatchSize*2;
    %     Y(103)=PatchSize*2;
    %     X(104)=PatchSize*2;
    %     Y(104)=0;
    %     patch(X,Y,'k');
    %     Theta=linspace(0,-pi,NumPoints); %100 evenly spaced points between 0 and -pi
    %     [X,Y] = pol2cart(Theta,Rho);
    %     X(101)=-PatchSize*2;
    %     Y(101)=0;
    %     X(102)=-PatchSize*2;
    %     Y(102)=-PatchSize*2;
    %     X(103)=PatchSize*2;
    %     Y(103)=-PatchSize*2;
    %     X(104)=PatchSize*2;
    %     Y(104)=0;
    %     patch(X,Y,'k');
    %
    %     axis tight; axis square

    %
    % if trialID==1
    % view(-Orient/Alpha,90)
    % else
    %     view(-Orient+45/Alpha,90)
    % end
    view(-Orient/Alpha,90)

    %     xlim([-Radius*0.8 Radius*0.8])
    %     ylim([-Radius*0.8 Radius*0.8])

    xlim([-Radius Radius])
    ylim([-Radius Radius])

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
            X=[-SegmLength/2 SegmLength/2]+JX;
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
            if  floor(rand*10) < diffic

                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
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
    view(-Orient/Alpha,90)
    %     xlim([-Radius*0.8 Radius*0.8])
    %     ylim([-Radius*0.8 Radius*0.8])
    xlim([-Radius Radius])
    ylim([-Radius Radius])

    set(gcf,'MenuBar','none');


    positionfig=[winx winy winwidth winheight];


    %positionfig=[1600 50 500 450];
    set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
    %notusedyet=borderwidth;
else

    close(fig1);

end

end
function ShowStimulusContourTraining(unused, opacity, display, winheight,winwidth,winx,winy,crudetoggle,Orient)
fig1=figure(100);
if display==1
    if crudetoggle==0
        %fine

        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=9; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments

    else
        %crude

        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=11; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=9; %line thickness9
        SegmJitter= 0.3;% jitter of segments

    end





    Alpha=-25; %determines closeness of contour elements, set somewhere between [-30 30]
    %see Li && Gilbert 2002
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
            if i==j && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments
                angle=45;
                X=[-SegmLength/2 SegmLength/2];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-SegmLength/2 SegmLength/2]+JX;
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


    %both sides
    for sides = 1:2

        if sides == 1
            subplot(1,2,1);
        else
            subplot(1,2,2);
        end


        set(gca,'color','black')
        set(gcf,'color','black')

        hold on;

        for i=-PatchSizeHalf:PatchSizeHalf
            for j=-PatchSizeHalf:PatchSizeHalf
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
            end
        end

        hold on

        % Draw segments grid as center

        for i=-PatchSizeHalf:PatchSizeHalf
            for j=-PatchSizeHalf:PatchSizeHalf

                if i==j && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments
                    angle=45;
                    X=[-SegmLength/2 SegmLength/2];
                    Y=[0 0];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);
                    plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
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

        %
        % if trialID==1
        % view(-Orient/Alpha,90)
        % else
        %     view(-Orient+45/Alpha,90)
        % end
        view(-Orient/Alpha,90)

        %         xlim([-Radius*0.8 Radius*0.8])
        %         ylim([-Radius*0.8 Radius*0.8])

        xlim([-Radius Radius])
        ylim([-Radius Radius])

        % print -dbmp LiStim1
    end


    positionfig=[winx winy winwidth winheight];


    %positionfig=[1600 50 500 450];
    set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
    %notusedyet=borderwidth;
else

    close(fig1);

end

end
function ShowStimulusOnePatchContour(this, trialID, opacity, display,winheight,winwidth,winx,winy,crudetoggle, Orient)
if crudetoggle==0
    %fine
    ContLength=7; % length of contour
    ContLengthHalf=ceil(ContLength/2); %half of the contour
    PatchSize=9; % size of patch, pick uneven
    PatchSizeHalf=floor(PatchSize/2); %half of the patch
    SegmLength=1.2; %length of sements
    BinSize=2; %size of bins
    SegmThick=7; %line thickness9
    SegmJitter= 0.3;% jitter of segments
else
    %crude
    ContLength=7; % length of contour
    ContLengthHalf=ceil(ContLength/2); %half of the contour
    PatchSize=11; % size of patch, pick uneven
    PatchSizeHalf=floor(PatchSize/2); %half of the patch
    SegmLength=1.2; %length of sements
    BinSize=2; %size of bins
    SegmThick=9; %line thickness9
    SegmJitter= 0.3;% jitter of segments
end
fig1=figure(100);
%show yes or no
if display==1
    Alpha=-25; %determines closeness of contour elements, set somewhere between [-30 30]
    %see Li && Gilbert 2002
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
                if i==j && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments
                    angle=45;
                    X=[-SegmLength/2 SegmLength/2];
                    Y=[0 0];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);
                else
                    JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                    JY=SegmJitter*2*(rand-0.5);
                    X=[-SegmLength/2 SegmLength/2]+JX;
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
        % figu=subplot(1,2,2);
        % else
        % subplot(1,2,1);
        % end
        set(gca,'color','black')
        set(gcf,'color','black')
        hold on;
        for i=-PatchSizeHalf:PatchSizeHalf
            for j=-PatchSizeHalf:PatchSizeHalf
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
            end
        end
        hold on
        % Draw segments grid as center
        for i=-PatchSizeHalf:PatchSizeHalf
            for j=-PatchSizeHalf:PatchSizeHalf
                if i==j && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments
                    angle=45;
                    X=[-SegmLength/2 SegmLength/2];
                    Y=[0 0];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);
                    plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
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
        %
        % if trialID==1
        % view(-Orient/Alpha,90)
        % else
        %     view(-Orient+45/Alpha,90)
        % end
        view(-Orient/Alpha,90)
        %         xlim([-Radius*0.8 Radius*0.8])
        %         ylim([-Radius*0.8 Radius*0.8])
        xlim([-Radius Radius])
        ylim([-Radius Radius])
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
                X=[-SegmLength/2 SegmLength/2]+JX;
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
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
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
        %         xlim([-Radius*0.8 Radius*0.8])
        %         ylim([-Radius*0.8 Radius*0.8])
        xlim([-Radius Radius])
        ylim([-Radius Radius])
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
function ShowStimulusTwoTaskCircle(trialID, opacity, display, winheight,winwidth,winx,winy,crudetoggle,Orient)


fig1=figure(100);
if display==1

    if crudetoggle==0
        %fine

        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=9; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments

    else
        %crude

        ContLength=3; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=13; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments

    end



    Alpha=-25; %determines closeness of contour elements, set somewhere between [-30 30]
    %see Li && Gilbert 2002
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

    % Draw CIRCLE
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            angle=rand*180;

            if i==j  && i==ContLengthHalf-2 %for contour segments (take center colum and then go along that)
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);


                X=[-SegmLength*0.1-0.7 SegmLength*0.9-0.7];
                Y=[-0.5 -0.5];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);

            elseif i==j  && i>-ContLengthHalf &&i<ContLengthHalf && i  %for contour segments (take center colum and then go along that)
                angle=110;
                X=[-SegmLength*0.1-0.7 SegmLength*0.9-0.7];
                Y=[-0.5 -0.5];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);


            elseif  i==j  && i>-ContLengthHalf &&i<ContLengthHalf %make sure the center of O is not  rand_array(1,rand_index)omly filling patch (avoid 45)

                angle= 155+75;
                X=[-SegmLength*0.1 SegmLength*0.9]+JX-0.17;
                Y=[0 0]-JY-0.4;
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi;
                [X,Y] = pol2cart(Theta,Rho);




            elseif i==j-1  && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments (take center colum and then go along that)
                if i == - ContLengthHalf+1
                    angle=82;
                    X=[-SegmLength*0.85-0.14 SegmLength*0.15-0.14];
                    Y=[-0.4 -0.4];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);

                elseif   i == ContLengthHalf-1
                    angle=140;
                    X=[-SegmLength*0.85+0.5 SegmLength*0.15+0.5];
                    Y=[1 1];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);

                else
                    angle=45;
                    X=[-SegmLength*0.85 SegmLength*0.15];
                    Y=[0 0];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);
                end

            elseif i==j+1  && i>-ContLengthHalf+1 &&i<ContLengthHalf+1 %for contour segments (take center colum and then go along that)
                if i ==  -ContLengthHalf+2
                    angle=140;
                    X=[-SegmLength*0.85+0.57 SegmLength*0.15+0.57];
                    Y=[-0.2 -0.2];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);

                elseif   i == ContLengthHalf-1
                    angle=45;
                    X=[-SegmLength*0.85-0.1 SegmLength*0.15-0.1];
                    Y=[-0.28 -0.28];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);

                else
                    angle=80;
                    X=[-SegmLength*0.85-0.02 SegmLength*0.15-0.02];
                    Y=[0.9 0.9];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);
                end

            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-SegmLength/2 SegmLength/2]+JX;
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
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end

    hold on

    % Draw CIRCLE

    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf



            if i==j  && i>-ContLengthHalf &&i<ContLengthHalf && i~=ContLengthHalf && i~=0%for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)


            elseif i==j-1  && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments (take center colum and then go along that)

                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)


            elseif i==j+1  && i>-ContLengthHalf+1 &&i<ContLengthHalf+1 %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)


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
    % if trialID==1
    % view(-Orient/Alpha,90)
    % else
    %     view(-Orient+45/Alpha,90)
    % end
    view(-Orient/Alpha,90)
    %     xlim([-Radius*0.8 Radius*0.8])
    %     ylim([-Radius*0.8 Radius*0.8])
    xlim([-Radius Radius])
    ylim([-Radius Radius])
    % print -dbmp LiStim1
    % SECOND PART OF FIGURE%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
            if i==j+2  && i==ContLengthHalf  %for contour segments (take center colum and then go along that)
                angle=1;
                % X=[-(SegmLength*0.4)+SegmLength (SegmLength*0.6)+SegmLength];
                X=[-(SegmLength*0.8) (SegmLength*0.2)];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j+1  && i==ContLengthHalf-1  %for contour segments (take center colum and then go along that)
                angle=1;
                % X=[-(SegmLength*0.4)+SegmLength (SegmLength*0.6)+SegmLength];
                X=[-(SegmLength*0.8) (SegmLength*0.2)];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j  && i==ContLengthHalf-2  %for contour segments (take center colum and then go along that)
                angle=1;
                % X=[-(SegmLength*0.4)+SegmLength (SegmLength*0.6)+SegmLength];
                X=[-(SegmLength*0.8) (SegmLength*0.2)];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j-1  && i==ContLengthHalf-3  %for contour segments (take center colum and then go along that)
                angle=1;
                % X=[-(SegmLength*0.4)+SegmLength (SegmLength*0.6)+SegmLength];
                X=[-(SegmLength*0.8) (SegmLength*0.2)];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j-2  && i==ContLengthHalf-4  %for contour segments (take center colum and then go along that)
                angle=1;
                % X=[-(SegmLength*0.4)+SegmLength (SegmLength*0.6)+SegmLength];
                X=[-(SegmLength*0.8) (SegmLength*0.2)];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j-2  && i==ContLengthHalf-2  %for contour segments (take center colum and then go along that)
                angle=90;
                % X=[-(SegmLength*0.4)+SegmLength (SegmLength*0.6)+SegmLength];
                X=[-(SegmLength*0.8) (SegmLength*0.2)];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j-1  && i==ContLengthHalf-2  %for contour segments (take center colum and then go along that)
                angle=90;
                % X=[-(SegmLength*0.4)+SegmLength (SegmLength*0.6)+SegmLength];
                X=[-(SegmLength*0.8) (SegmLength*0.2)];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j+1  && i==ContLengthHalf-2  %for contour segments (take center colum and then go along that)
                angle=90;
                % X=[-(SegmLength*0.4)+SegmLength (SegmLength*0.6)+SegmLength];
                X=[-(SegmLength*0.1) (SegmLength*0.9)];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j+2  && i==ContLengthHalf-2  %for contour segments (take center colum and then go along that)
                angle=90;
                % X=[-(SegmLength*0.4)+SegmLength (SegmLength*0.6)+SegmLength];
                X=[-(SegmLength*0.1) (SegmLength*0.9)];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-SegmLength/2 SegmLength/2]+JX;
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
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end
    hold on
    % Draw segments grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            if i==j+2  && i==ContLengthHalf  %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            elseif i==j+1  && i==ContLengthHalf-1  %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            elseif i==j  && i==ContLengthHalf-2  %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            elseif i==j-1  && i==ContLengthHalf-3  %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            elseif i==j-2  && i==ContLengthHalf-4  %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            elseif i==j-2  && i==ContLengthHalf-2  %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            elseif i==j-1  && i==ContLengthHalf-2  %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            elseif i==j+1  && i==ContLengthHalf-2  %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            elseif i==j+2  && i==ContLengthHalf-2  %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
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

    %     xlim([-Radius*0.8 Radius*0.8])
    %     ylim([-Radius*0.8 Radius*0.8])
    xlim([-Radius Radius])
    ylim([-Radius Radius])
    set(gcf,'MenuBar','none');


    positionfig=[winx winy winwidth winheight];
    %positionfig=[1600 50 500 450];
    set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
    %notusedyet=borderwidth;
else

    close(fig1);

end


end
function ShowStimulusTwoTaskCircleCUE(trialID, opacity, display, winheight,winwidth,winx,winy,crudetoggle,Orient)
fig1=figure(100);
opacity = 0;
color = 'w';
if display==1
    if crudetoggle==0
        %fine
        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=9; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    else
        %crude
        ContLength=3; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=13; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    end
    Alpha=-25; %determines closeness of contour elements, set somewhere between [-30 30]
    %see Li && Gilbert 2002
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
            if i==j  && i>-ContLengthHalf &&i<ContLengthHalf && i  %for contour segments (take center colum and then go along that)
                angle=110;
                X=[-SegmLength*0.1-0.7 SegmLength*0.9-0.7];
                Y=[-0.5 -0.5];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif  i==j  && i>-ContLengthHalf &&i<ContLengthHalf %make sure the center of O is not  rand_array(1,rand_index)omly filling patch (avoid 45)
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-SegmLength*0.1 SegmLength*0.9]+JX-0.17;
                Y=[0 0]-JY-0.4;
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j-1  && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments (take center colum and then go along that)
                if i == - ContLengthHalf+1
                    angle=82;
                    X=[-SegmLength*0.85-0.14 SegmLength*0.15-0.14];
                    Y=[-0.4 -0.4];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);
                elseif   i == ContLengthHalf-1
                    angle=140;
                    X=[-SegmLength*0.85+0.5 SegmLength*0.15+0.5];
                    Y=[1 1];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);
                else
                    angle=45;
                    X=[-SegmLength*0.85 SegmLength*0.15];
                    Y=[0 0];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);
                end
            elseif i==j+1  && i>-ContLengthHalf+1 &&i<ContLengthHalf+1 %for contour segments (take center colum and then go along that)
                if i ==  -ContLengthHalf+2
                    angle=140;
                    X=[-SegmLength*0.85+0.57 SegmLength*0.15+0.57];
                    Y=[-0.2 -0.2];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);
                elseif   i == ContLengthHalf-1
                    angle=45;
                    X=[-SegmLength*0.85-0.1 SegmLength*0.15-0.1];
                    Y=[-0.28 -0.28];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);
                else
                    angle=80;
                    X=[-SegmLength*0.85-0.02 SegmLength*0.15-0.02];
                    Y=[0.9 0.9];
                    [Theta,Rho] = cart2pol(X,Y);
                    Theta=Theta+angle/180*pi/Alpha;
                    [X,Y] = pol2cart(Theta,Rho);
                end
            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-SegmLength/2 SegmLength/2]+JX;
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
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end
    hold on
    % Draw segments grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            if i==j  && i>-ContLengthHalf &&i<ContLengthHalf && i~=ContLengthHalf && i~=0%for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),color,'LineWidth',SegmThick)
            elseif i==j-1  && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),color,'LineWidth',SegmThick)
            elseif i==j+1  && i>-ContLengthHalf+1 &&i<ContLengthHalf+1 %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),color,'LineWidth',SegmThick)
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
    %     xlim([-Radius*0.8 Radius*0.8])
    %     ylim([-Radius*0.8 Radius*0.8])
    xlim([-Radius Radius])
    ylim([-Radius Radius])
    set(gcf,'MenuBar','none');
    positionfig=[winx winy winwidth winheight];
    %positionfig=[1600 50 500 450];
    set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
    %notusedyet=borderwidth;
else
    close(fig1);
end
end
function ShowStimulusTwoTaskContour(trialID, opacity, display, winheight,winwidth,winx,winy,crudetoggle,Orient)
fig1=figure(100);
if display==1
    if crudetoggle==0
        %fine
        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=9; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    else
        %crude
        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=13; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    end
    Alpha=-25; %determines closeness of contour elements, set somewhere between [-30 30]
    %see Li && Gilbert 2002
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
            if i==j && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments
                angle=45;
                X=[-SegmLength/2 SegmLength/2];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-SegmLength/2 SegmLength/2]+JX;
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
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end
    hold on
    % Draw CONTOUR grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            if i==j && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments
                angle=45;
                X=[-SegmLength/2 SegmLength/2];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
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
    %     xlim([-Radius*0.8 Radius*0.8])
    %     ylim([-Radius*0.8 Radius*0.8])
    xlim([-Radius Radius])
    ylim([-Radius Radius])
    % SECOND PART OF FIGURE%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
            if i==j  && i>ContLengthHalf-1 &&i<ContLengthHalf-3  %for contour segments (take center colum and then go along that)
                angle=45;
                X=[-SegmLength*0.1 SegmLength*0.9];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j-1  && i>ContLengthHalf-6 &&i<ContLengthHalf-2%for contour segments (take center colum and then go along that)
                angle=45;
                X=[-SegmLength*0.85 SegmLength*0.15];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            elseif i==j+1  && i>ContLengthHalf-5 &&i<ContLengthHalf-1 %for contour segments (take center colum and then go along that)
                angle=45;
                % X=[-(SegmLength*0.4)+SegmLength (SegmLength*0.6)+SegmLength];
                X=[-(SegmLength*0.8) (SegmLength*0.2)];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-SegmLength/2 SegmLength/2]+JX;
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
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end
    hold on
    % Draw segments grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            if i==j  && i>ContLengthHalf-1 &&i<ContLengthHalf-3  %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            elseif i==j-1  && i>ContLengthHalf-6 &&i<ContLengthHalf-2%for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
            elseif i==j+1  && i>ContLengthHalf-5 &&i<ContLengthHalf-1 %for contour segments (take center colum and then go along that)
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick)
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
    %
    % if trialID==1
    % view(-Orient/Alpha,90)
    % else
    %     view(-Orient+45/Alpha,90)
    % end
    view(-Orient/Alpha,90)
    xlim([-Radius Radius])
    ylim([-Radius Radius])
    %     xlim([-Radius*0.8 Radius*0.8])
    %     ylim([-Radius*0.8 Radius*0.8])
    pause(0.001);
    positionfig=[winx winy winwidth winheight];
    set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
else
    close(fig1);
end
end
function ShowStimulusTwoTaskContourCUE(trialID, opacity, display, winheight,winwidth,winx,winy,crudetoggle,Orient)
fig1=figure(100);
opacity = 0;
color = 'w';
if display==1
    if crudetoggle==0
        %fine
        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=9; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    else
        %crude
        ContLength=7; % length of contour
        ContLengthHalf=ceil(ContLength/2); %half of the contour
        PatchSize=13; % size of patch, pick uneven
        PatchSizeHalf=floor(PatchSize/2); %half of the patch
        SegmLength=1.2; %length of sements
        BinSize=2; %size of bins
        SegmThick=7; %line thickness9
        SegmJitter= 0.3;% jitter of segments
    end
    Alpha=-25; %determines closeness of contour elements, set somewhere between [-30 30]
    %see Li && Gilbert 2002
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
            if i==j && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments
                angle=45;
                X=[-SegmLength/2 SegmLength/2];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
            else
                JX=SegmJitter*2*(rand-0.5); %introduce jitter on non contour segments only
                JY=SegmJitter*2*(rand-0.5);
                X=[-SegmLength/2 SegmLength/2]+JX;
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
            plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),'w','LineWidth',SegmThick,'Color',[1*opacity 1*opacity 1*opacity])
        end
    end
    hold on
    % Draw segments grid as center
    for i=-PatchSizeHalf:PatchSizeHalf
        for j=-PatchSizeHalf:PatchSizeHalf
            if i==j && i>-ContLengthHalf &&i<ContLengthHalf %for contour segments
                angle=45;
                X=[-SegmLength/2 SegmLength/2];
                Y=[0 0];
                [Theta,Rho] = cart2pol(X,Y);
                Theta=Theta+angle/180*pi/Alpha;
                [X,Y] = pol2cart(Theta,Rho);
                plot(SegmX(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),SegmY(:,i+PatchSizeHalf+1,j+PatchSizeHalf+1),color,'LineWidth',SegmThick)
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
    %     xlim([-Radius*0.8 Radius*0.8])
    %     ylim([-Radius*0.8 Radius*0.8])
    xlim([-Radius Radius])
    ylim([-Radius Radius])
    set(gcf,'MenuBar','none');
    positionfig=[winx winy winwidth winheight];
    %positionfig=[1600 50 500 450];
    set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
    %notusedyet=borderwidth;
else
    close(fig1);
end
end
function ShowStimulusGrating(trialID, opacity, display, winheight,winwidth,winx,winy,crudetoggle,Orient)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
fig1=figure(100);
%show yes or no
if display==1
    if crudetoggle==0
        %fine
        %size of bars
        lamd=70;
        %orientation
        thet=Orient;
        %offset of bars
        phas=0.25;
        %contrast
        contras=1-opacity;
        phaseRad = 0;
        %for garbor patch
        sigm=10;
        trim=0.005;
        %patch size
        percentOfScreenSide = 0.3;
        useMask = 1;
    else
        %crude
        %size of bars
        lamd=100;
        %orientation
        thet=Orient;
        %offset of bars
        phas=0.25;
        %contrast
        contras=1-opacity;
        phaseRad = 0;
        %for garbor patch
        sigm=10;
        trim=0.005;
        %patch size
        percentOfScreenSide = 0.2;
        useMask = 1;
    end
    %PART 1
    thet=90;
    X = 1:winwidth;                           % X is a vector from 1 to size
    X0 = (X / winwidth) - .5;                 % rescale X -> -.5 to .5
    freq = winwidth/lamd;                    % compute frequency from wavelength
    [Xm Ym] = meshgrid(X0, X0);             % 2D matrices
    Xf = (Xm * freq * 2*pi);
    thetaRad = ((thet / 360) * 2*pi);        % convert theta (orientation) to radians
    Xt = Xm * cos(thetaRad);                % compute proportion of Xm for given orientation
    Yt = Ym * sin(thetaRad);                % compute proportion of Ym for given orientation
    XYt = [ Xt + Yt ];                      % sum vis.X and Y components
    %these are the stimulus parameters used to display and saved for each
    %object
    grating = sin( Xf + phaseRad);          % make 2D sinewave
    phaseRad = (phas * 2* pi);             % convert to radians: 0 -> 2*pi
    XYf = XYt * freq * 2*pi;                % convert to radians and scale by frequency
    tempFreUse=freq./2.5;
    %the actual grating
    grating = (sin( (XYf+tempFreUse) + phaseRad))*contras;
    %reshape to fit height
    %grating2 = grating(1:end-winwidth-winheight,:);
    if winheight>winwidth
        grating= grating(1:winwidth,:);
    else
        grating= grating(1:winheight,:);
    end
    %set window prameters
    %set(gca,'pos', [0 0 1 1]);               % remove borders from plot
    %set(gcf, 'menu', 'none', 'Color',[.5 .5 .5]); % without background
    %colormap gray(256);                     % use gray colormap (0: black, 1: white)
    %axis off; axis image;    % use gray colormap
    %positionfig=[1600 50 500 450];
    %set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
    %patch
    centerCirclex = floor(winwidth*percentOfScreenSide+winheight*percentOfScreenSide*3);
    centerCircley =  floor(winheight*percentOfScreenSide+winheight*percentOfScreenSide*1.5);
    radius  = floor((winheight)*(percentOfScreenSide*2));
    mask = bsxfun(@plus, ((1:winwidth) - centerCirclex).^2, (transpose(1:winheight) -  centerCircley).^2) < radius^2;
    if useMask == 1
        C=zeros(size(grating));
        C(mask==1)=grating(mask==1);
        grating0 = C;
    else
        grating0 =  grating;
    end
    %PART 2
    thet=0;
    X = 1:winwidth;                           % X is a vector from 1 to size
    X0 = (X / winwidth) - .5;                 % rescale X -> -.5 to .5
    freq = winwidth/lamd;                    % compute frequency from wavelength
    [Xm Ym] = meshgrid(X0, X0);             % 2D matrices
    Xf = (Xm * freq * 2*pi);
    thetaRad = ((thet / 360) * 2*pi);        % convert theta (orientation) to radians
    Xt = Xm * cos(thetaRad);                % compute proportion of Xm for given orientation
    Yt = Ym * sin(thetaRad);                % compute proportion of Ym for given orientation
    XYt = [ Xt + Yt ];                      % sum vis.X and Y components
    %these are the stimulus parameters used to display and saved for each
    %object
    grating = sin( Xf + phaseRad);          % make 2D sinewave
    phaseRad = (phas * 2* pi);             % convert to radians: 0 -> 2*pi
    XYf = XYt * freq * 2*pi;                % convert to radians and scale by frequency
    tempFreUse=freq./2.5;
    %the actual grating
    grating = (sin( (XYf+tempFreUse) + phaseRad))*contras;
    %reshape to fit height
    %grating2 = grating(1:end-winwidth-winheight,:);
    if winheight>winwidth
        grating2= grating(1:winwidth,:);
    else
        grating2= grating(1:winheight,:);
    end
    %set window prameters
    set(gca,'pos', [0 0 1 1]);               % remove borders from plot
    %set(gcf, 'menu', 'none', 'Color',[.5 .5 .5]); % without background
    colormap gray(256);                     % use gray colormap (0: black, 1: white)
    axis off; axis image;    % use gray colormap
    %positionfig=[1600 50 500 450];
    positionfig=[winx winy winwidth winheight];
    %set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
    %patch
    centerCirclex = floor(winwidth*percentOfScreenSide+winheight*percentOfScreenSide*3);
    centerCircley =  floor(winheight*percentOfScreenSide+winheight*percentOfScreenSide*1.5);
    radius  = floor((winheight)*(percentOfScreenSide*2));
    mask = bsxfun(@plus, ((1:winwidth) - centerCirclex).^2, (transpose(1:winheight) -  centerCircley).^2) < radius^2;
    if useMask == 1
        C=zeros(size(grating2));
        C(mask==1)=grating2(mask==1);
        grating2 = C;

    end
    if trialID==1
        imshowpair(grating0, grating2, 'montage')
    else
        imshowpair(grating2, grating, 'montage')
    end
    positionfig=[winx winy winwidth winheight];
    set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
    %imshow(mask);
else
    %hide window
    close(fig1);
end
end
% Cued Images, for pre-rendered rather than generated from Perlin noise
function ShowStimulusImage(trialID, opacity, display, winheight,winwidth,winx,winy,crudetoggle,Orient)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
fig1=figure(100);
%show yes or no
if display==1
    %get side
    if trialID==1
        subfolder = 'right';
    else
        subfolder = 'left';
    end
    % make path
    opac = int2str(opacity*10);
    image_folder_path = ['D:\Box Sync\Gilbert Lab\Wills Box\modified BB\Air Puff!!\BehaviorBox3.1.3\Cue JPEGs\' opac,'\',subfolder];
    %image_folder_path = [opac,'/',subfolder];
    % Pick random image
    %   f = dir( image_folder_path );
    f = dir([image_folder_path '/*.jpg']);
    ridx = randi(numel(f));
    image_name = f(ridx).name;
    % if hidden file, repeat
    %     while image_name(1) == '.'
    %         ridx = randi(numel(f));
    %     image_name = f(ridx).name;
    %     end
    image_path = [image_folder_path,'\',image_name];
    % load image
    current_image = imread(image_path);
    current_image = imresize(current_image,0.5);
    % get size
    [y1,x1,~] = size(current_image);
    % show image
    set(fig1, 'MenuBar', 'none','ToolBar','none');
    %     positionfig=[winx winy x1 y1];
    positionfig=[winx winy x1 y1+30];
    set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
    set(gca,'pos', [0 0 1 1]);               % remove borders from plot
    set(gcf, 'menu', 'none', 'Color',[.5 .5 .5]); % without background
    imshow(current_image);
else
    %hide window
    close(fig1);
end
end
function ShowStimulusImageCUE(trialID, opacity, display, winheight,winwidth,winx,winy,crudetoggle,Orient)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
fig1=figure(100);
%show yes or no
if display==1
    subfolder = 'cue';
    % make path
    opac = int2str(opacity*10);
    image_folder_path = [opac,'/',subfolder];
    % pick random image
    %     f = dir( image_folder_path );
    f = dir([image_folder_path '/*.jpg']);
    ridx = randi(numel(f));
    image_name = f(ridx).name;
    %     image_name = 'Cue.jpg';
    % if hidden file, repeat
    %     while image_name(1) == '.' || image_name(1) == '..' || image_name(1) == 'Thumbs.db'
    %         ridx = randi(numel(f));
    %     image_name = f(ridx).name;
    %     end
    image_path = [image_folder_path,'/',image_name];
    % load image
    current_image = imread(image_path);
    current_image = imresize(current_image,0.5);
    % get size
    [y1,x1,z1] = size(current_image);
    % show image
    set(fig1, 'MenuBar', 'none');
    set(fig1, 'ToolBar', 'none');
    positionfig=[winx winy x1 y1];
    set(fig1,'OuterPosition',positionfig) ;%move window here, also determines size
    imshow(current_image);
else
    %hide window
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
function plotDistractors(Radius,numDistractors,SegmJitter,SegmThick,SegmLength,ContLength,trialID , SegmXa, SegmYa, PatchSize, BinSize, first, BarSeparation, SpotlightToggle, Spotlight, LineShade, Background, InputType)
% SANTI 10-1-2020
%BarSeparation = 13;
set(groot,'CurrentFigure',100)
fig1 = gcf;
SpotlightShade = Spotlight;
LineColor = LineShade;
if first && InputType ~=7 %% FIRST=1 MEANS STIMULUS WITH TARGET
    if trialID == 1
        if InputType == 6
            b = subplot(1,4,[3 4], 'Parent', fig1, 'Tag', 'Correct');
        else
            b = subplot(1,5,[4 5], 'Parent', fig1, 'Tag', 'Correct');
        end
        hold(b,'on')
        if SpotlightToggle %& InputType == 5
            getRect(SpotlightShade, SegmLength, ContLength, BarSeparation);
        end
        if InputType == 5
            pos = [0.5 0 0.5 1];
        elseif InputType == 6
            pos = [0.5 0 0.5 1];
        else
            pos = [0.6 0 0.4 1];
        end
        set(b, 'Position', pos)
    else
        if InputType == 6
            c = subplot(1,4,[1 2], 'Parent', fig1, 'Tag', 'Correct');
        else
            c = subplot(1,5,[1 2], 'Parent', fig1, 'Tag', 'Correct');
        end
        hold(c,'on')
        if SpotlightToggle %& InputType == 5
            getRect(SpotlightShade, SegmLength, ContLength, BarSeparation);
        end
        if InputType == 5
            pos = [0 0 0.5 1];
        elseif InputType == 6
            pos = [0 0 0.5 1];
        else
            pos = [0.0 0 0.4 1];
        end
        set(c, 'Position', pos)
    end
elseif ~first && InputType ~=7
    if trialID == 1
        c = subplot(1,5,[1 2], 'Parent', fig1, 'Tag', 'Incorrect');
        hold(c,'on')
        if SpotlightToggle %& InputType == 5
            getRect(SpotlightShade, SegmLength, ContLength, BarSeparation);
        end
        if InputType == 5
            pos = [0 0 0.5 1];
        elseif InputType == 6
            pos = [0 0 0.5 1];
        else
            pos = [0.0 0 0.4 1];
        end
        set(c, 'Position', pos)
    else
        b = subplot(1,5,[4 5], 'Parent', fig1, 'Tag', 'Incorrect');
        hold(b,'on')
        if SpotlightToggle %& InputType == 5
            getRect(SpotlightShade, SegmLength, ContLength, BarSeparation);
        end
        if InputType == 5
            pos = [0.5 0 0.5 1];
        elseif InputType == 6
            pos = [0.5 0 0.5 1];
        else
            pos = [0.6 0 0.4 1];
        end
        set(b, 'Position', pos)
    end
elseif InputType == 7
    a = subplot(1,1,1, 'Parent', fig1);
    getRect(SpotlightShade, SegmLength, ContLength, BarSeparation);
    %pos = [0.5 0 0.5 1];
    %set(a, 'Position', pos)
end
gridWidth = (SegmLength+BarSeparation)*ContLength;
maskRadius = gridWidth/2;
%Creates triangular grid
X = [-(gridWidth):SegmLength+BarSeparation:gridWidth];
Y = [-(gridWidth):SegmLength+BarSeparation:gridWidth] .* (sqrt(3) / 2); %Since it's triangular, we need to correct some distances
[X,Y] = meshgrid(X,Y);
X(1:2:length(X),:) = X(1:2:length(X),:) + 0.5*(SegmLength+BarSeparation); %Every other row gets displaced to the right
Mask = ( X.^2 + Y.^2) <= maskRadius^2; %Circular mask made with logical values
%Creates a 2 column list of all the grid nodes. Turns the grid 90°
listGridNodes = [Y(Mask) X(Mask)]; %By using X=Y and Y=X, we are effectively turning the grid 90°
if first
    contourNodesIdx = logical(listGridNodes(:,1) == 0) & sqrt( listGridNodes(:,1).^2 + listGridNodes(:,2).^2) <= (SegmLength+BarSeparation) * ContLength/2;
    contourNodes = listGridNodes(contourNodesIdx,:); %Contour nodes are those where X = 0 [this can be modified]
    nonContourNodes = listGridNodes(~contourNodesIdx,:); %Non contour nodes are those where X =/= 0 [this can be modified]
    for i = 1:size(contourNodes,1)
        %Creates the coordinates of the bar tip centered in [0,0]
        [Tip1X, Tip1Y] = pol2cart(deg2rad(90), SegmLength/2);
        [Tip2X, Tip2Y] = pol2cart(deg2rad(90 + 180), SegmLength/2);
        xCoordinates = [contourNodes(i,1) + Tip1X, contourNodes(i,1) + Tip2X];
        yCoordinates = [contourNodes(i,2) + Tip1Y, contourNodes(i,2) + Tip2Y];
        plot(xCoordinates, yCoordinates, 'Color', [LineShade LineShade LineShade], 'LineWidth',SegmThick)
        hold on
    end
else
    %If this is not the target figure, then nonContour = all nodes
    nonContourNodes = listGridNodes;
end
%Randomly selects a few (#nDistractors) nonContourNodes
selectedNodesIndex = randperm(length(nonContourNodes),numDistractors);
selectedNodes = nonContourNodes(selectedNodesIndex,:);
%Randomly selects angles for the bars
selectedAngle = randi(360,numDistractors);
for i = 1:numDistractors
    %Creates the coordinates of the bar tip centered in [0,0]
    [Tip1X, Tip1Y] = pol2cart(deg2rad(selectedAngle(i)), SegmLength/2); %Creates coords of a semi bar starting from 0,0
    [Tip2X, Tip2Y] = pol2cart(deg2rad(selectedAngle(i) + 180), SegmLength/2); %Creates the other half-bar
    xCoordinates = [selectedNodes(i,1) + Tip1X, selectedNodes(i,1) + Tip2X]; %Adds the coords from the nodes and half bars
    yCoordinates = [selectedNodes(i,2) + Tip1Y, selectedNodes(i,2) + Tip2Y];
    plot(xCoordinates, yCoordinates,'Color', [LineColor LineColor LineColor],'LineWidth',SegmThick)
    hold on
end
set(gca,'color','none')
set(gcf,'color',[Background Background Background])
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