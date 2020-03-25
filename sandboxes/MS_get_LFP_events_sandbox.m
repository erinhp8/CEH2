function events_out = MS_get_LFP_events_sandbox(cfg_in, csc)
%% MS_get_LFP_events_sandbox: WIP pipeline for rapid event detection in LFP data. 
%
%
%
%    Inputs: 
%     - cfg_in: [struct]    contains configuration (cfg) 
%           see defaults in cfg_def below.  These will be overwritten by
%           the same field names in the input. 
%
%     - csc [struct]        contains continously sampled channel (csc) data.  Should be
%           in the tsd format from MS_LoadCSC. Ideally this data should be
%           at 2000hz as this is what the built-in filters have been
%           optimized for.  Data with a higher sampling rate can be
%           decimated in the MS_LoadCSC function using
%           cfg.desired_sampling_frequency = 2000. 
%
%
%
%    Outputs: 
%     - events_out: [struct]   contains timestamps for the start and end of
%           each detected event as well as other user defined parameters
%           such as number of cycles, within event variance, min/max,...
%
%
%
%
% EC 2020-03-19   initial version based off of published methods from the
% van der Meer lab in Catanese et al. 2016, Carmichael et al., 2017,
% Carmichael et al. (2020; bioarxiv) and the vandermeer lab wiki: 
% https://rcweb.dartmouth.edu/~mvdm/wiki/doku.php?id=analysis:dataanalysis
%
%%  Initialize

cfg_def = [];
cfg_def.check = 1; % plot all checks throughout. 
%defaults to simple SWR detection. 
cfg_def.filt.type = 'butter'; %Cheby1 is sharper than butter
cfg_def.filt.f  = [140 250]; % broad, could use 150-200?
cfg_def.filt.order = 4; %type filter order (fine for this f range)
cfg_def.filt.display_filter = 1; % use this to see the fvtool
cfg_def.filt.units = 'amplitude'; % units can also be in 'power' 


cfg = ProcessConfig(cfg_def, cfg_in); 


 %% basic filtering and thresholding
    % mouse SWR parameters are based off of Liu, McAfee, & Heck 2017 https://www.nature.com/articles/s41598-017-09511-8#Sec6
    %set up ripple band
    cfg_filt_d = [];
    cfg_filt_d.type = 'butter'; %Cheby1 is sharper than butter
    cfg_filt_d.f  = [140 250]; % broad, could use 150-200?
    cfg_filt_d.order = 4; %type filter order (fine for this f range)
    cfg_filt_d.display_filter = 0; % use this to see the fvtool
    if cfg.check
            cfg_filt_d.display_filter = 0; % use this to see the fvtool
    end
    csc_ripple = FilterLFP(cfg_filt_d, csc);
    
    
    % convert to amplitude or power
    amp_ripple = csc_ripple; % clone to make things simple and replace
    
    
    for iChan = 1:size(csc_ripple.data,1)
        amp_ripple.data(iChan,:) = abs(hilbert(csc_ripple.data(iChan,:)));
        % Convolve with a gaussian kernel (improves detection)
        kernel = gausskernel(60,20); % note, units are in samples; for paper Methods, need to specify Gaussian SD in ms
        fprintf('\nGausskernal using 60 samples = %0.0fms with SD = 20 samples (%0.0fms)\n', (60/csc.cfg.hdr{1}.SamplingFrequency)*1000, (20/csc.cfg.hdr{1}.SamplingFrequency)*1000)
        amp_ripple.data(iChan,:) = conv(amp_ripple.data(iChan,:),kernel,'same');
                amp_ripple.units = 'amplitude';

        if isfield(cfg.filt, 'units') && strcmpi(cfg.filt.units, 'power')
           amp_ripple.data(iChan,:) =  amp_ripple.data(iChan,:).^2;
           amp_ripple.units = 'power';
        end
    end
    
    if cfg.check
        figure(111)
        plot(csc.tvec, csc.data(1,:),'k',csc_ripple.tvec, csc_ripple.data(1,:), 'r',...
            amp_ripple.tvec, amp_ripple.data(1,:),'b')
        legend({'Raw', '140-250 filt', 'Amp'})
        pause(1); close;
    end
    
    %% remove large amplitude artifacts before SWR detection
    
    
    csc_artif = csc;
    for iChan = 1:size(csc_ripple.data,1)
        csc_artif.data(iChan,:) = abs(csc_artif.data(iChan,:)); % detect artifacts both ways
    end
    
    cfg_artif_det = [];
    cfg_artif_det.method = 'raw';
    cfg_artif_det.threshold = std(csc_artif.data(1,:))*5;
    % cfg_artif_det.minlen = 0.01;
    cfg_artif_det.target = csc.label{1};
    evt_artif = TSDtoIV(cfg_artif_det,csc_artif);
    
    cfg_temp = []; cfg_temp.d = [-0.5 0.5];
    artif_evts = ResizeIV(cfg_temp,evt_artif);
    
    
    % plot
    if cfg.check
        plot(113)
        cfg_plot=[];
        cfg_plot.display = 'iv'; % tsd, iv
        cfg_plot.target = csc.label{1};
        PlotTSDfromIV(cfg_plot,artif_evts,csc_artif);
        hline(cfg_artif_det.threshold )
        pause(3); close all;
    end
    
    % zero pad artifacts to improve reliability of subsequent z-scoring
    artif_idx = TSD_getidx2(csc,evt_artif); % if error, try TSD_getidx (slower)
    for iChan = 1:size(csc_ripple.data,1)
        csc_ripple.data(iChan,artif_idx) = 0;
        amp_ripple.data(iChan,artif_idx) = 0;
    end
    
    % plot
    if cfg.check
        %     plot(114)
        hold on
        plot(amp_ripple.tvec, csc_ripple.data(1,:),'g');
        plot(amp_ripple.tvec, amp_ripple.data(1,:),'-k');
        
        pause(3); close all;
    end
    
    fprintf('\n<strong>MS_SWR_Ca2</strong>: %d large amplitude artifacts detected and zero-padded from csc_ripple.\n',length(artif_evts.tstart));

    %% isolate candidate events
    
    % get the thresholds
    cfg_detect = [];
    cfg_detect.operation = '>';
    cfg_detect.dcn = cfg_detect.operation; % b/c odd var naming in TSDtoIV
    cfg_detect.method = 'zscore';
    cfg_detect.threshold = 2;
    cfg_detect.target = csc.label{1};
    cfg_detect.minlen = 0.020; % 40ms from Vandecasteele et al. 2015
    cfg_detect.merge_thr = 0.02; % merge events that are within 20ms of each other.
    
    [swr_evts,evt_thr] = TSDtoIV(cfg_detect,amp_ripple);
    
    % % now apply to all data
    % cfg_select = [];
    % cfg_select.dcn = '>';
    % cfg_select.method = 'raw';
    % cfg_select.threshold = evt_thr;
    % cfg_select.target = 'CSC1.ncs';
    % cfg_select.minlen = cfg_detect.minlen;
    %
    % [evt_ids,~] = TSDtoIV(cfg_select,amp_ripple);
    
    
    
    fprintf('\n<strong>MS_SWR_Ca2</strong>: %d events detected initially.\n',length(swr_evts.tstart));
    
    if cfg.check
        cfg_plot = [];
        cfg_plot.display = 'iv';
        cfg_plot.mode = 'center';
        cfg_plot.width = 0.2;
        cfg_plot.target = csc.label{1};
        
        PlotTSDfromIV(cfg_plot,swr_evts,csc);
        pause(2); close all;
    end
    
    
    
    %% exclude events with insufficient cycles - count how many exist above same threshold as used for detection
    cfg_cc = [];
    cfg_cc.threshold_type = 'raw';
    cfg_cc.threshold = evt_thr; % use same threshold as for orignal event detection
    cfg_cc.filter_cfg = cfg_filt_d;
    events_out = CountCycles(cfg_cc,csc,swr_evts);
    
    % get get the evetns with sufficient cycles.
    cfg_gc = [];
    cfg_gc.operation = '>=';
    cfg_gc.threshold = 4;
    events_out = SelectIV(cfg_gc,events_out,'nCycles');
    fprintf('\n<strong>MS_SWR_Ca2</strong>: %d events remain after cycle count thresholding (%d cycle minimum).\n',length(events_out.tstart), cfg_gc.threshold);
    
    %% check for evnts that are too long.
    % add in a user field for the length of the events (currently not used)
    events_out.usr.evt_len = (events_out.tend - events_out.tstart)';
    
    cfg_max_len = [];
    cfg_max_len.operation = '<';
    cfg_max_len.threshold = .1;
    events_out = SelectIV(cfg_max_len,events_out,'evt_len');
    
    fprintf('\n<strong>MS_SWR_Ca2</strong>:: %d events remain after event length cutoff (> %d ms removed).\n',length(events_out.tstart), (cfg_max_len.threshold)*1000);
    
    
    %% check for evnts with high raw varience. 'var_raw' is added as a events_out.usr field in CountCycles
    
    cfg_max_len = [];
    cfg_max_len.operation = '<';
    cfg_max_len.threshold = 1;
    events_out = SelectIV(cfg_max_len,events_out,'var_raw');
    
    fprintf('\n<strong>MS_SWR_Ca2</strong>: %d events remain after raw varience thresholding (''var_raw'' > %d removed).\n',length(events_out.tstart), cfg_max_len.threshold);
    
    %% remove events that cooinside with artifacts.
    events_out = DifferenceIV([], events_out, artif_evts);
    
    fprintf('\n<strong>MS_SWR_Ca2</strong>: %d events remain after removing those co-occuring with artifacts.\n',length(events_out.tstart));
    
    %% check again
    if cfg.check
        cfg_plot = [];
        cfg_plot.display = 'iv';
        cfg_plot.mode = 'center';
        cfg_plot.width = 0.2;
        cfg_plot.target = csc.label{1};
        cfg_plot.title = 'var';
        PlotTSDfromIV(cfg_plot,events_out,csc);
        pause(3); close all;
    end


