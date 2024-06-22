%%%两种方法：1 一种每个平面的每对节点之间删除一条连接，判断在该网络情况下能产生的链接  
%%% 2 对于每个待增加的链接  删除每个平面和该节点有关的所有连接 再进行判断
%%% 该函数实现第一种方法
function [rest_add_delta_topo,update_logical_topo,update_delta_topo_del] = add_conns(inputs,logical_topo,Logical_topo_weight,update_delta_topo_add, update_logical_topo, update_delta_topo_del)
%%%debug
update_logical_topo_check = update_logical_topo;
%%%debug
% while
%%更新update_logical_topo_weight，以便决定在删除链接上的流量
%%每更新一次update_logical_topo,就相应更新update_logical_topo_weight，下边选择的时候只是应用，没有变更
for t = 1:inputs.groupnum
    for k = 1:inputs.oxcnum_agroup
       update_logical_topo_try{t,k} = update_logical_topo{t,k};
       for i = 1:inputs.nodes_num
           for j = 1:inputs.nodes_num
                if update_logical_topo_try{t,k}(i,j) > logical_topo{t,k}(i,j) %有新增链接，weight为0
                    new_add_link_num = update_logical_topo_try{t,k}(i,j) - logical_topo{t,k}(i,j);
                    update_logical_topo_weight{t,k}{i,j} = [zeros(1,new_add_link_num),Logical_topo_weight{t,k}{i,j}];
                else
                    new_del_link_num = -update_logical_topo_try{t,k}(i,j) + logical_topo{t,k}(i,j);
                    update_logical_topo_weight{t,k}{i,j} = [Logical_topo_weight{t,k}{i,j}(new_del_link_num+1:end)];
                    
                end
           end
       end
    end
end

%%inputs for this function: update_delta_topo_add, update_logical_topo, logical_topo_weight
%像删除链接一个每个节点对之间取一个组成新的要增加的拓扑
%待增加的链接应该包含所有平面删除的链接，不然各个平面的连接关系很小可能发生变化
links_tobe_add_topo = zeros(inputs.nodes_num,inputs.nodes_num);%下边更新，
for t = 1:inputs.groupnum
    for k = 1:inputs.oxcnum_agroup
        %每个逻辑拓扑的每个节点对删除一个链接，产生删除的连接拓扑，基于此进行匹配问题（最大流)
        del_topo_ind = find(update_logical_topo{t,k});
        links_tobe_add_topo(del_topo_ind) = links_tobe_add_topo(del_topo_ind) + 1;
        
    end
end
%%1 本来要删除的链接不算在待增加的连接中  2 在函数之外，运行函数之前把待删除的链接就删除了？但是不确定在那个平面上删，所以还是采用1
links_tobe_add_topo = links_tobe_add_topo - update_delta_topo_del;
links_tobe_add_topo(links_tobe_add_topo < 0) = 0;

% 不包含拓扑中删除的连接，本来待增加的连接
try_update_delta_topo_add = zeros(inputs.nodes_num,inputs.nodes_num);
add_links_ind = find(update_delta_topo_add);
try_update_delta_topo_add(add_links_ind) = 1;%%%不一定为1----但是也没有用到这个
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
        %每个逻辑拓扑的每个节点对删除一个链接
        del_update_logical_topo = zeros(inputs.nodes_num,inputs.nodes_num);
        del_topo_ind = find(update_logical_topo_kt);
        del_update_logical_topo(del_topo_ind) = 1;%%由删除的边确定在该逻辑拓扑中最大匹配的条数，即保证出度
        %待增加的链接应该包含所有平面删除的链接，不然各个平面的连接关系很小可能发生变化

        rest_del_update_logical_topo = update_logical_topo_kt - del_update_logical_topo;
        %基于rest_del_update_logical_topo计算每个节点的最大可以增加或者匹配的条数
        for i_ind = 1:size(rest_del_update_logical_topo,1)
            %%每个节点最多能连接的节点数 max_match_num 
            max_match_num(i_ind) = inputs.physical_conn_oxc - sum(rest_del_update_logical_topo(i_ind,:),'all');
            %没删除链接时每个节点最多能连接的节点数，即free ports
            free_ports_before_del(i_ind) = inputs.physical_conn_oxc - sum(update_logical_topo_kt(i_ind,:),'all');
        end
        %根据要增加的链接，确定每个节点可以匹配的节点编号。要增加的链接包含该拓扑中删除的链接和待增加的链接
        %如果每个最大匹配都不包含那条边，再考虑
        
        [add_rows,add_cols] = find(update_delta_topo_add);%不仅找出需要增加的，找出要增加的数目(to be)？
        % [del_row_kt_topo,del_col_kt_topo] = ind2sub([inputs.nodes_num,inputs.nodes_num],del_topo_ind);
        [tobe_add_row,tobe_add_col] = find(links_tobe_add_topo);
        %%NOTE！！！！！
        %%可以在最大流函数中给A(i)-B(j)的weight赋变化的值，表示A-BA(i)-B(j)之间需要更多的连接？那个时候可以考虑还要增加的数目
        match_matrix = [[add_rows,add_cols];[tobe_add_row,tobe_add_col]];
        links_tobe_add_all = match_matrix;
        match_matrix = unique(match_matrix,'rows');%去除重复连接后真正需要增加的链接，以此来决定每个节点可匹配的节点
        alreay_matched_nodes = [];
        for node_ind = 1:inputs.nodes_num
            alreay_matched_nodes = [node_ind;alreay_matched_nodes];
            row1 = find(match_matrix(:,1)==node_ind);
            row2 = find(match_matrix(:,2)==node_ind);
            matchnode1 = match_matrix(row1,2);
            matchnode2 = match_matrix(row2,1);
            matchnodes = setdiff([matchnode2;matchnode1],alreay_matched_nodes);
            matchnode{node_ind} = unique(matchnodes);  %%每个节点能匹配的节点
        end
        % 使用最大流算法找出最大能连接的数目以及节点间的对应关系
        [mf(t,k),add_connections{t,k}] = max_flow(inputs,matchnode,max_match_num); % Note：add_connections是单向链接
         %对比删除链接前的k,t logical topo，如果某些边能同时在多个t,k中实现，根据删除的代价选择
        %判断最大匹配找出的链接和原来拓扑的映射情况，需要删除多少链接 %%%这里应该是对比所有拓扑之后，计算在哪个
        
        %首先剔出连接没有变动的情况
        % add_connections1 = [add_connections(:,1:2);[add_connections(:,2),add_connections(:,1)]];
        % [rows_del,cols_del] = find(del_update_logical_topo);
        % add_connections1 = setdiff(add_connections1,[rows_del,cols_del],'row');
        % del_links_topo = setdiff([rows_del,cols_del],add_connections1,'row');
        % 变更为双向链接
        % add_connections2 = add_connections2  %%%%%%TODO：判断后边是需要双向链接还是单向连接

        %首先剔出连接没有变动的情况
        add_connections1_check = add_connections{t,k}(:,1:2);
        add_connections2_check = [add_connections{t,k}(:,2),add_connections{t,k}(:,1)];
        [rows_del,cols_del] = find(del_update_logical_topo);
        add_connections1 = setdiff(add_connections1_check,[rows_del,cols_del],'row');
        % add_connections2 = setdiff(add_connections2_check,[rows_del,cols_del],'row');

        % del_links_topo = setdiff([rows_del,cols_del],[add_connections1;add_connections2],'row');
        % del_links_topo = setdiff([rows_del,cols_del],[add_connections1_check;add_connections2_check],'row');% -3.30
        %del_links_topo与add_connections)_1比较，只需要考虑单向链接
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

        % del_links_topo1 = setdiff([rows_del,cols_del],add_connections1,'row');
        % del_links_topo2 = setdiff([rows_del,cols_del],add_connections2,'row');
        % %%取交集del_links_topo1 del_links_topo2
        % del_links_topo = intersect(del_links_topo1,del_links_topo2,'rows');

        %找出原有的空闲端口，以便后边判断删除的链接
        % free_ports_before_del1 = free_ports_before_del; % free_ports_before_del(i)表示每个端口的空闲数量
        % for add_conn_ind = 1:size(add_connections1,1)%这里要提前剔除没有变动的链接
        %     [lia,lib] = ismember(add_connections1(add_conn_ind,:),free_ports_before_del);
        %     if lia(1) == 1
        %         add_connections1(add_conn_ind,1) = 0;
        %         free_ports_before_del1(lib(1)) = free_ports_before_del1(lib(1)) - 1;
        %     end
        %     if lia(2) == 1
        %         add_connections1(add_conn_ind,2) = 0;
        %         free_ports_before_del1(lib(2)) = free_ports_before_del1(lib(2)) - 1;
        %     end
        % end
        
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
            
            % del_links_topo1 = del_links_topo; %没用到sort
            % for del_ind = 1:size(del_ports,1)
            %     [row_ports_del,col_ports_del] = find(del_links_topo == del_ports(del_ind));
            %     del_links_topo1(row_ports_del(1),col_ports_del(1)) = 0;
            %     % % NOTE:原因，最大流A-B超出了free，port限制，因为3-4相当于4的端口也被占了。如果把增加的不符合端口限制的链接删掉，可能就不是最大能增加的链接数目了
            %     % % 更改：A-B的匹配中，后续的A(i)-B(j)能匹配的节点，删除了前边已经考虑的节点
            % end

            %%每行有为0 的元素代表要删除
            [del_real_row,~] = find(del_links_topo1 == 0);
            del_real_row = unique(del_real_row);
            del_links_real{t,k} = del_links_topo(del_real_row,:);
            add_del_num(t,k) = size(del_links_real{t,k},1);
            %%删除连接的数目要减去update_delta_topo_del中的链接，最后在后边判断，如果该链接被删除了更新
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
    end
end
%%%两种方法，找出可以在多个k,t中添加的边，然后计算这些边应该在哪个k,t中实现
%%%直接计算出最小代价，然后挨个更新，上边采用第二种

% [sub_addlinks_row,sub_addlinks_col] = ind2sub([inputs.nodes_num,inputs.nodes_num],add_links_ind);%add_links_ind-待增加的双向链接
% sub_addlinks_change = [sub_addlinks_row,sub_addlinks_col];%%sub_addlinks_change 是双向的，但是，add_connections是单向的,不影响后续计算
%%% 待增加的双向链接，要查看所有重复删除的链接和要待增加的链接
tobe_add_topo = update_delta_topo_add + links_tobe_add_topo;
[sub_addlinks_row,sub_addlinks_col] = find(tobe_add_topo);
sub_addlinks = [sub_addlinks_row,sub_addlinks_col];
sub_addlinks_change = [];
for sub_addlinks_ind = 1:size(sub_addlinks_row,1)
    addlinks_val = tobe_add_topo(sub_addlinks_row(sub_addlinks_ind),sub_addlinks_col(sub_addlinks_ind));
    sub_addlinks_change = [sub_addlinks_change;repmat(sub_addlinks(sub_addlinks_ind,:),addlinks_val,1)];%待增加的链接集合，重复链接分开表述
end

[~,ind] = sort(benifit(:),'descend');%降序，先考虑benefit大的t,k拓扑

% check_tk_topo = ones(inputs.groupnum,inputs.oxcnum_agroup);%初始化标记矩阵
%当所有的t,k 被检查完或者sub_addlinks_change是空的，即应该增加的链接被增加完
index = 1;
[mark_row,mark_col] = ind2sub([inputs.groupnum,inputs.oxcnum_agroup],ind);
while index <= size(mark_row,1)
    %%%NOTE：每次计算的时候要提出已经被选择了的序号
    if isempty(sub_addlinks_change)
        break
    end

    %该拓扑上选择的增加的链接，来计算该拓扑上真正需要删除的链接
    % del_links_tk_topo = intersect(sub_addlinks_change,add_connections{mark_row(index),mark_col(index)}(:,1:2),'rows');
    add_links_tk_topo = intersect(sub_addlinks_change,add_connections{mark_row(index),mark_col(index)}(:,1:2),'rows');
    % 如果对于logical_topo,待增加的双向链接无法在该拓扑上添加，则查看下一个logical_topo
    if isempty(add_links_tk_topo)
        index = index + 1;
        break
    end

    %该拓扑上需要删除的链接,del_links_real{t,k}-如果计算出的最大链接全部在该拓扑上实施增加时需要删除的链接
    if ~isempty(del_links_real{mark_row(index),mark_col(index)})
        %%计算如果只增加部分链接需要删除的链接，简单处理的话可以直接用上边的计算结果del_links_real（最优实际上是最小割）
        del_links_real_check = del_links_real{mark_row(index),mark_col(index)};
        del_links_tk_topo = del_conns(add_links_tk_topo,del_links_real_check);%%
        del_links_tk_topo = [del_links_tk_topo;[del_links_tk_topo(:,2),del_links_tk_topo(:,1)]];

        %更新update_logical_topo,
        % 更新基于update_logical_topo删除的链接
        del_links_tk_topo_ind = sub2ind([inputs.nodes_num,inputs.nodes_num],del_links_tk_topo(:,1),del_links_tk_topo(:,2));
        update_logical_topo{mark_row(index),mark_col(index)}(del_links_tk_topo_ind) = update_logical_topo{mark_row(index),mark_col(index)}(del_links_tk_topo_ind) - 1;
        % 更新基于update_logical_topo新增的链接
        for add_links_tk_topo_ind = 1:size(add_links_tk_topo,1)
            add_row = add_links_tk_topo(add_links_tk_topo_ind,1);
            add_col = add_links_tk_topo(add_links_tk_topo_ind,2);
            update_logical_topo{mark_row(index),mark_col(index)}(add_row,add_col) = update_logical_topo{mark_row(index),mark_col(index)}(add_row,add_col) + 1;
        end
        
        %%%debug
        update_logical_topo_check_ind = update_logical_topo{mark_row(index),mark_col(index)}(del_links_tk_topo_ind);
        update_logical_topo_check_ind(update_logical_topo_check_ind>0) = 0;
        update_logical_topo_check_ind1 = sum(update_logical_topo_check_ind,'all');
        %%%debug

        %更新update_delta_topo_del
        if update_delta_topo_del(del_links_tk_topo_ind) > 0
            update_delta_topo_del(del_links_tk_topo_ind) =  update_delta_topo_del(del_links_tk_topo_ind) -1;
        end
    end
    
    %待增加上的链接，add_connections单向
    % % add_connections_bi = [add_connections;[add_connections(:,2),add_connections(:,1)]];
    % sub_addlinks_change1 = setdiff(sub_addlinks_change,add_connections{mark_row(index),mark_col(index)}(:,1:2),'rows');
    % sub_addlinks_change2 = setdiff(sub_addlinks_change,[add_connections{mark_row(index),mark_col(index)}(:,2),add_connections{mark_row(index),mark_col(index)}(:,1)],'rows');
    % sub_addlinks_change = intersect(sub_addlinks_change1,sub_addlinks_change2,'rows');
    add_links_tk_topo_bi = [add_links_tk_topo;add_links_tk_topo(:,2),add_links_tk_topo(:,1)];
    sub_addlinks_change = setdiff(sub_addlinks_change,add_links_tk_topo_bi,'rows');

    index = index + 1;
end

rest_add_delta_topo = zeros(inputs.nodes_num,inputs.nodes_num);
if ~isempty(sub_addlinks_change)%非空代表有剩余的连接还没有增加上去
     delta_add_link_ind = sub2ind([inputs.nodes_num,inputs.nodes_num],sub_addlinks_change(:,1),sub_addlinks_change(:,2));
    for tobe_add_links_ind = 1:length(delta_add_link_ind)
        rest_add_delta_topo(delta_add_link_ind) = rest_add_delta_topo(delta_add_link_ind) + 1;
    end
end



% while ~all(check_tk_topo(:) == 0)
% 
%     %该拓扑上删除的链接
%     del_links_tk_topo = intersect(sub_addlinks_change,add_connections{ind},'rows');
%     %待增加上的链接
%     sub_addlinks_change = setdiff(sub_addlinks_change,add_connections{ind},'rows');
% 
%     %更新标记矩阵
%     [mark_row,mark_col] = ind2sub([inputs.groupnum,inputs.oxcnum_agroup],ind);
%     check_tk_topo(mark_row,mark_col) = 0;
% 
%     %更新update_logical_topo
%     del_links_tk_topo_ind = sub2ind([inputs.nodes_num,inputs.nodes_num],del_links_tk_topo(:,1),del_links_tk_topo(:,2));
% 
%     update_logical_topo_kt(del_links_tk_topo_ind) = update_logical_topo_kt(del_links_tk_topo_ind) - 1;
%     update_logical_topo{mark_row,mark_col} = update_logical_topo_kt;
%     if isempty(sub_addlinks_change)
%         break
%     end
% end
          
% for t = 1:inputs.groupnum
%     if flag == 1
%         break
%     else
%         for k = 1:inputs.oxcnum_agroup
%             %该拓扑上删除的链接
%             del_links_tk_topo = intersect(sub_addlinks_change,add_connections{t,k},'rows');
%             %待增加上的链接
%             sub_addlinks_change = setdiff(sub_addlinks_change,add_connections{t,k},'rows');
% 
%             %更新update_logical_topo
%             del_links_tk_topo_ind = sub2ind([inputs.nodes_num,inputs.nodes_num],del_links_tk_topo(:,1),del_links_tk_topo(:,2));
%             update_logical_topo_kt(del_links_tk_topo_ind) = update_logical_topo_kt(del_links_tk_topo_ind) - 1;
% 
%             if isempty(sub_addlinks_change)
%                 flag = 1;
%                 break
%             end
%         end
%     end
% end











  

