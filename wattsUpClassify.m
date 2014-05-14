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
load('INCOffFeats.mat')
load('INCOnFeats.mat')
%load('CFLOnFeats.mat')
%load('CFLOffFeats.mat')
%load('fanOffFeats.mat')
%load('fanOnFeats.mat')
fullSet = catObservations(onApp, offApp);%, CFLOnFeats, CFLOffFeats, fanOnFeats, fanOffFeats);

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
clf;
hplot(1) = plot(ds.data);
hold on
hplot(2) = plot(ds.onEvents, 'ob');
hplot(3) = plot(ds.offEvents, 'or');
set(gca, 'xdir', 'reverse');
drawnow;
onCount = 0;
offCount = 0;

while true
    onCount = onCount+1;
    offCount = offCount+1;
    output = fscanf(s);
    reading = textscan(output, '%*s%*s%*s%f%f%f%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%f%*s%*s%f%f;', 'delimiter',',');
    
    if ~isempty(reading{6}) % && (data.timeStamp(2) == now)
        ds.data = circshift(ds.data, 1);
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
    if ~isempty(detectedOnIndex) && onCount > 6
        onCount = 0;
        % Downsample to 5 s surrounding the central on event
        onTestSet = ds.data';
        numSecsIncluded = 5;
        oneAroundCols = detectedOnIndex - numSecsIncluded:detectedOnIndex + numSecsIncluded;
        onDownSampled = onTestSet(oneAroundCols);
        
        % Run PCA. Keep top 20 components.
        nPcaComps = 5;
        pca = prtPreProcPca('nComponents',nPcaComps);
        pca = pca.train(fullSet);
        onSet = pca.run(fullSet);
    
        % Run classification.  Vary k as desired.
        for k = 8:8
          knnClassifier = prtClassKnn;
          knnClassifier.k = k;
          knnClassifier = knnClassifier.train(onSet);
          knnClassifier = knnClassifier.run(onDownSampled);
          onOuts = knnClassifier.kfolds(onSet,5);
          onOuts.userData.components = houseData.userData.components;

          % Generate the confusion matrix.
          [~,classIdx] = max(onOuts.data,[],2);
          kClassified = onOuts.uniqueClasses(classIdx);
          % classDecision
        end
        
    end
    
    %% Off Event Classification
    if ~isempty(detectedOffIndex) && offCount > 6
        offCount = 0;
        % Downsample to 5 s surrounding the central off event
        offTestSet = ds.data';
        numSecsIncluded = 5;
        oneAroundCols = detectedOffIndex - numSecsIncluded:detectedOffIndex + numSecsIncluded;
        offDownSampled = offTestSet(oneAroundCols);
        %downSampled = fullSet.retainFeatures(oneAroundCols);
        
        % Run PCA. Keep top 20 components.
        nPcaComps = 5;
        pca = prtPreProcPca('nComponents',nPcaComps);
        pca = pca.train(fullSet);
        offSet = pca.run(fullSet);
        
        % Run classification.  Vary k as desired.
        for k = 8:8
          knnClassifier = prtClassKnn;
          knnClassifier.k = k;
          knnClassifier = knnClassifier.train(offSet);
          knnClassifier = knnClassifier.run(offDownSampled);
          onOuts = knnClassifier.kfolds(offSet,5);
          onOuts.userData.components = houseData.userData.components;

          % Generate the confusion matrix.
          [~,classIdx] = max(onOuts.data,[],2);
          kClassified = onOuts.uniqueClasses(classIdx);
        end
    end
    
    set(hplot(1),'YData',ds.data);
    set(hplot(2),'YData',ds.onEvents);
    set(hplot(3),'YData',ds.offEvents);
    drawnow;
end
end