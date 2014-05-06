% Script to test the detectEvents function
% Kyle Bradbury
% Duke University
% March 14, 2014

reddDataDir = 'C:\Data\REDD\1Hz\' ;

%--------------------------------------------------------------------------
% Load Data
%--------------------------------------------------------------------------
% Load REDD data from file
fileName    = 'house_1_mains.mat' ;
load([reddDataDir fileName])
ds.data     = houseMains.data(420000:440000,1) ; % Select the refrigerator
ds.timeStamp= houseMains.data(420000:440000,5) ; % Get timestamps

%--------------------------------------------------------------------------
% Run Event Detection
%--------------------------------------------------------------------------
% Event detection parameters
ds.windowLength    = 51 ;
ds.bufferLength    = 6 ;
ds.threshold       = 0.9 ;
ds.smoothFactor    = 0.5 ;

% Detect events
events = detectEvents(ds) ;

% Plot the results
figure
h(1) = plot(1:length(ds.data),ds.data,'color','k') ; hold on ;
h(2) = plot(events.onEventsIndex,events.onEvents, 'bo') ;
h(3) = plot(events.offEventsIndex,events.offEvents,'ro') ;
legend(h,'Power Data','ON events','OFF events')
xlabel('Time')
ylabel('Power [Watts]')