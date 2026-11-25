function plot_airgesture()
% AIRGESTURE actual archive/model visualization. MATLAB R2020a or newer.
% Run this function with model_data.json and video_inventory.csv beside it.
% No Deep Learning Toolbox or Python required.
base = fileparts(mfilename('fullpath'));
out = fullfile(base,'figures');
if ~exist(out,'dir'), mkdir(out); end
T = readtable(fullfile(base,'video_inventory.csv'),'TextType','string');
M = jsondecode(fileread(fullfile(base,'model_data.json')));
labels = ["volume_ready","fist","open_palm","media2","ppt3","other"];
teal = [0.08 0.45 0.54]; orange = [0.89 0.55 0.15];
font = 'Malgun Gothic';
assert(all(ismember(T.label,labels)), 'Unknown dataset label');
assert(isequal(size(M.weight_0),[63 64]));
assert(isequal(size(M.weight_1),[64 32]));
assert(numel(M.weight_2)==32 && numel(M.mean)==63);
assert(all(M.scale>0) && M.threshold>0 && M.threshold<1);
N=zeros(1,6); F=N; D=N;
for k=1:6
    q=T.label==labels(k);
    N(k)=sum(q); F(k)=sum(T.header_frames(q)); D(k)=sum(T.header_seconds(q));
end

% 1. Counts from the actual video ZIP, NOT training sample counts.
f=newfig('Dataset inventory',font);
tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
ax=nexttile; b=bar(ax,N,'FaceColor','flat');
b.CData=repmat(teal,6,1); b.CData(1,:)=orange;
set(ax,'XTick',1:6,'XTickLabel',labels,'TickLabelInterpreter','none');
xtickangle(ax,25); ylabel(ax,'Video files'); ylim(ax,[0 max(N)*1.35]);
title(ax,'수집 영상 수: 라벨별 실제 집계'); grid(ax,'on');
for k=1:6,text(ax,k,N(k)+.08,string(N(k)),'HorizontalAlignment','center');end
ax=nexttile;bar(ax,F,'FaceColor',teal);
set(ax,'XTick',1:6,'XTickLabel',labels,'TickLabelInterpreter','none');
xtickangle(ax,25);ylabel(ax,'Frames recorded in AVI headers');
title(ax,'AVI 헤더 프레임 수: 최종 학습 샘플 수와 다름');grid(ax,'on');
sgtitle(f,sprintf('Dataset ZIP: %d videos / %d header frames',height(T),sum(F)));
savefigures(f,out,'01_dataset_counts');

% 2. Binary mapping for the intended MLP task, at VIDEO level.
f=newfig('Binary labels',font);
ax=axes(f); cnt=[sum(T.binary_label==1),sum(T.binary_label==0)];
b=bar(ax,cnt,'FaceColor','flat');b.CData=[orange;teal];
set(ax,'XTick',1:2,'XTickLabel',{'VOLUME_READY (1)','NOT_VOLUME_READY (0)'},'TickLabelInterpreter','none');
ylabel(ax,'Video files');ylim(ax,[0 max(cnt)*1.3]);grid(ax,'on');
for k=1:2,text(ax,k,cnt(k)+.3,sprintf('%d videos (%.1f%%)',cnt(k),100*cnt(k)/sum(cnt)),...
        'HorizontalAlignment','center','FontSize',16);end
title(ax,{'이진 라벨 구성: 수집 영상 기준','모델 학습 시 샘플링·분할·클래스 가중치는 기록 확인 필요'});
savefigures(f,out,'02_binary_video_counts');

% 3. Real network dimensions. Draw representative neurons only.
f=newfig('MLP structure',font);ax=axes(f);hold(ax,'on');axis(ax,[0 5 0 1]);axis(ax,'off');
sizes=[size(M.weight_0,1),size(M.weight_0,2),size(M.weight_1,2),1];
visible=[6 7 5 1]; xpos=[.5 1.8 3.1 4.4]; yy=cell(1,4);
for k=1:4
    if visible(k)==1,yy{k}=.5;else,yy{k}=linspace(.25,.73,visible(k));end
end
for k=1:3
    for a=yy{k}
        for b=yy{k+1}
            plot(ax,[xpos(k),xpos(k+1)],[a b],'-','Color',[.80 .85 .88],'LineWidth',.6);
        end
    end
end
names={'입력 특징','은닉층 1','은닉층 2','출력 점수'};
acts={'전처리 좌표','ReLU','ReLU','Sigmoid'};
for k=1:4
    col=teal;if k==4,col=orange;end
    scatter(ax,repmat(xpos(k),size(yy{k})),yy{k},420,col,'filled','MarkerEdgeColor','white','LineWidth',1.5);
    text(ax,xpos(k),.89,sprintf('%s\n%d',names{k},sizes(k)),...
        'HorizontalAlignment','center','FontSize',20,'FontWeight','bold');
    text(ax,xpos(k),.15,acts{k},'HorizontalAlignment','center','FontSize',18);
    if k<4,text(ax,xpos(k),.20,'...','HorizontalAlignment','center','FontSize',20);end
end
title(ax,'실제 저장 모델: 63 → 64 → 32 → 1','FontSize',25);
text(ax,2.5,.045,sprintf('대표 뉴런만 표시 / 실제 연결은 전결합 / 보강 임계값 %.2f',M.threshold),...
    'HorizontalAlignment','center','FontSize',16);
savefigures(f,out,'03_mlp_structure');

% 4. Actual learned parameters, no synthetic/random matrix.
f=newfig('Learned weights',font);
tiledlayout(f,1,3,'TileSpacing','compact','Padding','compact');
W={M.weight_0,M.weight_1,M.weight_2(:)};
lim=max(cellfun(@(x)max(abs(x(:))),W));
if lim==0,lim=1;end
for k=1:3
    ax=nexttile;imagesc(ax,W{k});axis(ax,'tight');caxis(ax,[-lim lim]);colorbar(ax);
    xlabel(ax,'Output neuron');ylabel(ax,'Input feature / neuron');
    title(ax,sprintf('W%d: %d x %d',k,size(W{k},1),size(W{k},2)));
end
sgtitle(f,'학습된 가중치 행렬: npz에서 추출한 실제 값');
savefigures(f,out,'04_learned_weights');

% 5. Flatten order exactly matches Python reshape(63).
f=newfig('Feature layout',font);ax=axes(f);
idx=reshape(1:63,3,21);imagesc(ax,idx);colormap(ax,parula(63));
set(ax,'XTick',1:21,'XTickLabel',0:20,'YTick',1:3,'YTickLabel',{'x','y','z'});
xlabel(ax,'MediaPipe landmark ID (0-based)');ylabel(ax,'Coordinate');
for i=1:21
    for j=1:3
        text(ax,i,j,string(idx(j,i)),'HorizontalAlignment','center','FontSize',11,'FontWeight','bold','Color','black');
    end
end
title(ax,{'21개 랜드마크 × 3개 좌표 = 63개 특징','칸의 숫자는 MATLAB 특징 인덱스(1~63), 색상은 값이나 중요도가 아님'});
savefigures(f,out,'05_feature_order');

% 6. End-to-end components drawn natively in MATLAB.
f=newfig('Pipeline',font);ax=axes(f);hold(ax,'on');axis(ax,[0 12 0 7]);axis(ax,'off');
drawbox(ax,[.25 4.7 2.3 1.2],{'USB webcam','640 x 480'},teal);
drawbox(ax,[3.15 4.7 2.3 1.2],{'MediaPipe','21 x (x,y,z)'},teal);
drawbox(ax,[6.05 4.7 2.3 1.2],{'좌표 전처리','63개 특징'},teal);
drawbox(ax,[8.95 4.7 2.7 1.2],{'MLP 63-64-32-1','VOLUME_READY 점수'},orange);
for x=[2.55 5.45 8.35],quiver(ax,x,5.3,.55,0,0,'Color',teal,'LineWidth',2,'MaxHeadSize',.8);end
drawbox(ax,[3.15 2 3.05 1.2],{'관절 각도 기반','기존 규칙 판정'},teal);
drawbox(ax,[8.45 2 3.2 1.2],{'점수 + 보호 조건','최종 자세 보강'},orange);
quiver(ax,4.3,4.7,0,-1.45,0,'Color',teal,'LineWidth',2,'MaxHeadSize',.35);
quiver(ax,10.3,4.7,0,-1.45,0,'Color',orange,'LineWidth',2,'MaxHeadSize',.35);
quiver(ax,6.2,2.6,2.2,0,0,'Color',teal,'LineWidth',2,'MaxHeadSize',.3);
text(ax,6,.85,'MLP는 정적 음량 준비 자세를 보강하며 회전·스와이프는 별도로 판정',...
    'HorizontalAlignment','center','FontSize',17);
title(ax,'영상 입력에서 규칙·MLP 결합까지','FontSize',25);
savefigures(f,out,'06_pipeline');

writetable(table(labels(:),N(:),F(:),D(:),'VariableNames',...
    {'Label','VideoCount','HeaderFrames','HeaderSeconds'}),fullfile(out,'dataset_summary.csv'));
fprintf('Saved 6 figures as PNG, PDF and FIG to:\n%s\n',out);
fprintf('MLP parameters (weights + biases): %d\n',...
    sum(cellfun(@numel,W))+numel(M.bias_0)+numel(M.bias_1)+numel(M.bias_2));
end

function f=newfig(name,font)
f=figure('Name',name,'Color','w','Position',[80 80 1280 720]);
set(f,'DefaultAxesFontName',font,'DefaultTextFontName',font,...
    'DefaultAxesFontSize',14,'DefaultTextInterpreter','none');
end
function drawbox(ax,pos,words,col)
rectangle(ax,'Position',pos,'Curvature',.12,'EdgeColor',col,'LineWidth',2,'FaceColor',[.96 .98 .99]);
text(ax,pos(1)+pos(3)/2,pos(2)+pos(4)/2,words,'HorizontalAlignment','center','FontSize',16);
end
function savefigures(f,out,name)
drawnow;
exportgraphics(f,fullfile(out,[name '.png']),'Resolution',300);
exportgraphics(f,fullfile(out,[name '.pdf']),'ContentType','vector');
savefig(f,fullfile(out,[name '.fig']));
end
