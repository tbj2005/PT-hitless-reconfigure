clear
clc
%%同样的平面连接，同样的流量分布，不影响在哪个平面操作，也不影响方案

inputs.nodes_num = 5; %% podsnum
inputs.groupnum = 2; %% vectornum
inputs.oxcports = 20; %% ports pair that an OXC provided
inputs.oxcnum_agroup = 1; %% oxc nums in a vector
inputs.connection_cap = 1; %% 每条链接可以提供的带宽容量
inputs.physical_conn_oxc = 4; % 一个pod连接到物理
inputs.maxhop = 2;
inputs.resi_cap = 0.65;

inputs.request = [2 3 2; 2 4 3];%%每行表示一条需求流量，三元组，源pod，目的pod和带宽需求
% inputs.request = [2 3 3; 1 4 3;2 4 1];%% 网络比较满，没有可用流量


for m = 1:3
    clearvars -except inputs m stage
    inputs.method = m;

    logical_topo{1,1} = [0 1 2 0 1; 1 0 0 2 1;2 0 0 1 0;0 2 1 0 0;1 1 0 0 0];
    logical_topo{2,1} = [0 1 2 0 0; 1 0 1 1 1;2 1 0 1 0;0 1 1 0 1;0 1 0 1 0];
    logical_topo_cap{1,1} = logical_topo{1,1} * inputs.connection_cap;%[t,k]
    logical_topo_cap{2,1} = logical_topo{2,1} * inputs.connection_cap;%由初始逻辑拓扑矩阵求初始带宽分配矩阵
    Logical_topo_init_conn = logical_topo{1,1} + logical_topo{2,1};
    Logical_topo_init_cap = logical_topo_cap{1,1} + logical_topo_cap{2,1}; %%节点对之间的容量
    Logical_topo_desi = [0,0,3,0,1;0,0,3,5,0;3,3,0,2,0;0,5,2,0,1;1,0,0,1,0];
    %%%%%%%%%%%输入转化
    [traffic_distr,flowpath,~] = distr_Traffic(Logical_topo_init_cap,inputs);
    
    [S,R,logical_topo_traffic,S_Conn_cap,port_allocation_inti_topo,port_allocation] = convert_inputs(inputs,flowpath,logical_topo);
    %%%%%%%%%%%
    %S,R,logical_topo_traffic{1},logical_topo_traffic{2},S_Conn_cap,port_allocation_inti_topo{1}{1},port_allocation_inti_topo{2}{1},port_allocation{1}{1},port_allocation{2}{1}
    %%拓扑变换
    delta_topology = Logical_topo_desi - Logical_topo_init_conn;%% + indicates add, - indicates delete
    
    %%计算物理目标物理拓扑
    [update_logical_topo] = physical_topo_fu(inputs,delta_topology,traffic_distr,logical_topo_traffic,logical_topo,logical_topo_cap);
    update_logical_topo{1}, update_logical_topo{2}
    %%%%%%%%%目标物理拓扑接口转化
    E = target_topo_convert(S_Conn_cap,S,logical_topo,update_logical_topo,port_allocation_inti_topo,inputs);
    %%%%%%%%%目标物理拓扑接口转化

    if inputs.method == 1
        stage(m) = reconfig_benchmark_fun(S,E,R,inputs,port_allocation);
    else
        stage(m) = reconfig_progress_fun(S,E,R,inputs,port_allocation);% satge = 0代表可以直接加连接
    end
end
save stage_test7 stage

