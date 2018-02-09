function varargout=fivedigitFreq3_maketgt(varargin); 
dummyscans      = 3; 
num_trials      = 2;    % # trials per trial type (speed x finger combo)
num_rests       = 7;    % # rests per block
length_rest     = 13.3; % length of rest (seconds)
time_announce   = 1;    % time for announce phase (seconds)
time_press      = 6;    % time for pressing phase (seconds)
ITI             = 1;    % inter-trial interval (seconds)
TR              = 1000; % time of scan (ms)
numPresses      = [2 4 8 16]; 
vararginoptions(varargin,{'dummyscans',...
                             'num_trials',...
                             'num_rests',...
                             'length_rest',...
                             'time_announce',...
                             'time_press',...
                             'ITI','TR',...
                             'numPresses'}); 

if (length(length_rest)==1)
    length_rest = ones(num_rests,1)*length_rest; 
end; 

length_rest     = length_rest(randperm(num_rests));
length_trial    = time_announce + time_press;
trials          = repmat([1:20],1,num_trials); 
trials          = sample_wor(trials',40,1); 
rests           = sample_wor([1:40]',num_rests,1); 
x               = dummyscans+1;                         % TR counter
r               = 1;                                    % rest counter
T               = [];                                   % prep output struct

for n=1:length(trials) 
    if isincluded(rests,n)
       x        = x+length_rest(r);
       r        = r+1; 
    end; 
    startSlice      = 1;                                
    D.startTime     = x*TR;                             
    x               = x + length_trial;                 
    D.endTime       = x*TR;                             
    D.digit         = mod(trials(n)-1,5)+1;
    D.numPresses    = numPresses(ceil(trials(n)/5));
    x               = x + ITI;
    T               = addstruct(T,D); 
end; 

varargout           = {T}; 