function Policy=UnKronPolicyIndexes_Case1_FHorz_semiz(Policy3, n_d1, n_d2, n_a, n_z,N_j,vfoptions)
% n_z should be [n_z,n_semiz]

%Input: Policy3=zeros(3,N_a,N_z,N_j); %first dim indexes the optimal choice for d2 and (d1,aprime) rest of dimensions a,z 
%Output: Policy (l_d+l_a,n_a,n_z,N_j);

% Note that if there is no d1 then input is instead of size: Policy3=zeros(2,N_a,N_z,N_j)

N_d1=prod(n_d1);
% N_d2=prod(n_d2);
N_a=prod(n_a);
N_z=prod(n_z);

l_d1=length(n_d1); % Note: this is anyway only used is N_d1~=0
l_d2=length(n_d2);
l_a=length(n_a);

% Sometimes numerical rounding errors (of the order of 10^(-16) can mean
% that Policy is not integer valued. The following corrects this by converting to int64 and then
% makes the output back into double as Matlab otherwise cannot use it in
% any arithmetical expressions.
if ~isfield(vfoptions,'policy_forceintegertype')
    vfoptions.policy_forceintegertype=0;
end
if vfoptions.policy_forceintegertype==1
    Policy3=round(Policy3);
end


if vfoptions.parallel~=2
    if N_d1==0
        Policy=zeros(l_d2+l_a,N_a,N_z,N_j);
        for a_c=1:N_a
            for z_c=1:N_z
                for jj=1:N_j
                    optd2indexKron=Policy3(1,a_c,z_c,jj);
                    optaindexKron=Policy3(2,a_c,z_c,jj);
                    optD2=ind2sub_homemade(n_d2',optd2indexKron);
                    optA=ind2sub_homemade(n_a',optaindexKron);
                    Policy(:,a_c,z_c,jj)=[optD2'; optA'];
                end
            end
        end
        Policy=reshape(Policy,[l_d2+l_a,n_a,n_z,N_j]);
    else
        Policy=zeros(l_d1+l_d2+l_a,N_a,N_z,N_j);
        for a_c=1:N_a
            for z_c=1:N_z
                for jj=1:N_j
                    optd1indexKron=Policy3(1,a_c,z_c,jj);
                    optd2indexKron=Policy3(2,a_c,z_c,jj);
                    optaindexKron=Policy3(3,a_c,z_c,jj);
                    optD1=ind2sub_homemade(n_d1',optd1indexKron);
                    optD2=ind2sub_homemade(n_d2',optd2indexKron);
                    optA=ind2sub_homemade(n_a',optaindexKron);
                    Policy(:,a_c,z_c,jj)=[optD1'; optD2'; optA'];
                end
            end
        end
        Policy=reshape(Policy,[l_d1+l_d2+l_a,n_a,n_z,N_j]);
    end
else
    if N_d1==0
        Policy=zeros(l_d2+l_a,N_a,N_z,N_j,'gpuArray');

        for jj=1:N_j
            if l_d2>1
                if l_d2>2
                    for ii=1:l_d2-1
                        Policy(ii,:,:,jj)=rem(ceil(Policy3(1,:,:,jj)/prod(n_d2(1:ii-1)))-1,n_d2(ii))+1;
                    end
                end
                Policy(l_d2,:,:,jj)=ceil(Policy3(1,:,:,jj)/prod(n_d1(1:l_d1-1)));
            end

            if l_a>1
                if l_a>2
                    for ii=1:l_a-1
                        Policy(l_d2+ii,:,:,jj)=rem(ceil(Policy3(3,:,:,jj)/prod(n_a(1:ii-1)))-1,n_a(ii))+1;
                    end
                end
                Policy(l_d2+l_a,:,:,jj)=ceil(Policy3(3,:,:,jj)/prod(n_a(1:l_a-1)));
            end
        end
        Policy=reshape(Policy,[l_d2+l_a,n_a,n_z,N_j]);

    else
        Policy=zeros(l_d1+l_d2+l_a,N_a,N_z,N_j,'gpuArray');

        for jj=1:N_j
            if l_d1>1
                if l_d1>2
                    for ii=1:l_d1-1
                        Policy(ii,:,:,jj)=rem(ceil(Policy3(1,:,:,jj)/prod(n_d1(1:ii-1)))-1,n_d1(ii))+1;
                    end
                end
                Policy(l_d1,:,:,jj)=ceil(Policy3(1,:,:,jj)/prod(n_d1(1:l_d1-1)));
            end

            if l_d2>1
                if l_d2>2
                    for ii=1:l_d2-1
                        Policy(l_d1+ii,:,:,jj)=rem(ceil(Policy3(1,:,:,jj)/prod(n_d2(1:ii-1)))-1,n_d2(ii))+1;
                    end
                end
                Policy(l_d1+l_d2,:,:,jj)=ceil(Policy3(1,:,:,jj)/prod(n_d1(1:l_d1-1)));
            end

            if l_a>1
                if l_a>2
                    for ii=1:l_a-1
                        Policy(l_d1+l_d2+ii,:,:,jj)=rem(ceil(Policy3(3,:,:,jj)/prod(n_a(1:ii-1)))-1,n_a(ii))+1;
                    end
                end
                Policy(l_d1+l_d2+l_a,:,:,jj)=ceil(Policy3(3,:,:,jj)/prod(n_a(1:l_a-1)));
            end
        end
        Policy=reshape(Policy,[l_d1+l_d2+l_a,n_a,n_z,N_j]);
    end
end


if vfoptions.policy_forceintegertype==1
    Policy=round(Policy);
end


end
