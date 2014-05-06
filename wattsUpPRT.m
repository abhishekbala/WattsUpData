%% WattsUpPRT
% Abhishek Balakrishnan
% Based on Code from Kenneth Morton, Duke University ECE

function wattsUpPRT(groupDescr)

% Set up path to data directory
dataDir = 'C:\Users\Abhishek B\Documents\My Documents\My Duke Documents\Coursework\Energy 596 - Bass Connections in Energy\MATLAB Disagggregation Models\WattsUpData\Results\AllData';

matFiles = prtUtilSubDir(dataDir,'*.mat');

for iFile = 1:length(matFiles)
    cFile = matFiles{iFile};
    
    loadedStuff = load(cFile);
    
    if iFile == 1
        allData = loadedStuff.data(:);
    else
        allData = cat(1,allData,loadedStuff.data(:));
    end
end

[classNames,~,classInds] = unique({allData.item}');
ds = prtDataSetTimeSeries({allData.power}',classInds,'classNames',classNames);
ds = ds.retainObservations(cellfun(@length,ds.data)>0);

plot(ds);

%% Setup and run the HMM classifier
gem = prtBrvDiscreteStickBreaking;
gem.model.alphaGammaParams = [1 1e-6]; % These parameters control the preferences for the number of states

bhmm = prtBrvDpHmm('components',repmat(prtBrvMvn,10,1),'verboseStorage',false,'vbVerbosePlot',1,'vbVerboseText',1,'vbConvergenceDecreaseThreshold', inf, 'vbMaxIterations',50);
bhmm.initialProbabilities = gem;
bhmm.transitionProbabilities = gem;

% classifier = prtClassMap('rvs',bhmm,'verboseStorage',false);
classifier = prtClassMapLog('rvs',bhmm,'verboseStorage',false);
classifier.twoClassParadigm = 'mary';
classifierTrained = train(classifier,ds);
classNames = ds.getClassNames;
strPath = ['C:\Users\Abhishek B\Documents\My Documents\My Duke Documents\Coursework\Energy 596 - Bass Connections in Energy\MATLAB Disagggregation Models\WattsUpData\Results\' groupDescr '.mat']
save(strPath,'classifierTrained','classNames');

