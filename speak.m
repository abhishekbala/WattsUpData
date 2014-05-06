function speak(str,rate) 
% SPEAK Access built in windows speach synthesis
%   Uses the .NET language
%   http://blogs.mathworks.com/loren/2010/12/07/using-microsoft-net-to-expand-matlab-capabilities/?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+mathworks%2Floren+%28Loren+on+the+Art+of+MATLAB%29&utm_content=Google+Reader
%
% speak('Hey yawwwwll')
%
% fastRate = 10; %-[10-10]
% slowRate = -10; %-[10-10]
% speak('Hey yawwwwll',slowRate);
% speak('Hey yawwwwll',fastRate);

if ~ispc
    error('speak is only for PCs')
end

if nargin < 2 || isempty(rate)
    rate = 1;
end

% .NET code (ported to MATLAB)
NET.addAssembly('System.Speech');
speaker = System.Speech.Synthesis.SpeechSynthesizer();
speaker.Rate = rate;
speaker.Volume = 100;
speaker.Speak(str);