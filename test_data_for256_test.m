%%随机产生拓扑、流量
clear
clc

input.nodesnum = [8,16,32,64,128,256];
input.groupnum = [1,1,1,1,1,1];
input.oxcports = [8*3,16*3,32*3,64*3,128*3,256*4];
input.oxcnum_agroup = [1,1,1,1,1,1];
input.connection_cap = [100, 100, 100,100, 100, 100];
input.physical_conn_oxc = input.oxcports./input.nodesnum;

input.max_num_requests = [10,20,30,400,800,1000];
input.cap_ratio = [0.01,0.03,0.05,0.07,0.09];

topo_index = 1;

% for i = 1:length(input.nodesnum)
for i = 5:6
    inputs.nodes_num = input.nodesnum(i); %% podsnum
    inputs.groupnum = input.groupnum(i); %% groupnum
    inputs.oxcports = input.oxcports(i); %% ports pair that an OXC provided
    inputs.oxcnum_agroup = input.oxcnum_agroup(i); %% oxc nums in a vector
    inputs.connection_cap = input.connection_cap(i);
    inputs.physical_conn_oxc = input.physical_conn_oxc(i);%一个pod连接到一个OXC的端口
    inputs.cap_ratio = 0.6;
    
    inputs.maxhop = 2;
    inputs.resi_cap = 0.75;

    % stage{i} = ones(input.max_num_requests(i),3)* Inf;

    % for j = 1: 2^(2*i-1):input.max_num_requests(i)
    % for j = 1: 2^(i):input.max_num_requests(i)
    for j = 1
        inputs.num_requests = j;
        % disp('i j')
        % disp([i,j])
        
        clearvars -except inputs input i j m stage topo_index RE

        breakflag0 = 1;
        breakflag1 = 1;
        kk = 1;
        %%如果流在初始或者目标逻辑拓扑上有没有两条内路径的情况，则换一组输入

        kk = kk + 1;
       
    
        %%随机产生初始拓扑, 不可行的概率太大了，很难找到有效数据
        [Logical_topo_init_conn,Logical_topo_init_cap,logical_topo,logical_topo_cap,~] = gener_topo(inputs,topo_index);
        %%1 初始逻辑拓扑 2 初始逻辑拓扑容量  3 分平面逻辑拓扑 4 分平面逻辑拓扑容量 5 流量请求
        %%流量：50-100-150-200
        flow_request = ger_flows(inputs,Logical_topo_init_cap,topo_index); %单跳
        % flow_request =
        % re_ger_flows(inputs,Logical_topo_init_cap);%已知一组流，增加流的数目
        % flow_request = rand_gen_flow(inputs,Logical_topo_init_cap);
        % flow_request =  genr_flow_2hop(inputs,Logical_topo_init_cap,Logical_topo_init_conn);%2-hop
        inputs.request = flow_request;

    
        % %计算流在初始逻辑拓扑中的路径和流量分布，流量分布也是在能找到可用路径的前提下，任意找的路径
        [~,~,breakflag0,unava_flow_ini] = distr_Traffic(Logical_topo_init_cap,inputs);%0表示有可用路径
       
        
        topo_index = topo_index + 1;
        %判断流在目标逻辑拓扑上是否有可用路径
        %%随机产生目标逻辑拓扑
        [Logical_topo_desi,Logical_topo_target_cap,logical_topo_desi,~,~] = gener_topo(inputs, topo_index);%0不进入随机产生流量的程序
       
        
        [~,~,breakflag1,unava_flow_tar] = distr_Traffic(Logical_topo_target_cap,inputs);

        if breakflag1 == 1 || breakflag0 == 1
            cannot_serflow = [];
            for i_r = 1:size(unava_flow_ini, 1)
                current_row = unava_flow_ini(i_r, 1:2);
                matching_rows = unava_flow_tar(:, 1:2) == current_row;
                if any(all(matching_rows, 2))
                    match_index = find(all(matching_rows, 2));

                    max_value = max([unava_flow_ini(i_r, 3), unava_flow_tar(match_index, 3)]);

                    cannot_serflow = [cannot_serflow; current_row, max_value];
                else
                    cannot_serflow = [];
                end
            end
            if ~isempty(cannot_serflow)
                re_cols = inputs.request(:, 1:2);
                [~, match_index_A] = ismember(cannot_serflow(:, 1:2), re_cols, 'rows');
                inputs.request(match_index_A(match_index_A > 0), 3) = inputs.request(match_index_A(match_index_A > 0), 3) - cannot_serflow(match_index_A > 0, 3);
    
                [bandwidth_0,~] = find(inputs.request(:,3)== 0);
                inputs.request(bandwidth_0,:)= [];
            end
        end
       
        
        [traffic_distr,flowpath,breakflag0,unava_flow_ini] = distr_Traffic(Logical_topo_init_cap,inputs);%0表示有可用路径
        
            
           
      
        RE = inputs.request;

        for m = 2:2

            inputs.method = m;
            
            [S,R,logical_topo_traffic,S_Conn_cap,port_allocation_inti_topo,port_allocation] = convert_inputs(inputs,flowpath,logical_topo);
            
            %%拓扑变换
            delta_topology = Logical_topo_desi - Logical_topo_init_conn;%% + indicates add, - indicates delete
            
            %%计算物理目标物理拓扑
            [update_logical_topo,update_check_flag] = physical_topo_fu(inputs,delta_topology,traffic_distr,logical_topo_traffic,logical_topo,logical_topo_cap);
            
            if update_check_flag == 1
                update_logical_topo = logical_topo_desi;
            end
            %%目标物理拓扑接口转化
            E = target_topo_convert(S_Conn_cap,S,logical_topo,update_logical_topo,port_allocation_inti_topo,inputs);
            tic
            if inputs.method == 1
                stage(i,j,m)  = reconfig_benchmark_fun(S,E,R,inputs,port_allocation);
                spendingtime = toc;
            else
                % stage(i,j,m) = reconfig_progress_fun(S,E,R,inputs,port_allocation);% satge = 0代表可以直接加连接
                stage(i,j,m) = reconfig_progress_fun(S,E,R,inputs,port_allocation);% satge = 0代表可以直接加连接
                spendingtime1 = toc;
            end
               
        
        end
    end
end
