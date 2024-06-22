% 通过初始带宽使用和输入参数，输出分别为：traffic_distr---一个元胞方阵，每一个元素的元素为一个三元组[S,D,R],表示流量的方向和带宽分配；
% flowpath---路径和资源分配，储存一跳和两跳通信的三元组[S,D,R]；breakflag---布尔值，1说明流量放不进拓扑；unava_flow---一个表示无法放进拓扑的流量，每个元素表示一个流量三元组[S,D,超出的带宽资源]
function [traffic_distr,flowpath,breakflag,unava_flow] = distr_Traffic(init_topo_cap,inputs)
path_topo =  init_topo_cap;
breakflag = 0;
traffic_distr = cell(inputs.nodes_num);
request = inputs.request;
unava_flow = [];
for r = 1:size(request,1) % 遍历流
    source = request(r,1);
    destination = request(r,2);
    flow_capacity = request(r,3);
    %%计算路径
    hop2_path =[];
    hop1_path = [];
    kk = 0;
    [~,col1] = find(path_topo(source,:));
    for ii = 1:length(col1)
        if col1(ii) == destination 
            hop1_path = [source,destination,path_topo(source,col1(ii))];
        else
            kk = kk + 1;
            [~,col2] = find(path_topo(col1(ii),:));
            [~,col3] = find(col2 == destination);
            next = col1(ii);
            if ~isempty(col3)
                hop2_path{kk} = [source,next,path_topo(source,col1(ii));next,destination,path_topo(col1(ii),destination)];
            else
                kk = kk - 1;
            end 
        end 
    end 
    %%找到所有 source pod 的一跳路径和两跳路径，分别存储在 hop1_path 和 hop2_path 中
    %%判断流使用那些可用路径 %%这是有一跳路径就不找第二跳了
    flag = 0;
    if ~isempty(hop1_path)
        if  path_topo(source,destination) >= flow_capacity % 如果直连总带宽大于等于流容量，即可直连
            flow_rest_cap = 0; % 这条流完全被放到该路径
        % if  hop1_path(:,3) > flow_capacity %3.12
            link_rest_cap = hop1_path(:,3) - flow_capacity;%边上的值使用hop1_path上边的值更新的
            path_topo(hop1_path(:,1),hop1_path(:,2)) = link_rest_cap;%更新放入流量后的剩余带宽矩阵
            path_topo(hop1_path(:,2),hop1_path(:,1)) = path_topo(hop1_path(:,1),hop1_path(:,2));
            flowpath{r} = [hop1_path(:,1:2),flow_capacity];
        else
            flowpath{r} = hop1_path; %需要两跳转发，但是还是要榨干直连的最后一丝价值
            link_rest_cap = 0;
            path_topo(hop1_path(:,1),hop1_path(:,2)) = link_rest_cap;
            path_topo(hop1_path(:,2),hop1_path(:,1)) = link_rest_cap;
            flow_rest_cap = flow_capacity - hop1_path(:,3);
            flag = 1;
        end
    else %单跳已经没有带宽了，等后续算两跳
        flag = 1;
        flowpath{r} = [];%%3.26
        flow_rest_cap = flow_capacity;
    end
    
    if flag == 1 
        used_path = hop2_path;
        for i = 1:size(hop2_path,1) % 遍历所有两跳路径
             % min_path_cap = min(hop2_path{i}(:,3));%3.12
             pathcap_index = sub2ind([inputs.nodes_num,inputs.nodes_num],hop2_path{i}(:,1),hop2_path{i}(:,2));
             min_path_cap = min(path_topo(pathcap_index));%找到两跳路径的最小带宽
             if min_path_cap >= flow_rest_cap %%路径上链路容量最小的链接可以满足剩余流量需求
                 used_path{i}(:,3) = flow_rest_cap;% flow_rest_cap表示流在该条链接上占用的带宽
                 flowpath{r} = [flowpath{r};[used_path{i}]];
                 path_topo(hop2_path{i}(1,1),hop2_path{i}(1,2)) = path_topo(hop2_path{i}(1,1),hop2_path{i}(1,2)) - flow_rest_cap;%path_topo表示的是剩余容量
                 path_topo(hop2_path{i}(1,2),hop2_path{i}(1,1)) = path_topo(hop2_path{i}(1,1),hop2_path{i}(1,2));%
                 path_topo(hop2_path{i}(2,1),hop2_path{i}(2,2)) = path_topo(hop2_path{i}(2,1),hop2_path{i}(2,2)) - flow_rest_cap;
                 path_topo(hop2_path{i}(2,2),hop2_path{i}(2,1)) = path_topo(hop2_path{i}(2,1),hop2_path{i}(2,2));
                 flow_rest_cap = 0;
             else
                 used_path{i}(:,3) = min_path_cap;
                 flow_rest_cap = flow_rest_cap - min_path_cap;
                 path_topo(hop2_path{i}(1,1),hop2_path{i}(1,2)) = max(0,(path_topo(hop2_path{i}(1,1),hop2_path{i}(1,2)) - min_path_cap));
                 path_topo(hop2_path{i}(1,2),hop2_path{i}(1,1)) = path_topo(hop2_path{i}(1,1),hop2_path{i}(1,2));
                 path_topo(hop2_path{i}(2,1),hop2_path{i}(2,2)) = max(0,(path_topo(hop2_path{i}(2,1),hop2_path{i}(2,2)) - min_path_cap));
                 path_topo(hop2_path{i}(2,2),hop2_path{i}(2,1)) = path_topo(hop2_path{i}(2,1),hop2_path{i}(2,2));
                 % flowpath = [flowpath;[hop2_path{i}]];
                 flowpath{r} = [flowpath{r};[used_path{i}]];
             end
        end
    end
    
    if flow_rest_cap > 0  %%如果流r找不到两跳内满足容量需求的，则做一个标记后换一组流，或者拓扑也重新换
        breakflag = 1;
        unava_flow = [unava_flow;[request(r,1:2),flow_rest_cap]];
        % traffic_distr = [];
    else
        for j = 1:size(flowpath{r},1)
            %%TO DO：让边上的流量占用保持一致 （目前不对称）可以使用的时候再处理
            traffic_distr{flowpath{r}(j,1),flowpath{r}(j,2)} = [traffic_distr{flowpath{r}(j,1),flowpath{r}(j,2)};[source,destination,flowpath{r}(j,3)]];%链接(u，v)，链接上流的源-目的，在该链接上占用的带宽
        end
    end
end

