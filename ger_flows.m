function flow_requests = ger_flows(inputs,Logical_topo_init_cap,topo_index)
%%假设初始的流量都是一跳可达的
%%%%%%%随机产生流量
    % rng(topo_index);
    flow_requests  = [];
    flow_requests_num = 0;
    [sour_row,dest_col] = find(triu(Logical_topo_init_cap));
    while flow_requests_num < inputs.num_requests
        if isempty(sour_row)
            break
        end
        hop1_ava_req = size(sour_row,1);
        rand_req_ind = randi([1,hop1_ava_req]);
        source = sour_row(rand_req_ind);
        destination = dest_col(rand_req_ind);
        sour_row(rand_req_ind) = [];
        dest_col(rand_req_ind) = [];

        %%带宽随机，但是总带宽不超过全网的n%
        update_total_bandwidth = 0;
        total_bandwidth = round((inputs.groupnum * inputs.oxcports *inputs.oxcnum_agroup * inputs.connection_cap/2) * inputs.cap_ratio);
        update_total_bandwidth = total_bandwidth - update_total_bandwidth;
        if update_total_bandwidth > 0
            %简单判断两跳内路径的容量
            ava_band_1hop = Logical_topo_init_cap(source,destination);%单跳
          
            ava_bandwidth = 0;
           
            ava_bandwidth = ava_bandwidth + ava_band_1hop;%%%一个流允许的最大带宽
    
            maxval = min(ava_bandwidth,update_total_bandwidth);
            if maxval ~= 0
                reqiure_bandwidth_band = randi(maxval);
                update_total_bandwidth = update_total_bandwidth - reqiure_bandwidth_band;
                flow_requests = [flow_requests;[source,destination,reqiure_bandwidth_band]];
                flow_requests_num = flow_requests_num +1;
            end
        end
    end
   
