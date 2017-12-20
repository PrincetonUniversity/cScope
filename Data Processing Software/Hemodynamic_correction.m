% % [SF_map]=Hemodynamic_correction
%
% % BBS 2017
%
% % Computes the alpha value for hemodynamic correction based on the blue -
% % green strobascopic illumination approach.  Requires that you have
% % already run Widefield_preprocessing on the data files from the miniscope
% % camera system.
%
% % For each pixel we find alpha where C/C0=(B/B0)/(G/G0) and G=Gmeas-alpha
% % by minimizing the power in the pulse, the ~6hz window corresponding to the
% % heart beat of the animal. the user is asked to crop the image (to exclude
% % metamond for example) and to identify the pulse frequency window.
%
%function Hemodynamic_correction
alertme=1; %plays music to let you know the processing is complete

%ignore the first 5 mintue
load params
%first5=params.fps/2*300;
%next10=10000+first5;

display('Please select a data folder')
folder_name = uigetdir; cd(folder_name);
display('Loading Files');
load preprocess_data; clear mov; load Clocks; load params
cropme=1;
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

fms=1000:10000;
bluemov=bluemov(X(1):X(2),Y(1):Y(2),fms);
greenmov=greenmov(X(1):X(2),Y(1):Y(2),fms);

blue_clock=blue_clock(fms);
green_clock=green_clock(fms);


%%REMOVE BLANK FRAMES USED FOR SYNCHRONIZATION
mB=squeeze(mean(mean(bluemov)));  mG=squeeze(mean(mean(greenmov)));
blue_clock(mB<mean(mB/4))=[]; green_clock(mG<mean(mG/4))=[];
bluemov(:,:,mB<mean(mB/4))=[];greenmov(:,:,mG<mean(mG/4))=[];


display('Computing');
meanproj = nanmean(bluemov,3); vascMask = single(removeVasculature_LP(meanproj)); vascMask(vascMask==1)=nan;
bluemov=bluemov+repmat(vascMask,1,1,length(bluemov)); %why addition?
frameRate=params.fps;



%%check the whole movie to identify pulse frequency
whole_frame_green=double(squeeze(nanmean(nanmean(greenmov))));
TPF=mode(diff(blue_clock))/2;
clock=blue_clock(start):TPF:blue_clock(end);
WFG=interp1(green_clock,whole_frame_green,clock);

F0=nanmean(WFG);
K=WFG./F0;
figure;
subplot(2,1,1)
plot(clock,WFG);
hold on
plot(clock,F0);
subplot(2,1,2)
plot(clock,K);
drawnow
K(isnan(K))=[];

[f,P1]=compute_spectrum(K,frameRate); %compute the power spectum
%x1b=5.3; x2b=6; % first guess
pulsecheck=1;
while pulsecheck
    figure
    subplot(2,1,2)
    hold on
    plot(f(f>0.1),log(P1(f>0.1)),'.')
    ylabel('Power'); xlabel('Frequency (hz)'); box off; title('Whole field PSD')
    [Y,~] = ginput(2);
    x1b=Y(1);
    x2b=Y(2);
    
    subplot(2,1,2)
    hold on
    plot(f(f>0.1),log(P1(f>0.1)),'.')
    plot(f(f>1 & f<x1b),log(P1(f>1 & f<x1b)),'.b')
    plot(f(f>x1b & f<x2b),log(P1(f>x1b & f<x2b)),'.r')
    ylabel('Power'); xlabel('Frequency (hz)'); box off; title('Whole field PSD')
    prompt = 'Is the frequency window correct for the pulse?  Enter 1 for yes, 2 for no ';
    x = input(prompt);
    if x==1
        pulsecheck=0;
        pulse_window=Y;
    elseif x==2
        pulsecheck=1;
    else
        display('Please enter 1 to continue or 2 to repeat)');
    end
end



figure
spectrogram(WFG,256,250,[],30,'yaxis')
ylim([.5 10])
title('Green channel spectrogram')


[XX,YY,~]=size(bluemov);
figure;
pulse_power=nan(XX,YY);
SF_map=pulse_power;
DF=25; %factor that reduces the number of points we hunt over
clock=0:TPF:blue_clock(end);
%wsSamp=120*params.fps; %omputes a 2 min

for xx=1:XX
    for yy=1:YY  
      mB1=double(squeeze(bluemov(xx,yy,:)));
      mB=interp1(blue_clock,mB1,clock);
      bK=mB./nanmean(mB);
      mmG=double(squeeze(greenmov(xx,yy,:)));
        UB=round((min(mmG)*.95)/DF);
        %UB=round((min(mmG)*.65)/DF);
        fits=zeros(UB+1,1);
        R=bK;R(isnan(R))=[];
        mmG=interp1(green_clock,mmG,clock);
        
        if ~isempty(R)
            
            for alpha=0:UB;
                mG=mmG-alpha*DF;
                gK=mG/nanmean(mG);
                
                K=bK./gK;
                K(isnan(K))=[];
                
                [f,P1]=compute_spectrum(K,frameRate); %compute the power spectum
                
                %%calculate the power in the pulse channel
                Y2=log(P1(f>=x1b & f<=x2b));
                
                Xvec=f(f>1 & f<x1b)';
                X2vec=ones(size(Xvec));
                Xvec=[Xvec X2vec];
                Yvec=log(P1(f>1 & f<x1b))';
                B=regress(Yvec,Xvec);
                pred=B(1)*f(f>=x1b & f<=x2b)+B(2);
                
                error_fun=sqrt(sum((Y2-pred).^2));
                
                fits(alpha+1)=error_fun;
                
                if alpha==0
                    subplot(3,2,1)
                    R=rot90(bluemov(:,:,1));
                    plot(xx,yy,'.r','MarkerSize',20);
                    imagesc(R);
                    axis off
                    
                    subplot(3,2,2)
                    hold off
                    
                    plot(f(f>0.1),log(P1(f>0.1)),'.')
                    hold on
                    plot(f(f>1 & f<x2b),B(1)*f(f>1 & f<x2b)+B(2),'y','LineWidth',3)
                    plot(f(f>=x1b & f<=x2b),pred,'r','LineWidth',3)
                    
                    ylabel('Power'); xlabel('Frequency (hz)'); box off; title(sprintf('Pixel %d and %d',xx,yy))
                    patch([x1b x2b x2b x1b],[-2 -2 -15 -15],[1 0.5 1],'LineStyle','none','FaceAlpha',.2)
                    title('Uncorrected')
                    ylim([-14 -4]); xlim([1 10]);
                    
                    subplot(3,2,3)
                    pulse_power(xx,yy)=error_fun;
                    imagesc(rot90(pulse_power))
                    title('Pulse Power'); axis off
                end
                
                subplot(3,2,4) %plot the error function
                
                plot((0:length(fits)-1)/length(fits)*.95,fits)
                xlabel('Offset/Intensity')
                ylabel('Pulse Power')
                minfit=find(fits==min(fits))*DF;
                
                subplot(3,2,5) %plot the map of offsets
                SF_map(xx,yy)=minfit(1);
                imagesc(rot90(SF_map));
                title('Scaling factor'); axis off
            end
            
            subplot(3,2,6); %plot the corrected specturm
            mG=mmG-minfit(1);
            %mG=interp1(green_clock,mG2,clock);
            gK=mG/nanmean(mG);
            K=bK./gK;
            K(isnan(K))=[];
            [f,P1]=compute_spectrum(K,frameRate); %compute the power spectum
            Xvec=f(f>1 & f<x1b)';
            X2vec=ones(size(Xvec));
            Xvec=[Xvec X2vec];
            Yvec=log(P1(f>1 & f<x1b))';
            B=regress(Yvec,Xvec);
            pred=B(1)*f(f>=x1b & f<=x2b)+B(2);
            hold off
            plot(f(f>0.1),log(P1(f>0.1)),'.')
            hold on
            
            plot(f(f>1 & f<x2b),B(1)*f(f>1 & f<x2b)+B(2),'y','LineWidth',3)
            plot(f(f>=x1b & f<=x2b),pred,'r','LineWidth',3)
            
            ylabel('Power'); xlabel('Frequency (hz)'); box off; title(sprintf('Pixel %d and %d',xx,yy))
            patch([x1b x2b x2b x1b],[-2 -2 -15 -15],[1 0.5 1],'LineStyle','none','FaceAlpha',.2)
            title('Corrected')
            ylim([-14 -4]); xlim([1 10]); drawnow
            
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
savefast Alpha_map Alpha_map pulse_power crop pulse_window % bluemov greenmov blue_clock green_clock

if alertme
    load handel
    sound(y,Fs)
end