function segmentAndTrack2( params)
% segment and track cells
%   inDir: input directory (expected input files format: t*.tif)
%   outDir: results output directory (output files format: mask*.tif)
%   NETNAME: name stub of the network
%   gpu_or_cpu: set mode of caffe: 'cpu' or 'gpu'
%
%   segmentation: Olaf Ronneberger
%   tracking: Robert Bensch
%
%   Image Analysis Lab, University of Freiburg


%
%  Load input data
%
d2 = dir([params.inDir '/*.tif']);
rawstack = [];
for fi=1:length(d2)
  filename = [params.inDir '/' d2(fi).name];
  disp(['loading ' filename])
  raw = permute(im2double(imread(filename)),[2 1]);
  rawSize = size(raw);
  rawstack = cat(3, rawstack, raw);
end

%
%  rescale images if requested
%
if( params.normImage)
  rawstack = rawstack - min(rawstack(:));
  rawstack = rawstack / max(rawstack(:));
  for t=1:size(rawstack,3)
	slice = rawstack(:,:,t);
	slice = slice - median(slice(:));
	rawstack(:,:,t) = slice;
  end	
end

if( params.scaleImage ~= 1)
  rawstack = imresize( rawstack, params.scaleImage, 'bilinear');
end

%
%  Do the segmenation
%

data = reshape( single(rawstack), ...
				[size(rawstack,1), size(rawstack,2), 1 size(rawstack,3)]);
%testIdx = 1:5; %size(data,4);
%data = data(:,:,:,testIdx);

opts.train_model_def_file = [params.netname '-train.prototxt'];
opts.model_file = [params.netname '.caffemodel'];
opts.n_tiles = params.nTiles;
opts.padding = 'mirror';
opts.downsampleFactor = 16;
d4a_size= 0;
opts.padInput =   (((d4a_size *2 +2 +2)*2 +2 +2)*2 +2 +2)*2 +2 +2;
opts.padOutput = ((((d4a_size -2 -2)*2-2 -2)*2-2 -2)*2-2 -2)*2-2 -2;
opts.average_mirror = true;
opts.gpu_or_cpu = params.gpu_or_cpu;
scores = mycaffe_tiled_forward5( data, opts );

if( params.scaleImage ~= 1)
  scores = imresize( scores, rawSize, 'bilinear');
end

[dummy labels] = max(scores,[],3);
labels = squeeze(labels-1);

mkdir( params.outDir)
hdf5write( [params.outDir '/raw_results.h5'], ...
		   'scores', single(squeeze(scores)), ...
		   'labels', uint8(squeeze(labels)));

%
%  write out label images
%
for fi = 1:size(labels,3)
  outfilename = [params.outDir 'binmask' num2str(fi-1, '%.03d') '.tif'];
  disp( ['saving ' outfilename])
  imwrite( permute(labels(:,:,fi), [2 1]), outfilename);
end


%
% Cell tracking
%
% Parameter structure for tracking
%params = struct;
%params.outDir = [outDir '/'];
%params.useFillHoles = 0;
%params.minSegmAreaPx = 500;
%params.FOI_E = 50;  % for dataset PhC-C2DH-U373

% Run cell tracking

trackCells2(labels, params);
