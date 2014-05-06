%% wattsUpRead.m
% This script will read data from WattsUp Power Meter and store it in .mat
% file format to be used by the disaggregation algorithm.

%% Serial Communication
% Test to see if the communications object exists
if ~exist('s','var')
    s=serial('COM4', 'BaudRate', 115200);
end

% Test to see if the communications channel is open
if ~strcmp(s.Status,'open')
    fopen(s);
end

%% Data Specs
prompt = 'What appliance is this?';
appliance = input(prompt, 's');

prompt = 'Describe the item:';
descr = input(prompt, 's');

%% Data Initialization
data(1).item = nan(1,1);
data(1).description = nan(1,1);
data(1).specification = nan(1,1);
data(1).power      = nan(100,1) ;
data(1).voltage        = nan(100,1) ;
%data.current        = nan(100,1) ;
%data.powerFactor    = nan(100,1) ;
%data.frequency      = nan(100,1) ;
data(1).apparentPower  = nan(100,1) ;
data(1).timeStamp      = nan(100,1) ;

% h(1) = plot(data.timeStamp,data.powerReal,      'r', 'linewidth',2) ; hold on ;
% h(2) = plot(data.timeStamp,data.powerApparent,  'b', 'linewidth',2) ; hold on ;
% h(3) = plot(data.timeStamp,data.frequency,      'g') ; hold on ;
% set(h(1),'YDataSource','data.powerReal')
% set(h(1),'XDataSource','data.timeStamp')
% set(h(2),'YDataSource','data.powerApparent')
% set(h(2),'XDataSource','data.timeStamp')
% set(h(3),'YDataSource','data.frequency')
% set(h(3),'XDataSource','data.timeStamp')
% xlabel('Time')
% ylabel('Magnitude')
% legend(h,'Real','Apparent')%,'Frequency')
% legend(h,'Real','Apparent','Frequency')

nBytes = s.BytesAvailable ;
% Send command to Watt Up device
fprintf(s,'#H,R,0;') % Header request
fscanf(s)
fprintf(s,'#C,W,18,1,1,1,0,0,0,0,0,0,0,0,0,0,1,0,0,1,1;')
fscanf(s)
fprintf(s,'#S,W,2,0,1;')
fscanf(s) ;
fprintf(s,'#L,W,3,E,0,1;')
fscanf(s) ;

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
data(1).item = appliance;
data(1).description = descr;
data(1).specification = 'sad';
tStart = rem(now,1);
deltaT = 0.0002;
tEnd = tStart+deltaT;

while rem(now,1) < tEnd
    output = fscanf(s) ;
    reading = textscan(output, '%*s%*s%*s%f%f%f%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%f%*s%*s%f%f;', 'delimiter',',');
    if ~isempty(reading{6}) % && (data.timeStamp(2) == now)
        data(1).power(1)      = reading{1}/10 ;
        data(1).voltage(1)        = reading{2}/10 ;
 %       data(1).current(1)        = reading{3}/1000 ;
 %       data.powerFactor(1)    = reading{4}/100 ;
 %       data.frequency(1)      = reading{5}/10 ;
        data(1).apparentPower(1)  = reading{2}.*reading{3} ; % How are they outputting power; if we can get something up and running with just real power, that would be fine
        data(1).timeStamp(1)      = rem(now,1);

        refreshdata
        drawnow

        data(1).power         = circshift(data(1).power,  1) ;
        data(1).voltage       = circshift(data(1).voltage,    1) ;
  %      data(1).current       = circshift(data(1).current,    1) ;
 %       data.powerFactor     = circshift(data.powerFactor,1) ;
 %       data.frequency       = circshift(data.frequency,  1) ;
        data(1).apparentPower = circshift(data(1).apparentPower,1) ;
        data(1).timeStamp     = circshift(data(1).timeStamp,  1) ;
    end
end

applianceName = strcat('C:\Users\Abhishek B\Documents\My Documents\My Duke Documents\Coursework\Energy 596 - Bass Connections in Energy\MATLAB Disagggregation Models\HMM_MATLAB_Model\WattsUpData\Results\',appliance);
save(applianceName, 'data');

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
fclose(s) ;

