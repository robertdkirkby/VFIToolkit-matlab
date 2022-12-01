function AgentDist=StationaryDist_FHorz_Case1_TPath_SingleStep_Iteration_noz_raw(AgentDist,AgeWeightParamNames,PolicyIndexesKron,N_d,N_a,N_j,Parameters,simoptions)
% Will treat the agents as being on a continuum of mass 1.

% Options needed
%  simoptions.maxit
%  simoptions.tolerance
%  simoptions.parallel

if simoptions.parallel~=2
    
    AgentDist=reshape(AgentDist,[N_a,N_j]);
%   Implicitly: AgentDist(:,1)=AgentDist(:,1); % Assume that endowment characteristics of newborngeneration are not changing over the transition path.
    
    % Remove the existing age weights, then impose the new age weights at the end 
    % (note, this is unnecessary overhead when the age weights are unchanged, but can't be bothered doing a clearer version)
    AgentDist=AgentDist./(ones(N_a,1)*sum(AgentDist,1)); % Note: sum(AgentDist,1) are the current age weights

    for jj=1:(N_j-1)
        %First, generate the transition matrix P=g of Q (the convolution of the optimal policy function and the transition fn for exogenous shocks)
        Ptranspose=zeros(N_a,N_a); %P(a,aprime)=proby of going to (a') given in (a)
        if N_d==0 %length(n_d)==1 && n_d(1)==0
            optaprime_jj=PolicyIndexesKron(:,jj)'; % Note transpose
        else
            optaprime_jj=PolicyIndexesKron(2,:,jj);
        end
        Ptranspose(optaprime_jj+N_a*(0:1:N_a-1))=1;
        
        AgentDist(:,jj+1)=Ptranspose*AgentDist(:,jj);
    end
    
elseif simoptions.parallel==2 % Using the GPU
        
    % Remove the existing age weights, then impose the new age weights at the end 
    % (note, this is unnecessary overhead when the age weights are unchanged, but can't be bothered doing a clearer version)
    AgentDist=AgentDist./(ones(N_a,1)*sum(AgentDist,1)); % Note: sum(AgentDist,1) are the current age weights
    
%     AgentDist=zeros(N_a,N_j,'gpuArray');
%     AgentDist(:,1)=AgentDist; % Assume that endowment characteristics of newborn
%     generation are not changing over the transition path.
    
    % First, generate the transition matrix P=g of Q (the convolution of the 
    % optimal policy function and the transition fn for exogenous shocks)
    for jj=1:(N_j-1)
        
        if N_d==0 %length(n_d)==1 && n_d(1)==0
            optaprime_jj=reshape(PolicyIndexesKron(:,jj),[1,N_a]);
        else
            optaprime_jj=reshape(PolicyIndexesKron(2,:,jj),[1,N_a]);
        end
        Ptran=zeros(N_a,N_a,'gpuArray');
        Ptran(optaprime_jj+N_a*(gpuArray(0:1:N_a-1)))=1;
        
        AgentDist(:,jj+1)=Ptran*AgentDist(:,jj);
    end
end

% Reweight the different ages based on 'AgeWeightParamNames'. (it is
% assumed there is only one Age Weight Parameter (name))
FullParamNames=fieldnames(Parameters);
nFields=length(FullParamNames);
found=0;
for iField=1:nFields
    if strcmp(AgeWeightParamNames{1},FullParamNames{iField})
        AgeWeights=Parameters.(FullParamNames{iField});
        found=1;
    end
end
if found==0 % Have added this check so that user can see if they are missing a parameter
    fprintf(['FAILED TO FIND PARAMETER ', AgeWeightParamNames{1}])
end
% I assume AgeWeights is a row vector, if it has been given as column then transpose it.
if length(AgeWeights)~=size(AgeWeights,2)
    AgeWeights=AgeWeights';
end

% Need to remove the old age weights, and impose the new ones
% Already removed the old age weights earlier, so now just impose the new ones.
% I assume AgeWeights is a row vector
AgentDist=AgentDist.*(ones(N_a,1)*AgeWeights);

end
