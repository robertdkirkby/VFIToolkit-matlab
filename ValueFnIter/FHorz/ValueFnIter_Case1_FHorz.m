function [V, Policy]=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j,d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions)

V=nan;
Policy=nan;

%% Check which vfoptions have been used, set all others to defaults 
if exist('vfoptions','var')==0
    disp('No vfoptions given, using defaults')
    %If vfoptions is not given, just use all the defaults
    vfoptions.parallel=1+(gpuDeviceCount>0);
    if vfoptions.parallel==2
        vfoptions.returnmatrix=2; % On GPU, must use this option
    end
    if isfield(vfoptions,'returnmatrix')==0
        if isa(ReturnFn,'function_handle')==1
            vfoptions.returnmatrix=0;
        else
            vfoptions.returnmatrix=1;
        end
    end
    vfoptions.verbose=0;
    vfoptions.lowmemory=0;
    if prod(n_z)>50
        vfoptions.paroverz=1; % This is just a refinement of lowmemory=0
    else
        vfoptions.paroverz=0;
    end
    vfoptions.incrementaltype=0; % (vector indicating endogenous state is an incremental endogenous state variable)
    vfoptions.polindorval=1;
    vfoptions.policy_forceintegertype=0;
    vfoptions.outputkron=0; % If 1 then leave output in Kron form
    vfoptions.exoticpreferences='None';
    vfoptions.dynasty=0;
    vfoptions.experienceasset=0;
else
    %Check vfoptions for missing fields, if there are some fill them with the defaults
    if ~isfield(vfoptions,'parallel')
        vfoptions.parallel=1+(gpuDeviceCount>0);
    end
    if vfoptions.parallel==2
        vfoptions.returnmatrix=2; % On GPU, must use this option
    end
    if ~isfield(vfoptions,'returnmatrix')
        if isa(ReturnFn,'function_handle')==1
            vfoptions.returnmatrix=0;
        else
            vfoptions.returnmatrix=1;
        end
    end
    if ~isfield(vfoptions,'lowmemory')
        vfoptions.lowmemory=0;
    end
    if ~isfield(vfoptions,'paroverz') % Only used when vfoptions.lowmemory=0
        if prod(n_z)>50
            vfoptions.paroverz=1;
        else
            vfoptions.paroverz=0;
        end
    end
    if ~isfield(vfoptions,'verbose')
        vfoptions.verbose=0;
    end
    if isfield(vfoptions,'incrementaltype')==0
        vfoptions.incrementaltype=0; % (vector indicating endogenous state is an incremental endogenous state variable)
    end
    if ~isfield(vfoptions,'polindorval')
        vfoptions.polindorval=1;
    end
    if ~isfield(vfoptions,'policy_forceintegertype')
        vfoptions.policy_forceintegertype=0;
    end
    if isfield(vfoptions,'ExogShockFn')
        vfoptions.ExogShockFnParamNames=getAnonymousFnInputNames(vfoptions.ExogShockFn);
    end
    if isfield(vfoptions,'EiidShockFn')
        vfoptions.EiidShockFnParamNames=getAnonymousFnInputNames(vfoptions.EiidShockFn);
    end
    if ~isfield(vfoptions,'outputkron')
        vfoptions.outputkron=0; % If 1 then leave output in Kron form
    end
    if ~isfield(vfoptions,'exoticpreferences')
        vfoptions.exoticpreferences='None';
    end
    if ~isfield(vfoptions,'dynasty')
        vfoptions.dynasty=0;
    end
    if ~isfield(vfoptions,'experienceasset')
        vfoptions.experienceasset=0;
    end

end

if isempty(n_d)
    n_d=0;
end
if isempty(n_z)
    n_z=0;
end
N_d=prod(n_d);
N_a=prod(n_a);
N_z=prod(n_z);

if ~all(size(d_grid)==[sum(n_d), 1])
    if ~isempty(n_d) % Make sure d is being used before complaining about size of d_grid
        if n_d~=0
            error('d_grid is not the correct shape (should be of size sum(n_d)-by-1)')
        end
    end
elseif ~all(size(a_grid)==[sum(n_a), 1])
    error('a_grid is not the correct shape (should be of size sum(n_a)-by-1)')
elseif ~all(size(z_grid)==[sum(n_z), 1]) && ~all(size(z_grid)==[prod(n_z),length(n_z)])
    if N_z>0
        error('z_grid is not the correct shape (should be of size sum(n_z)-by-1)')
    end
elseif ~isequal(size(pi_z), [N_z, N_z])
    if N_z>0
        error('pi is not of size N_z-by-N_z')
    end
elseif isfield(vfoptions,'n_e')
    if vfoptions.parallel<2
        error('Sorry but e (i.i.d) variables are not implemented for cpu, you will need a gpu to use them')
    end
    if ~isfield(vfoptions,'e_grid') && ~isfield(vfoptions,'e_grid_J')
        error('When using vfoptions.n_e you must declare vfoptions.e_grid (or vfoptions.e_grid_J)')
    elseif ~isfield(vfoptions,'pi_e') && ~isfield(vfoptions,'pi_e_J')
        error('When using vfoptions.n_e you must declare vfoptions.pi_e (or vfoptions.pi_e_J)')
    else
        % check size of e_grid and pi_e
        if isfield(vfoptions,'e_grid')
            if  ~all(size(vfoptions.e_grid)==[sum(vfoptions.n_e), 1]) && ~all(size(vfoptions.e_grid)==[prod(vfoptions.n_e),length(vfoptions.n_e)])
                error('vfoptions.e_grid is not the correct shape (should be of size sum(n_e)-by-1)')
            end
        else % using e_grid_J
            % HAVE NOT YET IMPLEMENTED A CHECK OF THE SIZE OF e_grid_J
        end
        if isfield(vfoptions,'pi_e')
            if ~all(size(vfoptions.pi_e)==[prod(vfoptions.n_e),1])
                error('vfoptions.pi_e is not the correct shape (should be of size N_e-by-1)')
            end
        else % using pi_e_J
            if ~all(size(vfoptions.pi_e_J)==[prod(vfoptions.n_e),N_j])
                error('vfoptions.pi_e_J is not the correct shape (should be of size N_e-by-N_j)')
            end
        end
    end
end

%% Implement new way of handling ReturnFn inputs
if n_d(1)==0
    l_d=0;
else
    l_d=length(n_d);
end
l_a=length(n_a);
l_z=length(n_z);
% [n_d,n_a,n_z]
% [l_d,l_a,l_z]
if n_z(1)==0
    l_z=0;
end
if isfield(vfoptions,'SemiExoStateFn')
    l_z=l_z+length(vfoptions.n_semiz);
end
if isfield(vfoptions,'n_e')
    l_e=length(vfoptions.n_e);
else
    l_e=0;
end
if vfoptions.experienceasset==1
    % One of the endogenous states should only be counted once. I fake this by pretending it is a z rather than a variable
    l_z=l_z+1;
    l_a=l_a-1;
end
% If no ReturnFnParamNames inputted, then figure it out from ReturnFn
if isempty(ReturnFnParamNames)
    temp=getAnonymousFnInputNames(ReturnFn);
    if length(temp)>(l_d+l_a+l_a+l_z+l_e) % This is largely pointless, the ReturnFn is always going to have some parameters
        ReturnFnParamNames={temp{l_d+l_a+l_a+l_z+l_e+1:end}}; % the first inputs will always be (d,aprime,a,z)
    else
        ReturnFnParamNames={};
    end
end
% clear l_d l_a l_z l_e % These are all messed up so make sure they are not reused later
% [l_d,l_a,l_z,l_e]

%% 
if vfoptions.parallel==2 
   % If using GPU make sure all the relevant inputs are GPU arrays (not standard arrays)
   pi_z=gpuArray(pi_z);
   d_grid=gpuArray(d_grid);
   a_grid=gpuArray(a_grid);
   z_grid=gpuArray(z_grid);
else
   % If using CPU make sure all the relevant inputs are CPU arrays (not standard arrays)
   % This may be completely unnecessary.
   pi_z=gather(pi_z);
   d_grid=gather(d_grid);
   a_grid=gather(a_grid);
   z_grid=gather(z_grid);
end

if vfoptions.verbose==1
    vfoptions
end

%% Deal with Exotic preferences if need to do that.
if strcmp(vfoptions.exoticpreferences,'None')
    % Just ignore and will then continue on.
elseif strcmp(vfoptions.exoticpreferences,'QuasiHyperbolic')
    [V, Policy]=ValueFnIter_Case1_FHorz_QuasiHyperbolic(n_d,n_a,n_z,N_j,d_grid,a_grid,z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
    return
elseif strcmp(vfoptions.exoticpreferences,'EpsteinZin')
    if vfoptions.dynasty==0
        [V, Policy]=ValueFnIter_Case1_FHorz_EpsteinZin(n_d,n_a,n_z,N_j,d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        return
    else
        error('CANNOT USE EPSTEIN-ZIN PREFERENCES TOGETHER WITH DYNASTY (email robertdkirkby@gmail.com if you need this option)')
    end
end

%% Using both Experience Asset and Semi-Exogenous state
if vfoptions.experienceasset==1 && isfield(vfoptions,'SemiExoStateFn')
    % First, sort out splitting up the decision variables (other, semiexo, experienceasset)
    if length(n_d)>2
        n_d1=n_d(1:end-2);
    else
        n_d1=0;
    end
    n_d2=n_d(end-1); % n_d2 is the decision variable that influences the transition probabilities of the semi-exogenous state
    n_d3=n_d(end); % n_d3 is the decision variable that influences the experience asset
    d1_grid=d_grid(1:sum(n_d1));
    d2_grid=d_grid(sum(n_d1)+1:sum(n_d1)+sum(n_d2));
    d3_grid=d_grid(sum(n_d1)+sum(n_d2)+1:end);
    % Split endogenous assets into the standard ones and the experience asset
    if length(n_a)==1
        n_a1=0;
    else
        n_a1=n_a(1:end-1);
    end
    n_a2=n_a(end); % n_a2 is the experience asset
    a1_grid=a_grid(1:sum(n_a1));
    a2_grid=a_grid(sum(n_a1)+1:end);

    % Second, set up the semi-exogenous state
    if ~isfield(vfoptions,'n_semiz')
        error('When using vfoptions.SemiExoShockFn you must declare vfoptions.n_semiz')
    end
    if ~isfield(vfoptions,'semiz_grid')
        error('When using vfoptions.SemiExoShockFn you must declare vfoptions.semiz_grid')
    end
    % Create the transition matrix in terms of (d,zprime,z) for the semi-exogenous states for each age
    N_semiz=prod(vfoptions.n_semiz);
    l_semiz=length(vfoptions.n_semiz);
    temp=getAnonymousFnInputNames(vfoptions.SemiExoStateFn);
    if length(temp)>(1+l_semiz+l_semiz) % This is largely pointless, the SemiExoShockFn is always going to have some parameters
        SemiExoStateFnParamNames={temp{1+l_semiz+l_semiz+1:end}}; % the first inputs will always be (d,semizprime,semiz)
    else
        SemiExoStateFnParamNames={};
    end
    pi_semiz_J=zeros(N_semiz,N_semiz,n_d2,N_j);
    for jj=1:N_j
        SemiExoStateFnParamValues=CreateVectorFromParams(Parameters,SemiExoStateFnParamNames,jj);
        pi_semiz_J(:,:,:,jj)=CreatePiSemiZ(n_d2,vfoptions.n_semiz,d2_grid,vfoptions.semiz_grid,vfoptions.SemiExoStateFn,SemiExoStateFnParamValues);
    end

    % Now just send it off
    [V,Policy]=ValueFnIter_Case1_FHorz_ExpAssetSemiExo(n_d1,n_d2,n_d3,n_a1,n_a2,n_z,vfoptions.n_semiz, N_j, d1_grid , d2_grid, d3_grid, a1_grid, a2_grid, z_grid, vfoptions.semiz_grid, pi_z, pi_semiz_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
    return

end

%% Deal with Experience Asset if need to do that
if vfoptions.experienceasset==1
    % It is simply assumed that the experience asset is the last asset, and that the decision that influences it is the last decision.
    
    % Split endogenous assets into the standard ones and the experience asset
    if length(n_a)==1
        n_a1=0;
    else
        n_a1=n_a(1:end-1);
    end
    n_a2=n_a(end); % n_a2 is the experience asset
    a1_grid=a_grid(1:sum(n_a1));
    a2_grid=a_grid(sum(n_a1)+1:end);
    % Split decision variables into the standard ones and the one relevant to the experience asset
    if length(n_d)==1
        n_d1=0;
    else
        n_d1=n_d(1:end-1);
    end
    n_d2=n_d(end); % n_d2 is the decision variable that influences next period vale of the experience asset
    d1_grid=d_grid(1:sum(n_d1));
    d2_grid=d_grid(sum(n_d1)+1:end);

    % Now just send all this to the right value fn iteration command
    [V,Policy]=ValueFnIter_Case1_FHorz_ExpAsset(n_d1,n_d2,n_a1,n_a2,n_z, N_j, d1_grid , d2_grid, a1_grid, a2_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
    return
end

%% Deal with StateDependentVariables_z if need to do that.
if isfield(vfoptions,'StateDependentVariables_z')==1
    if vfoptions.verbose==1
        fprintf('StateDependentVariables_z option is being used \n')
    end
    
    if N_d==0
        [VKron,PolicyKron]=ValueFnIter_Case1_FHorz_no_d_SDVz_raw(n_a, n_z, N_j, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
    else
        [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_SDVz_raw(n_d,n_a,n_z, N_j, d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
    end
    
    %Transforming Value Fn and Optimal Policy Indexes matrices back out of Kronecker Form
    V=reshape(VKron,[n_a,n_z,N_j]);
    Policy=UnKronPolicyIndexes_Case1_FHorz(PolicyKron, n_d, n_a, n_z, N_j,vfoptions);
    
    % Sometimes numerical rounding errors (of the order of 10^(-16) can mean
    % that Policy is not integer valued. The following corrects this by converting to int64 and then
    % makes the output back into double as Matlab otherwise cannot use it in
    % any arithmetical expressions.
    if vfoptions.policy_forceintegertype==1
        fprintf('USING vfoptions to force integer... \n')
        % First, give some output on the size of any changes in Policy as a
        % result of turning the values into integers
        temp=max(max(max(abs(round(Policy)-Policy))));
        while ndims(temp)>1
            temp=max(temp);
        end
        fprintf('  CHECK: Maximum change when rounding values of Policy is %8.6f (if these are not of numerical rounding error size then something is going wrong) \n', temp)
        % Do the actual rounding to integers
        Policy=round(Policy);
        % Somewhat unrelated, but also do a double-check that Policy is now all positive integers
        temp=min(min(min(Policy)));
        while ndims(temp)>1
            temp=min(temp);
        end
        fprintf('  CHECK: Minimum value of Policy is %8.6f (if this is <=0 then something is wrong) \n', temp)
        %     Policy=uint64(Policy);
        %     Policy=double(Policy);
    end
    
    return
end

%% Deal with dynasty if need to do that.
if vfoptions.dynasty==1
    if vfoptions.verbose==1
        fprintf('dynasty option is being used \n')
    end
    if isfield(vfoptions,'tolerance')==0
        vfoptions.tolerance=10^(-9);
    end
    
    if vfoptions.parallel==2
        if N_d==0
            [VKron,PolicyKron]=ValueFnIter_Case1_FHorz_no_d_Dynasty_raw(n_a, n_z, N_j, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        else
            [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_Dynasty_raw(n_d,n_a,n_z, N_j, d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        end
    elseif vfoptions.parallel==0 || vfoptions.parallel==1
        if N_d==0
            % Following command is somewhat misnamed, as actually does Par0 and Par1
            [VKron,PolicyKron]=ValueFnIter_Case1_FHorz_no_d_Par0_Dynasty_raw(n_a, n_z, N_j, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        else
            % Following command is somewhat misnamed, as actually does Par0 and Par1
            [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_Par0_Dynasty_raw(n_d,n_a,n_z, N_j, d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        end
    end
    
    %Transforming Value Fn and Optimal Policy Indexes matrices back out of Kronecker Form
    V=reshape(VKron,[n_a,n_z,N_j]);
    Policy=UnKronPolicyIndexes_Case1_FHorz(PolicyKron, n_d, n_a, n_z, N_j,vfoptions);
    
    % Sometimes numerical rounding errors (of the order of 10^(-16) can mean
    % that Policy is not integer valued. The following corrects this by converting to int64 and then
    % makes the output back into double as Matlab otherwise cannot use it in
    % any arithmetical expressions.
    if vfoptions.policy_forceintegertype==1
        fprintf('USING vfoptions to force integer... \n')
        % First, give some output on the size of any changes in Policy as a
        % result of turning the values into integers
        temp=max(max(max(abs(round(Policy)-Policy))));
        while ndims(temp)>1
            temp=max(temp);
        end
        fprintf('  CHECK: Maximum change when rounding values of Policy is %8.6f (if these are not of numerical rounding error size then something is going wrong) \n', temp)
        % Do the actual rounding to integers
        Policy=round(Policy);
        % Somewhat unrelated, but also do a double-check that Policy is now all positive integers
        temp=min(min(min(Policy)));
        while ndims(temp)>1
            temp=min(temp);
        end
        fprintf('  CHECK: Minimum value of Policy is %8.6f (if this is <=0 then something is wrong) \n', temp)
        %     Policy=uint64(Policy);
        %     Policy=double(Policy);
    end
    
    return
end

%% Semi-exogenous state
% The transition matrix of the exogenous shocks depends on the value of the 'last' decision variable(s).
if isfield(vfoptions,'SemiExoStateFn')
    if ~isfield(vfoptions,'n_semiz')
        error('When using vfoptions.SemiExoShockFn you must declare vfoptions.n_semiz')
    end
    if ~isfield(vfoptions,'semiz_grid')
        error('When using vfoptions.SemiExoShockFn you must declare vfoptions.semiz_grid')
    end
    if ~isfield(vfoptions,'numd_semiz')
        vfoptions.numd_semiz=1; % by default, only one decision variable influences the semi-exogenous state
    end
    if length(n_d)>vfoptions.numd_semiz
        n_d1=n_d(1:end-vfoptions.numd_semiz);
        d1_grid=d_grid(1:sum(n_d1));
    else
        n_d1=0; d1_grid=[];
    end
    n_d2=n_d(end-vfoptions.numd_semiz+1:end); % n_d2 is the decision variable that influences the transition probabilities of the semi-exogenous state
    l_d2=length(n_d2);
    d2_grid=d_grid(sum(n_d1)+1:end);
    % Create the transition matrix in terms of (d,zprime,z) for the semi-exogenous states for each age
    N_semiz=prod(vfoptions.n_semiz);
    l_semiz=length(vfoptions.n_semiz);
    temp=getAnonymousFnInputNames(vfoptions.SemiExoStateFn);
    if length(temp)>(l_semiz+l_semiz+l_d2) % This is largely pointless, the SemiExoShockFn is always going to have some parameters
        SemiExoStateFnParamNames={temp{l_semiz+l_semiz+l_d2+1:end}}; % the first inputs will always be (semiz,semizprime,d)
    else
        SemiExoStateFnParamNames={};
    end
    pi_semiz_J=zeros(N_semiz,N_semiz,prod(n_d2),N_j);
    for jj=1:N_j
        SemiExoStateFnParamValues=CreateVectorFromParams(Parameters,SemiExoStateFnParamNames,jj);
        pi_semiz_J(:,:,:,jj)=CreatePiSemiZ(n_d2,vfoptions.n_semiz,d2_grid,vfoptions.semiz_grid,vfoptions.SemiExoStateFn,SemiExoStateFnParamValues);
    end
    % Now that we have pi_semiz_J we are ready to compute the value function.
    if vfoptions.parallel==2
        if n_d1==0
            if isfield(vfoptions,'n_e')
                error('Have not implemented semi-exogenous shocks without at least two decision variables (one of which is that which determines the semi-exog transitions)')
            else
                if N_z==0
                    [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_nod1_noz_raw(n_d2,n_a,vfoptions.n_semiz, N_j, d2_grid, a_grid, vfoptions.semiz_grid, pi_semiz_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
                else
                    error('Have not implemented semi-exogenous shocks without at least two decision variables (one of which is that which determines the semi-exog transitions)')
                end
            end
        else
            if isfield(vfoptions,'n_e')
                if isfield(vfoptions,'e_grid_J')
                    e_grid=vfoptions.e_grid_J(:,1); % Just a placeholder
                else
                    e_grid=vfoptions.e_grid;
                end
                if isfield(vfoptions,'pi_e_J')
                    pi_e=vfoptions.pi_e_J(:,1); % Just a placeholder
                else
                    pi_e=vfoptions.pi_e;
                end
                if N_z==0
                    error('Have not implemented semi-exogenous shocks without at least one z variable (not counting the semi-exogenous one) but with an e variable [you could fake it adding a single-valued z with pi_z=1]')
                else
                    [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_e_raw(n_d1,n_d2,n_a,n_z,vfoptions.n_semiz,  vfoptions.n_e, N_j, d1_grid, d2_grid, a_grid, z_grid, vfoptions.semiz_grid, e_grid, pi_z, pi_semiz_J, pi_e, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
                end
            else
                if N_z==0
                    [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_noz_raw(n_d1,n_d2,n_a,vfoptions.n_semiz, N_j, d1_grid, d2_grid, a_grid, vfoptions.semiz_grid, pi_semiz_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
                    % error('Have not implemented semi-exogenous shocks without at least one exogenous variable (not counting the semi-exogenous one) [you could fake it adding a single-valued z with pi_z=1]')
                else
                    [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_raw(n_d1,n_d2,n_a,n_z,vfoptions.n_semiz, N_j, d1_grid, d2_grid, a_grid, z_grid, vfoptions.semiz_grid, pi_z, pi_semiz_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
                end
            end
        end
    end

    %Transforming Value Fn and Optimal Policy Indexes matrices back out of Kronecker Form
    if vfoptions.outputkron==0
        if isfield(vfoptions,'n_e')
            if N_z==0
                V=reshape(VKron,[n_a,vfoptions.n_semiz, vfoptions.n_e,N_j]);
                Policy=UnKronPolicyIndexes_Case1_FHorz_semiz_e(Policy3, n_d1,n_d2, n_a, vfoptions.n_semiz, vfoptions.n_e, N_j, vfoptions);
            else
                V=reshape(VKron,[n_a,n_z,vfoptions.n_semiz,vfoptions.n_e,N_j]);
                Policy=UnKronPolicyIndexes_Case1_FHorz_semiz_e(Policy3, n_d1,n_d2, n_a, [n_z, vfoptions.n_semiz], vfoptions.n_e, N_j, vfoptions);
            end
        else
            if N_z==0
                V=reshape(VKron,[n_a,vfoptions.n_semiz,N_j]);
                Policy=UnKronPolicyIndexes_Case1_FHorz_semiz(Policy3, n_d1, n_d2, n_a, vfoptions.n_semiz, N_j, vfoptions);
            else
                V=reshape(VKron,[n_a,n_z,vfoptions.n_semiz,N_j]);
                Policy=UnKronPolicyIndexes_Case1_FHorz_semiz(Policy3, n_d1, n_d2, n_a, [n_z,vfoptions.n_semiz], N_j, vfoptions);
            end
        end
    else
        V=VKron;
        Policy=Policy3;
    end

    return
end

%% Detect if using incremental endogenous states and solve this using purediscretization, prior to the main purediscretization routines
if any(vfoptions.incrementaltype)
    % Incremental Endogenous States: aprime either equals a, or one grid point higher (unchanged on incremental increase)
    [VKron,PolicyKron]=ValueFnIter_Case1_FHorz_Increment(n_d,n_a,n_z,d_grid,a_grid,z_grid,N_j,pi_z,ReturnFn,Parameters,ReturnFnParamNames,DiscountFactorParamNames,vfoptions);
    
    %Transforming Value Fn and Optimal Policy Indexes matrices back out of Kronecker Form
    if isfield(vfoptions,'n_e')
        if N_z==0
            V=reshape(VKron,[n_a,vfoptions.n_e,N_j]);
            Policy=UnKronPolicyIndexes_Case1_FHorz(PolicyKron, n_d, n_a, vfoptions.n_e, N_j, vfoptions); % Treat e as z (because no z)
        else
            V=reshape(VKron,[n_a,n_z,vfoptions.n_e,N_j]);
            Policy=UnKronPolicyIndexes_Case1_FHorz_e(PolicyKron, n_d, n_a, n_z, vfoptions.n_e, N_j, vfoptions);
        end
    else
        V=reshape(VKron,[n_a,n_z,N_j]);
        Policy=UnKronPolicyIndexes_Case1_FHorz(PolicyKron, n_d, n_a, n_z, N_j, vfoptions);
    end
    
    return
end


%% Just do the standard case
if N_d==0
    if vfoptions.parallel==2
        if isfield(vfoptions,'n_e')
            if isfield(vfoptions,'e_grid_J')
                e_grid=vfoptions.e_grid_J(:,1); % Just a placeholder
            else
                e_grid=vfoptions.e_grid;
            end
            if isfield(vfoptions,'pi_e_J')
                pi_e=vfoptions.pi_e_J(:,1); % Just a placeholder
            else
                pi_e=vfoptions.pi_e;
            end
            if N_z==0
                [VKron,PolicyKron]=ValueFnIter_Case1_FHorz_nod_noz_e_raw(n_a, vfoptions.n_e, N_j, a_grid, e_grid, pi_e, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
            else
                [VKron,PolicyKron]=ValueFnIter_Case1_FHorz_nod_e_raw(n_a, n_z, vfoptions.n_e, N_j, a_grid, z_grid, e_grid, pi_z, pi_e, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
            end
        else
            if N_z==0
                [VKron,PolicyKron]=ValueFnIter_Case1_FHorz_nod_noz_raw(n_a, N_j, a_grid, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
            else
                [VKron,PolicyKron]=ValueFnIter_Case1_FHorz_nod_raw(n_a, n_z, N_j, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
            end
        end
    elseif vfoptions.parallel==1
        if N_z==0
            [VKron,PolicyKron]=ValueFnIter_Case1_FHorz_nod_noz_Par1_raw(n_a, N_j, a_grid, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        else
            [VKron,PolicyKron]=ValueFnIter_Case1_FHorz_nod_Par1_raw(n_a, n_z, N_j, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        end
    elseif vfoptions.parallel==0
        [VKron,PolicyKron]=ValueFnIter_Case1_FHorz_nod_Par0_raw(n_a, n_z, N_j, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
    end
else
    if vfoptions.parallel==2
        if isfield(vfoptions,'n_e')
            if isfield(vfoptions,'e_grid_J')
                e_grid=vfoptions.e_grid_J(:,1); % Just a placeholder
            else
                e_grid=vfoptions.e_grid;
            end
            if isfield(vfoptions,'pi_e_J')
                pi_e=vfoptions.pi_e_J(:,1); % Just a placeholder
            else
                pi_e=vfoptions.pi_e;
            end
            [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_e_raw(n_d,n_a,n_z,  vfoptions.n_e, N_j, d_grid, a_grid, z_grid, e_grid, pi_z, pi_e, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        else
            if N_z==0
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_noz_raw(n_d,n_a, N_j, d_grid, a_grid, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
            else
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_raw(n_d,n_a,n_z, N_j, d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);                
            end
        end
    elseif vfoptions.parallel==1
        if N_z==0
            [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_noz_Par1_raw(n_d,n_a, N_j, d_grid, a_grid, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        else 
            [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_Par1_raw(n_d,n_a,n_z, N_j, d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        end
    elseif vfoptions.parallel==0
        [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_Par0_raw(n_d,n_a,n_z, N_j, d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
    end
end

%Transforming Value Fn and Optimal Policy Indexes matrices back out of Kronecker Form
if vfoptions.outputkron==0
    if isfield(vfoptions,'n_e')
        if N_z==0
            V=reshape(VKron,[n_a,vfoptions.n_e,N_j]);
            Policy=UnKronPolicyIndexes_Case1_FHorz(PolicyKron, n_d, n_a, vfoptions.n_e, N_j, vfoptions); % Treat e as z (because no z)
        else
            V=reshape(VKron,[n_a,n_z,vfoptions.n_e,N_j]);
            Policy=UnKronPolicyIndexes_Case1_FHorz_e(PolicyKron, n_d, n_a, n_z, vfoptions.n_e, N_j, vfoptions);
        end
    else
        if N_z==0
            V=reshape(VKron,[n_a,N_j]);
            Policy=UnKronPolicyIndexes_Case1_FHorz_noz(PolicyKron, n_d, n_a, N_j, vfoptions);
        else
            V=reshape(VKron,[n_a,n_z,N_j]);
            Policy=UnKronPolicyIndexes_Case1_FHorz(PolicyKron, n_d, n_a, n_z, N_j, vfoptions);
        end
    end
else
    V=VKron;
    Policy=PolicyKron;
end

% Sometimes numerical rounding errors (of the order of 10^(-16) can mean
% that Policy is not integer valued. The following corrects this by converting to int64 and then
% makes the output back into double as Matlab otherwise cannot use it in
% any arithmetical expressions.
if vfoptions.policy_forceintegertype==1
    fprintf('USING vfoptions to force integer... \n')
    % First, give some output on the size of any changes in Policy as a
    % result of turning the values into integers
    temp=max(max(max(abs(round(Policy)-Policy))));
    while ndims(temp)>1
        temp=max(temp);
    end
    fprintf('  CHECK: Maximum change when rounding values of Policy is %8.6f (if these are not of numerical rounding error size then something is going wrong) \n', temp)
    % Do the actual rounding to integers
    Policy=round(Policy);
    % Somewhat unrelated, but also do a double-check that Policy is now all positive integers
    temp=min(min(min(Policy)));
    while ndims(temp)>1
        temp=min(temp);
    end
    fprintf('  CHECK: Minimum value of Policy is %8.6f (if this is <=0 then something is wrong) \n', temp)
%     Policy=uint64(Policy);
%     Policy=double(Policy);
elseif vfoptions.policy_forceintegertype==2
    % Do the actual rounding to integers
    Policy=round(Policy);
end

end