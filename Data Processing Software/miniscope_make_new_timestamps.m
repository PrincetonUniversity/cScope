%this script reads the timestamps.dat file and used the interframe interval
%from the sysClock vector to find "unstable periods" and to indentify the
%number of dropped frames;  the script then recomputes the timestamps and
%and deletes the frames with inaccurate timestamps from the movie
function [newsysClock,newframeNum,delete_these_frames]=miniscope_make_new_timestamps(TPF)
%import miniscope data
timestamps=importdata('timestamp.dat');
sysClock=timestamps.data(:,3);
sysClock(1)=0;
frameNum=timestamps.data(:,2);
clear timestamps

%for debugging purposes
R_n=sysClock - (frameNum-1)*TPF;
figure
subplot(1,2,1)
plot(frameNum,R_n,'.'); hold on
for i=1:round(R_n(end)/TPF)
    plot([0 frameNum(end)],[floor(TPF*i) floor(TPF*i)],'b')
end
xlabel('Frame Number')
ylabel('Clock differential (ms)')
title('Before correction')
box off; set(gca,'tickdir','out')
axis tight
%identify unstable events
IFI=diff(sysClock);
upperthresh=TPF+1; lowerthresh=TPF-1;
%upperthresh=34; lowerthresh=33;
events=find(IFI>upperthresh); 
duplicates=find(diff(events)==1); events(duplicates+1)=[]; %remove duplicates


normaltimes=find(IFI<=upperthresh & IFI>=lowerthresh);

dT=zeros(length(events),1);
NoF=zeros(length(events),1);
lost_frames=dT;
delete_these_frames=zeros(frameNum(end),1);
newframeNum=frameNum;
for k=1:length(events);
    backtonormal=normaltimes(normaltimes>events(k));
    double_check=backtonormal(2:end)-backtonormal(1:end-1);
    double_check=find(double_check==1);
    %backtonormal=backtonormal(double_check(1))+1;
    %theseframes=events(k)-1:backtonormal;
    if ~isempty(double_check)
        backtonormal=backtonormal(double_check(1))+2;
    else
        backtonormal=frameNum(end-1);
    end
    
    theseframes=events(k)-2:backtonormal;
    theseframes(theseframes==0)=[];
    
    
    dT(k)=sum(IFI(theseframes));
    NoF(k)=length(theseframes);
    lost_time=dT(k)-NoF(k)*TPF;
    if lost_time>(TPF/2)
    lost_frames(k)=round(lost_time/TPF);
    delete_these_frames(theseframes+1)=1;
    newframeNum(theseframes(end):end)= newframeNum(theseframes(end):end)+lost_frames(k);
    plot(find(delete_these_frames), R_n(find(delete_these_frames)),'.r','MarkerSize',20)
    end
    
end
newframeNum(logical(delete_these_frames))=[];
newsysClock=(newframeNum-1)*TPF;

% %now check to make sure eveything look oks:
R_n=newsysClock - (newframeNum-1)*TPF;
subplot(1,2,2)
plot(newframeNum,R_n); hold on
for i=1:round(R_n(end)/TPF)
    plot([0 newframeNum(end)],[TPF*i-1 TPF*i-1])
end
title('After correction')
xlabel('Frame Number')
box off
set(gca,'tickdir','out')
ylabel('Clock differential (ms)')
xlim([0 newframeNum(end)])




