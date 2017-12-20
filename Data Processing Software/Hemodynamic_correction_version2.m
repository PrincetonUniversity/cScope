% % %
% % % % BBS 2017
% % %
% % % % Computes the alpha value for hemodynamic correction based on the blue -
% % % % green strobascopic illumination approach.  Requires that you have
% % % % already run Widefield_preprocessing on the data files from the miniscope
% % % % camera system.
% % %
% % % % For each pixel we find alpha where C/C0=(B/B0)/(G/G0) and G=Gmeas-alpha
% % % % by minimizing the difference between the blue and green channel
% over the first five minutes of the imaging session when the vasculature
% is changing.
% % %
%function Hemodynamic_correction_version2
alertme=1; %plays music to let you know the processing is complete
load params
display('Please select a data folder')
folder_name = uigetdir; cd(folder_name);
display('Loading Files');
load preprocess_data; clear mov; load Clocks; load params
%greenmov=greenmov;
%bluemov=bluemov;
cropme=0;
figure
while cropme
    display('Please crop the image');
    img=squeeze(mean(greenmov(:,:,1:1000),3));
    subplot(2,1,1)
    imagesc(img);
    drawnow
    [crop.Y,crop.X] = ginput(2);
    crop.Y=round(crop.Y); crop.X=round(crop.X);
    Y=crop.Y;X=crop.X;
    subplot(2,1,2)
    imagesc(img(X(1):X(2),Y(1):Y(2)));
    
    
    drawnow
    
    prompt = 'Is the crop correct?  Enter 1 for yes, 2 for no. ';
    x = input(prompt);
    if x==1
        cropme=0;
    elseif x==2
        cropme=1;
    else
        display('Please enter 1 to continue or 2 to repeat the crop)');
    end
end
display('Processing Files');
if params.fps==60
fms=2000:40000;
elseif params.fps==30
fms=1000:25000;  
end

%bluemov=bluemov(X(1):X(2),Y(1):Y(2),fms);
%greenmov=greenmov(X(1):X(2),Y(1):Y(2),fms);

bluemov=bluemov(:,:,fms);
greenmov=greenmov(:,:,fms);

blue_clock=blue_clock(fms);
green_clock=green_clock(fms);

%%REMOVE BLANK FRAMES USED FOR SYNCHRONIZATION
mB=squeeze(mean(mean(bluemov)));  mG=squeeze(mean(mean(greenmov)));
blue_clock(mB<mean(mB/4))=[]; green_clock(mG<mean(mG/4))=[];
bluemov(:,:,mB<mean(mB/4))=[];greenmov(:,:,mG<mean(mG/4))=[];

display('Computing');
meanproj = nanmean(greenmov,3); vascMask = single(removeVasculature_LP(meanproj)); vascMask(vascMask==1)=nan;
bluemov=bluemov+repmat(vascMask,1,1,length(bluemov)); %why addition?
frameRate=params.fps;

[XX,YY,~]=size(bluemov);
figure;
pulse_power=nan(XX,YY);
SF_map=pulse_power; errors=pulse_power;
TPF=mode(diff(blue_clock))/2;
clock=blue_clock(start):TPF:blue_clock(end);
figure;

for xx=1:XX
    for yy=1:YY
        if ~isnan(vascMask(xx,yy))
            mB1=squeeze(bluemov(xx,yy,:));
            mB=interp1(blue_clock,mB1,clock);
            bk=mB./nanmean(mB);
            mmG=squeeze(greenmov(xx,yy,:));
            UB=round(min(mmG));
            fits=zeros(UB+1,1);
            
            mmG=interp1(green_clock,mmG,clock);

            for alpha=0:UB;
                mG=mmG-alpha;
                gk=mG/nanmean(mG);
                fits(alpha+1)=nansum((bk-gk).^2);
                
                if alpha==0
                    subplot(3,2,1)
                    R=rot90(bluemov(:,:,1));
                    plot(xx,yy,'.r','MarkerSize',20);
                    imagesc(R);
                    axis off
                    
                    subplot(3,2,2)
                    hold off
                    
                    plot(bk,'b')
                    hold on
                    plot(gk,'g')
                    
                    title('Uncorrected')
                end
                
                subplot(3,2,4) %plot the error function
                
                plot((0:length(fits)-1)/length(fits),log(fits))
                xlabel('Offset/Intensity')
                ylabel('Error')
                minfit=find(fits==min(fits));
                
                subplot(3,2,3)
                tmp=min(fits);
                errors(xx,yy)=log(tmp(1));
                imagesc(rot90(errors));
                title('Residual errors'); axis off
                
                subplot(3,2,5) %plot the map of offsets
                SF_map(xx,yy)=minfit(1);
                imagesc(rot90(SF_map));
                title('Scaling factor'); axis off
            end
            
            subplot(3,2,6); %plot the corrected specturm
            mG=mmG-minfit(1);
            %mG=interp1(green_clock,mG2,clock);
            gk=mG/nanmean(mG);
            
            hold off
            
            plot(bk,'b')
            hold on
            plot(gk,'g')
            
            
            title('Corrected'); drawnow
            %ylim([-14 -4]); xlim([1 10]); drawnow
            
        end
        
    end
end

figure;
subplot(2,2,2)
S=fliplr(rot90(SF_map));
imagesc(S)
box off
axis off
colorbar
G=fliplr(rot90(mean(greenmov,3)));
title('Best fit offset')

subplot(2,2,1)
imagesc(G)
box off
axis off
colorbar
title('Green Channel Intensity')

subplot(2,2,3)
imagesc(S./G)
box off
axis off
colorbar
title('Offset/Intensity')

mode(S(:)./G(:))

nanmedian(S(:))

subplot(2,2,4)
plot(G(:),S(:),'.')
box off
ylabel('Offset')
xlabel('Green channel intensity')
title('Offset vs Intensity')
axis equal

Alpha_map=SF_map;
savefast Alpha_map2 Alpha_map  errors% bluemov greenmov blue_clock green_clock

if alertme
    load handel
    sound(y,Fs)
end