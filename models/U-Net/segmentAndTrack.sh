#!/bin/bash
# Segment images using u-net and associate segments over time by
# greedy algorithm   
#
# - change 'gpu' to 'cpu' if you have no CUDA capable GPU
# - If your GPU memory is too small you can increase the number of
#   Tiles (param.nTiles) until it fits
#
# Prerequisities: MATLAB 2014b (x64), Ubuntu Linux 14.04,
#

matlab_exec=matlab

LD_LIBRARY_PATH=$PWD/lib:$LD_LIBRARY_PATH ${matlab_exec} -nodesktop -nosplash <<'EOF'
params.inDir         = 'PhC-C2DH-U373/01/';
params.outDir        = 'PhC-C2DH-U373/01_RES/';
params.netname       = 'phseg_v5';
params.normImage     = false;
params.scaleImage    = 1;
params.nTiles        = 2;
params.gpu_or_cpu    = 'gpu';
params.useFillHoles  = 0;
params.minSegmAreaPx = 500;
params.FOI_E         = 50;  
segmentAndTrack2( params);
exit
EOF
