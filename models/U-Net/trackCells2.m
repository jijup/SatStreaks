function trackCells2( predLabels, params )
% Runs cell tracking
%   predLabels: image stack (nCols, nRows, nFrames) containing the
%     segmented frames, background must have label = 0, foreground segments
%     must have label value > 0.
%   params: parameter structure
%     useFillHoles:
%       1: applies 'imfill' to fill holes in the segmentation masks
%       0: no fill holes applied
%     minSegmAreaPx:
%       value: Removes small segments in each frame with number of pixels
%         value <= minSegmAreaPx.
%     FOI_E:       
%       value: Field of interest (FOI) is applied with a border of given
%       size (in pixels). See ISBI Cell Tracking Challenge Field of
%       interest specification.
%       Description: In each frame segments are discarded that lie completely outside
%       the FOI. However, for tracking all segments are used, and in case a
%       segment has been discarded in a previous frame but reappears and
%       could be tracked, then the previous and the new track are linked using the "Parent link" option.
%
%   (c) 2015 Robert Bensch, Image Analysis Group, Chair of Pattern Recognition and Image
%   Processing, University of Freiburg
%

%
% Parameters
%
FOI_E = params.FOI_E;
useFillHoles = params.useFillHoles;
minSegmAreaPx = params.minSegmAreaPx;
outDir = params.outDir;

nFrames = size(predLabels,3);
    
%
% Run Segmentation
%
tstart_total = tic;

fprintf('\n\n*\n');
fprintf('* Cell Tracking\n');
fprintf('* Processing %d file(s) in total.\n', nFrames);
fprintf('*\n\n');

% Initialize tracks
tracks = [];
maskFOI = [];

for frameIdx=1:nFrames
        
  tstart = tic;    
  
  % zero-based frame index, for output filename
  frameIdxStr = sprintf('%03d', frameIdx-1);
  fn = ['mask' frameIdxStr '.tif'];
  
  fprintf('\tProcessing %s\n', fn);
  
  BW = predLabels(:,:,frameIdx) > 0;
  
  %
  % Fill holes
  %
  if (useFillHoles==1)
    BW = imfill(BW,'holes');
  end
  CC = bwconncomp(BW);
  
  %
  % Remove small segments
  %
  if (minSegmAreaPx > 0)
    numPixels = cellfun(@numel,CC.PixelIdxList);
    CC2 = CC;
    CC2.PixelIdxList = CC2.PixelIdxList(numPixels>minSegmAreaPx);
    CC2.NumObjects = length(CC2.PixelIdxList);   
    CC = CC2;
  end  
  
  L2 = uint16(labelmatrix(CC));

  %
  % Remove objects that are completely outside the FOI
  %
  L2_FOI = L2;
  if (FOI_E > 0)
      if (frameIdx==1)
          % Initialize FOI mask
          maskFOI = false(size(L2));
          maskFOI(FOI_E+1:end-FOI_E, FOI_E+1:end-FOI_E) = true;
      end
      rp2 = regionprops( L2);
      L2_tmp = L2;
      L2_tmp(~maskFOI) = 0;
      rp3 = regionprops( L2_tmp);

      for i = 1:length(rp2)
        if (i<=length(rp3))
            if (rp3(i).Area==0)
              L2_FOI(L2_FOI==i) = 0;
            end
        else
            L2_FOI(L2_FOI==i) = 0;
        end
      end
  end  
    
  %
  % Tracking / Label propagation
  %
  if (frameIdx==1)
    
    % Initialize objects and labels
    nObjects = double(max(L2(:)));   
    %assert(curr_nObjects>0,'assert failed: curr_nObjects>0; No objects at initialization step.');
    
    % Initialize tracks
    nTracks = nObjects;
    for i = 1:nTracks
        if (sum(sum(L2_FOI(L2==i)>0)) > 0)
            tracks{i} = double([i (frameIdx-1) (frameIdx-1) 0]);
        else
            tracks{i} = [];
        end
    end
    
  else
    
    % Propagate object labels from previous segmentation mask
    curr_nObjects = double(max(L2(:)));
            
    if (nObjects>=0 && curr_nObjects>0)
    
        if (nObjects>0)
            
            %
            % compute intersection over union
            %
            currLin = double(L2(:))+1;
            prevLin = double(L2_prev(:))+1;
            intersec = sparse(prevLin, currLin, ones(size(prevLin)), ...
                                        max(prevLin), max(currLin));
            intersec = full(intersec);    
            areaPrev = sum(intersec,2);
            areaCurr = sum(intersec,1);
            
            intersec = intersec(2:end,2:end);
            areaPrev = areaPrev(2:end);
            areaCurr = areaCurr(2:end);
            
            lblMatrix = zeros(nObjects,curr_nObjects);
            
            idx = find(intersec>0);
            [idx_i,idx_j] = ind2sub(size(intersec), idx);
            for k = 1:length(idx_i)
                i = idx_i(k);
                j = idx_j(k);
                areaUnion = areaPrev(i) + areaCurr(j) - intersec(i,j);
                lblMatrix(i,j) = intersec(i,j)/areaUnion;             
            end
            
            % Enforces one-to-one mapping

            % Maximum intersection over union
            % src-objs. > curr-objs.
            [~,max_idx] = max(lblMatrix,[],2);
            linidx = sub2ind(size(lblMatrix),1:size(lblMatrix,1),max_idx');
            tmp_lblMatrix = zeros(size(lblMatrix));
            tmp_lblMatrix(linidx) = lblMatrix(linidx);
            lblMatrix = tmp_lblMatrix;

            % Maximum intersection over union
            % curr-objs.
            [max_val,max_idx] = max(lblMatrix,[],1);

            nAddObj = sum(max_val==0);
            max_idx(max_val==0) = nObjects+1:nObjects+nAddObj;
            lblMapping = max_idx;   

        elseif (nObjects==0)
            
            nAddObj = curr_nObjects;
            lblMapping = nObjects+1:nObjects+nAddObj;
            
        end
           
        % Propagate matched labels
        tmp_L2 = L2;
        for j=1:curr_nObjects
          
            % j: curr label
            % lblMapping(j): propagated label
            tmp_L2(L2==j) = lblMapping(j);

            if (sum(sum(L2_FOI(L2==j)>0)) > 0)

                % Update tracks
                if (lblMapping(j)>=1 && lblMapping(j)<=nObjects)
                    if (length(tracks) < lblMapping(j))
                        tracks{lblMapping(j)} = [];
                    end
                    if (isempty(tracks{lblMapping(j)}))
                        % Initialize track (uninitialized FOI track)
                        tracks{lblMapping(j)} = double([lblMapping(j) (frameIdx-1) (frameIdx-1) 0]);    
                    else
                        % Update track
                        track_entry = tracks{lblMapping(j)};
                        if (track_entry(3)==(frameIdx-2))
                            % Continuous track
                            track_entry(3) = (frameIdx-1);
                            tracks{lblMapping(j)} = track_entry;
                        else
                            % Interrupted track (due to observability in FOI)
                            % add track and link to parent track
                            nAddObj = nAddObj +1;
                            tracks{nObjects+nAddObj} = double([nObjects+nAddObj (frameIdx-1) (frameIdx-1) lblMapping(j)]);
                            tmp_L2(L2==j) = nObjects+nAddObj;
                        end
                    end
                elseif (lblMapping(j)>nObjects)
                    % Add track
                    tracks{lblMapping(j)} = double([lblMapping(j) (frameIdx-1) (frameIdx-1) 0]);
                end

            end
        
        end
                
        % Labels (propagated)
        L2 = tmp_L2;
        L2_FOI(L2_FOI>0) = L2(L2_FOI>0);
        nObjects = nObjects + nAddObj;       
        
    end
    
  end
      
  %
  % Write segmentation mask (propagated labels, uint16)
  %
  fnOut = [outDir fn];
  imwrite(uint16(L2_FOI'), fnOut,'WriteMode','overwrite');
  
  %
  % Store segmentation mask to be used in the next run
  %
  L2_prev = L2;
  
  tend = toc(tstart);
  fprintf('\t\ttime (sec): %5.2f\n', tend);
    
end

%
% Store tracking result
%
fnOut = [outDir 'res_track.txt'];
fprintf('\twrite %s\n', fnOut);

fileID = fopen(fnOut, 'w');
nTracks = length(tracks);
for i = 1:nTracks
  if (~isempty(tracks{i}))
      fprintf(fileID, '%d %d %d %d\n', tracks{i}(1), tracks{i}(2), tracks{i}(3), tracks{i}(4));
      fprintf('%d %d %d %d\n', tracks{i}(1), tracks{i}(2), tracks{i}(3), tracks{i}(4));
  else
      fprintf('track %d is empty\n', i);
  end
end
fclose(fileID);

tend_total = toc(tstart_total);
fprintf('time total (sec): %5.2f\n', tend_total);

end

