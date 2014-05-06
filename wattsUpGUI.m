function wattsUpGUI
%  
   %  Create and then hide the GUI as it is being constructed.
   f = figure('Visible','off','Position',[900, 1000, 1400, 570]);
 
   %  Construct the components.
   hcollect = uicontrol('Style','pushbutton','String','Begin Collection',...
          'Position',[1150,440,140,50],...
          'Callback',{@collectbutton_Callback});
   hstore = uicontrol('Style','pushbutton','String','Store Results',...
          'Position',[1150,360,140,50],...
          'Callback',{@storebutton_Callback});
   htext = uicontrol('Style','text','String','Select Appliance Data',...
          'Position',[1150,180,120,15]);
   hpopup = uicontrol('Style','popupmenu',...
          'String',{' ','INC','CFL','Fan01','Fan02','Fan03'},...
          'Position',[1150,100,200,50],...
          'Callback',{@popup_menu_Callback});
   ha1 = axes('Units','Pixels','Position',[100,120,400,370]);
   ha2 = axes('Units','Pixels','Position',[600,120,400,370]);
   align([hcollect,hstore,htext,hpopup],'Center','None');
   
   dsLogLike = zeros(0,5);
   dsClassNames = nan(0,5);
   bar(dsLogLike);
   set(gca, 'XTickLabel', dsClassNames);
   
   % Initialize the GUI.
   % Change units to normalized so components resize 
   % automatically.
   set([f,ha1,hcollect,hstore,htext,hpopup],...
   'Units','normalized');
   set([f,ha2,hcollect,hstore,htext,hpopup],...
   'Units','normalized');
   % Assign the GUI a name to appear in the window title.
   set(f,'Name','WattsUp GUI')
   % Move the GUI to the center of the screen.
   movegui(f,'center')
   % Make the GUI visible.
   set(f,'Visible','on');
 
   %  Callbacks for simple_gui. These callbacks automatically
   %  have access to component handles and initialized data 
   %  because they are nested at a lower level.
 
   %  Pop-up menu callback. Read the pop-up menu Value property
   %  to determine which item is currently displayed and make it
   %  the current data.
      function popup_menu_Callback(source,eventdata) 
         % Determine the selected data set.
%         str = get(source, 'String');
%         val = get(source,'Value');
%          % Set current data to the selected data set.
%          switch str{val};
%          case 'Peaks' % User selects Peaks.
%             current_data = peaks_data;
%          case 'Membrane' % User selects Membrane.
%             current_data = membrane_data;
%          case 'Sinc' % User selects Sinc.
%             current_data = sinc_data;
%          end
      end
  
   % Push button callbacks. Each callback plots current_data in
   % the specified plot type.
 
   function collectbutton_Callback(source,eventdata) 
      %% Extract Data
      [ds, classifierLoaded] = wattsUpEventDetector;
      ds = ds.retainObservations(cellfun(@length,ds.data)>0);
      plot(ha1, ds.expandedData);
      ds = ds.setClassNames(classifierLoaded.classNames);
      %classifierLoaded.classifierTrained.nObservations
      
      %% Log Likelihoods and Appliance Probabilities
      logLikelihoods = zeros(ds.nObservations, length(classifierLoaded.classifierTrained.rvs));
      for iY = 1:length(classifierLoaded.classifierTrained.rvs)
          logLikelihoods(:,iY) = getObservations(run(classifierLoaded.classifierTrained.rvs(iY), ds));
      end
      
      dsLogLike = prtDataSetClass(logLikelihoods);
      dsLogLike = dsLogLike.setClassNames(classifierLoaded.classNames);
      dsClassNames = classifierLoaded.classNames;
      bar(ha2, dsLogLike.data)
      set(gca, 'XTickLabel', dsClassNames);
      ylabel('Log Likelihoods');
      
      %% Cross validation
      dsOut = run(classifierLoaded.classifierTrained, ds);
      dsDecision = rt(prtDecisionMap,dsOut);
      decisionString = 'The appliance is most likely a ';
      for i=0:length(dsClassNames)
          if i==dsDecision.data
              dsClassNames_str = dsClassNames(i);
              dsClassNames_str = dsClassNames_str{1};
              decisionString = cat(2, decisionString, dsClassNames_str);
          end
      end
      speak(decisionString);
      
   end
 
   function storebutton_Callback(source,eventdata) 
      
   end
 
end 