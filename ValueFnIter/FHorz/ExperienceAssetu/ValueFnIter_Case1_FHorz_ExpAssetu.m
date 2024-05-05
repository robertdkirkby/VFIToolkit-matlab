function [V,Policy]=ValueFnIter_Case1_FHorz_ExpAssetu(n_d1,n_d2,n_a1,n_a2,n_z, N_j, d1_grid , d2_grid, a1_grid, a2_grid, z_gridvals_J, pi_z_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions)
% vfoptions are already set by ValueFnIter_Case1_FHorz()
if vfoptions.parallel~=2
    error('Can only use experience asset with parallel=2 (gpu)')
end

if isfield(vfoptions,'aprimeFn')
    aprimeFn=vfoptions.aprimeFn;
else
    error('To use an experience assetu you must define vfoptions.aprimeFn')
end

if isfield(vfoptions,'n_u')
    n_u=vfoptions.n_u;
else
    error('To use an experience assetu you must define vfoptions.n_u')
end
if isfield(vfoptions,'n_u')
    u_grid=gpuArray(vfoptions.u_grid);
else
    error('To use an experience assetu you must define vfoptions.u_grid')
end
if isfield(vfoptions,'pi_u')
    pi_u=gpuArray(vfoptions.pi_u);
else
    error('To use an experience assetu you must define vfoptions.pi_u')
end

% aprimeFnParamNames in same fashion
l_d2=length(n_d2);
l_a2=length(n_a2);
l_u=length(n_u);
temp=getAnonymousFnInputNames(aprimeFn);
if length(temp)>(l_d2+l_a2+l_u)
    aprimeFnParamNames={temp{l_d2+l_a2+l_u+1:end}}; % the first inputs will always be (d2,a2,u)
else
    aprimeFnParamNames={};
end


N_z=prod(n_z);

if isfield(vfoptions,'n_e')
    if prod(n_a1)==0
        if prod(n_d1)==0
            if N_z==0
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_nod1_noa1_noz_e_raw(n_d2,n_a2,vfoptions.n_e,n_u, N_j, d2_grid, a2_grid, vfoptions.e_gridvals_J, u_grid, vfoptions.pi_e_J, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            else
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_nod1_noa1_e_raw(n_d2,n_a2,n_z,vfoptions.n_e,n_u, N_j, d2_grid, a2_grid, z_gridvals_J, vfoptions.e_gridvals_J, u_grid, pi_z_J, vfoptions.pi_e_J, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            end
        else % n_d1
            if N_z==0
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_noa1_noz_e_raw(n_d1,n_d2,n_a2,vfoptions.n_e,n_u, N_j, d1_grid, d2_grid, a2_grid, vfoptions.e_gridvals_J, u_grid, vfoptions.pi_e_J, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            else
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_noa1_e_raw(n_d1,n_d2,n_a2,n_z,vfoptions.n_e,n_u, N_j, d1_grid, d2_grid, a2_grid, z_gridvals_J, vfoptions.e_gridvals_J, u_grid, pi_z_J, vfoptions.pi_e_J, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            end
        end
    else % n_a1
        if prod(n_d1)==0
            if N_z==0
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_nod1_noz_e_raw(n_d2,n_a1,n_a2,vfoptions.n_e,n_u, N_j, d2_grid, a1_grid, a2_grid, vfoptions.e_gridvals_J, u_grid, vfoptions.pi_e_J, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            else
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_nod1_e_raw(n_d2,n_a1,n_a2,n_z,vfoptions.n_e,n_u, N_j, d2_grid, a1_grid, a2_grid, z_gridvals_J, vfoptions.e_gridvals_J, u_grid, pi_z_J, vfoptions.pi_e_J, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            end
        else % n_d1
            if N_z==0
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_noz_e_raw(n_d1,n_d2,n_a1,n_a2,vfoptions.n_e,n_u, N_j, d1_grid, d2_grid, a1_grid, a2_grid, vfoptions.e_gridvals_J, u_grid, vfoptions.pi_e_J, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            else
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_e_raw(n_d1,n_d2,n_a1,n_a2,n_z,vfoptions.n_e,n_u, N_j, d1_grid, d2_grid, a1_grid, a2_grid, z_gridvals_J, vfoptions.e_gridvals_J, u_grid, pi_z_J, vfoptions.pi_e_J, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            end
        end
    end
else % no e variable
    if prod(n_a1)==0
        if prod(n_d1)==0
            if N_z==0
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_nod1_noa1_noz_raw(n_d2,n_a2,n_u, N_j, d2_grid, a2_grid, u_grid, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            else
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_nod1_noa1_raw(n_d2,n_a2,n_z,n_u, N_j, d2_grid, a2_grid, z_gridvals_J, u_grid, pi_z_J, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            end
        else
            if N_z==0
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_noa1_noz_raw(n_d1,n_d2,n_a2,n_u, N_j, d1_grid, d2_grid, a2_grid, u_grid, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            else
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_noa1_raw(n_d1,n_d2,n_a2,n_z,n_u, N_j, d1_grid, d2_grid, a2_grid, z_gridvals_J, u_grid, pi_z_J, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            end
        end
    else % n_a1
        if prod(n_d1)==0
            if N_z==0
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_nod1_noz_raw(n_d2,n_a1,n_a2,n_u, N_j, d2_grid, a1_grid, a2_grid, u_grid, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            else
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_nod1_raw(n_d2,n_a1,n_a2,n_z,n_u, N_j, d2_grid, a1_grid, a2_grid, z_gridvals_J, u_grid, pi_z_J, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            end
        else
            if N_z==0
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_noz_raw(n_d1,n_d2,n_a1,n_a2,n_u, N_j, d1_grid, d2_grid, a1_grid, a2_grid, u_grid, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            else
                [VKron, PolicyKron]=ValueFnIter_Case1_FHorz_ExpAssetu_raw(n_d1,n_d2,n_a1,n_a2,n_z,n_u, N_j, d1_grid, d2_grid, a1_grid, a2_grid, z_gridvals_J, u_grid, pi_z_J, pi_u, ReturnFn, aprimeFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, aprimeFnParamNames, vfoptions);
            end
        end
    end
end

%%
if vfoptions.outputkron==0
    if n_d1>0
        n_d=[n_d1,n_d2];
    else 
        n_d=n_d2;
    end
    if n_a1>0
        n_a=[n_a1,n_a2];
        n_d=[n_d,n_a1];
    else
        n_a=n_a2;
    end
    %Transforming Value Fn and Optimal Policy Indexes matrices back out of Kronecker Form
    if isfield(vfoptions,'n_e')
        if N_z==0
            V=reshape(VKron,[n_a,vfoptions.n_e,N_j]);
            Policy=UnKronPolicyIndexes_Case2_FHorz(PolicyKron, n_d, n_a, vfoptions.n_e, N_j, vfoptions); % Treat e as z (because no z)
        else
            V=reshape(VKron,[n_a,n_z,vfoptions.n_e,N_j]);
            Policy=UnKronPolicyIndexes_Case2_FHorz_e(PolicyKron, n_d, n_a, n_z, vfoptions.n_e, N_j, vfoptions);
        end
    else
        if N_z==0
            V=reshape(VKron,[n_a,N_j]);
            Policy=UnKronPolicyIndexes_Case2_FHorz_noz(PolicyKron, n_d, n_a, N_j, vfoptions);
        else
            V=reshape(VKron,[n_a,n_z,N_j]);
            Policy=UnKronPolicyIndexes_Case2_FHorz(PolicyKron, n_d, n_a, n_z, N_j, vfoptions);
        end
    end
else
    V=VKron;
    Policy=PolicyKron;
end


end


