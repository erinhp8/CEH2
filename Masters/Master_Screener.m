%% Master_Sub_Screener:  master control script for batch screening cells for spatial informaiton.
%
%
%  To run:  set up your desired directories in the below section and it
%  will process all the sessions in the data_dir. All figures will be saved
%  in the inter_dir along with the intermediate files. Nothing will be
%  written back to the data_dir.
%
%  % this uses PARAMS as a global parameter that can be called across
%  functions.  It is mostly used for tracking directories and colours. 
%
% EC 2021-01-02   initial version for subiculum screening.
%
%  TODO:
%   - make the initial data dir selection simple.  
%
%% initialize


close all
restoredefaultpath
global PARAMS  % these are global parameters that can be called into any function.  I limit these to directories for storing, loading, and saving files and codebases.
os = computer;

if ismac
    %     PARAMS.data_dir = '/Users/jericcarmichael/Documents/Williams_Lab/2019-12-04_11-10-01_537day0base1'; % where to find the raw data
    %     PARAMS.inter_dir = '/Users/jericcarmichael/Documents/Williams_Lab/Temp/'; % where to put intermediate files
    %     PARAMS.stats_dir = '/Users/jericcarmichael/Documents/Williams_Lab/Stats/'; % where to put the statistical output .txt
    %     PARAMS.code_base_dir = '/Users/jericcarmichael/Documents/GitHub/vandermeerlab/code-matlab/shared'; % where the codebase repo can be found
    %     PARAMS.code_CEH2_dir = '/Users/jericcarmichael/Documents/GitHub/CEH2'; % where the multisite repo can be found
    %
elseif strcmp(os, 'GLNXA64')
    
    %     PARAMS.data_dir = '/home/ecarmichael/Documents/Williams_Lab/2019-12-04_11-10-01_537day0base1'; % where to find the raw data
    PARAMS.data_dir = '/mnt/Data/Williams_Lab/II_classification/msbehavplace/ck2cre1'; % where to find the raw data
    %     PARAMS.raw_data_dir = '/home/ecarmichael/Documents/Williams_Lab/Raw_data/EV/';
    %         PARAMS.raw_data_dir = '/home/ecarmichael/Documents/Williams_Lab/Raw_data/JC/'; % raw data location.
    PARAMS.inter_dir = '/mnt/Data/Williams_Lab/II_classification/Inter/'; % where to put intermediate files
    PARAMS.stats_dir = '/mnt/Data/Williams_Lab/II_classification/Inter/'; % where to put the statistical output .txt
    PARAMS.code_base_dir = '/home/ecarmichael/Documents/GitHub/vandermeerlab/code-matlab/shared'; % where the codebase repo can be found
    PARAMS.code_CEH2_dir = '/home/ecarmichael/Documents/GitHub/CEH2'; % where the multisite repo can be found
    %
else
    PARAMS.data_dir = 'J:\Williams_Lab\II_classification'; % where to find the raw data
    PARAMS.raw_data_dir = 'J:\Williams_Lab\II_classification'; % raw data location.
    PARAMS.inter_dir = 'J:\Williams_Lab\II_classification\Inter'; % where to put intermediate files
    PARAMS.stats_dir = 'J:\Williams_Lab\II_classification\Inter\Stats'; % where to put the statistical output .txt
    PARAMS.code_base_dir = 'C:\Users\ecarm\Documents\GitHub\vandermeerlab\code-matlab\shared'; % where the codebase repo can be found
    PARAMS.code_CEH2_dir = 'C:\Users\ecarm\Documents\GitHub\CEH2'; % where the multisite repo can be found
    PARAMS.code_seqnmf_dir = 'C:\Users\ecarm\Documents\GitHub\seqNMF'; % where the multisite repo can be found
    
end

% colours
PARAMS.L_grey = [0.8 0.8 0.8];
PARAMS.D_grey = [0.2 0.2 0.2];
PARAMS.blue = [0.3639    0.5755    0.7484];
PARAMS.red = [0.9153    0.2816    0.2878];
PARAMS.green= [0.4416    0.7490    0.4322];
PARAMS.gold = [1.0000    0.5984    0.2000];

rng(11,'twister') % for reproducibility


% add the required code
addpath(genpath(PARAMS.code_base_dir));
addpath(genpath(PARAMS.code_CEH2_dir));
cd(PARAMS.data_dir) % move to the data folder

% make the Inter and Stats dir if they don't exist.
if ~exist(PARAMS.stats_dir,'dir')
    mkdir(PARAMS.stats_dir)
end

clear d os
beep off % I know when I mess up without that annoying beep, thanks.

% configuration 
%general
cfg.binary_thresh = 2; % number of sd for binary thresholding of zscored Ca data. 

% place
cfg.p_thres = 0.05; % value for pvalue cut off;
cfg.stability_thres = 0.5; % from van der Veldt 2020
cfg.nShuff = 200;
cfg.p_bin_size = 3 ; % in cm
cfg.split_gaus_sd = 3; % sd for gaussian smoothing of place tuning for split session xcorr.

% speed
cfg.s_bin_size = 1.375;
cfg.s_bins  =  2.5:cfg.s_bin_size:30; % between -2cm/s^2 and 2cm/s^s with 20 bins matches van de Veldt et al. 2020
cfg.s_bins(cfg.s_bins==0) = []; %remove 0 bin.

% acceleration
cfg.accel_bin_size = .2;
cfg.accel_bins  =  -2:cfg.accel_bin_size:2; % between -2cm/s^2 and 2cm/s^s with 20 bins matches van de Veldt et al. 2020
cfg.accel_bins(cfg.accel_bins==0) = []; %remove 0 bin.

%% navigate the desired directory.
% get all the sub folders in the dir. ex:  current dir 'ck2cre1'  contains
% '8-24-20', '8-25-20','8-26-20',...

parent_dir = cd; % keep the name of the main folder.

sess_list = {};
d = dir;
d=d(~ismember({d.name},{'.','..', '._*'})); % get the folder names and exclude any dir that start with '.'.
for iSess = 1:length(d)
    if ~strcmp(d(iSess).name(1:2), '._') % exclude any that are autosaves.
        sess_list{end+1} = d(iSess).name; % keep the good folder names.
    end
end

% loop across sessions.
for iSess = 3:length(sess_list) % loop through sessions for this subject.
    
    cd([parent_dir filesep sess_list{iSess}])
    
    % if there are multiple tasks in the day then loop through them.
    if ~exist('ms.mat')
        task_list = {};
        d = dir;
        d=d(~ismember({d.name},{'.','..', '._*'})); % get the folder names and exclude any dir that start with '.'.
        for this_Sess = 1:length(d)
            if ~strcmp(d(this_Sess).name(1:2), '._') % exclude any that are autosaves.
                task_list{end+1} = d(this_Sess).name; % keep the good folder names.
            end
        end
        
    else
        task_list{1} = sess_list{iSess}; % if this is the data folder (only one task that day, then just go here;
        
    end
    
    % loop through tasks in a session (if any)
    for iTask = 1:length(task_list) % loop through tasks in a session.
        cd([parent_dir filesep sess_list{iSess} filesep task_list{iTask}])
        %% get the file info
        parts = strsplit(cd, filesep);
        
        sess_parts = strsplit(strrep(parts{end}, '-', '_'), '_') ;
        
        fname = parts{end};
        f_info.subject = sess_parts{1};
        f_info.date = datestr(parts{end-1}, 'yyyy-mm-dd');
        f_info.task = sess_parts{2};
        f_info.time = datestr([sess_parts{end-2}(2:end),':', sess_parts{end-1}(2:end),':',sess_parts{end}(2:end)],'HH:MM:SS');
        f_info.fname = fname; % full name. 
        
        
        %% run the screening script 
        
        % TODO help this function handle LT data as 1D. maybe as a cfg?
        These_cells{iSess, iTask} = Spatial_screener(cfg, f_info); 
        
        close all
    end % end tasks
    
end %sessions
