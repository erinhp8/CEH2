%% CA2 + ephys sandbox

%% add paths

close all
restoredefaultpath
global PARAMS
os = computer;

if ismac
    PARAMS.data_dir = '/Users/jericcarmichael/Documents/Williams_Lab/7_12_2019_PV1069_LTD5'; % where to find the raw data
    PARAMS.inter_dir = '/Users/jericcarmichael/Documents/Williams_Lab/Temp/'; % where to put intermediate files
    PARAMS.stats_dir = '/Users/jericcarmichael/Documents/Williams_Lab/Stats/'; % where to put the statistical output .txt
    PARAMS.code_base_dir = '/Users/jericcarmichael/Documents/GitHub/vandermeerlab/code-matlab/shared'; % where the codebase repo can be found
    PARAMS.code_CEH2_dir = '/Users/jericcarmichael/Documents/GitHub/CEH2'; % where the multisite repo can be found
    
elseif strcmp(os, 'GLNXA64')
    
    PARAMS.data_dir = '/home/ecarmichael/Documents/Williams_Lab/7_12_2019_PV1069_LTD5'; % where to find the raw data
    PARAMS.inter_dir = '/home/ecarmichael/Documents/Williams_Lab/Temp/'; % where to put intermediate files
    PARAMS.stats_dir = '/home/ecarmichael/Documents/Williams_Lab/Stats/'; % where to put the statistical output .txt
    PARAMS.code_base_dir = '/home/ecarmichael/Documents/GitHub/vandermeerlab/code-matlab/shared'; % where the codebase repo can be found
    PARAMS.code_CEH2_dir = '/home/ecarmichael/Documents/GitHub/CEH2'; % where the multisite repo can be found
    
else
    disp('on a PC')
end


rng(11,'twister') % for reproducibility


% add the required code
addpath(genpath(PARAMS.code_base_dir));
addpath(genpath(PARAMS.code_CEH2_dir));
cd(PARAMS.data_dir) % move to the data folder

% try the newer NLX loaders for UNIX
[~, d] = version;
if str2double(d(end-3:end)) >2014
    rmpath('/Users/jericcarmichael/Documents/GitHub/vandermeerlab/code-matlab/shared/io/neuralynx')
    addpath(genpath('/Users/jericcarmichael/Documents/NLX_loaders_UNIX_2015'))
    disp('Version is greater than 2014b on UNIX so use updated loaders found here:')
    which Nlx2MatCSC
end

clear d os
%%  Laod some stuff
tic
load('ms.mat');
% load('SFP.mat');
% TS = MS_Load_TS('timestamp.dat');

% [MS_ts.camNum,MS_ts.frameNum,MS_ts.sysClock,MS_ts.buffer1] = MS_Load_TS('timestamp.dat');

% %% make a video
%
% for iframe =  1:size(SFP, 3)
%
%     imagesc(SFP(:,:,iframe))
%     M(iframe) = getframe;
% end

toc
%% load MS timestamps
cfg_ts = [];
% cfg_ts.fname = {'timestamp12.dat'};
cfg_ts.correct_time = 1;

TS= MS_Load_TS(cfg_ts);

all_TS_vals = [];
fprintf('\n****Comparing TS files to processed miniscope (ms) data\n')
for iT = 1:length(TS)
    if length(TS{iT}.system_clock{1}) == ms.timestamps(iT)
        disp([TS{iT}.filename   ':  ' num2str(length(TS{iT}.system_clock{1}))   ' - ms TS: ' num2str(ms.timestamps(iT))  '   ~ ' num2str(length(TS{iT}.system_clock{1}) / TS{iT}.cfg.Fs{1}) 's'])
    else
        warning(['TS do not match ms data' TS{iT}.filename   ':  ' num2str(length(TS{iT}.system_clock{1}))   ' - ms TS: ' num2str(ms.timestamps(iT))])
    end
    all_TS_vals = [all_TS_vals; TS{iT}.system_clock{end}];
end

% TS2 = MS_Load_TS('timestamp2.dat');

% [TS, CAMNUM,FRAMENUM,SYSCLOCK,BUFFER1] = MS_Load_TS('timestamp.dat');

% if length(unique(CAMNUM))
% this_cam = 0;
%     for ii = unique(CAMNUM)'
% %         disp(ii)
%         this_cam = this_cam+1;
%         idx = CAMNUM == ii;
%     TS.CAMNUM{this_cam} = CAMNUM(idx);
%     TS.FRAMENUM{this_cam} = FRAMENUM(idx);
%     TS.SYSCLOCK{this_cam} = SYSCLOCK(idx);
%     TS.BUFFER1{this_cam} = BUFFER1(idx);
%
%     end


%% GET nlx data

check = 1;

tic
cfg = [];
cfg.fc = {'CSC1.ncs'}%,'CSC6.ncs', 'CSC8.ncs'};
cfg.decimateByFactor = 8;
csc = LoadCSC(cfg);

% csc = restrict(csc, 1, 50000);

if check == 1
    len = 1:4000;
    figure(101)
    subplot(2,1,1)
    tvec = csc.tvec(len) - csc.tvec(1);
    offset = 0.0002;
    hold on
    for iC = 1:length(csc.label)
        plot(tvec, csc.data(iC,len)+(offset*iC))
    end
end

% filter into the theta band
cfg_filt = [];
% cfg_filt.f = [5 11]; %setting theta (hertz)
cfg_filt.type = 'cheby1'; %the type of filter I want to use via filterlfp
cfg_filt.f  = [6 11];
cfg_filt.order = 3; %type filter order
% cfg_filt.display_filter = 1; % use this to see the fvtool (but very slow
% with ord = 3 for some reason.  Looks like trash with ord ~= 3 in cheby1.
% Butter and fdesign are also trash.
theta_csc = FilterLFP(cfg_filt, csc);

% % alternative filtering (not used, just a check)
%
% Fs = csc.cfg.hdr{1}.SamplingFrequency;
% Wp = [ 6 11] * 2 / Fs;
% Ws = [ 4 13] * 2 / Fs;
% [N,Wn] = cheb1ord( Wp, Ws, 3, 20); % determine filter parameters
% [b_c1,a_c1] = cheby1(N,0.5,Wn); % builds filter
% csc_filtered = filtfilt(b_c1,a_c1,csc.data(1,:));



if check ==1
    figure(101)
    subplot(2,1,2)
    
    hold on
    tvec = theta_csc.tvec(len) - theta_csc.tvec(1);
    hold on
    offset = 0.0002;
    for iC = 1:length(theta_csc.label)
        plot(tvec, abs(hilbert(theta_csc.data(iC,len)))+(offset*iC))
        plot(tvec, abs(theta_csc.data(iC,len))+(offset*iC))
    end
end

cfg = [];
evt = LoadEvents(cfg);
evt.t{length(evt.t)+1} = unique(sort([evt.t{3} evt.t{4}]));
evt.label{length(evt.label)+1} = 'all_evt';

% get the recording start time from NLX header
if isfield(csc.cfg.hdr{1}, 'TimeCreated')
    NLX_start = csc.cfg.hdr{1}.TimeCreated; % find the creation time as a string
    if contains(NLX_start, ':')
        NLX_start = duration(str2double(strsplit(NLX_start(end-8:end),':'))); % pull out hours:mins:sec and convert to a time
    else
        NLX_start = duration([NLX_start(end-5:end-4) ':' NLX_start(end-3:end-2) ':' NLX_start(end-1:end)]); % pull out hours:mins:sec and convert to a time
    end
end

% identify major jumps in evts

%  all_jumps = diff(evt.t{5}) > (mean(diff(evt.t{5}) +0.5*std(diff(evt.t{5}))));
%  all_jumps(1) = 0; % correct for first jump;
%  jump_idx = find(all_jumps ==1);
%  rec_evt = [];
%  if sum(all_jumps) > 0 && sum(all_jumps) <2
%      fprintf('Jump found at time: %.0f\n', evt.t{5}(jump_idx))
%
%      rec_evt{1} = restrict(evt, evt.t{5}(1), evt.t{5}(jump_idx)); % add one index to compensate for the diff.
%      rec1_csc = restrict(csc, evt.t{5}(1), evt.t{5}(jump_idx));
%
%      rec_evt{2} = restrict(evt, evt.t{5}(jump_idx+1), evt.t{5}(end));
%      rec2_csc = restrict(csc, evt.t{5}(jump_idx+1), evt.t{5}(end));
%
%  elseif sum(all_jumps) >2
%
%      for iJ = length(jump_idx):-1:1
%          if iJ ==1
%              rec_evt{iJ} = restrict(evt, evt.t{5}(1), evt.t{5}(jump_idx(iJ)));
% %              rec_csc{iJ} = restrict(csc, evt.t{5}(1), evt.t{5}(jump_idx(iJ)));
%          else
%              rec_evt{iJ} = restrict(evt, evt.t{5}(jump_idx(iJ-1)), evt.t{5}(jump_idx(iJ)));
% %              rec_csc{iJ} = restrict(csc, evt.t{5}(jump_idx(iJ-1)), evt.t{5}(jump_idx(iJ)));
%          end
%      end
%  end
toc

%% if the TSs align with the evt then add it in as a subfield [works for EVA only]
for iE = 1:length(rec_evt)
    this_cam = 2;
    if length(rec_evt{iE}.t{5})== length(TS{iE}.system_clock{this_cam})
        disp(['TS and evts align! for Timestamp: ' TS{iE}.filename])
        TS{iE}.NLX_ts = rec_evt{iE}.t{5}';
        TS{iE}
    else
        warning(['TS and evt do not align for Timestamp: ' TS{iE}.filename])
    end
end

% maybe find jumps and fill them in?
TS_cam_mode = mode(diff(TS{iE}.system_clock{1}(2:end)));
% for iEvt = length(TS{iE}.system_clock{1}):-1:2

%     if TS{iE}.system_clock{1}(iEvt) - TS{iE}.system_clock{1}(iEvt-1)

% make a interpolated signal to see where things are missing
ts_norm = [0 ;TS{1}.system_clock{2}(2:end)]';
evt_norm = rec_evt{1}.t{5} - rec_evt{1}.t{5}(1);


%% check length of TSs
disp('TS1')
for this_cam = 1:length(TS.system_clock)
    fprintf('Number of Scope TS id: %.0f  =   %.0f  at %0.2f Hz\n',this_cam, length(TS.system_clock{this_cam}), 1/(median(diff(TS.system_clock{this_cam}(2:end)))*0.001))
end


disp('Rec1')
for this_evt = 3:length(rec1_evt.label) % correct for start and stop recording.
    fprintf('Number of evt evts id: %.0f  =   %.0f at %0.2f Hz\n',this_evt, length(rec1_evt.t{this_evt}),1/(median(diff(rec1_evt.t{this_evt}))))
end

disp('TS2')
for this_cam = 1:length(TS2.system_clock)
    fprintf('Number of Scope TS id: %.0f  =   %.0f  at %0.2f Hz\n',this_cam, length(TS2.system_clock{this_cam}), 1/(median(diff(TS2.system_clock{this_cam}(2:end)))*0.001))
end

disp('Rec2')
for this_evt = 3:length(rec2_evt.label) % correct for start and stop recording.
    fprintf('Number of evt evts id: %.0f  =   %.0f at %0.2f Hz\n',this_evt, length(rec2_evt.t{this_evt}),1/(median(diff(rec2_evt.t{this_evt}))))
end


disp('All evt')
for this_evt = 3:length(evt.label) % correct for start and stop recording.
    fprintf('Number of evt evts id: %.0f  =   %.0f at %0.2f Hz\n',this_evt, length(evt.t{this_evt}),1/(median(diff(evt.t{this_evt}))))
end

% fprintf('Number of NLX events: %.0f, Number of Scope TS: %.0f, Difference: %.0f\n', length(evt.t{this_evt}), length(TS.SYSCLOCK{this_cam}(2:end)), length(evt.t{this_evt}) -  length(TS.SYSCLOCK{this_cam}(2:end)));


%% give new TS to MS data
% if things checkout
TS2.NLX_tvec{2} = rec2_evt.t{5}';
TS2.NLX_tvec{1} = interp(rec2_evt.t{5}, 2)';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% for JISU DATA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % try plotting all of TS events as an array but with different colors for
% % each section
% all_ts = []; all_ys = []; this_val = 0.5;
% % colors = repmat({'r', 'b', 'g', 'c'},1,length(TS))
% for iT = 1:length(TS)
%     all_ts = [all_ts, TS{iT}.system_clock{1}'];
%     if this_val >0
%         all_ys = [all_ys, repmat(this_val,1, length(TS{iT}.system_clock{1}'))];
%         this_val = -.5;
%     elseif this_val <0
%                 all_ys = [all_ys, repmat(this_val,1, length(TS{iT}.system_clock{1}'))];
%                 this_val =.5 ;
%     end
% %     all_ys = [all_ys, repmat(iT, 1, length( TS{iT}.system_clock{1}'))];
% end

%% flag the longest part of the TS and flag it as a track sesson as it's own TS structure

for iT = 1:length(TS)
    all_TS_size(iT) = length(TS{iT}.system_clock{end});
    cam_ids(iT,:) = unique(TS{iT}.camera_id{end});
end

[largest_TS, idx] = max(all_TS_size);

fprintf('\nLargest TS segment is %.0f samples ~ %0.2f mins  cam ID: %.0f\n', largest_TS, (largest_TS/TS{idx}.cfg.Fs{end})/60, cam_ids(idx))

% remove the largest from the TS structure and put it in a new one

% make new TS for track
TS_track{1} = TS{idx};
% now remove it
TS(idx) = [];






%% identify peaks in  diff(evt.t{5}) marking transitions in the camera TTLs
peak_threshold =  (mean(diff(evt.t{5}) +0.05*std(diff(evt.t{5}))));
min_dist = 10;
[Rec_peak, Rec_idx] = findpeaks(diff(evt.t{5}), 'minpeakheight',peak_threshold, 'minpeakdistance', min_dist);
fprintf(['\nDetected %.0f trigger transitions treating this as %.0f distinct recordings\n'], length(Rec_idx), length(Rec_idx))


% plot the diff and the detected peaks as a check.
figure(1)
hold on
plot(diff(evt.t{5}), 'k')
hline(peak_threshold, '--r')
% plot(Rec_idx, 100, '*k')
for iRec = 1:length(Rec_idx)
    % text(Rec_idx(iRec),Rec_peak(iRec),num2str(iRec))
    text(Rec_idx(iRec),peak_threshold,num2str(iRec))
    
end


% t_start = Rec_idx(1:2:end-1);
% t_end = Rec_idx(2:2:end);
% plot([t_start ; t_end]', [50 50], '-b')

%% check the transitions for jumps and compare them to the TS times.  It seems like the TTL can have gitter around the transition periods.

for iRec = 1:length(Rec_idx)
    
    low_val = 10;
    high_val = -10;
    idx_low = NaN; % initialize with something.
    idx_high = NaN;
    
    if iRec == 1
        
        while ~isempty(idx_high)
            temp_evt = restrict(evt, evt.t{5}(Rec_idx(iRec)), evt.t{5}(Rec_idx(iRec+1)+high_val));
            %     idx_low =find(diff(temp_evt.t{5}(1:50)) > mode(diff(temp_evt.t{5}))*1.05)
            idx_high =find(diff(temp_evt.t{5}(end-11:end)) > mode(diff(temp_evt.t{5}))*1.05)
            high_val = high_val +1;
        end
        
        disp(['Corrected indexting ' num2str(0) ' - ' num2str(high_val)])
        
        times_to_use(iRec,:) = [0, high_val]; % keep the good values for restrictions in the next ce
        
        
    elseif iRec == length(Rec_idx)
        
        while ~isempty(idx_low)
            temp_evt = restrict(evt, evt.t{5}(Rec_idx(iRec)-low_val), evt.t{5}(Rec_idx(end)));
            idx_low =find(diff(temp_evt.t{5}(1:11)) > mode(diff(temp_evt.t{5}))*1.05)
            %     idx_high =find(diff(temp_evt.t{5}(end-50:end)) > mode(diff(temp_evt.t{5}))*1.05);
            low_val = low_val - 1;
        end
        
        
        disp(['Corrected indexting ' num2str(low_val) ' - ' num2str(0)])
        
        times_to_use(iRec,:) = [low_val, 0]; % keep the good values for restrictions in the next cell.
        
    else
        
        
        
        % loop until you find the index offset that gives no jump in time. for
        % start
        while ~isempty(idx_low)
            temp_evt = restrict(evt, evt.t{5}(Rec_idx(iRec)-low_val), evt.t{5}(Rec_idx(iRec+1)+high_val));
            idx_low =find(diff(temp_evt.t{5}(1:11)) > mode(diff(temp_evt.t{5}))*1.05)
            %     idx_high =find(diff(temp_evt.t{5}(end-50:end)) > mode(diff(temp_evt.t{5}))*1.05);
            low_val = low_val - 1;
        end
        
        % loop until you find the index offset that gives no jump in time. for
        % end
        while ~isempty(idx_high)
            temp_evt = restrict(evt, evt.t{5}(Rec_idx(iRec)-low_val), evt.t{5}(Rec_idx(iRec+1)+high_val));
            %     idx_low =find(diff(temp_evt.t{5}(1:50)) > mode(diff(temp_evt.t{5}))*1.05)
            idx_high =find(diff(temp_evt.t{5}(end-11:end)) > mode(diff(temp_evt.t{5}))*1.05)
            high_val = high_val +1;
        end
        
        disp(['Corrected indexting ' num2str(low_val) ' - ' num2str(high_val)])
        
        times_to_use(iRec,:) = [low_val, high_val]; % keep the good values for restrictions in the next cell.
    end
end




%% make some EVT blocks corresponding to the transitions and chop the data

% allocate nCells
rec_evt = cell(length(Rec_idx),1);
rec_csc = cell(length(Rec_idx),1);
rec_theta = cell(length(Rec_idx),1);

% restrict to the recording period and put them in cells. for events:
% 'evt', raw lfp : 'csc', filtered lfp = 'theta'
for iRec = 1:length(Rec_idx)
    if iRec < length(Rec_idx)
        rec_evt{iRec} = restrict(evt, evt.t{5}(Rec_idx(iRec)-times_to_use(iRec,1)), evt.t{5}(Rec_idx(iRec+1)+times_to_use(iRec,2))); % restrict the NLX evt struct to ms TTL periods
        rec_csc{iRec} = restrict(csc, evt.t{5}(Rec_idx(iRec)+2), evt.t{5}(Rec_idx(iRec+1)-1)); % same for the csc
        rec_theta{iRec} = restrict(theta_csc, evt.t{5}(Rec_idx(iRec)+2), evt.t{5}(Rec_idx(iRec+1)-1)); % same for the csc
        
    else
        rec_evt{iRec} = restrict(evt, evt.t{5}(Rec_idx(iRec)-times_to_use(iRec,1)), evt.t{5}(end)); % restrict the NLX evt file (last only)
        rec_csc{iRec} = restrict(csc, evt.t{5}(Rec_idx(iRec)+2), evt.t{5}(end)); % same for csc
        rec_theta{iRec} = restrict(theta_csc, evt.t{5}(Rec_idx(iRec)+2), evt.t{5}(end)); % same for csc
    end
end

%% check for jumps in TS files
for iT = 1:length(TS)
    fprintf('TS %s mode diff = %.0f max diff = %.0f\n', TS{iT}.filename, mode(diff(TS{iT}.system_clock{end})), max(diff(TS{iT}.system_clock{end})))
end

%% check length of TSs
all_evt = 0;
for iRec = 1:length(rec_evt)
    %     disp(['Rec ' num2str(iRec)])
    for this_evt = length(rec_evt{iRec}.label) % correct for start and stop recording.
        fprintf('Number of evts id: %.0f  =   %.0f samples at %0.2f Hz. Start at: %s for ~%.1fs \n',iRec, length(rec_evt{iRec}.t{this_evt}),1/(median(diff(rec_evt{iRec}.t{this_evt}))),...
            char(NLX_start + minutes((rec_evt{iRec}.t{this_evt}(1)  - csc.tvec(1))/60)), length(rec_evt{iRec}.t{this_evt})/(1/(median(diff(rec_evt{iRec}.t{this_evt})))))
    end
    all_evt = all_evt + length(rec_evt{iRec}.t{this_evt});
    all_evt_lens(iRec) = length(rec_evt{iRec}.t{this_evt});
end

all_TS = 0;
for iRec = 1:length(TS)
    %     disp(['TS ' num2str(iRec)])
    fprintf('Number of Scope TS id: %.0f  =   %.0f  at %0.2fHz for %.f sec\n',iRec, length(TS{iRec}.system_clock{1}), 1/(median(diff(TS{iRec}.system_clock{1}(2:end)))*0.001),...
        length(TS{iRec}.system_clock{1})/ (1/(median(diff(TS{iRec}.system_clock{1}(2:end)))*0.001)))
    all_TS = all_TS + length(TS{iRec}.system_clock{1});
    all_TS_len(iRec) = length(TS{iRec}.system_clock{1});
    
end

fprintf('All EVT: %.0f  All TS: %.0f', all_evt, all_TS)

disp('All evt')
for this_evt = 3:length(evt.label) % correct for start and stop recording.
    fprintf('Number of evt evts id: %.0f  =   %.0f at %0.2f Hz\n',this_evt, length(evt.t{this_evt}),1/(median(diff(evt.t{this_evt}))))
end

% fprintf('Number of NLX events: %.0f, Number of Scope TS: %.0f, Difference: %.0f\n', length(evt.t{this_evt}), length(TS.SYSCLOCK{this_cam}(2:end)), length(evt.t{this_evt}) -  length(TS.SYSCLOCK{this_cam}(2:end)));

% compare
disp('Compare')

for iRec = 1:length(rec_evt)
    %     disp(['Rec ' num2str(iRec)])
    for this_evt = length(rec_evt{iRec}.label) % correct for start and stop recording.
        fprintf('Evts id: %.0f = %.0f samples fs ~ %.1f  || TS id: %.0f = %.0f samples fs ~ %.1f\n',iRec, length(rec_evt{iRec}.t{this_evt}),mode(diff(rec_evt{iRec}.t{this_evt}))*1000,iRec, length(TS{iRec}.system_clock{end}), mode(diff(TS{iRec}.system_clock{end})))
    end
    evt_TS_diff(iRec) = length(rec_evt{iRec}.t{this_evt}) - length(TS{iRec}.system_clock{end});
end
evt_TS_diff % print the offset
%% restrict data to first recording of the session

% try to segment the ms structure
ms_seg = MS_segment_ms_sandbox(ms);


% remove the track segment

ms_seg = MS_remove_data_sandbox(ms_seg, [idx]);

% append restricted csc files
ms_seg = MS_append_data_sandbox(ms_seg, 'csc', rec_csc');

% appened a theta filtered signal

ms_seg = MS_append_data_sandbox(ms_seg, 'theta_csc', rec_theta');

%% Plot some examples of segments

%%%%%%%%%%%%%% this isn't lining up !! %%%%%%%%%%%%%%%%%%%%%%%%%%%

figure(111)

this_seg = 1;


ax(1) =subplot(2,1,1);
timein = (ms_seg.theta_csc{this_seg}.tvec - ms_seg.theta_csc{this_seg}.tvec(1)); % just to fix the timing offset between them back to ebing relative to this segment.
% timein = timein

plot(timein, abs(hilbert(ms_seg.theta_csc{this_seg}.data)), '--r');
hold on
plot(timein,ms_seg.theta_csc{this_seg}.data, '-b' );
xlim([timein(1), timein(end)])

ax(2) =subplot(2,1,2);
time_in2 = ms_seg.time{this_seg} - ms_seg.time{this_seg}(1);
plot(time_in2*0.001, ms_seg.RawTraces{this_seg}(:,1:5))
xlim([time_in2(1)*0.001 time_in2(end)*0.001])

linkaxes(ax, 'x')

%% correct for recording time (just to make things easier)
% for ii = 1:length(evt_r.t)
%     evt_r.t{ii} = evt_r.t{ii} - csc_r.tvec(1);
% end

all_evts_r = unique(sort(evt.t{5}));

% set a max cutoff_just for plotting


% all_evts_r = all_evts_r - csc_r.tvec(1);

% csc_r.tvec = csc_r.tvec - csc_r.tvec(1);

%% get some recording periods
peak_threshold = 5;
[~, Rec_idx] = findpeaks(diff(all_evts_r), 'minpeakheight',peak_threshold);
fprintf(['\nDetected %.0f trigger transitions treating this as %.0f distinct recordings\n'], length(Rec_idx), length(Rec_idx)/2)

% plot the events and trasitions
figure(1)
hold on
plot(diff(all_evts_r), 'k')
hline(peak_threshold, '--r')
plot(Rec_idx, 100, '*k')

% break them into recording sessions
t_start = Rec_idx(1:2:end-1);
t_end = Rec_idx(2:2:end);


plot([t_start ; t_end]', [50 50], '-b')

% convert identified peaks back into a time domain
Rec_intervals = all_evts_r(Rec_idx);
Inter_start = Rec_intervals(1:2:end-1);
Inter_end = Rec_intervals(2:2:end);

Rec_time_from_start = Rec_intervals  - csc.tvec(1);

for ii = 1: length(Inter_start)
    if ii  ==1
        time_since = minutes((Inter_start(ii)  - csc.tvec(1))/60);
    else
        time_since = minutes(((Inter_start(ii)- csc.tvec(1)) - (Inter_end(ii-1) - csc.tvec(1)))/60);
    end
    fprintf('\nDetected intervals %.0f started at %s, %s since last Ca2 recording, and was %.2f minutes long',ii, char(NLX_start + minutes((Inter_start(ii)  - csc.tvec(1))/60)),char(time_since),  (Inter_end(ii) - Inter_start(ii))/60)
end
fprintf('\n')

fprintf('Number of recording sessions from Ca2+ MS file: %.0f\n', length(ms.timestamps))




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


