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
ds.classLabel = ones(arraySize,1) * appClassLabel;
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
offCounter = 0;

while true
    output = fscanf(s);
    reading = textscan(output, '%*s%*s%*s%f%f%f%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%f%*s%*s%f%f;', 'delimiter',',');
    
    if ~isempty(reading{6}) % && (data.timeStamp(2) == now)
        if appOn == 1 && reading{1}/10 < 0.5 % if the appliance is turning off
            offCounter = offCounter + 1;
            if offCounter >= 10
                break;
            end
        end
        if reading{1}/10 > 0.5 % if the appliance turns on
            appOn = 1;
            offCounter = 0;
        end
        ds.data = circshift(ds.data, 1);
        cPower = reading{1}/10;
        ds.data(1) = cPower;
    end
    
    set(hplot(1),'YData',ds.data);
    drawnow;
end

% Compute the on and off events for the interval captured.
ds.onEvents = nan(arraySize,1);
ds.offEvents = nan(arraySize,1);    
detectedEvents = detectEvents(ds);
detectedOnEvents = detectedEvents.onEvents;
detectedOffEvents = detectedEvents.offEvents;
detectedOnIndex = detectedEvents.onEventsIndex;
detectedOffIndex = detectedEvents.offEventsIndex;
ds.onEvents(detectedOnIndex) = detectedOnEvents;
ds.offEvents(detectedOffIndex) = detectedOffEvents;

% Include the on and off events on the plot to give a visual representation
% of what observations will be added to the feature matrices.
set(hplot(2),'YData',ds.onEvents);
set(hplot(3),'YData',ds.offEvents);
drawnow;

% Downsample to intervals surrounding the central on and off events.
numSecsIncluded = 5;
fullSet = ds.data;
fullLabel = ds.classLabel;
%fullSet = prtDataSetClass(ds.data, ds.classLabel);

onOneAroundCols = detectedOnIndex - numSecsIncluded:detectedOnIndex + numSecsIncluded;
onAppDownSampled = fullSet(onOneAroundCols);
onLabel = fullLabel(onOneAroundCols);
onDownSampled = prtDataSetClass(onAppDownSampled, onLabel);

offOneAroundCols = detectedOffIndex - numSecsIncluded:detectedOffIndex + numSecsIncluded;
offAppDownSampled = fullSet(offOneAroundCols);
offLabel = fullLabel(offOneAroundCols);
offDownSampled = prtDataSetClass(offAppDownSampled, offLabel);

% Load the appliance's data:
onAppStr = cat(2, appClass, 'OnFeats.mat');
offAppStr = cat(2, appClass, 'OffFeats.mat');
if exist(onAppStr,'file')
    onApp = load(onAppStr);
    offApp = load(offAppStr);
    onApp = catObservations(onApp, onDownSampled);
    offApp = catObservations(offApp, offDownSampled);    
else
    onApp = onDownSampled;
    offApp = offDownSampled;
end

save(onAppStr, 'onApp');
save(offAppStr, 'offApp');

end