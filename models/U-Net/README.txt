This is the implementation of the u-net described in 

Olaf Ronneberger, Philipp Fischer, Thomas Brox:
U-Net: Convolutional Networks for Biomedical Image Segmentation
In: Medical Image Computing and Computer-Assisted Intervention (MICCAI), 2015 
http://arxiv.org/abs/1505.04597

It contains the ready trained network, the source code, the matlab
binaries of the modified caffe network, all essential third party
libraries, the matlab-interface for overlap-tile segmentation and a
greedy tracking algorithm used for our submission for the ISBI cell
tracking challenge 2015. Everything is compiled and tested only on
Ubuntu Linux 14.04 and Matlab 2014b (x64)

To apply the segmentation and the tracking to the images in
"PhC-C2DH-U373/01" simply run the shell script 

./segmentAndTrack.sh

The resulting segmentation masks will be written to
"PhC-C2DH-U373/01_RES"

If you do not have a CUDA-capable GPU or your GPU is smaller than
mine, edit segmentAndTrack.sh accordingly (see there for
documentation).

If you have any questions, you may contact me at
ronneber@informatik.uni-freiburg.de, but be aware that I can not
provide any support.

Olaf Ronneberger
