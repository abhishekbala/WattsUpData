%% Nick Czarnek
% 15 May 2014
% SSPACISS Laboratory
%
% The purpose of this script is to analyze and classify the features from
% AB's measurements.

% saveDir = 'C:\Users\Nick\Documents\MATLAB\dbSessions\]abhiEnergyDis_knn140515';

load('fullSet')

%% Targets should be a 1 d vector of labels, not a matrix.
fullSet.targets = fullSet.targets(:,1);

%% Visualize the data.
figure;
imagesc(fullSet)
colorbar
title('Event visualization')

%% Associated targets.
figure;
plot(fullSet.targets)
xlabel('Observations')
ylabel('Target values')
title('Observation targets')

%% Save the visualization.
% s2('png',fullfile(saveDir,'dataViz'))
% s2('fig',fullfile(saveDir,'dataViz'))


%% Run 5 fold cross val with 8 nearest neighbors.
knnClassifier = prtClassKnn('k',8);

kOuts = knnClassifier.kfolds(fullSet,5);

% Score performance using the max class decision statistic.
[~,classIdx] = max(kOuts.data,[],2);
figure;
prtScoreConfusionMatrix(kOuts.targets,classIdx)





%% Run incestuous training and testing.
knnClassifier = knnClassifier.train(fullSet);

testOuts = knnClassifier.run(fullSet);

% Score performance using the max class decision statistic.
[~,classIdx] = max(testOuts.data,[],2);
figure;
prtScoreConfusionMatrix(testOuts.targets,classIdx)