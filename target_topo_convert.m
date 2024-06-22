%%期望物理拓扑由update_logical_topo{t,k}计算,然后把pod之间连接数的数值转化为端口之间的对应关系
function E1 = target_topo_convert(S_Conn_cap,S,logical_topo,update_logical_topo,port_allocation_inti_topo,inputs)
    S_Conn_cap_1 = S_Conn_cap;
    port_allocation_inti_topo1 = port_allocation_inti_topo;
    E1 = S;
    T = inputs.groupnum;
    K = inputs.oxcnum_agroup;
    method = inputs.method;
    % 先更新S上删除的连接，保证删除的链接上流量最小，增加的连接不涉及流量，随机增加就可以。
    for t = 1: T
        for k = 1:K
            %%% for debuging 
            for de = 1:inputs.nodes_num
                sum_row(t,k,de) = sum(update_logical_topo{t,k}(de,:));
                sum_col(t,k,de) = sum(update_logical_topo{t,k}(:,de));
                checkdebug = 1;
            end
            %%%%%to debug
            del_logical_topo{t,k} = logical_topo{t,k} -update_logical_topo{t,k};
            del_logical_topo{t,k}(del_logical_topo{t,k}<0) = 0;
            add_logical_topo{t,k} = update_logical_topo{t,k} - logical_topo{t,k};
            add_logical_topo{t,k}(add_logical_topo{t,k}<0) = 0;
            [conn_row,conn_col] = find(triu(del_logical_topo{t,k}));
            del_logical_topo{t,k},conn_row,conn_col
            for conn_ind = 1:length(conn_row)
                zero_rows = all(S_Conn_cap_1(:,5:6) == 0, 2);
                S_Conn_cap_1(zero_rows,:) = [];
              
                [lia,lobc] = ismember(S_Conn_cap_1(:,1:2),[conn_row(conn_ind),conn_col(conn_ind)],'rows');% pod之间的连接对应的索引
                [conn_row_ind, ~] = find(lia);
                pods_port_cap = S_Conn_cap_1(conn_row_ind,7);% pods(u,v)连接对应端口的剩余容量
                if method == 2 || method == 3
                   [sorted_pods_port_cap,sorted_port_cap_ind] = sort(pods_port_cap,'descend');%降序排列port_rest_cap,后边则删除的是流量较少的连接
                else
                   [sorted_pods_port_cap,sorted_port_cap_ind] = sort(pods_port_cap,'ascend');%降序排列port_rest_cap,后边则删除的是流量较少的连接
                end
                % sorted_ports = S_Conn_cap_1(conn_row_ind(sorted_port_cap_ind),:);
                sorted_ports = S_Conn_cap_1(conn_row_ind(sorted_port_cap_ind),:);
                [lia_group,~] = ismember(sorted_ports(:,3:4),[t,k],'rows'); %[u,v,t,k,port,port]
                group_row = find(lia_group);
                sorted_ports1 = sorted_ports(group_row,:);
               
                %更新S_Conn_cap_1,甚至可以不更新
                used_ports_num = del_logical_topo{t,k}(conn_row(conn_ind),conn_col(conn_ind));% 该pod对之间删除的链接
                used_index = find(lia_group,used_ports_num);
                S_conn_cap_sortind = conn_row_ind(sorted_port_cap_ind);
                used_ports_loc = S_conn_cap_sortind(used_index);
                S_Conn_cap_1(used_ports_loc,5:7) = 0; %更新S_Conn_cap_1的可用情况%端口交换位置后不更新也无所谓

                %计算应该删除链接及释放的端口
                for ii = 1:del_logical_topo{t,k}(conn_row(conn_ind),conn_col(conn_ind)) %%此连接需要的端口数
                    % disp([t,k,conn_ind,ii])
                    E1(sorted_ports1(ii,5),sorted_ports1(ii,6),k,t) = 0; %%确定目标物理拓扑连接
                    E1(sorted_ports1(ii,6),sorted_ports1(ii,5),k,t) = 0; 
                    % S删除一些连接后释放了端口，把释放的端口添加回port_allocation_inti_topo中去，然后计算新的连接
                    port_allocation_inti_topo{t,1}{k,1}(1,sorted_ports1(ii,5)) = conn_row(conn_ind);
                    port_allocation_inti_topo{t,1}{k,1}(1,sorted_ports1(ii,6)) = conn_col(conn_ind);
                end
            end
            % 计算新增连接的端口连接
            [conn_row,conn_col] = find(triu(add_logical_topo{t,k}));
            for conn_ind = 1:length(conn_row)
                % S_Conn(conn_row(conn_ind),conn_col(conn_ind),k,t) = logical_topo{t,k}(conn_row,conn_col);%pod之间的关系，没有对应到端口上
                [~,poducol] = find(port_allocation_inti_topo{t,1}{k,1}(1,:) == conn_row(conn_ind));%找到对应的索引
                [~,podvcol] = find(port_allocation_inti_topo{t,1}{k,1}(1,:) == conn_col(conn_ind));
             
                % u和v各对应几个端口，这里相当于随机取前N个端口相连，可能会导致更多的链接断开，因为S连接确定
                for ii = 1:add_logical_topo{t,k}(conn_row(conn_ind),conn_col(conn_ind)) %%此连接需要的端口数 
                     E1(poducol(ii),podvcol(ii),k,t) = 1; %%确定初始物理拓扑连接
                     E1(podvcol(ii),poducol(ii),k,t) = 1;
                     port_allocation_inti_topo{t,1}{k,1}(1,poducol(ii)) = 0;% 更新端口数分配
                     port_allocation_inti_topo{t,1}{k,1}(1,podvcol(ii)) = 0;
                end
            end
        end
    end
end