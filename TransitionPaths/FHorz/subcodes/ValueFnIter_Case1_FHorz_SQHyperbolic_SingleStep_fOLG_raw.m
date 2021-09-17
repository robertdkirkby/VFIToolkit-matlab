function [V,Policy2]=ValueFnIter_Case1_FHorz_SQHyperbolic_SingleStep_fOLG_raw(V,n_d,n_a,n_z,N_j, d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions)
% fastOLG just means parallelize over "age" (j)
% Note, with Sophisticated QuasiHyperbolic V contains both Vunderbar and Vhat, the
% exponential discount of the sophisticated policy and sophisticated quasi-hyperbolic discounter
% respectively, while Policyhat is the sophisticated quasi-hyperbolic discounter.
%
% V.Vunderbar
% V.Vhat
%
% % Quasi-hyperbolic discount factors
% beta=prod(DiscountFactorParamsVec(1:end-1));
% beta0beta=prod(DiscountFactorParamsVec); % Discount rate between present period and next period

N_d=prod(n_d);
N_a=prod(n_a);
N_z=prod(n_z);

Policyhat=zeros(N_a,N_z,N_j,'gpuArray'); %first dim indexes the optimal choice for d and aprime rest of dimensions a,z

%%
eval('fieldexists_ExogShockFn=1;vfoptions.ExogShockFn;','fieldexists_ExogShockFn=0;')

%% First, create the big 'next period (of transition path) expected value fn.

% VfastOLG will be N_d*N_aprime by N_a*N_z*N_j (note: N_aprime is just equal to N_a)

% Create a matrix containing all the return function parameters (in order).
% Each column will be a specific parameter with the values at every age.
ReturnFnParamsAgeMatrix=CreateAgeMatrixFromParams(Parameters, ReturnFnParamNames,N_j); % this will be a matrix, row indexes ages and column indexes the parameters (parameters which are not dependent on age appear as a constant valued column)

if fieldexists_ExogShockFn==0
    z_grid_AllAges=z_grid.*ones(1,N_j);
    pi_z_AllAges=pi_z.*ones(1,1,N_j);
elseif fieldexists_ExogShockFn==1
    for jj=1:N_j
        if fieldexists_ExogShockFnParamNames==1
            ExogShockFnParamsVec=CreateVectorFromParams(Parameters, vfoptions.ExogShockFnParamNames,jj);
            [z_grid,pi_z]=vfoptions.ExogShockFn(ExogShockFnParamsVec);
            z_grid_AllAges(:,jj)=gpuArray(z_grid); pi_z_AllAges(:,:,jj)=gpuArray(pi_z);
        else
            [z_grid,pi_z]=vfoptions.ExogShockFn(jj);
            z_grid_AllAges(:,jj)=gpuArray(z_grid); pi_z_AllAges(:,:,jj)=gpuArray(pi_z);
        end
    end
end
z_grid_AllAges=z_grid_AllAges'; % Give it the size required for CreateReturnFnMatrix_Case1_Disc_Par2_fastOLG(): N_j-by-N_z
pi_z_AllAges=permute(pi_z_AllAges,[3,2,1]); % Give it the size best for the loop below: (j,z',z)

ReturnMatrix=CreateReturnFnMatrix_Case1_Disc_Par2_fastOLG(ReturnFn, n_d, n_a, n_z, N_j, d_grid, a_grid, z_grid_AllAges, ReturnFnParamsAgeMatrix);

% ReturnMatrix=permute(ReturnMatrix,[1 2 4 3]); % Swap j and z (so that z is last) 
% Modified CreateReturnFnMatrix_Case1_Disc_Par2_fastOLG to eliminate this step.
ReturnMatrix=reshape(ReturnMatrix,[N_d*N_a,N_a*N_j,N_z]);

DiscountFactorParamsVec=CreateAgeMatrixFromParams(Parameters, DiscountFactorParamNames,N_j);
% DiscountFactorParamsVec=prod(DiscountFactorParamsVec,2);
% DiscountFactorParamsVec=DiscountFactorParamsVec';
beta=prod(DiscountFactorParamsVec(:,1:end-1),2)';
beta0beta=prod(DiscountFactorParamsVec,2)'; % Discount rate between present period and next period

VKronNext=zeros(N_a,N_j,N_z,'gpuArray');
VKronNext(:,1:N_j-1,:)=permute(V.Vunderbar(:,:,2:end),[1 3 2]); % Swap j and z
VKronNext=reshape(VKronNext,[N_a*N_j,N_z]);

for z_c=1:N_z
    ReturnMatrix_z=ReturnMatrix(:,:,z_c);

    %Calc the condl expectation term (except beta), which depends on z but not on control variables
    EV_z=VKronNext.*kron(pi_z_AllAges(:,:,z_c),ones(N_a,1,'gpuArray'));
    EV_z(isnan(EV_z))=0; %multilications of -Inf with 0 gives NaN, this replaces them with zeros (as the zeros come from the transition probabilites)
    EV_z=sum(EV_z,2);

    % Calculate Vhat and Policyhat
    discountedEV_z=beta0beta.*reshape(EV_z,[N_a,N_j]); % (aprime)-by-(j) % Note: jprime and j are essentially the same thing.
    entirediscountedEV_z=kron(discountedEV_z,ones(N_d,N_a));
    entirediscountedEV_z=ReturnMatrix_z+entirediscountedEV_z; %(d,aprime)-by-(a,j)
    %Calc the max and it's index
    [Vtemp,maxindex]=max(entirediscountedEV_z,[],1);
    V.Vhat(:,z_c,:)=reshape(Vtemp,[N_a,1,N_j]); % V is over (a,z,j)
    Policyhat(:,z_c,:)=reshape(maxindex,[N_a,1,N_j]); % Policy is over (a,z,j)
    % Now Vunderbar
    discountedEV_z=beta.*reshape(EV_z,[N_a,N_j]); % (aprime)-by-(j) % Note: jprime and j are essentially the same thing.
    entirediscountedEV_z=kron(discountedEV_z,ones(N_d,N_a));
    entirediscountedEV_z=ReturnMatrix_z+entirediscountedEV_z; %(d,aprime)-by-(a,j)
    tempmaxindex=maxindex+(0:1:N_a-1)*(N_d*N_a);
    V.Vunderbar(:,z_c,:)=entirediscountedEV_z(tempmaxindex);

end

%%
Policy2=zeros(2,N_a,N_z,N_j,'gpuArray'); %NOTE: this is not actually in Kron form
Policy2(1,:,:,:)=shiftdim(rem(Policyhat-1,N_d)+1,-1);
Policy2(2,:,:,:)=shiftdim(ceil(Policyhat/N_d),-1);

end