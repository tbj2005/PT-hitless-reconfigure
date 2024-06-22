clear excpet mm
for mm = 1:3
    %% input
    inputs.nodes_num = 4; %% podsnum
    inputs.groupnum = 2; %% vectornum
    inputs.oxcports = 12; %% ports pair that an OXC provided
    inputs.oxcnum_agroup = 1; %% oxc nums in a vector
    inputs.connection_cap = 10;
    inputs.physical_conn_oxc = 3;
    inputs.maxhop = 2;
    inputs.resi_cap = 0.65;
    inputs.method = mm;
    
    max_links_innodes = inputs.physical_conn_oxc; %%node degree 
    Logical_topo_init = zeros(inputs.nodes_num,inputs.nodes_num);
    
    %% Test data 1
    % Test_data_1;
    Test_data_2;
    
    %% delta topology
    delta_topology = Logical_topo_desi - Logical_topo_init_conn;%% + indicates add, - indicates delete
    
    physical_topo;

    filename = ['update_logical_topo',num2str(mm),'.mat'];
    save(filename,'update_logical_topo')
    
    % interface;
    
    % if method == 1
    %    reconfig_benchmark;
    % else
        % reconfig_progress;
    % end
end