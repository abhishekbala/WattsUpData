%% aBalakrishnan_Energy_20140204_wattsUpMultiCollectExample

description = 'Fan';
item = 'Fan03';
nCollectionSeconds = 20;

nCollections = 8; % want between 10 and 20

for iCollection = 1:nCollections
    
    disp(sprintf('Waiting to collect data for collection # %02d...\n',iCollection));
    %pause;
    
    cData = wattsUpCollect(item,description, nCollectionSeconds);
    
    if iCollection == 1
        data = cData;
    else    
        data(iCollection,1) = cData;
    end
end

%%
strPath = ['C:\Users\Abhishek B\Documents\My Documents\My Duke Documents\Coursework\Energy 596 - Bass Connections in Energy\MATLAB Disagggregation Models\WattsUpData\Results\' description '\' item '.mat']
save(strPath,'data');

%%
ds = prtDataSetTimeSeries({data.power}) 
plot(ds)