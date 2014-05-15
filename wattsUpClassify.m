function wattsUpClassify(s)
% Serial Communication
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

% Data Collection
arraySize = 200;
ds.data = zeros(arraySize,1);
ds.onEvents = nan(arraySize,1);
ds.offEvents = nan(arraySize,1);
ds.classID = cell(arraySize,1);
ds.windowLength = 51;
ds.bufferLength = 6;
ds.threshold = 0.5;
ds.smoothFactor = 0.5;

figure(1)
axis([0 200 0 100])
axis manual;
clf;
hplot(1) = plot(ds.data, 'LineWidth', 3, 'Color', 'k');
hold on
hplot(2) = plot(ds.onEvents, 'ob');
hplot(3) = plot(ds.offEvents, 'or');
hArray = [];

set(gca, 'xdir', 'reverse');
drawnow;
axis([0 200 0 100])
onCount = 0;
offCount = 0;

% Run PCA. Keep top 20 components.
% nPcaComps = 5;
% pca = prtPreProcPca('nComponents',nPcaComps);
% pca = pca.train(fullSet); % train pca on training set

while true
    onCount = onCount+1;
    offCount = offCount+1;
    output = fscanf(s);
    reading = textscan(output, '%*s%*s%*s%f%f%f%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%f%*s%*s%f%f;', 'delimiter',',');
    
    if ~isempty(reading{6}) % && (data.timeStamp(2) == now)
        % Update the streaming data
        ds.data = circshift(ds.data, 1);
        ds.classID = circshift(ds.classID, 1);
        cPower = reading{1}/10;
        ds.data(1) = cPower;
        
        % Update the streaming data on the plot
        set(hplot(1),'YData',ds.data);
        set(hplot(2),'YData',ds.onEvents);
        set(hplot(3),'YData',ds.offEvents);
%         if ~isempty(hArray)
% %            object_handles
% %             obj = findall(gcf);
% %             textLabels = findall(obj, 'Type', 'text');
% %             delete(textLabels);
% %             for n=1:length(hArray) % update the strings
% %                 hold on;
% %                 x = get(hArray(n));
% %                 pos = x.Position;
% %                 set(hArray(n),'Position',[pos(1) + 1, pos(2)]);
% %             end
%         end
        axis([0 200 0 100])
        drawnow;
        axis([0 200 0 100])
    end
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
    
    if ~isempty(hArray)
        delete(hArray);
        hArray = [];
    end
    
    %% Event Classification
    for j=1:length(detectedIndices)
        i = detectedIndices(j);
        if ~isempty(i) && i > 5 && i < 195
            % Extract features: 5 s surrounding the central on event
            testSet = ds.data';
            numSecsIncluded = 5;
            oneAroundCols = i - numSecsIncluded:i + numSecsIncluded;
            extracted = testSet(oneAroundCols);
            extracted = prtDataSetClass(extracted);

           % trainSet = pca.run(fullSet); % This projects it to train set
           % onSet = pca.run(onDownSampled); % This projects it to test set

            % Run classification.  Vary k as desired.
            for k = 8:8
              knnClassifier = prtClassKnn;
              knnClassifier.k = k;
              knnClassifier = knnClassifier.train(fullSet); % use training features
              knnClassOut = knnClassifier.run(extracted);
              % knnClassifier is a classifier within PRT              
              [maxK, dcsID] = max(knnClassOut.data);
            end
            
            % Finish classification
            switch dcsID
                case 1
                    ds.classID{i} = 'Incandescent On';
                case 2
                    ds.classID{i} = 'Incandescent Off';
                case 3
                    ds.classID{i} = 'LED Lamp On';
                case 4
                    ds.classID{i} = 'LED Lamp Off';
                case 5
                    ds.classID{i} = 'Charger On';
                case 6
                    ds.classID{i} = 'Charger Off';
            end
            handleLength = length(hArray);
            hArray(handleLength+1) = text(i,ds.data(i)+5,ds.classID{i});
            %speak(ds.classID{i},-2);
        end
    end
end
end