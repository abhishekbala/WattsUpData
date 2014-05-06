function wattsUpDemo2(s)
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
    
%     ds.allOnEvents = cat(1,ds.allOnEvents,detectedOnEvents);
%     ds.allOffEvents = cat(1,ds.allOffEvents,detectedOffEvents);
%     if rem(count,30) == 0
%         disp(ds.allOnEvents);
%         disp(ds.allOffEvents);
%     end
    set(hplot(1),'YData',ds.data);
    set(hplot(2),'YData',ds.onEvents);
    set(hplot(3),'YData',ds.offEvents);
    drawnow;
end
end