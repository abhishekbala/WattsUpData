%% WattsUp Event Detection Code
function [ds, classifierLoaded] = wattsUpEventDetector(s)

% This script will read data from WattsUp Power Meter on the fly and
% use the PRT to cross validate with the trained data.

clear;
%% Serial Communication
% Test to see if the communications object exists
if nargin < 2 || isempty(s)
    s = serial('COM4', 'BaudRate', 115200);
    
    cleanerUpper = onCleanup(@()fclose(s));
end

% Test to see if the communications channel is open
if ~strcmp(s.Status,'open')
    fopen(s);
end

%% Load HMM Classifier Data
dataDir = ['C:\Users\Abhishek B\Documents\My Documents\My Duke Documents\Coursework\Energy 596 - Bass Connections in Energy\MATLAB Disagggregation Models\WattsUpData\Results\AllData.mat'];
%matFiles = prtUtilSubDir(dataDir,'*.mat');
%cFile = matFiles{1};
%classifierTrained2 = load(dataDir);
classifierLoaded = load(dataDir);

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

%% Data Collection
blockSize = 1000;
dataTable = nan(blockSize,7);
dataTable(1,:) = [0 0 0 0 60.0 0 now];
dataTable(2,:) = [0 0 0 0 60.0 0 now];
iRow = 2;
appOn = 0;
offCounter = 0;
loopVar = true;

while loopVar == true
    output = fscanf(s);
    reading = textscan(output, '%*s%*s%*s%f%f%f%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%f%*s%*s%f%f;', 'delimiter',',');
    
    if (isempty(reading{1}))
        continue;
    end
    
    if (reading{1} == 0) & (appOn == 0)
        fprintf('Waiting to detect event...\n')
        continue;
    end
    
    if (reading{1} == 0) & (appOn == 1) & (offCounter < 3)
        offCounter = offCounter + 1;
    end
        
    %% Event has stopped - what appliance was this?
    if (reading{1} == 0) & (offCounter == 3)
        fprintf('The event has ended\n')

        %% Package up data
        dataTable = dataTable(~all(isnan(dataTable),2),:); % Trim to only the rows that we used
        % elapsedTime = now - tStart;
        % w.update(min(elapsedTime/deltaT,1));
        collectedData = struct('item', '', 'description', '', 'specification', 'sad',...
            'power',dataTable(:,1),...
            'voltage',dataTable(:,2),...
            'current',dataTable(:,3),...
            'powerFactor',dataTable(:,4),...
            'frequency',dataTable(:,5),...
            'apparentPower',dataTable(:,6),...
            'timeStamp',dataTable(:,7));
        
        %% Appliance detection and PRT code
        % [classNames,~,classInds] = unique({collectedData.item}');
        % ds = prtDataSetTimeSeries({collectedData.power}',classInds,'classNames',classNames);
        ds = prtDataSetTimeSeries({collectedData.power}');
%         ds = ds.retainObservations(cellfun(@length,ds.data)>0);
%         plot(ds);
%         ds = ds.setClassNames(classifierLoaded.classNames);
%         %classifierLoaded.classifierTrained.nObservations
%         
%         %% Log Likelihoods and Appliance Probabilities
%         logLikelihoods = zeros(ds.nObservations, length(classifierLoaded.classifierTrained.rvs));
%         for iY = 1:length(classifierLoaded.classifierTrained.rvs)
%             logLikelihoods(:,iY) = getObservations(run(classifierLoaded.classifierTrained.rvs(iY), ds));
%         end
%         
%         dsLogLike = prtDataSetClass(logLikelihoods);
%         dsLogLike = dsLogLike.setClassNames(classifierLoaded.classNames);
%         dsClassNames = classifierLoaded.classNames;
% %         dsProbabilities = normalize_loglikes(dsLogLike.data);
% %         figure(2)
% %         bar(dsProbabilities);
% %         set(gca, 'XTickLabel', classifierLoaded.classNames);
% %         ylabel('Probabilities');
% %         for i=1:numel(dsProbabilities)
% %             text(i, dsProbabilities(i), num2str(dsProbabilities(i)), ...
% %                 'HorizontalAlignment', 'center', ...
% %                 'VerticalAlignment', 'bottom');
% %         end
%         
%         %% Cross validation
%         dsOut = run(classifierLoaded.classifierTrained, ds);
%         dsDecision = rt(prtDecisionMap,dsOut);
%         dsDecision.data;
%         
% %         %% Prompt user to continue data collection
% %         prompt = 'Do you want to continue collection? y/n ';
% %         result = input(prompt, 's');
% %         if result == 'y' % Clean up and recollect
% %             blockSize = 1000;
% %             dataTable = nan(blockSize,7);
% %             dataTable(1,:) = [0 0 0 0 60.0 0 now];
% %             dataTable(2,:) = [0 0 0 0 60.0 0 now];
% %             iRow = 2;
% %             appOn = 0;
% %             continue;
% %         else             % End collection
              loopVar = false;
% %         end
    end % end "Event has stopped" section of code    
    
    %% Event detected - data collection
    if appOn == 0 % The first time this event is on
        fprintf('The WattsUp Power Meter has detected an event!\n')
        offCounter = 0;
        appOn = 1;
    else          % Event is continuing
        if offCounter == 0
            fprintf('Event continuing!\n')
            offCounter = 0;
        else
            fprintf('Event ending!\n')
        end
    end

    iRow = iRow + 1;
    if iRow > size(dataTable, 1)
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


end % end while

end
