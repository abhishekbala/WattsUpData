% Test to see if the communications object exists
if ~exist('s','var')
    s=serial('COM4', 'BaudRate', 115200);
end

% Test to see if the communications channel is open
if ~strcmp(s.Status,'open')
    fopen(s);
end

data.powerReal      = nan(100,1) ;
data.voltage        = nan(100,1) ;
data.current        = nan(100,1) ;
data.powerFactor    = nan(100,1) ;
data.dutyCycle      = nan(100,1) ;
data.frequency      = nan(100,1) ;
data.powerApparent  = nan(100,1) ;
data.timeStamp      = nan(100,1) ;

h(1) = plot(data.timeStamp,data.powerReal,      'r', 'linewidth',2) ; hold on ;
h(2) = plot(data.timeStamp,data.powerApparent,  'b', 'linewidth',2) ; hold on ;
% h(3) = plot(data.timeStamp,data.frequency,      'g') ; hold on ;
set(h(1),'YDataSource','data.powerReal')
set(h(1),'XDataSource','data.timeStamp')
set(h(2),'YDataSource','data.powerApparent')
set(h(2),'XDataSource','data.timeStamp')
% set(h(3),'YDataSource','data.frequency')
% set(h(3),'XDataSource','data.timeStamp')
xlabel('Time')
ylabel('Magnitude')
legend(h,'Real','Apparent')%,'Frequency')
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

while true
    output = fscanf(s) ;
    reading = textscan(output, '%*s%*s%*s%f%f%f%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%f%*s%*s%f%f;', 'delimiter',',') ;
    if ~isempty(reading{6}) % && (data.timeStamp(2) == now)
        data.powerReal(1)      = reading{1}/10 ;
        data.voltage(1)        = reading{2}/10 ;
        data.current(1)        = reading{3}/1000 ;
        data.powerFactor(1)    = reading{4}/100 ;
        data.frequency(1)      = reading{5}/10 ;
        data.powerApparent(1)  = reading{6}/10 ;
        data.timeStamp(1)      = now ;

        refreshdata
        drawnow

        data.powerReal     = circshift(data.powerReal,  1) ;
        data.voltage       = circshift(data.voltage,    1) ;
        data.current       = circshift(data.current,    1) ;
        data.powerFactor   = circshift(data.powerFactor,1) ;
        data.frequency     = circshift(data.frequency,  1) ;
        data.powerApparent = circshift(data.powerApparent,1) ;
        data.timeStamp     = circshift(data.timeStamp,  1) ;
    end
end

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

