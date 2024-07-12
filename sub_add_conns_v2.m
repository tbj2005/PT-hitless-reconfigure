%%%两种方法：1 一种每个平面的每对节点之间删除一条连接，判断在该网络情况下能产生的链接  
%%% 2 对于每个待增加的链接  删除每个平面和该节点有关的所有连接 再进行判断
%%% 该函数实现第一种方法
function [rest_add_delta_topo,update_logical_topo,update_delta_topo_del,used_ind] = sub_add_conns_v2(inputs,update_logical_topo_weight, update_logical_topo, update_delta_topo_del,links_tobe_add_topo,used_ind,del_update_logical_topo_all)

for t = 1:inputs.groupnum
    for k = 1:inputs.oxcnum_agroup
        %决定t,k logical_topo_weight上的值
        logical_topo_weight = zeros(inputs.nodes_num,inputs.nodes_num);
        for i = 1:inputs.nodes_num
           for j = 1:inputs.nodes_num
               if isempty(update_logical_topo_weight{t,k}{i,j})
                   logical_topo_weight(i,j) = 0;
               else
                   logical_topo_weight(i,j) =  update_logical_topo_weight{t,k}{i,j}(1);
               end
           end
        end

        update_logical_topo_kt = update_logical_topo{t,k};
        rest_del_update_logical_topo = update_logical_topo_kt;
        %基于rest_del_update_logical_topo计算每个节点的最大可以增加或者匹配的条数
        for i_ind = 1:size(rest_del_update_logical_topo,1)
            %%每个节点最多能连接的节点数 max_match_num 
            max_match_num(i_ind) = inputs.physical_conn_oxc - sum(rest_del_update_logical_topo(i_ind,:),'all');
            %没删除链接时每个节点最多能连接的节点数，即free ports
            free_ports_before_del(i_ind) = inputs.physical_conn_oxc - sum(update_logical_topo_kt(i_ind,:),'all');
        end
        
        alreay_matched_nodes = [];
        for node_ind = 1:inputs.nodes_num
            alreay_matched_nodes = [node_ind;alreay_matched_nodes];
            match_cols = find(links_tobe_add_topo(node_ind,:));
            match_cols = setdiff(match_cols,alreay_matched_nodes);
            matchnode{node_ind} = [match_cols;links_tobe_add_topo(node_ind,match_cols)]'; %%每个节点能匹配的节点以及该节点对需要的数量            
        end
        
        % 使用最大流算法找出最大能连接的数目以及节点间的对应关系
        [mf(t,k),add_connections{t,k}] = max_flow(inputs,matchnode,max_match_num); % Note：add_connections是单向链接
        
        if mf(t,k) ~= 0
            [mf(t,k),add_connections{t,k}] = select_links(inputs,add_connections{t,k},links_tobe_add_topo,max_match_num);
        end
            del_update_logical_topo = del_update_logical_topo_all{t,k};%%%6.16
            %首先剔出连接没有变动的情况
            add_connections1_check = add_connections{t,k}(:,1:2);
            add_connections2_check = [add_connections{t,k}(:,2),add_connections{t,k}(:,1)];
            [rows_del,cols_del] = find(del_update_logical_topo);
            add_connections1 = setdiff(add_connections1_check,[rows_del,cols_del],'row');
         
            del_update_logical_topo1 = triu(del_update_logical_topo);
            for del_links_topo_ind = 1:size(add_connections1_check,1)
                if del_update_logical_topo1(add_connections1_check(del_links_topo_ind,1),add_connections1_check(del_links_topo_ind,2)) > 0
                    del_update_logical_topo1(add_connections1_check(del_links_topo_ind,1),add_connections1_check(del_links_topo_ind,2)) = 0;
                end
                if del_update_logical_topo1(add_connections2_check(del_links_topo_ind,1),add_connections2_check(del_links_topo_ind,2)) > 0
                    del_update_logical_topo1(add_connections2_check(del_links_topo_ind,1),add_connections2_check(del_links_topo_ind,2)) = 0;
                end
            end
            [del_links_topo_row, del_links_topo_col]= find(del_update_logical_topo1);
            del_links_topo = [del_links_topo_row, del_links_topo_col];
    
            %　NOTE：剩下的需要通过删除链接来创造，但是也并不是说，只能用创造的端口
            free_ports_before_del1 = free_ports_before_del; % free_ports_before_del(i)表示每个端口的空闲数量
            for add_conn_ind = 1:size(add_connections1,1)%这里要提前剔除没有变动的链接
                if free_ports_before_del1(add_connections1(add_conn_ind,1))>0
                    free_ports_before_del1(add_connections1(add_conn_ind,1)) = free_ports_before_del1(add_connections1(add_conn_ind,1)) - 1;
                    add_connections1(add_conn_ind,1) = 0;
                end
                if free_ports_before_del1(add_connections1(add_conn_ind,2))>0
                    free_ports_before_del1(add_connections1(add_conn_ind,2)) = free_ports_before_del1(add_connections1(add_conn_ind,2)) - 1;
                    add_connections1(add_conn_ind,2) = 0;
                end
            end
    
            del_ports_ind = find(add_connections1);
            del_ports = add_connections1(del_ports_ind);%增加的连接占用的ports需要删除连接
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
                    % % NOTE:原因，最大流A-B超出了free，port限制，因为3-4相当于4的端口也被占了。如果把增加的不符合端口限制的链接删掉，可能就不是最大能增加的链接数目了
                    % % 更改：A-B的匹配中，后续的A(i)-B(j)能匹配的节点，删除了前边已经考虑的节点
                    end
                end
    
                %%每行有为0 的元素代表要删除
                [del_real_row,~] = find(del_links_topo1 == 0);
                del_real_row = unique(del_real_row);
                del_links_real{t,k} = del_links_topo(del_real_row,:);
                add_del_num(t,k) = size(del_links_real{t,k},1);
                %%删除连接的数目要减去update_delta_topo_del中的链接，最后在后边判断，如果该链接被删除了更新
                %%                                                                                                           
                for del_real_ind = 1:size(del_links_real{t,k},1)
                    if update_delta_topo_del(del_links_real{t,k}(del_real_ind,1),del_links_real{t,k}(del_real_ind,2)) > 0
                        add_del_num(t,k) = add_del_num(t,k) - 1; %%去除本来就应该删除的链接之后要删除的链接
                    end
                end
                
                del_links_real_ind = sub2ind([inputs.nodes_num,inputs.nodes_num],del_links_real{t,k}(:,1),del_links_real{t,k}(:,2));
                add_del_traffic(t,k) = sum(logical_topo_weight(del_links_real_ind),'all');
                if inputs.method == 1
                    benifit(t,k) = mf(t,k) - add_del_num(t,k);
                else
                    benifit(t,k) = mf(t,k) - add_del_traffic(t,k);
                end
            else
                 benifit(t,k) = mf(t,k);
                 del_links_real{t,k} = [];
            end
        % else
        %     benifit(t,k) = -inf;
        % end
    end
end

%%% 待增加的双向链接，要查看所有重复删除的链接和要待增加的链接
% tobe_add_topo = update_delta_topo_add + links_tobe_add_topo;
tobe_add_topo = links_tobe_add_topo;
[sub_addlinks_row,sub_addlinks_col] = find(tobe_add_topo);
sub_addlinks = [sub_addlinks_row,sub_addlinks_col];
sub_addlinks_change = [];%% sub_addlinks_change 有点问题4.05
for sub_addlinks_ind = 1:size(sub_addlinks_row,1)
    addlinks_val = tobe_add_topo(sub_addlinks_row(sub_addlinks_ind),sub_addlinks_col(sub_addlinks_ind));
    sub_addlinks_change = [sub_addlinks_change;repmat(sub_addlinks(sub_addlinks_ind,:),addlinks_val,1)];%待增加的链接集合，重复链接分开表述
end

if ~isempty(used_ind)
    benifit(used_ind) = -Inf;
end
 [~,ind] = max(benifit(:));
%%计算的时候还是全部计算，取最大值的时候去除掉已经安排过的sub_logical_topo t,k
used_ind = [used_ind,ind];

% check_tk_topo = ones(inputs.groupnum,inputs.oxcnum_agroup);%初始化标记矩阵
%当所有的t,k 被检查完或者sub_addlinks_change是空的，即应该增加的链接被增加完
[mark_row,mark_col] = ind2sub([inputs.groupnum,inputs.oxcnum_agroup],ind);%%已经检查过的t.k，后边需要删除
rest_add_delta_topo = zeros(inputs.nodes_num,inputs.nodes_num);

if ~isempty(sub_addlinks_change)     
  
    add_links_tk_topo = add_connections{mark_row,mark_col}(:,1:2);%%可以按照weight repmat，但是由于匹配中间都是1 所以
    % disp("check");
    % 如果对于logical_topo,待增加的双向链接无法在该拓扑上添加，则查看下一个logical_topo
    if ~isempty(add_links_tk_topo)
        del_links_tk_topo = del_conns(inputs,add_links_tk_topo,update_logical_topo{mark_row,mark_col},del_update_logical_topo_all{mark_row,mark_col});%%
        update_logical_topo{mark_row,mark_col} = update_logical_topo{mark_row,mark_col} + del_update_logical_topo_all{mark_row,mark_col} - (del_links_tk_topo + del_links_tk_topo');
           
        % 更新基于update_logical_topo新增的链接
        for add_links_tk_topo_ind = 1:size(add_links_tk_topo,1)
            add_row = add_links_tk_topo(add_links_tk_topo_ind,1);
            add_col = add_links_tk_topo(add_links_tk_topo_ind,2);
            update_logical_topo{mark_row,mark_col}(add_row,add_col) = update_logical_topo{mark_row,mark_col}(add_row,add_col) + 1;
            update_logical_topo{mark_row,mark_col}(add_col,add_row) = update_logical_topo{mark_row,mark_col}(add_row,add_col);
        end  
      
        %%%%更新update_delta_topo_del %%%%6.17
        update_delta_topo_del = update_delta_topo_del - (del_links_tk_topo + del_links_tk_topo');
        update_delta_topo_del(update_delta_topo_del < 0) = 0;
          
        %待增加上的链接，add_connections单向
        add_links_tk_topo_bi = [add_links_tk_topo;add_links_tk_topo(:,2),add_links_tk_topo(:,1)];
        for i = 1:size(add_links_tk_topo_bi,1)
            ismember(sub_addlinks_change,add_links_tk_topo_bi(i,:),'rows')
            idx = find(ismember(sub_addlinks_change,add_links_tk_topo_bi(i,:),'rows'),1);
             if ~isempty(idx)
                sub_addlinks_change(idx, :) = []; 
             end
        end
    end

    delta_add_link_ind = sub2ind([inputs.nodes_num,inputs.nodes_num],sub_addlinks_change(:,1),sub_addlinks_change(:,2));
    for tobe_add_links_ind = 1:length(delta_add_link_ind)
        rest_add_delta_topo(delta_add_link_ind(tobe_add_links_ind)) = rest_add_delta_topo(delta_add_link_ind(tobe_add_links_ind)) + 1;
    end
end









  

