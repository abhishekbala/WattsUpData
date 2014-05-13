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
        fullSet = fullSet.retainFeatures(oneAroundCols);
        
        % Run PCA. Keep top 20 components.
        nPcaComps = 20;
        pca = prtPreProcPca('nComponents',nPcaComps);
        pca = pca.train(fullSet);
        onSet = pca.run(fullSet);

        % Run classification.  Vary k as desired.
        for k = 8:8
          knnClassifier = prtClassKnn;
          knnClassifier.k = k;
          knnClassifier = knnClassifier.train(onSet);
          onOuts2 = knnClassifier.kfolds(onSet,5);
          onOuts2.userData.components = houseData.userData.components;

          % Generate the confusion matrix.
          [~,classIdx] = max(onOuts2.data,[],2);
          kClassified = onOuts2.uniqueClasses(classIdx);

          figure;
          prtScoreConfusionMatrix(kClassified,onOuts2.targets)

        %   axesLabels = ['noise';houseData.userData.components(houseOuts2.uniqueClasses(2:end))];
        %   
        %   set(gca,'XTickLabel',axesLabels)
        %   set(gca,'YTickLabel',axesLabels)
        %   
        %   figCoordinates = get(gcf,'Position');
        %   set(gcf,'Position',[figCoordinates(1) figCoordinates(2) figCoordinates(3)+200 figCoordinates(4)+200]);


          axesLabels = {'Other Device','INC','CFL','Fan'} ;

          set(gca,'XTickLabel',axesLabels)
          set(gca,'YTickLabel',axesLabels)

          xlabel('Estimated Class')
          ylabel('True Class')
        %   title('')
          figCoordinates = get(gcf,'Position');
          set(gcf,'Position',[figCoordinates(1) figCoordinates(2) figCoordinates(3)+200 figCoordinates(4)+200]);



          % Save the figure if desired.
        %   s2('png',fullfile(saveDir30,['conMat_k_',num2str(k)]))
        %   s2('fig',fullfile(saveDir30,['conMat_k_',num2str(k)]))

          % Find the assigned class based on the max label.

          % Initialize truth
          INCTruth = zeros(onOuts2.nObservations,1);
          fanTruth = zeros(onOuts2.nObservations,1);
          CFLTruth = zeros(onOuts2.nObservations,1);
          otherTruth = zeros(onOuts2.nObservations,1);

          % Correct it.
          INCTruth(onSet.targets == 3) = 3;
          otherTruth(onSet.targets == 1) = 1;
          fanTruth(onSet.targets == 18) = 18;
          CFLTruth(onSet.targets == 7) = 7;

          % Generate the ROCs.
          figure('color','w');hold on
          % Other - column 1
          prtScoreRoc(onOuts2.data(:,1),otherTruth)
          dataObjs = findobj('Type','line');
          set(dataObjs(1),'Color','k','linewidth',2)
        %   set(dataObjs(1),'LineStyle','--');

          % Fridge - column 3
          prtScoreRoc(onOuts2.data(:,2),INCTruth)
          dataObjs = findobj('Type','line');
          set(dataObjs(1),'Color',rgbconv('FF0000'),'linewidth',2)

          % Dishwasher - column 4
          prtScoreRoc(onOuts2.data(:,3),dwTruth)
          dataObjs = findobj('Type','line');
          set(dataObjs(1),'Color',rgbconv('5CCCCC'),'linewidth',2)

          % Lights - column 7
          prtScoreRoc(onOuts2.data(:,4),CFLTruth)
          dataObjs = findobj('Type','line');
          set(dataObjs(1),'Color',rgbconv('FF7400'),'linewidth',2)

          % Microwave - column 9
          prtScoreRoc(onOuts2.data(:,5),mwTruth)
          dataObjs = findobj('Type','line');
          set(dataObjs(1),'Color',rgbconv('006363'),'linewidth',2)

          % Washer dryer - column 18
          prtScoreRoc(onOuts2.data(:,6),fanTruth)
          dataObjs = findobj('Type','line');
          set(dataObjs(1),'Color',rgbconv('00CC00'),'linewidth',2)

          hLegend = legend('Other Devices','Refrigerator','Dishwasher','Lighting','Microwave','Washer/Dryer');

          set(hLegend,'Interpreter','none')

        %   hTitle = title(['Received Operating Characteristic Curves for k = ',num2str(k),' Nearest Neighbor Classification']) ;
          hXLabel = xlabel('Probability of False Alarm') ;
          hYLabel = ylabel('Probability of Correct Detection') ;


          set( gca                       , ...
            'FontName'   , 'Helvetica' );
        set([hXLabel, hYLabel], ...
            'FontName'   , 'AvantGarde');
        set([hLegend, gca]             , ...
            'FontSize'   , 8           );
        set([hXLabel, hYLabel]  , ...
            'FontSize'   , 10          );
        % set( hTitle                    , ...
        %     'FontSize'   , 12          , ...
        %     'FontWeight' , 'bold'      );

        set(gca, ...
          'Box'         , 'off'     , ...
          'TickDir'     , 'out'     , ...
          'TickLength'  , [.02 .02] , ...
          'XMinorTick'  , 'on'      , ...
          'YMinorTick'  , 'on'      , ...
          'YGrid'       , 'on'      , ...
          'XGrid'       , 'on'      , ...
          'XColor'      , [.3 .3 .3], ...
          'YColor'      , [.3 .3 .3], ...
          'YTick'       , 0:0.125:1, ...
          'XTick'       , 0:0.125:1, ...
          'LineWidth'   , 1         );

          hold off

          % Save it

          % Save if desired.
        %   s2('png',fullfile(saveDir30,['roc_k_',num2str(k)]))
        %   s2('fig',fullfile(saveDir30,['roc_k_',num2str(k)]))
        end
    end
    
    set(hplot(1),'YData',ds.data);
    set(hplot(2),'YData',ds.onEvents);
    set(hplot(3),'YData',ds.offEvents);
    drawnow;
end
end