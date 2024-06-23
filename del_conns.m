
%%确定增加的连接有没有用到删除连接释放的端口，所以只有增加和删除连接，但是如果拓扑本身就有空闲端口，可能就也不需要删除连接来释放端口
function del_links_real = del_conns(inputs,add_links_tk_topo,update_logical_topo,del_update_logical_topo)
    % del_links_topo 就是 add_links_tk_topo决定del_ports
    del_links_topo = triu(del_update_logical_topo);%%每对节点对删除的连接
    del_ports = add_links_tk_topo(:);
    %%对del_ports进行处理，从del_ports中删除那些本身就有空闲端口的节点
    origin_update_logical_topo = update_logical_topo + del_update_logical_topo;
    for i_ind = 1:inputs.nodes_num
        index = find(del_ports == i_ind); 
        if ~isempty(index)
            free_portsnum(i_ind) = inputs.physical_conn_oxc - sum(origin_update_logical_topo(i_ind,:),'all');
            min_ind = min(length(index),free_portsnum(i_ind));
            del_ports(index(1:min_ind)) = [];
        end
    end

    if ~isempty(del_ports)
        %%%%%%最少删除哪些连接，空出del_ports 最小割问题或者启发式的求解
        %找出行列都在del_ports 中的del_links_topo
        if_in = [];
        for che_ind = 1:size(del_links_topo,1)
            lia = ismember(del_links_topo(che_ind,:),del_ports);
            if_in(che_ind) = sum(lia,'all');
        end
        [~,sort_ind]= sort(if_in);
        del_links_topo_sorted = del_links_topo(sort_ind,:);%优先考虑删除释放的两个端口都被用到的链接
    
        del_links_topo1 = del_links_topo_sorted;
        for del_ind = 1:size(del_ports,1)
            [row_ports_del,col_ports_del] = find(del_links_topo_sorted == del_ports(del_ind));
            if ~isempty(row_ports_del)
                del_links_topo1(row_ports_del(1),col_ports_del(1)) = 0;
            end
        end

        %%每行有为0 的元素代表要删除
        [del_real_row,~] = find(del_links_topo1 == 0);
        del_real_row = unique(del_real_row);
        del_links_real = del_links_topo(del_real_row,:);
    end
    