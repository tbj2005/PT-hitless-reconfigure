
function [Logical_topo_init_conn,Logical_topo_init_cap,logical_topo,logical_topo_cap,flow_requests] = gener_topo(inputs,topo_index)

Logical_topo_init_conn = zeros(inputs.nodes_num,inputs.nodes_num);
Logical_topo_init_cap = Logical_topo_init_conn;
% rng(1);%%四节点，1 直接添加就完了
% rng(topo_index);
%% 产生根据物理连接分解的初始逻辑拓扑
for t = 1:inputs.groupnum
    for k = 1:inputs.oxcnum_agroup

        logical_topo_1 = zeros(inputs.nodes_num,inputs.nodes_num);
        %这个是上边的流量 量,需要包含源、目的节点更细致的划分
        % traffic_logical_topo{t,k} = cell(inputs.nodes_num, inputs.nodes_num);
        for i = 1: inputs.nodes_num
            for j = i+1:inputs.nodes_num
                if i ~= j
                    % sum_j = sum(logical_topo_1(:,j));
                    % sum_i = sum_j + sum(logical_topo_1(i,:)); %%3.26 
                    sum_i = sum(logical_topo_1(i,:));
                    sum_j = sum(logical_topo_1(:,j));
                    rest_cap1 = inputs.physical_conn_oxc - sum_i; %% max_links_innodes canbe a arry for different pods if OXC ports cannot divide uniformly for each pod
                    rest_cap2 = inputs.physical_conn_oxc - sum_j;
                    rest_cap = min(rest_cap1,rest_cap2);
                    if rest_cap > 0
                        rand_i = randi([0, rest_cap],1,1);
                    else
                        rand_i = 0;
                    end 
                    % rand_i = randi([0, rest_cap],1,1);
                    logical_topo_1(i,j) = rand_i;
                    logical_topo_1(j,i) = logical_topo_1(i,j);
                end

                % input initial logical topologies
                % Logical_topo_init(i,j) = Logical_topo_init(i,j) + logical_topo_1(i,j);
            end
        end
        % logical_topo_2 = logical_topo_1 + logical_topo_1';
        % logical_topo{t,k} = logical_topo_2; %%物理独立的子逻辑拓扑分解
        logical_topo{t,k} = logical_topo_1; %%物理独立的子逻辑拓扑分解
        logical_topo_cap{t,k} = logical_topo{t,k} * inputs.connection_cap; %%物理独立的子逻辑拓扑分解
        Logical_topo_init_conn = Logical_topo_init_conn + logical_topo{t,k};
        Logical_topo_init_cap = Logical_topo_init_cap + logical_topo_cap{t,k};
   end
end
%汇合在一起的逻辑拓扑
% Logical_topo_init_conn = Logical_topo_init + Logical_topo_init'; %%节点对之间表示连接数
% Logical_topo_init_cap = Logical_topo_init_conn *inputs.connection_cap; %%节点对之间的容量
if topo_index ~= 0
%% 产生网络上的流量%%
%%%%%%%产生能在初始逻辑拓扑上有可用路径的流量（但是貌似代码没有考虑多路径） %%%这儿到时候用实际的trace替换
    % [flow_requests, ~] = generate_flow_requests(Logical_topo_init_cap, inputs.num_requests,inputs.maxhop);
%%%%%%%随机产生流量
    flow_requests  = [];
    % rng(size(flow_requests,1))
    rng(topo_index);
    for i = 1:inputs.num_requests
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
        total_bandwidth = round((inputs.groupnum * inputs.oxcports *inputs.oxcnum_agroup * inputs.connection_cap) * inputs.cap_ratio);
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
    end
else
    flow_requests = [];
end

