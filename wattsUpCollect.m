function data = wattsUpCollect(appliance, descr, nSecondsToRecord, s)

% This script will read data from WattsUp Power Meter and store it in .mat
% file format to be used by the disaggregation algorithm.

% Serial Communication
% Test to see if the communications object exists
if nargin < 4 || isempty(s)
    s = serial('COM4', 'BaudRate', 115200);
    
    cleanerUpper = onCleanup(@()fclose(s));
end

% Test to see if the communications channel is open
if ~strcmp(s.Status,'open')
    fopen(s);
end

% Watts up communication, why?
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

% fprintf(s,'#C,R,0;') % Chosen field list
% fprintf(s,'#S,R,0;') % Request Information on Logging Mode
% fprintf(s,'#R,W,0;') % Clear memory
% fprintf(s,'#L,W,3,E,0,1;') % Set to external
% fprintf(s,'#D,R,0;') % All Data request
% output = fscanf(s) ;
% dbstop if error
% keyboard
% data.powerReal      = reading{1}/10 ;
% data.voltage        = reading{2}/10 ;
% data.current        = reading{3}/1000 ;
% data.powerFactor    = reading{4}/100 ;
% data.dutyCycle      = reading{5}/100 ;
% data.frequency      = reading{6}/10 ;
% data.powerApparent  = reading{7}/10 ;

%% Data Collection

tStart = now;
deltaT = nSecondsToRecord/(60*60*24);
tEnd = tStart+deltaT;

blockSize = 1000;

w = prtUtilProgressBar(0,'Recording');


dataTable = nan(blockSize,7);
iRow = 0;
while now < tEnd
    
    output = fscanf(s);
    reading = textscan(output, '%*s%*s%*s%f%f%f%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%f%*s%*s%f%f;', 'delimiter',',');
    if ~isempty(reading{6}) % && (data.timeStamp(2) == now)
        iRow = iRow + 1;
        
        if iRow > size(dataTable,1)
            dataTable = cat(1,dataTable,nan(blockSize,size(dataTable,2)));
        end
        
        cPower = reading{1}/10;
        cVoltage = reading{2}/10;
        cCurrent = reading{3}/1000;
        cPowerFactor = reading{4}/100;
        cFrequency = reading{5}/10;
        cApparentPower = cVoltage * cCurrent;  % How are they outputting power; if we can get something up and running with just real power, that would be fine
        cTimeStamp = now;

        dataTable(iRow,:) = [cPower cVoltage cCurrent cPowerFactor cFrequency cApparentPower cTimeStamp];
        
    end
    elapsedTime = now - tStart;
    w.update(min(elapsedTime/deltaT,1));
end
dataTable = dataTable(~all(isnan(dataTable),2),:); % Trim to only the rows that we used


% Package up data
data = struct('item', appliance, 'description', descr, 'specification', 'sad',...
    'power',dataTable(:,1),...
    'voltage',dataTable(:,2),...
    'current',dataTable(:,3),...
    'powerFactor',dataTable(:,4),...
    'frequency',dataTable(:,5),...
    'apparentPower',dataTable(:,6),...
    'timeStamp',dataTable(:,7));

%%
%applianceName = strcat('C:\Users\Abhishek B\Documents\My Documents\My Duke Documents\Coursework\Energy 596 - Bass Connections in Energy\MATLAB Disagggregation Models\WattsUpData\Results\',appliance);
%save(applianceName, 'data');

%% Data Buffering
% Header: #h,-,18,W,V,A,WH,Cost,WH/Mo,Cost/Mo,Wmax,Vmax,Amax,Wmin,Vmin,Amin,PF,DC,PC,Hz,VA;
% Sample Data: #d,-,18,0,1201,0,0,0,2,0,0,1202,0,0,1201,0,100,0,0,600,0;

% samplesToRead  = 10 ;
%
% % fscanf(s) ; % Clear the serial buffer before reading
% for i = 1:samplesToRead
%     meas{i} = fscanf(s) ;
%     fprintf('Itr = %g\n',i)
% end