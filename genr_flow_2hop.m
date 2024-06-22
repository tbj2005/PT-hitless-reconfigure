
%% 产生网络上的流量%%
function flow_requests = genr_flow_2hop(inputs,Logical_topo_init_cap,Logical_topo_init_conn)
%%%%%%%随机产生流量
flow_requests  = [];
rng(size(flow_requests,1))
% rng(3);
real_num_size = 0;
while real_num_size < inputs.num_requests
% for i = 1:inputs.num_requests
    flag = 0;
    % 随机选择源节点和目的节点
    while flag == 0
        % disp('gener topo');
        source = randi(inputs.nodes_num);
        destination = randi(inputs.nodes_num);
        % 忽略自环
        if source ~= destination
            if ~isempty(flow_requests)
                lia = ismember([destination,source;source,destination],flow_requests(:,1:2),'rows');
                if sum(lia,'all') == 0
                   flag = 1;
                end
            else
                flag = 1;
            end
        end
    end
    % randnum = rand(1);
    % if randnum > 0.3 &&  Logical_topo_init_cap(source,destination) > 0
    %     reqiure_bandwidth_band =  randi(Logical_topo_init_cap(source,destination));
    % else
    %     reqiure_bandwidth_band =  randi(sum(Logical_topo_init_cap(source,:)/5,'all'));
    % end
    %%带宽随机，但是总带宽不超过全网的n%
    update_total_bandwidth = 0;
    total_bandwidth = round((inputs.groupnum * inputs.oxcports *inputs.oxcnum_agroup * inputs.connection_cap/2) * inputs.cap_ratio);
    update_total_bandwidth = total_bandwidth - update_total_bandwidth;
    if update_total_bandwidth > 0
        %简单判断两跳内的容量
        ava_band_1hop = Logical_topo_init_cap(source,destination);%单跳
        [~,col]= find(Logical_topo_init_conn(source,:));%source 的邻接节点

        ava_bandwidth = 0;
        for r = 1:length(col)
           [~,hop2_col1]  = find(Logical_topo_init_conn(col(r),:));% col(r)有连接的下一跳
           [~,hop2_col] = find(hop2_col1==destination);
           if ~isempty(hop2_col)
               hop1_cap = Logical_topo_init_cap(source,col(r));
               hop2_cap = Logical_topo_init_cap(col(r),destination);
               ava_cap = min(hop1_cap,hop2_cap);
               ava_bandwidth = ava_bandwidth + ava_cap;
           end
        end
        ava_bandwidth = ava_bandwidth + ava_band_1hop;%%%一个流允许的最大带宽

        maxval = min(ava_bandwidth,update_total_bandwidth);
        if maxval ~= 0
            reqiure_bandwidth_band = randi(maxval);
            update_total_bandwidth = update_total_bandwidth - reqiure_bandwidth_band;
            flow_requests = [flow_requests;[source,destination,reqiure_bandwidth_band]];
        end
    else
        break
    end
    real_num_size = size(flow_requests,1);
end

