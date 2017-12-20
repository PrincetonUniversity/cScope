function Widefield_analysis
alertme=1; bluemov=[];greenmov=[];
display('Please select a data folder')
folder_name = uigetdir; cd(folder_name);

display('Loading data')
load Alpha_map2 
load Clocks 
load preprocess_data

% if exist('crop','var')
%     display('Crop file exists')
%     Y=crop.Y;X=crop.X;
%     display('Cropping blue movie')
%     bluemov=bluemov(X(1):X(2),Y(1):Y(2),:);
%     display('Cropping green movie')
%     greenmov=greenmov(X(1):X(2),Y(1):Y(2),:);
% else
%     display('Crop file does not exists, loading movies from Alpha_map file')
% end
display('Loading complete.  Processing...')

%remove blank frames
display('Removing blank frames')
mB=squeeze(nanmean(nanmean(bluemov)));

blank=mB<(nanmean(mB)/4) ;
figure; plot(blue_clock(~blank)/60000,mB(~blank),'b')
hold on
bluemov(:,:,blank)=[];
blue_clock(blank)=[];
mG=squeeze(nanmean(nanmean(greenmov)));

blank=mG<(nanmean(mG)/4) ;
plot(green_clock(~blank)/60000,mG(~blank),'g')
xlabel('Time (min)')
drawnow
greenmov(:,:,blank)=[];
green_clock(blank)=[];

display('Offset correction')
greenmov = greenmov-repmat(Alpha_map,1,1,length(greenmov)); %correct offset & remove vasculature

display('Computing F/F0')

F0=nanmean(bluemov,3);
F0=repmat(F0,1,1,length(bluemov));
bluemov=bluemov./F0;

F0=nanmean(greenmov,3);
F0=repmat(F0,1,1,length(greenmov));
greenmov=greenmov./F0;

[Y,X,~]=size(greenmov);
G = interp3(1:X,1:Y,green_clock,greenmov,1:X,1:Y,blue_clock);

display('Performing hemodynamic correction')

GCAMP=bluemov./G;
H=-G;
clock=blue_clock+offset+blue_clock*scaler;

% cGCAMP=GCAMP;
% % sliding BK correction
% display('Computing sliding background correction')
% [X,Y,~]=size(GCAMP);
% load params
% ws=30;
% wsSamp=ws*params.fps;
% for ii=1:X
%     for jj=1:Y
%         dt=squeeze(GCAMP(ii,jj,:));
%          F0   = halfSampleMode(dt,wsSamp);
%         cGCAMP(ii,jj,:)=dt./F0;
%     end
% end
    
        

display('Saving')
savefast corrected_data GCAMP H clock 
display('Completed')

% Play victorious music
if alertme
    load handel
    sound(y,Fs)
end

