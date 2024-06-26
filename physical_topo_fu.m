%%%%% 二分图匹配
function [update_logical_topo,update_check_flag] = physical_topo_fu(inputs,delta_topology,traffic_distr,logical_topo_traffic,logical_topo,logical_topo_cap)
update_check_flag = 0;
if update_check_flag ~=0
    return
end
method = inputs.method;
delta_topo_add = delta_topology;
delta_topo_dele = delta_topology;
delta_topo_add(delta_topo_add<0) = 0; %% add links
delta_topo_dele(delta_topo_dele>0) = 0; %% delete links
delta_topo_dele = -delta_topo_dele;%链接符号取正
sum_add_conns = sum(triu(delta_topo_add),"all");

%判断增加连接在哪个拓扑上的时候没有对分解后的逻辑拓扑排序.(好像没有必要排序）
%%并且其实没有必要计算benifit(t,k)；因为没有比较benefit，直接可以增加的话就更新的。如果结果不好的话，可以尝试对逻辑拓扑的连接数由小到大排序
whole_logical_topo = zeros(inputs.nodes_num,inputs.nodes_num);
whole_logical_topo_cap = whole_logical_topo *inputs.connection_cap; %应该根据网络中流量分布进行更新
update_delta_topo_add = delta_topo_add;
update_logical_topo = logical_topo;
update_logical_topo_cap = logical_topo_cap; %应该根据网络中流量分布进行更新 3.24
for t = 1:inputs.groupnum % vector 
    for k = 1:inputs.oxcnum_agroup
        %%% find free ports, the available added connnections num is the same whatever how to connect the free ports
        %%% the num of connections canbe added can calculate by this, but the result may not required for delta topo
        % occupied_ports = sum(triu(logical_topo{k}),"all"); 
        % ava_add_conns = (oxcports - occupied_ports)/2;
        % add_mapping_topo = delta_topo_1 +  logical_topo{k};
        %%% determine how to add connections
        triu_update_delta_topo_add = triu(update_delta_topo_add);
        [sort_add_delta_topo, sort_add_delta_topoind] = sort(triu_update_delta_topo_add(:),'descend');%矩阵中的0也sort了
        [subindex_row,subindex_col] = ind2sub([inputs.nodes_num,inputs.nodes_num], sort_add_delta_topoind);
        subindex1 = [subindex_row,subindex_col];
        [row0,col0] = find(triu_update_delta_topo_add==0);
        subindex = setdiff(subindex1,[row0,col0],'rows','stable');%%去除有关0的排序
        benifit(t,k) = 0;
        for i = 1:size(subindex,1)
            indexi_degree1 = sum(update_logical_topo{t,k}(subindex(i,1),:));%% original logical topo degree
            indexi_degree2 = sum(update_logical_topo{t,k}(subindex(i,2),:));
            max_add_conns_innodepair = inputs.physical_conn_oxc - max(indexi_degree2,indexi_degree1);
            require_add_conns_innodepair = update_delta_topo_add(subindex(i,1),subindex(i,2));
            % require_add_conns_innodepair = sort_add_delta_topo(sort_add_delta_topoind(i));% express the same function with the top line code
            can_add_conns_innodepair = min(require_add_conns_innodepair, max_add_conns_innodepair);
            update_logical_topo{t,k}(subindex(i,1),subindex(i,2)) = can_add_conns_innodepair + update_logical_topo{t,k}(subindex(i,1),subindex(i,2));
            update_logical_topo{t,k}(subindex(i,2),subindex(i,1)) = update_logical_topo{t,k}(subindex(i,1),subindex(i,2));
            update_logical_topo_cap{t,k}(subindex(i,1),subindex(i,2)) = can_add_conns_innodepair*inputs.connection_cap + update_logical_topo{t,k}(subindex(i,1),subindex(i,2)) - can_add_conns_innodepair;
            update_logical_topo_cap{t,k}(subindex(i,2),subindex(i,1)) = update_logical_topo_cap{t,k}(subindex(i,1),subindex(i,2));
            update_delta_topo_add(subindex(i,1),subindex(i,2)) = update_delta_topo_add(subindex(i,1),subindex(i,2)) - can_add_conns_innodepair;
            update_delta_topo_add(subindex(i,2),subindex(i,1)) =  update_delta_topo_add(subindex(i,1),subindex(i,2));
            benifit(t,k) = benifit(t,k) + can_add_conns_innodepair;
        end
        whole_logical_topo = whole_logical_topo + update_logical_topo{t,k};
        whole_logical_topo_cap = whole_logical_topo_cap + update_logical_topo_cap{t,k};
    end
end

%%cap是logical整个剩下的容量，weight
for t = 1:inputs.groupnum
    for k = 1:inputs.oxcnum_agroup
        logical_topo_traffic{t,k} = logical_topo_traffic{t,k}' +logical_topo_traffic{t,k};
        [rows,cols] = find(logical_topo_traffic{t,k});%有流量的pods对
        % Logical_topo_weight{t,k} = cell(inputs.nodes_num,inputs.nodes_num);
        for u = 1:inputs.nodes_num
            for v = 1:inputs.nodes_num
             Logical_topo_weight{t,k}{u,v} = zeros(1,logical_topo{t,k}(u,v));
            end
        end
        for w_ind = 1:length(rows)
            w_requied_linknum = logical_topo_traffic{t,k}(rows(w_ind),cols(w_ind))/inputs.connection_cap;
            res_traffic = rem(logical_topo_traffic{t,k}(rows(w_ind),cols(w_ind)),inputs.connection_cap);
            w_requied_linknum_floor = floor(w_requied_linknum);
            actual_linksnum = update_logical_topo{t,k}(rows(w_ind),cols(w_ind));
            if res_traffic == 0 
                if actual_linksnum > w_requied_linknum_floor
                    Logical_topo_weight{t,k}{rows(w_ind),cols(w_ind)} = [zeros(1,actual_linksnum-w_requied_linknum_floor),(1:w_requied_linknum_floor)*inputs.connection_cap];
                else
                    Logical_topo_weight{t,k}{rows(w_ind),cols(w_ind)} = (1:w_requied_linknum_floor)*inputs.connection_cap;
                end
            else
                if actual_linksnum == w_requied_linknum_floor + 1
                    Logical_topo_weight{t,k}{rows(w_ind),cols(w_ind)} = [res_traffic,(1:w_requied_linknum_floor)*inputs.connection_cap];
                else
                    Logical_topo_weight{t,k}{rows(w_ind),cols(w_ind)} = [zeros(1,actual_linksnum-w_requied_linknum_floor-1),res_traffic,(1:w_requied_linknum_floor)*inputs.connection_cap];
                end
            end
        end
        Logical_topo_weight{t,k}(cellfun("isempty",Logical_topo_weight{t,k})== 1) = {0};%可有可无？不影响
        update_delta_topo_deled_tk{t,k} = zeros(inputs.nodes_num,inputs.nodes_num);
        deleted_links_all{t,k} = zeros(inputs.nodes_num,inputs.nodes_num);
    end
end
%% % (增和删可以不在一个逻辑拓扑上，反正删除不会影响新增的，那可以分开衡量增加和删除）
%%初始化，只需要对齐删除链接的拓扑，其他已经更新过了
% a = 0;
update_delta_topo_dele_ed = zeros(inputs.nodes_num,inputs.nodes_num);
update_delta_topo_dele = delta_topo_dele;
% deleted_links_all = ones(inputs.nodes_num,inputs.nodes_num);
while any(update_delta_topo_add,"all")

    % deleted_links_all{t,k} = deleted_links_all{t,k} +
    % update_delta_topo_deled_tk{t,k}; %
    % 上边的值应该是logical_topo_weight的应该取的值的索引 %3.31--line 99->line 222
    for t = 1:inputs.groupnum
        for k = 1:inputs.oxcnum_agroup
            %%% delete links benifits, should not delete links that added; judge delete links can creat free ports for adding or not
            %(1. 直接对能够删某个连接的全部逻辑拓扑进行排序，选择上边流量少且删除可以创造可用free ports，问题：可能需要删除多条不一样的才能看出能否创造出free ports 
            % dele_logical_topo = logical_topo{k} + delta_topo_2;
            % 2. 挨个对逻辑拓扑删除所有可以删除的链接进行评估，判断其收益和成本,问题：删除链接可能集中在几个拓扑上.集中的问题：可能需要疏导更多的流量） 
            % 3. 可以先考虑节点对之间的占用带宽最小的（一个）链接去对应逻辑拓扑，可以中和上边说的问题（也就是说产生每个节点对只删除一条连接的新中间拓扑）
            %     这里不应该提前确定连接的权重，因为权重和在logical_topo{k,t}中k,t的位置有关
            % 为什么不考虑一条一条链接拆，因为拆一条很可能并不能释放可用端口
            % 集中在某个平面，使用Google的按平面切可能会加快切换速度
            %% 3. 实际上对应的逻辑拓扑决定了节点对之间的占用带宽，各个占用带宽最小的连接可能并不在一个逻辑拓扑，不可行
            intermid_delta_topo_may = update_delta_topo_dele;%%
            intermid_delta_topo_may(intermid_delta_topo_may > 0) = 1;
            [row_del,col_del] = find(intermid_delta_topo_may);
            intermid_delta_topo_2 = zeros(inputs.nodes_num,inputs.nodes_num);
            % ind_del = find(intermid_delta_topo_2);

            %%下边应该判断逻辑拓扑k，t是否还具有删除detlo的能力，在这边判断就不需要在cost_delconn_groom判断了。删除不存在的边会影响边pod对之间多个链接上流量的分配-3.27
            % for index_del = 1:length(ind_del)%确定在logical_k,t中真正可以删除的链接
            %     if update_logical_topo{t,k}(ind_del) > 0
            %         intermid_delta_topo_2(ind_del) = 1;
            %     end
            % end
            for we = 1:size(row_del)%确定在logical_k,t中真正可以删除的链接,比如说logical_topo_k,t没有待删删除的那条连接
                if update_logical_topo{t,k}(row_del(we),col_del(we)) > 0
                    intermid_delta_topo_2(row_del(we),col_del(we)) = 1;
                end
            end
            [row_del1,col_del1] = find(intermid_delta_topo_2);
            if all(intermid_delta_topo_2(:) == 0) %t,k上的logical_topo不具备删除该topo_del的能力
                total_benefit(t,k) = -Inf;
                update_topo{t,k} = [];
                new_add_links(t,k) = 0;
            else
                delta_topo_delete_weight = intermid_delta_topo_2;
                deleted_links_all_1{t,k} = deleted_links_all{t,k} + intermid_delta_topo_2;%%应该和t,k有关
    
                % delta_topo_delete_weight(ind_del) = Logical_topo_weight{t,k}{ind_del}(deleted_links_all_2(ind_del));
                for we_in = 1:length(row_del1)
                    deleted_links_all_2 = deleted_links_all_1{t,k};
                    delta_topo_delete_weight(row_del1(we_in),col_del1(we_in)) = Logical_topo_weight{t,k}{row_del1(we_in),col_del1(we_in)}(deleted_links_all_2(row_del1(we_in),col_del1(we_in)));
                end
                delta_topo.delta_topo_delete_weight = delta_topo_delete_weight; %
                delta_topo.delta_topo_delete = intermid_delta_topo_2;
                delta_topo.delta_topo_add = update_delta_topo_add;
                Logical_topo.logical_topo_cap = update_logical_topo_cap{t,k};
                Logical_topo.logical_topo = update_logical_topo{t,k};
                
                %%% judge delete links can creat the number of free ports for adding 
                %%计算增删的代价
                [total_benefit(t,k),update_topo{t,k},new_add_links(t,k)] = cost_delconn_groom(inputs,delta_topo,Logical_topo,method); 
                % if all(update_topo{t,k}.update_delta_topo_dele==0,'all') && ~all(update_topo{t,k}.update_delta_add_topo==0,'all')
                %     total_benefit(t,k)= -Inf;%不能是INF，还可以利用其他空闲端口增加连接，然后删除本平面的该连接
                %     %%% 1. 查看要增加的连接的两个端口在哪些平面上还具有空闲端口
                %     %%% 2.比如说节点2有一个空闲端口，需要新增的连接是2-3，节点3上无空闲端口，判断删除节点3上的哪条连接，该链接可以在别的平面不删除连接增加，
                %     %%%    或者删除连接后有增加（可以联合整个网络看），以此来创造空闲端口来增加链接2-3
                %     %%% 删除delta中需要删除的链接是最优的选择，但是可能存在不可行解，需要新增删除的链接
                %     %%% 加一个判断，当待删除的链接删除之后无法为新增链接创造端口，则需要删除额外的链接，也需要增加额外的链接
                % end
            end
        end
    end
    
    %%% 1. 查看要增加的连接的两个端口在哪些平面上还具有空闲端口
    %%% 2.比如说节点2有一个空闲端口，需要新增的连接是2-3，节点3上无空闲端口，判断删除节点3上的哪条连接，该链接可以在别的平面不删除连接增加，
    %%%    或者删除连接后有增加（可以联合整个网络看），以此来创造空闲端口来增加链接2-3
    %%% 删除delta中需要删除的链接是最优的选择，但是可能存在不可行解，需要新增删除的链接
    %%% 加一个判断，当待删除的链接删除之后无法为新增链接创造端口，则需要删除额外的链接，也需要增加额外的链接
    %%% 并不是说预计删除的链接删完而需要增加的链接还没增加完才才需要考虑删除别的链接，而是一旦所有平面都不满足新增链接的条件，但是仍有新增链接未增加，则需要进入
    %%% 最差可以基于此粗暴的断开剩下的链接然后重连
    b_check = 0;
    if all(new_add_links(:) == 0)
        %% 如果每个平面不能新增链接，但是还需要新增链接
        while ~all(update_delta_topo_add(:) == 0)
            b_check = b_check + 1;

            %%%%NOTE：相当于整个循环出不来
            % [update_delta_topo_add,update_logical_topo,update_delta_topo_dele] = add_conns(inputs,logical_topo,Logical_topo_weight,update_delta_topo_add, update_logical_topo,update_delta_topo_dele);
            [update_delta_topo_add,update_logical_topo,update_delta_topo_dele] = re_add_conns(inputs,logical_topo,Logical_topo_weight,update_delta_topo_add, update_logical_topo, update_delta_topo_dele);
        end
    else
        min_total_benefit  = max(total_benefit,[],"all");
        [min_row,min_col] = find(total_benefit==min_total_benefit);     
        update_logical_topo{min_row(1),min_col(1)} = update_topo{min_row(1),min_col(1)}.update_logical_topo;
        update_logical_topo_cap{min_row(1),min_col(1)} = update_topo{min_row(1),min_col(1)}.update_delta_add_topo;
        update_delta_topo_dele_ed = update_topo{min_row(1),min_col(1)}.update_delta_dele_topo_ed;%%在选中的k,t上删除的链接拓扑
        update_delta_topo_add = update_topo{min_row(1),min_col(1)}.update_delta_add_topo;
        update_delta_topo_dele = update_delta_topo_dele - update_delta_topo_dele_ed;
        update_delta_topo_deled_tk{min_row(1),min_col(1)} = update_delta_topo_dele_ed; %3.26
        deleted_links_all{min_row(1),min_col(1)} = deleted_links_all{min_row(1),min_col(1)} + update_delta_topo_deled_tk{min_row(1),min_col(1)}; %3.31
        
    end
end   
end
