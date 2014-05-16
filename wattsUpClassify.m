function wattsUpClassify(s)

%% Constants
arraySize = 200;
vertSize = 100;
numSecsIncluded = 5;
% Data Collection
ds.data = zeros(arraySize,1);
ds.onEvents = nan(arraySize,1);
ds.offEvents = nan(arraySize,1);
ds.speakArray = zeros(arraySize,1);
ds.classID = cell(arraySize,1);
ds.windowLength = 51;
ds.bufferLength = 6;
ds.threshold = 0.5;
ds.smoothFactor = 0.5;

%% Serial Communication
% Test to see if the communications object exists
if nargin < 2 || isempty(s)
    s = serial('COM4', 'BaudRate', 115200);
    
    cleanerUpper = onCleanup(@()fclose(s));
end

% Test to see if the communications channel is open
if ~strcmp(s.Status,'open')
    fopen(s);
end

%% Load all of the files.
dataDir = 'C:\Users\Abhishek B\Documents\My Documents\My Duke Documents\Coursework\Energy 596 - Bass Connections in Energy\MATLAB Disagggregation Models\WattsUpData\';
matFiles = prtUtilSubDir(dataDir,'*.mat');
for iFile = 1:length(matFiles)
    cFile = matFiles{iFile};
    load(cFile)
    if iFile == 1
        fullSet = offApp;
    else
        if rem(iFile,2) == 0
            fullSet = catObservations(fullSet, onApp);
        else
            fullSet = catObservations(fullSet, offApp);
        end
    end
end

%% Watts up communication
% nBytes = s.BytesAvailable;
% Send command to Watts Up device
fprintf(s,'#H,R,0;'); % Header request
fscanf(s);
fprintf(s,'#C,W,18,1,1,1,0,0,0,0,0,0,0,0,0,0,1,0,0,1,1;');
fscanf(s);
fprintf(s,'#S,W,2,0,1;');
fscanf(s);
fprintf(s,'#L,W,3,E,0,1;');
fscanf(s);


%% Set up plots
figure(1)
axis([0 arraySize 0 vertSize])
axis manual;
clf;
hplot(1) = plot(ds.data, 'LineWidth', 3, 'Color', 'g');
hold on
%hplot(2) = plot(ds.onEvents, 'ob'); -- to plot the event location
%hplot(3) = plot(ds.offEvents, 'or'); -- to plot the event location
hTitle  = title ('Appliance Level Disaggregation with Watts Up? PRO Meter');
hXLabel = xlabel('Time Window (s)'                     );
hYLabel = ylabel('Power (Watts)'                      );
hArray = [];

set(gca, 'xdir', 'reverse');
set( gca                       , ...
    'FontName'   , 'Helvetica' );
set([hTitle, hXLabel, hYLabel, hArray], ...
    'FontName'   , 'AvantGarde');
set([hXLabel, hYLabel, hArray]  , ...
    'FontSize'   , 11          );
set( hTitle                    , ...
    'FontSize'   , 16          , ...
    'FontWeight' , 'bold'      );
set(gcf,'color','w');
drawnow;
axis([0 arraySize 0 vertSize])

%% Run PCA - optional step
% Run PCA. Keep top 20 components.
% nPcaComps = 5;
% pca = prtPreProcPca('nComponents',nPcaComps);
% pca = pca.train(fullSet); % train pca on training set

%% Data Analysis Loop
while true
    % Read data from the WattsUp
    output = fscanf(s);
    reading = textscan(output, '%*s%*s%*s%f%f%f%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%f%*s%*s%f%f;', 'delimiter',',');
    
    if ~isempty(reading{6}) % && (data.timeStamp(2) == now)
        % Update the streaming data
        ds.data = circshift(ds.data, 1);
        ds.speakArray = circshift(ds.speakArray,1);
        ds.classID = circshift(ds.classID, 1);
        cPower = reading{1}/10;
        ds.data(1) = cPower;
        ds.speakArray(1) = 0;
        ds.classID{1} = [];
        
        % Update the streaming data on the plot
        set(hplot(1),'YData',ds.data);
        drawnow;
        axis([0 200 0 vertSize])
    end
    
    % Reinitializing text array
    if ~isempty(hArray)
        delete(hArray);
        hArray = [];
    end
    
    % Compute the on and off events
    ds.onEvents = nan(arraySize,1);
    ds.offEvents = nan(arraySize,1);    
    detectedEvents = detectEvents(ds);
    detectedOnEvents = detectedEvents.onEvents;
    detectedOffEvents = detectedEvents.offEvents;
    detectedOnIndex = detectedEvents.onEventsIndex;
    detectedOffIndex = detectedEvents.offEventsIndex;
    detectedIndices = cat(1,detectedOnIndex,detectedOffIndex);
    ds.onEvents(detectedOnIndex) = detectedOnEvents;
    ds.offEvents(detectedOffIndex) = detectedOffEvents;
    
    %% Event Classification
    for j=1:length(detectedIndices)
        i = detectedIndices(j);
        if ~isempty(i) && i > 15 && i < 185
            % Extract features: "numSecsIncluded" s surrounding the central event
            testSet = ds.data';
            oneAroundCols = i - numSecsIncluded:i + numSecsIncluded;
            extracted = testSet(oneAroundCols);
            extracted = prtDataSetClass(extracted);
            
            % Run PCA - optional step
            % trainSet = pca.run(fullSet); % This projects it to train set
            % onSet = pca.run(onDownSampled); % This projects it to test set

            % Run classification.  Vary k as desired.
            for k = 8:8
              knnClassifier = prtClassKnn;
              knnClassifier.k = k;
              knnClassifier = knnClassifier.train(fullSet); % use training features
              knnClassOut = knnClassifier.run(extracted);
              % knnClassifier is a classifier within PRT              
              [~, dcsID] = max(knnClassOut.data);
            end
            
            % Finish classification and assign the appropriate string for decision
            switch dcsID
                case 1
                    ds.classID{i} = '2 C.F.L On';
                case 2
                    ds.classID{i} = '2 C.F.L Off';
                case 3
                    ds.classID{i} = 'C.F.L Lamp On';
                case 4
                    ds.classID{i} = 'C.F.L Lamp Off';
            end
            
            % Generate the text handles to print
            handleLength = length(hArray);
             if rem(handleLength, 2) == 0
                hArray(handleLength+1) = text(i,vertSize-5,ds.classID{i},'HorizontalAlignment','center','FontName','AvantGarde','FontSize',11,'Color',[0 0 1]);
             else
                hArray(handleLength+1) = text(i,vertSize-10,ds.classID{i},'HorizontalAlignment','center','FontName','AvantGarde','FontSize',11,'Color',[0 0 1]);
             end
             
             % Speak the decision if it has not already been done so
             if ds.speakArray(i)==0 && i < 50
                 speakInterval = i-numSecsIncluded:i+numSecsIncluded;
                 ds.speakArray(speakInterval) = 1;
                 speak(ds.classID{i},-2);
             end
        end
    end
end
end