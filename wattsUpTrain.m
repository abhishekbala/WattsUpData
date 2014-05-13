function wattsUpTrain(appClass, appClassLabel, s)
% Serial Communication
% Test to see if the communications object exists
if nargin < 3 || isempty(s)
    s = serial('COM4', 'BaudRate', 115200);
    
    cleanerUpper = onCleanup(@()fclose(s));
end

% Test to see if the communications channel is open
if ~strcmp(s.Status,'open')
    fopen(s); 
end

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

% Data Collection
arraySize = 200;
ds.data = zeros(arraySize,1);
ds.onEvents = nan(arraySize,1);
ds.offEvents = nan(arraySize,1);
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

appOn = 0;

while true
    output = fscanf(s);
    reading = textscan(output, '%*s%*s%*s%f%f%f%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%f%*s%*s%f%f;', 'delimiter',',');
    
    if ~isempty(reading{6}) % && (data.timeStamp(2) == now)
        if appOn == 1 & reading(1)/10 < 0.5 % if the appliance is turning off
            appOn = 0;
            break;
        end
        if reading(1)/10 > 0.5 % if the appliance turns on
            appOn = 1;
        end
        ds.data = circshift(ds.data, 1);
        cPower = reading{1}/10;
        ds.data(1) = cPower;
    end
    set(hplot(1),'YData',ds.data);    
    drawnow;
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

% Downsample to 10 s surrounding the central on and off events
numSecsIncluded = 10;
onOneAroundCols = detectedOnIndex - numSecsIncluded:detectedOnIndex + numSecsIncluded;
onDownSampled = fullSet.retainFeatures(onOneAroundCols);
offOneAroundCols = detectedOffIndex - numSecsIncluded:detectedOffIndex + numSecsIncluded;
offDownSampled = fullSet.retainFeatures(offOneAroundCols);

% Load the appliance's data:
onAppStr = cat(2, appClass, 'OnFeats');
onAppStrDir = cat(2, onAppStr, '.mat');
offAppStr = cat(2, appClass, 'OffFeats');
offAppStrDir = cat(2, offAppStr, '.mat');
if exist(onAppStrDir,'file')
    onApp = load(onAppStrDir);
    offApp = load(offAppStrDir);
    onApp.data = cat(1,onApp.data,onDownSampled);
    
    offApp.data = cat(1,offApp.data,offDownSampled);
    % add targets
    
else
    onApp = prtDataSetClass;
    % put the class labels
end

save(onAppStrDir, onApp);
save(offAppStrDir, offApp);

set(hplot(2),'YData',ds.onEvents);
set(hplot(3),'YData',ds.offEvents);
drawnow;

end