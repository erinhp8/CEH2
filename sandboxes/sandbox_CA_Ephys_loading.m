%% CA2 + ephys sandbox

%% add paths

close all
restoredefaultpath
global PARAMS

if isunix
    PARAMS.data_dir = '/Users/jericcarmichael/Documents/Williams_Lab/7_12_2019_PV1069_LTD5'; % where to find the raw data
    PARAMS.inter_dir = '/Users/jericcarmichael/Documents/Williams_Lab/Temp/'; % where to put intermediate files
    PARAMS.stats_dir = '/Users/jericcarmichael/Documents/Williams_Lab/Stats/'; % where to put the statistical output .txt
    PARAMS.code_base_dir = '/Users/jericcarmichael/Documents/GitHub/vandermeerlab/code-matlab/shared'; % where the codebase repo can be found
    PARAMS.code_CEH2_dir = '/Users/jericcarmichael/Documents/GitHub/CEH2'; % where the multisite repo can be found
else
 disp('on a PC')
end


rng(11,'twister') % for reproducibility


% add the required code
addpath(genpath(PARAMS.code_base_dir));
addpath(genpath(PARAMS.code_CEH2_dir));
cd(PARAMS.data_dir) % move to the data folder


%%  Laod some stuff

load('ms.mat');
% load('SFP.mat');


% %% make a video
% 
% for iframe =  1:size(SFP, 3)
%     
%     imagesc(SFP(:,:,iframe))
%     M(iframe) = getframe;
% end


%% GET nlx data
cfg = [];
cfg.fc = {'CSC1.ncs'}%, 'CSC8.ncs'};
csc = LoadCSC(cfg);

cfg = [];
evt = LoadEvents(cfg);
% all_evts = [evt.t{3} evt.t{4}];

%%
%restrict data to first recording of the session
csc_r = restrict(csc, evt.t{1}(1), evt.t{2}(1));
evt_r = restrict(evt, evt.t{1}(1), evt.t{2}(1));


% if evt_r.t{3}(1) < evt_r.t{4}(1)
%     all_evts_r = [evt_r.t{3} evt_r.t{4}];
% elseif evt_r.t{3}(1) > evt_r.t{4}(1)
%     all_evts_r = [evt_r.t{4} evt_r.t{3}];
% elseif evt_r.t{3}(1) == evt_r.t{4}(1)
%     warning(['Event times for ' evt_r.label{3} ' are somehow equal to ' evt_r.label{4} '.  Check into this...'])
% end

%% correct for recording time (just to make things easier)
for ii = 1:length(evt_r.t)
    evt_r.t{ii} = evt_r.t{ii} - csc_r.tvec(1);
end

    all_evts_r = sort([evt_r.t{3} evt_r.t{4}]);


all_evts_r = all_evts_r - csc_r.tvec(1);

csc_r.tvec = csc_r.tvec - csc_r.tvec(1);

%% get some recording periods
peak_threshold = 50;
[~, Rec_ts] = findpeaks(diff(all_evts_r), 'minpeakheight',peak_threshold);
fprintf(['\nDetected %.0f trigger transitions treating this as %.0f distinct recordings\n'], length(Rec_ts), length(Rec_ts)/2)

% plot the events and trasitions
figure(1)
hold on
plot(diff(all_evts_r), 'k')
hline(peak_threshold, '--r')
plot(Rec_ts, 100, '*k')

% break them into recording sessions
t_start = Rec_ts(1:2:end-1);
t_end = Rec_ts(2:2:end);


plot([t_start ; t_end]', [50 50], '-b')
%% plot
figure(8)

% plot(csc.tvec(1:10000), csc.data(1,1:10000), csc.tvec(1:10000), csc.data(2,1:10000),evt.t{3}, '*k' )
% t_start = nearest_idx3(csc.tvec, evt.t{3}(1));
% t_end = nearest_idx3(csc.tvec, evt.t{3}(end));

%
plot(csc_r.tvec, csc_r.data(1,:))
% convert x axis to reasonable time units.  In this case hours
% x_val = get(gca, 'xtick');
% set(gca, 'xticklabel', round(((x_val - x_val(1))/60)/60,1))


hold on
plot(all_evts_r,max(csc_r.data(1,:)), '*k' )
% plot(evt.t{4},max(csc_r.data(1,:)), '*c' )


