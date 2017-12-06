function QuantifyingImageDeformation
% This function is used to calculate the corrections to apply to images to
% correct for the barrel deformation of the microscope.

% This function has for single INPUT: 
%       - an image of the grid
% and for OUTPUTS:
%       - the corrected image (unwarped) of the grid
%       - and the computed geometric transformation object 'tform' that will be
%         used to correct other images.

% The calculated 'tform' will later be used on the experimental images to
% correct their deformation using the Matlab commands:
% UnwarpedImage = imwarp(Image,tform,'OutputView',imref2d(size(Image)));
% or
% UnwarpedImage = imwarp(Image,tform);


% NOTE:
% On rare occasions, this code fails because an insufficient number of points are
% available for the fits that are parts of the computation. This occurs
% generally if the grid image has low contrast, high noise, or is
% improperly focussed. It can happen also if when asked to choose a
% grid corner in the image, one with lower contrast, higher noise, or bad focus was
% selected.
% If the code fails,
% - running again the code selecting another corner should be attempted.
% - If failing again, modifying the value of the thresholding parameter 
% 'CorrDetectionThreshold', in our hands, has always been solving the 
% problem. This parameter has been modifed within the interval [0.75..0.85]
% for our images.


% EXPERIMENTAL CONSIDERATIONS:
% It is important that the grid used be larger than the field of view of 
% the microscope, be well focussed, and roughly be aligned with the edges of 
% the image frame.
% We have been acquiring the image of 500*500um grid( R1L3S3P from 
% Thorlabs, Inc.)
% An homogeneous illumination facilitates the calibration, as well as 
% using the full dynamical range of the camera, paying attention not to 
% reach pixel saturatrion.


% code writen by Stephan Thiberge, 
% Princeton neuroscience Institute
% Princeton university
% Tested using Matlab R2016a,with Image Processing Toolbox installed
% December 2016


%% Initiatlization 
IndicesCorners=[];

%% Load Calibration Image of 500um Grid

%CalibrationGridImage='500umGrid.png';
[filename, pathname] = uigetfile( ...
{'*.tif;*.tiff;*.png;*.bmp;*.jpeg;*.jpg','Image Files';...
   '*.*',  'All Files (*.*)'}, ...
   'Pick a file');
CalibrationGridImage=[pathname,filename];
info=imfinfo(CalibrationGridImage);

%Prepare filenames for the two ouput files: 
NoExtFileName=filename(1:end-(1+length(info.Format)));
OutputImageName=[pathname,NoExtFileName,'_Unwarped.',info.Format];
tform_filename=[pathname,'tform_',NoExtFileName,'.mat'];

GridImage=imread(CalibrationGridImage);
%if RGB format was used instead of greyscale during acquisition
if ~strcmp(info.ColorType,'grayscale')
    GridImage=GridImage(:,:,1);
end


%% identifying the corners of the grid
J=adapthisteq(GridImage);

% % Find a corner close to the middle of the image
scrsz = get(groot,'ScreenSize');
h=figure('Position',[scrsz(3)/4 scrsz(4)/4 scrsz(3)/2 scrsz(4)/2]);
imshow(J);
title('Click on a node of the grid')
[u,v]=ginput(1);

SizeCrop=30;                                %THIS PARAMETER MAY NEED TUNING IF DIFFERENT GRID SIZE IS USED (NOT RECOMMENDED)
Xcol=floor(u-SizeCrop/2);
Xrow=floor(v-SizeCrop/2);
GG=imcrop(J,[Xcol,Xrow,SizeCrop,SizeCrop]);
figure(h), imshow(GG)


% % cross-correlation analysis to identify corners accross the image
c = normxcorr2(GG,J);
CorrDetectionThreshold=0.8;                 %THIS PARAMETER MAY NEED TUNING
c(c(:)<CorrDetectionThreshold)=0;                          
%figure, surf(c), shading flat
BW=imregionalmax(c);
%imshow(BW)
%list peak positions
[row,col,v]=find(BW);

%Account for the padding that normxcorr2 adds.
row=row-round(SizeCrop/2);
col=col-round(SizeCrop/2);

CoordinatesCorners=[row,col];
figure, imshow(J); hold on; plot(col,row,'y+');

%% Find the center of the deformation

% Get the coordinates for each horizontal line of 'corners', and each 
% vertical line of 'corners', fit a straight line and evaluate the sum of 
% the residues plot 'Sum of residues' function of line position.
% Find the minimum for each of these two curves, that's the coordinates of
% the image deformation center.

% % The horizontal lines of 'corners'
index=0;
for Rowmin=max(1,min(row)-20):30:min(size(GridImage,1),max(row)+20);
 Rowmax=Rowmin+50;
 ThisRowPoints=CoordinatesCorners(find(row>=Rowmin & row<Rowmax),:);
 try
 [f,goodness,output]=fit( ThisRowPoints(:,2), ThisRowPoints(:,1),'poly1');
 Residual=(1/length(ThisRowPoints))*(sum(output.residuals(:).^2))^(1/2);
 index=index+1;
 Store(index,:)=[length(ThisRowPoints) Residual f.p1 f.p2];
 end
end
 
Store=unique(Store,'rows');
% plot(f,ThisRowPoints(:,2),ThisRowPoints(:,1),'residuals')
% plot(ThisRowPoints(:,1), output.residuals, '.' )
StoredFits=Store(find(Store(:,1)>9),:);                 % THIS PARAMETER (9,10,11) MAY NEED TUNING
%plot(StoredFits(:,4), StoredFits(:,2),'.');
TanAngleRows=mean(StoredFits(:,3));
[f6,goodness,output]=fit( StoredFits(:,4),StoredFits(:,2),'poly6');
%plot(f,StoredFits(:,4),StoredFits(:,2))
%CenterRow=round(-f.p2/(2*f.p1));
%find minimum coordinate
[u,CenterRow]=min(feval(f6,[1:size(GridImage,1)]));

% % The vertical Lines of 'corners'
index=0;
Store=[];
for Colmin=max(1,min(col)-20):30:min(size(GridImage,2),max(col)+20);
 Colmax=Colmin+50;
 ThisColPoints=CoordinatesCorners(find(col>=Colmin & col<Colmax),:);
 try
 [f,goodness,output]=fit( ThisColPoints(:,1), ThisColPoints(:,2),'poly1');
 % plot(f,ThisColPoints(:,1),ThisColPoints(:,2),'residuals')
 Residual=(1/length(ThisColPoints))*(sum(output.residuals(:).^2))^(1/2);
 index=index+1;
 Store(index,:)=[length(ThisColPoints) Residual f.p1 f.p2];
 end
end

Store=unique(Store,'rows');
% plot(ThisRowPoints(:,1), output.residuals, '.' )
StoredFits=Store(find(Store(:,1)>6),:);
%figure, plot(StoredFits(:,4), StoredFits(:,2),'.');
TanAngleCol=mean(StoredFits(:,3));
[f6,goodness,output]=fit( StoredFits(:,4),StoredFits(:,2),'poly6');
%figure,plot(f,StoredFits(:,4),StoredFits(:,2))
%find minimum coordinate
[u,CenterCol]=min(feval(f6,[1:size(GridImage,2)]));

% % angle of the grid
TanAngle=(TanAngleCol-TanAngleRows)/2;


% % 
% If the deformation is very small, finding the center of the deformation
% becomes harder, and eventually brings the code to fail if the determined
% center is nowhere close to the real optical axis.
% To prevent that force center of deformation to be within a reasonable
% area of the image (close to its center)
disp('---------');
if CenterRow<(1/4)*size(GridImage,1) || CenterRow>(3/4)*size(GridImage,1)
    CenterRow=floor(size(GridImage,1)/2);
    disp(['Center of distortion has been imposed.'])
end
if CenterCol<(1/4)* size(GridImage,2) || CenterCol>(3/4)* size(GridImage,2)
    CenterCol=floor( size(GridImage,2)/2);
    disp(['Center of distortion has been imposed.'])
end

%sumarizing result
CenterImage=[CenterRow CenterCol];
imshow(J); hold on; plot(col,row,'y+');
hold on; plot(CenterCol,CenterRow,'bo');
disp(['Center of distortion found at (',num2str(CenterCol),',',num2str(CenterRow),').'])

    

%% which are the 3 closest neighboors from the image deformation center?

CornerDistance2Center=( (col(:)-CenterCol).^2 + (row(:)-CenterRow).^2).^(1/2);

D=CornerDistance2Center;
for i=1:3
[M,jj]=min(D);
Indices3_center(i)=jj;
D(jj)=300; %increases D(jj) values such that, at the next iteration, it is not selected again
end

%coordinates of the three corners closest to the deformation center
Coord3_center=[row(Indices3_center(:)) col(Indices3_center(:))];

% we choose the distance between the two closest as the reference for the
% grid spacing
GridSpacing=((Coord3_center(2,2)-Coord3_center(1,2))^2+(Coord3_center(2,1)-Coord3_center(1,1))^2)^(1/2);

% giving indices to each corners, (0,0) being the 1st closest point to
% center
for jj=-100:100
 Rowmin=Coord3_center(1,1)-GridSpacing*(jj+1/2);
 Rowmax=min(Rowmin+GridSpacing,size(GridImage,1));
 IndicesCorners(1,find(row>=max(1,Rowmin) & row<Rowmax))=-jj;
end
for jj=-100:100
 Colmin=Coord3_center(1,2)-GridSpacing*(jj+1/2);
 Colmax=min(Colmin+GridSpacing,size(GridImage,2));
 IndicesCorners(2,find(col>=max(1,Colmin) & col<Colmax))=-jj;
end
IndicesCorners=IndicesCorners';
Check=[row col IndicesCorners];


% show the labeling
imshow(J); hold on; plot(col,row,'y+');
hold on; plot(CenterCol,CenterRow,'bo');
for ii=1:length(row)
    hold on;
    txt1=['[',num2str(Check(ii,4)),',',num2str(Check(ii,3)),']'];
    text(col(ii)+1,row(ii),txt1);
end


%% Creating the undeformed grid. 
% The point (0,0) is left untouched. Its coordinates are given 
% by Coord3_center(1,:). The reference nodes are GridSpacing apart, 
% and the grid is rotated by an angle given by TanAngleCol.

%DoubleCheck=[row col ColRowUndeformedGrid]
%TanAngleCol=0.1;
theta=atand(TanAngleCol);
A=[GridSpacing 0 ; 0 GridSpacing];
R=[cosd(theta) -sind(theta); sind(theta) cosd(theta)];
ColRowUndeformedGrid=(A*R*IndicesCorners')';
ColRowUndeformedGrid(:,1)=ColRowUndeformedGrid(:,1)+ Coord3_center(1,1);
ColRowUndeformedGrid(:,2)=ColRowUndeformedGrid(:,2)+ Coord3_center(1,2);
ColRowUndeformedGrid=round(ColRowUndeformedGrid);

% show the labeling
imshow(J); hold on; plot(col,row,'y+');
hold on; plot(CenterCol,CenterRow,'bo');
for ii=1:length(row)
    hold on;
    txt1=['[',num2str(Check(ii,4)),',',num2str(Check(ii,3)),']'];
    text(col(ii)+1,row(ii),txt1);
end
hold on; plot(ColRowUndeformedGrid(:,2),ColRowUndeformedGrid(:,1),'b+');

%% quantifying deformation
%DoubleCheck=[IndicesCorners row col ColRowUndeformedGrid] 

%CornerDistance2Center=( (col(:)-CenterCol).^2 + (row(:)-CenterRow).^2).^(1/2);
%RegularCornerDistance2Center=( (ColRowUndeformedGrid(:,2)-CenterCol).^2 + (ColRowUndeformedGrid(:,1)-CenterRow).^2).^(1/2);
RegularCornerDistance2Ref00=( (ColRowUndeformedGrid(:,2)-Coord3_center(1,2)).^2 + (ColRowUndeformedGrid(:,1)-Coord3_center(1,1)).^2).^(1/2);

%TripleCheck=[IndicesCorners row col ColRowUndeformedGrid CornerDistance2Center RegularCornerDistance2Center]

A=[row col ColRowUndeformedGrid];
DistanceRealPredicted=((A(:,4)-A(:,2)).^2 + (A(:,3)-A(:,1)).^2 ).^(1/2);

%Distortion=DistanceRealPredicted./RegularCornerDistance2Center;
Distortion=DistanceRealPredicted./RegularCornerDistance2Ref00;
Distortion(find(isnan(Distortion)))=0;

% % plot ditortion function of distance to center
% figure, plot(RegularCornerDistance2Ref00,100*Distortion,'.')
% ylim([0 20]);

%maximum Distortion
disp(['maximum distortion measured: ',num2str(100*max(Distortion)),'%.'])
disp(['found at a distance of ',num2str(round(max(RegularCornerDistance2Ref00))),'px from center of deformation']);
disp('---------');

%% Correcting image using the functions
% 'fitgeotrans' and 'imwarp' from the Image Processing Toolbox
% 

movingPoints = [col row];
fixedPoints =[ColRowUndeformedGrid(:,2) ColRowUndeformedGrid(:,1)];

tform = fitgeotrans(movingPoints,fixedPoints,'polynomial',4);
% alternative :
% tform = fitgeotrans(movingPoints,fixedPoints,'lwm',9);

Jregistered = imwarp(GridImage,tform);
% alternative :
%Jregistered = imwarp(GridImage,tform,'OutputView',imref2d(size(GridImage)));
figure, imshow(Jregistered)

%saving unwarped image
NoExtFileName=filename(1:end-(1+length(info.Format)));
OutputImageName=[pathname,NoExtFileName,'_Unwarped.',info.Format];
imwrite(Jregistered,OutputImageName)
% OutputImageName=[pathname,NoExtFileName,'_UnwarpedFull.',info.Format];
% imwrite(JregisteredFull,OutputImageName)


% saving the tform to be used in conjonction with the imwarp function to
% unwarp experimental images.
tform_filename=[pathname,'tform_',NoExtFileName,'.mat'];
save(tform_filename,'tform')

