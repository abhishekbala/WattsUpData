function detectedEvents = detectEvents(ds)
%DETECTEVENTS Event detection for 1-D timeseries
% 
% detectEvents(data,windowLength,threshold,smoothFactor)
%
% Performs event detection for 1-D time series data. This method uses an
% edge-detecting filter on smoothed data to detect state changes in the
% input time series
%
% INPUTS:
%   data         = [Nx1]     time series data
%   windowLength = [scalar]  length of filter for convolution
%   threshold    = [scalar]  event threshold for filtered data
% OUTPUTS:
%   events       = Strucuted containing detected event lists
%
% Examples:
% events = detectEvents(rand(100,1),31,1,0.5)

% Extract parameters and initialize variables
% nValues     = length(data) ;
% logLike     = nan(size(data)) ;

% Extract data and parameters from data structure
data            = ds.data ;
windowLength    = ds.windowLength ;
bufferLength    = ds.bufferLength ;
threshold       = ds.threshold ;
smoothFactor    = ds.smoothFactor ;
% timeStamp       = ds.timeStamp ;

% Get filter size and midpoint
windowLength= roundodd(windowLength) ;
midPoint    = (windowLength + 1)/2 ;

% Create the filter
bufferRange             = midPoint - bufferLength:midPoint + bufferLength ;
filter                  = nan(windowLength,1) ;
filter(1:midPoint-1)    = -1 ;
filter(midPoint+1:end)  =  1 ;
filter(bufferRange)     =  0 ;

% Evaluate filter output - smooth first, then convolve with edge detector
hFilterSize = roundodd(windowLength*smoothFactor) ;
hFilter = fspecial('average', hFilterSize) ;
smoothData = imfilter(data,hFilter) ;
filteredData = imfilter(smoothData,filter) ;

% Normalize by the length of the window
filteredData = filteredData / windowLength ;

%----TEMP PLOTTING CODE------------------
figure(2)
h(1) = subplot(2,1,1) ;
plot(data,'k') ;
h(2) = subplot(2,1,2) ;
plot(filteredData,'r')
linkaxes(h,'x')
%----------------------------------------

% Threshold data to determine the events
% threshold = 1 ;
events = zeros(size(filteredData)) ;
events(filteredData >=  threshold)  =  1 ;
events(filteredData <= -threshold)  = -1 ;

% For the regions with potential events, identify the max value
maxima = imregionalmax(filteredData) ;
minima = imregionalmin(filteredData) ;

% Output on/off event values, indices, and timestamps
onIndex     = logical(minima .* (events ==  -1)) ;
offIndex    = logical(maxima .* (events ==   1)) ;
detectedEvents.onEvents         = data(onIndex) ;
detectedEvents.offEvents        = data(offIndex) ;
detectedEvents.onEventsIndex    = find(onIndex) ;
detectedEvents.offEventsIndex   = find(offIndex) ;
% detectedEvents.onEventsTime     = timeStamp(detectedEvents.onEventsIndex) ;
% detectedEvents.offEventsTime    = timeStamp(detectedEvents.offEventsIndex) ;

end

function S = roundodd(S)
% This local function rounds the input to nearest odd integer.
idx = mod(S,2)<1;
S = floor(S);
S(idx) = S(idx)+1;
end