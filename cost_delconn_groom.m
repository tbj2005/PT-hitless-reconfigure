function [total_cost,update_topo,new_add_links] = cost_delconn_groom(inputs,delta_topo,Logical_topo,method,traffic_distr)
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
        for i = 1:size(subindex,1)
            %%增加相应链接之后再计算一遍节点的出度
            indexi_degree1_1 = sum(logical_topo(subindex(i,1),:));%% original logical topo degree
            indexi_degree2_1 = sum(logical_topo(subindex(i,2),:));
            %%找到逻辑拓扑新增链接之后，空闲的端口，即u，v，因为这里只考虑u，v之间的一条连接
            if max_links_innodes - indexi_degree1_1 > 0
                 free_ports = [free_ports;ones(1,(max_links_innodes - indexi_degree1_1))'*subindex(i,1)];
            end
            if max_links_innodes - indexi_degree2_1 > 0
                free_ports = [free_ports;ones(1,(max_links_innodes - indexi_degree2_1))'*subindex(i,2)]; %空闲的端口
            end
        end
        
        %%% delta_topo_delete
        after_delete_topo =  logical_topo - delta_topo_delete; %从逻辑拓扑中去掉删除的链接 % 不一定存在该链接，因此减完可能是负值，将负值置为0
        % 删除的时候不删除已经有空闲端口的链接
        after_delete_topo(after_delete_topo < 0) =  0;%不需要置换位0，后边的操作会把-值加回去变成0
        %%NOTE:这儿需要置为0？因为-数的话 会影响要增加的链接

        % 判断删除连接后，该逻辑拓扑能够增加的链接数
        %%%3.27 前边有重复计算
        % triu_delta_topo_add =triu(delta_topo_add);
        % [~, sort_add_delta_topoind] = sort(triu_delta_topo_add(:),'descend'); 
        % [subindex_row,subindex_col] = ind2sub([inputs.nodes_num,inputs.nodes_num], sort_add_delta_topoind);
        % subindex = [subindex_row,subindex_col];
        % [row0,col0] = find(~triu_delta_topo_add);
        % subindex = setdiff(subindex,[row0,col0],'rows','stable');%%去除有关0的排序，顺序可能乱，要使用stable等，不如先去掉0再排序
        %%%3.27 前边有重复计算
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
        % [~,sortind] =  sort(delta_topo_delete(:),'ascend');%%3/10
        % [sortindex_delete_topo_row,sortindex_delete_topo_col] = ind2sub([inputs.nodes_num,inputs.nodes_num],sortind);%单次可能删除的全部链接下标
        
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
        %%%空闲端口应在位删除未删除连接之前统计
        % for i = 1:size(subindex,1)
        %     %%增加相应链接之后再计算一遍节点的出度
        %     indexi_degree1_1 = sum(update_logical_topo(subindex(i,1),:));%% original logical topo degree
        %     indexi_degree2_1 = sum(update_logical_topo(subindex(i,2),:));
        %     %%找到逻辑拓扑新增链接之后，空闲的端口，即u，v，因为这里只考虑u，v之间的一条连接
        %     if max_links_innodes - indexi_degree1_1 > 0
        %          free_ports = [free_ports;ones(1,(max_links_innodes - indexi_degree1_1))*subindex(i,1)];
        %     end
        %     if max_links_innodes - indexi_degree2_1 > 0
        %         free_ports = [free_ports;ones(1,(max_links_innodes - indexi_degree2_1))*subindex(i,2)]; %空闲的端口
        %     end
        % end
        for i = 1:size(subindex,1)
            %% need to judge which deleted links do not contribute to add connections
            % 如果删除的链接的两端端口都没有被使用，则需要被回收；如果腾出了两个可用端口，只使用了一个，那么就选择上边流量少的回收
            %1. mark the specific added links, check the free ports unused
            if can_add_conns_innodepair(i) > 0 %%
                valuesin_addnodepairs = repmat([subindex(i,1),subindex(i,2)], 1, can_add_conns_innodepair(i));
                for j = 1:2*can_add_conns_innodepair(i)  
                    [~,loc_freeports] = ismember(valuesin_addnodepairs(j),free_ports);
                    if loc_freeports ~= 0
                       free_ports(:,loc_freeports) = 0;
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
                % real_add_nodepairs = [real_add_nodepairs;[subindex(i,1),subindex(i,2)]];%真正增加的链接，以此来判断，删除链接的产生的端口没有用到
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
        % if any(update_delta_dele_topo,"all")
        %     [del_row,del_col] = find(update_delta_dele_topo);%%计算逻辑拓扑上相应容量的更新
        %     del_ind = sub2ind([inputs.nodes_num,inputs.nodes_num],del_row,del_col);
        %     update_delta_dele_topo_cap(del_ind) = inputs.connection_cap;
        %     update_logical_topo_cap = logical_topo_cap - update_delta_dele_topo_cap;
        %     % update_delta_dele_topo_cap(del_ind) = delta_topo_delete_weight(del_ind);%%只有一条边，考虑一个
        %     % update_logical_topo_cap = logical_topo_cap- delta_topo_delete_weight + update_delta_dele_topo_cap;%%按道理还要增加新增链接提供的cap  
        % else
        %     update_logical_topo_cap = logical_topo_cap- delta_topo_delete_weight + ;
        % end

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
            if method == 3
                %%为删除链接上的流 基于每个物理独立的逻辑拓扑计算路径，统计2跳内的路径数
                %%但是两跳路径也可以使用不同的平面，所以再整个网络中之间计算是合理的，但是需要更新一下网络
                update_logical_topo_whole_conn = logical_topo_whole_conn - delta_topo_delete + update_delta_reback_topo;%只删除了链接，没有更新上边的容量
                % [dele_topo_row, dele_topo_col] = find(update_delta_reback_topo);
                % update_delta_dele_reback_wei = zeros(inputs.nodes_num,inputs.nodes_num);
                % if ~isempty(dele_topo_row)
                %     dele_topo_capind = sub2ind([inputs.nodes_num,inputs.nodes_num],dele_topo_row,dele_topo_col);
                %     update_delta_dele_reback_wei(dele_topo_capind) = delta_topo_delete_weight(dele_topo_capind);
                % end
                update_logical_topo_whole_cap = logical_topo_whole_cap - delta_topo_delete_weight + update_delta_dele_reback_wei;%%更新整个网络上边的容量，以进行后边的计算
                % update_logical_topo_cap = logical_topo_cap - delta_topo_delete_weight + update_delta_dele_reback_wei;
                %%调用函数计算路径，输入是logical_topo_calpath
                %%问题：细分的路径太多，没有办法计算完全。所以考虑一跳可达的端口数和容量；然后两跳到达的端口数量和容量
                [row,col] = find(update_delta_dele_topo);%%找出实际删除了链接的行列，即链接
                %%统计连接上要删除的流%%就这么多节点，把断开连接上的流按照源-目的-带宽统计出来，剩下的路径就不进行变动了
                R_inlinks = [];
                for ii = 1:length(row) 
                    R_inlinks = [R_inlinks;traffic_distr{row(ii),col(ii)}];%%删除链接上的流量值
                end

                %如果R_inlinks是空的，则说明断开的链接上没有流量，不用考虑疏导，直接给出下边的需要的变量值
                if ~isempty(R_inlinks)
                    unique_req(:,1:2) = unique(R_inlinks(:,1:2),'rows');
                    for jj = 1:size(unique_req,1) %%统计断开链接上的流量，以及需要的带宽
                        [locb,~] = ismember(R_inlinks(:,1:2),unique_req(jj,1:2),'rows'); %%
                        [row_lob,~] = find(locb);
                        % if ~isempty(locb) %%
                            % value = sum(R_inlinks(row_lob,1:2));
                            value = sum(R_inlinks(row_lob,3));
                            unique_req(jj,3) = value;
                        % end
                    end
                     cap_ratio_2hop(size(unique_req,1),:) = 0;%%预分配内存加快速度
                     con_num_2hop(size(unique_req,1),:) = 0;
                     con_num_1hop(size(unique_req,1),:) = 0;
                     cap_ratio_1hop(size(unique_req,1),:) = 0;
                    for ii = 1:size(unique_req,1) %%为每条流计算端口和容量比
                        con_num_1hop(ii) = update_logical_topo_whole_conn(unique_req(ii,1),unique_req(ii,2));%%直连链接端口数
                        con_cap_1hop = update_logical_topo_whole_cap(unique_req(ii,1),unique_req(ii,2));
                        cap_ratio_1hop(ii) = con_cap_1hop/unique_req(ii,3);
                        %%计算两跳路径的相应值
                        [~,col1] = find(update_logical_topo_whole_conn(unique_req(ii,1),:));%%源点邻接不为0的边的列的索引
                        if ~isempty(col1)
                            for jj = 1:length(col1)
                                cap1 = update_logical_topo_whole_cap(unique_req(ii,1),col1(jj));
                                port_num = update_logical_topo_whole_conn(unique_req(ii,1),col1(jj));
                                % [~,col2(jj)] = find(update_logical_topo_whole_conn(col1(jj),:) == unique_req(ii,2));%%中间节点的目的为源目的节点的端口数量
                                [~,cols] = find(update_logical_topo_whole_conn(col1(jj),:));%%索引jj邻接不为0 的边
                                [hop_2th_row,hop_2th_col] = find(cols==unique_req(ii,2));%找到第二跳节点是流目的节点的行列
                                if ~isempty(hop_2th_col)
                                    port_num2 = update_logical_topo_whole_conn(hop_2th_row,hop_2th_col);%%中间节点的目的为源目的节点的端口数量 %%3.12
                                    cap2 = update_logical_topo_whole_cap(hop_2th_row,hop_2th_col);
                                else
                                    col2(jj) = 0;
                                    cap2 = 0;%jj对应的中间节点的邻接节点不是目的节点，端口数和容量清零
                                    port_num2 = 0;
                                end 
                                cap(jj) = min(cap1,cap2);
                                col2(jj) = min(port_num,port_num2);
                               
                            end
                            con_num_2hop(ii) = sum(col2);
                            con_cap_2hop = sum(cap);
                            cap_ratio_2hop(ii) = con_cap_2hop/unique_req(ii,3);
                        else
                            con_num_2hop(ii) = 0;
                            cap_ratio_2hop(ii) = 0;
                        end
                        
                    end
                    %%%计算在该拓扑上进行删除增加连接的benefit
                    indices = sub2ind(size(delta_topo_delete_weight), real_del_subindex1, real_del_subindex2);
                    % %%%%%%%%%%%%%%%%%%%%%按照流量计算的删除代价
                    % delete_cost = sum(delta_topo_delete_weight(indices)); 
                    % %%%%%%%%%%%%%%%%%%%%按照连接数量计算的删除代价
                    % % delete_cost = sum(delta_topo_delete(indices)); 
                    % total_cost = add_benifit - delete_cost;
                    %%%%%%%%%%%%%%%%%%%%%%%按照被疏导的可能性计算代价
                    delete_cost = sum(delta_topo_delete_weight(indices)); 
                    %%%TO DO：带宽和，第三种判别方式
                    a = 1; b = 1; c = 1; d = 1; 
                    reroute_benefit = a* sum(con_num_1hop(:)) + b* sum(cap_ratio_1hop) + c* sum(con_num_2hop) + d* sum(cap_ratio_2hop);
                    total_cost = add_benifit - delete_cost + reroute_benefit;
                else
                    indices = sub2ind(size(delta_topo_delete_weight), real_del_subindex1, real_del_subindex2);
                    delete_cost = sum(delta_topo_delete_weight(indices)); 
                    total_cost = add_benifit - delete_cost;
                end
            end
             
            update_topo.update_logical_topo_cap = update_logical_topo_cap;
            update_topo.update_logical_topo = update_logical_topo;
            update_topo.update_delta_add_topo = update_delta_add_topo;
            update_topo.update_delta_dele_topo_ed =  update_delta_dele_topo;%在k,t logical topo上删除的链接拓扑
            update_topo.update_delta_topo_dele = delta_topo_delete - update_delta_dele_topo;
            if method == 3
                update_topo.logical_topo_whole_conn = update_logical_topo_whole_conn;
                update_topo.logical_topo_whole_cap = update_logical_topo_whole_cap;
            end
        else
            total_cost = -Inf;
            update_topo.update_logical_topo_cap = logical_topo_cap;
            update_topo.update_logical_topo = logical_topo;
            update_topo.update_delta_add_topo = delta_topo_add;
            update_topo.update_delta_dele_topo_ed =  zeros(inputs.nodes_num,inputs.nodes_num);%在k,t logical topo上删除的链接拓扑
            update_topo.update_delta_topo_dele = delta_topo_delete;
            new_add_links = 0;
            if method == 3
                update_topo.logical_topo_whole_conn = logical_topo_whole_conn;
                update_topo.logical_topo_whole_cap = logical_topo_whole_cap;
            end
        end
    else
        total_cost = -Inf;
        update_topo.update_logical_topo_cap = logical_topo_cap;
        update_topo.update_logical_topo = logical_topo;
        update_topo.update_delta_add_topo = delta_topo_add;
        update_topo.update_delta_dele_topo_ed =  zeros(inputs.nodes_num,inputs.nodes_num);%在k,t logical topo上删除的链接拓扑
        update_topo.update_delta_topo_dele = delta_topo_delete;
        new_add_links = 0;
        if method == 3
            update_topo.logical_topo_whole_conn = logical_topo_whole_conn;
            update_topo.logical_topo_whole_cap = logical_topo_whole_cap;
        end
    end        
end