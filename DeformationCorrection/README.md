QuantifyingImageDeformation.m is used to calculate the corrections to apply to correct for the barrel deformation of the macroscope.

This function has for single INPUT an image of the grid and for OUTPUTS, the corrected image (unwarped) of the grid and the computed geometric transformation object 'tform' that will be used to correct other images.

The calculated 'tform' will later be used on the experimental images to correct their deformation using the Matlab commands:
UnwarpedImage = imwarp(Image,tform,'OutputView',imref2d(size(Image)));
or
UnwarpedImage = imwarp(Image,tform);

An image ("500umgrid.png") is provided to test run the code. 
