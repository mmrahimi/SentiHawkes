%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Significance test for causal relationships
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

addpath('BasicFunc');
addpath('Data');
addpath('Simulation');
addpath('Learning');
addpath('Analysis');
addpath('Visualization');

clc 
clear
close all

load('.\\Data\\Data_Sequence.mat')

options.dt = 1; % time granularity
options.Tmax = 5000; % the maximum size of time window (for training)
options.M = round(options.Tmax./options.dt);

D = 7; % the dimension of Hawkes processes
nTest = 1; % iterations
Nout = 20; % epochs <--> outer

n_sampling = 1000;

models=cell(4,n_sampling);
seq_time_cell = cell(4,n_sampling);
seq_mark_cell = cell(4,n_sampling);
seq_sentiment_cell = cell(4,n_sampling);

for s=1:4
    for j = 1:n_sampling
        u=[];
        m = 5; %average_block_size
        T = length(Seqs(s).Time);
        u(1) = ceil(T*rand);
        for t=2:T
            if rand<1/m
                u(t) = ceil(T*rand);
            else
                u(t) = u(t-1) + 1;
            end
        end
        
        u = sort(u);
        seq = struct('Time', [], ...
                      'Mark', [], ...
                      'Start', [], ...
                      'Stop', [], ...
                      'Sentiment', [], ...
                      'Location', []);

        seq_time_repl = [Seqs(s).Time;Seqs(s).Time];
        seq.Time = seq_time_repl(u);
        seq_time_cell{s,j} = [seq.Time];

        seq_mark_repl = [Seqs(s).Mark;Seqs(s).Mark];
        seq.Mark = seq_mark_repl(u);
        seq_mark_cell{s,j} = [seq.Mark];
        
        seq_sentiment_repl = [Seqs(s).Sentiment;Seqs(s).Sentiment];
        seq.Sentiment = seq_sentiment_repl(u);
        seq_sentiment_cell{s,j} = [seq.Sentiment];

        seq.Stop = Seqs(s).Stop;
        seq.Start = Seqs(s).Start;
        
        para.mu = rand(D,1)/D;
        para.A = rand(D, D);
        para.A = 0.65 * para.A./max(abs(eig(para.A)));
        para.A = reshape(para.A, [D, 1, D]);
        para.w = 1;

        for n = 1:nTest
            % initialize
            model.A = rand(D,1,D)./(D^2);
            model.mu = rand(D,1)./D;
            model.s = rand(D,1,D)./(D^2);
            model.kernel = 'exp';
            model.w = 1;
            model.landmark = 0;
            alg1.LowRank = 0;
            alg1.Sparse = 1;
            alg1.GroupSparse = 0;
            alg1.alphaS = 10;
            alg1.alphaG = 100; 
            alg1.alphaP = 1000; 
            alg1.outer = Nout;
            alg1.rho = 0.1;
            alg1.inner = 1;
            alg1.thres = 1e-5;
            alg1.Tmax = [];
            alg1.storeErr = 0;
            alg1.storeLL = 0;
            alg1.truth = para;
            model = Learning_MLE_Basis_Feature(seq, model, alg1);
        end
        models{s,j} = model; 
        save('workspaces\significance_test_causal_classes.mat')
    end
end


%%
load('workspaces\significance_test_causal_classes.mat')
A_out = cell(4,1);
A_out_tested = cell(4,1);
dispersion_out = cell(4,1);
mean_value_out = cell(4,1);
confidence_intervals_out_max = cell(4,1);
confidence_intervals_out_min = cell(4,1);

for s=1:4
    events_number = length(Seqs(s).Time);
    A = zeros(D,D,n_sampling);
    for j = 1:n_sampling
        model = models{s,j};
        [A1, Phi1] = ImpactFunc(model, options);
        A(:,:,j) = squeeze(sum(Phi1,2));
    end
    
    A_out{s,1} = A;
    dispersion_out{s,1} = nanstd(A,[],3);
    mean_value_out{s,1} = nanmean(A,3);
    confidence_intervals_out_max{s,1} = mean_value_out{s,1} + 1.96*dispersion_out{s,1}/sqrt(n_sampling);
    confidence_intervals_out_min{s,1} = mean_value_out{s,1} - 1.96*dispersion_out{s,1}/sqrt(n_sampling);
    
    A_out_tested{s,1} = zeros(D,D);
    for i=1:D
        for j=1:D
            values = squeeze(A(i,j,:));
            sd_values = nanstd(values,[],1);
            test_array = values-1.96*sd_values/sqrt(n_sampling);
            if (isempty(test_array(test_array<=0)))
                A_out_tested{s,1}(i,j) = 1;
            end
        end
    end
end
 
%% Comparing causal graphs
figure
counter = 1;
X = categorical({'SCS','FSS','FGS','NMS'});
X = reordercats(X,{'SCS','FSS','FGS','NMS'});
for s = 1:4
    subplot(2,2,counter)
    imagesc(mean_value_out{s,1})
    caxis([0 1]);
    colorbar;
    title(X(s))
    axis square
    counter=counter+1;
end

%% with test

figure
counter = 1;
X = categorical({'SCS','FSS','FGS','NMS'});
X = reordercats(X,{'SCS','FSS','FGS','NMS'});
for s = 1:4
    subplot(2,2,counter)
    imagesc((mean_value_out{s,1} .* A_out_tested{s,1})>0,[0,1])
    caxis([0 1]);
    title(X(s))
    axis square
    counter=counter+1;
end

