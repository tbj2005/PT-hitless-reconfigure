%%%%k，t逻辑拓扑中每条连接的流量优先占满某个端口，对应于method2 或者3
%输入参数
function [S,R,logical_topo_traffic,S_Conn_cap,port_allocation_inti_topo,port_allocation]= convert_inputs(inputs,flowpath,logical_topo)
Omega = inputs.nodes_num; %% podsnum
T = inputs.groupnum; %% vectornum
sum_port = inputs.oxcports; %% ports pair that an OXC provided
K = inputs.oxcnum_agroup; %% oxc nums in a vector
B = inputs.connection_cap;
request = inputs.request;%网络中的流
req_num = size(request,1);
ave = floor(sum_port / Omega);%端口向下均分
remain = rem(sum_port, Omega);%取余

%pod和oxc之间的物理连接数目G_u^k,t
G = ones(Omega, K, T);%初始化三维数组，赋值
G = G.*ave;

if remain ~= 0%有余数时执行
    for i = 1 : size(G, 3)%有几个平面
        for j = 1 : size(G, 2)%每个平面有几个oxc
            Rand = randi([1, Omega], 1, remain);
            for k = 1 : remain
                G(Rand(1,k),j,i) = G(Rand(1,k),j,i) + 1;
            end
        end
    end
end

%将连接具体分配到端口上
port_allocation = cell(size(G, 3),1);%初始化一个空cell数组
for i = 1 : size(G, 3)%有几个平面
    for j = 1 : size(G, 2)%每个平面有几个oxc
        p = 0;%指示oxc的端口序号
        for k = 1 : Omega%指示当前pod序号
            for l = p + 1 : p + G(k,j,i)
                port_allocation{i,1}{j,1}(1,l) = k;%填充pod进去，标记该oxc端口与哪个pod相连
                port_allocation{i,1}{j,1}(2,l) = 0;%标记当前端口的占用情况，0表示未占用
            end
            p = p + G(k,j,i);%更新
        end
    end
end

%%初始物理拓扑由logical_topo{t,k}计算,然后把pod之间连接数的数值转化为端口之间的对应关系
S = zeros(sum_port,sum_port,K,T);
port_allocation_inti_topo = port_allocation;
S_Conn = [];
for t = 1: T
    for k = 1:K
        [conn_row,conn_col] = find(triu(logical_topo{t,k}));
        for conn_ind = 1:length(conn_row)
            % S_Conn(conn_row(conn_ind),conn_col(conn_ind),k,t) = logical_topo{t,k}(conn_row(conn_ind),conn_col(conn_ind));%pod之间的关系，没有对应到端口上
            [~,poducol] = find(port_allocation_inti_topo{t,1}{k,1}(1,:) == conn_row(conn_ind));%找到对应的索引
            [~,podvcol] = find(port_allocation_inti_topo{t,1}{k,1}(1,:) == conn_col(conn_ind));
            for ii = 1:logical_topo{t,k}(conn_row(conn_ind),conn_col(conn_ind)) %%此连接需要的端口数
                 % check_code = [t,k,conn_ind,ii]
                 S(poducol(ii),podvcol(ii),k,t) = 1; %%确定初始物理拓扑连接
                 S(podvcol(ii),poducol(ii),k,t) = 1; 
                 S_Conn = [S_Conn;[conn_row(conn_ind),conn_col(conn_ind),t,k,poducol(ii),podvcol(ii)]]; % 统计pods(u,v)之间连接的是哪些端口[u,v,t,k,port,port]
                 S_Conn = [S_Conn;[conn_col(conn_ind),conn_row(conn_ind),t,k,podvcol(ii),poducol(ii)]]; 
                 port_allocation_inti_topo{t,1}{k,1}(1,poducol(ii)) = 0;%更新端口数分配
                 port_allocation_inti_topo{t,1}{k,1}(1,podvcol(ii)) = 0;
            end
        end
    end
end

%更新端口占用情况，根据初始拓扑S_i,j^k,t更新(其中i和j是oxc上的端口，k为第几个oxc，t为第几个分平面)
for i = 1 : T
    for j = 1 : K
        for k = 1 : sum_port-1
            for l = k+1 : sum_port
                if S(k,l,j,i) == 1%表示第k个端口和第l个端口被占据
                    port_allocation{i,1}{j,1}(2,k)=1;
                    port_allocation{i,1}{j,1}(2,l)=1;
                end
            end
        end
    end
end

for t = 1 : T
    for k = 1 : K
        logical_topo_traffic{t,k} = zeros(inputs.nodes_num,inputs.nodes_num);
    end
end

% 流量R，给出信息包括流量大小，流量路径（具体到oxc的端口上），采用结构体存储，路由格式{[[第几个平面t，第几个oxc k，端口，端口（第一跳）]，[第几个平面，第几个oxc，端口，端口（第二跳）]，流量大小]}注意这是一条流路由
%流量选端口，挨个打满
S_Conn_cap = [S_Conn,ones(size(S_Conn,1),1)* B];% [u,v,t,k,port,port,ava_cap]
ava_ports = [];
for r = 1:req_num
    R(r).source = request(r,1);
    R(r).destination = request(r,2);
    R(r).demands = request(r,3);
    p = 1;% 更新 
    for l = 1:size(flowpath{1,r},1) %%两个阶段有重合的地方
        [row_des,~] = find(flowpath{1,r}(:,2) == R(r).destination);%找出一条路径结束的标志
        start = 1;
        path_hop = {};
        for jj = 1:length(row_des)%标志r有length(row_des)条路径
            path_hop{jj}= flowpath{1,r}(start:row_des(jj),:);%某条路径的连接，用到的capcity
            start = row_des(jj) + 1;
            flow_cap_r(jj) = path_hop{jj}(1,3);%在第jj条路径上的流r占用的bandwidth
            % if ~isempty(ava_ports)
            %     [lia,loc] = ismember(ava_ports(:,3:6),S_Conn_cap(:,3:6),'rows');%双向端口上的容量都要更新
            %     [lia1,loc1] = ismember([ava_ports(:,3:4),ava_ports(:,6),ava_ports(:,5)],S_Conn_cap(:,3:6),'rows');
            %     ava_ind = find(loc);
            %     ava_ind1 = find(loc1);
            %     loc(loc==0)=[];
            %     loc1(loc1==0)=[];
            %     S_Conn_cap(loc1,7) = ava_ports(ava_ind1,7);
            % end
            ava_ports = {};
            ava_ports_num = [];
            for ii = 1:size(path_hop{jj},1)
                Lialoc = ismember(S_Conn_cap(:,1:2),path_hop{jj}(ii,1:2),'rows');%(u,v)对应的端口和平面的行数
                ava_ports_num(ii) = sum(Lialoc(:));%满足该链接的端口数
                [ava_rows,~] = find(Lialoc);
                ava_port = S_Conn_cap(ava_rows,1:7);%对应的端口和OXC平面  %后边整体更新S_conn_cap
                [Xsorted,sortedind] = sort(ava_port(:,7));%对端口的剩余容量排序
                ava_ports{ii} = ava_port(sortedind,1:7);
            end
            if size(path_hop{jj},1) > 1 %路径有两跳，需要分配，从端口数多的,即平均流量少的开始计算
                flag = 0;
                for ij = 1:ava_ports_num(1) 
                    if flag == 1 %% 该flowpath上的流已经处理完
                        break;
                    end
                    if ava_ports{1}(ij,7) > 0 
                        for ji = 1:ava_ports_num(2) %% 随便从两跳中的哪一跳开始都行，但是要对S_Conn_cap进行更新和排序
                            if ava_ports{2}(ji,7) > 0
                                flow_val = min([ava_ports{1}(ij,7),ava_ports{2}(ji,7),flow_cap_r(jj)]);
                                R(r).route{1,p} = [ava_ports{1}(ij,3:6),ava_ports{2}(ji,3:6),flow_val];
                                
                                t = ava_ports{1}(ij,3);
                                k = ava_ports{1}(ij,4);
                                sub_path = path_hop{jj}(1,1:2);
                                logical_topo_traffic{t,k}(sub_path(1),sub_path(2)) = logical_topo_traffic{t,k}(sub_path(1),sub_path(2)) + flow_val;
                                % logical_topo_traffic{t,k}(path_hop{1}(2),path_hop{1}(1))
                                % =
                                % logical_topo_traffic{t,k}(path_hop{1}(2),path_hop{1}(1))
                                % + flow_val; %%3.22

                                t1 = ava_ports{2}(ji,3);
                                k1 = ava_ports{2}(ji,4);
                                logical_topo_traffic{t1,k1}(path_hop{jj}(2,1),path_hop{jj}(2,2)) = logical_topo_traffic{t1,k1}(path_hop{jj}(2,1),path_hop{jj}(2,2)) + flow_val;
                                % 3.22 logical_topo_traffic{t1,k1}(path_hop{2}(2),path_hop{2}(1)) = logical_topo_traffic{t1,k1}(path_hop{2}(2),path_hop{2}(1)) + flow_val;

                                % 更新对应端口的剩余流量
                                ava_ports{1}(ij,7) = ava_ports{1}(ij,7) - flow_val;
                                ava_ports{2}(ji,7) = ava_ports{2}(ji,7) - flow_val;
                                flow_cap_r(jj) = flow_cap_r(jj) - flow_val;
                                p = p+1;
                                % 更新S_Conn_cap
                                [lia,loc] = ismember(ava_ports{1}(:,3:6),S_Conn_cap(:,3:6),'rows');%双向端口上的容量都要更新
                                [lia1,loc1] = ismember([ava_ports{1}(:,3:4),ava_ports{1}(:,6),ava_ports{1}(:,5)],S_Conn_cap(:,3:6),'rows');
                                ava_ind = find(loc);
                                ava_ind1 = find(loc1);
                                loc(loc==0)=[];
                                loc1(loc1==0)=[];
                                S_Conn_cap(loc1,7) = ava_ports{1}(ava_ind1,7);
                                S_Conn_cap(loc,7) = ava_ports{1}(ava_ind,7);

                                [lia2,loc2] = ismember(ava_ports{2}(:,3:6),S_Conn_cap(:,3:6),'rows');%双向端口上的容量都要更新
                                [lia1_2,loc1_2] = ismember([ava_ports{2}(:,3:4),ava_ports{2}(:,6),ava_ports{2}(:,5)],S_Conn_cap(:,3:6),'rows');
                                ava_ind2 = find(loc2);
                                ava_ind1_2 = find(loc1_2);
                                loc2(loc2==0)=[];
                                loc1_2(loc1_2==0)=[];
                                S_Conn_cap(loc1_2,7) = ava_ports{2}(ava_ind1_2,7);
                                S_Conn_cap(loc2,7) = ava_ports{2}(ava_ind2,7);

                                if ava_ports{1}(ij,7) <= 0
                                    break;
                                end

                                if flow_cap_r(jj) <= 0
                                    flag = 1;
                                    break;
                                end
                            end
                        end
                    end
                end
            else
                %单跳路径
                for ij =  1:ava_ports_num
                    if ava_ports{1}(ij,7) > 0
                        flow_value = min(ava_ports{1}(ij,7),flow_cap_r(jj));
                        R(r).route{1,p} = [ava_ports{1}(ij,3:6),flow_value];

                        t = ava_ports{1}(ij,3);
                        k = ava_ports{1}(ij,4);
                        logical_topo_traffic{t,k}(path_hop{1}(1),path_hop{1}(2)) = logical_topo_traffic{t,k}(path_hop{1}(1),path_hop{1}(2)) + flow_value;

                        flow_cap_r(jj) = flow_cap_r(jj) - flow_value;
                        ava_ports{1}(ij,7) = ava_ports{1}(ij,7) - flow_value;
                        p = p+1;
                        [lia,loc] = ismember(ava_ports{1}(:,3:6),S_Conn_cap(:,3:6),'rows');%双向端口上的容量都要更新
                        [lia1,loc1] = ismember([ava_ports{1}(:,3:4),ava_ports{1}(:,6),ava_ports{1}(:,5)],S_Conn_cap(:,3:6),'rows');
                        ava_ind = find(loc);
                        ava_ind1 = find(loc1);
                        loc(loc==0)=[];
                        loc1(loc1==0)=[];
                        S_Conn_cap(loc1,7) = ava_ports{1}(ava_ind1,7);
                        S_Conn_cap(loc,7) = ava_ports{1}(ava_ind,7);
                        if flow_cap_r(jj) == 0
                            break;
                        end
                    end
                end
            end
        end
    end
end
end