function [V,Policy]=ValueFnIter_Case1_FHorz_SemiExo(n_d1,n_d2,n_a,n_semiz,n_z,N_j,d1_grid,d2_grid, a_grid, z_gridvals_J, semiz_gridvals_J, pi_z_J, pi_semiz_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions)

N_d1=prod(n_d1);
N_z=prod(n_z);
if isfield(vfoptions,'n_e')
    N_e=prod(vfoptions.n_e);
else
    N_e=0;
end

if vfoptions.divideandconquer==1
    if ~isfield(vfoptions,'level1n')
        vfoptions.level1n=5;
    end

    if length(n_a)>1
        error('vfoptions.divideandconquer==1 is currently only possible for one endogenous state (when using semi-exo)')
    end
    if N_e>0
        error('Have not yet implemented divideandconquer for semi-exo with an e variable (contact me)')
    end
end

if N_d1==0
    if N_e==0
        if vfoptions.divideandconquer==0
            if N_z==0
                [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_nod1_noz_raw(n_d2,n_a,n_semiz, N_j, d2_grid, a_grid, semiz_gridvals_J, pi_semiz_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
            else
                [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_nod1_raw(n_d2,n_a,n_z,n_semiz, N_j, d2_grid, a_grid, z_gridvals_J, semiz_gridvals_J, pi_z_J, pi_semiz_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
            end
        elseif vfoptions.divideandconquer==1
            if N_z==0
                [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_DC1_nod1_noz_raw(n_d2,n_a,n_semiz, N_j, d2_grid, a_grid, semiz_gridvals_J, pi_semiz_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
            else
                [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_DC1_nod1_raw(n_d2,n_a,n_z,n_semiz, N_j, d2_grid, a_grid, z_gridvals_J, semiz_gridvals_J, pi_z_J, pi_semiz_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
            end
        end
    else
        if N_z==0
            [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_nod1_noz_e_raw(n_d2,n_a,n_semiz, vfoptions.n_e, N_j, d2_grid, a_grid, semiz_gridvals_J, vfoptions.e_gridvals_J, pi_semiz_J, vfoptions.pi_e_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        else
            [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_nod1_e_raw(n_d2,n_a,n_z,n_semiz,  vfoptions.n_e, N_j, d2_grid, a_grid, z_gridvals_J, semiz_gridvals_J, vfoptions.e_gridvals_J, pi_z_J, pi_semiz_J, vfoptions.pi_e_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        end
    end
else
    if N_e==0
        if vfoptions.divideandconquer==0
            if N_z==0
                [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_noz_raw(n_d1,n_d2,n_a,n_semiz, N_j, d1_grid, d2_grid, a_grid, semiz_gridvals_J, pi_semiz_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
            else
                [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_raw(n_d1,n_d2,n_a,n_z,n_semiz, N_j, d1_grid, d2_grid, a_grid, z_gridvals_J, semiz_gridvals_J, pi_z_J, pi_semiz_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
            end
        elseif vfoptions.divideandconquer==1
            if N_z==0
                [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_DC1_noz_raw(n_d1, n_d2,n_a,n_semiz, N_j, d1_grid, d2_grid, a_grid, semiz_gridvals_J, pi_semiz_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
            else
                [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_DC1_raw(n_d1, n_d2,n_a,n_z,n_semiz, N_j, d1_grid, d2_grid, a_grid, z_gridvals_J, semiz_gridvals_J, pi_z_J, pi_semiz_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
            end
        end
    else
        if N_z==0
            [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_noz_e_raw(n_d1,n_d2,n_a,vfoptions.n_semiz, vfoptions.n_e, N_j, d1_grid, d2_grid, a_grid, semiz_gridvals_J, vfoptions.e_gridvals_J, pi_semiz_J, vfoptions.pi_e_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        else
            [VKron, Policy3]=ValueFnIter_Case1_FHorz_SemiExo_e_raw(n_d1,n_d2,n_a,n_z,vfoptions.n_semiz,  vfoptions.n_e, N_j, d1_grid, d2_grid, a_grid, z_gridvals_J, semiz_gridvals_J, vfoptions.e_gridvals_J, pi_z_J, pi_semiz_J, vfoptions.pi_e_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
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
            V=reshape(VKron,[n_a,vfoptions.n_semiz,n_z,vfoptions.n_e,N_j]);
            Policy=UnKronPolicyIndexes_Case1_FHorz_semiz_e(Policy3, n_d1,n_d2, n_a, [vfoptions.n_semiz,n_z], vfoptions.n_e, N_j, vfoptions);
        end
    else
        if N_z==0
            V=reshape(VKron,[n_a,vfoptions.n_semiz,N_j]);
            Policy=UnKronPolicyIndexes_Case1_FHorz_semiz(Policy3, n_d1, n_d2, n_a, vfoptions.n_semiz, N_j, vfoptions);
        else
            V=reshape(VKron,[n_a,vfoptions.n_semiz,n_z,N_j]);
            Policy=UnKronPolicyIndexes_Case1_FHorz_semiz(Policy3, n_d1, n_d2, n_a, [vfoptions.n_semiz,n_z], N_j, vfoptions);
        end
    end
else
    V=VKron;
    Policy=Policy3;
end

    

end