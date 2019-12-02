function [TS_out, camNum,frameNum,sysClock,buffer1] = MS_Load_TS(filename)
%IMPORTFILE Import numeric data from a text file as column vectors.
%   [CAMNUM,FRAMENUM,SYSCLOCK,BUFFER1] = IMPORTFILE(FILENAME) Reads data
%   from text file FILENAME for the default selection.
%
%   [CAMNUM,FRAMENUM,SYSCLOCK,BUFFER1] = IMPORTFILE(FILENAME, STARTROW,
%   ENDROW) Reads data from rows STARTROW through ENDROW of text file
%   FILENAME.
%
% Example:
%   [camNum,frameNum,sysClock,buffer1] = importfile('timestamp.dat',2, 2952);
%
%    See also TEXTSCAN.

% Auto-generated by MATLAB on 2019/11/22 14:53:51

%% Initialize variables.
delimiter = '\t';
if nargin<=2
    startRow = 2;
    endRow = inf;
end

%% Format for each line of text:
%   column1: double (%f)
%	column2: double (%f)
%   column3: double (%f)
%	column4: double (%f)
% For more information, see the TEXTSCAN documentation.
formatSpec = '%f%f%f%f%[^\n\r]';

%% Open the text file.
fileID = fopen(filename,'r');

%% Read columns of data according to the format.
% This call is based on the structure of the file used to generate this
% code. If an error occurs for a different file, try regenerating the code
% from the Import Tool.
dataArray = textscan(fileID, formatSpec, endRow(1)-startRow(1)+1, 'Delimiter', delimiter, 'TextType', 'string', 'EmptyValue', NaN, 'HeaderLines', startRow(1)-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');
for block=2:length(startRow)
    frewind(fileID);
    dataArrayBlock = textscan(fileID, formatSpec, endRow(block)-startRow(block)+1, 'Delimiter', delimiter, 'TextType', 'string', 'EmptyValue', NaN, 'HeaderLines', startRow(block)-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');
    for col=1:length(dataArray)
        dataArray{col} = [dataArray{col};dataArrayBlock{col}];
    end
end

%% Close the text file.
fclose(fileID);

%% Post processing for unimportable data.
% No unimportable data rules were applied during the import, so no post
% processing code is included. To generate code which works for
% unimportable data, select unimportable cells in a file and regenerate the
% script.

%% Allocate imported array to column variable names
camNum = dataArray{:, 1};
frameNum = dataArray{:, 2};
sysClock = dataArray{:, 3};
buffer1 = dataArray{:, 4};

%% extract multiple camera streams and format in the 'ts' manner
% which timestamp file is this? of how many
ts_files_here = dir('timestamp*');
for iTS = 1:length(ts_files_here)
    if strcmp(ts_files_here(iTS).name, filename)
    this_ts = iTS;
    end
end
TS_out.type = 'ts';
TS_out.unit = 'ms';
TS_out.file_num = this_ts;
TS_out.file_total = length(ts_files_here);
TS_out.cfg.history.mfun = [];
TS_out.cfg.history.cfg = [];
TS_out.cfg.filename = fullfile(pwd,filename);

this_cam = 0;
for ii = unique(camNum)'
    this_cam = this_cam+1;
    idx = camNum == ii;
    TS_out.camera_id{this_cam} = camNum(idx);
    TS_out.framenumber{this_cam} = frameNum(idx);
    TS_out.system_clock{this_cam} = sysClock(idx);
    TS_out.buffer{this_cam} = buffer1(idx);
    TS_out.cfg.Fs{this_cam} = 1/(median(diff(TS_out.system_clock{this_cam}(2:end)))*0.001);
end



