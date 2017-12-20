% Widefield_preprocessing

% Written by BBS 2017

% Performs the following steps on .avi data files collected with the
% miniscope camera using blue - green strobiscopic illumination.
%0) Rename the miniscope files to enable matlab to determine their
%chronological order
%1) Identification of frames dropped by the miniscope acquistion system and correction of the timestamps file
%2) Concatination of individual .avis into a single movie
%3) Downsampling of the movie in X and Y by binning. Sums the pixel values
%and converts to single format.
%4) Splitting movie into blue and green channels and saving as a .mat
%3) Motion correction (optional)
%4) Saving the blue and green channels as TIFFs (optional)
%5) Synchronization between bcontrol file and miniscope timestamps (optional, requires sessdata)

% The User is prompted for input at 4 points during the script.
% First, they are asked to identify the folder that contains the AVI files
% Second they are asked whether the Time per frame (TPF) is correct
% Third, they are asked to specify which channel is the blue illumination
% channel.
% Finaly they are asked to identify the bcontrol data file.

% Before running the script the user should specifc the following parameters
% params.savetif=0;  set to 1 if you want to save blue and green movies as tifs
% params.synchronize=1; set to 1 if you want to syncronize to session data
% params.normcorre=1; set to 1 if you want to motion correct by normcorre
% params.fps=30; 30 or 60 hz depending on your acquisition speed.
% params.binfac=4; downstampling, reduces file size, increases pixel signal
% to noise and speeds up motion correction.  binfac=4 means that you each
% pixel in the final movie corresponds to a 4by4 pixel region in the
% original movie.

function cScope_preprocessing

%USERS step 1 please set your parameters!
alertme=1;
params.concat=1;
params.savetif=1;  %saving the tif is the longest step in this script
params.synchronize=1;
params.binfac=4; %choose 2 or 4
%native movie is 752 by 480

%%OK now select the files you want to preprocess

display('Please select a data folder')
folder_name = uigetdir; cd(folder_name);
display('Processing...')
if params.concat
    params.fps=get_fps;
    renumberfile; %renames the msCam .avi files with the correct number of 0s, 1.avi becomes 001.avi
    if params.fps==60;
        %TPF=16.6725;
        TPF=16.6724;
        %TPF=17.08263;
    elseif params.fps==30;
        %TPF=33.351566;
        %TPF=33.351572; %for 5/5
        TPF=33.351649;
        %TPF=33.3516435;
        %TPF=33.35165;
        %TPF=33.351652;
    end
    
    TPFcheck=1;
    while TPFcheck
        [ts.newsysClock,ts.newframeNum,ts.delete_these_frames]=miniscope_make_new_timestamps(TPF);
        prompt = 'Is the TPF correct?  Enter 1 for yes, 2 for no ';
        x = input(prompt);
        if x==1
            TPFcheck=0;
        elseif x==2
            display(TPF)
            prompt = 'Please enter new TPF';
            TPF = input(prompt);
            
        else
            display('Please enter 1 to continue or 2 to repeat)');
        end
    end
    
    
    %note to self; just look for the existance of preprocess!  dont ask the user
    [bluemov,greenmov]=load_and_concatenate(params.binfac,ts); %loads each .avi;, resizes them, concatenates and saves as a .tf
    %cd(home_folder)
    % savefast full_mov mov crop ts %savefast can be found in the normcorre library
    save Clocks TPF ts
    save params params
else
    load full_mov
    load Clocks
end

[blue_clock,green_clock,bluemov,greenmov]=separate_and_save(ts.newsysClock,ts.newframeNum,bluemov,greenmov);

savefast preprocess_data bluemov greenmov

save Clocks blue_clock green_clock TPF ts

if params.savetif;
    
    load params
    savethetiffs(uint16(bluemov(:,:,1:params.fps:end)),uint16(greenmov(:,:,1:params.fps:end)));
end

%calculate the clock difference between bcontrol and miniscope
if params.synchronize;
    %load preprocess_data
    %load Clocks
    [sessname, PATHNAME] = uigetfile('*.mat','Please select a Bcontrol session file');
    cd(PATHNAME);
    [offset]=synchronize_with_bcontrol(sessname,blue_clock,bluemov,green_clock,greenmov,TPF);
    save Clocks blue_clock green_clock offset TPF ts
end

display('Processing completed')
if alertme
    load handel
    sound(y,Fs)
end
end

%%
function [bmov,gmov]=load_and_concatenate(binfactor,ts)
%profile on
evs=1:2:ts.newframeNum(end);
Bfs=ismember(ts.newframeNum,evs);
warning('off','MATLAB:audiovideo:aviinfo:FunctionToBeRemoved');
curdir=pwd;
fnames=dir('*.avi');
totalnumframes=0;
for i=1:length(fnames)
    AVI=aviinfo(fnames(i).name);
    totalnumframes=AVI.NumFrames+totalnumframes;
end

%make the template
i=round(length(fnames)/2);
V=mmread([pwd '/' fnames(i).name]);
cd(curdir);
thismov = single(accumfun(3, @(x) x.cdata(:,:,1), [V.frames]));

figure;
cropme=1;
while cropme==1
    display('Please crop the image');
    img=squeeze(mean(thismov(:,:,1:1000),3));
    subplot(2,1,1)
    imagesc(img);
    drawnow
    [Y,X] = ginput(2);
    Y=round(Y); X=round(X);

    newX=floor((X(2)-X(1))/binfactor)*binfactor-1;
    newY=floor((Y(2)-Y(1))/binfactor)*binfactor-1;
    X(2)=X(1)+newX;
    Y(2)=Y(1)+newY;
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


thismov=thismov(X(1):X(2),Y(1):Y(2),:);
off=(i-1)*1000;
theseBfs=Bfs((1:size(thismov,3))+off);
b_template=nanmean(thismov(:,:,theseBfs),3);
g_template=nanmean(thismov(:,:,~theseBfs),3);


[height,width,~]=size(thismov);
height=height/binfactor;
width=width/binfactor;

bmov=zeros(height,width,sum(Bfs),'single');
gmov=zeros(height,width,sum(~Bfs),'single');
frameoffset=0;
bmovieoffset=0;
gmovieoffset=0;





for i=1:length(fnames)
    
    display(sprintf('%d of %d',[i length(fnames)]))
    
    V=mmread([pwd '/' fnames(i).name]);
    cd(curdir);
    thismov = single(accumfun(3, @(x) x.cdata(:,:,1), [V.frames]));
    theseBfs=Bfs((1:size(thismov,3))+frameoffset);
    
    
    smallmov=thismov(X(1):X(2),Y(1):Y(2),:);
    %smallmov=thismov;
    bm=smallmov(:,:,theseBfs);
    gm=smallmov(:,:,~theseBfs);
    
%     if i==1
%         [bm_corr,~,b_template] = normcorre_batch(bm);
%         [gm_corr,~,g_template] = normcorre_batch(gm);
%     else
        [bm_corr,~,~] = normcorre_batch(bm,[],b_template);
        [gm_corr,~,~] = normcorre_batch(gm,[],g_template);
    %end
    
    bm_rebinned = rebin(bm_corr, binfactor, [1 2], @mean);
    gm_rebinned  = rebin(gm_corr, binfactor, [1 2], @mean);
    
    bmov(:,:,(1:size(bm_rebinned,3))+bmovieoffset)=bm_rebinned;
    gmov(:,:,(1:size(gm_rebinned,3))+gmovieoffset)=gm_rebinned;
    frameoffset=frameoffset+1000;
    bmovieoffset=bmovieoffset+size(bm_rebinned,3);
    gmovieoffset=gmovieoffset+size(bm_rebinned,3);
    
end
crop.X=X;
crop.Y=Y;

end

%%
function [blue_clock,green_clock,bluemov,greenmov]=separate_and_save(newsysClock,newframeNum,bluemov,greenmov)

%mov=FI(:,:,logical(~delete_these_frames));
evs=1:2:newframeNum(end);
Bfs=find(ismember(newframeNum,evs));
blue_clock=newsysClock(Bfs);
%bluemov=mov(:,:,Bfs);

ods=2:2:newframeNum(end);
Gfs=find(ismember(newframeNum,ods));
green_clock=newsysClock(Gfs);
%greenmov=mov(:,:,Gfs);

%%If the Arduino is not re-initialized between imaging sessions the frame order may be reversed
% one session you could have BGBG
% on the other you could have GBGB

%lets verifty the movie order is correct
figure;
subplot(2,1,1)
imagesc(bluemov(:,:,2))
title('1')

subplot(2,1,2)
imagesc(greenmov(:,:,2))
title('2')
check_movie=1;
while check_movie
    prompt = 'Which panel is the blue LED movie, 1 or 2? ';
    x = input(prompt);
    if x==1
        check_movie=0;
    elseif x==2
        check_movie=0;
        tmpc=green_clock; green_clock=blue_clock; blue_clock=tmpc;
        tmpm=greenmov; greenmov=bluemov; bluemov=tmpm;
    else
        display('Please enter 1 or 2');
    end
    
end
end
%%

function savethetiffs(bluemov,greenmov)
fname='bluemov.tif';
imwrite(bluemov(:,:,2), fname,'writemode', 'overwrite')
[~,~,Z]=size(bluemov);
for k = 2:Z
    imwrite(bluemov(:,:,k), fname, 'writemode', 'append');
end
clear bluemov

[~,~,Z]=size(greenmov);
fname='greenmov.tif';
imwrite(greenmov(:,:,2), fname,'writemode', 'overwrite')
for k = 2:Z
    imwrite(greenmov(:,:,k), fname, 'writemode', 'append');
end
end

%%
function [offset]=synchronize_with_bcontrol(sessname,blue_clock,bluemov,green_clock,greenmov,TPF)
%calculates the offset in ms you must apply to the clocks in order to
%synchronize the clocks

load(sessname);
%
scopeon=zeros(length(S.peh{1}));
scopeoff=scopeon;
for k=1:length(S.peh{1})
    if ~isempty(S.peh{1}(k).waves.TrigScope);
        scopeon(k)=S.peh{1}(k).waves.TrigScope(1);
        scopeoff(k)=S.peh{1}(k).waves.TrigScope(2);
    end
end

scopeon(scopeon==0)=[];
scopeoff(scopeoff==0)=[];

% converting time to ms, round to the nearest ms
scopeon=round(scopeon*1000);
scopeoff=round(scopeoff*1000);

scopeontimes=zeros(size(0:scopeoff(end)));
%
%
for g=1:length(scopeon)
    scopeontimes(scopeon(g):scopeoff(g))=1;
end

%%ok now we compute the green frames

%greenmov(:,:,1)=greenmov(:,:,2); %first green image is always bank
Y=squeeze(mean(mean(greenmov)));
Z=squeeze(mean(mean(bluemov)));

TT=[green_clock;blue_clock];
[clock,frameorder]=sort(TT);
Y=[Y;Z];
Y=Y(frameorder);
Y(1:10)=nanmean(Y(11:15));

blank_frames=Y<mean(Y)/4; %threshold is a quarter of the signal; ones where the LED is off

%first blank frame is actually up to 3 frames after the trigger pulse
%lets say it occurs near the beginning of a blue frame then the next green will be triggered and the next blue
%which is up to 90ms away

T=0:clock(end);
blank_frames_ms=interp1(clock,single(blank_frames),T); %put the LED into ms
%T(rmv)=[];
rmv=isnan(blank_frames_ms); %
blank_frames_ms(rmv)=0;
%scopeontimes(rmv)=[];
first_sync_on_green=find(diff(blank_frames_ms)>0);
first_sync_on_green=first_sync_on_green(1);

first_sync_on_bcontrol=find(diff(scopeontimes)>0);
first_sync_on_bcontrol=first_sync_on_bcontrol(1);


% X=xcorr(scopeontimes,blank_frames_ms);
% X(1:length(scopeontimes))=[];
%
% offset=find(X==max(X))+TPF*1.5;  %still not sure about this offset!
%
% if TPF<20;
%     offset=offset/2-1250;  %for some reason looks like the 60 hz recording session, the offset is 2X as big
% end
% figure;
% hold on
%
% plot((1:length(blank_frames_ms))+offset,blank_frames_ms,'.-g','MarkerSize',20);
%
% plot(scopeontimes-1,'.-k','MarkerSize',20)
% xlabel('Frame number')
% ylabel('Sync events')
%
% checkoffset=1;
% while checkoffset
%     prompt = 'Does this offset look reasonable?  Enter 1 for yes, 2 for no. ';
%     x = input(prompt);
%     if x==1
%         checkoffset=0;
%     elseif x==2


offset=first_sync_on_bcontrol-first_sync_on_green+TPF/2;

figure;
hold on

plot((1:length(blank_frames_ms))+offset,blank_frames_ms,'.-g','MarkerSize',20);

plot(scopeontimes-1,'.-k','MarkerSize',20)
xlabel('Frame number')
ylabel('Sync events')

%  end
%end
end

%%
function renumberfile
files=dir('*.avi');
for i =1:length(files)
    n=regexp(files(i).name,'\d');
    if numel(n)==1;
        newname=['msCam00' num2str(files(i).name(n)) '.avi'];
        movefile(files(i).name,newname)
    elseif numel(n)==2;
        newname=['msCam0' num2str(files(i).name(n)) '.avi'];
        movefile(files(i).name,newname)
    end
end
end
%%
function [fps,TPF]=get_fps

timestamps=importdata('timestamp.dat');
sysClock=timestamps.data(:,3);
TPF=mode(diff(sysClock));
fps=1000/TPF;
fps=round(fps/10)*10;
end

%%
function [newstack]=resize_stack(stack,n)

[X,Y,Z]=size(stack);
XX=floor(X/n);
YY=floor(Y/n);
newstack=nan(XX,YY);
for z=1:Z
    for x=1:XX;
        for y=1:YY
            pixel=stack(((x-1)*n+1):x*n,((y-1)*n+1):y*n,z);
            newstack(x,y,z)=mean(pixel(:));
        end
    end
end
end
