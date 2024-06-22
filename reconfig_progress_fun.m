function stages = reconfig_progress_fun(S,E,R,inputs,port_allocation)
    Omega = inputs.nodes_num; %% podsnum
    T = inputs.groupnum; %% vectornum
    sum_port = inputs.oxcports; %% ports pair that an OXC provided
    K = inputs.oxcnum_agroup; %% oxc nums in a vector
    B = inputs.connection_cap;
    H = inputs.maxhop;
    eta_th = inputs.resi_cap;%全网剩余容量阈值
    % request = inputs.request;%网络中的流

    M = S;
    stages = 0;
    %当前网络中的流量分布状态Distri
    clear Distri;
    Distri = struct('connections',{},'request',{},'size',{});%初始化结构体
    row = 0;%指示行数
    %遍历R中的每一条流
    for i = 1 : T
        for j = 1 : K
            for k = 1 : sum_port-1
                for l = k+1 : sum_port
                    if M(k,l,j,i)==1
                        %将该条连接存储进L中
                        row = row + 1;
                        Distri(row).connections = [i,j,k,l];%填充格式[分平面，OXC，端口，端口]
                        Distri(row).size = 0;%记录经过当前连接的流量大小
                        for m = 1 : length(R)
                            for n = 1 : length(R(m).route)
                                for o = 1 : ((length(R(m).route{n})-1)/4)%指示当前路由有几跳
                                    judge = [R(m).route{n}((o-1).*4+1), R(m).route{n}((o-1).*4+2), R(m).route{n}((o-1).*4+3), R(m).route{n}((o-1).*4+4)];
                                    if isequal([i,j,k,l], judge) || isequal([i,j,l,k], judge)%当前流经过该连接，存储起来
                                        Distri(row).request{length(Distri(row).request)+1} = [m,n];%存储的是在R中的位置
                                        Distri(row).size = Distri(row).size + R(m).route{n}(length(R(m).route{n}));%统计流量
                                        break;
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    while ~isequal(M, E)
        
        M_last = M;%M_last，记录上一个阶段的物理拓扑，用于判断是否可以平滑重构
        eta_den = length(Distri);%记录上一个阶段拓扑中的连接数
        clear L;
        L = struct('connections',{},'request',{},'size',{});%初始化结构体
        row = 0;%指示行数
        %找到要拆除的连接，比较M和E，找M=1，E=0的位置
        for i = 1 : T
            for j = 1 : K
                for k = 1 : sum_port-1
                    for l = k+1 : sum_port
                        if M(k,l,j,i)==1 && E(k,l,j,i)==0
                            %将该条连接存储进L中
                            row = row + 1;
                            L(row).connections = [i,j,k,l];%填充格式[分平面，OXC，端口，端口]
                            L(row).size = 0;%记录经过当前连接的流量大小
                            %遍历R中的每一条流
                            for m = 1 : length(R)
                                for n = 1 : length(R(m).route)
                                    for o = 1 : ((length(R(m).route{n})-1)/4)%指示当前路由有几跳
                                        judge = [R(m).route{n}((o-1).*4+1), R(m).route{n}((o-1).*4+2), R(m).route{n}((o-1).*4+3), R(m).route{n}((o-1).*4+4)];
                                        if isequal([i,j,k,l], judge) || isequal([i,j,l,k], judge)%当前流经过该连接，存储起来
                                            L(row).request{length(L(row).request)+1} = [m,n];%存储的是在R中的位置
                                            L(row).size = L(row).size + R(m).route{n}(length(R(m).route{n}));%统计流量
                                            break;
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    
        %根据L中每条连接上的流量进行升序排列
        L_1 = zeros(length(L),2);%初始化二维矩阵
        for i = 1 : length(L)
            L_1(i,1) = i;
            L_1(i,2) = L(i).size;
        end
    
        sorted_L = sortrows(L_1, 2);%对L_1第二列进行升序排列
    
        %eta = 1;%全网剩余容量（每个阶段都更新）
    
        for i = 1 : length(L)
            eta = (length(Distri)-1)/eta_den;
            if eta >= eta_th%判断是否不小于阈值
                copy_R = R;%复制一份(会对copy_R做更新，但是由于目前还不确定是否能拆除当前连接，所以不能对R直接进行操作)
                copy_Distri = Distri;%复制一份，同上
                flag = 0;%标识当前连接实际是否能被拆除（等于1表示不可拆）
    
                %从M中删除当前连接
                M(L(sorted_L(i,1)).connections(3),L(sorted_L(i,1)).connections(4),L(sorted_L(i,1)).connections(2),L(sorted_L(i,1)).connections(1)) = 0;
                M(L(sorted_L(i,1)).connections(4),L(sorted_L(i,1)).connections(3),L(sorted_L(i,1)).connections(2),L(sorted_L(i,1)).connections(1)) = 0;
                
                %更新copy_Distri
                for j = 1 : length(copy_Distri)
                    if isequal(L(sorted_L(i,1)).connections, copy_Distri(j).connections)
                        %删除该行
                        copy_Distri(j)=[];
                        break;
                    end
                end
    
                %还需要更新上面的流量分布（因为有些流量可能有多跳）
                if sorted_L(i,2) ~= 0
                    for j = 1 : length(L(sorted_L(i,1)).request)%遍历当前要拆除的连接上的每一条流
                        %检查该流原路由是几跳
                        Hops = (length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{L(sorted_L(i,1)).request{1,j}(2)})-1)/4;
                        Route = copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(L(sorted_L(i,1)).request{1,j}(2));
                        f_size = Route{1}(length(Route{1}));%存储该流流量大小
                        Route{1}(length(Route{1})) = [];%删除最后一位流量
                        if Hops > 1%说明有多跳
                            for k = 1 : Hops
                                mid = [Route{1}((k-1).*4+1), Route{1}((k-1).*4+2), Route{1}((k-1).*4+3), Route{1}((k-1).*4+4)];
                                if isequal(mid, L(sorted_L(i,1)).connections)
                                    continue;
                                else
                                    for l = 1 : length(copy_Distri)
                                        if isequal(mid, copy_Distri(l).connections)
                                            for m = 1 : length(copy_Distri(l).request)
                                                if isequal(L(sorted_L(i,1)).request(1,j), copy_Distri(l).request(1,m))
                                                    copy_Distri(l).request(m) = [];%删除
                                                    copy_Distri(l).size = copy_Distri(l).size - f_size;%更新该连接上的流量占用情况
                                                    break;
                                                end
                                            end
                                            break;
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
    
                if sorted_L(i,2) ~= 0%说明该条连接上有流量经过，检查实际是否可以拆除
    
                    %Route_Scheme = {};%路由方案存储（存储的是挑选完毕的路由），每一行对应一条待重路由的流
                    for j = 1 : length(L(sorted_L(i,1)).request)%遍历当前要拆除的连接上的每一条流
                        pod_3 = copy_R(L(sorted_L(i,1)).request{1,j}(1)).source;
                        pod_4 = copy_R(L(sorted_L(i,1)).request{1,j}(1)).destination;
                        
                        %先找一跳的路由
                        row = 0;%指示行数
                        one_hop = [];%初始化一个空二维数组，第一列存储该连接在copy_Distri中的第几行，第二列存储剩余容量便于选择
                        for k = 1 : T%遍历每个平面
                            for l = 1 : K%遍历每个OXC
                                for m = 1 : sum_port - 1
                                    for n = m + 1 : sum_port
                                        if M(m,n,l,k) == 1
                                            pod_1 = port_allocation{k,1}{l,1}(1,m);
                                            pod_2 = port_allocation{k,1}{l,1}(1,n);
                                            if (pod_1 == pod_3 && pod_2 == pod_4) || (pod_1 == pod_4 && pod_2 == pod_3)
                                                %检查当前连接上是否有足够空闲的余量
                                                for o = 1 : length(copy_Distri)
                                                    if isequal([k,l,m,n], copy_Distri(o).connections)
                                                        if copy_Distri(o).size < B%还有余量
                                                            row = row + 1;%行增一
                                                            one_hop(row,1) = o;%记录行号
                                                            one_hop(row,2) = B - copy_Distri(o).size;%记录余量
                                                        end
                                                        break;
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
    
                        %判断one_hop中是否有路由足以支撑当前流量
                        %当前流量尺寸（更新）
                        FLAG = 0;%初始化一个标识，以提示是否需要寻找二跳路由
                        sign = 0;%标识在copy_R中更新时要放到原位置还是往后面加
                        current_size = copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{L(sorted_L(i,1)).request{1,j}(2)}(length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{L(sorted_L(i,1)).request{1,j}(2)}));
    
                        if row == 0%说明一跳路由不存在，需找两跳
                            FLAG = 1;
                            sign = 1;%需首先在原位置更新
                        else%说明一跳路由存在，优先选择一跳
                            %对one_hop的第二列进行升序排列，优先选择剩余容量小的
                            sorted_onehop = sortrows(one_hop, 2);
                            for k = 1 : size(one_hop,1)%对每一行进行遍历
                                current_size = current_size - sorted_onehop(k,2);%更新还需要路由的流量大小
                                if current_size <= 0%一跳即可服务，退出循环 
                                     break;
                                end
                            end
    
                            %判断是否需要寻找两跳，同时存储一跳路由
                            if current_size > 0
                                FLAG = 1;%需要寻找两跳,修改标识
                                for l = 1 : k
                                    %Route_Scheme{j,1}(1,l) = copy_Distri(sorted_onehop(l,1)).connections;
                                    %Route_Scheme{j,1}{1,l}(5) = sorted_onehop(l,2);%%%%%%%%还需要更新copy_Distri中的剩余容量！！！！！！
                                    %更新copy_R和copy_Distri
                                    if l == 1
                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(L(sorted_L(i,1)).request{1,j}(2)) = {copy_Distri(sorted_onehop(l,1)).connections};
                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{L(sorted_L(i,1)).request{1,j}(2)}(5) = sorted_onehop(l,2);
                                        copy_Distri(sorted_onehop(l,1)).size = B;%更新剩余容量为0
                                        copy_Distri(sorted_onehop(l,1)).request(length(copy_Distri(sorted_onehop(l,1)).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), L(sorted_L(i,1)).request{1,j}(2)]};%直接加到copy_Distri的request字段最后
                                    else
                                        %加到route的最后
                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)+1) = {copy_Distri(sorted_onehop(l,1)).connections};
                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)}(5) = sorted_onehop(l,2);
                                        copy_Distri(sorted_onehop(l,1)).size = B;%更新剩余容量为0
                                        copy_Distri(sorted_onehop(l,1)).request(length(copy_Distri(sorted_onehop(l,1)).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};
                                    end
                                end
                            elseif current_size == 0%刚好用完
                                for l = 1 : k
                                    %Route_Scheme{j,1}(1,l) = Distri(sorted_onehop(l,1)).connections;
                                    %Route_Scheme{j,1}{1,l}(5) = sorted_onehop(l,2);
                                    %更新copy_R和copy_Distri
                                    if l == 1
                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(L(sorted_L(i,1)).request{1,j}(2)) = {copy_Distri(sorted_onehop(l,1)).connections};
                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{L(sorted_L(i,1)).request{1,j}(2)}(5) = sorted_onehop(l,2);
                                        copy_Distri(sorted_onehop(l,1)).size = B;%更新剩余容量为0
                                        copy_Distri(sorted_onehop(l,1)).request(length(copy_Distri(sorted_onehop(l,1)).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), L(sorted_L(i,1)).request{1,j}(2)]};%直接加到copy_Distri的request字段最后
                                    else
                                        %加到route的最后
                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)+1) = {copy_Distri(sorted_onehop(l,1)).connections};
                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)}(5) = sorted_onehop(l,2);
                                        copy_Distri(sorted_onehop(l,1)).size = B;%更新剩余容量为0
                                        copy_Distri(sorted_onehop(l,1)).request(length(copy_Distri(sorted_onehop(l,1)).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};
                                    end
                                end
                            else
                                if k > 1
                                    for l = 1 : k-1
                                        %Route_Scheme{j,1}(1,l) = Distri(sorted_onehop(l,1)).connections;
                                        %Route_Scheme{j,1}{1,l}(5) = sorted_onehop(l,2);
                                        %更新copy_R和copy_Distri
                                        if l == 1
                                            copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(L(sorted_L(i,1)).request{1,j}(2)) = {copy_Distri(sorted_onehop(l,1)).connections};
                                            copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{L(sorted_L(i,1)).request{1,j}(2)}(5) = sorted_onehop(l,2);
                                            copy_Distri(sorted_onehop(l,1)).size = B;%更新剩余容量为0
                                            copy_Distri(sorted_onehop(l,1)).request(length(copy_Distri(sorted_onehop(l,1)).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), L(sorted_L(i,1)).request{1,j}(2)]};%直接加到copy_Distri的request字段最后
                                        else
                                            %加到route的最后
                                            copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)+1) = {copy_Distri(sorted_onehop(l,1)).connections};
                                            copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)}(5) = sorted_onehop(l,2);
                                            copy_Distri(sorted_onehop(l,1)).size = B;%更新剩余容量为0
                                            copy_Distri(sorted_onehop(l,1)).request(length(copy_Distri(sorted_onehop(l,1)).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};
                                        end
                                    end
    
                                    copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)+1) = {copy_Distri(sorted_onehop(k,1)).connections};
                                    copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)}(5) = sorted_onehop(k,2) + current_size;
                                    copy_Distri(sorted_onehop(k,1)).size = B + current_size;%更新
                                    copy_Distri(sorted_onehop(k,1)).request(length(copy_Distri(sorted_onehop(k,1)).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};
                                else
                                    copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(L(sorted_L(i,1)).request{1,j}(2)) = {copy_Distri(sorted_onehop(1,1)).connections};
                                    copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{L(sorted_L(i,1)).request{1,j}(2)}(5) = sorted_onehop(1,2) + current_size;
                                    copy_Distri(sorted_onehop(1,1)).size = B + current_size;%更新
                                    copy_Distri(sorted_onehop(1,1)).request(length(copy_Distri(sorted_onehop(1,1)).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), L(sorted_L(i,1)).request{1,j}(2)]};%直接加到copy_Distri的request字段最后
                                end
                                %第k行只用了一半
                                %Route_Scheme{j,1}(1,k) = Distri(sorted_onehop(k,1)).connections;
                                %Route_Scheme{j,1}{1,k}(5) = sorted_onehop(k,2) + current_size;
                            end
                        end
    
                        %判断是否需要寻找两跳（多跳）路由
                        if FLAG == 1
                            Pod_array = 1 : Omega;%所有pod序号组成的数组
                            to_remove = [pod_3, pod_4];
                            logical_index = ~ismember(Pod_array, to_remove);
                            mid_pod = Pod_array(logical_index);%可以选做中间节点的全部pod
    
                            for k = 2 : H%找k跳路由
                                %选择(k-1)个数的所有可能组合
                                combinations = nchoosek(mid_pod, k-1);
                                % 生成有顺序的排列
                                permutations = [];
                                for l = 1:size(combinations, 1)
                                    permutation = perms(combinations(l, :));
                                    permutations = [permutations; permutation];
                                end
    
                                %在第一列插入源节点，最后一列插入目的节点
                                Source = pod_3 .* ones(size(permutations,1), 1);
                                Desti = pod_4 .* ones(size(permutations,1), 1);
                                permutations = [Source, permutations(:,1:end)];
                                permutations = [permutations, Desti];
    
                                %初始化一个cell数组，存储每一跳路由
                                Route_ehop = cell(size(permutations,1),k);
                                for ll = 1 : size(permutations,1)
                                    for l = 1 : k
                                        pod_3 = permutations(ll,l);
                                        pod_4 = permutations(ll,l+1);
                                        row = 0;
                                        %依次找第l跳的路由
                                        for m = 1 : T%遍历每个平面
                                            for n = 1 : K%遍历每个OXC
                                                for o = 1 : sum_port - 1
                                                    for p = o + 1 : sum_port
                                                        if M(o,p,n,m) == 1
                                                            pod_1 = port_allocation{m,1}{n,1}(1,o);
                                                            pod_2 = port_allocation{m,1}{n,1}(1,p);
                                                            if (pod_1 == pod_3 && pod_2 == pod_4) || (pod_1 == pod_4 && pod_2 == pod_3)
                                                                %检查当前连接上是否有足够空闲的余量
                                                                for q = 1 : length(copy_Distri)
                                                                    if isequal([m,n,o,p], copy_Distri(q).connections)
                                                                        if copy_Distri(q).size < B%还有余量
                                                                            row = row + 1;%行增一
                                                                            Route_ehop{ll,l}(row,1) = {[m,n,o,p,B-copy_Distri(q).size]};
                                                                        end
                                                                        break;
                                                                    end
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
    
                                while current_size > 0 
                                    row = 0;
                                    Route_avail = {};%初始化一个cell数组，存储所有可行路由
                                    for ll = 1 : size(permutations,1)
                                        tag = 0;%标识当前行是否有路由
                                        Record = cell(1,k);%记录可行路由
                                        for l = 1 : k
                                            mv = 2*B;%中间变量
                                            if length(Route_ehop{ll,l}) ~= 0
                                                for m = 1 : length(Route_ehop{ll,l})
                                                    if Route_ehop{ll,l}{m,1}(5) < mv
                                                        mv = Route_ehop{ll,l}{m,1}(5);%找最小者
                                                        mv_r = m;
                                                    end
                                                end
            
                                                Record(1,l) = Route_ehop{ll,l}(mv_r,1);
                                            else
                                                tag = 1;%修改标识，当前行没有可行路由
                                                break;
                                            end
                                        end
        
                                        if tag == 0
                                            mv = 2*B;%中间变量
                                            for l = 1 : k
                                                if Record{1,l}(5) < mv
                                                    mv = Record{1,l}(5);%找最小者
                                                end
                                            end
        
                                            row = row + 1;%行增一
                                            for l = 1 : k
                                                Route_avail(row,l) = Record(1,l);
                                                Route_avail{row,l}(5) = [];%删除第五个元素-剩余容量
                                            end
        
                                            Route_avail{row,k+1}(1) = mv;%第k+1个位置存储当前路由可用容量
                                        end
                                    end
        
                                    %在Route_avail中挑选一个最小容量的路由
                                    if size(Route_avail,1) == 0%表明没有可行路由
                                        break;%直接换到下一个k
                                    else
                                        mv = 2*B;
                                        for l = 1 : size(Route_avail,1)
                                            if Route_avail{l,k+1}(1) < mv
                                                mv = Route_avail{l,k+1}(1);%找最小者
                                                mv_r = l;%记录行号
                                            end
                                        end
        
                                        path = [];
                                        for l = 1 : k
                                            path = [path, Route_avail{mv_r,l}];%将路由组合起来
                                        end
        
                                        if current_size >= mv
                                            path(1, length(path)+1) = mv;%将流量加到最后
                                            current_size = current_size - mv;%更新待服务流量大小
                                        else
                                            path(1, length(path)+1) = current_size;
                                            current_size = 0;
                                        end
        
                                        %更新copy_Distri和copy_R
                                        %判断sign的值，如果等于1首先在原位置更新
                                        if sign == 1
                                            copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(L(sorted_L(i,1)).request{1,j}(2)) = {path};
                                            for l = 1 : k
                                                for m = 1 : length(copy_Distri)
                                                    if isequal(Route_avail{mv_r,l}, copy_Distri(m).connections)
                                                        copy_Distri(m).size = copy_Distri(m).size + path(1,length(path));%更新
                                                        copy_Distri(m).request(length(copy_Distri(m).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), L(sorted_L(i,1)).request{1,j}(2)]};%直接加到copy_Distri的request字段最后
                                                        break;
                                                    end
                                                end
                                            end
                                            sign = 0;%修改标识
                                        else
                                            copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)+1) = {path};
                                            for l = 1 : k
                                                for m = 1 : length(copy_Distri)
                                                    if isequal(Route_avail{mv_r,l}, copy_Distri(m).connections)
                                                        copy_Distri(m).size = copy_Distri(m).size + path(1,length(path));%更新
                                                        copy_Distri(m).request(length(copy_Distri(m).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};
                                                        break;
                                                    end
                                                end
                                            end
                                        end
        
                                        %更新Route_ehop
                                        if current_size > 0
                                            for ll = 1 : size(Route_ehop,1)
                                                for l = 1 : k
                                                    if length(Route_ehop{ll,l}) ~= 0
                                                        m = 1;
                                                        while m <= length(Route_ehop{ll,l})
                                                            midd = Route_ehop{ll,l}(m,1);
                                                            midd{1,1}(5) = [];%删除第五个元素-剩余容量
                                                            for n = 1 : k
                                                                if isequal(midd, Route_avail(mv_r,n))
                                                                    %更新可用容量
                                                                    if Route_ehop{ll,l}{m,1}(5) - path(1,length(path)) > 0
                                                                        Route_ehop{ll,l}{m,1}(5) = Route_ehop{ll,l}{m,1}(5) - path(1,length(path));
                                                                        m = m + 1; 
                                                                    else%无余量，直接删除
                                                                        Route_ehop{ll,l}(m) = [];
                                                                    end
            
                                                                    break;
                                                                else
                                                                    if n == k
                                                                        m = m + 1;
                                                                    end
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
    
                                if current_size <= 0
                                    break;
                                end
                            end
    
                        end
    
                        if current_size > 0%说明没服务完，该条连接实际不可拆
                            flag = 1;
                            break;
                        end
                    end
    
                    if flag == 0
                        %表明可拆
                        R = copy_R;
                        Distri = copy_Distri;
                        %在port_allocation第二行中标记该条连接的端口空闲
                        port_allocation{L(sorted_L(i,1)).connections(1),1}{L(sorted_L(i,1)).connections(2),1}(2,L(sorted_L(i,1)).connections(3)) = 0;
                        port_allocation{L(sorted_L(i,1)).connections(1),1}{L(sorted_L(i,1)).connections(2),1}(2,L(sorted_L(i,1)).connections(4)) = 0;
                    else
                        %不可拆，把该连接添加回来
                        M(L(sorted_L(i,1)).connections(3),L(sorted_L(i,1)).connections(4),L(sorted_L(i,1)).connections(2),L(sorted_L(i,1)).connections(1)) = 1;
                        M(L(sorted_L(i,1)).connections(4),L(sorted_L(i,1)).connections(3),L(sorted_L(i,1)).connections(2),L(sorted_L(i,1)).connections(1)) = 1;
                    end
                else%该连接上无流量经过，可以直接拆除
                    Distri = copy_Distri;
                    %在port_allocation第二行中标记该条连接的端口空闲
                    port_allocation{L(sorted_L(i,1)).connections(1),1}{L(sorted_L(i,1)).connections(2),1}(2,L(sorted_L(i,1)).connections(3)) = 0;
                    port_allocation{L(sorted_L(i,1)).connections(1),1}{L(sorted_L(i,1)).connections(2),1}(2,L(sorted_L(i,1)).connections(4)) = 0;
                end
            else
                break;%当前阶段拆线结束
            end
        end
    
        %增线，在M和E之间，寻找M=0，E=1的位置，需更新port_allocation
        for i = 1 : T
            for j = 1 : K
                for k = 1 : sum_port-1
                    for l = k+1 : sum_port
                        if M(k,l,j,i)==0 && E(k,l,j,i)==1
                            %检验端口是否空闲
                            if port_allocation{i,1}{j,1}(2,k) == 0 && port_allocation{i,1}{j,1}(2,l) == 0
                                %连接起来，在Distri中更新
                                Distri(length(Distri)+1).connections = [i,j,k,l];
                                Distri(length(Distri)).size = 0;
                                port_allocation{i,1}{j,1}(2,k) = 1;
                                port_allocation{i,1}{j,1}(2,l) = 1;
                                M(k,l,j,i) = 1;
                                M(l,k,j,i) = 1;
                            end
                        end
                    end
                end
            end
        end
    
        if M_last == M %表明无法平滑重构
            stages = -1;
            disp('Reconfiguration failed.');
            break;%跳出循环
        else
            stages = stages + 1;%阶段增1
        end
    end











