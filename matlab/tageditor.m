function tageditor(annotations, vid, outpath)
% TAGEDITOR Editor for bee tag annotations
% Allows the manipulation of bee tag annotation files

%  set figure dimensions
set(0,'units','pixels');
ss = get(0,'screensize');   % screen size
sar = ss(4)/ss(3);          % screen aspect ratio
far = 3/4;                  % figure aspect ratio
fds = 2/3;                  % figure downscale

if far > sar
    % set dimensions based on screen width
    w = fds*ss(3);
    h = w*far;
else
    % set dimensions based on screen height
    h = fds*ss(4);
    w = h/far;    
end

fdims = [floor(ss(3)/2-w/2), floor(ss(4)/2-h/2), w, h];

f = figure('Visible','off','Position', fdims, 'Name', 'Tag Editor',...
    'NumberTitle','off', 'Toolbar', 'none');

% set figure panels
pvid = uipanel(f, 'Title', 'Video', 'Position', [0.005, 0.7+0.0025, 0.99, 0.3-0.0075]);
axvid = axes(pvid);
ptags = uipanel(f, 'Title', 'Tags', 'Position', [0.005, 0.005, 0.7-0.0075, 0.7-0.0075]);
ptracks = uipanel(f, 'Title', 'Tracks', 'Position', [0.7+0.0025, 0.005, 0.15-0.005, 0.7-0.0075]);
peditor = uipanel(f, 'Title', 'Editor', 'Position', [0.85+0.0025, 0.005, 0.15-0.0075, 0.7-0.0075]);

% add tracks listbox
tracks = unique([annotations.trackid]);
tracknames = arrayfun(@(x) ['track ' num2str(x)], tracks, 'UniformOutput', false);
htracks = uicontrol(ptracks, 'Style', 'listbox', 'String', tracknames, ...
          'Units', 'normalized', 'Position', [0.01, 0.01, .98, .98], ...    
          'Max', 2, 'Min', 0, 'Value', 1, ...
          'Callback', @tracks_Callback);

% add tag table
tagdata = tracks2cell(annotations, tracks(1));
htags = uitable(ptags, 'Data', tagdata, ...
        'Units', 'normalized', 'Position', [0.01, 0.01, .98, .98], ...
        'RowName', [], ...
        'ColumnName', {'Tag', 'Track', 'Tag ID', 'Time', 'X', 'Y', 'Digits'}, ...
        'ColumnFormat', {'logical', 'numeric', 'char', 'numeric', 'numeric', 'numeric', 'char'}, ...
        'ColumnEditable', logical([1 1 0 0 0 0 1]), ...
        'CellSelectionCallback', @tags_SelectionCallback, ...
        'CellEditCallback', @tags_EditCallback);

wtable = (ptags.Position(3)-htags.Position(1)*2)*f.Position(3); 
htags.ColumnWidth = {floor(wtable/size(tagdata,2))};

% add editor controls
htoggle(1) = uicontrol(peditor, 'Style', 'togglebutton', ...
            'String', 'Tracks', ...
            'Units', 'normalized', 'Position', [0.01, 0.89, 0.49, 0.1], ...
            'Value', 0, ...
            'Callback', @toggle_Callback);
htoggle(2) = uicontrol(peditor, 'Style', 'togglebutton', ...
            'String', 'Digits', ...
            'Units', 'normalized', 'Position', [0.5, 0.89, 0.49, 0.1], ...
            'Value', 1, ...
            'Callback', @toggle_Callback);
htxtbox = uicontrol(peditor,'Style','edit',...
          'Units', 'normalized', 'Position',[0.01 0.835 0.98 0.055]);
happly = uicontrol(peditor,'Style','pushbutton', 'String', 'Apply', ...
         'Units', 'normalized', 'Position',[0.01 0.67 0.98 0.155], ...
         'Callback', @apply_Callback);
hsave = uicontrol(peditor,'Style','pushbutton', 'String', 'Save', ...
        'Units', 'normalized', 'Position',[0.01 0.5050 0.98 0.155], ...
        'Callback', @save_Callback);
hexportdata = uicontrol(peditor,'Style','pushbutton', 'String', 'Export Data', ...
              'Units', 'normalized', 'Position',[0.01 0.34 0.98 0.155], ...
              'Callback', @exportdata_Callback);
hexportvid = uicontrol(peditor,'Style','pushbutton', 'String', 'Export Video', ...
             'Units', 'normalized', 'Position',[0.01 0.175 0.98 0.155], ...
             'Callback', @exportvid_Callback);
hquit = uicontrol(peditor,'Style','pushbutton', 'String', 'Quit', ...
        'Units', 'normalized', 'Position',[0.01 0.01 0.98 0.155], ...
        'Callback', @quit_Callback);
    
% store gui data
gdata.f = f;
gdata.annotations = annotations;
gdata.outpath = outpath;
gdata.vid = vid;
gdata.axvid = axvid;
gdata.tracks = tracks;
gdata.htracks = htracks;
gdata.htags = htags;
gdata.htoggle = htoggle;
gdata.htxtbox = htxtbox;
gdata.hexportdata = hexportdata;
gdata.hexportvid = hexportvid;
gdata.times = unique([0, annotations.time]);
guidata(f, gdata);

% add video frame
showframe(1, gdata);

% display initial state
f.Visible = 'on';

end

%% Functions\Callbacks

function tracks_Callback(hObject, eventdata)
    % get data
    gdata = guidata(hObject);
    idx = hObject.Value;
    
    % convert index to trackid
    trackid = gdata.tracks(idx);
    
    % create/display new table
    gdata.htags.Data = tracks2cell(gdata.annotations, trackid);
    
    % display first video frame
    showframe(1, gdata);
    
    % reassign guidata
    guidata(hObject, gdata);
end %tracks_Callback

function tags_SelectionCallback(hObject, eventdata)
    % skip if no index
    if isempty(eventdata.Indices)
        return
    end
    
    % get data
    gdata = guidata(hObject);
    row = eventdata.Indices(1,1);
    
    % display video frame
    showframe(row, gdata);
    
    % reassign guidata
    guidata(hObject, gdata);
end %tags_SelectionCallback

function tags_EditCallback(hObject, eventdata)
    % get data
    gdata = guidata(hObject);
    idx = eventdata.Indices;
    val = eventdata.NewData;
    r = idx(1,1);
    c = idx(1,2);
    
    % check which column editted (7 - digits; 2 - track, 1 - istag)
    if c == 7
        % check format
        if (length(val) ~= 3) || ~all(isstrprop(val, 'digit'))
            % reset previous value
            hObject.Data{r,c} = eventdata.PreviousData;
            return
        end
        
        % update digits
        tagid = hObject.Data{r,3};
        anntIdx = strcmp(tagid, {gdata.annotations.tagid});
        gdata.annotations(anntIdx).digits = val;
        
        % remove confidence values
        gdata.annotations(anntIdx).confidence = NaN;
    elseif c == 2
        % check format
        if ~isnumeric(val) || int64(val) ~= val || val < 1
            % reset previous value
            hObject.Data{r,c} = eventdata.PreviousData;
            return
        end
        
        % update track
        tagid = hObject.Data{r,3};
        anntIdx = strcmp(tagid, {gdata.annotations.tagid});
        gdata.annotations(anntIdx).trackid = val;
        
        % update track listbox
        gdata.tracks = unique([gdata.annotations.trackid]);
        gdata.htracks.String = arrayfun(@(x) ['track ' num2str(x)], gdata.tracks, 'UniformOutput', false);
    else
        % update istag
        tagid = hObject.Data{r,3};
        anntIdx = strcmp(tagid, {gdata.annotations.tagid});
        gdata.annotations(anntIdx).istag = val;
    end %if-elseif
    
    % reassign guidata
    guidata(hObject, gdata);
end %tags_EditCallback

function toggle_Callback(hObject, eventdata)
    % get data
    gdata = guidata(hObject);
    
    % get index of hot toggle
    idx = gdata.htoggle ~= hObject;
    
    % toggle
    hObject.Value = 1;
    gdata.htoggle(idx).Value = 0;
    
    % reassign guidata
    guidata(hObject, gdata);
end %toggle_Callback

function apply_Callback(hObject, eventdata)
    % get data
    gdata = guidata(hObject);
    val = gdata.htxtbox.String;
    x = gdata.annotations;
   
    % check which apply function (0 - digits; 1 - tracks)
    if gdata.htoggle(1).Value == 0
        % check format
        if (length(val) ~= 3) || ~all(isstrprop(val, 'digit'))
            return
        end
        
        % update digits and remove confidence values
        gdata.htags.Data(:,7) = {val};
        tagid = gdata.htags.Data(:,3);
        anntIdx = find(ismember({gdata.annotations.tagid}, tagid));
        for i = anntIdx
            gdata.annotations(i).digits = val;
            gdata.annotations(i).confidence = NaN;
        end   
    else
        val = str2double(val);
        % check format
        if isempty(val) || int64(val) ~= val || val < 1
            return
        end
        
        % update tracks
        gdata.htags.Data(:,2) = {val};
        tagid = gdata.htags.Data(:,3);
        anntIdx = find(ismember({gdata.annotations.tagid}, tagid));
        for i = anntIdx
            gdata.annotations(i).trackid = val;
        end
        
        % update track listbox
        gdata.tracks = unique([gdata.annotations.trackid]);
        gdata.htracks.String = arrayfun(@(x) ['track ' num2str(x)], gdata.tracks, 'UniformOutput', false);        
    end
    
    % reassign guidata
    guidata(hObject, gdata);
end %apply_Callback

function save_Callback(hObject, eventdata)
    % get data
    gdata = guidata(hObject);
    annotations = gdata.annotations;
    
    % save annotation file
    save(fullfile(gdata.outpath, 'tags', 'tag_annotations.mat'), 'annotations');
end %save_Callback

function exportdata_Callback(hObject, eventdata)
    % get data
    gdata = guidata(hObject);
    
    % change button color to red
    gdata.hexportdata.BackgroundColor = [1 0 0];
    
    % convert to table
    x = struct2table(gdata.annotations);
    
    % export
    [filename, pathname] = uiputfile({'*.xls', 'Excel File (*.xls)'; ...
                           '*.csv', 'Text File (*.csv)'},'Export Data', ...
                           gdata.outpath);
    writetable(x, fullfile(pathname, filename));
    
    % revert button color
    gdata.hexportdata.BackgroundColor = [0.94 0.94 0.94];
end %exportdata_Callback

function exportvid_Callback(hObject, eventdata)
    % get data
    gdata = guidata(hObject);
    
    % change button color to red
    gdata.hexportvid.BackgroundColor = [1 0 0];
    
    % export
    [filename, pathname] = uiputfile({'*.avi', 'Motion JPEG AVI (*.avi)'; ...
                           '*.mp4', 'MPEG-4 (*.mp4)'},'Export Video', ...
                           gdata.outpath);
    tagvidgen(gdata.annotations, gdata.vid, fullfile(pathname, filename));
    
    % revert button color
    gdata.hexportvid.BackgroundColor = [0.94 0.94 0.94];
end %exportvid_Callback

function quit_Callback(hObject, eventdata)
    % get data
    gdata = guidata(hObject);
    
    % close figure window
    close(gdata.f);
end %quit_Callback

function data = tracks2cell(x, t)
    % get index of track set
    idx = ismember([x.trackid], t);
    
    % convert to cell array
    data = struct2cell(x(idx));
    
    % get necessary columns (10 - istag; 16 - track; 3 - tagid; 5 - time; 
    % 8 - centroid; 11 - digits)
    data = squeeze(data([10, 16, 3, 5, 8, 8, 11], :, :))';
    
    % split centroids to x and y
    data(:,5) = arrayfun(@(y) {y{:}(1)}, data(:,5));
    data(:,6) = arrayfun(@(y) {y{:}(2)}, data(:,6));
end %tracks2cell

function showframe(idx, gdata)
    % get data
    [istag, tagid, time] = gdata.htags.Data{idx,[1, 3:4]};
    
    % get data for frame
    framedata = gdata.annotations([gdata.annotations.time] == time);
    
    % get index for specific tag
    idx = strcmp(tagid, {framedata.tagid});
    
    % get frame
    gdata.vid.CurrentTime = time;
    frame = readFrame(gdata.vid);
    
    % add bboxes
    if istag
        frame = insertShape(frame,'rectangle', framedata(idx).bbox, 'Color', 'green');
    else
        frame = insertShape(frame,'rectangle', framedata(idx).bbox, 'Color', 'red');
    end
    frame = insertShape(frame,'rectangle', vertcat(framedata(~idx).bbox), 'Color', 'yellow');
    
    % display
    image(gdata.axvid, frame);
    axis off;    
end %showframe