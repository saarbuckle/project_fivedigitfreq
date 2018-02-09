function varargout=fivedigitFreq3_maketgtall(varargin); 
numRuns         = 12;
sn              = 0;
dummyscans      = 3; 
num_trials      = 2;    % # trials per trial type (speed x finger combo)
num_rests       = 7;    % # rests per block
length_rest     = 13; % length of rest (imgs.)
time_announce   = 1;
time_press      = 6;
ITI             = 1;
TR              = 1000; 
numPresses      = [2 4 8 16]; 
vararginoptions(varargin,{'numRuns','numPresses','num_trials',...
    'num_Rests','length_rest','sn','ITI','time_announce','time_press','TR',...
    'dummyscans'});

for s=sn
    D = [];
    for i=1:numRuns
        T = fivedigitFreq3_maketgt('dummyscans',dummyscans,...
                                 'num_trials',num_trials,...
                                 'num_rests',num_rests,...
                                 'length_rest',length_rest,...
                                 'time_announce',time_announce,...
                                 'time_press',time_press,...
                                 'ITI',ITI,'TR',TR,...
                                 'numPresses',numPresses); 
        dsave(sprintf('fdf3_s%02d_%d.tgt',s,i),T);
        D = addstruct(D,T); 
    end
end; 