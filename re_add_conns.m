%%%两种方法：1 一种每个平面的每对节点之间删除一条连接，判断在该网络情况下能产生的链接  
%%% 2 对于每个待增加的链接  删除每个平面和该节点有关的所有连接 再进行判断
%%% 该函数实现第一种方法
function [links_tobe_add_topo,update_logical_topo,update_delta_topo_del] = re_add_conns(inputs,logical_topo,Logical_topo_weight,update_delta_topo_add, update_logical_topo, update_delta_topo_del)

% while


% check_tk_topo = ones(inputs.groupnum,inputs.oxcnum_agroup);%初始化标记矩阵
%当所有的t,k 被检查完或者sub_addlinks_change是空的，即应该增加的链接被增加完
index = 1;
while index <= inputs.groupnum * inputs.oxcnum_agroup
    
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
    if index == 1
        %%inputs for this function: update_delta_topo_add, update_logical_topo, logical_topo_weight
        %像删除链接一个每个节点对之间取一个组成新的要增加的拓扑
        %%%%%%%待增加的链接应该包含所有平面删除的链接，不然各个平面的连接关系很小可能发生变化
        links_tobe_add_topo = zeros(inputs.nodes_num,inputs.nodes_num);%下边更新，
        used_ind = [];
        for t = 1:inputs.groupnum
            for k = 1:inputs.oxcnum_agroup
                %每个逻辑拓扑的每个节点对删除一个链接，产生删除的连接拓扑，基于此进行匹配问题（最大流)
                del_topo_ind = find(update_logical_topo{t,k});
                links_tobe_add_topo(del_topo_ind) = links_tobe_add_topo(del_topo_ind) + 1;
               
                %%%6.16
                %每个逻辑拓扑的每个节点对删除一个链接
                del_update_logical_topo{t,k} = zeros(inputs.nodes_num,inputs.nodes_num);
                del_update_logical_topo{t,k}(del_topo_ind) = 1;%
                update_logical_topo{t,k} = update_logical_topo{t,k} - del_update_logical_topo{t,k};
                %%%6.16
            end
        end
        %%1 本来要删除的链接不算在待增加的连接中  2 在函数之外，运行函数之前把待删除的链接就删除了？但是不确定在那个平面上删，所以还是采用1
        links_tobe_add_topo = links_tobe_add_topo - update_delta_topo_del;
        links_tobe_add_topo(links_tobe_add_topo < 0) = 0;

        links_tobe_add_topo = update_delta_topo_add + links_tobe_add_topo;
        
        %%sub_add_conns和v2的区别
        %%sub_add_conns_v2:match_node:1->[ 2 3 5];2->[1 4...]，求出来的链接可能是对称的，因此后续删除的时候优先保留对称链接
        %%sub_add_conns：match_node:1->[ 2 3 5];2->[4...]，进行了预处理，求出来不是对称的，这样实际上就可以随意删除超过的，更简单
        % [links_tobe_add_topo,update_logical_topo,update_delta_topo_del,used_ind] = sub_add_conns(inputs,update_logical_topo_weight, update_logical_topo, update_delta_topo_del,links_tobe_add_topo,used_ind);
        [links_tobe_add_topo,update_logical_topo,update_delta_topo_del,used_ind] = sub_add_conns_v2(inputs,update_logical_topo_weight, update_logical_topo, update_delta_topo_del,links_tobe_add_topo,used_ind,del_update_logical_topo);
        
        %%debug
        row_sums = sum(update_logical_topo{used_ind}, 2);
        [find_rows,~] = find(row_sums > inputs.physical_conn_oxc); %超出
        if ~isempty(find_rows)
            disp('out')
            disp(find_rows)
        end
        % if ~isequal(update_logical_topo{used_ind},update_logical_topo{used_ind}') 
        %     disp('not equal1')
        %     disp(used_ind)
        % end
        %%debug

        index = index +1;

        if isempty(links_tobe_add_topo)
            break
        end
    else
        % [links_tobe_add_topo,update_logical_topo,update_delta_topo_del,used_ind] = sub_add_conns(inputs,update_logical_topo_weight, update_logical_topo, update_delta_topo_del,links_tobe_add_topo,used_ind);
        [links_tobe_add_topo,update_logical_topo,update_delta_topo_del,used_ind] = sub_add_conns_v2(inputs,update_logical_topo_weight, update_logical_topo, update_delta_topo_del,links_tobe_add_topo,used_ind,del_update_logical_topo);

        if ~isequal(update_logical_topo{used_ind(end)},update_logical_topo{used_ind(end)}') 
            disp('not equal2')
            disp(used_ind)
        end

        index = index +1;  
        if isempty(links_tobe_add_topo)
            break
        end
    end

    % disp('in this loop')
end












  

