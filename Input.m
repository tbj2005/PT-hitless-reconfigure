%% %%%% input
%% intial logical topologies and ones after decomposition
% % global nodes_num groupnum Logical_topo_init oxcports oxcnum_agroup
% clear
% clc
inputs.nodes_num = 4; %% podsnum
inputs.groupnum = 2; %% vectornum
inputs.oxcports = 12; %% ports pair that an OXC provided
inputs.oxcnum_agroup = 1; %% oxc nums in a vector
inputs.connection_cap = 1;
inputs.physical_conn_oxc = 3;
inputs.maxhop = 2;
inputs.resi_cap = 0.65;
inputs.method = 3;

max_links_innodes = inputs.physical_conn_oxc; %%node degree 
Logical_topo_init = zeros(inputs.nodes_num,inputs.nodes_num);

% % rng(1);%%四节点，1 直接添加就完了
% rng(2);
% %% 产生根据物理连接分解的初始逻辑拓扑
% for t = 1:inputs.groupnum
%     for k = 1:inputs.oxcnum_agroup
% 
%         logical_topo_1 = zeros(inputs.nodes_num,inputs.nodes_num);
%         %这个是上边的流量 量,需要包含源、目的节点更细致的划分
%         traffic_logical_topo{t,k} = cell(inputs.nodes_num, inputs.nodes_num);
%         for i = 1: inputs.nodes_num
%             for j = i+1:inputs.nodes_num
%                 sum_j = sum(logical_topo_1(:,j));
%                 sum_i = sum_j + sum(logical_topo_1(i,:));  
%                 % %%% Note: node degree cannot exceed pod-oxc connections and oxc ports
%                 % sum_all = sum(logical_topo_1,"all"); %% oxc physical constraints
%                 % sum_i = sum(logical_topo_1(i,:));%% node dgree constraints (pod physical connection constraints)
%                 % rest_cap = min((max_links_innodes - sum_i),(oxcports - sum_all));
%                 rest_cap = max_links_innodes - sum_i; %% max_links_innodes canbe a arry for different pods if OXC ports cannot divide uniformly for each pod
%                 if rest_cap > 0
%                     rand_i = randi([0, rest_cap],1,1);
%                 else
%                     rand_i = 0;
%                 end 
%                 % rand_i = randi([0, rest_cap],1,1);
%                 logical_topo_1(i,j) = rand_i;
%                 %% traffic in a logical topoloy for an oxc %%generate when need to use
%                 %%产生逻辑拓扑上的流量分配情况,只针对连接上的流量做了随机的产生，没有划分流，实际上后边还是要用到流
%                 %traffic_logical_topo{k}{i,j} = rand([1, logical_topo_1(i, j)]) * max_traffic;%% uniform distribution
%                 %%所以可以针对每个逻辑子拓扑来产生流量，（问题，怎么解释单跳还有剩余容量的时候就考虑多跳，那就单跳可以的时候就不考虑多跳，及没有单跳路径的时候跳出来考虑整个网络。重新开一个循环）
%                 %traffic_logical_topo{k}{i,j} = rand([1, logical_topo_1(i, j)]) * max_traffic;%% uniform distribution
%                 % input initial logical topologies
%                 Logical_topo_init(i,j) = Logical_topo_init(i,j) + logical_topo_1(i,j);
%             end
%         end
%         logical_topo_2 = logical_topo_1 + logical_topo_1';
%         logical_topo{t,k} = logical_topo_2; %%物理独立的子逻辑拓扑分解
%         logical_topo_cap{t,k} = logical_topo{t,k} * inputs.connection_cap; %%物理独立的子逻辑拓扑分解
%    end
% end
% %汇合在一起的逻辑拓扑
% Logical_topo_init_conn = Logical_topo_init + Logical_topo_init'; %%节点对之间表示连接数
% Logical_topo_init_cap = Logical_topo_init_conn *inputs.connection_cap; %%节点对之间的容量
% %% 产生网络上的流量%%
% % 初始化流量请求和路由
% %%%%%%%先产生流量请求，然后把流量请求按照某种规则分配到各个平面上去 %%%这儿到时候用实际的trace替换
% % for i = 1:flow_num       
% %     % [flow_requests, routes] = generate_flow_requests(Logical_topo_init, num_requests, h);%根据路由分配（均分，也可以按比例分）
% %     [path_exists, routes, min_capacity] = find_paths(network_topology, source, destination, h);
% %     %%为已知请求简单分配路径，优先单跳路径
% %     %%然后根据路径将容量分配到边上
% %     %根据路由分配（均分，也可以按比例分）
% % end
% %%%%%%
% %%%已知网络中的流量要求，但是没有分布情况
% [traffic_distr,logical_topo_traffic] = distr_Traffic(Logical_topo_init_cap,inputs);
% 
% %% generate feasiable desired logical topologies
% %%%产生逻辑拓扑的时候必要考虑到满足已有的流量矩阵。
% %之前用来计算期望逻辑拓扑的，但是不一定能够满足平滑重构的要求.需要重新根据请求计算或者根据MILP计算
% Logical_topo_desi = zeros(inputs.nodes_num,inputs.nodes_num);
% for t = 1:inputs.groupnum
%     for k = 1:inputs.oxcnum_agroup
%         logical_topo_1 = zeros(inputs.nodes_num,inputs.nodes_num);
%         for i = 1: inputs.nodes_num
%             for j = i+1: inputs.nodes_num 
%                 sum_i = sum(logical_topo_1,"all"); 
%                 rest_cap = max_links_innodes - sum_i;
%                 if rest_cap > 0
%                     rand_i = randi([0, rest_cap],1,1);
%                 else
%                     rand_i = 0;
%                 end 
%                 % rand_i = randi([0, rest_cap],1,1);
%                 logical_topo_1(i,j) = rand_i;
%                 % sum_i = sum_j + sum(logical_topo_1(i,:));    
%                 % input initial logical topologies
%                 Logical_topo_desi(i,j) = Logical_topo_desi(i,j) + logical_topo_1(i,j);
%             end
%         end
%         logical_topo_2 = logical_topo_1 + logical_topo_1';
%         logical_topo_target{t,k} = logical_topo_2; 
%     end
% end
%  Logical_topo_desi = Logical_topo_desi + Logical_topo_desi';
% 

%% Test data 1
% Test_data_1;
Test_data_2;

%% delta topology
delta_topology = Logical_topo_desi - Logical_topo_init_conn;%% + indicates add, - indicates delete


%%用来计算期望逻辑拓扑，满足物理限制但是不一定能够满足平滑重构的要求
% Logical_topo_desi = zeros(inputs.nodes_num,inputs.nodes_num);
% for k = 1:inputs.groupnum*inputs.oxcnum_agroup
%     max_links_innodes = 6; %%
%     logical_topo_1 = zeros(inputs.nodes_num,inputs.nodes_num);
%     for i = 1: inputs.nodes_num
%         for j = i+1: inputs.nodes_num 
%             sum_i = sum(logical_topo_1,"all"); 
%             rest_cap = max_links_innodes - sum_i;
%             if rest_cap > 0
%                 rand_i = randi([0, rest_cap],1,1);
%             else
%                 rand_i = 0;
%             end 
%             % rand_i = randi([0, rest_cap],1,1);
%             logical_topo_1(i,j) = rand_i;
%             % sum_i = sum_j + sum(logical_topo_1(i,:));    
%             % input initial logical topologies
%             Logical_topo_desi(i,j) = Logical_topo_desi(i,j) + logical_topo_1(i,j);
%         end
%     end
%     logical_topo_2 = logical_topo_1 + logical_topo_1';
%     logical_topo{k} = logical_topo_2; 
% end
%  Logical_topo_desi = Logical_topo_desi + Logical_topo_desi';';


