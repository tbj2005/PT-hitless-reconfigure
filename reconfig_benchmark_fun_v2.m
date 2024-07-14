%优化运行时间，将路由计算转移到逻辑拓扑中去做，每次切换限制在一个平面内，路由优先选择剩余容量大的
%每一个阶段Distri都会发生改变，其记录了全网所有的连接，通过该变量可以查看oxc的配置改变，以及每条连接上有哪些流经过
%M是每个中间阶段的物理拓扑
%R中记录了每条流的源pod、目的pod以及流路由情况

function stages = reconfig_benchmark_fun_v2(S,E,R,inputs,port_allocation)

Omega = inputs.nodes_num; %% podsnum
T = inputs.groupnum; %% vectornum
sum_port = inputs.oxcports; %% ports pair that an OXC provided
K = inputs.oxcnum_agroup; %% oxc nums in a vector
B = inputs.connection_cap;
eta_th = inputs.resi_cap;%全网剩余容量阈值
request = inputs.request;%网络中的流

%初始化中间拓扑M = S，平滑重构切换阶段数stages = 0;
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

Logical_Matrix = zeros(Omega,Omega);%初始化逻辑拓扑矩阵
Logical_Phy = cell(Omega,Omega);%物理和逻辑拓扑的映射
%由物理连接关系计算逻辑拓扑矩阵，矩阵中的元素值表示两个pod之间的总可用带宽
for i = 1 : length(Distri)
    k = Distri(i).connections(1);%平面
    l = Distri(i).connections(2);%第几个oxc
    s = Distri(i).connections(3);%源端口（小）
    d = Distri(i).connections(4);%目的端口（大）
    pod_s = port_allocation{k,1}{l,1}(1,s);%源pod
    pod_d = port_allocation{k,1}{l,1}(1,d);%目的pod

    Logical_Matrix(pod_s,pod_d) = Logical_Matrix(pod_s,pod_d) + (B - Distri(i).size);%只填充了上三角矩阵
    % Logical_Matrix(pod_d,pod_s) = Logical_Matrix(pod_s,pod_d);%对称
    Logical_Phy{pod_s,pod_d}(1, size(Logical_Phy{pod_s,pod_d},2)+1) = {Distri(i).connections};%只填充了上三角矩阵
    Logical_Phy{pod_s,pod_d}{2, size(Logical_Phy{pod_s,pod_d},2)} = B - Distri(i).size;%填充可用容量
end

%分平面去统计待拆线待增线有多少条
STA = zeros(2,T);
for i = 1 : T
    for j = 1 : K
        for k = 1 : sum_port-1
            for l = k+1 : sum_port
                if M(k,l,j,i)==1 && E(k,l,j,i)==0
                    STA(1,i) = STA(1,i) + 1;%拆线
                end

                if M(k,l,j,i)==0 && E(k,l,j,i)==1
                    STA(2,i) = STA(2,i) + 1;%增线
                end
            end
        end
    end
end

for i = 1 : T
    if STA(1,i) == 0 && STA(2,i) ~= 0%该平面只需要增线
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

                            pod_s = port_allocation{i,1}{j,1}(1,k);%源pod
                            pod_d = port_allocation{i,1}{j,1}(1,l);%目的pod
                        
                            Logical_Matrix(pod_s,pod_d) = Logical_Matrix(pod_s,pod_d) + B;%只填充了上三角矩阵
                            Logical_Phy{pod_s,pod_d}(1, size(Logical_Phy{pod_s,pod_d},2)+1) = {[i,j,k,l]};%只填充了上三角矩阵
                            Logical_Phy{pod_s,pod_d}{2, size(Logical_Phy{pod_s,pod_d},2)} = B;%填充可用容量
                        else
                            stages = -1;
                            disp('Reconfiguration failed.');
                            break;%跳出循环
                        end
                    end
                end

                if stages == -1
                    break;
                end
            end
            
            if stages == -1
                break;
            end
        end

        if stages == -1
            break;
        else
            STA(2,i) = 0;%更新待增线为0
            stages = stages + 1;
        end
    end
end

if stages ~= -1

    %剩下要处理的全部都是需要拆线的
    chai = [];%存储当前需要拆线的平面
    chai_col = 0;%列数
    for i = 1 : T
        if STA(1,i) ~= 0%该平面需要拆线
            chai_col = chai_col + 1;
            chai(1, chai_col) = i;
        end
    end

    while size(chai,2) ~= 0%代表还有待拆的平面

%         if size(chai,2) == 0
%             break;%重构成功结束
%         else
        eta_den = length(Distri);%记录上一个阶段拓扑中的连接数
        for i_p = 1 : size(chai,2)%确定当前要重构的平面
            i = chai(1, i_p);%替换i = chai(1, i_p)，i指示在STA中的列号，也即当前操作的一个分平面
            new_flag = 0;%标识当前平面是否真的能拆线/增线
            clear L;
            L = struct('connections',{},'request',{},'size',{});%初始化结构体
            row = 0;%指示行数
            for j = 1 : K %找到要拆除的连接，比较M和E，找M=1，E=0的位置
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

            L_1 = zeros(length(L),2);%初始化二维矩阵
            for i = 1 : length(L)
                L_1(i,1) = i;
                L_1(i,2) = L(i).size;
            end

            sorted_L = sortrows(L_1, 2);%对L_1第二列进行升序排列

            for i = 1 : length(L)%%%%遍历每一条待拆除的连接
%                 if i == 1228 && chai(1,i_p) == 2
%                     disp('debug');%%%%%%%%%%%%%%%%%%%%%%%%%debug使用
%                 end

                eta = (length(Distri)-1)/eta_den;
                if eta >= eta_th%判断是否不小于阈值
                    copy_R = R;%复制一份(会对copy_R做更新，但是由于目前还不确定是否能拆除当前连接，所以不能对R直接进行操作)
                    copy_Distri = Distri;%复制一份，同上
                    copy_LM = Logical_Matrix;%复制一份，同上
                    copy_LP = Logical_Phy;%复制一份，同上
                    flag = 0;%标识当前连接实际是否能被拆除（等于1表示不可拆）
                    
                    k = L(sorted_L(i,1)).connections(1);%平面
                    l = L(sorted_L(i,1)).connections(2);%第几个oxc
                    s = L(sorted_L(i,1)).connections(3);%源端口（小）
                    d = L(sorted_L(i,1)).connections(4);%目的端口（大）
                    pod_s = port_allocation{k,1}{l,1}(1,s);%源pod
                    pod_d = port_allocation{k,1}{l,1}(1,d);%目的pod

                    %从M中删除当前连接
                    M(s,d,l,k) = 0;
                    M(d,s,l,k) = 0;
                    
                    %更新copy_Distri
                    for j = 1 : length(copy_Distri)
                        if isequal(L(sorted_L(i,1)).connections, copy_Distri(j).connections)
                            %把信息复制给L和sorted_L
                            L(sorted_L(i,1)).request = copy_Distri(j).request;
                            L(sorted_L(i,1)).size = copy_Distri(j).size;
                            sorted_L(i,2) = copy_Distri(j).size;
                            %删除该行
                            copy_Distri(j)=[];
                            break;
                        end
                    end
                        
                    %更新copy_LM
                    copy_LM(pod_s, pod_d) = copy_LM(pod_s, pod_d) - (B - L(sorted_L(i,1)).size);

                    %还需要更新上面的流量分布（因为有些流量可能有多跳）
                    if sorted_L(i,2) ~= 0
                        for j = 1 : length(L(sorted_L(i,1)).request)%遍历当前要拆除的连接上的每一条流
                            %检查该流原路由是几跳
                            Hops = (length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{L(sorted_L(i,1)).request{1,j}(2)})-1)/4;
                            Route = copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(L(sorted_L(i,1)).request{1,j}(2));
                            f_size = Route{1}(length(Route{1}));%存储该流流量大小
                            Route{1}(length(Route{1})) = [];%删除最后一位流量
%                             route_seq = L(sorted_L(i,1)).request{1,j};%路由编号
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

                                        %更新待拆除连接上的流量占用情况（因为有可能有两跳的路由都在待拆除的数组中！！！！！！），有可能拆不掉，还需要复原
                                        %初始化一个cell数组，存储连接上的流量变动
%                                         L_Var = {};%第一行记录在sorted_L中的行号（暂时不要），第二行记录流量有变动的连接，第三行记录流量路由编号【m,n】，第四行记录流量变动的大小
                                       
%                                         for l = 1 : length(sorted_L)
%                                             if isequal(mid, L(sorted_L(l,1)).connections)
%                                                 %sorted_L(l,2) = sorted_L(l,2) - f_size;%更新流量占用，后续会重新排序
%                                                 for m = 1 : length(L(sorted_L(l,1)).request)
%                                                     if isequal(L(sorted_L(l,1)).request{1,m}, route_seq)
%                                                         L_Var{1,size(L_Var,2)+1} = l;%记录行号
%                                                         L_Var(2,size(L_Var,2)) = {mid};%记录连接
%                                                         L_Var(3,size(L_Var,2)) = {route_seq};%记录行号
%                                                         L_Var{4,size(L_Var,2)} = - f_size;%记录流量变动大小，负数代表需要减去
% 
%                                                         %L(sorted_L(l,1)).request(m) = [];%删除
%                                                         %L(sorted_L(l,1)).size = L(sorted_L(l,1)).size - f_size;%更新链路上的流量占用
%                                                         break;
%                                                     end
%                                                 end
%                                                 break;
%                                             end
%                                         end
                                                        
                                        pod_s1 = port_allocation{mid(1),1}{mid(2),1}(1,mid(3));%源pod
                                        pod_d1 = port_allocation{mid(1),1}{mid(2),1}(1,mid(4));%目的pod
                                        copy_LM(pod_s1, pod_d1) = copy_LM(pod_s1, pod_d1) + f_size;
                                        for l = 1 : size(copy_LP{pod_s1, pod_d1}, 2)
                                            if isequal(copy_LP{pod_s1, pod_d1}{1,l}, mid)
                                                copy_LP{pod_s1, pod_d1}{2,l} = copy_LP{pod_s1, pod_d1}{2,l} + f_size;%可用容量更新
                                                break;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
        
                    %更新copy_LP
                    for j = 1 : size(copy_LP{pod_s, pod_d},2)
                        if isequal(L(sorted_L(i,1)).connections, copy_LP{pod_s, pod_d}{1,j})
                            copy_LP{pod_s, pod_d}(:,j) = [];%删除该条连接
                            break;
                        end
                    end

                    if sorted_L(i,2) ~= 0%说明该条连接上有流量经过，检查实际是否可以拆除
        
                        LM_1 = inf(Omega);%矩阵
                        LM_1(1:Omega+1:end) = 0; % 将对角线上的元素设为0
                        for k = 1 : Omega-1
                            for l = k+1 : Omega
                                if copy_LM(k,l) ~= 0
                                    LM_1(k,l) = 1;
                                    LM_1(l,k) = 1;%填充成对称阵
                                end
                            end
                        end

                        for j = 1 : length(L(sorted_L(i,1)).request)%遍历当前要拆除的连接上的每一条流
                            pod_3 = copy_R(L(sorted_L(i,1)).request{1,j}(1)).source;
                            pod_4 = copy_R(L(sorted_L(i,1)).request{1,j}(1)).destination;
                            current_size = copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{L(sorted_L(i,1)).request{1,j}(2)}(length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{L(sorted_L(i,1)).request{1,j}(2)}));

                            if pod_3 > pod_4%需要做一下交换
                                mid_pod = pod_3;
                                pod_3 = pod_4;
                                pod_4 = mid_pod;
                            end

                            FLAG = 0;%指示为请求重新路由的第一个分请求
                            %在LM_1中找最短路由
                            while current_size > 0
%                                 tic
                                [path, dist] = dijkstra(LM_1, pod_3, pod_4);
%                                 time = toc;
%                                 disp(time);

                                if length(path) ~= 0 && dist <= 2%路由存在且跳数不超过2
                                    if dist == 1%只有一跳
                                        capa_1 = copy_LM(pod_3, pod_4);%可用带宽
                                        if current_size > capa_1%说明全部用完还不够
                                            %使用更新
                                            for k = 1 : size(copy_LP{pod_3, pod_4},2)
                                                if copy_LP{pod_3, pod_4}{2,k} ~= 0
                                                    FLAG = FLAG + 1;%当FLAG = 1时表示第一次分割请求，放入copy_R的原始位置
                                                    for l = 1 : length(copy_Distri)
                                                        if isequal(copy_LP{pod_3, pod_4}{1,k}, copy_Distri(l).connections)
                                                            %更新copy_Distri
                                                            if FLAG == 1
                                                                copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(L(sorted_L(i,1)).request{1,j}(2)) = {copy_Distri(l).connections};
                                                                copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{L(sorted_L(i,1)).request{1,j}(2)}(5) = copy_LP{pod_3, pod_4}{2,k};
                                                                copy_Distri(l).size = B;%更新剩余容量为0
                                                                copy_Distri(l).request(length(copy_Distri(l).request) + 1) = L(sorted_L(i,1)).request(1,j);
                                                               
%                                                                 L_Var{1,size(L_Var,2)+1} = 0;%不确定新路由是否在待拆连接之中
%                                                                 L_Var(2,size(L_Var,2)) = {copy_Distri(l).connections};%记录连接
%                                                                 L_Var(3,size(L_Var,2)) = L(sorted_L(i,1)).request(1,j);%记录路由编号
%                                                                 L_Var{4,size(L_Var,2)} = copy_LP{pod_3, pod_4}{2,k};%记录流量变动大小

                                                                copy_LP{pod_3, pod_4}{2,k} = 0;%更新剩余容量为0
                                                            else
                                                                copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)+1) = {copy_Distri(l).connections};
                                                                copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)}(5) = copy_LP{pod_3, pod_4}{2,k};
                                                                copy_Distri(l).size = B;%更新剩余容量为0
                                                                copy_Distri(l).request(length(copy_Distri(l).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};
                                                                
%                                                                 L_Var{1,size(L_Var,2)+1} = 0;%不确定新路由是否在待拆连接之中
%                                                                 L_Var(2,size(L_Var,2)) = {copy_Distri(l).connections};%记录连接
%                                                                 L_Var(3,size(L_Var,2)) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};%记录路由编号
%                                                                 L_Var{4,size(L_Var,2)} = copy_LP{pod_3, pod_4}{2,k};%记录流量变动大小
                                                                
                                                                copy_LP{pod_3, pod_4}{2,k} = 0;%更新剩余容量为0
                                                            end
                                                            break;
                                                        end
                                                    end
                                                end
                                            end
    
                                            copy_LM(pod_3, pod_4) = 0;
                                            LM_1(pod_3, pod_4) = inf;%%%%LM_1是对称阵
                                            LM_1(pod_4, pod_3) = inf;
                                            current_size = current_size - capa_1;%更新待服务流量大小
                                        else%足够服务剩余请求大小（有可能恰好用完、有可能未用完）
                                            %使用更新
                                            copy_LM(pod_3, pod_4) = copy_LM(pod_3, pod_4) - current_size;
                                            if copy_LM(pod_3, pod_4) == 0%表示恰好用完
                                                LM_1(pod_3, pod_4) = inf;%%%%LM_1是对称阵
                                                LM_1(pod_4, pod_3) = inf;
                                            end
                                            copy_LP{pod_3,pod_4} = sortrows(copy_LP{pod_3,pod_4}', -2)';%对pod_3、pod_4之间的连接按照可用容量升序排列%%%修改，改为降序排列，先用大的，减少流量分割
                                            for k = 1 : size(copy_LP{pod_3, pod_4},2)
                                                if current_size > 0
                                                    if copy_LP{pod_3, pod_4}{2,k} ~= 0
                                                        FLAG = FLAG + 1;%当FLAG = 1时表示第一次分割请求，放入copy_R的原始位置
                                                        if current_size > copy_LP{pod_3, pod_4}{2,k}
                                                            current_size = current_size - copy_LP{pod_3, pod_4}{2,k};%更新待服务流量大小
                                                            for l = 1 : length(copy_Distri)
                                                                if isequal(copy_LP{pod_3, pod_4}{1,k}, copy_Distri(l).connections)
                                                                    %更新copy_Distri
                                                                    if FLAG == 1
                                                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(L(sorted_L(i,1)).request{1,j}(2)) = {copy_Distri(l).connections};
                                                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{L(sorted_L(i,1)).request{1,j}(2)}(5) = copy_LP{pod_3, pod_4}{2,k};
                                                                        copy_Distri(l).size = B;%更新剩余容量为0
                                                                        copy_Distri(l).request(length(copy_Distri(l).request) + 1) = L(sorted_L(i,1)).request(1,j);
                                                                        
%                                                                         L_Var{1,size(L_Var,2)+1} = 0;%不确定新路由是否在待拆连接之中
%                                                                         L_Var(2,size(L_Var,2)) = {copy_Distri(l).connections};%记录连接
%                                                                         L_Var(3,size(L_Var,2)) = L(sorted_L(i,1)).request(1,j);%记录路由编号
%                                                                         L_Var{4,size(L_Var,2)} = copy_LP{pod_3, pod_4}{2,k};%记录流量变动大小
                                                                        
                                                                        copy_LP{pod_3, pod_4}{2,k} = 0;%更新剩余容量为0
                                                                    else
                                                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)+1) = {copy_Distri(l).connections};
                                                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)}(5) = copy_LP{pod_3, pod_4}{2,k};
                                                                        copy_Distri(l).size = B;%更新剩余容量为0
                                                                        copy_Distri(l).request(length(copy_Distri(l).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};
                                                                        
%                                                                         L_Var{1,size(L_Var,2)+1} = 0;%不确定新路由是否在待拆连接之中
%                                                                         L_Var(2,size(L_Var,2)) = {copy_Distri(l).connections};%记录连接
%                                                                         L_Var(3,size(L_Var,2)) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};%记录路由编号
%                                                                         L_Var{4,size(L_Var,2)} = copy_LP{pod_3, pod_4}{2,k};%记录流量变动大小
                                                                        
                                                                        copy_LP{pod_3, pod_4}{2,k} = 0;%更新剩余容量为0
                                                                    end
                                                                    break;
                                                                end
                                                            end                                        
%                                                             current_size = current_size - copy_LP{pod_3, pod_4}{2,k};%更新待服务流量大小%%%%%%%%%%%应该在前面更新
                                                        else%当前连接即可以服务完
                                                            for l = 1 : length(copy_Distri)
                                                                if isequal(copy_LP{pod_3, pod_4}{1,k}, copy_Distri(l).connections)
                                                                    %更新copy_Distri
                                                                    if FLAG == 1
                                                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(L(sorted_L(i,1)).request{1,j}(2)) = {copy_Distri(l).connections};
                                                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{L(sorted_L(i,1)).request{1,j}(2)}(5) = current_size;
                                                                        copy_Distri(l).size = copy_Distri(l).size + current_size;%更新已使用容量
                                                                        copy_Distri(l).request(length(copy_Distri(l).request) + 1) = L(sorted_L(i,1)).request(1,j);
                                                                        copy_LP{pod_3, pod_4}{2,k} = copy_LP{pod_3, pod_4}{2,k} - current_size;%更新剩余容量

%                                                                         L_Var{1,size(L_Var,2)+1} = 0;%不确定新路由是否在待拆连接之中
%                                                                         L_Var(2,size(L_Var,2)) = {copy_Distri(l).connections};%记录连接
%                                                                         L_Var(3,size(L_Var,2)) = L(sorted_L(i,1)).request(1,j);%记录路由编号
%                                                                         L_Var{4,size(L_Var,2)} = current_size;%记录流量变动大小
                                                                    else
                                                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)+1) = {copy_Distri(l).connections};
                                                                        copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)}(5) = current_size;
                                                                        copy_Distri(l).size = copy_Distri(l).size + current_size;%更新已使用容量
                                                                        copy_Distri(l).request(length(copy_Distri(l).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};
                                                                        copy_LP{pod_3, pod_4}{2,k} = copy_LP{pod_3, pod_4}{2,k} - current_size;%更新剩余容量

%                                                                         L_Var{1,size(L_Var,2)+1} = 0;%不确定新路由是否在待拆连接之中
%                                                                         L_Var(2,size(L_Var,2)) = {copy_Distri(l).connections};%记录连接
%                                                                         L_Var(3,size(L_Var,2)) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};%记录路由编号
%                                                                         L_Var{4,size(L_Var,2)} = current_size;%记录流量变动大小
                                                                    end
                                                                    break;
                                                                end
                                                            end
                                                            current_size = 0;
                                                        end
                                                    end
                                                else
                                                    break;
                                                end
                                            end
                                        end
    
                                    else%有两跳
                                        mid_pod = path(2);
                                        if pod_3 < mid_pod && mid_pod < pod_4
                                            % capa_1 = min(copy_LM(pod_3, mid_pod), copy_LM(mid_pod, pod_4));
                                            pod_fir = pod_3;
                                            pod_sec = mid_pod;
                                            pod_thi = mid_pod;
                                            pod_fou = pod_4;
                                        elseif pod_4 < mid_pod
                                            % capa_1 = min(copy_LM(pod_3, mid_pod), copy_LM(pod_4, mid_pod));
                                            pod_fir = pod_3;
                                            pod_sec = mid_pod;
                                            pod_thi = pod_4;
                                            pod_fou = mid_pod;
                                        else
                                            % capa_1 = min(copy_LM(mid_pod, pod_3), copy_LM(mid_pod, pod_4));
                                            pod_fir = mid_pod;
                                            pod_sec = pod_3;
                                            pod_thi = mid_pod;
                                            pod_fou = pod_4;
                                        end
    
                                        copy_LP{pod_fir,pod_sec} = sortrows(copy_LP{pod_fir,pod_sec}', -2)';%对第一跳之间的连接按照可用容量升序排列%%%%%%修改为降序排列
                                        copy_LP{pod_thi,pod_fou} = sortrows(copy_LP{pod_thi,pod_fou}', -2)';%对第二跳之间的连接按照可用容量升序排列%%%%%%修改为降序排列
                                        memory_cs = current_size;%将此时的流量大小记录下来
                                        k = 1;
                                        k_k = 1;
%                                             %使用更新%%%%%%%%修改，删除
%                                             for k = 1 : size(copy_LP{pod_fir, pod_sec},2)%遍历第一跳
%                                                 if copy_LP{pod_fir, pod_sec}{2,k} ~= 0
%                                                     break;
%                                                 end
%                                             end
%         
%                                             for k_k = 1 : size(copy_LP{pod_thi, pod_fou},2)%遍历第二跳
%                                                 if copy_LP{pod_thi, pod_fou}{2,k_k} ~= 0
%                                                     break;
%                                                 end
%                                             end
    
                                        while current_size > 0
                                            if copy_LP{pod_fir, pod_sec}{2,k} ~= 0 && copy_LP{pod_thi, pod_fou}{2,k_k} ~= 0%%%%%%%%%两跳均有剩余容量
                                                FLAG = FLAG + 1;%当FLAG = 1时表示第一次分割请求，放入copy_R的原始位置
                                                Route = [copy_LP{pod_fir, pod_sec}{1,k}, copy_LP{pod_thi, pod_fou}{1,k_k}];%将路由组合起来
                                                capa_1 = min(copy_LP{pod_fir, pod_sec}{2,k}, copy_LP{pod_thi, pod_fou}{2,k_k});%此路由的可用容量
                                                if current_size > capa_1%代表要用完
                                                    for l = 1 : length(copy_Distri)
                                                        if isequal(copy_LP{pod_fir, pod_sec}{1,k}, copy_Distri(l).connections)
                                                            %更新copy_Distri
                                                            if FLAG == 1
                                                                copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(L(sorted_L(i,1)).request{1,j}(2)) = {Route};
                                                                copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{L(sorted_L(i,1)).request{1,j}(2)}(9) = capa_1;
                                                                copy_Distri(l).size = copy_Distri(l).size + capa_1;%更新占用容量
                                                                copy_Distri(l).request(length(copy_Distri(l).request) + 1) = L(sorted_L(i,1)).request(1,j);
                                                                copy_LP{pod_fir, pod_sec}{2,k} = copy_LP{pod_fir, pod_sec}{2,k} - capa_1;%更新剩余容量

%                                                                 L_Var{1,size(L_Var,2)+1} = 0;%不确定新路由是否在待拆连接之中
%                                                                 L_Var(2,size(L_Var,2)) = {copy_Distri(l).connections};%记录连接
%                                                                 L_Var(3,size(L_Var,2)) = L(sorted_L(i,1)).request(1,j);%记录路由编号
%                                                                 L_Var{4,size(L_Var,2)} = capa_1;%记录流量变动大小
                                                            else
                                                                copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)+1) = {Route};
                                                                copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)}(9) = capa_1;
                                                                copy_Distri(l).size = copy_Distri(l).size + capa_1;%更新占用容量
                                                                copy_Distri(l).request(length(copy_Distri(l).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};
                                                                copy_LP{pod_fir, pod_sec}{2,k} = copy_LP{pod_fir, pod_sec}{2,k} - capa_1;%更新剩余容量

%                                                                 L_Var{1,size(L_Var,2)+1} = 0;%不确定新路由是否在待拆连接之中
%                                                                 L_Var(2,size(L_Var,2)) = {copy_Distri(l).connections};%记录连接
%                                                                 L_Var(3,size(L_Var,2)) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};%记录路由编号
%                                                                 L_Var{4,size(L_Var,2)} = capa_1;%记录流量变动大小
                                                            end
                                                            break;
                                                        end
                                                    end
        
                                                    for l = 1 : length(copy_Distri)
                                                        if isequal(copy_LP{pod_thi, pod_fou}{1,k_k}, copy_Distri(l).connections)
                                                            %更新copy_Distri
                                                            if FLAG == 1
                                                                copy_Distri(l).size = copy_Distri(l).size + capa_1;%更新占用容量
                                                                copy_Distri(l).request(length(copy_Distri(l).request) + 1) = L(sorted_L(i,1)).request(1,j);
                                                                copy_LP{pod_thi, pod_fou}{2,k_k} = copy_LP{pod_thi, pod_fou}{2,k_k} - capa_1;%更新剩余容量

%                                                                 L_Var{1,size(L_Var,2)+1} = 0;%不确定新路由是否在待拆连接之中
%                                                                 L_Var(2,size(L_Var,2)) = {copy_Distri(l).connections};%记录连接
%                                                                 L_Var(3,size(L_Var,2)) = L(sorted_L(i,1)).request(1,j);%记录路由编号
%                                                                 L_Var{4,size(L_Var,2)} = capa_1;%记录流量变动大小
                                                            else
                                                                copy_Distri(l).size = copy_Distri(l).size + capa_1;%更新占用容量
                                                                copy_Distri(l).request(length(copy_Distri(l).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};
                                                                copy_LP{pod_thi, pod_fou}{2,k_k} = copy_LP{pod_thi, pod_fou}{2,k_k} - capa_1;%更新剩余容量

%                                                                 L_Var{1,size(L_Var,2)+1} = 0;%不确定新路由是否在待拆连接之中
%                                                                 L_Var(2,size(L_Var,2)) = {copy_Distri(l).connections};%记录连接
%                                                                 L_Var(3,size(L_Var,2)) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};%记录路由编号
%                                                                 L_Var{4,size(L_Var,2)} = capa_1;%记录流量变动大小
                                                            end
                                                            break;
                                                        end
                                                    end
                                                    
                                                    current_size = current_size - capa_1;%更新待服务流量大小
                                                else%足够服务剩余请求大小（有可能恰好用完、有可能未用完）
                                                    %使用更新                                       
                                                    for l = 1 : length(copy_Distri)
                                                        if isequal(copy_LP{pod_fir, pod_sec}{1,k}, copy_Distri(l).connections)
                                                            %更新copy_Distri
                                                            if FLAG == 1
                                                                copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(L(sorted_L(i,1)).request{1,j}(2)) = {Route};
                                                                copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{L(sorted_L(i,1)).request{1,j}(2)}(9) = current_size;
                                                                copy_Distri(l).size = copy_Distri(l).size + current_size;%更新占用容量
                                                                copy_Distri(l).request(length(copy_Distri(l).request) + 1) = L(sorted_L(i,1)).request(1,j);
                                                                copy_LP{pod_fir, pod_sec}{2,k} = copy_LP{pod_fir, pod_sec}{2,k} - current_size;%更新剩余容量

%                                                                 L_Var{1,size(L_Var,2)+1} = 0;%不确定新路由是否在待拆连接之中
%                                                                 L_Var(2,size(L_Var,2)) = {copy_Distri(l).connections};%记录连接
%                                                                 L_Var(3,size(L_Var,2)) = L(sorted_L(i,1)).request(1,j);%记录路由编号
%                                                                 L_Var{4,size(L_Var,2)} = current_size;%记录流量变动大小
                                                            else
                                                                copy_R(L(sorted_L(i,1)).request{1,j}(1)).route(length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)+1) = {Route};
                                                                copy_R(L(sorted_L(i,1)).request{1,j}(1)).route{length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)}(9) = current_size;
                                                                copy_Distri(l).size = copy_Distri(l).size + current_size;%更新占用容量
                                                                copy_Distri(l).request(length(copy_Distri(l).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};
                                                                copy_LP{pod_fir, pod_sec}{2,k} = copy_LP{pod_fir, pod_sec}{2,k} - current_size;%更新剩余容量

%                                                                 L_Var{1,size(L_Var,2)+1} = 0;%不确定新路由是否在待拆连接之中
%                                                                 L_Var(2,size(L_Var,2)) = {copy_Distri(l).connections};%记录连接
%                                                                 L_Var(3,size(L_Var,2)) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};%记录路由编号
%                                                                 L_Var{4,size(L_Var,2)} = current_size;%记录流量变动大小
                                                            end
                                                            break;
                                                        end
                                                    end
        
                                                    for l = 1 : length(copy_Distri)
                                                        if isequal(copy_LP{pod_thi, pod_fou}{1,k_k}, copy_Distri(l).connections)
                                                            %更新copy_Distri
                                                            if FLAG == 1
                                                                copy_Distri(l).size = copy_Distri(l).size + current_size;%更新占用容量
                                                                copy_Distri(l).request(length(copy_Distri(l).request) + 1) = L(sorted_L(i,1)).request(1,j);
                                                                copy_LP{pod_thi, pod_fou}{2,k_k} = copy_LP{pod_thi, pod_fou}{2,k_k} - current_size;%更新剩余容量

%                                                                 L_Var{1,size(L_Var,2)+1} = 0;%不确定新路由是否在待拆连接之中
%                                                                 L_Var(2,size(L_Var,2)) = {copy_Distri(l).connections};%记录连接
%                                                                 L_Var(3,size(L_Var,2)) = L(sorted_L(i,1)).request(1,j);%记录路由编号
%                                                                 L_Var{4,size(L_Var,2)} = current_size;%记录流量变动大小
                                                            else
                                                                copy_Distri(l).size = copy_Distri(l).size + current_size;%更新占用容量
                                                                copy_Distri(l).request(length(copy_Distri(l).request) + 1) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};
                                                                copy_LP{pod_thi, pod_fou}{2,k_k} = copy_LP{pod_thi, pod_fou}{2,k_k} - current_size;%更新剩余容量

%                                                                 L_Var{1,size(L_Var,2)+1} = 0;%不确定新路由是否在待拆连接之中
%                                                                 L_Var(2,size(L_Var,2)) = {copy_Distri(l).connections};%记录连接
%                                                                 L_Var(3,size(L_Var,2)) = {[L(sorted_L(i,1)).request{1,j}(1), length(copy_R(L(sorted_L(i,1)).request{1,j}(1)).route)]};%记录路由编号
%                                                                 L_Var{4,size(L_Var,2)} = current_size;%记录流量变动大小
                                                            end
                                                            break;
                                                        end
                                                    end
                                                    
                                                    current_size = 0;%更新待服务流量大小
                                                end
        
                                                if copy_LP{pod_fir, pod_sec}{2,k} == 0
                                                    k = k + 1;
                                                end
        
                                                if copy_LP{pod_thi, pod_fou}{2,k_k} == 0
                                                    k_k = k_k + 1;
                                                end
        
                                                if k > size(copy_LP{pod_fir, pod_sec},2) || k_k > size(copy_LP{pod_thi, pod_fou},2)
                                                    break;
                                                end
                                            else%%%%%%%至少一跳无剩余容量，只能再去找其他的路由
                                                break;%退出当前循环
                                            end
                                        end
        
                                        %可以最后更新
                                        copy_LM(pod_fir, pod_sec) = copy_LM(pod_fir, pod_sec) - (memory_cs - current_size);
                                        copy_LM(pod_thi, pod_fou) = copy_LM(pod_thi, pod_fou) - (memory_cs - current_size);
                                        if copy_LM(pod_fir, pod_sec) == 0
                                            LM_1(pod_fir, pod_sec) = inf;%%%%LM_1是对称阵
                                            LM_1(pod_sec, pod_fir) = inf;
                                        end
    
                                        if copy_LM(pod_thi, pod_fou) == 0
                                            LM_1(pod_thi, pod_fou) = inf;%%%%LM_1是对称阵
                                            LM_1(pod_fou, pod_thi) = inf;
                                        end
                                    end
    
                                else%没有路由了
                                    break;
                                end
                            end
        
                            if current_size > 0%说明没服务完，该条连接实际不可拆
                                flag = 1;
                                break;
                            end
                        end
        
                        if flag == 0
                            %表明可拆
                            new_flag = 1;%修改标识
                            R = copy_R;
                            Distri = copy_Distri;
                            Logical_Phy = copy_LP;
                            Logical_Matrix = copy_LM;
                            %在port_allocation第二行中标记该条连接的端口空闲
                            port_allocation{L(sorted_L(i,1)).connections(1),1}{L(sorted_L(i,1)).connections(2),1}(2,L(sorted_L(i,1)).connections(3)) = 0;
                            port_allocation{L(sorted_L(i,1)).connections(1),1}{L(sorted_L(i,1)).connections(2),1}(2,L(sorted_L(i,1)).connections(4)) = 0;
                            STA(1,chai(1,i_p)) = STA(1,chai(1,i_p)) - 1;%更新待拆线数目
                            %%每次重路由之后在L和sorted_L更新，可能会影响到后续的待拆连接
%                             for j = 1 : size(L_Var,2)
%                                 if L_Var{1,j} ~= 0%说明在sorted_L中存在，无需判断
%                                     sorted_L(L_Var{1,j},2) = sorted_L(L_Var{1,j},2) + L_Var{4,j};%更新流量占用，后续会重新排序
%                                     %L(sorted_L(L_Var{1,j},1)).request(m) = [];%删除
%                                     %L(sorted_L(L_Var{1,j},1)).size = L(sorted_L(L_Var{1,j},1)).size - f_size;%更新链路上的流量占用

                        else
                            %不可拆，把该连接添加回来
                            M(L(sorted_L(i,1)).connections(3),L(sorted_L(i,1)).connections(4),L(sorted_L(i,1)).connections(2),L(sorted_L(i,1)).connections(1)) = 1;
                            M(L(sorted_L(i,1)).connections(4),L(sorted_L(i,1)).connections(3),L(sorted_L(i,1)).connections(2),L(sorted_L(i,1)).connections(1)) = 1;
                        end
                    else%该连接上无流量经过，可以直接拆除
                        new_flag = 1;%修改标识
                        Distri = copy_Distri;
                        Logical_Phy = copy_LP;
                        Logical_Matrix = copy_LM;
                        %在port_allocation第二行中标记该条连接的端口空闲
                        port_allocation{L(sorted_L(i,1)).connections(1),1}{L(sorted_L(i,1)).connections(2),1}(2,L(sorted_L(i,1)).connections(3)) = 0;
                        port_allocation{L(sorted_L(i,1)).connections(1),1}{L(sorted_L(i,1)).connections(2),1}(2,L(sorted_L(i,1)).connections(4)) = 0;
                        STA(1,chai(1,i_p)) = STA(1,chai(1,i_p)) - 1;%更新待拆线数目
                    end
                else
                    break;%当前阶段拆线结束
                end
            end

            i = chai(1, i_p);%i指示在STA中的列号，也即当前操作的一个分平面
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

                                STA(2,i) = STA(2,i) - 1;%更新待增线数目

                                pod_s = port_allocation{i,1}{j,1}(1,k);%源pod
                                pod_d = port_allocation{i,1}{j,1}(1,l);%目的pod
                        
                                Logical_Matrix(pod_s,pod_d) = Logical_Matrix(pod_s,pod_d) + B;%只填充了上三角矩阵
                                Logical_Phy{pod_s,pod_d}(1, size(Logical_Phy{pod_s,pod_d},2)+1) = {[i,j,k,l]};%只填充了上三角矩阵
                                Logical_Phy{pod_s,pod_d}{2, size(Logical_Phy{pod_s,pod_d},2)} = B;%填充可用容量
                                new_flag = 1;%修改标识
                            end
                        end
                    end
                end
            end

            if new_flag == 1%标识当前平面的连线有变动
                stages = stages + 1;
%                 disp(chai(1,i_p));
                break;%退出i_p循环
            end
        end

        if new_flag == 0%表明每个平面都不能变动，平滑重构失败
            stages = -1;
            disp('Reconfiguration failed.');
            break;%跳出循环
        else%表示当前阶段重构成功
            if STA(1,chai(1, i_p)) == 0 && STA(2,chai(1, i_p)) == 0%待拆线、增线均为0，从chai中删除掉
                chai(i_p) = [];%从chai中删除，后面元素前移
            elseif STA(1,chai(1, i_p)) == 0 && STA(2,chai(1, i_p)) ~= 0%待拆线为0，待增线不为0，重构失败
                stages = -1;
                disp('Reconfiguration failed.');
                break;%跳出循环
            end
        end

    end

end
