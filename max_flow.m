
%%%%%TO DO：max_flow函数中间A部B部的连接应该可以赋权重
function [mf,add_connections] = max_flow(inputs,matchnode,max_match_num)
s = inputs.nodes_num*2 + 1;
t = inputs.nodes_num*2 + 2;
max_flow_matrix = zeros(inputs.nodes_num+inputs.nodes_num+2,inputs.nodes_num+inputs.nodes_num+2);% s为nodes_num+1，d为nodes_num+2
for i = 1:inputs.nodes_num
    max_flow_matrix(inputs.nodes_num*2 + 1,i) = max_match_num(i);%s-A(j)
    max_flow_matrix(i+inputs.nodes_num,t) = max_match_num(i);%B(j)-t
    matchnodes_i = matchnode{i};
    if ~isempty(matchnodes_i)
        %%% A{i}-B{i}
        for j = 1:size(matchnodes_i,1)
            max_flow_matrix(i,inputs.nodes_num + matchnodes_i(j,1)) =  matchnodes_i(j,2);
        end
    end
end
[mf,GT,~,~] = maxflow(digraph(max_flow_matrix),s,t);
may_match_connections = GT.Edges;
may_match_connections = [may_match_connections.EndNodes,may_match_connections.Weight];
[rows,~] = find(may_match_connections(:,1:2) > inputs.nodes_num*2);
rows_match = setdiff(1:size(may_match_connections,1),rows);
add_connections = may_match_connections(rows_match,:);
add_connections(:,2) = add_connections(:,2) - inputs.nodes_num;



