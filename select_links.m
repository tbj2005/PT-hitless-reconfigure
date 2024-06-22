function [graph_weight, add_connections_real] = select_links(inputs,add_connections,links_tobe_add_topo,max_match_num)
    %%应该把连接的权重展开成边，调用这个函数就可以了,%%%不行因为对称的连接数量不一致
    asymm_links = [];
    for i = 1:size(add_connections,1)
        asymm_links = [asymm_links;repmat(add_connections(i,1:2), add_connections(i,3), 1)];
    end

    %%两种方法：1 对 待增加的连接进行升序排列，优先删除需要增加连接少的节点有关的连接，删除的时候随机删除选定的链接中的几个
    %%%%%%%%%% 2 优先删除链接的两个端点节点度都超出的链接   实际上也可以两种结合，这种需要在每一轮计算并标记出所有超出节点度的链接
    node_num = sum(links_tobe_add_topo);
    [~, sort_idx] = sort(node_num); %对要删除的连接的节点出现次数升序排列
   
   %%找出并标记每条链接上的节点及节点超出节点度的情况
   beyond_nodes = [];
   for node_i = 1:inputs.nodes_num
      
        [node_i_rows_asy_1{node_i},~] = find(asymm_links(:,1) == sort_idx(node_i)); 
        [node_i_rows_asy_2{node_i},~] = find(asymm_links(:,2) == sort_idx(node_i)); 
        node_i_rows_asy{node_i} = [node_i_rows_asy_1{node_i};node_i_rows_asy_2{node_i}];
        beyond_node_degree(node_i) = length(node_i_rows_asy{node_i}) - max_match_num(sort_idx(node_i));
    
        %%node_i实际上是排序后的索引
        %%根据链接的两个节点是否节点度都超出对链接进行排序
        if beyond_node_degree(node_i) > 0
           beyond_nodes = [beyond_nodes,sort_idx(node_i)];
        end
   end 
   %%对链接进行重新排序
    num_b = sum(ismember(asymm_links, beyond_nodes), 2);
    [~, sorted_Indices] = sort(num_b, 'descend');
    asymm_links = asymm_links(sorted_Indices, :);
   
    %%直接从超出节点度最大的节点开始删除，优先删除连接的两个节点都超出可用节点度的
    %%1 每次进入循环先判断一下每个节点的节点都超出情况，或者 2 提前判断了，后边发生变化在做更新，这里先采用2
    [~,Index] = max(beyond_node_degree);
    while  beyond_node_degree(Index) > 0 %%排序后索引超出节点度再进行以下判断
        if ~isempty(asymm_links) 
            del_asy_num = length(node_i_rows_asy{Index}) - max_match_num(sort_idx(Index));%%不对称需要删除的数量
            asymm_links(1:del_asy_num,:) = [];
            
        end 
        %%TO DO:这里需要判断，经过删除之后节点的节点度是否还超出
        [beyond_node_degree,asymm_links] = beyondnodes(inputs,sort_idx,max_match_num,asymm_links);
        [~,Index] = max(beyond_node_degree);
    end
 
add_connections_real = asymm_links;
graph_weight = size(add_connections_real,1);

end

