function flow_request = re_ger_flows(inputs,Logical_topo_init_cap)
load R_64_50.mat
total_bandwidth = sum(RE(:,3));
%%%%%%%把总带宽均分，然后剩下的随机填充
    [sour_row,dest_col] = find(triu(Logical_topo_init_cap));
    random_indices = randperm(length(sour_row));
    random_selection = sour_row(random_indices(1:inputs.num_requests));
    flow_request(:,1:2) = [sour_row(random_selection),dest_col(random_selection)];
    flow_init_bandwidth = floor(total_bandwidth/inputs.num_requests);

    for r = 1:inputs.num_requests
        topo_cap = Logical_topo_init_cap(flow_request(r,1),flow_request(r,2));
        flow_request(r,3) = min(topo_cap,flow_init_bandwidth);
    end
    rest_ava_band = flow_init_bandwidth - sum(flow_request(:,3));

    while rest_ava_band > 0
        for r = 1:inputs.num_requests
            topo_cap_rest = Logical_topo_init_cap(flow_request(r,1),flow_request(r,2)) - flow_request(r,3); 

            flow_request(r,3) = flow_request(r,3) +  topo_cap_rest;
            rest_ava_band = rest_ava_band - topo_cap_rest;
        end
    end
   
