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
for i=1:200
    ds.classID{i} = '';
end
ds.windowLength = 51;
ds.bufferLength = 6;
ds.threshold = 0.5;
ds.smoothFactor = 0.5;

figure(1)
clf;
hplot(1) = plot(ds.data);
hold on
hplot(2) = plot(ds.onEvents, 'ob');
hplot(3) = plot(ds.offEvents, 'or');
% for i=1:200
%     hplot(i+3) = text(i, ds.data(i)+5, ds.classID{i});
% end

set(gca, 'xdir', 'reverse');
drawnow;
onCount = 0;
offCount = 0;

% Run PCA. Keep top 20 components.
nPcaComps = 5;
pca = prtPreProcPca('nComponents',nPcaComps);
pca = pca.train(fullSet); % train pca on training set

while true
    onCount = onCount+1;
    offCount = offCount+1;
    output = fscanf(s);
    reading = textscan(output, '%*s%*s%*s%f%f%f%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%f%*s%*s%f%f;', 'delimiter',',');
    
    if ~isempty(reading{6}) % && (data.timeStamp(2) == now)
        ds.data = circshift(ds.data, 1);
        ds.classID = circshift(ds.classID, 1);
%         ds.onEvents = circshift(ds.onEvents, 1);
%         ds.offEvents = circshift(ds.offEvents, 1);
        cPower = reading{1}/10;
        ds.data(1) = cPower;
    end
    ds.onEvents = nan(arraySize,1);
    ds.offEvents = nan(arraySize,1);    
    detectedEvents = detectEvents(ds);
    detectedOnEvents = detectedEvents.onEvents;
    detectedOffEvents = detectedEvents.offEvents;
    detectedOnIndex = detectedEvents.onEventsIndex;
    detectedOffIndex = detectedEvents.offEventsIndex;    
    ds.onEvents(detectedOnIndex) = detectedOnEvents;
    ds.offEvents(detectedOffIndex) = detectedOffEvents;
    
    %% On Event Classification
    for j=1:length(detectedOnIndex)
        i = detectedOnIndex(j);
        if ~isempty(i) && onCount > 6 && i > 5 && i < 195
            onCount = 0;
            % Downsample to 5 s surrounding the central on event
            onTestSet = ds.data';
            numSecsIncluded = 5;
            onOneAroundCols = i - numSecsIncluded:i + numSecsIncluded;
            onDownSampled = onTestSet(onOneAroundCols);
            onDownSampled = prtDataSetClass(onDownSampled);

           % trainSet = pca.run(fullSet); % This projects it to train set
           % onSet = pca.run(onDownSampled); % This projects it to test set

            % Run classification.  Vary k as desired.
            for k = 8:8
              knnClassifier = prtClassKnn;
              knnClassifier.k = k;
              knnClassifier = knnClassifier.train(fullSet); % use training features
              knnClassOnOut = knnClassifier.run(onDownSampled);
              % knnClassifier is a classifier within PRT              
              [maxK, dcsID] = max(knnClassOnOut.data);
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
            ds.classID{i}
        end
    end
    
    %% Off Event Classification
    for j=1:length(detectedOffIndex);
        i = detectedOffIndex(j);
        if ~isempty(i) && offCount > 6 && i > 5 && i < 195
            offCount = 0;
            % Downsample to 5 s surrounding the central off event
            offTestSet = ds.data';
            numSecsIncluded = 5;
            offOneAroundCols = i - numSecsIncluded:i + numSecsIncluded;
            offDownSampled = offTestSet(offOneAroundCols);
            offDownSampled = prtDataSetClass(offDownSampled);

            trainSet = pca.run(fullSet); % This projects it to train set
            offSet = pca.run(offDownSampled); % This projects it to test set

            % Run classification.  Vary k as desired.
            for k = 8:8
              knnClassifier = prtClassKnn;
              knnClassifier.k = k;
              knnClassifier = knnClassifier.train(trainSet); % use training features
              knnClassOffOut = knnClassifier.run(offSet);
              % knnClassifier is a classifier within PRT
              [maxK, dcsID] = max(knnClassOffOut.data);
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
            ds.classID{i}
        end
    end

    set(hplot(1),'YData',ds.data);
    set(hplot(2),'YData',ds.onEvents);
    set(hplot(3),'YData',ds.offEvents);
%     for i=1:200
%         set(hplot(i+3),'YData',ds.classID{i});
%     end
    drawnow;
end
end