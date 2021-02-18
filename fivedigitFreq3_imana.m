function varargout=fivedigitFreq3_imana(what,varargin)
% % function    varargout=fivedigitFreq3_imana(what,varargin)
%  
% Operates with vararginoptions, eg.:
%       fivedigitFreq3_imana(what,'sn',1,'roi',2)
%   
%
% UPDATE INFO IN SECTION 4 WITH EVERY NEW SUBJECT
%
% Imaging analysis code for fdf2 (fivedigitFrequency 2)
%   - Using 7T scanner at Robarts Research Inst. 
%   - TR=100[msec], 1.4mm isotropic (no gap, 52 slices) 
%   - Right fingerboard box with high force transducer
%   - 9 subjects (shared with sequenceHierarchical, sh2)
%   - pressed cued digit of right hand 2,4,8,or 16 times in 6 seconds
%   - cued with letters: 
%           E = thumb
%           I = index
%           M = middle
%           F = fourth
%           J = little
%
% IMPORTANT NOTES:
%   With every new subject, you must update variables in 'Subject Things'.
%
%      'dircheck' is a local function that creates a new directories so it
%      can save appropriate datafile structures. 
%
%   Of course, for full functionality you will need many functions from
%      various Diedrichsen Lab toolboxes (sourced through github and the
%      lab website).


% Spencer Arbuckle, Atsushi Yokoi, Joern Diedrichsen, UWO, 2017
% saarbuckle@gmail.com


% ------------------------- Directories -----------------------------------
fdf2BaseDir     ='/Users/sarbuckle/Documents/MotorControl/data/FingerPattern/fivedigitFreq2';

baseDir         ='/Users/sarbuckle/DATA/FingerPattern/fivedigitFreq3'; 
%codeDir ='C:\Users\saarb\Dropbox (Diedrichsenlab)\Arbuckle_code\projects\project_fivedigitfreq';
codeDir         ='/Users/sarbuckle/Dropbox (Diedrichsenlab)/Arbuckle_code/projects/project_fivedigitfreq';
behavDir        =[baseDir '/data'];                       %dircheck(behavDir);
imagingDir      =[baseDir '/imaging_data'];               %dircheck(imagingDir);
imagingDirRaw   =[baseDir '/imaging_data_raw'];           %dircheck(imagingDirRaw);
dicomDir        =[baseDir '/data_dicom'];                 %dircheck(dicomDir);
phaseDirDicom   =[baseDir '/phase_data_dicom'];
phaseDirRaw     =[baseDir '/phase_data_raw'];
phaseDir        =[baseDir '/phase_data'];
anatomicalDir   =[baseDir '/anatomicals'];                %dircheck(anatomicalDir);
freesurferDir   =[baseDir '/surfaceFreesurfer'];          %dircheck(freesurferDir);
caretDir        =[baseDir '/surfaceCaret'];               %dircheck(caretDir);
gpCaretDir      =[caretDir '/fsaverage_sym'];             %dircheck(gpCaretDir);   
regDir          =[baseDir '/RegionOfInterest/'];          %dircheck(regDir);
fieldmapDir     =[baseDir '/fieldmaps/'];
% update glmDir when adding new glms
glmDir          ={[baseDir '/glm1'],[baseDir '/glm2'],[baseDir '/glm3'],[baseDir '/glm4'],[baseDir '/glm5'],[baseDir '/glm6']};
    % dircheck(glmDir{1});
    % dircheck(glmDir{2});
    % dircheck(glmDir{3});

% set default plotting style
style.file(fullfile(codeDir,'fivedigitFreq3_style.m'));
style.use('default');

% ------------------------- Experiment Info -------------------------------
numDummys  = 3;      % per run
numTRs     = 430;    % per run (includes dummies)
TR_length  = 1;      % length of img acquisition in seconds
voxSize    = 1.4;    % mm^3
run        = {'1','2','3','4','5','6','7','8'};

% ------------------------- ROI things ------------------------------------
hem        = {'lh','rh'};                                                   % short-hand hemisphere strings for folder names/prefixes
regname    = {'sS1','sM1','sSMA','sMT','sV1','sV1/V2','Ba1','Ba2','B3a','B3b',...
              'oS1','oM1','oPMd','oPMv','oSMA','oV12','oSPLa','oSPLp'};     % s-prefix identifies that ROIs are "spencer" rois, o-prefix are rois from probabalistic atlases
regSide    = [ones(size(regname)),...                                       % 1 = left hemi (contra)
                ones(size(regname)).*2];                                    % 2 = right hemi (ipsi)
regType    = [1:length(regname),...                                         % roi # (within hemisphere)
                1:length(regname)];
numregions = max(regType);                                                  % total number of regions 
% title of regions ordered according to numerical call id (eg. 2 = Lh M1)
reg_title  = {'Lh sS1','Lh sM1','Lh sSMA','Lh sMT','Lh sV1','Lh sV1/V2',...     %1:6
              'Lh Ba1','Lh Ba2','Lh B3a','Lh B3b',...                           %7:10
              'Lh oS1','Lh oM1','Lh oPMd','Lh oPMv','Lh oSMA','Lh oV12','Lh oSPLa','Lh oSPLp',...   %11:18
              'Rh sS1','Rh sM1','Rh sSMA','Rh sMT','Rh sV1','Rh sV1/V2',...     %19:24
              'Rh Ba1','Rh Ba2','Rh B3a','Rh B3b',...                           %25:28
              'Rh oS1','Rh oM1','Rh oPMd','Rh oPMv','Rh oSMA','Rh oV12','Rh oSPLa','Rh oSPLp'}; %29:36

% ------------------------- Freesurfer things -----------------------------         
atlasA    = 'x';                                                            % freesurfer filename prefix
atlasname = 'fsaverage_sym';                                                % freesurfer average atlas
hemName   = {'LeftHem','RightHem'};                                         % freesurfer hemisphere folder names    
                              
% ------------------------- Voxel Depth/Layer things ----------------------
% Although not true cortical 'layers', these 'layers' facilitate 
% harvesting of data from voxels at specified depths along the grey matter 
% sheet. 
%
% The layers are:
%       1  :  'all' voxels
%       2  :  'superficial' voxels
%       3  :  'deep' voxels
%
% Voxels with a depth of zero (or negative) have their centroid located on
% (or above) the grey matter surface (constructed with freesurfer tools).
% Voxels with a depth of 1 (or greater) have their centroid located at (or
% in) the grey & pial matter juncture.
% Voxels may have centroids that don't fall within the grey matter sheet
% because they are still included in the grey matter mask, given portions
% of the voxel (and thus portions of their signal) originate from grey
% matter.
layers = { [-Inf Inf], [-Inf 0.5], [0.5 Inf] };
layer_name = {'all','superficial','deep'};

% ------------------------- Subject things --------------------------------
% The variables in this section must be updated for every new subject.
%       DiconName  :  first portion of the raw dicom filename
%       NiiRawName :  first protion of the nitfi filename (get after 'PREP_4d_nifti')
%       fscanNum   :  series # for corresponding functional runs. Enter in run order
%       pscanNum   :  ''.........................phase.........................''
%       anatNum    :  series # for anatomical scans (~208 or so imgs/series)
%       fieldNum   :  ''.........................fieldmaps (should be 2)
%       loc_AC     :  location of the anterior commissure. For some reason,
%                      files from this dataset were not recentred prior to
%                      surface reconstruction (even though 'PREP_centre_AC'
%                      was run for each subject). Thus, AC coords are not
%                      [0 0 0] in this dataset.
%
% The values of loc_AC should be acquired manually prior to the preprocessing
%   Step 1: get .nii file of anatomical data by running "spmj_tar2nii(TarFileName,NiiFileName)"
%   Step 2: open .nii file with MRIcron and manually find AC and read the xyz coordinate values
%           (note: there values are not [0 0 0] in the MNI coordinate)
%   Step 3: set those values into loc_AC (subtract from zero)

% although data is stored in different folders, subjects are named in
% conjunction with fiveDigitFreq2 experiment
subj_name   = {'','','s03','','','','s07','','','s10','s11','s12','s13','s14','s15','s16','s17'};
%fdf2_idx   = [7,3]; % corresponding fdf2 subject number in order they were re-scanned                       
loc_AC     = {[],[],[-104 -160 -167],...
              [],[],[],[-110 -165 -173],...
              [],[],[-102 -170 -175],...
              [-108 -174 -149],...
              [-106 -162 -170],...
              [-106 -169 -163],...
              [-108 -168 -169],...
              [-103 -167 -163],...
              [-105 -171 -168],...
              [-104 -160 -171]};
DicomName   = {'',...
               '',...
               '2017_01_19_FDF3_01.MR.DIEDRICHSEN_FINGERMAP',...
               '',...
               '',...
               '',...
               '2017_01_23_FDF3_S02.MR.DIEDRICHSEN_EXTFLEXSION',...
               '',...
               '',...
               '2017_03_14_FDF3_S10.MR.DIEDRICHSEN_EXTFLEXION',...
               '2017_04_04_FDF3_S11.MR.DIEDRICHSEN_EXTFLEXION',...
               '2017_04_05_FDF3_S12.MR.DIEDRICHSEN_EXTFLEXION',...
               '2017_04_06_FDF3_S13.MR.DIEDRICHSEN_FIVEDIGITFREQ',...
               '2017_05_09_FDF3_S14.MR.DIEDRICHSEN_FIVEDIGITFREQ',...
               '2017_05_10_FDF3_S15.MR.DIEDRICHSEN_FIVEDIGITFREQ',...
               '2017_05_17_FDF3_S16.MR.DIEDRICHSEN_FIVEDIGITFREQ',...
               '2017_05_18_FDF3_S17.MR.DIEDRICHSEN_FIVEDIGITFREQ'};
FNiiRawName  = {'',...
                '',...
                '170119151804STD131221107523418932',...
                '',...
                '',...
                '',...
                '170123151549STD131221107523418932',...
                '',...
                '',...
                '170314141439DST131221107523418932',...
                '170404145213DST131221107523418932',...
                '170405143438DST131221107523418932',...
                '170406140728DST131221107523418932',...
                '170509121328DST131221107523418932',...
                '170510120402DST131221107523418932',...
                '170517141503DST131221107523418932',...
                '170518141652DST131221107523418932'};
fscanNum    = {[],...      % functional data series numbers
               [],...
               [17 20 23 26 29 32 35 38],...
               [],...
               [],...
               [],...
               [17 20 23 26 29 35 38 41],...
               [],...
               [],...
               [16,19,22,25,28,31,34,37],...    % s10
               [16 19 22 25 28 31 34 37],...    % s11
               [15 18 21 27 30 33 36 39],...    % s12
               [18 21 24 27 39 42 45 48],...    % s13
               [16 19 22 25 28 31 34 37],...    % s14
               [16 19 22 25 28 31 34 37],...    % s15
               [21 24 27 30 33 36 39 42],...
               [16 19 22 25 28 34 37 40]};      
pscanNum    = {[],...      % phase data series numbers
               [],...
               [76 79 82 85 88 91 94 97],...
			   [],...
               [],...
               [],...
               [],...
			   [],...
               [],...
               [43 46 49 52 55 58 61 64],...    % s10
               [50 53 56 59 62 65 68 71],...    % s11
               [52 55 58 61 64 67 70 73],...    % s12
               [64 67 70 73 79 82 85 88],...    % s13
               [17 20 23 26 29 32 35 38],...    % s14
               [17 20 23 26 29 32 35 38],...    % s15
               [22 25 28 31 34 37 40 43],...
               [17 20 23 26 29 35 38 41]};      
anatNum     = {[],[],[],[],[],[],[],[],[],...
                [10:14],[13],[11],[13],[13],[12],[13],[13]};
            % fieldmap series numbers
fieldNum    = {[],[],[],[],[],[],[],[],[],[39,40],[39 40],[41 42],[50 51],[39 40],[39 40],[44 45],[42 43]};


% ------------------------- Analysis Cases --------------------------------
switch(what)
    case '0' % ------------ MISC: some aux. things ------------------------
    case 'MISC_check_time'                                                  % Check alignment of scanner and recorded time (sanity check): enter sn
        vararginoptions(varargin,{'sn'});
        %sn = Opt.sn;
        cd(behavDir);
        
        D = dload(sprintf('fdf3_%02d.dat',sn));
        figure('Name',sprintf('Timing of Task Onsets vs. TR onsets for Subj %d',sn),'NumberTitle','off')
        
        % plot alignment of TR time and trial onset time
        for b = unique(D.BN)'
            subplot(2,length(run),b);
            d = getrow(D,D.BN==b);
            %subplot(2,1,1); plot(D.realStartTime/1000,(D.realStartTR-1)*0.7+D.realStartTRTime/1000)
            plot(d.realStartTime/1000,(d.realStartTR-1)*(TR_length) + d.realStartTRTime/1000,'LineWidth',1.5,'Color','k')
            title(sprintf('run %s',run{b}));
            xlabel('trial start time (s)');
            ylabel('tr start time (s)');
            grid on
            axis equal
        end
        
        % plot difference of TR time and trial onset time
        subplot(2,length(run),[length(run)+1 : length(run)*2]); 
        plot(D.realStartTime/1000 - ((D.realStartTR-1)*TR_length + D.realStartTRTime/1000),'LineWidth',1.5,'Color','k')
        ylabel('trial onset - tr time (s)');
        xlabel('trial number');
        title('Difference of Trial onset time and TR time')
        xlim([0 length(run)*40]);
        hold on
        % draw line marking each new run
        for r = 2:length(run)
            drawline((r-1)*40,'dir','vert','linestyle',':');
        end
        hold off
        %keyboard
    case 'MISC_check_movement'                                              % Check movement of subject. Requires GLM 3 for specified subject.
        vararginoptions(varargin,{'sn'});
        glm = 3;
        load(fullfile(glmDir{glm},sprintf('s%02d',sn),'SPM.mat'));
        spm_rwls_resstats(SPM)       
    case 'MISC_checkDesignMatrix'
        vararginoptions(varargin,{'sn','glm'});
        load(fullfile(glmDir{glm},subj_name{sn},'SPM.mat'));
        imagesc(SPM.xX.X,[0 0.1]);
    case 'BEHA_getBehaviour'                                                % Harvest figner force data from fingerbox force traces
        % harvest pressing force data for each trial
        sn       = [10:13];
        vararginoptions(varargin,{'sn'});
        cwd = pwd;
        for s = sn;
            cd(behavDir);
            [D,ND] = fivedigitFreq2_subj(sprintf('%02d',s),0,1,1,'prefix','fdf3');
            % D  = force data of cued fingers
            % ND = force data of non-cued fingers
            save(fullfile(behavDir,sprintf('fdf3_forces_s%02d.mat',s)),'D');%,'ND');
        end
        varargout = {D,ND};
        cd(cwd);
    case 'MISC_SEARCH_calculate_contrast'                                   % Called by 'SEARCH_map_contrast': calculates distances from searchlight results at each node using submitted contrast matrix.
        vararginoptions(varargin,{'sn','glm','C','file'});
        % C = contrast matrix
        % file = filename of searchlight results (nifti extension)
        %   - file can be string array if calling for multiple subjs
        % % (1). Create variables that remain identical across subjs
        K = 20;                     % num conditions
        H = eye(K) - ones(K)/K;     % centering matrix (sets baseline to avg. for G)
        Y = [];                     % output structure
        
        % % Loop through subjects
        for s = sn
            % % (2). Load subject surface searchlight results (1 vol per paired conds)
            if length(sn)>1
                [subjDir,fname,ext] = fileparts(file{s-(s-1)});             % if looping over many subjs
            else
                [subjDir,fname,ext] = fileparts(file);                      % if doing for only one subj
            end
            cd(subjDir);
            vol  = spm_vol([fname ext]);
            vdat = spm_read_vols(vol);                                      % searchlight data
            % % (3). Get distances at each voxel
            [xVox,yVox,nslices,lRDM] = size(vdat);
            V.all = zeros((xVox*yVox*nslices),lRDM);                        % preallocate voxel full RDM field
            for i = 1:lRDM
                V.all(:,i) = reshape(vdat(:,:,:,i),[],1);                   % string out voxels to one dimension (easier indexing) & get distances described at each voxel
            end
            clear vdat
            
            % % (3). Calc G for each voxel, est. new distances
            LDC{s} = zeros((xVox*yVox*nslices),1);                          % preallocate new voxel RDM field
            % loop through voxels
            for v = 1:size(V.all,1)                     
                RDM         = rsa_squareRDM(V.all(v,:));                    % get RDM (all K conds)
                G           = -0.5*(H*RDM*H);                               % make G w/ centering matrix
                avgDist     = sum((C*G).*C,2)';                             % est. new distances
                LDC{s}(v,1) = nansum(avgDist)/size(C,1);                    % average across new distances for each voxel
            end
            clear V.all
            
            % % (4). Make output structure
            Ys.LDC = reshape(LDC{s},xVox,yVox,nslices);                     % re-arrange voxels to original space
            Ys.SN  = s;
            Ys.C   = C;
            Ys.dim = vol(1).dim;
            Ys.dt  = vol(1).dt;
            Ys.mat = vol(1).mat;
            Y = addstruct(Y,Ys);
            clear vol                                                      
        end
        varargout = {Y};
    case 'scatterplotSpeed'
        color           = {[0 0 0] [0.5 0 0] [0.9 0 0] [1 0.6 0]};
        CAT.markercolor = color;
        CAT.markerfill  = color;
        CAT.markertype  = 'o';
        CAT.markersize  = 10;
        
        linestyle = ':';
        dolabel   = 0;
        regress   = [];
        legnd     = {'2','4','8','16'};
        
        vararginoptions(varargin,{'data','split','label','dolabel','regress','linestyle'});
        % scatterplot data according to speed groupings
        if dolabel % labeling points?
            scatterplot(data(:,1),data(:,2),'split',split,'label',label,'CAT',CAT,'intercept',0,'regression',regress,'leg',legnd);
        else
            scatterplot(data(:,1),data(:,2),'split',split,'CAT',CAT,'intercept',0,'regression',regress,'leg',legnd);
        end;
        % change font properties
        h = get(gca);
        %set(h,'FontName','Myriad Pro');
        %h.FontSize = 13;
        % if plotting regression line, change line properties (for each
        % speed)
        if regress
            for spd = 1:2:8
                h.Children(spd).LineStyle = ':';
                h.Children(spd).LineWidth = 2;
            end
        end;
        
        axis equal;
        xlim([-0.05 0.25])
        ylim([-0.05 0.25])
        drawline(0,'dir','horz');
        drawline(0);
        %__________________________________________________________________    
    case 'scatterplotMDS'
        linewidth = 1;
        
        color           = {[0 0 0] [0.5 0 0] [0.9 0 0] [1 0.6 0]};
        CAT.markercolor = color;
        CAT.markerfill  = color;
        CAT.markertype  = 'o';
        CAT.markersize  = 6;
        
        Y     = varargin{1};
        speed = varargin{2};
        digit = varargin{3};
        lines = varargin{4};
        roi   = varargin{5};
        % get labels (digits for sensorimotor, letters for visual rois)
        if roi==16 | roi==34 | roi==6 | roi==24
            letter_label = {'E','I','M','F','J'};
            t = [];
            for i = 1:length(digit)
                t{i,1} = letter_label{digit(i)};
            end
            labelformat='%s';
            digit = t;
        else
            labelformat='%d';
        end
        % plot
        scatterplot3(Y(1:20,1),Y(1:20,2),Y(1:20,3),'split',speed,'label',digit,'labelformat',labelformat,'CAT',CAT);
        % format plot
        if lines
            if roi==16 | roi==34 % draw lines differently for visual cortices
                for i=1:4
                    hold on;
                    indx=[1,2,5,4,3,1]'+(i-1)*5;
                    line(Y(indx,1),Y(indx,2),Y(indx,3),'color',color{i},'LineWidth',linewidth);
                end
            elseif roi==6 | roi==24 % draw lines differently for visual cortices
                for i=1:4
                    hold on;
                    indx=[1,2,5,4,3,1]'+(i-1)*5;
                    line(Y(indx,1),Y(indx,2),Y(indx,3),'color',color{i},'LineWidth',linewidth);
                end
            else
                for i=1:4
                    hold on;
                    indx=[1:5 1]'+(i-1)*5;
                    line(Y(indx,1),Y(indx,2),Y(indx,3),'color',color{i},'LineWidth',linewidth);
                end
            end
        end;
        if (size(Y,1)==21) % if rest is explicitly modeled
            hold on;
            plot3(Y(21,1),Y(21,2),Y(21,3),'+');
            hold off;
        else % if rest is implicitly modeled (i.e. rest is zero)
            hold on;
            plot3(0,0,0,'+');
            hold off;
        end;
        axis equal;
        xlabel pc1
        ylabel pc2
        zlabel pc3
        
        %__________________________________________________________________
    case 'scatterplotMDS_black'
        color={[0.9 0 0] [1 0.6 0] [1 1 0.2] [1 1 1]};
        CAT.markercolor=color;
        CAT.markerfill=color;
        CAT.markertype='o';
        CAT.markersize=10;
        
        
        Y     = varargin{1};
        speed = varargin{2};
        digit = varargin{3};
        
        scatterplot3(Y(1:20,1),Y(1:20,2),Y(1:20,3),'split',speed,'label',digit,...
            'labelcolor',[1 1 1],'CAT',CAT,'labelsize',17,'labelfont','Arial');
        
        for i=1:4
            hold on;
            indx=[1:5 1]'+(i-1)*5;
            h=line(Y(indx,1),Y(indx,2),Y(indx,3),'color',color{i},'LineWidth',3);
        end;
        
        if (size(Y,1)==21)
            hold on;
            h=plot3(Y(21,1),Y(21,2),Y(21,3),'w+','MarkerSize',12);
            hold off;
        end;
        axis equal vis3d;
        set(gca,'Color',[ 0 0 0],'GridColor',[0.3 0.3 0.3],'GridAlpha',1,...
            'XTickLabel',{},'YTickLabel',{},'ZTickLabel',{},...
            'XColor',[1 1 1],'YColor',[1 1 1],'ZColor',[1 1 1],...
            'XLimMode','manual','YLimMode','manual','ZLimMode','manual');
        
        %__________________________________________________________________
     
    case '0' % ------------ PREP: preprocessing. Expand for more info. ----
        % The PREP cases are preprocessing cases. 
        % You should run these in the following order:
        %       'PREP_dicom_import'* :  call with 'series_type','functional', 
        %                               and again with
        %                               'series_type','anatomical'.
        %       'PREP_process1'      :  Runs steps 1.3 - 1.7 (see below).
        %       'PREP_coreg'*        :  Registers meanepi to anatomical img. (step 1.8)
        %       'PREP_process2'*     :  Runs steps 1.9 - 1.11 (see below).
        %
        %   * requires user input/checks after running BEFORE next steps.
        %       See corresponding cases for more info about required
        %       user input.
        %
        % When calling any case, you can submit an array of Subj#s as so:
        %       ('some_case','sn',[Subj#s])
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    case 'WRAPPER_dicom_import'                                             % imports dicoms for ONE subject
        % converts dicom to nifti files w/ spm_dicom_convert
        vararginoptions(varargin,{'sn'});
        fivedigitFreq3_imana('PREP_dicom_import','sn',sn,'series_type','anatomical');
        fivedigitFreq3_imana('PREP_dicom_import','sn',sn,'series_type','functional');
        fivedigitFreq3_imana('PREP_dicom_import','sn',sn,'series_type','phase');
        fivedigitFreq3_imana('PREP_dicom_import','sn',sn,'series_type','fieldmap');    
    case 'PREP_dicom_import'                                                % STEP 1.1/2 :  Import functional/anatomical dicom series: enter sn
        % converts dicom to nifti files w/ spm_dicom_convert
        series_type = 'functional';
        vararginoptions(varargin,{'sn','series_type'});
        cwd = pwd;
        switch series_type
            case 'functional'
                seriesNum = fscanNum;
            case 'anatomical'
                seriesNum = anatNum;  
            case 'fieldmap'
                seriesNum = fieldNum;
        	case 'phase'
        		seriesNum = pscanNum;
        end
        
        % Loop through subjects
        for s = sn;
            cd(fullfile(dicomDir,subj_name{s}));
            % For each series number of this subject (in 'Subject Things')
            for i=1:length(seriesNum{s})
                r     = seriesNum{s}(i);
                % Get DICOM FILE NAMES
                DIR   = dir(sprintf('%s.%4.4d.*.IMA',DicomName{s},r));          
                Names = vertcat(DIR.name);
                % Convert the dicom files with these names.
                if (~isempty(Names))
                    % Load dicom headers
                    HDR=spm_dicom_headers(Names,1);  
                    % Make a directory for series{r} for this subject.
                    % The nifti files will be saved here.
                    dirname = fullfile(dicomDir,subj_name{s},sprintf('series%2.2d',r));
                    dircheck(dirname);
                    % Go to the dicom directory of this subject
                    cd(dirname);
                    % Convert the data to nifti
                    spm_dicom_convert(HDR,'all','flat','nii');                  
                    cd ..
                end
                display(sprintf('Series %d done \n',seriesNum{s}(i)))
            end
            % Display verbose messages to user. 
            % Lazy and won't include none-verbose version here.
            switch series_type
                case 'functional'
                    fprintf('Subject %02d functional runs imported. Copy the unique .nii name for subj files and place into ''Subject Things''.\n',s)
                case 'anatomical'
                    fprintf('Anatomical runs have been imported for subject %d.\n',s); 
                    fprintf('Please locate the T1 weighted anatomical img. Copy it to the anatomical folder.\n');
                    fprintf('Rename this file to ''s%02d_anatomical_raw.nii'' in the anatomical folder.\n',s); 
                case 'fieldmap'
                    fprintf('Subject %02d fieldmaps imported.\n');
                    fprintf('Copy magnitude and phase imgs and move to fieldmaps folder.\n');
                    fprintf('Rename files as follows in fieldmap folder:.\n');
                    fprintf('''s%02d_magnitude.nii''\n',s);
                    fprintf('''s%02d_phase.nii''\n',s);
            end
        end
        cd(cwd);           
    case 'WRAPPER_preprocess1'                                                   
        % NEEDS JAVA FUNCTIONALITY (cannot run through terminal)
        vararginoptions(varargin,{'sn'});
        
        for s = sn
            fivedigitFreq3_imana('PREP_make_4dNifti','sn',s,'series_type','functional');
            fivedigitFreq3_imana('PREP_make_4dNifti','sn',s,'series_type','phase');
            if s>9
                fivedigitFreq3_imana('PREP_makefieldmap','sn',s);
                fivedigitFreq3_imana('PREP_make_realign_unwarp','sn',s);
            else
                fivedigitFreq3_imana('PREP_realign','sn',s);
            end
            fivedigitFreq3_imana('PREP_move_data','sn',s);
            fivedigitFreq3_imana('PREP_reslice_LPI','sn',s);
            fivedigitFreq3_imana('PREP_centre_AC','sn',s);
            fivedigitFreq3_imana('PREP_meanimage_bias_correction','sn',s);
        end
    case 'PREP_make_4dNifti'                                                % STEP 1.3   :  Converts dicoms to 4D niftis out of your raw data files
        series_type = 'functional';
        vararginoptions(varargin,{'sn','series_type'});
        cwd = pwd;
        switch series_type
            case 'functional'
                seriesNum = fscanNum;
                niiName   = FNiiRawName;
                fname     = '';
                outDir    = imagingDirRaw;
        	case 'phase'
        		seriesNum = pscanNum;
                niiName   = FNiiRawName; % same naming convention
                fname     = 'phase_';
                outDir    = phaseDirRaw;
        end
        for s = sn
            % For each functional run
            for i = 1:length(seriesNum{s})                                      
                outfilename = fullfile(outDir,subj_name{s},sprintf('%s%s_run_%2.2d.nii',fname,subj_name{s},i));
                % Create a 4d nifti of all imgs in this run.
                % Don't include the first few dummy scans in this 4d nifti.
                for j = 1:(numTRs-numDummys)                                        
                    P{j} = fullfile(dicomDir,subj_name{s},sprintf('series%2.2d',seriesNum{s}(i)),...
                            sprintf('f%s-%4.4d-%5.5d-%6.6d-01.nii',niiName{s},seriesNum{s}(i),j+numDummys,j+numDummys));
                end;
                % check if output directory exists- if not, make it
                dircheck(fullfile(outDir,subj_name{s}))
                % merge and save 3d niftis to 4d
                spm_file_merge(char(P),outfilename);
                fprintf('Run %d done\n',i);
            end
        end
    case 'PREP_makefieldmap'
        sn = 10;
        prefix = '';
        vararginoptions(varargin,{'sn','prefix'});
        if sn<10
            error('no fieldmaps acquired for these subjects. Use ''PREP_realign''');
        end
        run    = {'_01','_02','_03','_04','_05','_06','_07','_08'};
        spmj_makefieldmap(baseDir, subj_name{sn}, run,'prefix',prefix);
    case 'PREP_make_realign_unwarp'
        sn = 10;
        prefix  ='';
        vararginoptions(varargin,{'sn','prefix'});
        if sn<10
            error('no fieldmaps acquired for these subjects. Use ''PREP_realign''');
        end
        run     = {'_01','_02','_03','_04','_05','_06','_07','_08'};
        spmj_realign_unwarp_sess(baseDir,subj_name{sn},{run},numTRs,'prefix',prefix);
    case 'PREP_realign'                                                     % STEP 1.4   :  Realign functinoal runs
        % SPM realigns first volume in each run to first volume of first
        % run, and then registers each image in that run to the first
        % volume of that run. Hence also why it's often better to run
        % anatomical before functional scans.

        % SPM does this with 4x4 affine transformation matrix in nifti
        % header (see function 'coords'). These matrices convert from voxel
        % space to world space(mm). If the first image has an affine
        % transformation matrix M1, and image two has one (M2), the mapping
        % from 1 to 2 is: M2/M1 (map image 1 to world space-mm - and then
        % mm to voxel space of image 2).

        % Registration determines the 6 parameters that determine the rigid
        % body transformation for each image (described above). Reslice
        % conducts these transformations; resampling each image according
        % to the transformation parameters. This is for functional only!
        
        % Appends prefix 'r' to realigned imgs.
        prefix='';
        vararginoptions(varargin,{'sn','prefix'});
%         if sn>9
%             error('use fieldmap correction for subject 10');
%         end

        cd(fullfile(imagingDirRaw,subj_name{sn}));
        for s=sn;
            data={};
            for i=1:length(fscanNum{sn});
                for j=1:numTRs-numDummys;
                    data{i}{j,1}=sprintf('%s%s_run_%2.2d.nii,%d',char(prefix),subj_name{sn},i,j);
                end;
            end;
            spmj_realign(data);
            fprintf('Subj %d realigned\n',s);
        end;


    %__________________________________________________________________
    case 'PREP_move_data'                                                   % STEP 1.5   :  Moves subject data from raw directories to working directories
        % Moves image data from imaging_dicom_raw into a "working dir":
        % imaging_dicom.                               
        prefix=''; 
        vararginoptions(varargin,{'sn','prefix'});
        prefix = getCorrectPrefix(sn,prefix,what);
        
        dircheck(fullfile(baseDir, 'imaging_data',subj_name{sn}))
        for r=1:length(run);
            % realigned niftis
            source = fullfile(baseDir, 'imaging_data_raw',subj_name{sn}, [char(prefix) subj_name{sn},'_run_0',run{r},'.nii']);
            dest = fullfile(baseDir, 'imaging_data',subj_name{sn}, [char(prefix) subj_name{sn},'_run_0',run{r},'.nii']);
            copyfile(source,dest);
            % realignment txt files
            source = fullfile(baseDir, 'imaging_data_raw',subj_name{sn}, ['rp_' subj_name{sn},'_run_0',run{r},'.txt']);
            dest = fullfile(baseDir, 'imaging_data',subj_name{sn}, ['rp_' subj_name{sn},'_run_0',run{r},'.txt']);
            copyfile(source,dest);
        end;
        % realigned meanepi file
        source = fullfile(baseDir, 'imaging_data_raw',subj_name{sn}, ['mean' char(prefix) subj_name{sn},'_run_0',run{1},'.nii']);
        dest = fullfile(baseDir, 'imaging_data',subj_name{sn}, [char(prefix) 'meanepi_' subj_name{sn} '.nii']);
        copyfile(source,dest);


    %__________________________________________________________________
    case 'PREP_reslice_LPI'                                                 % STEP 1.6   :  Reslice anatomical image within LPI coordinate systems
        vararginoptions(varargin,{'sn'});

        % (1) Reslice anatomical image to set it within LPI co-ordinate frames
        source  = fullfile(anatomicalDir,subj_name{sn},[subj_name{sn}, '_anatomical_raw','.nii']);
        dest    = fullfile(anatomicalDir,subj_name{sn},[subj_name{sn}, '_anatomical','.nii']);
        spmj_reslice_LPI(source,'name', dest);

        % (2) In the resliced image, set translation to zero
        V               = spm_vol(dest);
        dat             = spm_read_vols(V);
        V.mat(1:3,4)    = [0 0 0];
        spm_write_vol(V,dat);
        display 'Done'


    %___________
    case 'PREP_centre_AC'                                                   % STEP 1.7   :  Re-centre AC in anatomical image
        % Set origin of anatomical to anterior commissure (must provide
        % coordinates in section (4)).
        vararginoptions(varargin,{'sn'});

        img             = fullfile(anatomicalDir,subj_name{sn},[subj_name{sn}, '_anatomical','.nii']);
        V               = spm_vol(img);
        dat             = spm_read_vols(V);
        V.mat(1:3,4)    = loc_AC{sn};
        spm_write_vol(V,dat);
        display 'Done'


    %_____
    case 'PREP_meanimage_bias_correction'    % STEP 2.6: Bias correct mean image prior to coregistration
        prefix = '';
        vararginoptions(varargin,{'sn','prefix'});
        prefix = getCorrectPrefix(sn,prefix,what);
        
        % make copy of original mean epi, and work on that
        source  = fullfile(baseDir, 'imaging_data',subj_name{sn},[char(prefix) 'meanepi_' subj_name{sn} '.nii']);
        dest    = fullfile(baseDir, 'imaging_data',subj_name{sn},['b' char(prefix) 'meanepi_' subj_name{sn} '.nii']);
        copyfile(source,dest);
        
        % bias correct mean image for grey/white signal intensities 
        P{1}    = dest;
        spmj_bias_correct(P);
    case 'PREP_coreg'                                                       % STEP 1.8   :  Coregister meanepi to anatomical image
        % (1) Manually seed the functional/anatomical registration
        % - Do "coregtool" on the matlab command window
        % - Select anatomical image and meanepi image to overlay
        % - Manually adjust meanepi image and save result as rmeanepi
        %   image
        prefix = '';
        vararginoptions(varargin,{'sn','prefix'});
        prefix = getCorrectPrefix(sn,prefix,what);
        
        cd(fullfile(anatomicalDir,subj_name{sn}));
        coregtool;
        keyboard();
        
        % (2) Automatically co-register functional and anatomical images
        
        J.ref = {fullfile(anatomicalDir,subj_name{sn},[subj_name{sn}, '_anatomical','.nii'])};
        J.source = {fullfile(imagingDir,subj_name{sn},['rbb' char(prefix) 'meanepi_' subj_name{sn} '.nii'])}; 
        J.other = {''};
        J.eoptions.cost_fun = 'nmi';
        J.eoptions.sep = [4 2];
        J.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
        J.eoptions.fwhm = [7 7];
        matlabbatch{1}.spm.spatial.coreg.estimate=J;
        spm_jobman('run',matlabbatch);
        
        % (3) Manually check again
        coregtool;
        keyboard();
        
        % NOTE:
        % Overwrites meanepi, unless you update in step one, which saves it
        % as rmeanepi.
        % Each time you click "update" in coregtool, it saves current
        % alignment by appending the prefix 'r' to the current file
        % So if you continually update rmeanepi, you'll end up with a file
        % called r...rrrmeanepi.
        
        %__________________________________________________________________
    case 'WRAPPER_preprocess2'                                                   
        vararginoptions(varargin,{'sn'});
        
        for s = sn
            fivedigitFreq3_imana('PREP_make_samealign','sn',s);
            fivedigitFreq3_imana('PREP_segmentation','sn',s);
            fivedigitFreq3_imana('PREP_make_maskImage','sn',s);
            display('Run spmj_checksamealign to check alignment of run_epi to rmean_epi')
            %spmj_checksamealign
        end
    case 'PREP_make_samealign'                                              % STEP 1.9   :  Align to first image (rbmeanepi_* of first session)
        prefix = '';
        vararginoptions(varargin,{'sn','prefix'});
        prefix = getCorrectPrefix(sn,prefix,what);

        cd(fullfile(imagingDirRaw,subj_name{sn}));

        % Select image for reference
        P{1} = fullfile(imagingDir,subj_name{sn},sprintf('rbb%smeanepi_%s.nii',char(prefix),subj_name{sn}));

        % Select images to be realigned
        Q={};
        for r=1:numel(run)
            for i=1:numTRs-numDummys;
                Q{end+1}    = fullfile(imagingDir,subj_name{sn},...
                    sprintf('%s%s_run_%2.2d.nii,%d',char(prefix), subj_name{sn},r,i));
            end;
        end;

        % Run spmj_makesamealign_nifti to bring all functional runs into
        % same space as realigned mean epis
        spmj_makesamealign_nifti(char(P),char(Q));
        fprintf('Done. Run spmj_checksamealign to check alignment.\n')
        %spmj_checksamealign
    case 'PREP_segmentation'                                                % STEP 1.10  :  Segmentation & normalization
        vararginoptions(varargin,{'sn'});

        SPMhome=fileparts(which('spm.m'));
        J=[];
        for s=sn
            J.channel.vols = {fullfile(anatomicalDir,subj_name{sn},[subj_name{sn},'_anatomical.nii,1'])};
            J.channel.biasreg = 0.001;
            J.channel.biasfwhm = 60;
            J.channel.write = [0 0];
            J.tissue(1).tpm = {fullfile(SPMhome,'tpm/TPM.nii,1')};
            J.tissue(1).ngaus = 1;
            J.tissue(1).native = [1 0];
            J.tissue(1).warped = [0 0];
            J.tissue(2).tpm = {fullfile(SPMhome,'tpm/TPM.nii,2')};
            J.tissue(2).ngaus = 1;
            J.tissue(2).native = [1 0];
            J.tissue(2).warped = [0 0];
            J.tissue(3).tpm = {fullfile(SPMhome,'tpm/TPM.nii,3')};
            J.tissue(3).ngaus = 2;
            J.tissue(3).native = [1 0];
            J.tissue(3).warped = [0 0];
            J.tissue(4).tpm = {fullfile(SPMhome,'tpm/TPM.nii,4')};
            J.tissue(4).ngaus = 3;
            J.tissue(4).native = [1 0];
            J.tissue(4).warped = [0 0];
            J.tissue(5).tpm = {fullfile(SPMhome,'tpm/TPM.nii,5')};
            J.tissue(5).ngaus = 4;
            J.tissue(5).native = [1 0];
            J.tissue(5).warped = [0 0];
            J.tissue(6).tpm = {fullfile(SPMhome,'tpm/TPM.nii,6')};
            J.tissue(6).ngaus = 2;
            J.tissue(6).native = [0 0];
            J.tissue(6).warped = [0 0];
            J.warp.mrf = 1;
            J.warp.cleanup = 1;
            J.warp.reg = [0 0.001 0.5 0.05 0.2];
            J.warp.affreg = 'mni';
            J.warp.fwhm = 0;
            J.warp.samp = 3;
            J.warp.write = [0 0];
            matlabbatch{1}.spm.spatial.preproc=J;
            spm_jobman('run',matlabbatch);
            fprintf('Check segmentation results for %s\n', subj_name{s})
        end;


    %__________________________________________________________________
    case 'PREP_make_maskImage'                                              % STEP 1.11  :  Make mask images (noskull and gray_only)
        prefix = '';
        vararginoptions(varargin,{'sn','prefix'});
        prefix = getCorrectPrefix(sn,prefix,what);
        
        if strcmp(prefix,'u')
            outprefix = '';
        else
            outprefix = prefix;
        end

        cd(fullfile(imagingDir,subj_name{sn}));

        nam{1}  = fullfile(imagingDir,subj_name{sn}, ['rbb' char(prefix) 'meanepi_' subj_name{sn} '.nii']);
        nam{2}  = fullfile(anatomicalDir, subj_name{sn}, ['c1' subj_name{sn}, '_anatomical.nii']);
        nam{3}  = fullfile(anatomicalDir, subj_name{sn}, ['c2' subj_name{sn}, '_anatomical.nii']);
        nam{4}  = fullfile(anatomicalDir, subj_name{sn}, ['c3' subj_name{sn}, '_anatomical.nii']);
        outfile = ['r' char(outprefix) 'mask_noskull.nii'];
        spm_imcalc_ui(nam, outfile, 'i1>1 & (i2+i3+i4)>0.2');

        nam={};
        nam{1}  = fullfile(imagingDir,subj_name{sn}, ['rbb' char(prefix) 'meanepi_' subj_name{sn} '.nii']);
        nam{2}  = fullfile(anatomicalDir, subj_name{sn}, ['c1' subj_name{sn}, '_anatomical.nii']);
        outfile = ['r' char(outprefix) 'mask_gray.nii'];
        spm_imcalc_ui(nam, outfile, 'i1>1 & i2>0.4');
        
    case '0' % ------------ PHASE: phase regression funcs. Expand for more info. -    
    case 'PHASE_raw_4dnii'                  
        vararginoptions(varargin,{'sn'});
        
        for i = 1:length(pscanNum{sn})                                        % run number
            outfilename = fullfile(phaseDirRaw,subj_name{sn},sprintf('%s_phase_run_%2.2d.nii',subj_name{sn},i));
            for j = 1:(numTRs-numDummys)                                    % doesn't include dummy scans in .nii file
                P{j} = fullfile(phaseDirDicom,subj_name{sn},sprintf('series%2.2d',pscanNum{sn}(i)),...
						sprintf('f%s-%4.4d-%5.5d-%6.6d-01.nii',PNiiRawName{sn},pscanNum{sn}(i),j+numDummys,j+numDummys));
            end;
            dircheck(fullfile(phaseDirRaw,subj_name{sn}))
            spm_file_merge(char(P),outfilename);
            fprintf('Run %d done\n',i);
		end;
    case 'PHASE_preprocess'
        sn         = 3;
        mask_type  = 'none';  % shouldn't have mask here b/c not aligned
        vararginoptions(varargin,{'sn','mask_type'});
        % get filenames for runs
        Q = {};
        for r = 1:length(run);
            Q{end+1} = fullfile(phaseDir,subj_name{sn}, [subj_name{sn},'_phase_run_0',run{r},'.nii']);
        end;
        % Voxel Mask setup ('grey', 'noskull', or 'none')
        switch mask_type
            case 'gray'
                maskFile  = fullfile(imagingDir,subj_name{sn},'rmask_gray.nii');
            case 'noskull'
                maskFile  = fullfile(imagingDir,subj_name{sn},'rmask_noskull.nii');
            case 'none'
                maskFile = {};
        end;
        % do preprocessing
        fprintf('Subj %d',sn)
        phase_preprocessPhase(Q,'verbose',1,'maskFile',maskFile);  
    case 'PHASE_align'              % Align all phase data according to aligned epi img.
        sn = 3;
        vararginoptions(varargin,{'sn'});
        % get filenames for runs
        Q = {};
        for r = 1:length(run);
            Q{end+1} = fullfile(phaseDir,subj_name{sn}, ['p' subj_name{sn},'_phase_run_0',run{r},'.nii']);
        end;
        % get rigid transform matrix from realign mean epi
        V = spm_vol(fullfile(imagingDir,subj_name{sn},sprintf('rbbmeanepi_%s.nii',subj_name{sn})));
        % align phase niftis accordingly (follow steps of spm alignment)
        phase_alignPhaseNii(Q,V.mat);
        % Checks:
        fprintf('Done Phase alignment. Run checks.\n')
        %spmj_checksamealign
        % can also check w/ coregtool by visualizing run specific phase
        % overlay on subject's anatomical
        %coregtool
    case 'PHASE_olsFit'
        sn         = 3;
        mask_type  = 'noskull';  % shouldn't have mask here b/c not aligned
        vararginoptions(varargin,{'sn','mask_type'});
        % get filenames for runs
        phaseFiles = {};
        magFiles   = {};
        for r = 1:length(run);
            phaseFiles{end+1} = fullfile(phaseDir,subj_name{sn}, ['rp' subj_name{sn},'_phase_run_0' num2str(r) '.nii']);
            magFiles{end+1}   = fullfile(imagingDir,subj_name{sn}, ['r' subj_name{sn},'_run_0' num2str(r) '.nii']);
        end;
        % Voxel Mask setup ('grey', 'noskull', or 'none')
        switch mask_type
            case 'gray'
                maskFile  = fullfile(imagingDir,subj_name{sn},'rmask_gray.nii');
            case 'noskull'
                maskFile  = fullfile(imagingDir,subj_name{sn},'rmask_noskull.nii');
            case 'none'
                maskFile = {};
        end;
        % do fitting
        fprintf('Subj %d',sn)
        phase_fitPhase(phaseFiles,magFiles,'verbose',1,'maskFile',maskFile);  
        
    case '0' % ------------ SURF: Freesurfer funcs. Expand for more info. -
        % The SURF cases are the surface reconstruction functions. Surface
        % reconstruction is achieved via freesurfer.
        % All functions can be called with ('SURF_processAll','sn',[Subj#s]).
        % You can view reconstructed surfaces with Caret software.
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    case 'WRAPPER_SURF'                                                 
        vararginoptions(varargin,{'sn'});
        % You can call this case to do all the freesurfer processing.
        % 'sn' can be an array of subjects because each processing case
        % contained within loops through the subject array submitted to the
        % case.
        fivedigitFreq3_imana('SURF_freesurfer','sn',sn);
        fivedigitFreq3_imana('SURF_xhemireg','sn',sn);
        fivedigitFreq3_imana('SURF_map_ico','sn',sn);
        fivedigitFreq3_imana('SURF_make_caret','sn',sn);
    case 'SURF_freesurfer'                                                  % STEP 2.1
        vararginoptions(varargin,{'sn'});
        for i=sn
            freesurfer_reconall(freesurferDir,subj_name{i},fullfile(anatomicalDir,subj_name{i},[subj_name{i} '_anatomical.nii']));
        end
    case 'SURF_xhemireg'                                                    % STEP 2.2   :  Cross-Register surfaces left / right hem
        vararginoptions(varargin,{'sn'});
        for i=sn
            freesurfer_registerXhem({subj_name{i}},freesurferDir,'hemisphere',[1 2]); % For debug... [1 2] orig
        end;
    case 'SURF_map_ico'                                                     % STEP 2.3   :  Align to the new atlas surface (map icosahedron)
        vararginoptions(varargin,{'sn'});
        for i=sn
            freesurfer_mapicosahedron_xhem(subj_name{i},freesurferDir,'smoothing',1,'hemisphere',[1:2]);
        end;
    case 'SURF_make_caret'                                                  % STEP 2.4   :  Translate into caret format
        vararginoptions(varargin,{'sn'});
        for i=sn
            caret_importfreesurfer(['x' subj_name{i}],freesurferDir,caretDir);
        end;
    
    case '0' % ------------ GLM: SPM GLM fitting. Expand for more info. ---
        % The GLM cases fit general linear models to subject data with 
        % SPM functionality.
        %
        % All functions can be called with ('GLM_processAll','sn',[Subj#s]).
        %
        % You can view reconstructed surfaces with Caret software.
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    case 'WRAPPER_GLM'                                                   
        glm = 3;
        vararginoptions(varargin,{'sn','glm'});
        % You can call this case to do all the GLM estimation.
        for s = sn
            for g = glm
                fivedigitFreq3_imana('GLM_make','sn',s,'glm',g);
                fivedigitFreq3_imana('GLM_estimate','sn',s,'glm',g);
                %fivedigitFreq3_imana('GLM_contrast','sn',s,'glm',g);
            end
        end
    case 'GLM_make'                                                         % STEP 3.1   :  Make the SPM.mat and SPM_info.mat files (prep the GLM)
        prefix = '';
        vararginoptions(varargin,{'sn','glm','prefix'});
        prefix = getCorrectPrefix(sn,prefix,what);
        % Set some constants.
        T			 = [];
        dur			 = 6;                                                   % secs (length of task dur, not trial dur)
        announcetime = 0;                                                   % length of task announce time
        % Gather appropriate GLM presets.
        rm_errors  = 0;
        switch glm
            case 6
                hrf_params = [4.5 11];
                hrf_cutoff = inf;
                cvi_type   = 'fast';
                prefix     = 'MAr'; % use macro-vasculature BOLD
            case 5
                hrf_params = [4.5 11];
                hrf_cutoff = inf;
                cvi_type   = 'fast';
                prefix     = 'umi'; % use micro-vasculature BOLD
            case 4      % remove trials with errors            
                hrf_params = [4.5 11];
                hrf_cutoff = inf;
                cvi_type   = 'fast';
                rm_errors  = 1;
            case 3
                hrf_params = [4.5 11];
                hrf_cutoff = inf;
                cvi_type   = 'fast';
            case 2
                hrf_params = [4.5 11];
                hrf_cutoff = 128;
                cvi_type   = 'fast';
            case 1
                hrf_params = [4.5 11];
                hrf_cutoff = 128;
                cvi_type   = 'wls';
        end
        % Loop through subjects and make SPM files.
        for s = sn
            %D			   = dload(fullfile(baseDir, 'data',['fdf3_',subj_name{s}(2:3),'.dat']));
            load(fullfile(behavDir,sprintf('fdf3_forces_s%02d.mat',s)));
            [~,~,D.speed]  = unique(D.numPresses);
            D.tt		   = (D.speed-1)*5+D.digit;                         % determine condition numbers (see README in fdf3 data folder)
            
            if rm_errors  % remove trials with errors in # presses (within tolerance limit)...also recode if necessary (as different trial type)
                deviations = D.numPresses-D.numPeaks;                       % difference b/t cued # presses & actual # presses
                keep       = zeros(size(deviations));
                recode     = keep;
                tolerance  = [0,0,1,2];
                % first pass- exlucde trials (within tolerance limit)
                for spd = 1:4
                    recode(D.speed==spd,1) = logical(abs(deviations(D.speed==spd,1))>tolerance(spd));
                end
                % second pass- check to recode trials as diff. pressing spd
                if sum(recode)>0
                    recode_indx = find(recode==1);
                    actual_spd  = floor(log2(D.numPresses(recode==1)-deviations(recode==1)));
                    do_recode   = logical(ismember(actual_spd,[1:4]));
                    recode_indx = recode_indx(do_recode);
                    D.speed(recode_indx) = actual_spd(do_recode);
                    D.tt	    = (D.speed-1)*5+D.digit;      % recalc. condition labels (to account for any trials recoded)
                end
                % set all trials not correct/recoded to error-coding
                % condition (cond # 21)
                for spd = 1:4
                    keep(D.speed==spd,1)   = logical(abs(deviations(D.speed==spd,1))<=tolerance(spd));
                end
                D.tt(~keep,1) = 21; 
            end
            
            if s==3; run={'01','02','03','04','06','07','08'}; end          % remove run 5 (TR timing drift) for subj 3
            % Do some subject structure fields
            J.dir 			 = {fullfile(glmDir{glm}, subj_name{s})};
            J.timing.units   = 'secs';                                      % timing unit that all timing in model will be
            J.timing.RT 	 = 1;                                           % TR (in seconds, as per 'J.timing.units')
            J.timing.fmri_t  = 16;
            J.timing.fmri_t0 = 1;
            % Loop through runs. 
            for r = 1:numel(run)                                             
                R = getrow(D,D.BN==r);
                for i = 1:(numTRs-numDummys)                                % get nifti filenames, correcting for dummy scancs
                    N{i} = [fullfile(baseDir, 'imaging_data',subj_name{s}, [char(prefix) subj_name{s},'_run_0',run{r},'.nii,',num2str(i)])];
                end;
                J.sess(r).scans = N;                                        % number of scans in run
                % Loop through conditions.
                Jindx = 1;
                for c = 1:(20 + rm_errors)
                    idx = find(R.tt==c);             % find indx of all trials in run of that condition
                    if sum(idx)>0
                        duration = dur;
                        onsets   = [R.realStartTime(idx)/1000-J.timing.RT*numDummys-announcetime];
                        if c<21
                            S.digit 		= R.digit(idx(1));
                            S.numPresses 	= R.numPresses(idx(1));
                            S.realPresses   = R.numPeaks(idx(1));
                            S.speed 		= R.speed(idx(1));
                            S.numTrials     = length(onsets);
                            S.regtype		= 'Task';
                            name            = sprintf('D%d_speed%d',S.digit,S.speed);
                        elseif c==21 
                            S.digit 		= 0;
                            S.numPresses 	= 0;
                            S.realPresses   = 0;
                            S.speed 		= 0;
                            S.numTrials     = length(onsets);
                            S.regtype		= 'Errs';
                            name            = 'error_trials';
                        end
                        J.sess(r).cond(Jindx).name 	   = name;
                        % Correct start time for numDummys removed & convert to seconds
                        J.sess(r).cond(Jindx).onset    = onsets;   
                        J.sess(r).cond(Jindx).duration = duration;                       % durations of task we are modeling (not length of entire trial)
                        J.sess(r).cond(Jindx).tmod     = 0;
                        J.sess(r).cond(Jindx).orth     = 0;
                        J.sess(r).cond(Jindx).pmod     = struct('name', {}, 'param', {}, 'poly', {});
                        Jindx = Jindx + 1;
                    else 
                        S.speed 		= ceil(c/5);
                        S.digit 		= c - S.speed + 1;
                        S.numPresses 	= 0;
                        S.realPresses   = 0;
                        S.numTrials     = 0;
                    end
                    % Do some subject info for fields in SPM_info.mat.
                    S.SN    		= s;
                    S.run   		= r;
                    S.tt			= c;
                    T				= addstruct(T,S);
                end;
                % Add any additional aux. regressors here.
                J.sess(r).multi 	= {''};
                J.sess(r).regress 	= struct('name', {}, 'val', {});
                J.sess(r).multi_reg = {''};                                 % add cardiac regressors here
                % Define high pass filter cutoff (in seconds): see glm cases.
                J.sess(r).hpf 		= hrf_cutoff;
            end;
            J.fact 			   = struct('name', {}, 'levels', {});
            J.bases.hrf.derivs = [0 0];
            J.bases.hrf.params = hrf_params;
            J.volt 			   = 1;
            J.global 		   = 'None';
            J.mask 	           = {fullfile(baseDir, 'imaging_data',subj_name{s}, 'rmask_noskull.nii,1')};
            J.mthresh 		   = 0.05;
            J.cvi_mask 		   = {fullfile(baseDir, 'imaging_data',subj_name{s},'rmask_gray.nii')};
            J.cvi 			   = cvi_type;
            % Save the GLM file for this subject.
            spm_rwls_run_fmri_spec(J);
            % Save the aux. information file (SPM_info.mat).
            % This file contains user-friendly information about the glm
            % model, regressor types, condition names, etc.
            save(fullfile(J.dir{1},'SPM_info.mat'),'-struct','T');

        end; %subj
    case 'GLM_estimate'                                                     % STEP 3.2   :  Run the GLM according to model defined by SPM.mat
        % Estimate the GLM from the appropriate SPM.mat file. 
        % Make GLM files with case 'GLM_make'.
        vararginoptions(varargin,{'sn','glm'});
        for s = sn
            % Load files
            load(fullfile(glmDir{glm},subj_name{s},'SPM.mat'));
            SPM.swd = fullfile(glmDir{glm},subj_name{s});
            % Run the GLM.
            spm_rwls_spm(SPM);
        end;
        % for checking -returns img of head movements and corrected sd vals
        % spm_rwls_resstats(SPM)
    case 'GLM_contrast'                                                     % STEP 3.3   :  Make t-stat contrasts for specified GLM estimates.
        % enter sn, glm #
        % 1,2,3,4:   Speeds vs. rest
        % 5,6,7,8,9: digit vs. rests
        % 10:        all digits vs. rest
        % 11:        increased activity w/ spd increase
        % 12 to 16:  thumb to little for 2 presses vs. rest
        % 17 to 21:  thumb to little for 4 presses vs. rest
        % 22 to 26:  thumb to little for 8 presses vs. rest
        % 27 to 31:  thumb to little for 16 presses vs.rest
        % 32 to 36:  avg. of all thumbs, avg. of index, etc. presses (avg.
        % across speeds)
        sn=10:17;
        glm=3;
        vararginoptions(varargin,{'sn','glm'});
        
        for s = sn
            for g = glm
                cd(fullfile(glmDir{g}, subj_name{s}));
                load SPM;
                SPM=rmfield(SPM,'xCon');
                T = load('SPM_info.mat');
                
                %_____t contrast fpr speeds
                for sp=1:4
                    con=zeros(1,size(SPM.xX.X,2));
                    con(:,T.speed==sp)=1;
                    con=con/sum(con);
                    SPM.xCon(sp)=spm_FcUtil('Set',sprintf('speed%d',sp), 'T', 'c',con',SPM.xX.xKXs);
                end;
                %_____t contrast for digits
                for d=1:5
                    con=zeros(1,size(SPM.xX.X,2));
                    con(:,T.digit==d)=1;
                    con=con/sum(con);
                    SPM.xCon(d+4)=spm_FcUtil('Set',sprintf('digit%d',d), 'T', 'c',con',SPM.xX.xKXs);
                end;
                
                %_____t contrast overall digits
                con=zeros(1,size(SPM.xX.X,2));
                con(:,T.digit>0)=1;
                con=con/sum(con);
                SPM.xCon(10)=spm_FcUtil('Set',sprintf('overall'), 'T', 'c',con',SPM.xX.xKXs);
                
                %_____t increase with speed
                con=zeros(1,size(SPM.xX.X,2));
                con(:,T.speed>0)=T.speed-mean(T.speed);
                SPM.xCon(11)=spm_FcUtil('Set',sprintf('speed_var'), 'T', 'c',con',SPM.xX.xKXs);
                
                %_____t all speed finger pairs (20 conds)
                ind=12;
                for sp=1:4
                    for d=1:5
                        con=zeros(1,size(SPM.xX.X,2));
                        con(:,T.speed==sp & T.digit==d)=1;
                        con=con/sum(con);
                        SPM.xCon(ind)=spm_FcUtil('Set',sprintf('D%d_spd%d',d,sp), 'T', 'c',con',SPM.xX.xKXs);
                        ind=ind+1;
                    end
                end
                
                %_____t avg. single finger contrast (avg. across speeds per finger)
                for d=1:5
                    con=zeros(1,size(SPM.xX.X,2));
                    con(:,T.digit==d)=1;
                    con=con/sum(con);
                    SPM.xCon(ind)=spm_FcUtil('Set',sprintf('D%d_spd%d',d,sp), 'T', 'c',con',SPM.xX.xKXs);
                    ind=ind+1;
                end
                
                
                %____do the constrasts
                SPM=spm_contrasts(SPM,[1:length(SPM.xCon)]);
                save('SPM.mat','SPM');
            end
        end;
        
        
        %__________________________________________________________________
	
    case '0' % ------------ SEARCH: searchlight analyses. Expand for more info.  REQUIRES FURTHER EDITING in group_cSPM (editing for comments on what is happening)!!!
        % The SEARCH cases are used to conduct surface-searchlight analyses 
        % using the rsa toolbox from JDiedrichsen and NEjaz (among others).
        %
        % All functions can be called with ('SEARCH_processAll','sn',[Subj#s]).
        %
        % You can view reconstructed surfaces with Caret software.
        %
        % The contrast metrics calculated from the full condition
        % searchlight are used to estimate boundaries for the rois.
        % The values used to estimate boundaries are the avg. paired
        % distances.
        %
        % See blurbs in each SEARCH case to understand what they do.
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -    
    case 'SEARCH_processAll'                                               
        glm = 3;
        vararginoptions(varargin,{'sn','glm'});
        % You can call this case to do all the searchlight analyses.
        % 'sn' can be an array of subjects because each processing case
        % contained within loops through the subject array submitted to the
        % case.
        for s = sn
            fivedigitFreq3_imana('SEARCH_define','sn',s,'glm',glm);
            fivedigitFreq3_imana('SEARCH_run_LDC','sn',s,'glm',glm);
            %fivedigitFreq3_imana('SEARCH_map_contrast','sn',s,'glm',glm);
            %fivedigitFreq3_imana('SEARCH_map_LDC','sn',s,'glm',glm);
            %fivedigitFreq3_imana('SEARCH_group_make');
            %fivedigitFreq3_imana('SEARCH_group_cSPM');
        end
    case 'SEARCH_define'                                                    % STEP 4.1   :  Defines searchlights for 120 voxels in grey matter surface
        glm = 3;
        vararginoptions(varargin,{'sn','glm'});
        
        for s=sn
            mask       = fullfile(glmDir{glm},subj_name{s},'mask.nii');
            Vmask      = spm_vol(mask);
            Vmask.data = spm_read_vols(Vmask);
            
            LcaretDir = fullfile(caretDir,sprintf('xs%02d',s),'LeftHem');
            RcaretDir = fullfile(caretDir,sprintf('xs%02d',s),'RightHem');
            white     = {fullfile(LcaretDir,'lh.WHITE.coord'),fullfile(RcaretDir,'rh.WHITE.coord')};
            pial      = {fullfile(LcaretDir,'lh.PIAL.coord'),fullfile(RcaretDir,'rh.PIAL.coord')};
            topo      = {fullfile(LcaretDir,'lh.CLOSED.topo'),fullfile(RcaretDir,'rh.CLOSED.topo')};
            S         = rsa_readSurf(white,pial,topo);
            
            L = rsa.defineSearchlight_surface(S,Vmask,'sphere',[15 120]);
            save(fullfile(anatomicalDir,subj_name{s},sprintf('s%d_searchlight_120.mat',s)),'-struct','L');
        end
    case 'SEARCH_run_LDC'                                                   % STEP 4.2   :  Runs LDC searchlight using defined searchlights (above)
        % Requires java functionality unless running on SArbuckle's
        % computer.
        glm = 3;
        vararginoptions(varargin,{'sn','glm'});
        
        block = 5e7;
        cwd   = pwd;                                                        % copy current directory (to return to later)
        for s=sn
            % if subj 2, alter for excluded run #7
            if s==3; runs = [1:7]; else runs = [1:8]; end
            % make index vectors
            conditionVec  = kron(ones(numel(runs),1),[1:20]');
            partition     = kron(runs',ones(20,1));
            % go to subject's glm directory 
            cd(fullfile(glmDir{glm},subj_name{s}));
            % load their searchlight definitions and SPM file
            L = load(fullfile(anatomicalDir,subj_name{s},sprintf('s%02d_searchlight_120.mat',s)));
            load SPM;
            SPM  = spmj_move_rawdata(SPM,fullfile(imagingDir,subj_name{s}));

            name = sprintf('s%02d_glm%d',s,glm);
            % run the searchlight
            rsa.runSearchlightLDC(L,'conditionVec',conditionVec,'partition',partition,'analysisName',name,'idealBlock',block,'java',0);

        end
        cd(cwd);
    case 'SEARCH_map_contrast'                                              % STEP 4.3   :  Averaged LDC values for specified contrasts
        % Calls 'MISC_SEARCH_calculate_contrast'
        sn  = [10:13];
        glm = 3;
        con = {'avg','speed','digit'};
        vararginoptions(varargin,{'sn','glm','con'});
        % Use 'con' option to define different contrasts.
        %   'avg'    :  Average LDC nii for all 20 conds
        %   'speed'  :  Calculate distances between pressing speed
        %                conditions, invariant of fingers pressed (avg of 6 pairwise distances)
        %   'digit'  :  Calculate distances between different finger presses,
        %                invariant of speed (avg of 10 pairwise distances)
        cWD = cd;
        for s = sn
            % Load subject surface searchlight results (1 vol per paired conds)
            LDC_file            = fullfile(glmDir{glm},subj_name{s},sprintf('s%02d_glm%d_LDC.nii',s,glm)); % searchlight nifti
            [subjDir,fname,ext] = fileparts(LDC_file);
            cd(subjDir);
            % For each of the predefined contrast types (see above)...
            for c = 1:length(con)
                switch con{c}
                    case 'avg' % just average across all paired distances 
                        vol     = spm_vol([fname ext]);
                        vdat    = spm_read_vols(vol); % is searchlight data
                        % average across all paired dists (avg. distance across conditions)
                        Y.LDC   = nanmean(vdat,4);
                        % prep output file
                        Y.dim   = vol(1).dim;
                        Y.dt    = vol(1).dt;
                        Y.mat   = vol(1).mat;    
                    case {'digit','speed'}
                        switch con{c}
                            case 'digit'
                                C = kron(ones([1,4]),rsa.util.pairMatrix(5));  % digit contrast  
                                C = C/4; % scale contrast vectors across speeds
                            case 'speed'
                                C = kron(rsa.util.pairMatrix(4),ones(1,5));    % speed contrast
                                C = C/5; % scale contrast vectors across digits
                        end
                        % get new distances from searchlight results
                        Y = fivedigitFreq3_imana('MISC_SEARCH_calculate_contrast','sn',s,'glm',glm,'C',C,'file',LDC_file);
                end

            % save output
            Y.fname   = sprintf('s%02d_glm%d_%sLDC.nii',s,glm,con{c});
            Y.descrip = sprintf('exp: ''fdf2'' \nglm: ''FAST'' \ncontrast: ''%s''',con{c});

            spm_write_vol(Y,Y.LDC);
            fprintf('Done s%02d_glm%d_%sLDC.nii \n',s,glm,con{c})

            clear vol vdat LDC Y
            end
        end
        cd(cWD);  % return to working directory
    case 'SEARCH_map_LDC'                                                   % STEP 4.4   :  Map searchlight results (.nii) onto surface (.metric)
        % map volume images to metric file and save them in individual surface folder
        sn  = [10:13];
        glm = 3;
        con = {'avg','speed','digit'}; % does all con imgs as default
        vararginoptions(varargin,{'sn','con','glm'});
        % 'con' option defines each contrast.
        %   'avg'    :  Average LDC nii for all 20 conds
        %   'speed'  :  Calculate distances between pressing speed
        %                conditions, invariant of fingers pressed (avg of 6 pairwise distances)
        %   'digit'  :  Calculate distances between different finger presses,
        %                invariant of speed (avg of 10 pairwise distances)
        hemisphere = 1:2;
        for s = sn
            for c = 1:length(con)
                ctype = con{c};
                for h=hemisphere
                    caretSDir = fullfile(caretDir,[atlasA,subj_name{s}],hemName{h});
                    white     = caret_load(fullfile(caretSDir,[hem{h} '.WHITE.coord']));
                    pial      = caret_load(fullfile(caretSDir,[hem{h} '.PIAL.coord']));
                    images    = fullfile(glmDir{glm},subj_name{s},sprintf('s%02d_glm%d_%sLDC.nii',s,glm,ctype));
                    outfile   = sprintf('s%02d_%sfunc_%d.metric',s,ctype,glm);
                    M         = caret_vol2surf_own(white.data,pial.data,images,'ignore_zeros',1);
                    caret_save(fullfile(caretSDir,outfile),M);
                    fprintf('Done subj %d con %s hemi %d \n',s,ctype,h)
                end
            end
        end
    case 'SEARCH_group_make'                                                % STEP 4.5   :  Make group metric files by condensing subjec contrast metric files
        % Calculate group metric files from the searchlight results. 
        % Takes the 3 contrast results ('avg','speed', & 'digit') across
        % subjects and makes a group level metric file that contains each
        % subject's data for that contrast type.
        sn = 10:13;
        vararginoptions(varargin,{'sn'});
        % Some presets
        INname     = {'avgfunc_3','speedfunc_3','digitfunc_3'};
        OUTname    = {'group_avg_3','group_speed_3','group_digit_3'};
        inputcol   = [1 1 1];
        replaceNaN = [0 0 0];     
        % Loop over hemispheres.
        for h = 1:2
            % Go to the directory where the group surface atlas resides
            surfaceGroupDir = [caretDir filesep atlasname filesep hemName{h}];
            cd(surfaceGroupDir);
            % Loop over each input metric file in 'INname' and make a group metric file
            for j = 1:length(INname); 
                % Loop over subjects...
                for i = 1:length(sn); 
                    s = sn(i);
                    % ...and define the names of their metric files
                    infilenames{j}{i} = [caretDir filesep atlasA subj_name{s} filesep hemName{h} filesep subj_name{s} '_' INname{j} '.metric'];
                end;
                % Name the output filename for this group metric file in average surface folder
                outfilenames{j} = [surfaceGroupDir filesep hem{h} '.' OUTname{j} '.metric'];
                % Finally, make the group metric file for this metric type/contrast
                caret_metricpermute(infilenames{j},'outfilenames',outfilenames(j),'inputcol',inputcol(j),'replaceNaNs',replaceNaN(j));
                % Verbose display to user
                fprintf('hem: %i  image: %i \n', h,j);
            end;
        end;
    case 'SEARCH_group_cSPM'                                                % STEP 4.6   :  Generate a statistical surface map (onesample_t test) from smoothed group metric files. Also avgs. distances across subjs.
        % Calculate group stats files from the group metric files. 
        % Takes the 3 group metric files ('avg','speed', & 'digit') and 
        % calculates group level stats (one sample t test that the mean 
        % effect is bigger than zero). 
        % 
        % Although we calculate the t-score, corresponding p-value for that
        % t-score, and finally the z-score 
        % subject's data for that contrast type.
        % ******* finish blurb here and comments + styling code below.
        
        sn = 10:13;
        SPMname={'group_avg_3','group_speed_3','group_digit_3'};
        
        sqrtTransform=[1,1,1]; % Should you take ssqrt before submitting? 
                                % Yes, b/c used rsa.distanceLDC to
                                % calculate distances. This function
                                % returns squared cv mahalanobis distance.
        SummaryName = '.summary.metric';
        hemi = [1 2];
        
        for h=hemi
            surfaceGroupDir=[caretDir filesep 'fsaverage_sym'  filesep hemName{h}];
            %----get the full directory name of the metric files and the NONsmoothed metric files that we create below
            for i=1:length(SPMname);
                %sfilenames{i}=[surfaceGroupDir filesep 's' hem{h} '.' SPMname{i} '.metric']; % smoothed
                sfilenames{i}=[surfaceGroupDir filesep hem{h} '.' SPMname{i} '.metric']; % no smoothing
            end;
            %----loop over the metric files and calculate the cSPM of each with the non-smoothed metrics
            for i=1:length(SPMname);
                Data=caret_load(sfilenames{i});
                if sqrtTransform(i)
                    Data.data=ssqrt(Data.data);
                end;
                cSPM=caret_getcSPM('onesample_t','data',Data.data(:,1:length(sn)),'maskthreshold',0.5); % set maskthreshold to 0.5 = calculate stats at location if 50% of subjects have data at this point
                caret_savecSPM([surfaceGroupDir filesep hem{h} '.' SPMname{i} '_stats.metric'],cSPM);
                save([surfaceGroupDir  filesep   'cSPM_' SPMname{i} '.mat'],'cSPM');
                data(:,i)=cSPM.con(1).con; % mean
                data(:,i+length(SPMname))=cSPM.con(1).Z; % T
                column_name{i}=['mean_' SPMname{i}];
                column_name{i+length(SPMname)}=['T_' SPMname{i}];
            end;
            C = caret_struct('metric','data',data,'column_name',column_name);
            caret_save([surfaceGroupDir  filesep hem{h} SummaryName],C);
        end;
        fprintf('Done \n')
        
    case '0' % ------------ ROI: roi analyses. Expand for more info. ------
        % The ROI cases are used to:
        %       - map ROIs to each subject
        %       - harvest timeseries from each roi for each condition
        %       - harvest activity patterns (i.e. beta weights for each voxel 
        %          in roi of that subject)
        %       - conduct statistical analyses on activity patterns and distances
        %       - assess pattern consistencies (for each subject for a glm)
        %       - assess reliability of distance estimates across subejcts
        %
        % There is no 'processAll' case here. However, the following cases
        % must be called to utilize other roi cases:
        %       'ROI_makePaint'   :  Creates roi paint files (see case)
        %       'ROI_define'      :  Maps rois to surface of each subject-
        %                             requires paint files from above case.
        %       'ROI_timeseries'  :  Only if you wish to plot timeseries
        %       'ROI_getBetas'    :  Harvest patterns from roi
        %       'ROI_stats'       :  Estimate distances, etc. 
        %                               This is the big kahuna as it is
        %                               often loaded by future cases.
        %
        % You can view roi maps by loading paint files and subject surfaces
        % in Caret (software).
        % 
        % Most functionality is achieved with rsa toolbox by JDiedrichsen
        % and NEjaz (among others).
        %
        % See blurbs in each SEARCH case to understand what they do.
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    case 'ROI_makePaint'                                                    % STEP make paint file for ROIs (saves as ROI_2.paint)
    % Modified from df1_imana. (in current state this is ugly..)
    % Creates ROI boundaries on the group template/atlas (fsaverage).
    % ROIs are defined using:
    %       - probabilistic atlas
    %       - boundaries for 4 major lobes
    %       - group surface searchlight results
    %       - flatmap coordinates for X Y coordinate restriction 
    
    for h=1:2 % loop over hemispheres
        % - - - - - - - - - - - - Load some files - - - - - - - - - - - - -
        groupDir=[caretDir filesep 'fsaverage_sym'  filesep hemName{h} ];
        cd(groupDir);
        C = caret_load([hem{h} '.FLAT.coord']);               % Caret flatmap (for X Y coordinate restrictions)
        M = caret_load([hem{h} '.propatlas.metric']);         % probabilistic atlas
        P = caret_load([hem{h} '.lobes.paint']);              % paint file of 4 major lobes (1 = col 2 of paintnames)
        % A  = caret_load('ROI.paint');                     % ROI.paint file from probabalistic atlas- file has nice, standard ROIs for motor, sensory, aux. rois, and some visual rois: Naveed maybe made this?
        % Load searchlight metrics
        Avg = caret_load([hem{h} '.group_avg_3_stats.metric']); % group surface searchlight results (FAST glm)- data(:,10) is group avg LDC
        
        % - - - - - - - - - - Assign roi labels to vertices - - - - - - - -
        % get data for new rois (from probability atlas)
        M1  = sum(M.data(:,[7,8]),2); % M1 is BA4a + 4p
        S1  = sum(M.data(:,[1:4]),2); % S1 is BA1 + 2 + 3a + 3b
        MT  = M.data(:,10);         
        SMA = M.data(:,9);           
        V1  = M.data(:,12);
        V2  = M.data(:,13);
        Ba1 = M.data(:,1);
        Ba2 = M.data(:,2);
        B3a = M.data(:,3);
        B3b = M.data(:,4);
        
        % coordinate is ROI w/ for which it has greatest associated probability
        [Prop,ROI]   = max([S1 M1 SMA MT V1 V1+V2],[],2); 
                    % ROI-> 1...2..3..4..5...6  
        [Prop3,ROI3] = max([Ba1 Ba2 B3a B3b],[],2);
                    % ROI->  7...8...9..10
                
        % Define ROIS with:
        %...cytoarchitectonic prob (>0.2) - - - - - - - - - - - - - - - - -
            ROI(Prop<0.15)=0;
            ROI3(Prop3<0.2)=0;
        %...boundaries of 4 major lobes (F.P.O.T.)- - - - - - - - - - - - -
            ROI(ROI==5) = 6;    
            ROI(ROI==1 & P.data~=2 & Prop<0.25)    = 0;  % sS1  :  parietal and higher prob
            ROI(ROI==2 & P.data~=1 & Prop<0.25)    = 0;  % sM1  :  frontal and higher prob
            ROI(ROI==3 & P.data~=1)                = 0;  % sSMA :  frontal
            ROI(ROI==4 & P.data~=2)                = 0;  % sMT  :  frontal
            
           % ROI(ROI==6 & P.data~=3)                = 0;  % sV1/2:  occipital
            %ROI(ROI==5 & P.data~=3)                = 0;  % sV1  :  occipital
            ROI3(ROI3==1 & P.data~=2)              = 0;  % Ba1  :  parietal
            ROI3(ROI3==2 & P.data~=2)              = 0;  % Ba2  :  parietal
            ROI3(ROI3==3 & P.data~=2)              = 0;  % B3a  :  parietal
            ROI3(ROI3==4 & P.data~=2)              = 0;  % B3b  :  parietal
            
            %ROI(ROI==5) = 6;
            %ROI(ROI==5) = 0;
        %...average distances of all condition pairs (for SMA, MT, V1, and V2)
        % (and the flatmap coords for left hemi rois)
        idx = size(Avg.data,2)-3;  % column for avg. distance across subjects
        switch h   % hemispheres
            case 1 % left hemi
                ROI(ROI==1 & Avg.data(:,idx)<0.15)    = 0;  % sS1- these dissimiarlity cutoffs lead to ROIs that focus on hand knob M1 S1
                ROI(ROI==2 & Avg.data(:,idx)<0.15)    = 0;  % sM1
                ROI(ROI==3 & Avg.data(:,idx)<0.1)     = 0;  % sSMA
                ROI(ROI==4 & Avg.data(:,idx)<0.1)     = 0;  % sMT
                %ROI(ROI==5 & Avg.data(:,idx)<0.05)    = 0;  % sV1
                %ROI(ROI==6 & Avg.data(:,idx)<0.05)    = 0;  % sV2
                
                %...flatmap X Y coordinates - - - - - - - - - - - - - - - -
                % SMAcoords
                    % Y coords
                    ROI(ROI==3 & C.data(:,2)>42)=0;
                    ROI(ROI==3 & C.data(:,2)<25)=0;
                    % X coords
                    ROI(ROI==3 & C.data(:,1)<-42)=0;
                    ROI(ROI==3 & C.data(:,1)>-21)=0;   
                % M1 (little blob near temporal lobe that still persists)
                    ROI(ROI==2 & C.data(:,2)<-1.5)=0;
            case 2 % right hemi
                ROI(ROI==1 & Avg.data(:,idx)<0.08)    = 0;  % sS1
                ROI(ROI==2 & Avg.data(:,idx)<0.07)    = 0;  % sM1
                %ROI(ROI==3 & Avg.data(:,10)<0.001)=0;     % sSMA- most voxels don't survive distance criteria in right hemi
                ROI(ROI==4 & Avg.data(:,idx)<0.05)    = 0;  % sMT
                %ROI(ROI==5 & Avg.data(:,idx)<0.05)    = 0;  % sV1
                %ROI(ROI==6 & Avg.data(:,idx)<0.05)    = 0;  % sV2
        end
        
        % - - - - - - - - - - - Save ROIpaint files - - - - - - - - - - - -  
        % Save Paint files for first six ROIs - - - - - - - - - - - - - - -
        areas{1}{1}  = {'sS1'}; 
        areas{2}{1}  = {'sM1'}; 
        areas{3}{1}  = {'sSMA'}; 
        areas{4}{1}  = {'sMT'};
        areas{5}{1}  = {'sV1'}; 
        areas{6}{1}  = {'sV1/V2'}; 
        names        = {'sS1','sM1','sSMA','sMT','sV1','sV1/V2'};
        
        colors=[255 0 0;...  % sS1
            0 255 0;...      % sM1
            0 0 255;...      % sSMA
            160 0 160;...    % sMT
            75 150 0;...     % sV1
            200 0 100];      % sV2
            
        Paint = caret_struct('paint','data',ROI,'paintnames',names,'column_name',{'ROI'});
        caret_save(['ROI_2.paint'],Paint);
        caret_combinePaint('ROI_2.paint','ROI_2.paint','ROI_2.areacolor',...
            'areas',areas,'names',names,'colors',colors);
        
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % Save paint file for Ba1:3b (cannot index same vertex for many
        % rois in same file..or at least not sure how to do so
        % currently)-SA
        clear areas colors names Paint
        areas{1}{1} = {'sBa1'}; 
        areas{2}{1} = {'sBa2'}; 
        areas{3}{1} = {'sB3a'}; 
        areas{4}{1} = {'sB3b'};
        
        names = {'sBa1','sBa2','sB3a','sB3b'};
        
        colors = [0 100 200;... % Ba1
            255 255 0;...       % Ba2
            150 50 255;...      % Ba3
            0 153 153];         % Ba3b
        
        Paint = caret_struct('paint','data',ROI3,'paintnames',names,'column_name',{'ROI'});
        caret_save(['ROI_3.paint'],Paint);
        caret_combinePaint('ROI_3.paint','ROI_3.paint','ROI_3.areacolor',...
            'areas',areas,'names',names,'colors',colors);
        
    end;    
    case 'ROI_define'                                                       % STEP 4.1: enter sn, glm #, defines ROIs that are refereneced in (2) at start of func
        % Define the ROIs of the group fsaverage atlas for each subject's
        % surface reconstruction. 
        % Output saved for each subject ('s#_regions.mat').
        % The save variable for each subject is a cell array of size
        % {1,#rois}. 
        % The cell for each roi contains the following fields:
        %       'type'   :   
        %
        %
        sn  = 10:17;
        glm = 3;
        vararginoptions(varargin,{'sn','glm'});

        linedef = [5,0,1]; % take 5 steps along node between white (0) and pial (1) surfaces

        for s=sn
            for h=1:2
                D  = caret_load(fullfile(caretDir,atlasname,hemName{h},['ROI.paint']));   % premade ROIs from fsaverage_sym (rois 11+)
                D2 = caret_load(fullfile(caretDir,atlasname,hemName{h},['ROI_2.paint'])); % sS1 sM1 sSMA sMT sV1 sV2 (rois 1:6)
                D3 = caret_load(fullfile(caretDir,atlasname,hemName{h},['ROI_3.paint'])); % sBa1 sBa2 sB3a sB3b (rois 7:10)
                
                caretSubjDir = fullfile(caretDir,[atlasA subj_name{s}]);
                file         = fullfile(glmDir{glm},subj_name{s},'mask.nii');
                
                for i=1:numregions
                    if i<7 % use D2- probabalistic + searchlight made rois
                        C = D2;
                        r = i;
                    elseif i<11 && i>6 % use D3- broadmann areas 1-3
                        C = D3;
                        r = i-6;
                    elseif i>10 % use D- probabalistic rois (premade)
                        C = D;
                        r = i-10;
                    end
                    idx = i+(h-1)*numregions;
                    R{idx}.type     = 'surf_nodes';
                    R{idx}.location = find(C.data(:,1)==r);
                    R{idx}.white    = fullfile(caretSubjDir,hemName{h},[hem{h} '.WHITE.coord']);
                    R{idx}.pial     = fullfile(caretSubjDir,hemName{h},[hem{h} '.PIAL.coord']);
                    R{idx}.topo     = fullfile(caretSubjDir,hemName{h},[hem{h} '.CLOSED.topo']);
                    R{idx}.linedef  = linedef;
                    R{idx}.image    = file;
                    R{idx}.name     = [subj_name{s} '_' regname{i} '_' hem{h}];
                    R{idx}.flat     = fullfile(caretDir,'fsaverage_sym',hemName{h},[hem{h} '.FLAT.coord']);
                end    
            end;
            R = region_calcregions(R,'exclude',[11,12;19,20],'exclude_thres',0.75);
            cd(regDir);
            save([subj_name{s} '_regions.mat'],'R');
            %varargout={R};
            fprintf('\n %s done\n',subj_name{s})
            clear R
        end;
    case 'ROI_timeseries'                                                   % STEP 4.2(optional): get TR timeseries for specified region (enter sn, region, glm #)
        % Use this and 'ROI_plot_timeseries' to ensure good GLM fits with
        % measured BOLD in rois.
        
        % Defaults
        sn   = [10:17];
        glm  = 3;
        roi  = 12;
        vararginoptions(varargin,{'sn','glm','roi'});

        pre  = 4;   % how many TRs before trial onset (2.8 secs)
        post = 20;  % how many TRs after trial onset (11.2 secs)
        
        % (2) Load SPM and region.mat files, extract timeseries, save file
        T = [];
        for s = sn
            cd(fullfile(glmDir{glm},subj_name{s}));                         % cd to subject's GLM dir
            load SPM;
            load(fullfile(regDir,[subj_name{s},'_regions.mat']));           % load subject's region_define info- variable loaded is R
                for reg = roi
                    R2  = R(reg);                                           % load R2 with region coordinates from
                    [y_raw, y_adj, y_hat, y_res,B] = region_getts(SPM,R2);  % get SPM info for voxels contained in specified region
                    D    = spmj_get_ons_struct(SPM);                        % get trial onsets in TRs- because model was in secs, spmj converts onsets to TR #s by dividing time/TR length (320 trials to 4872 TRs)
                    for r = 1:size(y_raw,2)
                        for i = 1:size(D.block,1);                          % extract the timeseries of each trial from y_adj, y_hat, & y_res
                            D.y_adj(i,:)=cut(y_adj(:,r),pre,round(D.ons(i))-1,post,'padding','nan')';
                            D.y_hat(i,:)=cut(y_hat(:,r),pre,round(D.ons(i))-1,post,'padding','nan')';
                            D.y_res(i,:)=cut(y_res(:,r),pre,round(D.ons(i))-1,post,'padding','nan')';
                            D.y_raw(i,:)=cut(y_raw(:,r),pre,round(D.ons(i))-1,post,'padding','nan')';
                        end
                        D.region = ones(size(D.event,1),1)*reg;
                        D.SN     = ones(size(D.event,1),1)*s;
                        T        = addstruct(T,D);
                    end
                end
        end;
        save(fullfile(regDir,sprintf('glm%dreg_timeseries',glm)),'-struct','T');
        
        %__________________________________________________________________
    case 'ROI_timeseries_plot'                                              % STEP 4.3(optional): plots timeseries for specified region by pressing speed (enter sn, region, glm #)
        glm = 3;
        sn  = 10;
        roi = 12;
        vararginoptions(varargin,{'sn','glm','roi'});
        
        figure('Name',sprintf('%s Timeseries from %s',reg_title{roi},sprintf('glm%d',glm)),'NumberTitle','off')
        D   = load(fullfile(regDir,sprintf('glm%dreg_timeseries',glm)));
        
        for s = sn
            T = getrow(D,D.SN==s);
            T = getrow(T,T.region==roi);
            T.pressFreq = ceil(T.event/5);
            T=getrow(T,T.pressFreq>1);
            %             traceplot([-4:20],T.y_raw,'errorfcn','stderr','split',ceil(T.event/5));
            %             legend({'2 presses','','4 presses','','8 presses','','16 presses',''});
            
            subplot(length(sn),1,find(sn==s))
            traceplot([-4:20],T.y_adj,'errorfcn','stderr','split',ceil(T.event/5));
            legend({'4 presses','','8 presses','','16 presses'});
            hold on;
            traceplot([-4:20],T.y_hat,'linestyle',':','split',ceil(T.event/5),'linewidth',2);
            hold off;
            xlabel('TR');
            ylabel('activation');
            xlim([-4 20]);
            title(sprintf('%s %s ROI Timeseries', subj_name{s}, reg_title{roi}));
            drawline(0);
            drawline(11.4);
        end
        
        
        %__________________________________________________________________
    case 'PSC_calc_con'
        % calculate psc for all digits vs. rest - based on betas    
        glm=3;
        sn= 10:17;
        vararginoptions(varargin,{'sn','glm'});
        con_num = [1:4];
        name={'2','4','8','16'};
        for s=sn
            cd(fullfile(glmDir{glm}, subj_name{s}));
            load SPM;
            T = load('SPM_info.mat');
            X = (SPM.xX.X(:,SPM.xX.iC));      % Design matrix - raw
            h = median(max(X));               % Height of response;
            P = {};
            numB = length(SPM.xX.iB);         % Partitions - runs
            for p = SPM.xX.iB
                P{end+1} = sprintf('beta_%4.4d.nii',p);       % get the intercepts (for each run) and use them to calculate the baseline (mean images)
            end;
            for con=1:length(name)    % 4 contrasts
                P{numB+1}=sprintf('con_%04d.nii',con);
                outname=sprintf('psc_press_%s.nii',name{con}); % ,subj_name{s}
                
                formula=sprintf('100.*%f.*i9./((i1+i2+i3+i4+i5+i6+i7+i8)/8)',h);    % 8 runs overall
                
                spm_imcalc_ui(P,outname,formula,{0,[],spm_type(16),[]});        % Calculate percent signal change
            end;
            fprintf('Subject %d: %3.3f\n',s,h);
        end;
    case 'PSC_calc_surface'
        % create surface maps of percent signal change 
     % trained and untrained sequences
     
        smooth=0;  
        glm=3;
        sn = 10:17;
        vararginoptions(varargin,{'sn','glm','smooth'});

        hemisphere=1:length(hem);
        fileList = [];
        column_name = [];
        name={'2','4','8','16'};
        for n = 1:length(name)
            fileList{n}=fullfile(['psc_press_' name{n} '.nii']);
            column_name{n} = fullfile(sprintf('%s.nii',name{n}));
        end
        for s=sn
            for h=hemisphere
                caretSDir = fullfile(caretDir,['x',subj_name{s}],hemName{h});
                white=fullfile(caretSDir,[hem{h} '.WHITE.coord']);
                pial=fullfile(caretSDir,[hem{h} '.PIAL.coord']);
                
                C1=caret_load(white);
                C2=caret_load(pial);
                
                for f=1:length(fileList)
                    images{f}=fullfile(glmDir{glm},subj_name{s},fileList{f});
                end;
                metric_out = fullfile(caretSDir,sprintf('%s_Press_PSC.metric',subj_name{s}));
                M=caret_vol2surf_own(C1.data,C2.data,images,'ignore_zeros',1);
                M.column_name = column_name;
                caret_save(metric_out,M);
                fprintf('Subj %d, Hem %d\n',s,h);
                
                if smooth == 1;
                    % Smooth output .metric file (optional)
                    % Load .topo file
                    closed = fullfile(caretSDir,[hem{h} '.CLOSED.topo']);
                    Out = caret_smooth(metric_out, 'coord', white, 'topo', closed);%,...
                    %'algorithm','FWHM','fwhm',12);
                    char(Out);  % if smoothed adds an 's'
                else
                end;
                
            end;
        end;
    case 'ROI_getBetas'
        glm        = 3;
        sn         = 10:17;
        %roi        = [1:36];
        roi = [11,12,16,34,6,24];
        %roi = [6,24];
        addon      = 0;     % if true, loads previous reg_betas .mat file and appends new subjects
        vararginoptions(varargin,{'sn','glm','roi','addon'});
        
        T = [];
        if addon
            T = load(fullfile(regDir,sprintf('glm%d_reg_betas.mat',glm)));
        end
              
        % % start harvest
        for s = sn % for each subj
            fprintf('\nSubject: %d\n',s) % output to user
            
            % load files
            load(fullfile(glmDir{glm}, subj_name{s}, 'SPM.mat'));  		   % load subject's SPM data structure (SPM struct)
            load(fullfile(regDir,sprintf('s%02d_regions.mat',s)));         % load subject's region parcellation & depth structure (R)
            
            % img info
            V = SPM.xY.VY; 
            
            % add percent signal change imgs
            Q = {};
            for q = 1:4
                Q{q} = (fullfile(glmDir{glm}, subj_name{s}, sprintf('psc_press_%d.nii',2^q)));
            end
            Q = spm_vol(char(Q));
            
            for r = roi % for each region
                % get raw data for voxels in region
                Y = region_getdata(V,R{r});  % Data Y is N x P (P is in order of transpose of R{r}.depth)
                % get psc for voxels in region
                PSC = region_getdata(Q,R{r});
                
                % estimate region betas
                %[betaW,resMS,SW_raw,beta] = rsa.spm.noiseNormalizeBeta(Y,SPM,'normmode','runwise');
                [betaW,resMS,SW_raw,beta] = rsa.spm.noiseNormalizeBeta(Y,SPM,'normmode','overall');
                %betaUW                    = bsxfun(@rdivide,beta,sqrt(resMS));  
                S.betaW  = {betaW};        % cells for voxel data b/c diff numVoxels across subjs
                %S.betaUW = {betaUW};
                S.beta   = {beta};
                S.resMS  = {resMS};
                
                % get percent signal change
                S.psc = {PSC}; % psc is 4 (speeds) x P 
               
                if ~isfield(R{r},'excl')
                    error('betas not excluded across rois');
                    S.depth= {R{r}.depth'};
                else
                    S.depth= {R{r}.depth(~R{r}.excl,:)'};
                end
                S.SN     = s;
                S.region = r;
                T        = addstruct(T,S);
                
                fprintf('%d.',r)
            end
        end
        % % save T
        save(fullfile(regDir,sprintf('glm%d_reg_betas.mat',glm)),'-struct','T'); 
        fprintf('\n')
    case 'ROI_stats'
        glm = 3;
        sn  = 10:17;
        roi = [11,12,16,34,6,24];
        vararginoptions(varargin,{'sn','glm','roi'});
        
        T = load(fullfile(regDir,sprintf('glm%d_reg_betas.mat',glm))); % loads region data (T)
        
        % output structures
        Ts = [];
        To = [];
        
        % do stats
        for s = sn % for each subject
            D = load(fullfile(glmDir{glm}, subj_name{s}, 'SPM_info.mat'));   % load subject's trial structure
            fprintf('\nSubject: %d\n',s)
            % get num runs
            num_run = length(unique(D.run));
            
            for r = roi % for each region
                S = getrow(T,(T.SN==s & T.region==r)); % subject's region data
                fprintf('%d.',r)
                
                for L = 1:length(layers) % for each layer defined in 'layers'
                    L_indx = (S.depth{1} > layers{L}(1)) & (S.depth{1} < layers{L}(2)); % index of voxels for layer depth
                    betaW  = S.betaW{1}(:,L_indx); 
                    beta   = S.beta{1}(:,L_indx);
                    psc    = S.psc{1}(:,L_indx);
                    % % Toverall structure stats
                    % crossval second moment matrix
                    [G,Sig]     = pcm_estGCrossval(betaW(1:(20*num_run),:),D.run,D.tt);
                    So.IPM      = rsa_vectorizeIPM(G);
                    So.Sig      = rsa_vectorizeIPM(Sig);
                    % squared distances
                    So.RDM_nocv = distance_euclidean(betaW',D.tt)';
                    So.RDM      = rsa.distanceLDC(betaW,D.run,D.tt);
                    % indexing fields
                    So.SN       = s;
                    So.region   = r;
                    So.layer    = L;
                    So.numVox   = sum(L_indx);
                    So.regSide  = regSide(r);
                    So.regType  = regType(r);
                    To          = addstruct(To,So);
                    
                    % % Tspeed structure stats
                    for spd=1:4 % for each pressing condition
                        % distances
                        Ss.RDM     = rsa.distanceLDC(betaW,D.run,D.digit.*double(D.speed==spd));
                        Ss.act     = mean(mean(beta(D.speed==spd,:)));
                        Ss.psc     = mean(psc(spd,:));
                        % indexing fields
                        Ss.SN      = s;
                        Ss.region  = r;
                        Ss.speed   = spd;
                        Ss.numVox  = sum(L_indx);
                        Ss.layer   = L;
                        Ss.regSide = regSide(r);
                        Ss.regType = regType(r);
                        Ts         = addstruct(Ts,Ss);
                    end
                end; % each layer
            end; % each region
        end; % each subject

        % % save
        save(fullfile(regDir,sprintf('glm%d_reg_Tspeed.mat',glm)),'-struct','Ts');
        save(fullfile(regDir,sprintf('glm%d_reg_Toverall.mat',glm)),'-struct','To');
        fprintf('\nDone.\n')
    case 'ROI_patternconsistency'                                           % STEP 5.2: enter sn, region, glm #, beta: 0=betaW, 1=betaU, 2=raw betas
        % pattern consistency for specified roi
        % (1) Set parameters
        glm = [1:3];
        sn  = [10:17];
        roi = 12; % lh M1
        layer = 'all';
        removeMean = 'no'; % are we removing pattern means for patternconsistency?
        vararginoptions(varargin,{'sn','glm','roi','removeMean','layer'});
        
        if strcmp(removeMean,'yes')
             keepmean = 1; % we are removing the mean
        else keepmean = 0; % we are keeping the mean
        end
        switch layer
            case 'all'
                L=1;
            case 'superficial'
                L=2;
            case 'deep'
                L=3;
        end
        Rreturn=[];
        %========%
        for g = glm
            T = load(fullfile(regDir,sprintf('glm%d_reg_betas.mat',g))); % loads in struct 'T'
            for r = roi
                Rall=[]; %prep output variable
                for s = sn
                    S      = getrow(T,(T.SN==s & T.region==r));
                    % get voxels for this layer
                    L_indx = (S.depth{1} > layers{L}(1)) & (S.depth{1} < layers{L}(2)); 
                    betaW  = S.betaW{1}(:,L_indx); 
                    % make vectors for pattern consistency func
                    if s==3; runs=[1:7]; else runs = [1:8]; end;
                    conditionVec = kron(ones(numel(runs),1),[1:20]');
                    partition    = kron(runs',ones(20,1));

                    R2   = rsa_patternConsistency(betaW,partition,conditionVec,'removeMean',keepmean);
                    Rall = [Rall,R2];
                end
                Rreturn = [Rreturn;Rall];
            end
        end
        varargout = {Rreturn};
        % output arranged such that each row is an roi, each col is subj
        
        %_______________
    case 'ROI_dist_stability'                                               % STEP 5.3: enter region, glm #
        glm = 3;
        roi = 11; % default primary motor cortex
        layer = 1;
        % correlate distances of conditions in roi across subjs
        vararginoptions(varargin,{'roi','glm','layer'});
        
        D   = load(fullfile(regDir,sprintf('glm%d_reg_Toverall.mat',glm)));      
        D   = getrow(D,D.region==roi & D.layer==layer);
        Cs  = corr(D.RDM');
        
        varargout = {Cs};
    case 'ROI_MDS_overall'                                                  % enter region, glm #
        cplot = 'one';
        glm   = 3;
        layer = 1;
        roi   = 12; % lh M1
        sn    = 10:17;
        fig   = [];
        lines = 1; % draw lines connecting 1:5 in MDS plot
        vararginoptions(varargin,{'roi','glm','cplot','layer','sn','fig','lines'});
        % cplot = 'all' to plot all 4 MDS figures (i.e. no contrast and 3 contrasts)- default
        % cplot = 'one'  to plot only no contrast MDS figure        

        T   = load(fullfile(regDir,sprintf('glm%d_reg_Toverall.mat',glm)));
        %T   = load(fullfile(regDir,sprintf('glm%d_reg_Toverall_noMeanSpeedPattern.mat',glm)));
        T   = getrow(T,T.layer==layer);
        if ~any(ismember(roi,[16,34,6,24]))
            IPM = T.IPM(T.region==roi & ismember(T.SN,sn),:); 
        elseif any(ismember(roi,[16,34])) % if visual cortices, avg. IPMs across hemis
            T = getrow(T,T.region==16 | T.region==34);
            T = tapply(T,{'SN'},{'IPM','mean'});
            IPM = T.IPM;
        elseif any(ismember(roi,[6,24])) % if visual cortices, avg. IPMs across hemis
            T = getrow(T,T.region==6 | T.region==24);
            T = tapply(T,{'SN'},{'IPM','mean'});
            IPM = T.IPM;
        end;
        
        if size(IPM,1)>1
            IPM = mean(IPM);
        end
        % % use to create rotation matrix for left hemi M1
%         r    = 2;
%         IPM2 = T.IPM(T.region==r,:);
%         %IPM2 = mean(T.IPM(T.region==r,:)); 
%         Y{2} = rsa_classicalMDS(IPM2,'mode','IPM');
%         [D,Z,Transform] = procrustes(Y{1},Y{2},'Scaling',false);
%         Y{2}=Y{2}*Transform.T;
        
        switch cplot
            case 'all' % do and plot 
                speed  = kron([1:4]',ones(5,1));
                digit  = kron(ones(4,1),[1:5]');
                Cspeed = indicatorMatrix('identity',speed);
                Cspeed = bsxfun(@minus,Cspeed,mean(Cspeed,2));
                Cdigit = indicatorMatrix('identity',digit);
                Cdigit = bsxfun(@minus,Cdigit,mean(Cdigit,2));
                Call   = eye(20)-ones(20)/20;

                Y{1} = rsa_classicalMDS(IPM,'mode','IPM');
                Y{2} = rsa_classicalMDS(IPM,'mode','IPM','contrast',Call);
                Y{3} = rsa_classicalMDS(IPM,'mode','IPM','contrast',Cspeed);
                Y{4} = rsa_classicalMDS(IPM,'mode','IPM','contrast',Cdigit);

                %clf;
                % h=axes('position',[0 0 1 1],'Visible','off');
                figure('Name',sprintf('ROI %s LAYER %s',reg_title{roi},layer),'NumberTitle','off')
                h1=axes('position',[0.1 0.6 0.35 0.35]);
                fivedigitFreq3_imana('scatterplotMDS',Y{1}(:,1:3),speed,digit,lines,roi);
                title('No contrast specified')
                h2=axes('position',[0.1 0.1 0.35 0.35]);
                fivedigitFreq3_imana('scatterplotMDS',Y{2}(:,1:3),speed,digit,lines,roi);
                title('Call')
                h3=axes('position',[0.6 0.6 0.35 0.35]);
                fivedigitFreq3_imana('scatterplotMDS',Y{3}(:,1:3),speed,digit,lines,roi);
                title('Cspeed')
                h4=axes('position',[0.6 0.1 0.35 0.35]);
                fivedigitFreq3_imana('scatterplotMDS',Y{4}(:,1:3),speed,digit,lines,roi);
                title('Cdigit')
            case 'one' % only do and plot no contrast MDS
                %Y{2}   = rsa_classicalMDS(IPM,'mode','IPM');
                Y{1}   = rsa_classicalMDS(IPM,'mode','IPM');
                speed  = kron([1:4]',ones(5,1));
                digit  = kron(ones(4,1),[1:5]');
                if isempty(fig)
                    figure('Name',sprintf('ROI %s  LAYER %s',reg_title{roi},layer),'NumberTitle','off','Color',[1 1 1]);
                else
                    fig;
                end
                fivedigitFreq3_imana('scatterplotMDS',Y{1}(:,1:3),speed,digit,lines,roi);
                title(reg_title{roi});
        end
%         keyboard
    case 'ROI_patternReliability'                                          % plot w/in subj, w/in speed rdm reliability (Across two partitions), compare with across-speed correlations. Insights into RSA stability    
        % Splits data for each session into two partitions (even and odd runs).
        % Calculates correlation coefficients between each condition pair 
        % between all partitions.
        % Default setup includes subtraction of each run's mean
        % activity pattern (across conditions).
        glm = 3;
        roi = 2; % default roi
        sn  = 6;
        mean_subtract = 1; % subtract run means
        beta_type = 'raw'; % use raw, not normalized betas
        % Correlate patterns across even-odd run splits within subjects.
        % Does correlation across all depths.
        vararginoptions(varargin,{'roi','glm','sn'});
        R    = []; % output struct
        runs = 1:numel(run);
        % Select function to harvest approrpaite betas
        switch beta_type
            case 'raw'
                betaFcn = 't.beta{1}(1:length(D.tt),:);';
            case 'uni'
                betaFcn = 'bsxfun(@rdivide,t.beta{1}(1:length(D.tt),:),ssqrt(t.resMS{1}));';
            case 'multi'
                betaFcn = 't.betaW{1}(1:length(D.tt),:);';
        end
        % Load subject's betas in all rois
        T = load(fullfile(regDir,sprintf('glm%d_reg_betas.mat',glm)));      
        % loop across and correlate
        for s = sn % for each subject
            D = load(fullfile(glmDir{glm}, subj_name{s}, 'SPM_info.mat')); % load subject's trial structure
            for r = roi % for each roi
                t     = getrow(T,T.SN==s & T.region==r); 
                betas = eval(betaFcn); % get specified patterns
                % remove run means?
                if mean_subtract
                    C0  = indicatorMatrix('identity',D.run);
                    betas = betas - C0*pinv(C0)* betas; % run mean subtraction  
                end
                % split patterns into even and odd runs, avg. within splits
                Bi    = [];
                parts = logical(rem(runs,2));
                for i = 1:2
                    idx        = logical(ismember(D.run,runs(parts)));
                    b.digit    = D.digit(idx);
                    b.numPress = D.numPresses(idx);
                    b.speed    = D.speed(idx);
                    b.tt       = D.tt(idx);
                    b.split    = ones(sum(idx),1).*i;
                    b.sn       = D.SN(idx);
                    b.betas    = betas(idx,:);
                    b  = tapply(b,{'sn','digit','speed','numPress','tt','split'},{'betas','mean'});
                    Bi = addstruct(Bi,b);
                    parts = ~parts; % since only even-odd splits, this works (maybe not elegant)
                end
                % correlation harvest matrices
                sameCond  = tril(bsxfun(@eq,Bi.tt,Bi.tt'),-1);
                diffSplit = tril(bsxfun(@(x,y) x~=y,Bi.split,Bi.split'),-1);
                % do correlations between partition patterns
                Rm = corr(Bi.betas');
                % harvest into output structure
                w.corr   = Rm(sameCond & diffSplit);
                w.within = ones(sum(sum(sameCond & diffSplit)),1);
                w.sn     = w.within.*s;
                w.roi    = w.within.*r;
                a.corr   = Rm(~sameCond & diffSplit);
                a.sn     = ones(sum(sum(~sameCond & diffSplit)),1).*s;
                a.roi    = ones(sum(sum(~sameCond & diffSplit)),1).*r;
                a.within = zeros(sum(sum(~sameCond & diffSplit)),1);
                r = [];
                r = addstruct(w,a);
                R = addstruct(R,r);
            end
        end;
        varargout = {R};  
    


    case '0' % ------------ NeuroImage Stability Paper- Figure and Stats cases
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -        
    case '0' % Project activity patterns onto surface for figs.
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    case 'fingerpics'                                                       % Makes jpegs of finger activity patterns on cortical surface M1/S1
        glm = 3;
        sn  = 10:13;
        vararginoptions(varargin,{'sn','glm'});
        
        for s = sn;
            for g = glm;
                fivedigitFreq3_imana('surf_map_finger','sn',s,'glm',g)
                %fivedigitFreq3_imana('surf_fingerpatterns','sn',s,'glm',g,'hemi',1)
                %fivedigitFreq3_imana('surf_fingerpatterns','sn',s,'glm',g,'hemi',2)
            end
        end  
    case 'surf_map_finger'                                                  % Map locations of finger patterns- run after glm estimation
        %df1_imana
        % map volume images to metric file and save them in individual surface folder
        sn  = 10;
        glm = 3;
        vararginoptions(varargin,{'sn','glm'});
        
        hemisphere = [1];   % both left (1) and right (2) hemis 
        
        % take contrast of each finger and press combo vs. rest
        j=1;
        for c = 32:36
            fileList{j} = sprintf('spmT_00%d.nii',c); % see case 'GLM_contrast' for contrast number index
            % contrast numbers 12:31
            j=j+1;
        end
        for s = sn
            for h = hemisphere
                caretSDir = fullfile(caretDir,[atlasA,subj_name{s}],hemName{h});
                specname  = fullfile(caretSDir,[atlasA,subj_name{s} '.' hem{h} '.spec']);
                white     = fullfile(caretSDir,[hem{h} '.WHITE.coord']);
                pial      = fullfile(caretSDir,[hem{h} '.PIAL.coord']);
                topo      = fullfile(caretSDir,[hem{h} '.CLOSED.topo']);
                
                C1 = caret_load(white);
                C2 = caret_load(pial);
                
                for f = 1:length(fileList)
                    images{f} = fullfile(glmDir{glm},subj_name{s},fileList{f});
                end;
                
                M = caret_vol2surf_own(C1.data,C2.data,images,'topo',topo,'exclude_thres',0.75,'ignore_zeros',1,'column_names',{'D1','D2','D3','D4','D5'});
                caret_save(fullfile(caretSDir,sprintf('s%02d_glm%d_hemi%d_singleFinger.metric',s,glm,h)),M);
            end;
        end;
    case 'surf_fingerpatternsM1S1'                                          % Make finger pattern jpegs
        sn = 10;
        glm = 3;
        vararginoptions(varargin,{'sn','glm'});
        
        h=1; % left hemi
        groupDir=[gpCaretDir filesep hemName{h} ];
        cd(groupDir);
        border=fullfile(caretDir,'fsaverage_sym',hemName{h},['CS.border']);
        switch(h)
            case 1
                coord='lh.FLAT.coord';
                topo='lh.CUT.topo';
                data='lh.surface_shape';
                xlims=[-14 5]; % may need to adjust locations for pics
                %ylims=[-1 18];
                ylims=[-2 17];
            case 2
                coord='rh.FLAT.coord';
                topo='rh.CUT.topo';
                data='rh.surface_shape';
                xlims=[-10 20];
                ylims=[-15 30];   
        end;
        
        
        B = caret_load(border);
        data   = fullfile(caretDir,['x' subj_name{sn}],hemName{h},sprintf('s%02d_glm%d_hemi%d_finger.metric',sn,glm,h));
        sshape = fullfile(caretDir,'fsaverage_sym',hemName{h},[hem{h} '.surface_shape']);
        %         subplot(2,3,1);
        
        % plot image of the portion of cortical surface we are projecting
        % finger patterns onto
        figure('Color',[1 1 1]); % make figure
        M=caret_plotflatmap('col',2,'data',sshape,'border',B.Border,'topo',topo,'coord',coord,'xlims',xlims,'ylims',ylims,'bordersize',10);
        colormap('gray');
        set(gca,'XTick',[]); % remove X and Y axis ticks
            set(gca,'YTick',[]);
            %axis equal;
            box on
            ax = get(gca);
            ax.XAxis.LineWidth = 4;
            ax.YAxis.LineWidth = 4;
        
        % plot finger patterns
        figure('Color',[1 1 1]); % make figure 
        % plot each pattern
        for i=1:20
            subplot(4,5,i);
            [M,d]=caret_plotflatmap('M',M,'col',i,'data',data,'cscale',[-6 12],...
                'border',B.Border,'topo',topo,'coord',coord,'bordersize',10);
            maxT(i)=max(d(:));
            minT(i)=min(d(:));
        end;
        % scale each pattern
        mm = 12;%max(maxT);
        for i=1:20
            subplot(4,5,i);
            caxis([-mm/2 mm]);   % scale color across plots
            set(gca,'XTick',[]); % remove X and Y axis ticks
            set(gca,'YTick',[]);
            %axis equal;
            box on
            ax = get(gca);
            ax.XAxis.LineWidth = 4;
            ax.YAxis.LineWidth = 4;
            colormap jet
        end;
        set(gcf,'PaperPosition',[1 1 10 7]);
        set(gcf,'InvertHardcopy','off'); % allows save function to save pic w/ current background colour (not default to white)
        wysiwyg;
        
        %keyboard
        %saveas(gcf, [subj_name{sn},'_',hemName{h},'_',sprintf('%d',mm)], 'jpg')
    case 'surf_fingerpatternsV1V2'                                          % Make finger pattern jpegs
        sn = 10;
        glm = 3;
        vararginoptions(varargin,{'sn','glm'});
        
        h=1; % left hemi
        groupDir=[gpCaretDir filesep hemName{h} ];
        cd(groupDir);
        border=fullfile(caretDir,'fsaverage_sym',hemName{h},['V1V2.border']);
        switch(h)
            case 1
                coord='lh.FLAT.coord';
                topo='lh.CUT.topo';
                xlims=[70 115]; % may need to adjust locations for pics
                %ylims=[-1 18];
                ylims=[-10 50];
            case 2
                error('rh V1V2 not defined');
                coord='rh.FLAT.coord';
                topo='rh.CUT.topo';
                xlims=[-10 20];
                ylims=[-15 30];   
        end;
        
        
        B      = caret_load(border);
        data   = fullfile(caretDir,['x' subj_name{sn}],hemName{h},sprintf('s%02d_glm%d_hemi%d_finger.metric',sn,glm,h));
        sshape = fullfile(caretDir,'fsaverage_sym',hemName{h},[hem{h} '.surface_shape']);
        %         subplot(2,3,1);
        
        % plot image of the portion of cortical surface we are projecting
        % finger patterns onto
        figure('Color',[1 1 1]); % make figure
        M=caret_plotflatmap('col',2,'data',sshape,'border',B.Border,'bordercolor',{'k.','k.','w.','w.'},'topo',topo,'coord',coord,'xlims',xlims,'ylims',ylims,'bordersize',10);
        colormap('gray');
        set(gca,'XTick',[]); % remove X and Y axis ticks
            set(gca,'YTick',[]);
            %axis equal;
            box on
            ax = get(gca);
            ax.XAxis.LineWidth = 4;
            ax.YAxis.LineWidth = 4;
        
        % plot finger patterns
        figure('Color',[1 1 1]); % make figure 
        % plot each pattern
        for i=1:20
            subplot(4,5,i);
            [M,d]=caret_plotflatmap('M',M,'col',i,'data',data,'cscale',[-6 12],...
                'border',B.Border,'bordercolor',{'k.','k.','w.','w.'},'topo',topo,'coord',coord,'bordersize',10);
            maxT(i)=max(d(:));
            minT(i)=min(d(:));
        end;
        % scale each pattern
        mm = 10;%max(maxT);
        for i=1:20
            subplot(4,5,i);
            caxis([-mm/2 mm]);   % scale color across plots
            set(gca,'XTick',[]); % remove X and Y axis ticks
            set(gca,'YTick',[]);
            %axis equal;
            box on
            ax = get(gca);
            ax.XAxis.LineWidth = 4;
            ax.YAxis.LineWidth = 4;
            colormap jet
        end;
        set(gcf,'PaperPosition',[1 1 10 7]);
        set(gcf,'InvertHardcopy','off'); % allows save function to save pic w/ current background colour (not default to white)
        wysiwyg;
        
        %keyboard
        %saveas(gcf, [subj_name{sn},'_',hemName{h},'_',sprintf('%d',mm)], 'jpg')
    
    case 'surf_fingermapCollection'                                                  % Map locations of finger patterns- run after glm estimation
        % map volume images to metric file and save them in individual
        % surface folder for fingermapCollection
        sn  = 10:17;
        glm = 3;
        vararginoptions(varargin,{'sn','glm'});
        
        hemisphere = [1];   % left (1) hemi 
        
        % take contrast of each finger and press combo vs. rest
        j=1;
        for c = 32:36 % finger contrast, avg.  across pressing speeds
            fileList{j} = sprintf('spmT_00%d.nii',c); % see case 'GLM_contrast' for contrast number index
            j=j+1;
        end
        for s = sn
            for h = hemisphere
                % first map caret files:
                caretSDir = fullfile(caretDir,[atlasA,subj_name{s}],hemName{h});
                white     = fullfile(caretSDir,[hem{h} '.WHITE.coord']);
                pial      = fullfile(caretSDir,[hem{h} '.PIAL.coord']);
                topo      = fullfile(caretSDir,[hem{h} '.CLOSED.topo']);
                
                C1 = caret_load(white);
                C2 = caret_load(pial);
                
                for f = 1:length(fileList)
                    images{f} = fullfile(glmDir{glm},subj_name{s},fileList{f});
                end;
                
                [M,vox2Node] = surf_vol2surf(C1.data,C2.data,images,'topo',topo,'exclude_thres',0.75,'ignore_zeros',1,'column_names',{'D1','D2','D3','D4','D5'});
                caret_save(fullfile(caretSDir,sprintf('s%02d_glm%d_hemi%d_singleFinger.metric',s,glm,h)),M);
                save(fullfile(caretSDir,sprintf('s%02d_glm%d_hemi%d_finger_vox2Node.mat',s,glm,h)),'vox2Node');
                
                % now do same maps in workbench format (gifti):
            end;
        end;
    case 'surf_fingermapCollectionOLD'                                          % Make finger pattern jpegs
        sn = 10;
        glm = 3;
        vararginoptions(varargin,{'sn','glm'});
        
        h=1; % contrlateral (left) hemi
        groupDir=[gpCaretDir filesep hemName{h} ];
        cd(groupDir);
        switch(h)
            case 1
                coord='lh.FLAT.coord';
                topo='lh.CUT.topo';
                data='lh.surface_shape';
                xlims=[-32 35];
                ylims=[-20 25];
        end

        M=fullfile(caretDir,['x' subj_name{sn}],hemName{h},sprintf('s%02d_glm%d_hemi%d_finger.metric',sn,glm,h));
        % data finger pattern data
        d=[];
        for i=1:5
            [~,d(:,i)]=caret_plotflatmap('col',i,'data',M,'topo',topo,'coord',coord,'xlims',xlims,'ylims',ylims); 
        end
        
        % make into functional surface gifti
        anatStruct = {'CortexLeft','CortexRight'};
        hemiLetter = {'L','R'};
        G=surf_makeFuncGifti(d,'anatomicalStruct',anatStruct{h},'columnNames',{'D1','D2','D3','D4','D5'}); 
        save(G,sprintf('/Users/sarbuckle/Desktop/Fingermaps/fdf3.%s.%s.func.gii',subj_name{sn},hemiLetter{h}));
        fprintf('fdf3.%s.%s...done.\n',subj_name{sn},hemiLetter{h});
        
    case '0' % Make first-pass versions of paper figures.
    case 'depreciated_Fig2'   
       % create two panel figure of pattern scaling for paper. Exact
       % placement of patterns in voxel-space was done in illustrator
       % (here, just got raw panels ready).
       
       % 2 voxels with patterns for 3 conditions
%        vL = [1,1 ; 2,1; 1,2]; % raw patterns
%        vL = [vL(:,1),vL(:,2)-0.3];
%        vH = vL*2;           % scaled patterns
%        vHsat = [vL(1,:)+1;vL(2:3,:)+1.9];
%        vHsat(vHsat>3) = 3.1;     % saturate patterns

       vL = [1,1 ; 3,1; 1,3]; % raw patterns
       vH = vL*2.1;           % scaled patterns
       vHsat = vL+1.1;
       vHsat(vH>3) = 3.1;     % saturated patterns

       figure('Color',[1 1 1]);
       % panel A: Activity patterns as heatmaps
       clims = [min(min(vL))-0.5 max(max(vH))];
       subplot(1,5,1);
       patchimg(vL,'linewidth',1.5,'colorlimits',clims,'map','jet');
       subplot(1,5,2);
       patchimg(vHsat,'linewidth',1.5,'colorlimits',clims,'map','jet');
       subplot(1,5,3);
       patchimg(vH,'linewidth',1.5,'colorlimits',clims,'map','jet');
       subplot(1,5,4);
       imagesc([],clims);
       colormap jet; colorbar
       % panel B: Activities in pattern space
       subplot(1,5,5);
       hold on
       scatter(vL(:,1),vL(:,2));
       scatter(vH(:,1),vH(:,2));
       scatter(vHsat(:,1),vHsat(:,2));
       plot(0,0,'Marker','+');
       hold off
       axis equal
       xlim([-0.2 7])
       ylim([-0.2 7])
       set(gca,'XTick',[]);
       set(gca,'YTick',[]);
    case 'Fig2'   
       % fingerpatterns and ROI_stats figure. 
       figure('Color',[1 1 1]); 
       % Panel A: use case ('surf_fingerpatternsM1S1','sn',14,'glm',3) for patterns from paper.
       
       % Panel B: avg. adjusted activity of raw patterns in M1, S1, and V12
       % (avg. across hemispheres, NOT combined patterns together).
       
       
       
       % plot group avg. data
       fivedigitFreq3_imana('FIG_ROIactivity','sn',10:17,'roi',[11,12,24],'fig',gcf,'sty','3black');
       hold on
       % next, plot individual data
       for s = 10:17
           %D = fivedigitFreq3_imana('HARVEST_ROIactivity','sn',s,'roi',[11,12,24],'glm',3,'layer',1);
           hold on
           fivedigitFreq3_imana('FIG_ROIactivity','sn',s,'roi',[11,12,24],'fig',gcf,'sty','3subjs');
       end
       hold off
    case 'Fig3'   
       % MDS of M1 and (bilateral) V12 rep structures.
       figure('Color',[1 1 1]);
       % row 1 (panel A): contralateral M1 rep structures from different angles
       subplot(2,3,1); fivedigitFreq3_imana('ROI_MDS_overall','sn',10:17,'roi',12,'fig',gcf,'lines',1);
       xlim([-0.001 0.27]); title('');
       set(gca,'CameraPosition',[-1.6532,-0.2110,-0.1583]);
       subplot(2,3,2); fivedigitFreq3_imana('ROI_MDS_overall','sn',10:17,'roi',12,'fig',gcf,'lines',1);
       xlim([-0.001 0.27]); title('M1');
       set(gca,'CameraPosition',[-1.1591,1.2819,1.1854]);
       subplot(2,3,3); fivedigitFreq3_imana('ROI_MDS_overall','sn',10:17,'roi',12,'fig',gcf,'lines',1);
       xlim([-0.001 0.27]); title('');
       set(gca,'CameraPosition',[-1.2593,-1.2668,0.2982]);
       % row 2 (panel B): bilateral V12 rep structures
       subplot(2,3,4); fivedigitFreq3_imana('ROI_MDS_overall','sn',10:17,'roi',6,'fig',gcf,'lines',1);
       xlim([-0.001 0.27]); title('');
       set(gca,'CameraPosition',[-1.5793,-0.2113,0.2096]);
       subplot(2,3,5); fivedigitFreq3_imana('ROI_MDS_overall','sn',10:17,'roi',6,'fig',gcf,'lines',1);
       xlim([-0.001 0.27]); title('V12');
       set(gca,'CameraPosition',[-1.3764,0.7711,0.4536]);
       subplot(2,3,6); fivedigitFreq3_imana('ROI_MDS_overall','sn',10:17,'roi',6,'fig',gcf,'lines',1);
       xlim([-0.001 0.27]); title('');
       set(gca,'CameraPosition',[-0.1524,-1.7929,0.4305]);
    case 'Fig4'
       % Plot RDM lines in first col, split-half corrs in 2nd col,
       % cross-speed RDM corrs in 3rd col, diff b/t corrs in 4th col
       % Each row is an ROI: 1st = M1, 2nd = S1, 3rd = V12 (bilateral)
       clrdots = 'modelFits';%'modelFits'; % clr dots per 'subj', log-linear 'modelFits', or 'none'
       figure('Color',[1 1 1]);
       % Column 1 plots
       subplot(3,5,[1:2]);   fivedigitFreq3_imana('FIG_DistShape','sn',10:17,'glm',3,'roi',12,'subplt',gca); ylim([-0.002 0.06]); % panel A- M1
       hold on; drawline(0,'dir','horz','linewidth',1); hold off;
       title('contra M1  .');
       subplot(3,5,[6:7]);   fivedigitFreq3_imana('FIG_DistShape','sn',10:17,'glm',3,'roi',11,'subplt',gca); ylim([-0.002 0.06]); % panel E- S1
       hold on; drawline(0,'dir','horz','linewidth',1); hold off;
       title('contra S1  .');
       subplot(3,5,[11:12]); fivedigitFreq3_imana('FIG_DistShape','sn',10:17,'glm',3,'roi',6,'subplt',gca); ylim([-0.002 0.06]); % panel I- V12
       hold on; drawline(0,'dir','horz','linewidth',1); hold off;
       title('bilateral V1/V2  .');
       set(gca,'XTickLabel',{'E:I','E:M','E:F','E:J','I:M','I:F','I:J','M:F','M:J','F:J'});
       xlabel('Letter pair');
       % Column 2:4 plots
       h = {subplot(3,5,3),subplot(3,5,4),subplot(3,5,5)}; 
       fivedigitFreq3_imana('FIG_rdmStability','sn',10:17,'glm',3,'roi',12,'subplt',h,'clrdots',clrdots); % panels B,C,D- M1 
       h = {subplot(3,5,8),subplot(3,5,9),subplot(3,5,10)}; 
       fivedigitFreq3_imana('FIG_rdmStability','sn',10:17,'glm',3,'roi',11,'subplt',h,'clrdots',clrdots); % panels B,C,D- S1
       h = {subplot(3,5,13),subplot(3,5,14),subplot(3,5,15)}; 
       fivedigitFreq3_imana('FIG_rdmStability','sn',10:17,'glm',3,'roi',24,'subplt',h,'clrdots',clrdots); % panels B,C,D- V12
       subplot(3,5,13); hold on; drawline(0,'dir','horz','linewidth',1); hold off;
       subplot(3,5,14); hold on; drawline(0,'dir','horz','linewidth',1); hold off;
       h = {subplot(3,5,3),subplot(3,5,4),subplot(3,5,8),subplot(3,5,9)};
       %for i=1:4; set(h{i},'YLim',[0.75 1]); end  
       for i=1:4; set(h{i},'YLim',[0.5 1]); end  
       %set(subplot(3,5,5),'YLim',[-0.15 0.16]);
       %set(subplot(3,5,10),'YLim',[-0.15 0.16]);
       %set(gca,'Position',[0.7813,0.1100,0.1237,0.2157]);
    case '0' % Cases called by figures above or stats for results.
    case 'HARVEST_behaviour'
        % harvest pressing force data for each trial
        sn       = 10:17;
        T = [];
        for s = sn;
            load(fullfile(behavDir,sprintf('fdf3_forces_s%02d.mat',s)));
            %D = fivedigitFreq3_imana('BEHA_getBehaviour','sn',s);
            for sp=1:4 % for each speed
                dd = getrow(D,D.numPresses==2^sp);
                for dgt=1:5 % for each digit
                    d             = getrow(dd,dd.digit==dgt);
                    t.SN          = s;
                    t.digit       = dgt;
                    t.speed       = sp;
                    t.goodPresses = mean(d.numPeaks); % uses numPeaks so that you can lower force threshold required to count as correct press
                    t.stdPresses  = std(d.numPeaks);
                    t.avgF        = nanmean(d.avrgPeakHeight(d.digit==dgt));%d.forces(repmat([1:5],size(d.digit,1),1)~=repmat(d.digit,1,5))); % avg force of noncued fingers
                    t.std         = nanstd(d.avrgPeakHeight(d.digit==dgt));%d.forces(repmat([1:5],size(d.digit,1),1)~=repmat(d.digit,1,5)));
                    t.timebtpress = nanmean(d.avgTimeBTPeaks);
                    T             = addstruct(T,t);
                end
            end
        end
        varargout = {T};
    case 'HARVEST_ROIactivity'   
        roi   = [11,12,16,34];
        sn    = 10:17;
        glm   = 3;
        layer = 1;
        vararginoptions(varargin,{'roi','glm','sn','layer'});

        % load appropriate file and get rows for subjs and roi
        D = load(fullfile(regDir,sprintf('glm%d_reg_Tspeed.mat',glm)));
        % avg. visual cortices across hemispheres
        if sum(ismember(roi,[16,34]))>0
            T = getrow(D,(D.region==16 | D.region==34) & ismember(D.SN,sn) & D.layer==layer);
            T = tapply(T,{'speed','SN'},{'act','mean'},{'psc','mean'},{'RDM','mean'});
            T.region = ones(size(T.act)).*16;
            
            D = getrow(D,D.layer==layer & ismember(D.region,roi) & ismember(D.SN,sn));
            D = getrow(D,~ismember(D.region,[16,34,6,24]));
            D = addstruct(D,T);
        elseif sum(ismember(roi,[6,24]))>0
            T = getrow(D,(D.region==6 | D.region==24) & ismember(D.SN,sn) & D.layer==layer);
            T = tapply(T,{'speed','SN'},{'act','mean'},{'psc','mean'},{'RDM','mean'});
            T.region = ones(size(T.act)).*24;
            
            D = getrow(D,D.layer==layer & ismember(D.region,roi) & ismember(D.SN,sn));
            D = getrow(D,~ismember(D.region,[16,34,6,24]));
            D = addstruct(D,T);
        else
            D = getrow(D,D.layer==layer & ismember(D.region,roi) & ismember(D.SN,sn));
        end
        % remove fields from datastructure we don't need..
        D = rmfield(D,{'numVox','layer','regSide','regType'});
%         D.RDM = mean(D.RDM,2); % avg. pairwise distances per freq
        D.numPress = 2.^D.speed;
        varargout = {D};
    case 'FIG_ROIactivity'                                                  % plot avg (adjusted) activity   
        % plots average activities for M1, S1, and (bilateral) V12.
        % Avg. activity is average betas within speed in that roi
        % Shaded regions are stderr across subjects.
        roi   = [11,12,24];
        sn    = 10:17;
        glm   = 3;
        layer = 1;
        fig   = [];
        sty   = '3black';
        vararginoptions(varargin,{'roi','glm','sn','layer','fig','sty'});

        % get avg. activity datatstructure
        D = fivedigitFreq3_imana('HARVEST_ROIactivity','sn',sn,'roi',roi,'glm',glm,'layer',layer);

        % bring plotting space to front
        if isempty(fig); figure('Color',[1 1 1]); else; fig; end
        
        % plot 
        style.use(sty);
        plt.line(D.numPress,D.act,'split',D.region);
        %plt.line(log(D.numPress),D.act,'split',D.region);
        plt.legend('northwest',{'S1','M1','V1/V2'});
        xlabel('Number of presses');
        ylabel('Average adjusted activity');
        hold on; drawline(0,'dir','horz','linewidth',1); hold off
    case 'STATS_ROIactivity'
        % Computes linear and log-linear fits to avg. roi activities.
        % Do so for M1, S1, and V12.
        roi   = [11,12,16,34];
        sn    = 10:17;
        glm   = 3;
        layer = 1;
        verbose = 0;
        vararginoptions(varargin,{'glm','sn','roi','verbose','layer'});

        % get avg. activity datatstructure
        D = fivedigitFreq3_imana('HARVEST_ROIactivity','sn',sn,'roi',roi,'glm',glm,'layer',layer);
        %D.act = D.psc; % uncomment if you wish to test for percent signal
        %change
        % fit presses to activity
        T = [];
        for i = 1:length(unique(D.region))
            r = roi(i);
           for s = sn
                d = getrow(D,D.SN==s & D.region==r);
                %d = getrow(D,D.region==r);
                t.y_bar_mean = repmat(mean(d.act),size(d.act,1),1)';
                t.act = d.act';
                % fit intercept (mean) to scale lower-bound of fits
                [t.int_beta,stats] = linregress(t.act',t.y_bar_mean','intercept',0); % no int b/c d.act is an intercept
                t.tss = stats.totSS;
                t.int_rss = stats.resSS;
                t.int_r2  = 1-(t.int_rss/t.tss);
                
                % use rss as total ss from fitting mean b/c this is left-over variance that can be explained not from mean activity alone
                
                % fit linear
                [t.lin_beta,stats] = linregress(t.act',d.numPress,'intercept',0);
                t.lin_rss = stats.resSS;
                t.lin_r2  = 1-(t.lin_rss/t.int_rss);  
                % fit log
                [t.log_beta,stats] = linregress(t.act',log(d.numPress),'intercept',0);
                t.log_rss = stats.resSS;
                t.log_r2 = 1-(t.log_rss/t.int_rss);
                % index fields
                t.sn  = s;
                t.roi = r;
                T = addstruct(T,t);
           end
            if verbose
                fprintf('roi: %s \n',reg_title{r})
                % one-sided ttest because we expect log_r2 to fit better in
                % M1/S1. change to 2-tailed for V1/V2
                ttest(T.log_r2(T.roi==r),T.lin_r2(T.roi==r),1,'paired')
                %signtest(T.log_r2(T.roi==r)-T.lin_r2(T.roi==r))
            end
        end
        varargout = {T};
    case 'ROI_stats_splithalf'
        glm = 3;
        sn  = 10:17;
        roi = [11,12,16,34,6,24];
        partitions = [1:2:7; 2:2:8];
        vararginoptions(varargin,{'sn','glm','roi'});
        
        T = load(fullfile(regDir,sprintf('glm%d_reg_betas.mat',glm))); % loads region data (T)

        Ts = [];
        % do stats
        for s = sn % for each subject
            fprintf('\nSubject: %02d  roi:  ',s)
            D = load(fullfile(glmDir{glm}, subj_name{s}, 'SPM_info.mat'));   % load subject's trial structure
            
            % for each partition
            for p = 1:size(partitions,1); 
                partitionIdx = ismember(D.run,partitions(p,:));
                % for each region
                for r = roi 
                    fprintf('%02d  ',r)
                    S           = getrow(T,(T.SN==s & T.region==r)); % subject's region data
                    betaW       = S.betaW{1}(partitionIdx,:); 

                    % for each pressing condition (in roi) in this subject 
                    for spd=1:4 
                        % distances
                        Ss.RDM       = rsa.distanceLDC(betaW,D.run(partitionIdx),D.digit(partitionIdx).*double(D.speed(partitionIdx)==spd));
                        Ss.act       = mean(mean(betaW(D.speed(partitionIdx)==spd,:)));
                        % indexing fields
                        Ss.SN        = s;
                        Ss.region    = r;
                        Ss.speed     = spd;
                        Ss.numVox    = size(betaW,2);
                        Ss.partition = p;
                        Ts = addstruct(Ts,Ss);
                    end
                end; % each region
            end
        end; % each subject

        % % save
        save(fullfile(regDir,sprintf('glm%d_reg_splithalf_Tspeed.mat',glm)),'-struct','Ts');
        varargout = {Ts};
        fprintf('\nDone.\n')
    case 'HARVEST_rdmStability'
        % split-half correlations of RDM for each subject. 
        % RDMs include conds split per frequency.
        % Dissimilarities are calculated for each partition with
        % crossvalidation (distance_euclidean).
        glm     = 3;
        roi     = 12; % default primary motor cortex
        sn      = 10:17;
        type    = 'pearson';
        % Correlate patterns across even-odd run splits WITHIN subjects.
        % Does correlation across all depths.
        vararginoptions(varargin,{'roi','glm','sn','type'});
        if length(roi)>1; error('only one roi at a time.'); end
        T = load(fullfile(regDir,sprintf('glm%d_reg_splithalf_Tspeed.mat',glm)));
        
        if roi==16 | roi==34 % if visual cortices, avg. across hemispheres
            T = getrow(T,T.region==16 | T.region==34);
            T = tapply(T,{'SN','partition','speed'},{'RDM','mean'}); % don't touch this- it keeps rows in the same order compared to other rois!
        elseif roi==6 | roi==24 
            T = getrow(T,T.region==6 | T.region==24);
            T = tapply(T,{'SN','partition','speed'},{'RDM','mean'}); % don't touch this- it keeps rows in the same order compared to other rois!
        else
            T = getrow(T,T.region==roi);
        end
        A = []; % across speeds
        W = []; % within speeds
        
        pairIdx = rsa_squareRDM(1:6); % used for an indexing field (indicates the speed-pair number- 1:6)
        for s = sn % for each subject
            t = getrow(T,T.SN==s);
            % correlate splithalf RDMs
            switch type
                case 'pearson'
                    R = corrN(t.RDM');
                    %R = corrN(ssqrt(t.RDM)');
                case 'spearman'
                    R = corr(t.RDM','type','Spearman');
                    %R = corr(ssqrt(t.RDM)','type','Spearman');
                otherwise 
                    error 'No such correlation type'
            end
            % take correlations between partitions
            R = R(1:4,5:8); % take off-diag square matrix (correlations between even-odd data splits)
            for spd1 = 1:3
                w1 = R(spd1,spd1);              % observed spd 1 corr- used for prediction
                for spd2 = (spd1+1):4
                    w2 = R(spd2,spd2);          % observed spd 2 corr- used for prediction
                    b1 = R(spd1,spd2);          % corr b/t 1 & 2- used for observed
                    b2 = R(spd2,spd1);          % corr b/t 1 & 2- used for observed
                    % harvest cross-speed, cross-partition correlations
                    b.pcorr     = ssqrt(w1*w2); % predicted corr- sqrt b/c geometric mean
                    b.acorr     = ssqrt(b1*b2); % observed corr
                    %b.acorr     = (b1+b2)/2;
                    b.pcorr_fz  = fisherz(b.pcorr); % fisherz-transformed correlations
                    b.acorr_fz  = fisherz(b.acorr);
                    b.deviationN= b.acorr - b.pcorr; % Actual - Predicted speed pair correlation 
                    b.ratioNdev = b.deviationN./b.pcorr;
                    b.ratioNscl = b.acorr/b.pcorr;
                    b.dev_fz    = b.acorr_fz - b.pcorr_fz; % fisherz-transformed deviation
                    b.SN        = s;
                    b.roi       = roi;
                    b.speedpair = [spd1,spd2];
                    b.pairIdx   = pairIdx(spd1,spd2);
                    A = addstruct(A,b);
                end
            end
            % harvest within-speed, cross-partition correlations
            for spd = 1:4
                w.corr  = R(spd,spd);
                w.SN    = s;
                w.roi   = roi;
                w.speed = spd;
                W = addstruct(W,w);
            end
        end;
        
        %keyboard
        % rescale by avg. noise ceiling across subjs for each pairdIdx
        b = []; B = [];
        for i = 1:6
            b = getrow(A,A.pairIdx==i);
            b.ratioNsclAvg = b.acorr./mean(b.pcorr);
            B = addstruct(B,b);
        end
        A = B;
        % done stability analysis..
        varargout = {A,W};
    case 'FIG_rdmStability'                                                 % Primary stability analysis
        glm     = 3;
        roi     = 12; % default primary motor cortex
        sn      = 10:17;
        type    = 'pearson';
        subplt  = [];
        clrdots = 'none';
        % Correlate patterns across even-odd run splits WITHIN subjects.
        % Does correlation across all depths.
        vararginoptions(varargin,{'roi','glm','sn','type','subplt','clrdots'});
        
        [A,W] = fivedigitFreq3_imana('HARVEST_rdmStability','sn',sn,'roi',roi,'glm',glm,'type',type);   % get correlations
        
        
        switch clrdots
            case 'modelFits'
                % colour subject data points by linear or log-linear avg.
                % scaling fits
                clrs = {};
                T    = fivedigitFreq3_imana('STATS_ROIactivity','sn',sn,'roi',roi,'glm',glm);                  % get log-linear fits
                % determine which subjects had better log-linear fits
                betterLog = [T.log_r2 > T.lin_r2]+1;
                logColors = {[0.7 0.7 0.7],[0.3 0.3 0.3]}; % lightgrey = <lin fit, darkgray = <log fit
                for i = 1:length(sn)
                    clrs{i} = logColors{betterLog(i)};
                end
            case 'subj'
                % colour dots for each subject separately
                clrs = plt.helper.get_shades(length(sn),'jet','decrease');
        end
        
        % % ..now Plotting
        if isempty(subplt)
            figure('Color',[1 1 1]);
            subplt{1} = subplot(1,3,1);
            subplt{2} = subplot(1,3,2);
            subplt{3} = subplot(1,3,3);
        end
        % plot within-subject-WITHIN-speed-between-partition RDM correlations
        axes(subplt{1});
        myboxplot(A.pairIdx,A.acorr,'linecolor',[0 0 0],'xtickoff','style_tukey','plotall',1);
        %style.use('1black');
        %plt.dot(A.pairIdx,A.acorr,'split',A.pairIdx);
        %legend off
        title(reg_title{roi});
        set(gca,'XTickLabel',{'1:2','1:3','1:4','2:3','2:4','3:4'});
        xlabel('freq. condition pair');
        ylabel('cross-freq. correlation');
        if exist('clrs','var')
            hold on
            for j = 1:length(sn)
                % plot single-subject points
                s   = sn(j);
                a   = getrow(A,A.SN==s);
                plot(1:6,a.acorr,'LineStyle','none','Marker','o',...
                    'MarkerSize',5,'MarkerEdgeColor',clrs{j},'MarkerFaceColor',clrs{j});
            end
            hold off
        end   
        % get ylim info
        info = get(gca); 
        wlims = info.YAxis.Limits;
        
        % plot within-subjet-BETWEEN-speed-between-partition RDM correlations
        axes(subplt{2});
        myboxplot(W.speed,W.corr,'linecolor',[0 0 0],'xtickoff','style_tukey','plotall',1);
        %style.use('4speedsMarkers');
        %plt.dot(W.speed,W.corr,'split',W.speed);
        %legend off
        set(gca,'XTickLabel',{'1','2','3','4'});
        xlabel('freq. condition');
        ylabel('split-half reliability');
        if exist('clrs','var')
            hold on
            for j = 1:length(sn)
                % plot single-subject points
                s   = sn(j);
                w   = getrow(W,W.SN==s);
                plot(1:4,w.corr,'LineStyle','none','Marker','o',...
                    'MarkerSize',5,'MarkerEdgeColor',clrs{j},'MarkerFaceColor',clrs{j});
            end
            hold off
        end    
        ylim(wlims);
        % bring this subplot nearer to first subplot (sorta make it the
        % same plot space)
        %info = get(gca); info.YAxis.Visible = 'off';
        
        
        % plot deviations of actual-predicted between-speed correlations (2
        % points per subject b/c 2 partitions)
        axes(subplt{3});
%         myboxplot(A.pairIdx,A.deviationN,'linecolor',[0 0 0],'xtickoff','style_tukey','plotall',0);
%         drawline(0,'dir','horz');
%         set(gca,'XTickLabel',{'1:2','1:3','1:4','2:3','2:4','3:4'});
%         ylabel('Measured - Expected correlation');
        myboxplot(A.pairIdx,A.ratioNscl,'linecolor',[0 0 0],'xtickoff','style_tukey','plotall',1);
        %style.use('1black');
        %keyboard
        %plt.dot(A.pairIdx,A.ratioNscl,'split',A.pairIdx); 
        %legend off
        drawline(1,'dir','horz');
        set(gca,'XTickLabel',{'1:2','1:3','1:4','2:3','2:4','3:4'});
        ylabel('Measured / Expected correlation');
        xlabel('freq. condition pair');
        if exist('clrs','var')
            hold on
            for j = 1:length(sn)
                % plot single-subject points
                s   = sn(j);
                a   = getrow(A,A.SN==s);
                plot(1:6,a.ratioNscl,'LineStyle','none','Marker','o',...
                    'MarkerSize',5,'MarkerEdgeColor',clrs{j},'MarkerFaceColor',clrs{j});
            end
            hold off
        end
            
        %set(gcf,'PaperPosition',[0.25 2.5 8 3]);
        wysiwyg
    case 'STATS_rdmStability'                                       
        glm     = 3;
        roi     = 12; % default primary motor cortex
        sn      = 10:17;
        type    = 'pearson';
        % Correlate patterns across even-odd run splits WITHIN subjects.
        % Does correlation across all depths.
        % Computes stats (sign-rank tests), and returns datastructures.
        % Sign test run on non-fisherz transformed deviations, since
        % fisherz transform retains the sign of the deviation (it's
        % redundant).
        vararginoptions(varargin,{'roi','glm','sn','type'});
        
        [A,W] = fivedigitFreq3_imana('HARVEST_rdmStability','sn',sn,'roi',roi,'glm',glm,'type',type);
        
        % sign test for Observed - Predicted reliabilities at each of
        % the six speed pairs (1:2, 1:3, 1:4, 2:3, 2:4, 3:4).
        p = []; d = []; h= [];
        for i = 1:6
            %[p(end+1),h(end+1)] = signtest(A.deviationN(A.pairIdx==i),[],'tail','left'); 
            %d(end+1) = mean(A.deviationN(A.pairIdx==i));
            [p(end+1),h(end+1)] = signtest(A.ratioNscl(A.pairIdx==i)-1,[],'tail','left'); 
            d(end+1) = mean(A.ratioNscl(A.pairIdx==i));
        end
        p
        h
        d
        varargout = {A,W};
    case 'FIG_DistShape'                                                    % plot finger pattern RDMs for each speed as a different line. Subplot for each roi.       
        color = {[0 0 0] [0.5 0 0] [0.9 0 0] [1 0.6 0]};
        glm   = 3;
        roi   = 12;
        layer = 1;
        sn    = 10:17;
        subplt= [];
        vararginoptions(varargin,{'roi','glm','comp','layer','sn','subplt'});
        
        % load appropriate file and get rows for subjs and roi
        D = load(fullfile(regDir,sprintf('glm%d_reg_Tspeed.mat',glm)));
        D = getrow(D,D.layer==layer);
        if roi==16 | roi==34 % if visual cortices, avg. rdms over hemispheres
            D = getrow(D,D.region==16 | D.region==34);
            D = tapply(D,{'SN','speed'},{'RDM','mean'});
        elseif roi==6 | roi==24 % if visual cortices, avg. rdms over hemispheres
            D = getrow(D,D.region==6 | D.region==24);
            D = tapply(D,{'SN','speed'},{'RDM','mean'});
        else
            D = getrow(D,D.region==roi);
        end
        % harvesting for specific subjects
        T = [];
        for s = sn
            t = getrow(D,D.SN==s);
            T = addstruct(T,t);
            t = [];
        end
        D = T; 
        T = [];

        % dist shape subplot
        if isempty(subplt)
            figure('Color',[1 1 1],'NumberTitle','off','Name',sprintf('ROI: %d  LAYER: %d',roi,layer))
            subplot(1,2,[1:2]);
        else
            axes(subplt);
        end
        style.use('4speedsMarkers');
        plt.trace([1:10],D.RDM,'split',D.speed);%,'CAT',CAT,'errorfcn','stderr','leg',{'0.3Hz','0.6Hz','1.3Hz','2.6Hz'});
        plt.legend('northeast',{'0.3Hz','0.6Hz','1.3Hz','2.6Hz'});
        xlabel('Finger pair');
        ylabel('dissimilarity^2 (a.u.)');
        title(reg_title{roi});
        set(gca,'XLim',[0.5 10.5]);
        set(gca,'XTick',[1:10]);
        set(gca,'XTickLabel',{'1:2','1:3','1:4','1:5','2:3','2:4','2:5','3:4','3:5','4:5'});
        ylim([-0.002 0.053])

        set(gcf,'PaperPosition',[2 2 7 3]);
        wysiwyg;
        gcf;

        set(gcf,'InvertHardcopy','off');
        set(gcf,'PaperPosition',[2 2 7 2*length(roi)]);
        wysiwyg;
         
        %keyboard
    
    case 'STATS_distortionCurve'    
        % Simulates distorted model fitting between usage and muscle
        % models.
        % Generates rdm from each model G, distorts it, calculates
        % correlation b/t distorted and original rdm, and with other model
        % rdm.
        % Distorts paired distances in Usage rdm.
        % Distortions done to all 10 distances.
        % Model with highest correlation is winner. 
        % Returns results in plotting-friendly data structure.
        disLevel =[0:0.1:1];
        compLvl  = 'hard';
        vararginoptions(varargin,{'disLevel','compLvl'});
        numIters = 1000;
        squareroot = 0; % don't take ssqrt of rdms
        % load models
        load('/Users/sarbuckle/Documents/git_repos/pcm_toolbox/recipe_finger/data_recipe_finger7T.mat');
        % second moments for models
        if strcmp('hard',compLvl)
            G{1} = Model(1).G_cent; % muscle model
            compLvl = 2;
        elseif strcmp('med',compLvl)
            G{1} = Model(3).G_cent; % somatotopic model
            compLvl = 1;
        end
        G{2} = Model(2).G_cent; % usage model
        C = rsa.util.pairMatrix(5); % contrast matrix
        Mrdm = sum((C*G{1}).*C,2);  % muscle model RDM
        Nrdm = sum((C*G{2}).*C,2);  % usage model RDM
        if squareroot
            Mrdm = ssqrt(Mrdm);
            Nrdm = ssqrt(Nrdm);
        end
        T = []; % output structure
        for m = 1:2 % for each model
            % calc paired distances between fingers from second moments
            rdm = sum((C*G{m}).*C,2);
            if squareroot
                rdm = ssqrt(rdm);
            end
            rdm = repmat(rdm,1,numIters);
            %dist_func = {@(x,y) ones(x,y).*-1, @(x,y) ones(x,y), @(x,y) sample_wr([1,-1],x,y)};
            for j = 10 % for all 10 distances
                for d = disLevel % for each distortion level
                    Drdm = rdm;
                    jidx = sample_wor([1:10],j,numIters);                  % fingerpair(s) to distort
                    jidx = jidx + kron(ones(j,1),[0:10:numIters*10 - 10]); % add values to correctly index by column-major order
                    didx = sample_wr([1,-1],j,numIters);
                    Drdm(jidx) = Drdm(jidx) + (Drdm(jidx).*d.*didx);       % distort by add or subtracting some percentage 
                    
                    % calculate model correlations
                    t.mcorr  = corr(Mrdm,Drdm)';
                    t.mcorrN = corrN(Mrdm,Drdm)';
                    t.ncorr  = corr(Nrdm,Drdm)';
                    t.ncorrN = corrN(Nrdm,Drdm)';
                    
                    % determine winning model (and if winning model is
                    % true model)
                    if m==1 % muscle model
                        t.correctCorr  = t.mcorr > t.ncorr;
                        t.correctCorrN = t.mcorrN > t.ncorrN;
                        t.deviationN   = t.mcorrN-1;
                        t.trueCorrN    = t.mcorrN;
                    elseif m==2 % usage model
                        t.correctCorr  = t.ncorr > t.mcorr;
                        t.correctCorrN = t.ncorrN > t.mcorrN;
                        t.deviationN   = t.ncorrN-1;
                        t.trueCorrN    = t.ncorrN;
                    end
                    % add indexing fields
                    t.numPairs  = ones(numIters,1).*j;
                    t.pdistort  = ones(numIters,1).*d;
                    t.trueModel = ones(numIters,1).*m;
                    t.compLvl   = ones(numIters,1).*compLvl;
                    %t.distortType = ones(numIters,1).*i;
                    T = addstruct(T,t);
                end
            end
        end
        varargout = {T};
    case 'FIG_distortionCurve'
        % CAUTION: ALTERATION WILL MESS UP THE X-AXIS LABELS
        disLevel = [0:0.05:0.6];
        plotMean = 1;
        D1 = fivedigitFreq3_imana('STATS_distortionCurve','compLvl','hard','disLevel',disLevel);
        D1 = tapply(D1,{'pdistort','compLvl'},{'trueCorrN','mean'},{'correctCorrN','mean'},{'correctCorr','mean'});
        D2 = fivedigitFreq3_imana('STATS_distortionCurve','compLvl','med','disLevel',disLevel);
        D2 = tapply(D2,{'pdistort','compLvl'},{'trueCorrN','mean'},{'correctCorrN','mean'},{'correctCorr','mean'});
        D = addstruct(D1,D2);
        % avg. trueCorrN for same distortion lvl across comp difficulty so
        % we can plot on same x-axis points
        D.trueCorrN = repmat(mean([D.trueCorrN(D.compLvl==1) D.trueCorrN(D.compLvl==2)],2),[2,1]);

        xlabs = {};
        for i = 1:length(disLevel)
            xlabs{end+1} = sprintf('%0.3f',mean(D.trueCorrN(D.pdistort==disLevel(i))));
        end
        
        
        %modelName = {'muscle','usage'};
        % plot for each model in different figure
%         for m=1:2
            j = 1;
            figure('Color',[1 1 1]);
            % plot rdm correlations
%             subplot(1,3,j);
%             plt.box(D.pdistort,[D.mcorr,D.ncorr],'style',sty,'subset',D.trueModel==m);
%             plt.labels('distortion level (%)','corr to true rdms',sprintf('%s model  .',modelName{m}));
%             plt.set('xticklabel',{'','0','','0.1','','0.2','','0.3','','0.4','','0.5',...
%                                    '','0.6','','0.7','','0.8','','0.9','','1'},'xticklabelrotation',45);
%             plt.legend('northeast',modelName);
%             ylim([0 1])
%             j = j+1;
%             % plot % correct model wins
%             subplot(1,3,j);
%             plt.box(D.pdistort,[D.mcorrN,D.ncorrN],'style',sty,'subset',D.trueModel==m);
%             plt.labels('distortion level (%)','corrN to true rdms',sprintf('%s model  .',modelName{m}));
%             plt.set('xticklabel',{'','0','','0.1','','0.2','','0.3','','0.4','','0.5',...
%                                    '','0.6','','0.7','','0.8','','0.9','','1'},'xticklabelrotation',45);
%             plt.legend('northeast',modelName);
%             j = j+1;
%             % plot % correct model wins
%             subplot(1,3,j);
            plt.line(-D.trueCorrN,[1-D.correctCorrN],'style',style.custom({'lightgray','darkgray'}),'split',D.compLvl);
            plt.labels('distortion level (%)','confusion rate (%)');
            plt.set('xticklabelrotation',45,'xtick',[-1:0.02:-0.84],'xticklabel',{'1','0.98','0.96','0.94','0.92','0.90','0.88','0.86','0.84'});
            plt.legend('northeast',{'med','hard'});
            xlim([-1,-0.86]);
            ylim([0 0.35]);
            
            if plotMean
                m1 = fivedigitFreq3_imana('BAYES_bf','roi',12,'glm',3,'freqPair',[2,3,5],'squareroot',0,'disLevel',[0]);
                s1 = fivedigitFreq3_imana('BAYES_bf','roi',11,'glm',3,'freqPair',[2,3,5],'squareroot',0,'disLevel',[0]);
                v1v2 = fivedigitFreq3_imana('BAYES_bf','roi',24,'glm',3,'freqPair',[5],'squareroot',0,'disLevel',[0]);
                drawline(-m1.ratioN,'dir','vert','linestyle',':','color',[0 0.8 0]);
                drawline(-s1.ratioN,'dir','vert','linestyle',':','color',[0 0 0]);
                drawline(-v1v2.ratioN,'dir','vert','linestyle',':','color',[0.25 0.88 0.82]);
            end
            
            %plt.match('y');
%         end
       %keyboard
        
    case 'depreciated_BAYES_rdmStability'    
        % Simulates distorted rdms.
        % Mixed 10% distortion to all 10 paired distances.
        % Returns results in plotting-friendly data structure.
        numIters = 1000; % per subject's data
        sn = 10:17;
        glm = 3;
        roi = [12];
        vararginoptions(varargin,{'sn','glm','roi'});
        
        disLevel = 0.1; % 10% distortion level
        
        if length(roi)>1; error('only one roi for case.'); end
        % load data
        T = load(fullfile(regDir,sprintf('glm%d_reg_splithalf_Tspeed.mat',glm)));
        if roi==16 | roi==34 % if visual cortices, avg. across hemispheres
            T = getrow(T,T.region==16 | T.region==34);
            T = tapply(T,{'SN','speed'},{'RDM','mean'}); % don't touch this- it keeps rows in the same order compared to other rois!
        else
            T = getrow(T,T.region==roi);
        end
        A = []; % across freqs
        W = []; % within speeds
        
        pairIdx = rsa_squareRDM(1:6); % used for an indexing field (indicates the speed-pair number- 1:6)
        for s = sn % for each subject
            t = getrow(T,T.SN==s);
            % correlate RDMs without distortion
            R = corrN(t.RDM');
            %R = corrN(ssqrt(t.RDM)');
            % take correlations between partitions
            R = R(1:4,5:8); % take off-diag square matrix (correlations between even-odd data splits)
            for spd1 = 1:3
                w1 = R(spd1,spd1);              % observed spd 1 corr- used for prediction
                for spd2 = (spd1+1):4
                    w2 = R(spd2,spd2);          % observed spd 2 corr- used for prediction
                    b1 = R(spd1,spd2);          % corr b/t 1 & 2- used for observed
                    b2 = R(spd2,spd1);          % corr b/t 1 & 2- used for observed
                    % harvest cross-speed, cross-partition correlations
                    b.pcorr     = ssqrt(w1*w2); % predicted corr- sqrt b/c geometric mean
                    b.acorr     = ssqrt(b1*b2); % observed corr
                    b.dev_corr  = b.acorr-b.pcorr;
                    b.sn        = s;
                    b.roi       = roi;
                    b.freqPair = [spd1,spd2];
                    b.pairIdx   = pairIdx(spd1,spd2);
                    
                    
                    % % INCORRECT APPROACH (i think- SA)
                    % now calculate distorted rdm distribution
                    % First, distort [spd1 rdm, partition 1] and [spd1 rdm, partition 2]
                    oRDM = [repmat(t.RDM(t.speed==spd2 & t.partition==2,:)',1,numIters), repmat(t.RDM(t.speed==spd2 & t.partition==1,:)',1,numIters)];
                    sRDM = [repmat(t.RDM(t.speed==spd1 & t.partition==1,:)',1,numIters), repmat(t.RDM(t.speed==spd1 & t.partition==2,:)',1,numIters)];
                    jidx  = sample_wor([1:10],10,numIters*2);                       % fingerpair(s) to distort
                    jidx  = jidx + kron(ones(10,1),[0:10:numIters*10*2 - 10]);  % add values to correctly index by column-major order
                    didx  = sample_wr([1,-1],10,numIters*2);
                    sRDM(jidx) = sRDM(jidx) + (sRDM(jidx).*disLevel.*didx); % distort by add or subtracting some percentage 
                    % correlate distored rdms with undistorted spd1 rdm
                    Rd1 = diag(corrN(oRDM,sRDM));
                    % Now distort [spd2 rdm, partition 1] and [spd2 rdm, partition 1]
                    sRDM = [repmat(t.RDM(t.speed==spd2 & t.partition==2,:)',1,numIters), repmat(t.RDM(t.speed==spd2 & t.partition==1,:)',1,numIters)];
                    oRDM = [repmat(t.RDM(t.speed==spd1 & t.partition==1,:)',1,numIters), repmat(t.RDM(t.speed==spd1 & t.partition==2,:)',1,numIters)];
                    jidx  = sample_wor([1:10],10,numIters*2);                       % fingerpair(s) to distort
                    jidx  = jidx + kron(ones(10,1),[0:10:numIters*10*2 - 10]);  % add values to correctly index by column-major order
                    didx  = sample_wr([1,-1],10,numIters*2);
                    sRDM(jidx) = sRDM(jidx) + (sRDM(jidx).*disLevel.*didx); % distort by add or subtracting some percentage 
                    % correlate distored rdms with undistorted spd2 rdm
                    Rd2 = diag(corrN(oRDM,sRDM));
                    % avg. simulated distrotion correlations, then
                    % geometric mean of the 
                    b.dcorr  = ssqrt(mean(Rd1)*mean(Rd2));
                    b.dsd    = std([Rd1;Rd2]);
                    b.dev_dcorr = b.dcorr-b.pcorr;
                    
                    A = addstruct(A,b);
                end
            end
        end;
        b = [];
        B = []; %plotting friendly structure
        ii = ones(2,1);
        for i = 1:length(A.sn)
            b.corr    = [A.dev_corr(i);A.dev_dcorr(i)];
            b.pairIdx = ii.*A.pairIdx(i);
            b.sn      = ii.*A.sn(i);
            b.roi     = ii.*A.roi(i);
            b.type    = [1;2]; % 1=actual corr. deviation, 2=distorted corr deviation
            B = addstruct(B,b);
        end
        
        varargout = {A,B};
    case 'depreciated_BAYES_rdmStabilityDist'    
        % Simulates distorted rdms.
        % Mixed 10% distortion to all 10 paired distances.
        % Returns results in plotting-friendly data structure.
        numIters = 1000; % per subject's data
        sn = 10:17;
        glm = 3;
        roi = [12];
        disLevel = 0.1; % 10% distortion level
        squareroot = 0; 
        vararginoptions(varargin,{'sn','glm','roi','disLevel','squareroot'});
        
        if length(roi)>1; error('only one roi for case.'); end
        % load data
        %T = load(fullfile(regDir,sprintf('glm%d_reg_splithalf_Tspeed.mat',glm)));
        T = load(fullfile(regDir,sprintf('glm%d_reg_Tspeed.mat',glm)));
        T = getrow(T,T.layer==1);
        if roi==16 | roi==34 % if visual cortices, avg. across hemispheres
            T = getrow(T,T.region==16 | T.region==34);
            T = tapply(T,{'SN','speed'},{'RDM','mean'}); % don't touch this- it keeps rows in the same order compared to other rois!
        elseif roi==6 | roi==24 % if visual cortices, avg. across hemispheres
            T = getrow(T,T.region==6 | T.region==24);
            T = tapply(T,{'SN','speed'},{'RDM','mean'}); % don't touch this- it keeps rows in the same order compared to other rois!
        else
            T = getrow(T,T.region==roi);
        end
        B = [];
        for s = sn % for each subject
            t = getrow(T,T.SN==s);
            for spd = 1:4
                % Get rdms for this speed
                rdm  = t.RDM(t.speed==spd,:)';
                if squareroot
                    rdm  = ssqrt(rdm);
                end  
                Drdm = repmat(rdm,1,numIters);
                jidx = sample_wor([1:10],10,numIters);                   % fingerpair(s) to distort- distort all 10
                jidx = jidx + kron(ones(10,1),[0:10:numIters*10 - 10]);  % add values to correctly index by column-major order
                didx = sample_wr([1,-1],10,numIters);                    % randomly sample add/subtract. distortion for each iteration
                Drdm(jidx) = Drdm(jidx) + (Drdm(jidx).*disLevel.*didx);  % do distortion
                % correlate distored rdms with undistorted rdms
                Rnd = corrN(rdm,Drdm);
                Rd  = corr(rdm,Drdm);
                % avg. simulated distrotion correlations
                b.dcorrN     = mean(Rnd);
                b.dcorr      = mean(Rd);
                b.dsd        = std(Rnd);
                b.deviationN = b.dcorrN-1;
                b.deviation  = b.dcorr-1;
                b.speed      = spd;
                b.roi        = roi;
                b.SN         = s;
                B = addstruct(B,b);
            end
        end;
        
        varargout = {B};
    case 'depreciated_PLOT_bayesDists_allPairs'   
        sn = 10:17;
        glm = 3;
        roi = [12];
        type = 'corrN'; % or 'corr'
        squareroot = 0;
        disLevel = [0.1,0.2,0.3]; % distortion levels
        vararginoptions(varargin,{'sn','glm','roi','disLevel','type','squareroot'});
        
        numCols = length(disLevel)+1;
        
        A = fivedigitFreq3_imana('BAYES_rdmStabilityTrue','sn',sn,'roi',roi,'glm',glm,'squareroot',squareroot);   % get actual correlation deviations
        
        figure('Color',[1 1 1]);
        % plot real data deviation histrograms, split by cross-freq. pair
        subplot(2,numCols,1);
        if strcmp(type,'corr')
            plt.hist(A.deviation,'split',A.pairIdx,'style',style.custom(plt.helper.get_shades(6,'jet','decrease')));
        elseif strcmp(type,'corrN')
            plt.hist(A.deviationN,'split',A.pairIdx,'style',style.custom(plt.helper.get_shades(6,'jet','decrease')));
        end
        plt.labels('observed - predicted crossfreq. corr','count',sprintf('%s real data  .',regname{roi}));
        plt.legend('northeast',{'crossfreq pair 1','pair 2','pair 3','pair 4','pair 5','pair 6'});
        
        j = 2; % subplot ticker
        for i = 1:length(disLevel)
            % distortion at this level
            B = fivedigitFreq3_imana('BAYES_rdmStabilityDist','sn',sn,'roi',roi,'glm',glm,'disLevel',disLevel(i),'squareroot',squareroot);
            % plot distorted histrgrams, split by frequency condition
            subplot(2,numCols,j);
            style.use('4speedsMarkers');
            if strcmp(type,'corr')
                plt.hist(B.deviation,'split',B.speed);
            elseif strcmp(type,'corrN')
                plt.hist(B.deviationN,'split',B.speed);
            end
            plt.labels('distorted - predicted reliability','count',sprintf('%1.2f percent distortion  .',disLevel(i)));
            plt.legend('northeast',{'freq 1','freq 2','freq 3','freq 4'});

            % plot deviation distributions, overlayed
            subplot(2,numCols,j+numCols);
            AB.SN        = [A.SN;B.SN];
            AB.roi       = [A.roi;B.roi];
            AB.type      = [ones(length(A.SN),1);ones(length(B.SN),1).*2];
            if strcmp(type,'corr')
                AB.deviation = [A.deviation;B.deviation];
                plt.hist(AB.deviation,'split',AB.type,'style',style.custom({'black','lightgray'}));
            elseif strcmp(type,'corrN')
                AB.deviationN = [A.deviationN;B.deviationN];
                plt.hist(AB.deviationN,'split',AB.type,'style',style.custom({'black','lightgray'}));
            end
            plt.labels('correlation deviations','count','overlayed distributions  .');
            plt.legend('northeast',{'real data','distorted'});
            j = j+1;
        end
        %keyboard
    case 'depreciated_BAYES_bf_allPairs'
        % Compute probability of true deviations from distribution of
        % distorted deviations.
        % Uses std of real data and mean of distorted deviations to compute
        % prior probabilities.
        sn = 10:17;
        glm = 3;
        roi = [12];
        type = 'corrN'; % or 'corr'
        squareroot = 0;
        disLevel = [0,0.01,0.05,0.1,0.2,0.3]; % distortion levels
        freqPair = [1:6]; % which cross-frequency pairs to include
        vararginoptions(varargin,{'sn','glm','roi','disLevel','type','freqPair','squareroot'});
        % get actual correlation deviations
        A = fivedigitFreq3_imana('BAYES_rdmStabilityTrue','sn',sn,'roi',roi,'glm',glm,'squareroot',squareroot);
        A = getrow(A,ismember(A.pairIdx,freqPair));
        % calc std of deviation distributions
        if strcmp(type,'corr');
            sigmaA = std(A.deviation);
        elseif strcmp(type,'corrN');
            sigmaA = std(A.deviationN);
        end
        
        D = [];
        for i = 1:length(disLevel)
            % distortion at this level
            B = fivedigitFreq3_imana('BAYES_rdmStabilityDist','sn',sn,'roi',roi,'glm',glm,'disLevel',disLevel(i),'squareroot',squareroot); 
            % calculate probabilities under alternative and null models
            if strcmp(type,'corr');
                d.meanD = mean(B.deviation);
                pA = exp(-(-A.deviation).^2/(2*sigmaA^2));
                pB = exp(-(-A.deviation-mean(B.deviation)).^2/(2*sigmaA^2));
            elseif strcmp(type,'corrN');
                d.meanD = mean(B.deviationN);
                pA = exp(-(-A.deviationN).^2/(2*sigmaA^2));
                pB = exp(-(-A.deviationN-mean(B.deviationN)).^2/(2*sigmaA^2));
            end
            d.pA = pA';
            d.pB = pB';
            d.bf = prod(pA)/prod(pB); % calcualte bayes factor
            d.sigma = sigmaA;
            d.disLevel = disLevel(i);
            d.disNum = i; % for plotting 
            d.roi = roi;
            d.glm = glm;
            d.type = type;
            d.freqPair = freqPair;
            D = addstruct(D,d);
        end
        varargout = {D};
    case 'depreciated_PLOT_bayesBF_allPairs'
        % Plots bayes factors for roi across increasing levels of distortion.
        % Plots are split by cross-frequency pairs (1:6)
        sn = 10:17;
        glm = 3;
        roi = [12];
        type = 'corrN'; % or 'corr'
        fig = [];
        disLevel = [0,0.01,0.05,0.1,0.2,0.3]; % distortion levels
        squareroot = 0; % take ssqrt of rdms or not
        vararginoptions(varargin,{'sn','roi','disLevel','type','fig','squareroot'});
        
        % Loop through cross-frequency pairs, calculate BF, add to plotting
        % friendly-structure
        D = [];
        for f = 1:6
            d = fivedigitFreq3_imana('BAYES_bf_allPairs','type',type,'roi',roi,'glm',glm,'disLevel',disLevel,'freqPair',f,'squareroot',squareroot);
            D = addstruct(D,d);
        end
        % plot
        if isempty(fig); figure('Color',[1 1 1]); else; fig; end
        sty = style.custom(plt.helper.get_shades(6,'jet','decrease'));
        plt.line(D.disNum,D.bf,'split',D.freqPair,'style',sty);
        xlabs = {};
        for i = 1:length(disLevel)
            xlabs{end+1} = sprintf('%0.2f',disLevel(i));
        end
        plt.set('xticklabel',xlabs,'xticklabelrotation',45);
        plt.labels('distortion level (%)','log bayes factor',sprintf('%s %s   .',regname{roi},type));
        plt.legend('northwest',{'freqPair 1','pair 2','pair 3','pair 4','pair 5','pair 6'});
        
        ylim([0.5 4]);
        drawline(1,'dir','horz','color',[0.7 0 0]);
        drawline(3,'dir','horz','color',[0.7 0 0],'linestyle',':');
        
        %keyboard
        
        varargout = {D};
    case 'depreciated_PLOT_bayesDists'   
        sn = 10:17;
        glm = 3;
        roi = [12];
        type = 'corrN'; % or 'corr'
        squareroot = 0;
        disLevel = [0.1,0.2,0.3]; % distortion levels
        freqPair = [2,3,5]; % which cross-frequency pairs to include
        vararginoptions(varargin,{'sn','glm','roi','disLevel','type','squareroot'});
        
        numCols = length(disLevel)+1;
        
        A = fivedigitFreq3_imana('BAYES_rdmStabilityTrue','sn',sn,'roi',roi,'glm',glm,'squareroot',squareroot);   % get actual correlation deviations
        A = getrow(A,ismember(A.pairIdx,freqPair)); % cross-frequency pairs to test
        figure('Color',[1 1 1]);
        % plot real data deviation histrograms, split by cross-freq. pair
        subplot(2,numCols,1);
        if strcmp(type,'corr')
            plt.hist(A.deviation,'split',A.pairIdx,'style',style.custom(plt.helper.get_shades(6,'jet','decrease')));
        elseif strcmp(type,'corrN')
            plt.hist(A.deviationN,'split',A.pairIdx,'style',style.custom(plt.helper.get_shades(6,'jet','decrease')));
        end
        plt.labels('observed - predicted crossfreq. corr','count',sprintf('%s real data  .',regname{roi}));
        plt.legend('northeast',{'crossfreq pair 1','pair 2','pair 3','pair 4','pair 5','pair 6'});
        
        j = 2; % subplot ticker
        for i = 1:length(disLevel)
            % distortion at this level
            B = fivedigitFreq3_imana('BAYES_rdmStabilityDist','sn',sn,'roi',roi,'glm',glm,'disLevel',disLevel(i),'squareroot',squareroot);
            % plot distorted histrgrams, split by frequency condition
            subplot(2,numCols,j);
            style.use('4speedsMarkers');
            if strcmp(type,'corr')
                plt.hist(B.deviation,'split',B.speed);
            elseif strcmp(type,'corrN')
                plt.hist(B.deviationN,'split',B.speed);
            end
            plt.labels('distorted - predicted reliability','count',sprintf('%1.2f percent distortion  .',disLevel(i)));
            plt.legend('northeast',{'freq 1','freq 2','freq 3','freq 4'});

            % plot deviation distributions, overlayed
            subplot(2,numCols,j+numCols);
            AB.SN        = [A.SN;B.SN];
            AB.roi       = [A.roi;B.roi];
            AB.type      = [ones(length(A.SN),1);ones(length(B.SN),1).*2];
            if strcmp(type,'corr')
                AB.deviation = [A.deviation;B.deviation];
                plt.hist(AB.deviation,'split',AB.type,'style',style.custom({'black','lightgray'}));
            elseif strcmp(type,'corrN')
                AB.deviationN = [A.deviationN;B.deviationN];
                plt.hist(AB.deviationN,'split',AB.type,'style',style.custom({'black','lightgray'}));
            end
            plt.labels('correlation deviations','count','overlayed distributions  .');
            plt.legend('northeast',{'real data','distorted'});
            j = j+1;
        end
        %keyboard
    
    case 'BAYES_rdmStabilityTrue'
        % split-half correlations of RDM for each subject. 
        % RDMs include all 20 conds.
        % Dissimilarities are calculated for each partition with
        % crossvalidation (distance_euclidean).
        glm     = 3;
        roi     = 12; % default primary motor cortex
        sn      = 10:17;
        squareroot = 0;
        % Correlate patterns across even-odd run splits WITHIN subjects.
        % Does correlation across all depths.
        vararginoptions(varargin,{'roi','glm','sn','squareroot'});
        
        T = load(fullfile(regDir,sprintf('glm%d_reg_splithalf_Tspeed.mat',glm)));
        
        if roi==16 | roi==34 % if visual cortices, avg. across hemispheres
            T = getrow(T,T.region==16 | T.region==34);
            T = tapply(T,{'SN','partition','speed'},{'RDM','mean'}); % don't touch this- it keeps rows in the same order compared to other rois!
        elseif roi==6 | roi==24 % if visual cortices, avg. across hemispheres
            T = getrow(T,T.region==6 | T.region==24);
            T = tapply(T,{'SN','partition','speed'},{'RDM','mean'}); % don't touch this- it keeps rows in the same order compared to other rois!
        else
            T = getrow(T,T.region==roi);
        end
        A = []; % across speeds
        
        pairIdx = rsa_squareRDM(1:6); % used for an indexing field (indicates the speed-pair number- 1:6)
        for s = sn % for each subject
            t = getrow(T,T.SN==s);
            % correlate splithalf RDMs
            if squareroot
                Rn = corrN(ssqrt(t.RDM)');
                R  = corr(ssqrt(t.RDM)');
            else
                Rn = corrN(t.RDM');
                R  = corr(t.RDM');
            end
            % take correlations between partitions
            Rn = Rn(1:4,5:8); % take off-diag square matrix (correlations between even-odd data splits)
            R  = R(1:4,5:8); % take off-diag square matrix (correlations between even-odd data splits)
            for spd1 = 1:3
                w1n = Rn(spd1,spd1);              % observed spd 1 corr- used for prediction
                w1  = R(spd1,spd1);             
                for spd2 = (spd1+1):4
                    w2n = Rn(spd2,spd2);          % observed spd 2 corr- used for prediction
                    b1n = Rn(spd1,spd2);          % corr b/t 1 & 2- used for observed
                    b2n = Rn(spd2,spd1);          % corr b/t 1 & 2- used for observed
                    w2  = R(spd2,spd2);         
                    b1  = R(spd1,spd2);          
                    b2  = R(spd2,spd1);         
                    % harvest cross-speed, cross-partition correlations
                    b.pcorrN    = ssqrt(w1n*w2n); % predicted corr- sqrt b/c geometric mean
                    b.acorrN    = ssqrt(b1n*b2n); % observed corr
                    b.pcorr     = ssqrt(w1*w2);
                    b.acorr     = ssqrt(b1*b2);
                    % calculate deviations
                    b.deviationN = b.acorrN - b.pcorrN; % Actual - Predicted speed pair correlation 
                    b.deviation  = b.acorr - b.pcorr;
                    % add indexing fields
                    b.SN        = s;
                    b.roi       = roi;
                    b.speedpair = [spd1,spd2];
                    b.pairIdx   = pairIdx(spd1,spd2);
                    A = addstruct(A,b);
                end
            end
        end;
        % done stability analysis..
        varargout = {A};
    case 'BAYES_bf'
        % Compute probability of true deviations from distribution of
        % distorted deviations.
        % Uses std of real data and mean of distorted deviations to compute
        % prior probabilities.
        sn = 10:17;
        glm = 3;
        roi = [12];
        type = 'corrN'; % or 'corr'
        squareroot = 0;
        disLevel = [0,0.01,0.05,0.1,0.2,0.3]; % distortion levels
        freqPair = [2,3,5]; % which cross-frequency pairs to include
        vararginoptions(varargin,{'sn','glm','roi','disLevel','type','freqPair','squareroot'});
        % get actual correlation deviations
        %A = fivedigitFreq3_imana('BAYES_rdmStabilityTrue','sn',sn,'roi',roi,'glm',glm,'squareroot',squareroot);
        A = fivedigitFreq3_imana('HARVEST_rdmStability','sn',sn,'roi',roi,'glm',glm,'type','pearson');
        A = getrow(A,ismember(A.pairIdx,freqPair));
        %A.ratioN = A.deviationN./A.pcorrN; % calculate ratio of deviation given noise ceiling
        % avg. deviations for each subject across cross-freq pairs
        A = tapply(A,{'SN','roi'},{'deviationN','mean'},{'ratioNdev','mean'},{'ratioNscl','mean'},{'ratioNsclAvg','mean'});
        % calc std of deviation distributions
        if strcmp(type,'corr');
            sdA = std(A.deviation);
        elseif strcmp(type,'corrN');
            %sdA = std(A.ratioNdev);
            sdA = std(A.ratioNscl);
            %sdA = std(A.ratioNsclAvg);
        end
        
        D = [];
        % get distortion distribution means
        B = fivedigitFreq3_imana('STATS_distortionCurve','disLevel',disLevel);
        B = tapply(B,{'pdistort'},{'deviationN','mean'},{'trueCorrN','mean'});
        for i = 1:length(disLevel)
            b = getrow(B,B.pdistort==disLevel(i));
            % distortion at this level for each subject's data
            %b = fivedigitFreq3_imana('BAYES_rdmStabilityDist','sn',sn,'roi',roi,'glm',glm,'disLevel',disLevel(i),'squareroot',squareroot); 
            %b = tapply(b,{'SN','roi'},{'deviationN','mean'},{'deviation','mean'});
            % calculate probabilities under alternative and null models
            if strcmp(type,'corr');
                error('corr not supported. Support only for corrN.')
                %d.meanD = mean(B.deviation);
                %pA = exp(-(A.deviation).^2/(2*sdA^2));
                %pB = exp(-(A.deviation - b.deviation).^2/(2*sdA^2));  % prob under distortion
            elseif strcmp(type,'corrN');
                 %d.meanD = b.deviationN;
                 %d.ratioN = mean(A.ratioNdev);
                 %pA = exp(-(A.ratioNdev).^2/(2*sdA^2));                % prob under null
                 %pB = exp(-(A.ratioNdev - b.deviationN).^2/(2*sdA^2)); % prob under distortion
                 
                 pA = normpdf(A.ratioNscl,1,sdA);  % to check work
                 pB = normpdf(A.ratioNscl,b.trueCorrN,sdA);
                 
                 d.meanD = b.trueCorrN;
                 d.ratioN = mean(A.ratioNscl);
                 %pA = exp(-(A.ratioNscl-1).^2/(2*sdA^2));                % prob under null
                 %pB = exp(-(A.ratioNscl - b.trueCorrN).^2/(2*sdA^2)); % prob under distortion
            end
            d.numSubj = length(sn);
            d.bfnull    = prod(pA)/prod(pB); % calculate bayes factor
            d.bfalt     = prod(pB)/prod(pA); % calculate bayes factor
            d.logbfnull = sum(log(pA)) - sum(log(pB)); % logBF of alt models is the inverse.
            d.KRlogbfnull = sum(2*log(pA)) - sum(2*log(pB)); % calculate the Kass & Raftery (1995) BF = 2*log(B) scale
           % d.logbfalt  = sum(log(pB)) - sum(log(pA));
            d.sdA = sdA;
            d.disLevel = disLevel(i);
            d.disNum = i; % for plotting 
            d.roi = roi;
            d.glm = glm;
            d.type = type;
            %d.freqPair = freqPair;
            D = addstruct(D,d);
        end
        varargout = {D};
    case 'depreciated_PLOT_bayesBF_singleROI'
        % Plots bayes factors for roi across increasing levels of distortion.
        % Plots are for BF pooled across freqPairs 2,3,& 5 for one roi.
        sn = 10:17;
        glm = 3;
        roi = [12];
        type = 'corrN'; % or 'corr'
        fig = [];
        disLevel = [0:0.05:0.25]; % distortion levels
        squareroot = 0; % don't take ssqrt of rdms
        vararginoptions(varargin,{'sn','roi','disLevel','type','fig','squareroot'});
        
        % Calculate BF across pairs (group-BF test)
        D = fivedigitFreq3_imana('BAYES_bf','type',type,'roi',roi,'glm',glm,'disLevel',disLevel,'freqPair',[2,3,5],'squareroot',squareroot,'sn',sn);

        % plot
        if isempty(fig); figure('Color',[1 1 1]); else; fig; end
        sty = style.custom(plt.helper.get_shades(6,'jet','decrease'));
        plt.line(D.disNum,D.logbfnull,'style',sty);
        xlabs = {};
        for i = 1:length(disLevel)
            xlabs{end+1} = sprintf('%0.2f',disLevel(i));
        end
        plt.set('xticklabel',xlabs,'xticklabelrotation',45);
        plt.labels('noise level','log bayes factor',sprintf('%s %s   .',regname{roi},type));
        
        %ylim([0.5 4]);
        drawline(log(1),'dir','horz','color',[0.7 0 0]);
        drawline(log(3),'dir','horz','color',[0.7 0 0],'linestyle',':');
        
        %keyboard
        
        varargout = {D};
    case 'PLOT_bayesBF_multiROI'
        % Plots bayes factors for roi across increasing levels of distortion.
        % Plots the raw bayes factor for statistical interpretations.
        % Plots are split by cross-frequency pairs (1:6)
        sn = 10:17;
        glm = 3;
        roi = [11,12,24];
        type = 'corrN'; % or 'corr' DON'T CHANGE
        fig = [];
        disLevel = [0:0.05:0.6]; % distortion levels
        squareroot = 0; % don't take ssqrt of rdms DON'T CHANGE
        vararginoptions(varargin,{'disLevel','fig'});
        
        D = [];
        for r = roi
            % Calculate BF across pairs (group-BF test)
            d = fivedigitFreq3_imana('BAYES_bf','type',type,'roi',r,'glm',glm,'disLevel',disLevel,'freqPair',[2,3,5],'squareroot',squareroot,'sn',sn);
            if r==16 | r==24
                d = fivedigitFreq3_imana('BAYES_bf','type',type,'roi',r,'glm',glm,'disLevel',disLevel,'freqPair',[5],'squareroot',squareroot,'sn',sn);
                d.roi = ones(size(d.roi)).*16;
            end
            D = addstruct(D,d);
        end
        % plot styling
        xlabs1 = {};
        xlabs2 = xlabs1;
        for i = 1:length(disLevel)
            xlabs1{end+1} = sprintf('%0.2f',disLevel(i));
            xlabs2{end+1} = sprintf('%0.3f',mean(D.meanD(D.disLevel==disLevel(i))));
            D.meanD(D.disLevel==disLevel(i)) = mean(D.meanD(D.disLevel==disLevel(i)));
        end
        % plot
        if isempty(fig); figure('Color',[1 1 1]); else; fig; end
        sty = style.custom({[0 0 0],[0 0.75 0],[0.3 0.8 0.8]});
        sty.general.markersize = 4;
        hold on;
        xlim([-1,-0.86]);
        % add evidence cutoff lines according to Kass & Raftery 1995
        drawline(0,'dir','horz','color',[0.7 0 0]);
        drawline(1,'dir','horz','color',[0.7 0 0],'linestyle',':');  % log BF of 1 ~ BF of 3
        drawline(3,'dir','horz','color',[0.7 0 0],'linestyle',':');  % log BF of 3 ~ BF of 20
        drawline(-1,'dir','horz','color',[0.7 0 0],'linestyle',':');
        % plot the log(BF)
        plt.line(-D.meanD,D.bfnull,'split',D.roi,'style',sty);
        plt.set('xtick',[-1:0.02:-0.84],'xticklabel',{'1','0.98','0.96','0.94','0.92','0.90','0.88','0.86','0.84'},'xticklabelrotation',45);
        %plt.set('ytick',[-6:2:12],'yticklabel',{'20','8','3','0','3','8','20','55','150','400'});
        %ylim([-6 12]);
        xlim([-1,-0.86]);
        
        %plt.set('xticklabel',xlabs2,'xticklabelrotation',45);
        plt.labels('rescaled cross-freq corrN','bayes factor','RDM stability');
        plt.legend('northwest',{'S1','M1','V1/V2'});
        varargout = {D};    
    case 'Fig_BF'
        % Plots bayes factors for roi across increasing levels of distortion.
        % Plots are split by rois.
        % plotting is done by switching signs (from pos to
        % negative) for stylistic purposes.
        sn   = 10:17;%[10,12:17];
        glm  = 3;
        roi  = [11,12,24];
        type = 'corrN'; % or 'corr' DON'T CHANGE
        fig  = [];
        disLevel = [0:0.01:0.6]; % distortion levels
        squareroot = 0; % don't take ssqrt of rdms DON'T CHANGE
        vararginoptions(varargin,{'disLevel','fig'});
        
        D = [];
        for r = roi
            % Calculate BF across pairs (group-BF test)
            d = fivedigitFreq3_imana('BAYES_bf','type',type,'roi',r,'glm',glm,'disLevel',disLevel,'freqPair',[2,3,5],'squareroot',squareroot,'sn',sn);
            if r==16 | r==24
                d = fivedigitFreq3_imana('BAYES_bf','type',type,'roi',r,'glm',glm,'disLevel',disLevel,'freqPair',[5],'squareroot',squareroot,'sn',sn);
                d.roi = ones(size(d.roi)).*16;
            end
            D = addstruct(D,d);
        end
        % plot styling
        xlabs1 = {};
        xlabs2 = xlabs1;
        for i = 1:length(disLevel)
            xlabs1{end+1} = sprintf('%0.2f',disLevel(i));
            xlabs2{end+1} = sprintf('%0.3f',mean(D.meanD(D.disLevel==disLevel(i))));
            D.meanD(D.disLevel==disLevel(i)) = mean(D.meanD(D.disLevel==disLevel(i)));
        end
        % plot
        if isempty(fig); figure('Color',[1 1 1]); else; fig; end
        sty = style.custom({[0 0 0],[0 0.75 0],[0.3 0.8 0.8]});
        sty.general.markersize = 4;
        hold on;
        xlim([-1,-0.86]);
        % add evidence cutoff lines according to Kass & Raftery 1995
        drawline(0,'dir','horz','color',[0.7 0 0]);
        drawline(2,'dir','horz','color',[0.7 0 0],'linestyle',':');  % log BF of 1 ~ BF of 3
        drawline(6,'dir','horz','color',[0.7 0 0],'linestyle',':');  % log BF of 3 ~ BF of 20
        drawline(-2,'dir','horz','color',[0.7 0 0],'linestyle',':');
        % plot the Kass & Raftery (1995) 2*log(B) scale, then re-write
        % ylabels according to real log values
        plt.line(-D.meanD,D.KRlogbfnull,'split',D.roi,'style',sty);
        plt.set('xtick',[-1:0.02:-0.84],'xticklabel',{'1','0.98','0.96','0.94','0.92','0.90','0.88','0.86','0.84'},'xticklabelrotation',45);
        plt.set('ytick',[-6:2:12],'yticklabel',{'20','8','3','0','3','8','20','55','150','400'});
        ylim([-6 12]);
        xlim([-1,-0.86]);
        
        %plt.set('xticklabel',xlabs2,'xticklabelrotation',45);
        plt.labels('rescaled cross-freq corrN','bayes factor','RDM stability');
        plt.legend('northwest',{'S1','M1','V1/V2'});
        varargout = {D};    
    case 'Fig_BFvsActivityDifference'
        % Plots bayes factors for one roi.
        % Plots are split by differences in frequency (and thus activity).
        % splits: 3 fq. diff (1:4), 2 fq. diff (1:3,2:4), 1 fq. diff (1:2,2:3,3:4)
        % plotting is done by switching signs (from pos to
        % negative) for stylistic purposes.
        
        sn   = 10:17;%[10,12:17];
        glm  = 3;
        roi  = 12;
        type = 'corrN'; % or 'corr' DON'T CHANGE
        fig  = [];
        disLevel = [0:0.01:0.6]; % distortion levels
        squareroot = 0; % don't take ssqrt of rdms DON'T CHANGE
        plotMean = 1;
        vararginoptions(varargin,{'disLevel','fig','roi','plotMean'});
        
        if length(roi)>1; error('too many rois for case. only 1, please.'); end
        
        D = [];
        pairs = {[3],[2,5],[1,4,6]};
        for i = 1:3
            % Calculate BF across pairs (group-BF test)
            d = fivedigitFreq3_imana('BAYES_bf','type',type,'roi',roi,'glm',glm,'disLevel',disLevel,'freqPair',pairs{i},'squareroot',squareroot,'sn',sn);
            d.split = ones(size(d.roi)).*i;
            D = addstruct(D,d);
        end
        % plot styling
        xlabs1 = {};
        xlabs2 = xlabs1;
        for i = 1:length(disLevel)
            xlabs1{end+1} = sprintf('%0.2f',disLevel(i));
            xlabs2{end+1} = sprintf('%0.3f',mean(D.meanD(D.disLevel==disLevel(i))));
            D.meanD(D.disLevel==disLevel(i)) = mean(D.meanD(D.disLevel==disLevel(i)));
        end
        % plot
        if isempty(fig); figure('Color',[1 1 1]); else; fig; end
        %sty = style.custom({[0 0 0],[0 0.75 0],[0.3 0.8 0.8]});
        clrs = {[0.6 0.6 0.6],[0.3 0.3 0.3],[0 0 0]};
        sty = style.custom(clrs);
        sty.general.markersize = 4;
        hold on;
        xlim([-1,-0.86]);
        % add evidence cutoff lines according to Kass & Raftery 1995
        drawline(0,'dir','horz','color',[0.7 0 0]);
        drawline(2,'dir','horz','color',[0.7 0 0],'linestyle',':');  % log BF of 1 ~ BF of 3
        drawline(6,'dir','horz','color',[0.7 0 0],'linestyle',':');  % log BF of 3 ~ BF of 20
        drawline(-2,'dir','horz','color',[0.7 0 0],'linestyle',':');
        drawline(-6,'dir','horz','color',[0.7 0 0],'linestyle',':');
        % plot the Kass & Raftery (1995) 2*log(B) scale, then re-write
        % ylabels according to real log values
        plt.line(-D.meanD,D.KRlogbfnull,'split',D.split,'style',sty);
        plt.set('xtick',[-1:0.02:-0.84],'xticklabel',{'1','0.98','0.96','0.94','0.92','0.90','0.88','0.86','0.84'},'xticklabelrotation',45);
        plt.set('ytick',[-12:2:12],'yticklabel',{'400','150','55','20','8','3','0','3','8','20','55','150','400'});
        ylim([-12 12]);
        xlim([-1,-0.86]);
        
        %plt.set('xticklabel',xlabs2,'xticklabelrotation',45);
        plt.labels('rescaled cross-freq corrN','bayes factor',sprintf('%s RDM stability',reg_title{roi}));
        plt.legend('southeast',{'3 freq diff','2 freq diff','1 freq diff'});
        
        if plotMean
            for i =1:3
                plot(-mean(D.ratioN(D.split==i)),-6,'d','Color',clrs{i});
            end
        end
        
        varargout = {D};    
    case 'Fig_BFvsActMultiROI'
        roi = [12,11,24];
        disLevel = [0:0.01:0.9];
        figure('Color',[1 1 1]);
        D = [];
        for i = 1:3
            subplot(1,3,i);
            d = fivedigitFreq3_imana('Fig_BFvsActivityDifference','roi',roi(i),'fig',gca,'disLevel',disLevel);
            D = addstruct(D,d);
        end
        varargout = {D};
        
    case '0' % ------------ NeuroImage PCM Paper- PCM, Figure, and Stats cases
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -       
    case '0' % PCM: PCM model fitting. Expand for more info.
        % The PCM cases fit pattern-component models to subjects' roi data.
        %
        %       'PCM_fitGroup'   :  Fit at the group level (obtain 
        %                            crossvalidated fits)
        %       'PCM_fitSubject' :  Fit at the single subject level 
        %
        % You can plot results in cases found in 'FIG'
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    case 'PCM_GroupFit'                                                     % Fit CV group models- Pattern component modeling
        glm = 3;            % glm is glm #
        sn  = 10:17;        % default is to include all subjects
        roi = 12;           % default primary motor cortex
        layer = 1;          % what voxels are we including in modeling?
        vararginoptions(varargin,{'roi','glm','sn','layer'});
        % change current path to appropriate PCM toolbox version
        % addpath('/Users/sarbuckle/Documents/MotorControl/matlab/pcm_toolbox-master');
        if length(roi)>1; error('PCM case only fits one roi at a time.'); end
        
        switch layer
            case 'all'
                L=1;
            case 'superficial'
                L=2;
            case 'deep'
                L=3;
        end

        % load files
        T = load(fullfile(regDir,sprintf('glm%d_reg_betas.mat',glm))); % region stats (T)
        T = getrow(T,T.region==roi);
        fprintf('\nSN \t #Voxels\n-----------------\n'); 
        % prep inputs for PCM modelling functions
        for s = sn
            % get subject's data (and select voxels in layer)
            Ts              = getrow(T,T.SN==s);
            L_indx          = (Ts.depth{1} > layers{layer}(1)) & (Ts.depth{1} < layers{layer}(2)); % index of voxels for layer depth
            betaW           = Ts.betaW{1}(:,L_indx); 
            % get subject's partitions and second moment matrix
            D               = load(fullfile(glmDir{glm}, subj_name{s}, 'SPM_info.mat'));   % load subject's trial structure
            N               = length(D.run);
            i               = s-(min(sn)-1);
            Y{i}            = betaW(1:N,:);
            conditionVec{i} = D.tt;
            partitionVec{i} = D.run;
            G_hat(:,:,i)    = pcm_estGCrossval(Y{i},partitionVec{i},conditionVec{i});
            numVox(i)       = size(betaW,2);
            % print to command window
            fprintf('%d \t %d\n',s,size(betaW,2));
        end;
        fprintf('\n');

        % Get the starting values for the finger structure from the highest
        % speed
        G_mean                = mean(G_hat,3);
        [Fx0,Greg,scaleParam] = pcm_modelpred_free_startingval(G_mean([16:20],[16:20])); % scales Fx0 by default
        scale_vals            = [log(0.30); log(0.62); log(0.85)];
        add_vals              = [log(0.2);  log(0.62); log(1)];
        
        % Null model- all distances equal
        M{1}.type       = 'nonlinear'; 
        M{1}.modelpred  = @fdf2_modelpred_null;
        M{1}.fitAlgorithm = 'minimize'; 
        M{1}.numGparams = 1;
        M{1}.theta0     = 0.3;
        M{1}.name       = 'Null';
        
        % Scaling model- distances multiplied by constant scaler dependent
        % on movement force
        M{2}.type       = 'nonlinear'; 
        M{2}.modelpred  = @fdf2_modelpred_scale;
        M{2}.fitAlgorithm = 'minimize'; 
        M{2}.numGparams = 17;
        M{2}.theta0     = [Fx0;scale_vals];   % Scale values
        M{2}.name       = 'Scaling';
        
        % Additive independent model- adds independent pattern (NOT mean
        % pattern) that scales with pressing frequency/BOLD activity
        M{3}.type       = 'nonlinear'; 
        M{3}.modelpred  = @fdf2_modelpred_add;
        M{3}.fitAlgorithm = 'minimize'; 
        M{3}.numGparams = 17;
        M{3}.theta0     = [Fx0;add_vals];   % Scale values
        M{3}.name       = 'Additive';
        
        % Additive independent + Scaling model combo
        M{4}.type       = 'nonlinear'; 
        M{4}.modelpred  = @fdf2_modelpred_addsc;
        M{4}.fitAlgorithm = 'minimize'; 
        M{4}.numGparams = 20;
        M{4}.theta0     = [Fx0;scale_vals;add_vals];   % Scale values
        M{4}.name       = 'Combination';
        
        % Naive averaring model- noise ceiling method 1- totall free model
        M{5}.type       = 'freechol';  
        M{5}.numCond    = 20;
        M{5}.name       = 'noiseceiling';
        M{5}            = pcm_prepFreeModel(M{5});
        
        [Ti,theta_hat_nocv,G_pred] = pcm_fitModelGroup(Y,M,partitionVec,conditionVec,'isCheckDeriv',0);
        [Tg,theta_hat_cv,G_predCV] = pcm_fitModelGroupCrossval(Y,M,partitionVec,conditionVec,'isCheckDeriv',0);
        % keyboard
        
        % to plot:
        % pcm_plotModelLikelihood(Tg,M,'upperceil',Ti.likelihood(:,5),'style','dot')
         save(fullfile(regDir,sprintf('pcm_group_fit_reg%d_L%d_glm%d.mat',roi,layer,glm)),...
             'Ti','Tg','theta_hat_cv','theta_hat_nocv','G_hat','G_pred','G_predCV','M');
    case 'PCM_IndividFit'                                                   % Fit CV individ models- Pattern component modeling
        glm = 3;            % glm is glm #
        sn  = 10:17;        % default is to include all subjects
        roi = 12;           % default primary motor cortex
        layer = 1;          % what voxels are we including in modeling?
        vararginoptions(varargin,{'roi','glm','sn','layer'});
        % change current path to appropriate PCM toolbox version
        % addpath('/Users/sarbuckle/Documents/MotorControl/matlab/pcm_toolbox-master');
        
        switch layer
            case 'all'
                L=1;
            case 'superficial'
                L=2;
            case 'deep'
                L=3;
        end

        % load files
        T = load(fullfile(regDir,sprintf('glm%d_reg_betas.mat',glm))); % region stats (T)
        T = getrow(T,T.region==roi);
        fprintf('\nSN \t #Voxels\n-----------------\n'); 
        % prep inputs for PCM modelling functions
        for s = sn
            % get subject's data (and select voxels in layer)
            Ts              = getrow(T,T.SN==s);
            L_indx          = (Ts.depth{1} > layers{layer}(1)) & (Ts.depth{1} < layers{layer}(2)); % index of voxels for layer depth
            betaW           = Ts.betaW{1}(:,L_indx); 
            % get subject's partitions and second moment matrix
            D               = load(fullfile(glmDir{glm}, subj_name{s}, 'SPM_info.mat'));   % load subject's trial structure
            N               = length(D.run);
            i               = s-(min(sn)-1);
            Y{i}            = betaW(1:N,:);
            conditionVec{i} = D.tt;
            partitionVec{i} = D.run;
            G_hat(:,:,i)    = pcm_estGCrossval(Y{i},partitionVec{i},conditionVec{i});
            numVox(i)       = size(betaW,2);
            % print to command window
            fprintf('%d \t %d\n',s,size(betaW,2));
        end;
        fprintf('\n');

        % Get the starting values for the finger structure from the highest
        % speed
        G_mean                = mean(G_hat,3);
        [Fx0,Greg,scaleParam] = pcm_modelpred_free_startingval(G_mean([16:20],[16:20])); % scales Fx0 by default
        scale_vals            = [log(0.30); log(0.62); log(0.85)];
        add_vals              = [log(0.2);  log(0.62); log(1)];
        
        % Null model- all distances equal
        M{1}.type       = 'nonlinear'; 
        M{1}.modelpred  = @fdf2_modelpred_null;
        M{1}.numGparams = 1;
        M{1}.theta0     = 0.3;
        M{1}.name       = 'Null';
        
        % Scaling model- distances multiplied by constant scaler dependent
        % on pressing frequency/BOLD activity
        M{2}.type       = 'nonlinear'; 
        M{2}.modelpred  = @fdf2_modelpred_scale;
        M{2}.numGparams = 17;
        M{2}.theta0     = [Fx0;scale_vals];   % Scale values
        M{2}.name       = 'Scaling';
        
        % Additive independent model- adds independent pattern (NOT mean
        % pattern) that scales with pressing frequency/BOLD activity
        M{3}.type       = 'nonlinear'; 
        M{3}.modelpred  = @fdf2_modelpred_add;
        M{3}.numGparams = 17;
        M{3}.theta0     = [Fx0;add_vals];   % Scale values
        M{3}.name       = 'Additive';
        
        % Additive independent + Scaling model combo
        M{4}.type       = 'nonlinear'; 
        M{4}.modelpred  = @fdf2_modelpred_addsc;
        M{4}.numGparams = 20;
        M{4}.theta0     = [Fx0;scale_vals;add_vals];   % Scale values
        M{4}.name       = 'Combination';
        
        % Naive averaring model- noise ceiling method 1- totall free model
        M{5}.type       = 'noiseceiling';         
        M{5}.numGparams = 0;
        M{5}.theta0     = [];
        M{5}.name       = 'noiseceiling';
        
        [Ti_nocv,theta_hat_nocv,G_pred] = pcm_fitModelIndivid(Y,M,partitionVec,conditionVec,'isCheckDeriv',0);
        [Ti_cv,theta_hat_cv,G_predCV] = pcm_fitModelIndividCrossval(Y,M,partitionVec,conditionVec);
        % keyboard
        
        % to plot:
        % pcm_plotModelLikelihood(Tg,M,'upperceil',Ti.likelihood(:,5),'style','dot')
         save(fullfile(regDir,sprintf('pcm_individ_fit_reg%d_L%d_glm%d.mat',roi,layer,glm)),...
             'Ti_nocv','Ti_cv','theta_hat_cv','theta_hat_nocv','G_hat','G_pred','G_predCV','M');
    case '0' % Make first-pass versions of paper figures.
    case 'FIG_pcmGroupFits'                                                 % NeuroImage PCM paper figure
        roi   = 12;
        sn    = 10:17;
        glm   = 3;
        layer = 1;
        vararginoptions(varargin,{'roi','glm','sn','layer','errorfcn'});
        load(fullfile(regDir,sprintf('pcm_group_fit_reg%d_L%d_glm%d.mat',roi,layer,glm)));
        %figure('Color',[1 1 1],'Name',reg_title{roi});
        T = pcm_plotModelLikelihood(Tg,M,'upperceil',Ti.likelihood(:,5),'style','bar','fig',gca);
        keyboard
        %ttest(T.likelihood_norm(:,5),T.likelihood_norm(:,4),1,'paired'); % test combo model vs lower noise ceiling
    case 'FIG_ModelStructures'                                              % NeuroImage PCM paper figure: plots observed and model pred Gs and their representational structures
        % Figure of observed and model predicted G, and MDS of rep
        % structures for observed data and 3 models
        glm = 3;
        roi = 12;
        titles = {'Empirical','Scaling','Additive','Combination'};
        vararginoptions(varargin,{'roi','glm','titles'});

        speed = kron([1:4]',ones(5,1)); 
        digit = kron(ones(4,1),[1:5]'); 
        
        % load model fit from layer
        load(fullfile(regDir,sprintf('pcm_group_fit_reg%d_L%d_glm%d.mat',roi,1,glm)));

        % Scale the mean G-matrices to the same scale 
        G{1} = mean(G_hat,3);         % empirical 
        % scaling:
        sc   = repmat(reshape(Tg.scale(:,2),1,1,size(G_predCV{2},3)),20,20); % subject scaling params
        G{2} = mean(G_predCV{2}.*sc,3);  
        % additive independent:
        sc   = repmat(reshape(Tg.scale(:,3),1,1,size(G_predCV{3},3)),20,20); 
        G{3} = mean(G_predCV{3}.*sc,3);  
        % combination:
        sc   = repmat(reshape(Tg.scale(:,4),1,1,size(G_predCV{4},3)),20,20); 
        G{4} = mean(G_predCV{4}.*sc,3);  

        % Now plot the matrices
        figure;
        numDim    = 20; % Number of dimensions to consider in procrustes alignment
        Yall      = zeros(21,numDim,3);
        numModels = size(G,2);

        for i = 1:numModels
            Q = subplot(3,numModels,i);
            imagesc(G{i},[0 0.04]); % Forced scaling
            axis equal;
            set(gca,'XTick',[],'YTick',[]);
            title(titles{i});
            dim = get(Q,'Position');
            set(Q,'Position',[dim(1) dim(2) dim(3)*1.25 dim(4)*1.25]);
            
            Y = rsa_classicalMDS(G{i},'mode','IPM');
            if i==1 % MDS of empirical data
                Yall(1:20,1:numDim,i) = Y(:,1:numDim);
            else % MDS of model predicted G- rotate to align to empirical fit
                Yall(1:20,1:numDim,i) = Y(:,1:numDim);
                [D,Z,Transform]       = procrustes(Yall(:,:,1),Yall(:,:,i),'Scaling',false);
                Yall(:,1:numDim,i)    = Yall(:,1:numDim,i)*Transform.T;
            end;
            
            subplot(3,numModels,i+numModels);
            fivedigitFreq3_imana('scatterplotMDS',Yall(1:20,1:3,i),speed,digit);
            set(gca,'XLim',[0 0.28],'YLim',[-0.1 0.15],'ZLim',[-0.08 0.1],'view',[-81.6 2.8],...
                'XTick',[0:0.05:0.25],'YTick',[-0.10:0.05:0.20],'ZTick',[-0.1:0.05:0.1],...
                'YTickLabel',[],'XTickLabel',[],'ZTickLabel',[]);
            
            subplot(3,numModels,i+numModels*2);
            fivedigitFreq3_imana('scatterplotMDS',Yall(1:20,1:3,i),speed,digit);
            set(gca,'XLim',[0 0.28],'YLim',[-0.1 0.15],'ZLim',[-0.08 0.1],'view',[-14.6 12.8],...
                'XTick',[0:0.05:0.25],'YTick',[-0.10:0.05:0.20],'ZTick',[-0.1:0.05:0.1],...
                'YTickLabel',[],'XTickLabel',[],'ZTickLabel',[]);
            zoom(1.35) % force zoom- maybe not the best solution...
            
        end; % for each model
        set(gcf,'Color',[1 1 1],'PaperPositionMode','manual','PaperPosition',[2 2 18 11]);
        wysiwyg; 
    
        
        
        
    case '0' % - - - - - E X T R A   A N A L Y S I S   C A S E S - - - - -

    case '0' % ------------ FIG: figure, plotting, and sometimes stats. ---
        % The FIG cases usually harvest some data from ROI stats structures.
        % Sometimes they also do stats (since the data is harvested
        % accordingly).
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    case 'FIG_behaviour'                                                    % plot # of presses, avg. force, and avg. time between presses across subjects
    % harvest pressing force data for each trial
        sn       = 10:17;
        vararginoptions(varargin,{'sn'});
        
        T = [];
        for s = sn;
            load(fullfile(behavDir,sprintf('fdf3_forces_s%02d.mat',s)));
            D.sn = ones(length(D.BN),1).*s;
            T = addstruct(T,D);
        end     
        T = tapply(T,{'digit','sn','numPresses'},...
            {'goodPresses','nanmean(x)'},...
            {'avrgPeakHeight','nanmean(x)'},...
            {'avgTimeBTPeaks','nanmean(x)'});    
         
        % convert numpresses to pressing frequencies
        T.cuedFreq = T.numPresses./6;    % 6sec is pressing phase
        T.behaFreq = T.goodPresses./6;
        
        % now plot
        style.use('4speedsMarkers');
        figure('Color',[1 1 1]);
        % plot pressing frequency
        subplot(1,3,1);
        plt.line(T.digit,T.behaFreq,'split',T.cuedFreq);
        ylim([0 3]);
        plt.legend('north',{'0.3Hz','0.6Hz','1.3Hz','2.6Hz'});
        plt.labels('digit','pressing freq. (Hz)');
        % plot digit forces
        subplot(1,3,2);
        plt.line(T.digit,T.avrgPeakHeight,'split',T.cuedFreq);
        ylim([2 4]);
        plt.legend('north',{'0.3Hz','0.6Hz','1.3Hz','2.6Hz'});
        plt.labels('digit','pressing force (N)');
        % plot time b/t presses
        subplot(1,3,3);
        plt.line(T.digit,T.avgTimeBTPeaks,'split',T.cuedFreq);
        plt.legend('north',{'0.3Hz','0.6Hz','1.3Hz','2.6Hz'});
        plt.labels('digit','time between presses (ms)');
       
        % Stats
        % anovaMixed(T.avrgPeakHeight,T.SN,'within',[T.digit,T.cuedFreq],{'digit','freq'})
        %keyboard         
    case 'FIG_ROIstats'                                                     % plot avg (adjusted) activity and avg sqrt(LDC) for rois  
        % plots average distances and activities for specified rois
        % Avg. activity is average betas within speed in that roi
        % Avg. dist is avg LDCs between fingers for each speed, NOT from
        % rest.
        % Shaded regions are stderr across subjects.
        % enter roi = 0 to average across all rois
        roi   = [11,12,16];
        sn    = 10:17;
        glm   = 3;
        layer = 1;
        fig   = [];
        errorfcn = 'stderr'; % error fcn for shaded patch on plot
        
        vararginoptions(varargin,{'roi','glm','sn','layer','errorfcn','fig'});
        
        % formatting options
        CAT.linecolor  = {[0.1 0.1 0.1],[0.4 0.4 0.4],[0.7 0.7 0.7]}; 
        CAT.patchcolor = {[0.1 0.1 0.1],[0.4 0.4 0.4],[0.7 0.7 0.7]};
        CAT.markercolor  = {[0.1 0.1 0.1],[0.4 0.4 0.4],[0.7 0.7 0.7]}; 
        CAT.linewidth  = 1.75;
        CAT.marker     = 'o';
        CAT.markersize = 8;
        Freq        = [2,4,8,16];%log([2,4,8,16]);

        % load appropriate file and get rows for subjs and roi
        D = load(fullfile(regDir,sprintf('glm%d_reg_Tspeed.mat',glm)));
        %D = load(fullfile(regDir,sprintf('glm%d_reg_Tspeed_noMeanSpeedPattern.mat',glm)));
        D = getrow(D,D.layer==layer);
        
        % % HARVEST - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % harvest activities into NumSubj x NumSpeeds matrix
        R_act = [];
        R_ldc = [];
       % split = [];
        speed = [];
        for r=1:length(roi)
            if ~roi(r)==16 % if V12, avg. across hemis
                Dr = getrow(D,D.region==roi(r));
            else
                Dr = getrow(D,D.region==16 | D.region==34);
            end
            for j=1:length(sn)                          % for each subject...
                s = sn(j);
                d = getrow(Dr,Dr.SN==s);
                R_act(end+1,:) = d.act';                % harvest avg activity
                R_ldc(end+1,:) = mean(ssqrt(d.RDM),2)'; % harvest avg sqrt LDC
                %R_ldc(end+1,:) = mean((d.RDM),2)';
                %split(end+1,1) = r;                     % make split vector
                speed(end+1,:) = d.speed;
            end
            leg{r} = reg_title{roi(r)};                 % update legend array  
        end
        
        % % PLOT - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        if isempty(fig) % check if we are plotting to already existing figure
            figure('Color',[1 1 1]);
        else
            fig;
        end
        %set(gcf,'InvertHardcopy','off'); % allows save function to save pic w/ current background colour (not default to white)
        
        % plot avg betas
        subplot(1,2,1);
        hold on
        traceplot(Freq,R_act,'split',split,'leg',leg,'errorfcn',errorfcn,'CAT',CAT);
        set(gca,'XTick',Freq,'XTickLabel',{'2','4','8','16'});
        ylabel('avg non-whitened betas (a.u.)');
        xlabel('num presses');
        drawline(0,'dir','horz');
        hold off
        
        % plot avg ldcs
        subplot(1,2,2);
        hold on
        traceplot(Freq,R_ldc,'split',split,'leg',leg,'errorfcn',errorfcn,'CAT',CAT);
        set(gca,'XTick',Freq,'XTickLabel',{'2','4','8','16'});
        ylabel('avg LDC');
        xlabel('num presses');
        hold off

        wysiwyg;   
    case 'FIG_pattern_reliability'                                          % plot w/in subj, w/in speed rdm reliability (Across two partitions), compare with across-speed correlations. Insights into RSA stability    
        % Splits data for each session into two partitions (even and odd runs).
        % Calculates correlation coefficients between each condition pair 
        % between all partitions.
        % Default setup includes subtraction of each partition's mean
        % activity pattern (across conditions).
        % Conducts ttest comparing correlations within-conditions (within
        % subject) to those between-conditions (across subject). If stable,
        % within-condition corrs should be significantly larger than those
        % between.
        % Finally, plots within-condition correlations. Shaded region
        % reflects stderr across subjects.
        glm = 3;
        roi = 11; % default primary motor cortex
        sn  = 10:17;
        fig = [];
        remove_mean = 1; % subtract 
        partitions = [1:2:7; 2:2:8];
        numRuns    = 1:8;
        numConds   = 1:20;
        % Correlate patterns across even-odd run splits within subjects.
        % Does correlation across all depths.
        vararginoptions(varargin,{'roi','glm','fig','sn','remove_mean'});
        
        T   = load(fullfile(regDir,sprintf('glm%d_reg_betas.mat',glm)));      
        T   = getrow(T,T.region==roi);

        splitcorrs = [];
        conds   = repmat([numConds],1,length(numRuns));
        runNums = kron([numRuns],ones(1,length(numConds)));
        sindx = 0;
        
        for s = sn % for each subject
            D = load(fullfile(glmDir{glm}, subj_name{s}, 'SPM_info.mat')); % load subject's trial structure
            t = getrow(T,T.SN==s & T.region==roi);
            betaW = t.betaW{1};
            % remove run mean?
            if remove_mean
                for i = unique(D.run)'
                    idx = logical(D.run==i);
                    betaW(idx,:) = bsxfun(@minus,betaW(idx,:),mean(betaW(idx,:),1));
                end
            end
            sindx = sindx + 1;
            prepBetas = [];
            % avwerage betas according to partition splits
            for i = 1:size(partitions,1)
                partitionIdx = logical(ismember(runNums,partitions(i,:)))';
                condIdx(:,i) = conds(partitionIdx);
                prepBetas(:,:,i) = betaW(partitionIdx,:);
            end
            % correlate patterns across partitions, both within and across
            % conditions
            for c1 = numConds % for each condition
                % condition mean activity pattern for this run partition
                oddCon   = condIdx(:,1)==c1;
                oddBetas = mean(prepBetas(oddCon,:,1)); 
                for c2 = numConds % for each condition
                    % condition mean activity pattern for the other run partition
                    evenCon   = condIdx(:,2)==c2;
                    evenBetas = mean(prepBetas(evenCon,:,2)); 
                    % correlate condition patterns across partitions and
                    % harvest into correlation matrix
                    tmp = corrcoef(evenBetas,oddBetas);
                    splitcorrs(c1,c2,sindx) = tmp(1,2);
                end
            end
        end
        
        % within-condition correlations
        within  = arrayfun(@(i) diag(splitcorrs(:,:,i)),1:size(splitcorrs,3),'uni',false)';
        within  = cat(2,within{:})';
        % between-condtion correlations
        offdiagIdx = logical(triu(ones(length(numConds)),1));
        offdiagIdx = offdiagIdx(:);
        offdiagIdx = repmat(offdiagIdx,length(sn),1);
        all_corrs  = splitcorrs(:);
        between    = all_corrs(offdiagIdx);
        
        % ttest within vs between condition reliability correlations
        ttest(within',between,1,'independent');
        
        % plot within-condition correlations (error across subjects)
        if isempty(fig)
            figure('Color',[1 1 1]);
            traceplot(numConds,within,'errorfcn','stderr');
            ylabel('correlation (corrcoef) of partition avg. patterns');
            xlabel('condition number');
            legend({reg_title{roi}});
            title({reg_title{roi}});
            ylim([0 1]);
            xlim([0.5 max(numConds)+0.5]);
        else
            fig;
            hold on
            traceplot(numConds,within,'errorfcn','stderr');
            hold off
        end
        
        
        
        varargout = {splitcorrs};
    case 'FIG_singleRDM'                                                    % Lower triangular RDM for one speed. Subplots for different ROIs. 
        roi   = 12;
        sn    = 10:17;  % select which subjs to include- RDM will be avgd if >1 subj included
        glm   = 3;
        layer = 1;      % select the voxel depth for which the RDM will be plotted
        speed = 3;      % select the speed condition for which the RDM will be plotted
        fig   = [];
        clrlim= [];
        vararginoptions(varargin,{'roi','glm','sn','layer','errorfcn','speed','fig','clrlim'});
        
        % load data
        D = load(fullfile(regDir,sprintf('glm%d_reg_Tspeed.mat',glm)));
        % get RDMs for layer & speed
        D = getrow(D,D.layer==layer & D.speed==speed);
        % harvesting for specific subjects
        T = [];
        for s = sn
            t = getrow(D,D.SN==s);
            T = addstruct(T,t);
        end
        D = T; clear T;
        
        % set upper colorscale limit across rois (if >1 roi)
%         roi_max = [];
%         for r = roi
%             d = getrow(D,D.region==r);
%             roi_max(end+1) = max(max(mean(ssqrt(d.RDM,1))));
%         end
%         cmax = max(roi_max); 
        
        % loop through ROIs & plot subplot RDM for each roi
        if isempty(fig)
            figure('Color',[1 1 1],'Name',['speed ' num2str(speed)]);
        else
            fig;
        end
        color = get(gcf,'Color');
        for i = 1:length(roi)
            r = roi(i);
            if roi==6 | roi==24 
                d = getrow(D,D.region==6 | D.region==24);
                d = tapply(D,{'SN','speed'},{'RDM','mean'});
            else
                d = getrow(D,D.region==r);
            end
            % rescale distances to max dist per subj
            d.RDM = bsxfun(@rdivide,d.RDM,max(d.RDM,[],2));
            % plot
            %subplot(length(roi),1,i);
            %imagesc(tril(rsa_squareRDM(mean(d.RDM,1))));%,[0 cmax]);
            idx = tril(ones(5));
            %l_RDM = tril(rsa_squareRDM(mean(ssqrt(d.RDM),1)));
            l_RDM = tril(rsa_squareRDM(mean(d.RDM,1)));
            l_RDM(idx==0) = nan;
            patchimg(l_RDM,'scale',clrlim);
            %colormap bone
            %colormap hot
            title(reg_title{r});
            xlim([0 5]);
            ylim([0 5]);
            %axis equal
            
            ax = get(gca);
            if (roi~=6 && roi~=24)
                set(gca,'XTick',[0.5:4.5],'XTickLabel',{'1','2','3','4','5'});
                set(gca,'YTick',[0.5:4.5],'YTickLabel',{'1','2','3','4','5'});
            else
                set(gca,'XTick',[0.5:4.5],'XTickLabel',{'E','I','M','F','J'});
                set(gca,'YTick',[0.5:4.5],'YTickLabel',{'E','I','M','F','J'});
            end
        end
    case 'FIG_digitPSC'                                                     % Plots % signal change for each digit for multiple glms
        % Plots % signal change for each digit.
        % Subplots are for each roi.
        % Outputs the plotting structure for further analysis.
        sn    = 10:17;
        roi   = 12;
        glm   = 3;
        vararginoptions(varargin,{'sn','roi','glm'});
        
        % error handling
        if length(roi)>1; error('case cannot handle >1 roi'); end
        
        P = []; % output structure
        
        figure('Color',[1 1 1]);
        j = 1;
        for g = glm
            plt.subplot(1,length(glm),j);
            p = fivedigitFreq3_imana('FIG_digitPSC_singleROI_singleGLM','sn',sn,'roi',roi,'glm',g,'fig',gca);
            P = addstruct(P,p);
            j = j+1;
        end
        plt.match('y');
        varargout = {P};
    case 'FIG_digitPSC_singleROI_singleGLM'                                 % Plots % signal change for each digit for ONE roi for ONE glm
        % plots average of betas across voxels from ROI for each finger,
        % split by trial type
        sn    = 10:17;
        roi   = 12;
        glm   = 3;
        fig   = [];
        vararginoptions(varargin,{'sn','roi','fig','glm'});
        
        % error handling
        if length(roi)>1; error('Can only plot PSC from one roi at a time'); end

        P = []; % plotting structure
        
        T = load(fullfile(regDir,sprintf('glm%d_reg_Toverall.mat',glm))); % loads structure To from case 'ROI_stats'
        % Harvest and arrange data to plot
        T = getrow(T,T.region==roi & ismember(T.SN,sn)); % get rows of stats structure that correspond to desired layer
        v  = ones(5,1);
        for i = 1:length(T.SN)
            p.psc   = T.psc(i,:)';
            p.digit = [1:5]';
            p.sn    = v.*T.SN(i);
            p.roi   = v.*T.region(i);
            P = addstruct(P,p);
        end
        
        % Plot
        leg = {};
        for s = sn; leg{end+1} = subj_name{s}; end
        if isempty(fig); figure('Color',[1 1 1]); else fig; end % check figure space 
        % get plotting colours
        numShades = length(sn);
        shades    = plt.helper.get_shades(numShades,'gray','decrease',10);
        sty       = style.custom(shades);
        plt.line(P.digit,P.psc,'split',P.sn,'subset',logical(P.roi==roi),'style',sty);
        plt.labels('finger','percent signal change',sprintf('%s glm %d  .',regname{roi},glm));
        plt.legend('northeast',leg);
        drawline(0,'dir','horz');
        % output to user
        varargout = {P};
    case 'FIG_multipleRoiRDMs'
        % plots rescaled distances for each freq for specified rois, avg.
        % across subjects.
        % rescales each subject's RDM by the max distance, so 
        clrlim = {[0 0.04],[0 0.03],[0 0.05]};
        freq = {'0.3Hz','0.6Hz','1.3Hz','2.6Hz'};
        sn = [10:17];
        roi = [11,12,24];
        %roi = 12;
        reg_titles = {'S1','M1','V1/V2'};
        %reg_titles = {'M1'};
        jj = 1; % subplot ticker
        figure('Color',[1 1 1]);
        for rr = 1:length(roi);
            r = roi(rr);
            % plot rdms for each freq.- one row=one roi
            for spd = 1:4
                subplot(length(roi),5,jj)
                %fivedigitFreq3_imana('FIG_singleRDM','sn',sn,'glm',3,'layer',1,'roi',r,'speed',spd,'fig',gca,'clrlim',clrlim{rr});
                fivedigitFreq3_imana('FIG_singleRDM','sn',sn,'glm',3,'layer',1,'roi',r,'speed',spd,'fig',gca);
                % add title
                if spd~=1
                   title(sprintf('%s',freq{spd}));
                else
                    title(sprintf('%s %s',reg_titles{rr},freq{spd}));
                end
                % update suplot counter
                jj = jj+1; 
            end
            jj = jj+1; 
        end
        
    case '0' % ------------ Cases in dev, depreciated, or not pertinant to main analyses
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -      
    case 'FIG_rdm_reliability_btSubj'
        % split-half correlations of RDM for each subject. 
        % RDMs include all 20 conds.
        % Dissimilarities are calculated for each partition without
        % crossvalidation (distance_euclidean).
        glm     = 3;
        roi     = 12; % default primary motor cortex
        sn      = 10:17;
        speeds  = 1:4;
        fig     = [];
        % Correlate RDMs across speeds, BETWEEN subjects.
        % Does correlation across all depths.
        vararginoptions(varargin,{'roi','glm','sn','speeds','fig'});
        
        %T   = load(fullfile(regDir,sprintf('glm%d_reg_splithalf_Tspeed.mat',glm)));  
        T = load(fullfile(regDir,sprintf('glm%d_reg_Tspeed.mat',glm)));
        T   = getrow(T,T.region==roi & T.layer==1);
        % harvest for specific subjects
        B = [];
        for s = sn
            b = getrow(T,T.SN==s);
            B = addstruct(B,b);
        end
        T = B;
        clear b
        % prep output structures
        B   = [];
        W   = [];
        % loop through RDM speed pairs, correlate across subjects
        SN    = bsxfun(@times,T.SN,ones(1,length(T.SN))); 
        inSN  = (bsxfun(@eq,T.SN,T.SN'));      % which are for same subj?
        %R     = corrN(T.RDM');
        R     = corrN(T.RDM');
        pairIdx = rsa_squareRDM(1:6);
        % for each speed pair
        for i = 1:length(sn)
            s = sn(i); 
            for spd1 = 1:3
                for spd2 = speeds(spd1+1:end)
                    oppSp = bsxfun(@times,T.speed==spd2,T.speed'==spd1) | bsxfun(@times,T.speed==spd1,T.speed'==spd2); 
                    % harvest cross-speed, b/t subject correlations
                    b.corr      = R(SN==s & ~inSN & oppSp)';
                    b.SN        = s;
                    b.roi       = roi;
                    b.speedpair = [spd1,spd2];
                    b.pairIdx   = pairIdx(spd1,spd2);
                    B = addstruct(B,b);
                end
            end
            % harvest within-speed, across-subject correlations
            for spd = 1:4
                inSp    = bsxfun(@eq,T.speed==spd,T.speed'==spd);  % which are for same speed?
                inSp(T.speed~=spd,T.speed'~=spd) = 0;
                w.corr  = R(SN==s & ~inSN & inSp)';
                w.SN    = s;
                w.roi   = roi;
                w.speed = spd;
                W = addstruct(W,w);
            end
        end;
        % done correlations across subjects, between speed pairs
        
        % % now plot subject avgs.
        if isempty(fig)
            figure('Color',[1 1 1]);
        else
            fig;
        end
        pairclrs  = {[1 1 1],[0.2 0.2 1],[0.9 0.9 0],[0.5 0 0.6],[0 0.6 0],[0 0.6 0.6]};
        % plot BETWEEN-subjet-BETWEEN-speed-between-partition RDM correlations
        myboxplot(B.pairIdx,mean(B.corr,2),'plotall',0,'linecolor',[0 0 0],'xtickoff');
        hold on
        between = [];
        for i = 1:6
            h = plot(i,mean(B.corr(B.pairIdx==i,:),2),'LineStyle','none','MarkerSize',7,...
                'MarkerFaceColor',pairclrs{i},'MarkerEdgeColor','k','Marker','o');
            %hMarkers = h(1).MarkerHandle.get;  % a matlab.graphics.primitive.world.Marker object
            %hMarkers.FaceColorData = uint8(255*[pairclrs{i}';0.1]);  % Alpha=0.3 => 70% transparent 
            between(:,i) = mean(B.corr(B.pairIdx==i,:),2);
        end
        hold off
        title(reg_title{roi});
        set(gca,'XTickLabel',{'1:2','1:3','1:4','2:3','2:4','3:4'});
        xlabel('speed pair');
        ylim([0 1]);

        keyboard
        %anova1(mean(B.corr,2),B.pairIdx)
        %anova1(mean(W.corr,2),W.speed)
    case 'FIG_rdm_reliability_inSubjbtROI'
        % correlations of RDM for each subject b/t ROIs. 
        % RDMs include all 20 conds.
        % Dissimilarities are calculated for each partition without
        % crossvalidation (distance_euclidean).
        glm     = 3;
        roi     = [12,30]; % default primary motor cortex
        sn      = 10:17;
        speeds  = 1:4;
        fig     = [];
        % Correlate RDMs across speeds, BETWEEN subjects.
        % Does correlation across all depths.
        vararginoptions(varargin,{'roi','glm','sn','speeds','fig'});
        
        %T   = load(fullfile(regDir,sprintf('glm%d_reg_splithalf_Tspeed.mat',glm)));  
        T = load(fullfile(regDir,sprintf('glm%d_reg_Tspeed.mat',glm)));
        T   = getrow(T,(T.region==roi(1) | T.region==roi(2)) & T.layer==1);
        % harvest for specific subjects
        B = [];
        for s = sn
            b = getrow(T,T.SN==s);
            B = addstruct(B,b);
        end
        T = B;
        clear b
        % prep output structures
        B   = [];
        W   = [];
        % loop through RDM speed pairs, correlate across subjects
        SN    = bsxfun(@times,T.SN,ones(1,length(T.SN))); 
        inSN  = (bsxfun(@eq,T.SN,T.SN'));              % which are for same subj?
        inROI = (bsxfun(@eq,T.region,T.region'));      % which are for same roi?
        %R     = corrN(T.RDM');
        R     = corr(T.RDM');
        pairIdx = rsa_squareRDM(1:6);
        % for each speed pair
        for i = 1:length(sn)
            s = sn(i); 
            for spd1 = 1:3
                for spd2 = speeds(spd1+1:end)
                    oppSp = bsxfun(@times,T.speed==spd2,T.speed'==spd1) | bsxfun(@times,T.speed==spd1,T.speed'==spd2); 
                    % harvest cross-speed, b/t ROI within subject correlations
                    b.corr      = R(triu(SN==s & inSN & oppSp & ~inROI))';
                    b.SN        = s;
                    b.roi       = roi;
                    b.speedpair = [spd1,spd2];
                    b.pairIdx   = pairIdx(spd1,spd2);
                    B = addstruct(B,b);
                end
            end
            % harvest within-speed, within-subject, between ROI correlations
            for spd = 1:4
                inSp    = bsxfun(@eq,T.speed==spd,T.speed'==spd);  % which are for same speed?
                inSp(T.speed~=spd,T.speed'~=spd) = 0;
                w.corr  = R(triu(SN==s & inSN & inSp & ~inROI))';
                w.SN    = s;
                w.roi   = roi;
                w.speed = spd;
                W = addstruct(W,w);
            end
        end;
        % done correlations across subjects, between speed pairs
        
        % % now plot subject avgs.
        if isempty(fig)
            figure('Color',[1 1 1]);
        else
            fig;
        end
        speedclrs = {[0 0 0] [0.5 0 0] [0.9 0 0] [1 0.6 0]};
        pairclrs  = {[1 1 1],[0.2 0.2 1],[0.9 0.9 0],[0.5 0 0.6],[0 0.6 0],[0 0.6 0.6]};
        % plot within-subject-WITHIN-speed-between-partition RDM correlations
        subplot(1,2,1);
        myboxplot(W.speed,W.corr,'linecolor',[0 0 0],'xtickoff','plotall',0);
        hold on
        for i = speeds
            plot(i,W.corr(W.speed==i),'LineStyle','none','MarkerSize',7,...
                'MarkerFaceColor',speedclrs{i},'MarkerEdgeColor','k','Marker','o');
            within(:,i) = mean(W.corr(W.speed==i,:),2);
        end
        hold off
        set(gca,'XTickLabel',{'1','2','3','4'});
        ylabel('correlations of RDMs within subject across ROIs');
        xlabel('pressing speed');
        info = get(gca); wlims = info.YAxis.Limits;
        
        % plot WITHIN-subjet-BETWEEN-speed-between-ROI RDM correlations
        subplot(1,2,2)
        myboxplot(B.pairIdx,mean(B.corr,2),'plotall',0,'linecolor',[0 0 0],'xtickoff');
        hold on
        for i = 1:6
            h = plot(i,mean(B.corr(B.pairIdx==i,:),2),'LineStyle','none','MarkerSize',7,...
                'MarkerFaceColor',pairclrs{i},'MarkerEdgeColor','k','Marker','o');
            between(:,i) = mean(B.corr(B.pairIdx==i,:),2);
            %hMarkers = h(1).MarkerHandle.get;  % a matlab.graphics.primitive.world.Marker object
            %hMarkers.FaceColorData = uint8(255*[pairclrs{i}';0.1]);  % Alpha=0.3 => 70% transparent 
        end
        hold off
        title(sprintf('%s corr with %s',reg_title{roi(1)},reg_title{roi(2)}));
        set(gca,'XTickLabel',{'1:2','1:3','1:4','2:3','2:4','3:4'});
        xlabel('speed pair');
        ylim(wlims);
        % bring this subplot nearer to first subplot (sorta make it the
        % same plot space)
        info = get(gca); info.YAxis.Visible = 'off';
        p = info.Position; p(1) = 0.5; set(gca,'pos',p);

        keyboard
        %anova1(mean(B.corr,2),B.pairIdx)
        %anova1(mean(W.corr,2),W.speed)
    case 'FIG_rdm_reliability_btSubjbtROI'
        % split-half correlations of RDM for each subject. 
        % RDMs include all 20 conds.
        % Dissimilarities are calculated for each partition without
        % crossvalidation (distance_euclidean).
        glm     = 3;
        roi     = [12,30]; % default primary motor cortex
        sn      = 10:17;
        speeds  = 1:4;
        fig     = [];
        % Correlate RDMs across speeds, BETWEEN subjects.
        % Does correlation across all depths.
        vararginoptions(varargin,{'roi','glm','sn','speeds','fig'});
        
        %T   = load(fullfile(regDir,sprintf('glm%d_reg_splithalf_Tspeed.mat',glm)));  
        T = load(fullfile(regDir,sprintf('glm%d_reg_Tspeed.mat',glm)));
        %T = load(fullfile(regDir,sprintf('glm%d_reg_Tspeed_noMeanSpeedPattern.mat',glm)));
        T   = getrow(T,(T.region==roi(1) | T.region==roi(2)) & T.layer==1);
        % harvest for specific subjects
        B = [];
        for s = sn
            b = getrow(T,T.SN==s);
            B = addstruct(B,b);
        end
        T = B;
        clear b
        % prep output structures
        B   = [];
        W   = [];
        % loop through RDM speed pairs, correlate across subjects
        SN    = bsxfun(@times,T.SN,ones(1,length(T.SN))); 
        inSN  = (bsxfun(@eq,T.SN,T.SN'));      % which are for same subj?
        inROI = (bsxfun(@eq,T.region,T.region'));      % which are for same roi?
        %R     = corrN(T.RDM');
        R     = corr(T.RDM');
        pairIdx = rsa_squareRDM(1:6);
        % for each speed pair
        for i = 1:length(sn)
            s = sn(i); 
            for spd1 = 1:3
                for spd2 = speeds(spd1+1:end)
                    oppSp = bsxfun(@times,T.speed==spd2,T.speed'==spd1) | bsxfun(@times,T.speed==spd1,T.speed'==spd2); 
                    % harvest cross-speed, b/t subject correlations
                    b.corr      = R(SN==s & ~inSN & oppSp & ~inROI)';
                    b.SN        = s;
                    b.roi       = roi;
                    b.speedpair = [spd1,spd2];
                    b.pairIdx   = pairIdx(spd1,spd2);
                    B = addstruct(B,b);
                end
            end
            % harvest within-speed, across-subject correlations
            for spd = 1:4
                inSp    = bsxfun(@eq,T.speed==spd,T.speed'==spd);  % which are for same speed?
                inSp(T.speed~=spd,T.speed'~=spd) = 0;
                w.corr  = R(SN==s & ~inSN & inSp)';
                w.SN    = s;
                w.roi   = roi;
                w.speed = spd;
                W = addstruct(W,w);
            end
        end;
        % done correlations across subjects, between speed pairs
        
        % % now plot subject avgs.
        if isempty(fig)
            figure('Color',[1 1 1]);
        else
            fig;
        end
        pairclrs  = {[1 1 1],[0.2 0.2 1],[0.9 0.9 0],[0.5 0 0.6],[0 0.6 0],[0 0.6 0.6]};
        % plot BETWEEN-subjet-BETWEEN-speed-between-partition RDM correlations
        myboxplot(B.pairIdx,mean(B.corr,2),'plotall',0,'linecolor',[0 0 0],'xtickoff');
        hold on
        for i = 1:6
            h = plot(i,mean(B.corr(B.pairIdx==i,:),2),'LineStyle','none','MarkerSize',7,...
                'MarkerFaceColor',pairclrs{i},'MarkerEdgeColor','k','Marker','o');
            %hMarkers = h(1).MarkerHandle.get;  % a matlab.graphics.primitive.world.Marker object
            %hMarkers.FaceColorData = uint8(255*[pairclrs{i}';0.1]);  % Alpha=0.3 => 70% transparent 
        end
        hold off
        title(sprintf('%s corr with %s',reg_title{roi(1)},reg_title{roi(2)}));
        set(gca,'XTickLabel',{'1:2','1:3','1:4','2:3','2:4','3:4'});
        xlabel('speed pair');
        ylim([0 1]);

        keyboard
        %anova1(mean(B.corr,2),B.pairIdx)
        %anova1(mean(W.corr,2),W.speed)
     
    case 'FIG_RDM'
        % Plots one RDM for each pressing speed in subplot.
        % RDMs are scaled to same colour limits.
        % If called with >1 subj, avgs. RDMs across subjects.
        glm   = 3;
        roi   = 12;
        layer = 1;
        sn    = 10:17;
        vararginoptions(varargin,{'roi','glm','sn','layer'});

        % load data
        D = load(fullfile(regDir,sprintf('glm%d_reg_Tspeed.mat',glm)));
        % get RDMs for layer
        D = getrow(D,D.layer==layer);
        % harvesting for specific subjects
        T = [];
        for s = sn
            t = getrow(D,D.SN==s);
            T = addstruct(T,t);
        end
        D = T; clear T;
        
        % loop through ROIs
        for r = roi
            figure('Color',[1 1 1]);
            d = getrow(D,D.region==r);
            cmax = max(max(mean(d.RDM(d.speed==4,:),1)));
            for i = 1:4
                subplot(2,2,i);
                imagesc(rsa_squareRDM(mean(d.RDM(d.speed==i,:),1)),[0 cmax]);
                title(['speed ' num2str(i)]);
            end
        end
    case 'FIG_TruePatternHistogram'
        roi = 12;
        sn  = 10:13;
        numVox = 100; % most informative voxels
        
        cd /Users/sarbuckle/Documents/MotorControl/data/FingerPattern/fivedigitFreq3/RegionOfInterest
        Q = load('glm3_reg_betasTrueNoSat.mat');
        q = getrow(Q,Q.region==roi);

        numSubjs = length(sn);

        % roi finger-voxel tuning histograms
        indx = 1;
        figure;
        for i = 1:5
            for s = 1:numSubjs
                j = sn(s);
                subplot(5,numSubjs,indx);
                histogram(q.betaT{s}(i,:));
                indx = indx+1;

                %xlim([-10 10]);
                %ylim([0 250]);
            end
        end


        % Select "most significantly informative" voxels and plot tuning as histograms.
        % If regression was okay, then expect to see no betas below zero in plots.
        indx = 1;
        figure;
        for i = 1:5
            for s = 1:numSubjs
                j = sn(s);
                [~,SortByFit]  = sort(q.pFit{s}(i,:),'ascend');
                plotVoxels     = q.betaT{s}(i,SortByFit);
                plotVoxels     = plotVoxels(1:numVox);
                subplot(5,numSubjs,indx);
                histogram(plotVoxels);
                indx = indx+1;

                %xlim([0 10]);
                %ylim([0 50]);
            end
        end
        
        
        % Select "most explainable" voxels and plot tuning as histograms.
        % If regression was okay, then expect to see no betas below zero in plots.
        indx = 1;
        figure;
        for i = 1:5
            for s = 1:numSubjs
                j = sn(s);
                [~,SortByFit]  = sort(q.r2{s}(i,:),'ascend');
                plotVoxels     = q.betaT{s}(i,SortByFit);
                plotVoxels     = plotVoxels(1:numVox);
                subplot(5,numSubjs,indx);
                histogram(plotVoxels);
                indx = indx+1;

                %xlim([0 10]);
                %ylim([0 50]);
            end
        end
    case 'FIG_CorrSpeedRDMs'
        % Correlate RDMs of fingerpairs at each pressing speed across
        % subjects in specified roi. 
        glm   = 3;
        roi   = 12;
        layer = 1;
        sn    = 10:13;
        vararginoptions(varargin,{'roi','glm','sn','layer'});
        
        CAT.linewidth  = 2;
        CAT.marker     = 'o';
        CAT.markersize = 8;

        % load data
        D = load(fullfile(regDir,sprintf('glm%d_reg_Tspeed.mat',glm)));
        % get RDMs for layer
        D = getrow(D,D.layer==layer);
        % harvesting for specific subjects
        T = [];
        for s = sn
            t = getrow(D,D.SN==s);
            T = addstruct(T,t);
        end
        D = T; clear T;
        
        % determine subject correlation indexes
        sindx = [];
        for s = 1:length(sn)
            for sj = (s+1):length(sn)
                sindx(end+1,1:2) = [sn(s),sn(sj)];
            end
        end
        
        % loop through ROIs
        Q = [];
        for r = roi
            for sp = 1:4 % for each pressing speed
                d = getrow(D,D.region==r & D.speed==sp);
                % Now compare within speed across Subj
                R = corrN(d.RDM'); 
                % take only across subj correlations (i.e. don't include diag)
                q.corr  = rsa_vectorizeRDM(R);
                q.cond  = sp;
                q.SN    = sn;
                q.roi   = r;
                q.layer = layer;
%                 q.corr  = rsa_vectorizeRDM(R)';
%                 q.cond  = sp.*ones(size(q.corr));
%                 q.SN    = sindx;
%                 q.roi   = r.*ones(size(q.corr));
%                 q.layer = layer.*ones(size(q.corr));
                Q = addstruct(Q,q);
            end  
        end
        keyboard
             
    case 'stats_CorrCrossROI'
        % Correlate distances between ROIs within speeds within subjects.
        % Must have two ROIs.
        glm   = 3;
        roi   = [12,30];
        layer = 1;
        sn    = 10:13;
        vararginoptions(varargin,{'roi','glm','sn','layer'});

        % load appropriate file and get rows for subjs and roi
        D = load(fullfile(regDir,sprintf('glm%d_reg_Tspeed.mat',glm)));
        D = getrow(D,D.layer==layer);
        D = getrow(D,D.region==roi(1) | D.region==roi(2));
        % harvesting for specific subjects
        T = [];
        for s = sn
            t = getrow(D,D.SN==s);
            T = addstruct(T,t);
        end
        D = T; clear T;
        
        % Now compare within speed and between speed correlations (across
                % Subj) 
        SN    = bsxfun(@times,D.SN,ones(1,length(D.SN))); 
        inSN  = bsxfun(@eq,D.SN,D.SN');         % which are for same subj?
        ROI   = bsxfun(@times,D.region,ones(1,length(D.region)));
        inROI = bsxfun(@eq,D.region,D.region'); % which are in same region?
        inSp  = bsxfun(@eq,D.speed,D.speed');    % which are for same speed?
        %oppSp = bsxfun(@times,D.speed==4,D.speed'==1) | bsxfun(@times,D.speed==1,D.speed'==4); 

        R=corrN(D.RDM'); % [36 (subjs*4 frequencies) X 10 (paired dists at frequency)] matrix
        %R = corrNoInt(D.RDM);
        for i = 1:length(sn)
            s = sn(i);
            %within(i,1)  = mean(R(SN==s & inSN & inSp & ROI==roi(1) & inROI));   % should be 1 b/c correlating distances for subject
            %at each speed within ROI.
            between(i,1) = mean(R(SN==s & inSN & inSp & ROI==roi(1) & ~inROI));  % avg correlation between distances between ROIs at each pressing speed (avg. across 4 per subject)
        end;
        varargout ={between};
        
    
    
        sn   = 10;
        glm  = 3;
        hemi = 1;
        vararginoptions(varargin,{'sn','glm','hemi'});
        
        h = hemi;
        % change current directory
        groupDir = [gpCaretDir filesep hemName{h}];
        cd(groupDir);
        
        % hemisphere filenames and picture coords
        switch(h) 
            case 1
                coord = 'lh.FLAT.coord';
                topo  = 'lh.CUT.topo';
                data  = 'lh.surface_shape';
                xlims = [-12 7]; % may need to adjust locations for pics
                ylims = [-1 18];
                
            case 2
                coord = 'rh.FLAT.coord';
                topo  = 'rh.CUT.topo';
                data  = 'rh.surface_shape';
                xlims = [-12 7];
                ylims = [-1 18];
                
        end;
        
        % load Central Sulcus border line (to plot as dashed line in pics)
        border = fullfile(caretDir,'fsaverage_sym',hemName{h},['CS.border']);
        B      = caret_load(border);

        % plot section of surface reconstruction (w/out patterns)
        %figure('Color',[0 0 0]); % make figure w/ black background
        figure('Color',[1 1 1]); % make figure w/ white background
        sshape = fullfile(caretDir,'fsaverage_sym',hemName{h},[hem{h} '.surface_shape']);
        M      = caret_plotflatmap('col',2,'data',sshape,'border',B.Border,...
                'topo',topo,'coord',coord,'xlims',xlims,'ylims',ylims,'bordersize',15);
        colormap('bone');
        
        % plot pattern for each condition (rows = speeds, cols = fingers)
        data   = fullfile(caretDir,['x' subj_name{sn}],hemName{h},sprintf('s%02d_glm%d_hemi%d_finger.metric',sn,glm,h));
        %figure('Color',[0 0 0]); % make figure w/ black background
        figure('Color',[1 1 1]); % figure w/ white background
        for i = 1:20
            subplot(4,5,i);
            [M,d]   = caret_plotflatmap('M',M,'col',i,'data',data,'cscale',[-6 12],...
                        'border',B.Border,'bordersize',10,'topo',topo,'coord',coord);
            maxT(i) = max(d(:));
            minT(i) = min(d(:));
            colormap('jet');
        end;
        
        % force colour scaling on patterns
        mm = 10;%max(maxT);
        for i=1:20
            subplot(4,5,i);
            ax = get(gca);
            box on
            caxis([-mm/2 mm]);   % scale color across plots
            set(gca,'XTick',[]); % remove X and Y axis ticks
            set(gca,'YTick',[]);
            %axis equal;
            ax.XAxis.LineWidth = 3;
            ax.YAxis.LineWidth = 3;
        end;
        
        set(gcf,'PaperPosition',[1 1 10 7]);
        set(gcf,'InvertHardcopy','off'); % allows save function to save pic w/ current background colour (not default to white)
        wysiwyg;
        
       keyboard
       %saveas(gcf, [subj_name{sn},'_',hemName{h},'_',sprintf('%d',mm)], 'jpg')
    
    case 'STATS_ResponseProperties' 
        glm = 3;
        sn  = [10:17];
        roi = [11,12,6,24];
        %speeds = [1:4]; % include selection of speeds
        vararginoptions(varargin,{'sn','glm','roi','speeds'});
        
        % digit contrast
        C = rsa.util.pairMatrix(5);
        
        % load region data (T)
        T = load(fullfile(regDir,sprintf('glm%d_reg_betas.mat',glm))); 
        % prep output structure
        UM = [];
        
        % do stats
        for s = sn % for each subject
            Dd = load(fullfile(glmDir{glm}, subj_name{s}, 'SPM_info.mat'));   % load subject's trial structure
            fprintf('\nSubject: %d\n',s)

            for spd = 1:4 % for each speed
                % logical for runs to take betas from
                %take_betas = logical(ismember(D.speed,speeds));
                take_betas = logical(Dd.speed==spd);
                D = getrow(Dd,take_betas);
                D.tt = renumber_conds(D.tt);
                
                for r = roi % for each region
                    S = getrow(T,(T.SN==s & T.region==r)); % subject's region data
                    fprintf('%d.',r)
                    % get betas
                    beta    = S.beta{1}(take_betas,:); % raw betas
                    betaUW  = bsxfun(@rdivide,beta,sqrt(S.resMS{1}));  % apply univariate whitening to beta regressors (divide by voxel's variation)

                    for q = 1:3
                        switch q
                            case 1 % Univariate (projections)
                                % project patterns on mean pattern line
                                betas = calcUnivariateProjections(betaUW,D.run);
                            case 2 % Multivariate (deviations from projections)
                                betas = betaUW - betas; % note betas here are the univariate mean pattern projections
                            case 3 % Uni + Multi (untouched betas)
                                betas = betaUW;
                        end
                        % do stats on betas                                
                        So.numvox       = size(beta,2);
                        So.mm_area      = So.numvox*voxSize;
                        G               = pcm_estGCrossval(betas,D.run,D.tt);
                        Gpd             = pcm_makePD(G);
                        So.G            = rsa_vectorizeIPM(G);
                        So.Gpd          = rsa_vectorizeIPM(Gpd);
                        So.dist_nocv    = distance_euclidean(betas',D.tt)';
                        So.dist_nocv_mm = (So.dist_nocv.*So.numvox)./So.mm_area;
                        So.ldc_pd       = sum((C*Gpd).*C,2)';
                        So.ldc          = rsa.distanceLDC(betas,D.run,D.tt);    % info/voxel
                        So.ldc_mm       = (So.ldc.*So.numvox)./So.mm_area; % info/mm^3
                        % indexing fields
                        So.numPress = 2^spd;
                        So.type     = q;
                        So.sn       = s;
                        So.roi      = r;
                        So.regSide  = regSide(r);
                        So.regType  = regType(r);
                        UM          = addstruct(UM,So);
                    end
                end; % each region
            end % for each speed
        end; % each subject

        % save
        save(fullfile(regDir,sprintf('glm%d_uni_vs_multi_Stats.mat',glm)),'UM');
        fprintf('\nDone.\n')   
    case 'HARVEST_ResponseProperties'
        glm = 3;
        sn  = 10:17;
        roi = 11;
        vararginoptions(varargin,{'sn','glm','roi'});
        % load subject's response properties (UM struct)
        load(fullfile(regDir,sprintf('glm%d_uni_vs_multi_Stats.mat',glm)));
        UM = getrow(UM,ismember(UM.sn,sn) & ismember(UM.roi,roi));
        % arrange into structure
        w = ones(size(UM.ldc,2),1); % number of paired distances
        W = [];
        for j = 1:length(UM.type)
            vv.dist_nocv    = UM.dist_nocv(j,:)';
            vv.ldc          = UM.ldc_pd(j,:)';
            vv.dist_nocv_mm = UM.dist_nocv_mm(j,:)';
            vv.ldc_mm       = UM.ldc_mm(j,:)';
            vv.type         = w.*UM.type(j);
            vv.sn           = w.*UM.sn(j);
            vv.roi          = w.*UM.roi(j);
            vv.exp          = w.*4; % experiment 4
            vv.species      = w.*1; % human
            vv.numPress     = w.*UM.numPress(j);
            W = addstruct(W,vv);
        end
        % avg. dists within subjects
        W = tapply(W,{'sn','roi','type','exp','species','numPress'},{'ldc','mean'},{'ldc_mm','mean'},{'dist_nocv','mean'},{'dist_nocv_mm','mean'});
        % calc dist ratio
        Wr = [];
        for r = roi
            for f = [2,4,8,16]
                w1 = getrow(W,W.type==1 & W.roi==r & W.numPress==f);    % Univariate distance (differences along univariate projection)
                w2 = getrow(W,W.type==2 & W.roi==r & W.numPress==f);    % Multivariate distance (deviations from univariate projections)
                w3 = getrow(W,W.type==3 & W.roi==r & W.numPress==f);    % Overall distance (untouched betas)
                %wr.ratio    = w2.ldc./w3.ldc;           % multivariate-to-total distances
                wr.ratio_uni= w1.ldc./w3.ldc;
                wr.ratio_mm = w2.ldc_mm./w3.ldc_mm; 
                wr.ratio_uniAvg = w1.ldc./mean(w3.ldc);
                wr.ratio_mmAvg  = w2.ldc./mean(w3.ldc);
                wr.sn       = w2.sn;
                wr.roi      = w2.roi;
                wr.exp      = ones(size(w2.sn)).*4; % experiment 4
                wr.species  = ones(size(w2.sn)).*1; % human
                wr.numPress = w2.numPress;
                Wr = addstruct(Wr,wr);
            end
        end
        varargout = {W,Wr};
    case 'FIG_mltDistRatio'
        roi = [11,12,6,24]; % s1, m1, v1/v2 (both hemis)
        sn  = 10:17;
        glm = 3;
        
        [~,Wr] = fivedigitFreq3_imana('HARVEST_ResponseProperties','roi',roi,'sn',sn,'glm',glm);
        Wr.freq = Wr.numPress./6;
        % first, avg. ratios for v1/v2 across hemispheres
        Wr.roi(Wr.roi==6)=24;
        Wr = tapply(Wr,{'sn','roi','freq','numPress'},{'ratio_mmAvg','nanmean'},{'ratio_uniAvg','nanmean'});
        % exclude plotting data for two lowest frequencies in visual
        % cortices
        % why? Because some avg. univariate distances (on the components) are
        % negative, which causes the overall distance to be less than the
        % multivariate (b/c total has multi - uni, in this case, instead of
        % multi + uni)
        Wr.subset = true(size(Wr.roi));
        %Wr.subset((Wr.roi==24 & Wr.numPress==2)|(Wr.roi==24 & Wr.numPress==4)) = false;
        % plot all freqs for all rois
        %shades = plt.defaults.colours({'black','medred','medgreen'});
        %sty    = style.custom(shades);
        style.use('3black');
        figure('Color',[1 1 1]);
        plt.line(log(Wr.numPress),Wr.ratio_mmAvg,'split',Wr.roi,'subset',Wr.subset,'errorfcn','');
        ylim([0 1]); % V1/V2 ratios may be weird for first two freqs, since very noisy
        plt.labels('stimulation freq. (Hz)','multi/total ldc');
        plt.set('xticklabel',{'0.3','0.6','1.3','2.6'},'xticklabelrotation',45);
        plt.legend('southwest',{'S1','M1','V1/V2'});
        drawline(0.5,'dir','horz','linestyle',':','linewidth',1.5);
        %text(1.75,0.35,(['\downarrow ', sprintf('greater \n univariate \n distance')]));
        %keyboard
        varargout={Wr};
        
    case 'STATS_patternVarRatio'  
        glm = 3;
        sn  = [10:17];
        roi = [11,12];
        %speeds = [1:4]; % include selection of speeds
        vararginoptions(varargin,{'sn','glm','roi','speeds'});
        
        % load region data (T)
        T = load(fullfile(regDir,sprintf('glm%d_reg_betas.mat',glm))); 
        % prep output structure
        W = [];
        
        % do stats
        for s = sn % for each subject
            Dd = load(fullfile(glmDir{glm}, subj_name{s}, 'SPM_info.mat'));   % load subject's trial structure
            fprintf('\nSubject: %d\n',s)
            
            for spd = 1:4 % for each speed
                % logical for runs to take betas from
                %take_betas = logical(ismember(D.speed,speeds));
                take_betas = logical(Dd.speed==spd);
                D = getrow(Dd,take_betas);
                D.tt = renumber_conds(D.tt);
                
                for r = roi % for each region
                    S = getrow(T,(T.SN==s & T.region==r)); % subject's region data
                    fprintf('%d.',r)
                    % get betas
                    beta    = S.beta{1}(take_betas,:); % raw betas
                    betaUW  = bsxfun(@rdivide,beta,sqrt(S.resMS{1}));  % apply univariate whitening to beta regressors (divide by voxel's variation)
                    
                    C0    = indicatorMatrix('identity',D.run); % run means contrast matrix
                    U_uni = C0*pinv(C0)*betaUW;
                    U_mlt = betaUW - U_uni; 

                    % calc Gs
                    G_tot = pcm_estGCrossval(betaUW,D.run,D.tt);
                    G_uni = pcm_estGCrossval(U_uni,D.run,D.tt);
                    G_mlt = pcm_estGCrossval(U_mlt,D.run,D.tt);

                    So.m_uni = mean(diag(G_uni));
                    So.m_mlt = mean(diag(G_mlt));
                    So.m_tot = mean(diag(G_tot));

                    So.G_tot = rsa_vectorizeIPM(G_tot);
                    So.G_uni = rsa_vectorizeIPM(G_uni);
                    So.G_mlt = rsa_vectorizeIPM(G_mlt);

                    So.ratio_um = So.m_uni/So.m_mlt;
                    So.ratio_ut = So.m_uni/So.m_tot;
                    So.ratio_mt = So.m_mlt/So.m_tot;
%                     % project patterns on mean pattern line
%                     uniBetas = calcUnivariateProjections(betaUW,D.run);
%                     % calc multivar patterns
%                     mltBetas = betaUW - uniBetas;
%                     % cal second moments of both sets of patterns
%                     uniG    = pcm_estGCrossval(uniBetas,D.run,D.tt);
%                     mltG    = pcm_estGCrossval(mltBetas,D.run,D.tt);
%                     % calc ratio of univariate vars ./ multivariate vars
%                     So.diag_ratio = [ssqrt(diag(uniG))./ssqrt(diag(mltG))]';
%                     So.uniG = rsa_vectorizeIPM(uniG);
%                     So.mltG = rsa_vectorizeIPM(mltG);
                    % indexing fields
                    So.numPress = 2^spd;
                    So.sn       = s;
                    So.roi      = r;
                    So.regSide  = regSide(r);
                    So.regType  = regType(r);
                    W           = addstruct(W,So);
                end % each region
            end; % each speed
        end; % each subject
        % save
        save(fullfile(regDir,sprintf('glm%d_uni_vs_multi_vars.mat',glm)),'W');
        fprintf('\nDone.\n')    
    case 'HARVEST_patternVarRatio'    
        glm = 3;
        sn  = 10:17;
        roi = 11;
        vararginoptions(varargin,{'sn','glm','roi'});
        % load subject's response properties (W struct)
        load(fullfile(regDir,sprintf('glm%d_uni_vs_multi_vars.mat',glm)));
        W = getrow(W,ismember(W.sn,sn) & ismember(W.roi,roi));
        % avg. ratios across pressing freqs within subj
        %W = tapply(W,{'sn','roi'},{'diag_ratio','mean'});
        % rearrange into plotting structure
        Wr = [];
        %v  = ones(5,1);
        for i = 1:size(W.sn,1)
            w.ratio_um = W.ratio_um(i,:);
            w.ratio_ut = W.ratio_ut(i,:);
            w.ratio_mt = W.ratio_mt(i,:);
            %w.digit    = [1:5]';
            w.sn       = W.sn(i);
            w.roi      = W.roi(i);
            w.numPress = W.numPress(i);
            w.exp      = 4; % experiment 4
            w.species  = 1; % human
            Wr = addstruct(Wr,w);
        end
        varargout = {Wr};
      
    case 'STATS_spatialCorrelation'
        % correlates activity patterns of each finger across speeds.
        % if RDM is stable, are spatial patterns also stable?
        glm = 3;
        roi = 12; % default primary motor cortex
        sn  = 10:17;
        Do  = []; % output structure
        v   = ones(12,1);
        % load region data
        T  = load(fullfile(regDir,sprintf('glm%d_reg_betas.mat',glm)));      
        T  = getrow(T,T.region==roi);
        
        for s = sn % for each subject
            D     = load(fullfile(glmDir{glm}, subj_name{s}, 'SPM_info.mat')); % load subject's trial structure
            t     = getrow(T,T.SN==s & T.region==roi);
            betas = bsxfun(@rdivide,t.beta{1}(1:length(D.run),:),sqrt(t.resMS{1})); % univariate whitened betas
            % - remove run mean
%             C0 = indicatorMatrix('identity',D.run); % run-mean centring matrix
%             betas = betas-C0*pinv(C0)*betas;
            % - make datastructure 
            t = [];
            t.betas = betas;
            t.run   = D.run;
            t.speed = D.speed;
            t.digit = D.digit;
            % - split patterns into even and odd runs, avg. patterns within
            % splits
            t.even = mod(t.run,2);
            tEven  = tapply(t,{'speed','digit'},{'betas','mean'},'subset',t.even==1);
            tOdd   = tapply(t,{'speed','digit'},{'betas','mean'},'subset',t.even==0);
            % - correlate patterns
            R = corr(tEven.betas',tOdd.betas');
            diffSpeed = bsxfun(@(x,y) x~=y,tEven.speed,tOdd.speed');
            % - get correlations across speeds for each digit
            for d = 1:5
                sameDigit = bsxfun(@(x,y) x==y & x==d,tEven.digit,tOdd.digit');               
                Di.corr   = R(sameDigit & diffSpeed);
                Di.digit  = v.*d;
                Di.sn     = v.*s;
                Di.roi    = v.*roi;
                Do = addstruct(Do,Di);
            end
        end
        varargout = {Do};
    case 'PLOT_spatialCorrelation'
        D = fivedigitFreq3_imana('STATS_spatialCorrelation');
        D = tapply(D,{'sn','digit','roi'},{'corr','mean'});
        plt.dot(D.digit,D.corr)
        
    case '0' % These cases toyed around w/ the idea of regressing out the scaling effect from the raw activity to estimate "true" finger patterns (remove this BOLD effect)
    case 'ROI_TruePatterns'
        glm        = 3;
        sn         = [10:13];
        roi        = [11,12,29,30];
        vararginoptions(varargin,{'sn','glm','roi'});
        runs = [1:8];
        
        Q = [];
        Z = [];
        %parts = [1:4;5:8];  % split-half partitions
        parts = [1:8];
        % suppress warnings from robustfit
        warning off    
        
        %digitIdx = repmat([1:5]',[4,1]);
        digitIdx = [repmat([1:5]',[3,1]); zeros([5,1])];    % take only data for first 3 pressing speeds (not when it supposedly saturates)
        
        % % start harvest
        for s = sn % for each subj
            fprintf('\nSubject: %d\n',s) % output to user
            
            % load files
            load(fullfile(glmDir{glm}, subj_name{s}, 'SPM.mat'));  		   % load subject's SPM data structure (SPM struct)
            load(fullfile(regDir,sprintf('s%02d_regions.mat',s)));         % load subject's region parcellation & depth structure (R)
            load(fullfile(behavDir,sprintf('fdf3_forces_s%02d',s)));
            
            % TR img info
            V = SPM.xY.VY; 
                  
            for r = roi % for each region
                % get raw data for voxels in region
                Y = region_getdata(V,R{r});  % Data Y is N x P (P is in order of transpose of R{r}.depth)
                % estimate region betas
                [betaW,~,~,~] = rsa.spm.noiseNormalizeBeta(Y,SPM,'normmode','overall'); 
                
                % preallocate output arrays for this roi in subject
                betaT = zeros([5,size(betaW,2)]);
                fit   = betaT;
                r2    = betaT;
                
                sse    = [];
                ssr    = [];
                y_hat  = [];
                stderr = [];
                
                NI_betaT = [];
                NI_fit   = [];
                r2       = [];
                NI_sse   = [];
                NI_ssr   = [];
                NI_y_hat = [];
                NI_stderr= [];
                
                % for each partition (defined by number of rows in 'parts')
                for partition = 1:size(parts,1);
                    % define partitions
                    takeRuns    = parts(partition,:);
                    %partLogical = [zeros([4*(length(takeRuns)*(partition-1)),1]); ones([4*length(takeRuns),1])];
                    % take all speeds save for 16 pressing speed (b/c 16
                    % presses appears to saturate patterns)
                    partLogical = [zeros([3*(length(takeRuns)*(partition-1)),1]); ones([3*length(takeRuns),1])];
                    
                    % harvest runs in this partition
                    T = [];
                    for j = takeRuns
                        t = getrow(D,D.BN==j);
                        T = addstruct(T,t);
                    end
                    Dd = T; clear T t;
                    
                    % for each digit...
                    for d = 1:5                     
                        % create digit index (across speeds & runs in this
                        % partition)
                        dind  = logical(digitIdx==d);
                        dind  = repmat(dind,[(length(runs)),1]);  % make digit index map to betaW matrix size (so ids rows for digit, irrespective of speed condition)
                        dind  = betaW(dind==1,:);
                        % get row of D that corresponds to digit.
                        % Do this so that we can use the pressing
                        % frequency of each run (in subj) to regress BOLD
                        % against.
                        F  = getrow(Dd,Dd.digit==d);               
                        F  = getrow(F,F.tt<16);
                        % get pressing frequency for subject's trials witihn each block (so
                        % avg. of two trials per block = 32 conds if all runs included)
                        freq  = log(splitmath(F.goodPresses,uniquePairs([F.BN,F.tt])));
                        % split betaW by partitions
                        pind  = dind(partLogical==1,:);
                        
                        % for each voxel...
                        for p = 1:size(pind,2)      
                            %[betaT(d,p),stats] = robustfit(pind(:,p),freq,[],[],0); % linear regression without intercept
                            [betaT(d,p),stats] = robustfit(freq,pind(:,p),[],[],0);
                            fit(d,p)           = stats.p; % harvest p-value (fits)
                            stderr(d,p)        = stats.se;
                            % calculate possible r2
                            % NOTE: using robust fit, which doens't
                            % maximize r2 (like OLS), so r2 will always be
                            % =< r2 form OLS fit. 
                            sse     = stats.dfe * stats.robust_s^2; 
                            y_hat   = betaT(d,p) * pind(:,p);
                            ssr     = norm(y_hat - mean(y_hat))^2;
                            r2(d,p) = 1 - sse/(sse+ssr); %corr(pind(:,p),y_hat);
                        end
                    end
                    % add to output structure
                    q.IPM    = rsa_vectorizeIPM((betaT*betaT')/size(pind,2));
                    q.RDM    = distance_euclidean(betaT',[1:5])';
                    q.betaT  = {betaT};
                    q.pFit   = {fit};
                    q.r2     = {r2};
                    q.stderr = {stderr};
                    q.SN     = s;
                    q.split  = partition;
                    q.region = r;
                    Q = addstruct(Q,q);
                end
                % end of regression stuff
                
                fprintf('%d.',r)
                
                
                % Let's look at voxels not tuned to each finger- does their
                % activity change as pressing speeds inc./saturate?
                % Therefore, include all pressing speeds.
                digitIdx = repmat([1:5]',[4,1]);
                for d = 1:5
                    t = getrow(Q,Q.SN==s & Q.region==r);
                    non_inform_voxels = logical(t.pFit{1}(d,:)>0.05 & t.stderr{1}(d,:)>=min(max(t.stderr{1})));
                    % get row of D that corresponds to digit.
                    % Do this so that we can use the pressing
                    % frequency of each run (in subj) to regress BOLD
                    % against.
                    F  = getrow(Dd,Dd.digit==d);               
                    % get pressing frequency for subject's trials witihn each block (so
                    % avg. of two trials per block = 32 conds if all runs included)
                    freq  = log(splitmath(F.goodPresses,uniquePairs([F.BN,F.tt])));
                    
                    dind  = logical(digitIdx==d);
                    dind  = repmat(dind,[(length(runs)),1]);  % make digit index map to betaW matrix size (so ids rows for digit, irrespective of speed condition)
                    dind  = betaW(dind==1,non_inform_voxels);
                    partLogical = [zeros([4*(length(takeRuns)*(partition-1)),1]); ones([4*length(takeRuns),1])];
                    pind  = dind(partLogical==1,:);
                    % for each voxel...
                    for p = 1:size(pind,2)      
                        %[betaT(d,p),stats] = robustfit(pind(:,p),freq,[],[],0); % linear regression without intercept
                        [NI_betaT(d,p),stats] = robustfit(freq,pind(:,p),[],[],0);
                        NI_fit(d,p)           = stats.p; % harvest p-value (fits)
                        NI_stderr(d,p)        = stats.se;
                        % calculate possible r2
                        % NOTE: using robust fit, which doens't
                        % maximize r2 (like OLS), so r2 will always be
                        % =< r2 form OLS fit. 
                        NI_sse     = stats.dfe * stats.robust_s^2; 
                        NI_y_hat   = NI_betaT(d,p) * pind(:,p);
                        NI_ssr     = norm(NI_y_hat - mean(NI_y_hat))^2;
                        NI_r2(d,p) = 1 - NI_sse/(NI_sse + NI_ssr); %corr(pind(:,p),y_hat);
                    end
                end
                % add to output structure
                z.IPM    = rsa_vectorizeIPM((NI_betaT*NI_betaT')/sum(non_inform_voxels));
                z.RDM    = distance_euclidean(NI_betaT',[1:5])';
                z.betaT  = {NI_betaT};
                z.pFit   = {NI_fit};
                z.r2     = {NI_r2};
                z.stderr = {NI_stderr};
                z.SN     = s;
                z.split  = partition;
                z.region = r;
                Z = addstruct(Z,z);
            end
        end
        
        % un-suppress warnings
        warning on
        
        % % save Q
        save(fullfile(regDir,sprintf('glm%d_reg_betasTrueNoSat.mat',glm)),'-struct','Q'); 
        save(fullfile(regDir,sprintf('glm%d_reg_betasNonInform.mat',glm)),'-struct','Z'); 
        fprintf('\n')
    case 'ROI_VoxActWeights_betas'
        glm        = 3;
        sn         = [10:17];
        roi        = [11,12,29,30];
        vararginoptions(varargin,{'sn','glm','roi'});
        
        Q = [];
        parts = [1:2:7;2:2:8];  % split-half partitions
        runs  = unique(parts);
        
        digitIndex = repmat(kron(ones(1,4),1:5),1,length(runs))';
        
        % load in beta estimates from region (ROI_getBetas output struct)
        Y = load(fullfile(regDir,sprintf('glm%d_reg_betas.mat',glm)));
        % Load in scaling model theta_hats from pcm fitting.
        % Using the noCV fits because then the scaling params fit to each
        % subject are the same. 
        % This might not be the best...but let's start here.
        P = load(fullfile(regDir,sprintf('fit_model_pcm_reg%d_L%d_glm%d.mat',roi,1,glm)));
        theta_scaling = [P.theta_hat_nocv{2}(15:17);1];
        
        % % start harvest
        for s = sn % for each subj
            fprintf('\nSubject: %d\n',s) % output to user
            
            % load subject's behavioural data (D)
            load(fullfile(behavDir,sprintf('fdf3_forces_s%02d',s)));
                  
            for r = roi % for each region
                
                % get raw data for voxels in region
                S = getrow(Y,Y.region==r & Y.SN==s);
                % estimate region betas
                betaW = S.betaW{1};
                
                % preallocate output arrays for this roi in subject
                slopes = zeros([5,size(betaW,2)]);
                
                % for each partition (defined by number of rows in 'parts')
                for partition = 1:size(parts,1);
                    % define partitions
                    takeRuns    = ismember(runs,parts(partition,:))';
                    partLogical = kron(takeRuns,ones(1,20))';
                    
                    % harvest runs in this partition
                    T = [];
                    for j = runs(takeRuns)'
                        t = getrow(D,D.BN==j);
                        T = addstruct(T,t);
                    end
                    Dd = T; clear T t;
                    
                    % for each digit...
                    for d = 1:5                     
                        % create digit index (across speeds & runs in this
                        % partition)
                        digitBetas  = betaW(digitIndex==d & partLogical,:);
                        % get row of D that corresponds to digit.
                        % Do this so that we can use the pressing
                        % frequency of each run (in subj) to regress BOLD
                        % against.
                        F  = getrow(Dd,Dd.digit==d);               
                        % get pressing frequency for subject's trials witihn each block (so
                        % avg. of two trials per block = 32 conds if all runs included)
                        freq  = log(splitmath(F.goodPresses,uniquePairs([F.BN,F.tt])));
                        
                        % for each voxel for this finger...
                        for p = 1:size(digitBetas,2)      
                            slopes(d,p) = pinv(freq'*freq)*freq'*digitBetas(:,p); % linear regression without intercept
                        end
                    end
                    % add to output structure
                    q.voxel_weights = {slopes};
                    q.SN            = s;
                    q.partition     = partition;
                    q.runs          = parts(partition,:);
                    q.region        = r;
                    Q = addstruct(Q,q);
                end
                % end of regression stuff
                
                fprintf('%d.',r)
            end
        end
        
        % % save Q
        save(fullfile(regDir,sprintf('glm%d_reg_VoxActWeights.mat',glm)),'-struct','Q'); 
        fprintf('\n')
    case 'ROI_VoxActWeights_stats'
        glm = 3;
        sn  = [10:17];
        roi = [11,12,29,30];
        vararginoptions(varargin,{'sn','glm','roi'});
        
        parts = [1:2:7; 2:2:8];  % split-half partitions
        runs  = unique(parts);
        VH_cutoff = 0.15;
        VL_cutoff = -0.15;
        
        Q = load(fullfile(regDir,sprintf('glm%d_reg_VoxActWeights.mat',glm))); % loads region's voxel weights
        T = load(fullfile(regDir,sprintf('glm%d_reg_betas.mat',glm)));         % loads region data (T)
        % output structures
        V = [];
        
        % prep some condition logicals
        speedIndex = repmat(kron(1:4,ones(1,5)),1,length(runs))';
        digitIndex = repmat(kron(ones(1,4),1:5),1,length(runs))';
        
        % do stats
        for s = sn % for each subject
            fprintf('\nSubject: %d\n',s)
            
            for r = roi % for each region
                S = getrow(T,(T.SN==s & T.region==r)); % subject's region data
                q = getrow(Q,(Q.SN==s & Q.region==r)); % subject's region voxel weights
                fprintf('%d.',r)
                
                for p = q.partition'
                    % make logical for high-activity and low-activity
                    % voxels based on partition (and apply to weights from
                    % left-out partitions)
                    v_high_logical = logical(q.voxel_weights{q.partition==p,1}>VH_cutoff);
                    v_low_logical  = logical(q.voxel_weights{q.partition==p,1}<=VH_cutoff & q.voxel_weights{q.partition==p,1}>VL_cutoff);
                    
                    % define test partitions (note: taking left-out data to
                    % test!)
                    takeRuns    = ~ismember(runs,parts(p,:))';
                    partLogical = kron(takeRuns,ones(1,20))';
                    
                    % loop through speeds (and fingers)
                    v.VH_act = [];
                    v.VL_act = [];
                    v.numVH  = [];
                    v.numVL  = [];
                    for d = 1:5
                        for spd = 1:4
                            VH_indx         = repmat(v_high_logical(d,:),4,1);
                            VL_indx         = repmat(v_low_logical(d,:),4,1);
                            testIndex       = logical(speedIndex==spd & digitIndex==d & partLogical);
                            test_data       = S.betaW{1}(testIndex,:);
                            v.VH_act(1,spd) = mean(test_data(VH_indx));
                            v.VL_act(1,spd) = mean(test_data(VL_indx));
                            v.numVH(1,spd)  = sum(v_high_logical(d,:));
                            v.numVL(1,spd)  = sum(v_low_logical(d,:));
                        end
                        v.digit     = d;
                        v.SN        = s;
                        v.region    = r;
                        v.partition = p;
                        V = addstruct(V,v);
                    end
                    
                end
            end; % each region
        end; % each subject

        % % save
        save(fullfile(regDir,sprintf('glm%d_reg_Voverall.mat',glm)),'V');
        fprintf('\nDone.\n')
    case 'ROI_stats_noMeanSpeedPattern'
        glm = 3;
        sn  = 10:17;
        roi = [11,12,29,30];
        vararginoptions(varargin,{'sn','glm','roi'});
        
        T = load(fullfile(regDir,sprintf('glm%d_reg_betas_noMeanSpeedPattern.mat',glm))); % loads region data (T)
        
        % output structures
        Ts = [];
        To = [];
        
        % do stats
        for s = sn % for each subject
            D = load(fullfile(glmDir{glm}, subj_name{s}, 'SPM_info.mat'));   % load subject's trial structure
            fprintf('\nSubject: %d\n',s)
            % get num runs
            num_run = length(unique(D.run));
            
            for r = roi % for each region
                S = getrow(T,(T.SN==s & T.region==r)); % subject's region data
                fprintf('%d.',r)
                
                for L = 1:length(layers) % for each layer defined in 'layers'
                    L_indx = (S.depth{1} > layers{L}(1)) & (S.depth{1} < layers{L}(2)); % index of voxels for layer depth
                    betaW  = S.betaW{1}(:,L_indx); 
                    % % Toverall structure stats
                    % crossval second moment matrix
                    [G,Sig]     = pcm_estGCrossval(betaW(1:(20*num_run),:),D.run,D.tt);
                    So.IPM      = rsa_vectorizeIPM(G);
                    So.Sig      = rsa_vectorizeIPM(Sig);
                    % squared distances
                    So.RDM_nocv = distance_euclidean(betaW',D.tt)';
                    So.RDM      = rsa.distanceLDC(betaW,D.run,D.tt);
                    % indexing fields
                    So.SN       = s;
                    So.region   = r;
                    So.layer    = L;
                    So.numVox   = sum(L_indx);
                    So.regSide  = regSide(r);
                    So.regType  = regType(r);
                    To          = addstruct(To,So);
                    
                    % % Tspeed structure stats
                    for spd=1:4 % for each pressing condition
                        % distances
                        Ss.RDM     = rsa.distanceLDC(betaW,D.run,D.digit.*double(D.speed==spd));
                        Ss.act     = mean(mean(betaW(D.speed==spd,:)));
                        % indexing fields
                        Ss.SN      = s;
                        Ss.region  = r;
                        Ss.speed   = spd;
                        Ss.numVox  = sum(L_indx);
                        Ss.layer   = L;
                        Ss.regSide = regSide(r);
                        Ss.regType = regType(r);
                        Ts         = addstruct(Ts,Ss);
                    end
                end; % each layer
            end; % each region
        end; % each subject

        % % save
        save(fullfile(regDir,sprintf('glm%d_reg_Tspeed_noMeanSpeedPattern.mat',glm)),'-struct','Ts');
        save(fullfile(regDir,sprintf('glm%d_reg_Toverall_noMeanSpeedPattern.mat',glm)),'-struct','To');
        fprintf('\nDone.\n')
       
       
    case '0' % These cases run analyses to see if dists. or additive vs. scaling components change across cortical depth.- Answer: No. 
    case 'PCM_depthAnalysis'
        roi = 12; % lh M1
        fivedigitFreq3_imana('PCM_GroupFit','layer',2,'roi',roi,'glm',3); % 'superficial' voxels
        fivedigitFreq3_imana('PCM_GroupFit','layer',3,'roi',roi,'glm',3); % 'deep' voxels
    case 'FIG_DistDepthScaling'                                             % plot avg. paired distance vs avg pattern distance of deep and superficial voxels for each speed
        glm = 3;
        roi = 2;
        sn  = 10:13;
        do_anova = 1;
        vararginoptions(varargin,{'roi','glm','sn','do_anova'});

        T = [];
        
        % distance contrasts:
        fp_con  = indicatorMatrix('allpairs',[1:5]); % paired finger distances
        spd_con = ones(1,5)/5;                       % mean pattern distance
        % HARVEST
        D = load(fullfile(regDir,sprintf('glm%d_reg_Toverall.mat',glm)));
        if length(roi)<2
            for i = 2:3 % for voxels at superficial or deep depths
                for s = sn
                    % subject's crossvalidated G in this roi at this depth
                    G = rsa_squareIPM(D.IPM(D.SN==s & D.layer==i & D.region==roi,:));
                    for spd = 1:4
                        % G values pertaining to this speed
                        sindx = [1+((spd*5)-5):5+((spd*5)-5)];
                        Gs    = G(sindx,sindx); 
                        % harvest identifiers
                        t.speed = spd;
                        t.depth = i;
                        t.vox   = D.numVox(D.SN==s & D.layer==i & D.region==roi,:);
                        t.SN    = s;
                        % calculate distances
                        t.paired      = [ssqrt(sum((fp_con*Gs).*fp_con,2))]';
                        t.avg_pattern = ssqrt(sum(sum((spd_con*Gs).*spd_con,2))); % distance of avg pattern from baseline
                        t.avg_paired  = mean(t.paired,2);   % avg distance of paired finger patterns
                        T = addstruct(T,t);     
                    end
                end
            end;
            T.ratio = T.avg_paired./T.avg_pattern;
            %save(fullfile(regDir,sprintf('%s_distdepth.mat',reg_title{roi})),'T');
            %fprintf('\nDepth \tSpeed \tnumVox\n')
            
            % PLOT
            figure; 
            hold on
            markers = {'o','s'};
            if do_anova     % plot as subplot if also plotting anova
                subplot(1,2,1);
                hold on
            end
            clrs    = {[0 0 0] [0.5 0 0] [0.9 0 0] [1 0.6 0]};
            % plot for each speed
            J = [];
            for spd=1:4
                t = getrow(T,T.speed==spd);
                plot(splitmath(t.avg_pattern,t.depth),splitmath(t.avg_paired,t.depth),...
                    ':','LineWidth',2,'Color',clrs{spd},'MarkerSize',7,'MarkerFaceColor',clrs{spd});
                % change marker styles (circle for deep, square for
                % superficial)
                for i = 2:3
                    tt = getrow(t,t.depth==i);
                    plot(mean(tt.avg_pattern),mean(tt.avg_paired),'MarkerSize',7,...
                        'Marker',markers{i-1},'Color',clrs{spd},'MarkerFaceColor',clrs{spd});
                end
                % determine y intercept
                deepAVG  = t.avg_pattern(t.depth==3);
                superAVG = t.avg_pattern(t.depth==2);
                deepP    = t.avg_paired(t.depth==3);
                superP   = t.avg_paired(t.depth==2);
                for i = 1:length(unique(t.SN))
                    [j.int,j.slope] = intercept(deepAVG(i),deepP(i),superAVG(i),superP(i));
                    j.speed = spd;
                    j.SN = i;
                    J = addstruct(J,j);
                end 
            end
            %keyboard
            ttest(J.int(J.speed==4),[],1,'onesample')
            
            title(sprintf('%s',reg_title{roi}));
            ylabel('Avg. Distance between Finger Patterns');
            xlabel('Distance of Avg. Pattern from Baseline');
            xlim([0 0.4]);
            ylim([0 0.4]);
            %figure_scaleAllsubplots('axlims',[0 0.4]);

            hold off;
            %keyboard
            if do_anova
                anovaMixed(T.ratio,T.SN,'within',T.speed,{'speed'},'between',T.depth,{'depth'})
                subplot(1,2,2); 
                traceplot([1:4],[reshape(T.ratio(T.depth==2),[4,length(sn)])';...               % ratios for superficial depth
                                reshape(T.ratio(T.depth==3),[4,length(sn)])'],'split',...       % ratios for deeper depth
                    [ones(length(sn),1);ones(length(sn),1).*2],'errorfcn','stderr','leg',{'surface voxels','deep voxels'},...
                    'marker','o');
                xlabel('Pressing Frequency (Hz)')
                ylabel('AvgPaired / AvgPattern')
                ylim([0 2]);
                set(gca,'XTick',[1:4]);
                set(gca,'XTickLabels',{'0.3','0.6','1.3','2.6'});
            end
        
        else % if doing multiple rois...
            % copy figures of multiple rois to one figure space
            F1 = figure('NumberTitle','off','Color',[1 1 1]);
            for r=1:length(roi)
                fivedigitFreq2_imana('figure_DistDepthScaling','roi',roi(r),'do_anova',do_anova);
                
                if do_anova
                    subplot(2,1,1);  ax1_copy = copyobj(gca,F1); % copy axes
                    subplot(2,1,2);  ax2_copy = copyobj(gca,F1);
                    close gcf;
                    
                    F1; % plot copied axies to same figure handle
                    subplot(2,length(roi),r,ax1_copy); 
                    grid on
                    axis equal
                    
                    subplot(2,length(roi),r+length(roi),ax2_copy); 
                    
                else
                    ax1_copy = copyobj(gca,F1); % copy axes
                    close gcf;
                    
                    F1; % plot copied axies to same figure handle
                    subplot(1,length(roi),r,ax1_copy); 
                    grid on
                    axis equal
                end
                
            end
            set(gcf,'InvertHardcopy','off');
            %set(gcf,'PaperPosition',[2 2 8 2*length(roi)]);
            wysiwyg;
        end 
    case 'FIG_voxdepth'                                                     % plot voxel depth for each subject
        roi = 2;
        sn  = 2;
        vararginoptions(varargin,{'roi','sn'});
        
        figure;
        f = 1; % subplot counter
        for j = 1:length(sn)
            s = sn(j); % get subj number (useful if specifying non-incremental subjs)
            load(fullfile(regDir,sprintf('s0%d_regions.mat',s)));
            for r = roi
                d = R{r}.depth; % voxel depths
                % % plotting stuff
                subplot(length(sn),length(roi),f); 
                title(sprintf('Subj %d roi %d',s,r))
                hold on
                xlim([-1.5,2.5]); 
                ylim([-0.15,0.15]);
                set(gca,'YTick',[]);
                drawline(0,'dir','horz');
                plot(d,0,'kx','markersize',10);
                drawline([0,1],'dir','vert','color',[1 0 0],'lim',[-0.05,0.05]);
                drawline([0.5],'dir','vert','color',[0 0 1],'lim',[-0.05,0.05]);
                % add text for numvox at certain depth thresholds
                text([-0.5,0.5,1.5,0.25,0.75],[0.07,0.07,0.07,-0.07,-0.07],{sprintf('%d',sum(d<0)),... % above pial(0)
                                                      sprintf('%d',sum((d>=0)&(d<=1))),...  % between pial and white
                                                      sprintf('%d',sum(d>1)),...            % below white
                                                      sprintf('%d',sum((d>=0)&(d<=0.4999))),...  % superficial layer
                                                      sprintf('%d',sum((d>=0.5001)&(d<=1)))},... % deep layer
                                                      'interpreter','latex'); %latex makes nicer text
                % add text for surface types
                text([0,1],[-0.1,-0.1],{'pial','white'},'interpreter','latex'); 
                %--------------------------------%
                f=f+1; % increase subplot counter
                hold off
                %fprintf('vox between q2-q3: %d\n',sum((d>=0.25)&(d<=0.75)))
            end
        end

        %set(gcf,'PaperPosition',[2 2 3*length(sn) 3*length(roi)+0.5]);
        wysiwyg;
    case 'FIG_modelDists'                                                   % compute avg paired and avg pattern distance of models and observed data; plot 
        % Model distances are calculated from Group Level crossvalidated G 
        glm = 3;
        sn  = 10:13;
        roi = 2;
        subj_plots = 0; % plot observed dists for each subj in new figure
        layers = 1;
        vararginoptions(varargin,{'sn','glm','roi','subj_plots','layers'});

        Mt=[]; % pivottable structure

        % distance contrasts:
        fp_con  = indicatorMatrix('allpairs',[1:5]); % paired finger avg distance
        spd_con = ones(1,5)/5;                       % mean pattern distance

        for L = 1:layers % for each layer
        
            % load layer fit model G results
            load(fullfile(regDir,sprintf('fit_model_pcm_reg%d_L%d_glm%d.mat',roi,L,glm)));
            % also loads G_hat for each subject
            for i = 1:length(sn) % for each subject
                subj = sn(i);
                for m=1:4 % for each model
                    % model 1 : observed data
                    %   "   2 : scaling model
                    %   "   3 : additive model
                    %   "   4 : combo model
                    
                    for s = 1:4; % for each pressing condition
                        spd_indx= [1+((s*5)-5):5+((s*5)-5)]; % index of G values pertaining to this speed

                        % harvest appropriate G values with speed index:
                        if m==1 % if observed data, take from appropriate place
                            scaleP = 1; 
                            G = G_hat(spd_indx,spd_indx,i);  
                        else % if model predicted data
                            G = G_predCV{m}(spd_indx,spd_indx,i).*Tg.scale(i,m);
                        end
                        % calculate distances
                        Tt.avgPattern_dist = ssqrt(sum(sum((spd_con*G).*spd_con,2))); % distance of avg pattern from baseline
                        Tt.avgPaired_dist = mean(ssqrt(sum((fp_con*G).*fp_con,2)));   % avg distance of paired finger patterns
                        % add indexing fields in structure   
                        Tt.SN = subj;
                        Tt.model = m; % model 1 is observed data
                        Tt.speed = s;
                        Tt.layer = L;
                        Mt = addstruct(Mt,Tt);
                    end % for each movement speed
                end % for each "model"
            end; % for each subject
            % - - - - - - - - - - -
            % plot GROUP LVL 
            figure('NumberTitle','off','Name',sprintf('Layer: %s  %s Group Avg',layer_name{L},reg_title{roi})); 
            gc1 = gca;
            hold on;
            for m=1:4 % (3 fit models + 1 real data)
                for s=1:4
                    % harvesting LDCs in this manner because speed field is
                    % arranged 1:4 for each subject, not speed 1 of all subjs
                    Tt = getrow(Mt,Mt.model==m);
                    Tt = getrow(Tt,Tt.speed==s);
                    avgPattern(s) = mean(Tt.avgPattern_dist);
                    avgPaired(s)  = mean(Tt.avgPaired_dist);
                    if m==1 % used to plot each subject's observed distances
                        subj_avgPattern(s,:) = Tt.avgPattern_dist';
                    end
                end
                plot(gc1,avgPattern',avgPaired','LineWidth',2);
            end; % for each model 
            title(sprintf('GROUP LVL: All Voxels in %s',reg_title{roi}));
            xlabel('LDC of Avg Pattern Dist to Baseline');
            ylabel('Avg LDC of Finger Pairs (within speed)');
            legend({'Observed','Scaling','Additive','Combo'})
            %text([0.2],[0.08],{'All voxels'},'interpreter','latex'); %latex makes nicer text
            hold off;

            % plot SUBJECT AVG PATTERN DISTs (one line per subject)
            if subj_plots
                figure('NumberTitle','off','Name',sprintf('%s Subject Avg Pattern Dist',reg_title{roi})); 
                plot([1:4]',subj_avgPattern,'-o','LineWidth',1.5,'MarkerSize',8);
                xlim([0.5 4.5]);
                ylabel('avg. pattern dist from Baseline');
                xlabel('speed')
            end;
            eval(sprintf('L%d = Mt;',L));
            Mt = [];
        end; % for each layer plot    
    
    
    otherwise
        disp('NO SUCH CASE')
        
end % switch(what)
end


% Local Functions
function prefix = getCorrectPrefix(sn,prefix,step)
% Uses correct prefix for different subjects for each preprocessing step
if isempty(prefix)
    switch step
        case {'PREP_move_data','PREP_coreg','PREP_make_samealign','PREP_make_maskImage','GLM_make','PREP_meanimage_bias_correction'}
            p = {'','','r','','','','r','','','u','u','u','u','u','u','u','u'};
            prefix = p(sn);
    end
end    
end

function dircheck(dir)
% Checks existance of specified directory. Makes it if it does not exist.
% SA 01/2016
if ~exist(dir,'dir');
    %warning('%s didn''t exist, so this directory was created.\n',dir);
    mkdir(dir);
end
end

function [b,m] = intercept(x1,y1,x2,y2)
m = (y2-y1) / (x2-x1);
b = y1 - m*x1;
end

function new_conds = renumber_conds(old_conds)
% Makes condition_idx labels range from 1:length(unique(old_conds)).
% Ignores 0.
new_conds = zeros(size(old_conds));
kk = 1;
for jj = unique(old_conds)'
    if jj==0 % ignore zero entries
    else
        jj_indx = old_conds==jj;
        new_conds(jj_indx) = kk;
        kk = kk+1;
    end
end

end

