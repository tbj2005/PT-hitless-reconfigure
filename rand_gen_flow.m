function flow_requests = rand_gen_flow(inputs,Logical_topo_init_cap)
    flow_requests  = [];
    % rng(size(flow_requests,1))
    % rng(topo_index);
    real_req_num = 0;
    while real_req_num < inputs.num_requests
        flag = 0;
        % 随机选择源节点和目的节点
        while flag == 0
            % disp('gener topo');
            source = randi(inputs.nodes_num);
            destination = randi(inputs.nodes_num);
            % 忽略自环
            if source ~= destination
                if ~isempty(flow_requests)
                    lia = ismember([destination,source;source,destination],flow_requests(:,1:2),'rows');
                    if sum(lia,'all') == 0
                       flag = 1;
                    end
                else
                    flag = 1;
                end
            end
        end
        randnum = rand(1);
        if randnum > 0.3 &&  Logical_topo_init_cap(source,destination) > 0
            reqiure_bandwidth_band =  randi(Logical_topo_init_cap(source,destination));
        else
            reqiure_bandwidth_band =  randi(sum(Logical_topo_init_cap(source,:)/5,'all'));
        end
        flow_requests = [flow_requests;[source,destination,reqiure_bandwidth_band]];
        real_req_num = size(flow_requests,1);
    end
end