function scores = mycaffe_tiled_forward5_cpu( data, opts)

%  compute input and output sizes (for v-shaped 4-resolutions network)
%
d4a_size = ceil(([size(data,1) ceil(size(data,2)/opts.n_tiles)] - opts.padOutput)/opts.downsampleFactor);
input_size = opts.downsampleFactor*d4a_size + opts.padInput;
output_size = opts.downsampleFactor*d4a_size + opts.padOutput;
%disp(['d4a_size = ' num2str(d4a_size) ' --> insize = ' num2str(input_size) ...
%      ', outsize = ' num2str(output_size)])


%
%  create padded volume mit maximal border
%
border = round(input_size-output_size)/2;
paddedFullVolume = zeros(size(data,1) + 2*border(1), ...
                         size(data,2) + 2*border(2), ...
                         size(data,3),...
                         size(data,4), 'single');

paddedFullVolume( border(1)+1:border(1)+size(data,1), ...
                  border(2)+1:border(2)+size(data,2), ...
                  :, : ) =data;


if( strcmp(opts.padding,'mirror'))
  xpad  = border(1);
  xfrom = border(1)+1;
  xto   = border(1)+size(data,1);
  paddedFullVolume(1:xfrom-1,:,:) = paddedFullVolume( xfrom+xpad:-1:xfrom+1,:,:);
  paddedFullVolume(xto+1:end,:,:) = paddedFullVolume( xto-1:-1:xto-xpad,    :,:);
  
  ypad  = border(2);
  yfrom = border(2)+1;
  yto   = border(2)+size(data,2);
  paddedFullVolume(:, 1:yfrom-1,:) = paddedFullVolume( :, yfrom+ypad:-1:yfrom+1,:);
  paddedFullVolume(:, yto+1:end,:) = paddedFullVolume( :, yto-1:-1:yto-ypad,    :);
end

%
%  create Network with fitting dimensions
%
fid = fopen(opts.train_model_def_file);
trainPrototxt = fread( fid);
fclose(fid);

model_def_file = 'tmp-test.prototxt';

fid = fopen(model_def_file,'w');
fprintf(fid, 'input: "data"\n'); 
fprintf(fid, 'input_dim: 1\n'); 
fprintf(fid, 'input_dim: %g\n', size(data,3)); 
fprintf(fid, 'input_dim: %g\n', input_size(2)); 
fprintf(fid, 'input_dim: %g\n', input_size(1)); 
fprintf(fid, 'state: { phase: TEST }'); 
fwrite(fid, trainPrototxt);
fclose(fid);


if( opts.gpu_or_cpu == 'gpu')
  addpath caffe_gpu
  wait_message = ' ... You use the GPU -- that''s pretty fast, isn''t it?';
else
  addpath caffe_cpu
  wait_message = [' ... Please wait a long time, because you use the' ...
				  ' CPU.  On GPU this takes only around 1 second'];
end

if( isfield( opts, 'gpu_device'))
  caffe('set_device', opts.gpu_device)
end
caffe('init', model_def_file, opts.model_file)
if( opts.gpu_or_cpu == 'gpu')
  caffe('set_mode_gpu')
end
caffe('set_phase_test')

%
%  do the classification (tiled)
%  average over flipped images

for num=1:size(data,4)
  disp(['segmenting image ' num2str(num) wait_message])
  tic
  % crop input data
  for yi=0:opts.n_tiles-1
    paddedInputSlice = zeros([input_size size(data,3)], 'single');
    validReg(1) = min(input_size(1), size(paddedFullVolume,1));
    validReg(2) = min(input_size(2), size(paddedFullVolume,2) - yi*output_size(2));
    paddedInputSlice(1:validReg(1), 1:validReg(2),:) = ...
		paddedFullVolume(1:validReg(1), yi*output_size(2)+1:yi*output_size(2)+validReg(2), :, num);
  
    scores_caffe = caffe('forward', {paddedInputSlice});
    scoreSlice = scores_caffe{1};
	
	if( opts.average_mirror == true)
	  scores_caffe = caffe('forward', {fliplr(paddedInputSlice)});
	  scoreSlice = scoreSlice+fliplr(scores_caffe{1});
	  scores_caffe = caffe('forward', {flipud(paddedInputSlice)});
	  scoreSlice = scoreSlice+flipud(scores_caffe{1});
	  scores_caffe = caffe('forward', {flipud(fliplr(paddedInputSlice))});
	  scoreSlice = scoreSlice+flipud(fliplr(scores_caffe{1}));
	  scoreSlice = scoreSlice/4;
	end

	if( num==1 && yi==0)
	  nClasses = size(scoreSlice,3);
	  scores = zeros( size(data,1), size(data,2), nClasses, size(data,4));
	end
	%    figure(4); imshow( reshape(scores, [size(scores,1) size(scores,2)*size(scores,3)]),[])
    validReg(1) = min(output_size(1), size(scores,1));
    validReg(2) = min(output_size(2), size(scores,2) - yi*output_size(2));
    scores(1:validReg, yi*output_size(2)+1:yi*output_size(2)+validReg(2),:,num) = ...
		scoreSlice(1:validReg(1),1:validReg(2),:);
  end
  toc
end
caffe('reset')
