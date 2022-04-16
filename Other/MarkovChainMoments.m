function [mean,variance,autocorrelation,statdist]=MarkovChainMoments(z_grid,pi_z,mcmomentsoptions)
% Calculates the mean, variance, autocorrellation, and stantionary
% distribution of a first-order markov process.
% 
% Inputs:
%   - z_grid: the grids for z
%   - pi_z_J: the transition matrix
% Optional inputs:
%   - mcmomentsoptions: allows setting moments
%
% Outputs:
%   - mean: mean of first order markov chain for each age (i.e., age conditional mean)
%   - variance: variance of first order markov chain for each age  (i.e., age conditional variance)
%   - autocorrelation: autocorrelation of first order markov chain for each
%             age, j-th entry is autocorrelation between j and j-1 (hence j=1 is nan)
%   - statdist: stationary distribution of first order markov chain for
%             each age (note the age j=1 will just reproduce jequaloneDist)
%


if exist('mcmomentsoptions','var')==0
    mcmomentsoptions.parallel=1+(gpuDeviceCount>0);
    mcmomentsoptions.eigenvector=1; % Use eigenvector based approach by default
    mcmomentsoptions.T=10^6;
    mcmomentsoptions.Tolerance=10^(-8);
    mcmomentsoptions.calcautocorrelation=1; % Have made it easy to skip calculating autocorrelation as this takes time
else
    if isfield(mcmomentsoptions,'parallel')==0
        mcmomentsoptions.parallel=1+(gpuDeviceCount>0);
    end
    if isfield(mcmomentsoptions,'eigenvector')==0
        mcmomentsoptions.eigenvector=1; % Use eigenvector based approach by default
    end
    if isfield(mcmomentsoptions,'Tolerance')==0
        mcmomentsoptions.Tolerance=10^(-8);
    end
    if isfield(mcmomentsoptions,'T')==0
        mcmomentsoptions.T=10^6;
    end
    if isfield(mcmomentsoptions,'calcautocorrelation')==0
        mcmomentsoptions.calcautocorrelation=1;
    end
end


%% Compute the stationary distribution
if mcmomentsoptions.eigenvector==1
    pi_z_transpose=gather(pi_z');
    % We are only interested in the largest eigenvector.
    % In principle we can do this using eigs(), but this doesn't seem any
    % faster than just using eig() for the kind of Ptraspose matrices in actual
    % economic models (eigs() was faster when I just created random matrices,
    % but when I then implemented it here it was slower)
    % Following commented out line is what I had
    % [V,~] = eigs(Ptranspose,1); % We are only interested in the largest eigenvector
    % Following lines are alternative I found in MNS2016. It includes a bunch
    % of checks of input and output
    assert(all(abs(sum(pi_z_transpose)-1)<1e-10));
    opts.disp=0;
    [x,eval] = eigs(pi_z_transpose,[],1,1+1e-10,opts);
    assert(abs(eval-1)<1e-10);
    V = x/sum(x);
    assert(min(V)>-1e-12);
    V = max(V,0);
    
    statdist=V/sum(V);
    
    % Note that we could check the first eigenvalue, D(1, 1), which should be 1
    % (otherwise it is indicating that the stationary distribution can be
    % reduced, it would be D in [V,D] = eig(Ptranspose',1);).
    % The second eigenvalue would tell us how quickly the markov process
    % converges to the stationary distribution, specifically 1/SecondEigenvalue gives the order of rate of convergence.
    
    %% Personal notes on trying to speed things up.
    % eigs() is faster than eig() as we are only interested in the first eigenvector (which corresponds to the largest eigenvalue)
    % Matlab cannot do eigs for gpu. eig() on gpuArray is slower than eig() on standard array.
    % eig() and eigs() are no faster due to the extreme sparseness of Ptranspose than they would be for a matrix with no zero elements
    % making pi_z a sparse matrix (i.e., sparse(pi_z)) just makes eigs() run slower
else
    pi_z_transpose=pi_z';
    statdist=ones(length(z_grid),1)/length(z_grid);
    currdist=1;
    while currdist>mcmomentsoptions.Tolerance
        statdistold=statdist;
        statdist=pi_z_transpose*statdist;
        currdist=sum(abs(statdist-statdistold));
    end
end

% % Eigenvvector approach to stationary distriubtion 
% % (see https://en.wikipedia.org/wiki/Markov_chain#Stationary_distribution_relation_to_eigenvectors_and_simplices )
% % does not appear to be any faster (in fact marginally slower)
% tic;
% [statdist,~]=eigs(gather(pi_z)',1);
% statdist=statdist./sum(statdist);
% toc

%% Calculate the mean and variance
mean=(z_grid')*statdist;

secondmoment=(z_grid.^2)'*statdist;
variance=secondmoment-mean^2;

covar_withlag=sum(statdist.*sum(pi_z.*((z_grid-mean)*(z_grid-mean)'),2));
autocorrelation=covar_withlag/variance; % Note: demoninator is stdev*stddev, but since they (this period and last period) have the same stdev it is just the variance


%% Following is old code that used to simulate the markov to calculate the autocorrelation. 
% The final line checks it against the new code, and the new code is more
% accurate as well as immesurably faster.

% %% Now for the (first-order auto-) correlation
% % This takes vast majority of the time of MarkovChainMoments()
% % Might be possible to speed this up by using parallelization? Not sure
% % about computing correlation using parallelization (does it converge, and
% % does it work faster?)
% 
% if mcmomentsoptions.calcautocorrelation==1
%     
%     if mcmomentsoptions.parallel==2 || mcmomentsoptions.parallel==4 % Move to cpu for simulation. Is just much faster.
%         z_grid=gather(z_grid);
%     end
%     
%     T=mcmomentsoptions.T;
%     
%     % Simulate Markov chain with transition state pi_z
%     % Maybe I should be doing burnin here??
%     A=zeros(T,1); % A contains the time series of states
%     A(1)=floor(length(z_grid)/2); % Start the simulation in the midpoint
%     shocks_raw=rand(T,1);
%     cumsum_pi_z=cumsum(gather(pi_z),2);
%     for t=2:T
%         temp_cumsum_pi_z=cumsum_pi_z(A(t-1),:);
%         temp_cumsum_pi_z(temp_cumsum_pi_z<=shocks_raw(t))=2;
%         [~,A(t)]=min(temp_cumsum_pi_z);
%     end
%     corr_temp=corrcoef(z_grid(A(2:T)),z_grid(A(1:T-1)));
%     correlation=corr_temp(2,1);
%    
% else
%     correlation=NaN;
% end
% 
% [autocorrelation,correlation]
 
end