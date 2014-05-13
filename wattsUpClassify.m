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
load('INCFeats.mat')
load('CFLFeats.mat')
load('fanFeats.mat')
fullSet = catObservations(INCFeats, CFLFeats, fanFeats);

%% Watts up communication, why?
% nBytes = s.BytesAvailable;

% Send command to Watts Up device
fprintf(s,'#H,R,0;') % Header request
fscanf(s)
fprintf(s,'#C,W,18,1,1,1,0,0,0,0,0,0,0,0,0,0,1,0,0,1,1;')
fscanf(s)
fprintf(s,'#S,W,2,0,1;')
fscanf(s);
fprintf(s,'#L,W,3,E,0,1;')
fscanf(s);

arraySize = 200;

% Data Collection
ds.data = zeros(arraySize,1);
ds.onEvents = nan(arraySize,1);
ds.offEvents = nan(arraySize,1);
ds.windowLength = 51;
ds.bufferLength = 6;
ds.threshold = 0.5;
ds.smoothFactor = 0.5;

% ds.allOnEvents = zeros(1);
% ds.allOffEvents = zeros(1);

figure(1)
clf;
hplot(1) = plot(ds.data);
hold on
hplot(2) = plot(ds.onEvents, 'ob');
hplot(3) = plot(ds.offEvents, 'or');
set(gca, 'xdir', 'reverse');
drawnow;
count = 0;

while true
    count = count+1;
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
    if ~isEmpty(detectedOnIndex)
        % Downsample to 10 s surrounding the central on event
        numSecsIncluded = 10;
        oneAroundCols = detectedOnIndex - numSecsIncluded:detectedOnIndex + numSecsIncluded;
        downSampled = fullSet.retainFeatures(oneAroundCols);
        
        % Run PCA. Keep top 20 components.
        nPcaComps = 20;
        pca = prtPreProcPca('nComponents',nPcaComps);
        pca = pca.train(downSampled);
        onSet = pca.run(downSampled);
    
        % Run classification.  Vary k as desired.
        for k = 8:8
          knnClassifier = prtClassKnn;
          knnClassifier.k = k;
          knnClassifier = knnClassifier.train(onSet);
          onOuts = knnClassifier.kfolds(onSet,5);
          onOuts.userData.components = houseData.userData.components;

          % Generate the confusion matrix.
          [~,classIdx] = max(onOuts.data,[],2);
          kClassified = onOuts.uniqueClasses(classIdx);
        end
    end
    
    %% Off Event Classification
    if ~isEmpty(detectedOffIndex)
        % Downsample to 10 s surrounding the central on event
        numSecsIncluded = 10;
        oneAroundCols = detectedOffIndex - numSecsIncluded:detectedOffIndex + numSecsIncluded;
        downSampled = fullSet.retainFeatures(oneAroundCols);
        
        % Run PCA. Keep top 20 components.
        nPcaComps = 20;
        pca = prtPreProcPca('nComponents',nPcaComps);
        pca = pca.train(downSampled);
        offSet = pca.run(downSampled);
    
        % Run classification.  Vary k as desired.
        for k = 8:8
          knnClassifier = prtClassKnn;
          knnClassifier.k = k;
          knnClassifier = knnClassifier.train(offSet);
          offOuts = knnClassifier.kfolds(offSet,5);
          offOuts.userData.components = houseData.userData.components;

          % Generate the confusion matrix.
          [~,classIdx] = max(offOuts.data,[],2);
          kClassified = offOuts.uniqueClasses(classIdx);
        end
    end
    
    set(hplot(1),'YData',ds.data);
    set(hplot(2),'YData',ds.onEvents);
    set(hplot(3),'YData',ds.offEvents);
    drawnow;
end
end