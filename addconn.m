function [can_add_conns_innodepair,update_logical_topo,update_delta_topo] = addconn(delta_topo_add,logical_topo)
        [~, sort_add_delta_topoind] = sort(delta_topo_add(:));
        subindex = ind2sub(sort_add_delta_topoind);
        update_delta_topo = delta_topo_add;
        update_logical_topo = logical_topo;
        for i = 1:size(subindex,1)
            indexi_degree1 = sum(update_logical_topo(subindex(i,1),:));%% original logical topo degree
            indexi_degree2 = sum(update_logical_topo(subindex(i,2),:));
            max_add_conns_innodepair = max_links_innodes - max(indexi_degree2,indexi_degree1);
            %problem:
            %不一定是增加连接数最多的方法，增加的链接数不一定是最多的，首先增加的某对链接集中在单个物理逻辑拓扑上，增加的链接节点对不分散并且作用的物理逻辑拓扑不分散。
            require_add_conns_innodepair = update_delta_topo(subindex(i,1),subindex(i,2));
            % require_add_conns_innodepair = sort_add_delta_topo(sort_add_delta_topoind(i));% express the same function with the top line code
            can_add_conns_innodepair = min(require_add_conns_innodepair,max_add_conns_innodepair);
            update_logical_topo(subindex(i,1),subindex(i,2)) = can_add_conn_innodepair + update_logical_topo(subindex(i,1),subindex(i,2));
            update_delta_topo = delta_topo_add(subindex(i,1),subindex(i,2)) - can_add_conns_innodepair;
        end
end