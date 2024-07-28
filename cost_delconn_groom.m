function [total_cost,update_topo,new_add_links] = cost_delconn_groom(inputs,delta_topo,Logical_topo,method)
    %%要给出删除的链接拓扑，上边的权重，和上边的流量（源-目的，需求带宽）
    %1. 直接选择可以删除链接最多的那个逻辑拓扑  2. 挨个匹配，还是要看删掉可以增加的链接数，以及去掉多余删除的代价，求取物理拓扑
    %2.
    max_links_innodes = inputs.physical_conn_oxc;
    delta_topo_delete_weight = delta_topo.delta_topo_delete_weight;
    delta_topo_delete = delta_topo.delta_topo_delete;
    delta_topo_add = delta_topo.delta_topo_add;
    if method == 3
        logical_topo_whole_conn = Logical_topo.logical_topo_whole_conn;
        logical_topo_whole_cap = Logical_topo.logical_topo_whole_cap;
    end
    logical_topo_cap = Logical_topo.logical_topo_cap;
    logical_topo = Logical_topo.logical_topo;

    %%如果该逻辑拓扑上没有要删除的链接，则直接跳出 benifit = -Inf
    del_ind = find(delta_topo_delete);
    del_ele = sum(logical_topo(del_ind),'all');

    free_ports = [];
    if  del_ele > 0 % 有可以删除的链接
        %%%%%统计空闲端口 3.27
        triu_delta_topo_add =triu(delta_topo_add);
        [~, sort_add_delta_topoind] = sort(triu_delta_topo_add(:),'descend'); 
        [subindex_row,subindex_col] = ind2sub([inputs.nodes_num,inputs.nodes_num], sort_add_delta_topoind);
        subindex = [subindex_row,subindex_col];
        [row0,col0] = find(~triu_delta_topo_add);
        subindex = setdiff(subindex,[row0,col0],'rows','stable');%%去除有关0的排序，顺序可能乱，要使用stable等，不如先去掉0再排序
        add_links_ports = unique(subindex);
        for i = 1:size(add_links_ports,2)%% Erro:重复计算了freeport
            %%增加相应链接之后再计算一遍节点的出度
            indexi_degree1_1 = sum(logical_topo(add_links_ports(i),:));%% original logical topo degree
            if max_links_innodes - indexi_degree1_1 > 0
                 free_ports = [free_ports;ones(1,(max_links_innodes - indexi_degree1_1))'*add_links_ports(i)];
            end
        end

        % for i = 1:size(subindex,1)
            %%增加相应链接之后再计算一遍节点的出度
        %     indexi_degree1_1 = sum(logical_topo(subindex(i,1),:));%% original logical topo degree
        %     indexi_degree2_1 = sum(logical_topo(subindex(i,2),:));
            %%找到逻辑拓扑新增链接之后，空闲的端口，即u，v，因为这里只考虑u，v之间的一条连接
        %     if max_links_innodes - indexi_degree1_1 > 0
        %          free_ports = [free_ports;ones(1,(max_links_innodes - indexi_degree1_1))'*subindex(i,1)];
        %     end
        %     if max_links_innodes - indexi_degree2_1 > 0
        %         free_ports = [free_ports;ones(1,(max_links_innodes - indexi_degree2_1))'*subindex(i,2)]; %空闲的端口
        %     end
        % end
        
        %%% delta_topo_delete
        after_delete_topo =  logical_topo - delta_topo_delete; %从逻辑拓扑中去掉删除的链接 % 不一定存在该链接，因此减完可能是负值，将负值置为0
        % 删除的时候不删除已经有空闲端口的链接
        after_delete_topo(after_delete_topo < 0) =  0;%不需要置换位0，后边的操作会把-值加回去变成0
        update_delta_add_topo = delta_topo_add;
        % update_logical_topo = logical_topo;
        update_logical_topo =  after_delete_topo;
        %%%%%TODO: method= 1，2的时候甚至不需要排序；如果需要排序则要根据上边的流量排序，要避免对0排序已经使用weight_topo
        %%删除的行.可以不用排序，每对索引的第三列对应于一个流量值3/10
        %%还是应该排序才能知道删那条链接上的流量比较少,现在没有排序，在后边判断
        [index_delete_topo_row,index_delete_topo_col] = find(triu(delta_topo_delete));
        weight_in_index = sub2ind([inputs.nodes_num,inputs.nodes_num],index_delete_topo_row,index_delete_topo_col);
        del_index = [index_delete_topo_row,index_delete_topo_col,delta_topo_delete(weight_in_index)];%del_index-u,v,weight
        del_index_init = del_index;
        add_benifit = 0;
        % free_ports = [];
        for i = 1:size(subindex,1) 
            indexi_degree1 = sum(update_logical_topo(subindex(i,1),:));%% original logical topo degree
            indexi_degree2 = sum(update_logical_topo(subindex(i,2),:));
            max_add_conns_innodepair = max_links_innodes - max(indexi_degree2,indexi_degree1);%max_links_innodes is the max allowed physical degree between nodespair
            require_add_conns_innodepair = update_delta_add_topo(subindex(i,1),subindex(i,2));
            % require_add_conns_innodepair = sort_add_delta_topo(sort_add_delta_topoind(i));delta_topo_delete% express the same function with the top line code
            can_add_conns_innodepair(i) = min(require_add_conns_innodepair,max_add_conns_innodepair);
            add_benifit = add_benifit + can_add_conns_innodepair(i);
            % 增加链接后更新相应拓扑
            update_logical_topo(subindex(i,1),subindex(i,2)) = can_add_conns_innodepair(i) + update_logical_topo(subindex(i,1),subindex(i,2));% 增加链接之后的logical topo
            update_logical_topo(subindex(i,2),subindex(i,1)) = update_logical_topo(subindex(i,1),subindex(i,2));
            update_delta_add_topo(subindex(i,1),subindex(i,2)) = delta_topo_add(subindex(i,1),subindex(i,2)) - can_add_conns_innodepair(i);% 一次增加链接之后的Δ topo；
            update_delta_add_topo(subindex(i,2),subindex(i,1)) = update_delta_add_topo(subindex(i,1),subindex(i,2));
        end
        new_add_links = sum(can_add_conns_innodepair,'all');
        for i = 1:size(subindex,1)
            %% need to judge which deleted links do not contribute to add connections
            % 如果删除的链接的两端端口都没有被使用，则需要被回收；如果腾出了两个可用端口，只使用了一个，那么就选择上边流量少的回收
            %1. mark the specific added links, check the free ports unused
            if can_add_conns_innodepair(i) > 0 %%
                valuesin_addnodepairs = repmat([subindex(i,1),subindex(i,2)], 1, can_add_conns_innodepair(i));
                for j = 1:2*can_add_conns_innodepair(i) 
                    [~,loc_freeports] = ismember(valuesin_addnodepairs(j),free_ports);
                    if loc_freeports ~= 0
                       free_ports(loc_freeports) = 0;
                    else
                        [row_indices, col_indices] = find(del_index(:,1:2) == valuesin_addnodepairs(j));%这是一个端口，判断sortindex中含有这端口的行列
                        if ~isempty(row_indices) 
                            % Find the row with the smallest row index % 删的时候只删一条，还是应该优先删除上边流量比较小的
                            [~,min_row_index]= min(del_index(row_indices,3));
                            % Replace the value at the position with the smallest row index with 0
                            % sortindex_delete(row_indices(min_row_index),col_indices(min_row_index)) = 0;%%3/10
                            del_index(row_indices(min_row_index), col_indices(min_row_index)) = 0;
                        end
                    end  
                end
            end %%   
        end    
         % Delete rows containing 0 elements from sortindex_delete, that is, the delete topo  
        update_delta_dele_topo = zeros(inputs.nodes_num,inputs.nodes_num);
        [rows_with_zero,~] = find(del_index(:,1:2)==0);%找出至少释放的一个端口被占用的链接，说明该链接一定被删除
        rows_with_zero = unique(rows_with_zero);

        del_uv = del_index_init(rows_with_zero,1:2);
        del_uv_ind = sub2ind([inputs.nodes_num,inputs.nodes_num],del_uv(:,1),del_uv(:,2));
        update_delta_dele_topo(del_uv_ind) = 1; %实际删除链接的矩阵
        update_delta_dele_topo = update_delta_dele_topo + update_delta_dele_topo';
        update_delta_reback_topo = delta_topo_delete - update_delta_dele_topo; %需要加回去的矩阵链接  
        update_logical_topo = update_logical_topo + update_delta_reback_topo;
        %cap是剩余容量，weight是使用容量,新增链接上weight设置为Inf（还没设置）

        [dele_topo_row, dele_topo_col] = find(update_delta_reback_topo);
        update_delta_dele_reback_wei = zeros(inputs.nodes_num,inputs.nodes_num);
        if ~isempty(dele_topo_row)
            dele_topo_capind = sub2ind([inputs.nodes_num,inputs.nodes_num],dele_topo_row,dele_topo_col);
            update_delta_dele_reback_wei(dele_topo_capind) = delta_topo_delete_weight(dele_topo_capind);
        end
        update_logical_topo_cap = logical_topo_cap - delta_topo_delete_weight + update_delta_dele_reback_wei;

        [real_del_subindex1,real_del_subindex2] = find(update_delta_dele_topo);
        if  ~all(update_delta_dele_topo(:) == 0)%%如果没有删除连接，表示也没有新增链接
       
            if method == 1 %minimum rewiring 
               %%%计算在该拓扑上进行删除增加连接的benefit
               indices = sub2ind(size(delta_topo_delete_weight), real_del_subindex1, real_del_subindex2);
               % %%%%%%%%%%%%%%%%%%%%按照连接数量计算的删除代价
               delete_cost = sum(delta_topo_delete(indices)); 
               total_cost = add_benifit - delete_cost;
            end 
            if method == 2
                %%%计算在该拓扑上进行删除增加连接的benefit
                indices = sub2ind(size(delta_topo_delete_weight), real_del_subindex1, real_del_subindex2);
                %%%%%%%%%%%%%%%%%%%%%按照流量计算的删除代价
                delete_cost = sum(delta_topo_delete_weight(indices));  
                total_cost = add_benifit - delete_cost;
            end 
     
            update_topo.update_logical_topo_cap = update_logical_topo_cap;
            update_topo.update_logical_topo = update_logical_topo;
            update_topo.update_delta_add_topo = update_delta_add_topo;
            update_topo.update_delta_dele_topo_ed =  update_delta_dele_topo;%在k,t logical topo上删除的链接拓扑
            update_topo.update_delta_topo_dele = delta_topo_delete - update_delta_dele_topo;
        else
            total_cost = -Inf;
            update_topo.update_logical_topo_cap = logical_topo_cap;
            update_topo.update_logical_topo = logical_topo;
            update_topo.update_delta_add_topo = delta_topo_add;
            update_topo.update_delta_dele_topo_ed =  zeros(inputs.nodes_num,inputs.nodes_num);%在k,t logical topo上删除的链接拓扑
            update_topo.update_delta_topo_dele = delta_topo_delete;
            new_add_links = 0;
        end
    else
        total_cost = -Inf;
        update_topo.update_logical_topo_cap = logical_topo_cap;
        update_topo.update_logical_topo = logical_topo;
        update_topo.update_delta_add_topo = delta_topo_add;
        update_topo.update_delta_dele_topo_ed =  zeros(inputs.nodes_num,inputs.nodes_num);%在k,t logical topo上删除的链接拓扑
        update_topo.update_delta_topo_dele = delta_topo_delete;
        new_add_links = 0;
    end        
end