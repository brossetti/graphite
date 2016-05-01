function [ annotations ] = tagtracker(annotations, outpath)
%TAGTRACKER Filters/processes tag annotations to define tracked trackects
% 

% parameters
t = 0.25;

% remove preexisting trackid field
if isfield(annotations, 'trackid')
    annotations = rmfield(annotations, 'trackid');
end

% initialize track structure with tracks in first frame
times = unique([annotations.time]);

for i = 1:find([annotations.time] == times(1), 1, 'last')
    annotations(i).trackid = i;
end

%loop through each time point
for i = times(2:end)
    % get current tag indices
    tagIdx = find([annotations.time] == i);
    
    % get track within 1 sec of current time
    trackIdx = find([annotations.time] > i-t & [annotations.time] < i);

    % create new track if none found else detect match
    if isempty(trackIdx)
        for j = tagIdx
            annotations(j).trackid = max([annotations.trackid])+1;
        end
    else
        % get last frame of each track
        tracks = annotations(trackIdx);
        [~, trackIdx] = unique(flip([tracks.trackid]));
        trackIdx = length(tracks)-trackIdx+1;
        tracks = tracks(trackIdx);
        
        % create feature matrix for tracks
        trackMat = [vertcat(tracks.centroid), vertcat(tracks.area)];
       
        % create feature matrix for current tags
        tags = annotations(tagIdx);
        tagMat = [vertcat(tags.centroid), vertcat(tags.area)];

        % match features
        idxPair = matchFeatures(trackMat, tagMat, 'Unique', true);
        
        % assign unmatched tags
        umIdx = true(1, length(tags));
        umIdx(idxPair(:,2)) = false;
        umIdx = find(umIdx);
        
        tracknum = max([annotations.trackid]);
        for j = umIdx
            tracknum = tracknum + 1;
            tags(j).trackid = tracknum;
        end
        
        % assign matched tags
        if ~isempty(idxPair)
            [tags(idxPair(:,2)).trackid] = tracks(idxPair(:,1)).trackid;
        end
        
        [annotations(tagIdx).trackid] = tags.trackid;    
    end %if-else
end %for

% save tag annotations
save(fullfile(outpath, 'tags', 'tag_annotations.mat'), 'annotations');

end %function