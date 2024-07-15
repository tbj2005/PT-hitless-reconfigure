import numpy as np
import copy
import time


def find_list_in_dict(dictionary, target_list, key):
    """
    查找匹配的列表位置
    :param dictionary:
    :param target_list:
    :param key:
    :return:
    """
    try:
        index = dictionary[key].index(target_list)
        return index
    except (KeyError, ValueError):
        return None


def hitless_reconfigure(S_numpy, E_numpy, R_in, inputs, port_allocation):
    # 参数输入
    Omega = inputs.nodes_num  # pods_num
    T = inputs.group_num  # vector_num
    sum_port = inputs.oxc_ports  # ports pair that an OXC provided
    K = inputs.oxc_num_a_group  # oxc nums in a vector
    B = inputs.connection_cap
    eta_th = inputs.resi_cap  # 全网剩余容量阈值
    G = sum_port // Omega  # 每个pod连接到每个oxc上的连接数（这里是取了整，真实情况可能不是这样）

    # Omega = 32 # pods_num
    # T = 2 # vector_num
    # sum_port = 32*3 # ports pair that an OXC provided
    # K = 1 # oxc nums in a vector
    # B = 100
    # eta_th = 0.75 # 全网剩余容量阈值
    # G = sum_port // Omega # 每个pod连接到每个oxc上的连接数（这里是取了整，真实情况可能不是这样）

    # 初始化空字典，用于存储转换后的数据

    for r in range(0, len(R_in)):
        for i in range(0, len(R_in[r].route)):
            if len(R_in[r].route[i]) == 5:
                if R_in[r].route[i][2] > R_in[r].route[i][3]:
                    A = 0 + R_in[r].route[i][2]
                    C = 0 + R_in[r].route[i][3]
                    R_in[r].route[i][2] = C + 0
                    R_in[r].route[i][3] = A + 0
            if len(R_in[r].route[i]) == 9:
                if R_in[r].route[i][2] > R_in[r].route[i][3]:
                    A = 0 + R_in[r].route[i][2]
                    C = 0 + R_in[r].route[i][3]
                    R_in[r].route[i][2] = C + 0
                    R_in[r].route[i][3] = A + 0
                if R_in[r].route[i][6] > R_in[r].route[i][7]:
                    A = 0 + R_in[r].route[i][6]
                    C = 0 + R_in[r].route[i][7]
                    R_in[r].route[i][6] = C + 0
                    R_in[r].route[i][7] = A + 0

    R = {'sou_des': [[R_in[i].source, R_in[i].destination] for i in range(0, len(R_in))],
         'route': [R_in[i].route for i in range(0, len(R_in))]}

    S_real_numpy = np.zeros((Omega, Omega, K, T))

    for i in range(0, sum_port):
        for j in range(0, sum_port):
            for k in range(0, K):
                for t in range(0, T):
                    if i > j:
                        S_numpy[i][j][k][t] = 0
                        E_numpy[i][j][k][t] = 0

    # 抽象成真正的物理拓扑，即S[pod, pod, K, T]，也是只填充了上三角
    indices = np.argwhere(S_numpy == 1)
    for index in indices:
        pod_s = int(port_allocation[index[3]][index[2]][0][index[0]])  # 源 POD
        pod_d = int(port_allocation[index[3]][index[2]][0][index[1]])  # 目的 POD
        S_real_numpy[pod_s, pod_d, index[2], index[3]] += 1

    # E =  # 目标物理拓扑
    # E = [[[[0 for _ in range(T)] for _ in range(K)] for _ in range(sum_port)] for _ in range(sum_port)] # list的数据结构
    E_real_numpy = np.zeros((Omega, Omega, K, T))
    # 赋值
    # 抽象成真正的物理拓扑，即E[pod, pod, K, T]，也是只填充了上三角
    indices = np.argwhere(E_numpy == 1)
    for index in indices:
        pod_s = int(port_allocation[index[3]][index[2]][0][index[0]])  # 源 POD
        pod_d = int(port_allocation[index[3]][index[2]][0][index[1]])  # 目的 POD
        E_real_numpy[pod_s, pod_d, index[2], index[3]] += 1

    # ##############################################################################################################################################
    # start_time = time.time() # 统计代码运行时间
    # 初始化中间拓扑M = S，平滑重构切换阶段数stages = 0
    M_real_numpy = S_real_numpy
    stages = 0

    # 初始化字典，记录每个平面的每个oxc上pod对之间的连接已用容量
    Distri_pod = {
        'pod_pairs': [],  # pod a -> pod b
        'connections': [],  # group -> oxc
        'occupy': []  # Bandwidth used by each connection
    }

    indices = np.argwhere(M_real_numpy != 0)
    for index in indices:
        res = find_list_in_dict(Distri_pod, [index[0], index[1]], 'pod_pairs')
        if res is not None:
            Distri_pod['connections'][res].append([index[3], index[2]])  # 填充格式[group, OXC]
            Distri_pod['occupy'][res].append({'Band_occupy': [], 'Req': []})
        else:
            Distri_pod['pod_pairs'].append([index[0], index[1]])  # pod pairs
            Distri_pod['connections'].append([])
            Distri_pod['connections'][-1].append([index[3], index[2]])  # 填充格式[group, OXC]
            Distri_pod['occupy'].append([{'Band_occupy': [], 'Req': []}])

    # 初始化字典Distri, numpy方法
    Distri = []
    indices = np.argwhere(S_numpy == 1)
    for index in indices:
        new_entry = {
            'connections': [index[3], index[2], index[0], index[1]],  # 填充格式[分平面，OXC，端口，端口]
            'size': 0,  # 记录经过当前连接的流量大小
            'request': []  # 初始化request
        }

        for m in range(len(R['route'])):
            for n in range(len(R['route'][m])):
                for o in range((len(R['route'][m][n]) - 1) // 4):  # 指示当前路由有几跳
                    judge = R['route'][m][n][o * 4:(o * 4 + 4)]
                    if judge == [index[3], index[2], index[0], index[1]]:  # 当前流经过该连接，存储起来
                        new_entry['request'].append([m, n])  # 存储的是在R中的位置
                        new_entry['size'] += R['route'][m][n][-1]  # 统计流量
                        break
        Distri.append(new_entry)

    # 初始化一个numpy数组，记录每个平面每个oxc下的每个pod还剩下几个可用端口
    port_usage_numpy = G * np.ones((T, K, Omega))

    for item in Distri:
        k, l, s, d = item['connections']
        pod_s = int(port_allocation[k][l][0][s])
        pod_d = int(port_allocation[k][l][0][d])
        index = find_list_in_dict(Distri_pod, [pod_s, pod_d], 'pod_pairs')
        nested_array = np.array(Distri_pod['connections'][index])  # transform to numpy array
        indices = np.where((nested_array == [k, l]).all(axis=1))[0]
        Distri_pod['occupy'][index][indices[0]]['Band_occupy'].append(item['size'])  # occupied capacity
        Distri_pod['occupy'][index][indices[0]]['Req'].append(item['request'])
        port_usage_numpy[k, l, pod_s] -= 1  # residual available port number
        port_usage_numpy[k, l, pod_d] -= 1

    # Change the flow routing in R to pod level
    for i in range(len(R['route'])):
        for j in range(len(R['route'][i])):
            if (len(R['route'][i][j]) - 1) // 4 == 1:  # one hop
                R['route'][i][j][2] = R['route'][i][j][2] // G
                R['route'][i][j][3] = R['route'][i][j][3] // G
            else:
                R['route'][i][j][2] = R['route'][i][j][2] // G
                R['route'][i][j][3] = R['route'][i][j][3] // G
                R['route'][i][j][6] = R['route'][i][j][6] // G
                R['route'][i][j][7] = R['route'][i][j][7] // G

    print('Initial state of R:', R, '\n')  # 打印初始流量情况
    print('************************************************************************************************************************************')  # 分隔符

    # 初始化 STA 数组
    STA = np.zeros((2, T), dtype=int)
    Delta = M_real_numpy - E_real_numpy  # Difference matrix
    Delta = Delta.astype('int')
    indices = np.argwhere(Delta > 0)  # 找到待拆线
    for index in indices:
        STA[0, index[3]] += Delta[index[0], index[1], index[2], index[3]]  # 拆线

    indices = np.argwhere(Delta < 0)  # 找到待增线
    for index in indices:
        STA[1, index[3]] += (-Delta[index[0], index[1], index[2], index[3]])

    # 遍历所有平面，如果某个平面只需要增线，则进行相应的连接更新操作
    for i in range(T):
        if STA[0, i] == 0 and STA[1, i] != 0:  # 该平面只需要增线
            indices = np.argwhere(Delta[..., i] < 0)
            for index in indices:
                # 检验端口是否空闲
                res = max(port_usage_numpy[i, index[2], index[0]],
                          port_usage_numpy[i, index[2], index[1]])  # residual port number
                if res >= (-Delta[index[0], index[1], index[2], i]):  # 代表可增加连线
                    # 连接起来
                    port_usage_numpy[i, index[2], index[0]] += Delta[index[0], index[1], index[2], i]
                    port_usage_numpy[i, index[2], index[1]] += Delta[index[0], index[1], index[2], i]
                    STA[1, i] += Delta[index[0], index[1], index[2], i]
                    results = find_list_in_dict(Distri_pod, [index[0], index[1]], 'pod_pairs')
                    if results is not None:
                        nested_array = np.array(Distri_pod['connections'][results])  # transform to numpy array
                        inseq = np.where((nested_array == [i, index[2]]).all(axis=1))[0]
                        if inseq.size != 0:
                            for j in range(-Delta[index[0], index[1], index[2], i]):
                                Distri_pod['occupy'][results][inseq[0]]['Band_occupy'].append(0)
                                Distri_pod['occupy'][results][inseq[0]]['Req'].append([])
                        else:
                            Distri_pod['connections'][results].append([i, index[2]])
                            Distri_pod['occupy'][results].append({'Band_occupy': [], 'Req': []})
                            for j in range(-Delta[index[0], index[1], index[2], i]):
                                Distri_pod['occupy'][results][-1]['Band_occupy'].append(0)
                                Distri_pod['occupy'][results][-1]['Req'].append([])

                    else:  # 新增的pod对
                        Distri_pod['pod_pairs'].append([index[0], index[1]])
                        Distri_pod['connections'].append([])
                        Distri_pod['connections'][-1].append([i, index[2]])
                        Distri_pod['occupy'].append([{'Band_occupy': [], 'Req': []}])
                        for j in range(-Delta[index[0], index[1], index[2], i]):
                            Distri_pod['occupy'][-1][0]['Band_occupy'].append(0)
                            Distri_pod['occupy'][-1][0]['Req'].append([])
                    print('Group[', i, ']OXC[', index[2], ']Pod[', index[0], ']and Pod[', index[1], '], Add', - Delta[index[0], index[1], index[2], i], 'Links') # 增加连接的输出打印
                    Delta[index[0], index[1], index[2], i] = 0
                else:
                    stages = -1
                    print('Reconfiguration failed.')
                    break  # 跳出循环

            if stages == -1:
                break
            else:
                # STA[1, i] = 0  # 更新待增线为0
                stages += 1
                print('Current Stage = ', stages, 'Completed\n')  # 打印当前阶段数，当前阶段已完成

    if stages != -1:
        # 剩下要处理的全部都是需要拆线的
        remove = []  # 存储当前需要拆线的平面

        for i in range(T):
            if STA[0, i] != 0:  # 该平面需要拆线
                remove.append(i)

        eta_den = 0  # Records the number of real-time connections on the network
        for i in range(len(Distri_pod['occupy'])):
            for j in range(len(Distri_pod['occupy'][i])):
                eta_den += len(Distri_pod['occupy'][i][j]['Band_occupy'])

        while len(remove) != 0:  # 代表还有待拆的平面
            # 记录上一个阶段拓扑中的连接数
            for item in remove:  # 确定当前要重构的平面
                new_flag = 0  # 标识当前平面是否真的能拆线/增线
                new_flag_2 = 0 # 标识当前阶段是否有流量路由变动
                eta_basic = eta_den
                indices = np.argwhere(Delta[..., item] > 0)  # 拆线
                for index in indices:  # 找到要拆除的连接(s)
                    j = index[2]
                    k = index[0]
                    l = index[1]

                    # 判断能否拆除
                    # 判断的方法是看此两个pod之间是否存在其他的可替代连接
                    seq = find_list_in_dict(Distri_pod, [k, l], 'pod_pairs')
                    nested_array = np.array(Distri_pod['connections'][seq])  # transform to numpy array
                    inseq = np.where((nested_array == [item, j]).all(axis=1))[0]

                    for i in range(int(Delta[k, l, j, item])):
                        eta = (eta_den - 1) / eta_basic
                        if eta >= eta_th:  # 判断是否不小于阈值
                            min_value = min(Distri_pod['occupy'][seq][inseq[0]]['Band_occupy'])
                            min_index = Distri_pod['occupy'][seq][inseq[0]]['Band_occupy'].index(min_value)
                            if min_value == 0:  # Indicates that there is no traffic on this link
                                del Distri_pod['occupy'][seq][inseq[0]]['Band_occupy'][min_index]  # delete
                                del Distri_pod['occupy'][seq][inseq[0]]['Req'][min_index]  # delete
                                Delta[k, l, j, item] -= 1
                                port_usage_numpy[item, j, k] += 1
                                port_usage_numpy[item, j, l] += 1
                                STA[0, item] -= 1
                                new_flag = 1
                                eta_den -= 1
                                print('Group[', item, ']OXC[', index[2], ']Pod[', index[0], ']and Pod[', index[1], '], Remove 1 Link' ) # 拆除连接的输出打印
                            else:
                                # Divert traffic to its alternative link(s)
                                new_flag_2 = 1 # modify
                                Alter_list = [[], [], []]  # group, oxc, item in Distri['occupy'], residual bandwith
                                total_band_kl = 0  # total available bandwidth between pod k and pod l
                                # Record the traffic on the connection to be removed
                                Record = [[], []]
                                for Ele in Distri_pod['occupy'][seq][inseq[0]]['Req'][min_index]:
                                    Record[0].append(Ele)
                                    Record[1].append(R['route'][Ele[0]][Ele[1]][-1])  # 原本流量的大小

                                for nape in range(len(Distri_pod['occupy'][seq])):
                                    for nape_v2 in range(
                                            len(Distri_pod['occupy'][seq][nape]['Band_occupy'])):  # each link
                                        if nape != inseq[0] or nape_v2 != min_index:
                                            if Distri_pod['occupy'][seq][nape]['Band_occupy'][nape_v2] != B:
                                                Alter_list[0].append(nape)
                                                Alter_list[1].append(nape_v2)
                                                Alter_list[2].append(B - Distri_pod['occupy'][seq][nape]['Band_occupy'][
                                                    nape_v2])  # residual capacity

                                for nape in Alter_list[2]:
                                    total_band_kl += nape

                                if total_band_kl >= min_value:  # can be directly groommed
                                    o = 0  # for o in range(len(Alter_list[0]))

                                    for Elem in range(len(Record[0])):  # for each flow
                                        Times = 0
                                        Hops = (len(R['route'][Record[0][Elem][0]][Record[0][Elem][1]]) - 1) // 4
                                        if Hops == 1:
                                            loc = 0
                                        else:
                                            for a in range(2):
                                                judge = R['route'][Record[0][Elem][0]][Record[0][Elem][1]][
                                                        a * 4:(a * 4 + 4)]
                                                if [judge[2], judge[3]] == [k, l]:
                                                    loc = a * 4
                                                    break

                                        while Record[1][Elem] != 0:
                                            can_serve = min(Alter_list[2][o], Record[1][Elem])

                                            if Times == 0:  # the first piece
                                                Distri_pod['occupy'][seq][Alter_list[0][o]]['Req'][
                                                    Alter_list[1][o]].append(Record[0][Elem])
                                                # modify R
                                                R['route'][Record[0][Elem][0]][Record[0][Elem][1]][-1] = can_serve
                                                R['route'][Record[0][Elem][0]][Record[0][Elem][1]][loc] = \
                                                    Distri_pod['connections'][seq][Alter_list[0][o]][0]
                                                R['route'][Record[0][Elem][0]][Record[0][Elem][1]][loc + 1] = \
                                                    Distri_pod['connections'][seq][Alter_list[0][o]][1]

                                            else:
                                                # modify R
                                                rou_te = copy.deepcopy(
                                                    R['route'][Record[0][Elem][0]][Record[0][Elem][1]])  # list
                                                rou_te[-1] = can_serve
                                                rou_te[loc] = Distri_pod['connections'][seq][Alter_list[0][o]][0]
                                                rou_te[loc + 1] = Distri_pod['connections'][seq][Alter_list[0][o]][1]
                                                R['route'][Record[0][Elem][0]].append(rou_te)
                                                Distri_pod['occupy'][seq][Alter_list[0][o]]['Req'][
                                                    Alter_list[1][o]].append(
                                                    [Record[0][Elem][0], len(R['route'][Record[0][Elem][0]]) - 1])

                                            Record[1][Elem] -= can_serve
                                            Alter_list[2][o] -= can_serve
                                            Distri_pod['occupy'][seq][Alter_list[0][o]]['Band_occupy'][
                                                Alter_list[1][o]] += can_serve  # Weighted equipartition
                                            Times += 1
                                            if Alter_list[2][o] == 0:
                                                o += 1

                                    del Distri_pod['occupy'][seq][inseq[0]]['Band_occupy'][min_index]  # delete
                                    del Distri_pod['occupy'][seq][inseq[0]]['Req'][min_index]  # delete
                                    print('Group[', item, ']OXC[', index[2], ']Pod[', index[0], ']and Pod[', index[1],
                                          '], Remove 1 Link')  # 拆除连接的输出打印

                                    Delta[k, l, j, item] -= 1
                                    port_usage_numpy[item, j, k] += 1
                                    port_usage_numpy[item, j, l] += 1
                                    STA[0, item] -= 1
                                    new_flag = 1
                                    eta_den -= 1
                                else:  # find other available route for each traffic
                                    new_flag_2 = 1  # modify
                                    copy_Distri = copy.deepcopy(
                                        Distri_pod)  # 复制一份 但是由于目前还不确定是否能拆除当前连接，所以不能对Distri直接进行操作
                                    del copy_Distri['occupy'][seq][inseq[0]]['Band_occupy'][min_index]  # delete
                                    del copy_Distri['occupy'][seq][inseq[0]]['Req'][min_index]  # delete
                                    sign = 0  # 标志当前连接是否能被拆除

                                    for o in range(len(Record[0])):
                                        hop = (len(R['route'][Record[0][o][0]][Record[0][o][1]]) - 1) // 4
                                        if hop == 2:
                                            j_break = 0
                                            for a in range(hop):
                                                judge = R['route'][Record[0][o][0]][Record[0][o][1]][a * 4:(a * 4 + 4)]
                                                if judge != [item, j, k, l]:
                                                    seq_1 = find_list_in_dict(copy_Distri, [judge[2], judge[3]],
                                                                              'pod_pairs')
                                                    nested_array_1 = np.array(
                                                        copy_Distri['connections'][seq_1])  # transform to numpy array
                                                    inseq_1 = \
                                                        np.where((nested_array_1 == [judge[0], judge[1]]).all(axis=1))[0]
                                                    for b in range(len(
                                                            copy_Distri['occupy'][seq_1][inseq_1[0]]['Band_occupy'])):
                                                        for c in range(len(
                                                                copy_Distri['occupy'][seq_1][inseq_1[0]]['Req'][b])):
                                                            if copy_Distri['occupy'][seq_1][inseq_1[0]]['Req'][b][c] == \
                                                                    Record[0][o]:
                                                                j_break = 1
                                                                del copy_Distri['occupy'][seq_1][inseq_1[0]]['Req'][b][
                                                                    c]
                                                                copy_Distri['occupy'][seq_1][inseq_1[0]]['Band_occupy'][
                                                                    b] -= Record[1][o]
                                                                break

                                                        if j_break == 1:
                                                            break
                                                if j_break == 1:
                                                    break

                                    Logical_res = np.zeros(
                                        (Omega, Omega))  # 存储对应pod对的剩余可用容量

                                    for o in range(len(copy_Distri['pod_pairs'])):
                                        mid = 0
                                        for o_1 in range(len(copy_Distri['connections'][o])):
                                            for o_2 in range(len(copy_Distri['occupy'][o][o_1]['Band_occupy'])):
                                                mid += (B - copy_Distri['occupy'][o][o_1]['Band_occupy'][o_2])

                                        if mid != 0:
                                            Logical_res[
                                                copy_Distri['pod_pairs'][o][0], copy_Distri['pod_pairs'][o][1]] = mid
                                            Logical_res[
                                                copy_Distri['pod_pairs'][o][1], copy_Distri['pod_pairs'][o][0]] = mid

                                    copyR_List = []  # Stores changes to corresponding rows in R
                                    for o in range(len(Record[0])):  # Find routes from source pod to destination pod
                                        copyR_List.append(R['route'][Record[0][o][0]])  # copy
                                        flow_sou = R['sou_des'][Record[0][o][0]][0]  # source pod
                                        flow_des = R['sou_des'][Record[0][o][0]][1]  # destination pod
                                        FLAG = 0  # 指示为流重新路由的第一个分请求

                                        if Logical_res[flow_sou, flow_des] != 0:
                                            seq_1 = find_list_in_dict(copy_Distri, [flow_sou, flow_des], 'pod_pairs')
                                            if Logical_res[flow_sou, flow_des] >= Record[1][o]:  # can serve
                                                for o_1 in range(len(copy_Distri['connections'][seq_1])):
                                                    for o_2 in range(
                                                            len(copy_Distri['occupy'][seq_1][o_1]['Band_occupy'])):
                                                        if copy_Distri['occupy'][seq_1][o_1]['Band_occupy'][o_2] != B:
                                                            FLAG += 1  # 当FLAG = 1时表示第一次分割请求，放入copy_R的原始位置
                                                            portion = min(
                                                                B - copy_Distri['occupy'][seq_1][o_1]['Band_occupy'][
                                                                    o_2], Record[1][o])
                                                            if FLAG == 1:
                                                                copyR_List[o][Record[0][o][1]] = [
                                                                    copy_Distri['connections'][seq_1][o_1][0],
                                                                    copy_Distri['connections'][seq_1][o_1][1], flow_sou,
                                                                    flow_des, portion]
                                                                copy_Distri['occupy'][seq_1][o_1]['Band_occupy'][
                                                                    o_2] += portion
                                                                copy_Distri['occupy'][seq_1][o_1]['Req'][o_2].append(
                                                                    Record[0][o])
                                                            else:
                                                                copyR_List[o].append(
                                                                    [copy_Distri['connections'][seq_1][o_1][0],
                                                                     copy_Distri['connections'][seq_1][o_1][1],
                                                                     flow_sou, flow_des, portion])
                                                                copy_Distri['occupy'][seq_1][o_1]['Band_occupy'][
                                                                    o_2] += portion
                                                                copy_Distri['occupy'][seq_1][o_1]['Req'][o_2].append(
                                                                    [Record[0][o][0], len(copyR_List[o]) - 1])
                                                            Logical_res[flow_sou, flow_des] -= portion
                                                            Logical_res[flow_des, flow_sou] -= portion
                                                            Record[1][o] -= portion  # update

                                                        if Record[1][o] == 0:  # Complete service
                                                            break
                                                    if Record[1][o] == 0:  # Complete service
                                                        break

                                            else:  # use all
                                                for o_1 in range(len(copy_Distri['connections'][seq_1])):
                                                    for o_2 in range(
                                                            len(copy_Distri['occupy'][seq_1][o_1]['Band_occupy'])):
                                                        if copy_Distri['occupy'][seq_1][o_1]['Band_occupy'][o_2] != B:
                                                            FLAG += 1  # 当FLAG = 1时表示第一次分割请求，放入copy_R的原始位置
                                                            portion = B - \
                                                                      copy_Distri['occupy'][seq_1][o_1]['Band_occupy'][
                                                                          o_2]
                                                            if FLAG == 1:
                                                                copyR_List[o][Record[0][o][1]] = [
                                                                    copy_Distri['connections'][seq_1][o_1][0],
                                                                    copy_Distri['connections'][seq_1][o_1][1], flow_sou,
                                                                    flow_des, portion]
                                                                copy_Distri['occupy'][seq_1][o_1]['Band_occupy'][
                                                                    o_2] = B
                                                                copy_Distri['occupy'][seq_1][o_1]['Req'][o_2].append(
                                                                    Record[0][o])
                                                            else:
                                                                copyR_List[o].append(
                                                                    [copy_Distri['connections'][seq_1][o_1][0],
                                                                     copy_Distri['connections'][seq_1][o_1][1],
                                                                     flow_sou, flow_des, portion])
                                                                copy_Distri['occupy'][seq_1][o_1]['Band_occupy'][
                                                                    o_2] = B
                                                                copy_Distri['occupy'][seq_1][o_1]['Req'][o_2].append(
                                                                    [Record[0][o][0], len(copyR_List[o]) - 1])
                                                Record[1][o] -= Logical_res[flow_sou, flow_des]  # update
                                                Logical_res[flow_sou, flow_des] = 0
                                                Logical_res[flow_des, flow_sou] = 0

                                        if Record[1][o] != 0:  # find two hops
                                            for a in range(Omega):
                                                if a != flow_sou and a != flow_des:
                                                    pod_fir = min(a, flow_sou)
                                                    pod_sec = max(a, flow_sou)
                                                    pod_thi = min(a, flow_des)
                                                    pod_fou = max(a, flow_des)
                                                    # if a < flow_sou:
                                                    #     pod_fir = a
                                                    #     pod_sec = flow_sou
                                                    # else:
                                                    #     pod_fir = flow_sou
                                                    #     pod_sec = a
                                                    #
                                                    # if a < flow_des:
                                                    #     pod_thi = a
                                                    #     pod_fou = flow_des
                                                    # else:
                                                    #     pod_thi = flow_des
                                                    #     pod_fou = a

                                                    if Logical_res[pod_fir, pod_sec] != 0 and Logical_res[
                                                        pod_thi, pod_fou] != 0:
                                                        seq_1 = find_list_in_dict(copy_Distri, [pod_fir, pod_sec],
                                                                                  'pod_pairs')
                                                        seq_2 = find_list_in_dict(copy_Distri, [pod_thi, pod_fou],
                                                                                  'pod_pairs')
                                                        # if ava_capa >= Record[1][o]:  # can serve
                                                        o_1 = 0
                                                        o_2 = 0
                                                        o_3 = 0
                                                        o_4 = 0

                                                        while Record[1][o] > 0:
                                                            while len(copy_Distri['occupy'][seq_1][o_1][
                                                                          'Band_occupy']) == 0:
                                                                o_1 += 1
                                                                if o_1 >= len(copy_Distri['connections'][seq_1]):
                                                                    break
                                                            if o_1 >= len(copy_Distri['connections'][seq_1]):
                                                                break

                                                            while len(copy_Distri['occupy'][seq_2][o_3][
                                                                          'Band_occupy']) == 0:
                                                                o_3 += 1
                                                                if o_3 >= len(copy_Distri['connections'][seq_2]):
                                                                    break
                                                            if o_3 >= len(copy_Distri['connections'][seq_2]):
                                                                break

                                                            if copy_Distri['occupy'][seq_1][o_1]['Band_occupy'][
                                                                o_2] != B and \
                                                                    copy_Distri['occupy'][seq_2][o_3]['Band_occupy'][
                                                                        o_4] != B:
                                                                FLAG += 1  # 当FLAG = 1时表示第一次分割请求，放入copy_R的原始位置
                                                                capa = min(B - copy_Distri['occupy'][seq_1][o_1][
                                                                    'Band_occupy'][o_2], B -
                                                                           copy_Distri['occupy'][seq_2][o_3][
                                                                               'Band_occupy'][o_4])
                                                                portion = min(capa, Record[1][o])

                                                                if FLAG == 1:
                                                                    copyR_List[o][Record[0][o][1]] = [
                                                                        copy_Distri['connections'][seq_1][o_1][0],
                                                                        copy_Distri['connections'][seq_1][o_1][1],
                                                                        pod_fir, pod_sec,
                                                                        copy_Distri['connections'][seq_2][o_3][0],
                                                                        copy_Distri['connections'][seq_2][o_3][1],
                                                                        pod_thi, pod_fou, portion]
                                                                    copy_Distri['occupy'][seq_1][o_1]['Band_occupy'][
                                                                        o_2] += portion
                                                                    copy_Distri['occupy'][seq_1][o_1]['Req'][
                                                                        o_2].append(Record[0][o])
                                                                    copy_Distri['occupy'][seq_2][o_3]['Band_occupy'][
                                                                        o_4] += portion
                                                                    copy_Distri['occupy'][seq_2][o_3]['Req'][
                                                                        o_4].append(Record[0][o])
                                                                else:
                                                                    copyR_List[o].append(
                                                                        [copy_Distri['connections'][seq_1][o_1][0],
                                                                         copy_Distri['connections'][seq_1][o_1][1],
                                                                         pod_fir, pod_sec,
                                                                         copy_Distri['connections'][seq_2][o_3][0],
                                                                         copy_Distri['connections'][seq_2][o_3][1],
                                                                         pod_thi, pod_fou, portion])
                                                                    copy_Distri['occupy'][seq_1][o_1]['Band_occupy'][
                                                                        o_2] += portion
                                                                    copy_Distri['occupy'][seq_1][o_1]['Req'][
                                                                        o_2].append(
                                                                        [Record[0][o][0], len(copyR_List[o]) - 1])
                                                                    copy_Distri['occupy'][seq_2][o_3]['Band_occupy'][
                                                                        o_4] += portion
                                                                    copy_Distri['occupy'][seq_2][o_3]['Req'][
                                                                        o_4].append(
                                                                        [Record[0][o][0], len(copyR_List[o]) - 1])

                                                                Logical_res[pod_fir, pod_sec] -= portion
                                                                Logical_res[pod_sec, pod_fir] -= portion
                                                                Logical_res[pod_thi, pod_fou] -= portion
                                                                Logical_res[pod_fou, pod_thi] -= portion
                                                                Record[1][o] -= portion  # update

                                                            if copy_Distri['occupy'][seq_1][o_1]['Band_occupy'][
                                                                o_2] == B:
                                                                o_2 += 1
                                                                if o_2 >= len(copy_Distri['occupy'][seq_1][o_1][
                                                                                  'Band_occupy']):
                                                                    o_1 += 1
                                                                    o_2 = 0
                                                                    if o_1 >= len(copy_Distri['connections'][seq_1]):
                                                                        break

                                                            if copy_Distri['occupy'][seq_2][o_3]['Band_occupy'][
                                                                o_4] == B:
                                                                o_4 += 1
                                                                if o_4 >= len(copy_Distri['occupy'][seq_2][o_3][
                                                                                  'Band_occupy']):
                                                                    o_3 += 1
                                                                    o_4 = 0
                                                                    if o_3 >= len(copy_Distri['connections'][seq_2]):
                                                                        break

                                                if Record[1][o] == 0:
                                                    break

                                        if Record[1][o] != 0:
                                            # 当前阶段不可拆此线
                                            sign = 1
                                            break

                                    if sign == 0:  # can remove
                                        Distri_pod = copy.deepcopy(copy_Distri)
                                        for o in range(len(Record[0])):
                                            R['route'][Record[0][o][0]] = copy.deepcopy(copyR_List[o])

                                        print('Group[', item, ']OXC[', index[2], ']Pod[', index[0], ']and Pod[',
                                              index[1], '], Remove 1 Link')  # 拆除连接的输出打印
                                        Delta[k, l, j, item] -= 1
                                        port_usage_numpy[item, j, k] += 1
                                        port_usage_numpy[item, j, l] += 1
                                        STA[0, item] -= 1
                                        new_flag = 1
                                        eta_den -= 1
                        else:  # End of current stage
                            break

                    if eta < eta_th:  # End of current stage
                        break

                if new_flag_2 == 1: # 标识有流量变动
                    print('Current R:', R)  # 打印当前流量情况

                # 增线
                indices = np.argwhere(Delta[..., item] < 0)
                for index in indices:
                    j = index[2]
                    k = index[0]
                    l = index[1]

                    seq = find_list_in_dict(Distri_pod, [k, l], 'pod_pairs')

                    for i in range(int(-Delta[k, l, j, item])):
                        res = max(port_usage_numpy[item, j, k], port_usage_numpy[item, j, l])
                        if res >= 1:
                            port_usage_numpy[item, j, k] -= 1
                            port_usage_numpy[item, j, l] -= 1
                            STA[1, item] -= 1
                            Delta[k, l, j, item] += 1
                            new_flag = 1
                            eta_den += 1
                            print('Group[', item, ']OXC[', j, ']Pod[', k, ']and Pod[', l, '], Add 1 Links') # 增加连接的输出打印
                            if seq is not None:
                                nested_array = np.array(Distri_pod['connections'][seq])  # transform to numpy array
                                inseq = np.where((nested_array == [item, j]).all(axis=1))[0]
                                if inseq.size != 0:
                                    Distri_pod['occupy'][seq][inseq[0]]['Band_occupy'].append(0)
                                    Distri_pod['occupy'][seq][inseq[0]]['Req'].append([])
                                else:
                                    Distri_pod['connections'][seq].append([item, j])
                                    Distri_pod['occupy'][seq].append({'Band_occupy': [0], 'Req': [[]]})

                            else:  # 新增的pod对连接
                                Distri_pod['pod_pairs'].append([k, l])
                                Distri_pod['connections'].append([[item, j]])
                                Distri_pod['occupy'].append([{'Band_occupy': [0], 'Req': [[]]}])
                        else:
                            break

                if new_flag == 1:  # 标识当前平面的连线有变动
                    stages += 1
                    print('Current Stage = ', stages, 'Completed\n')  # 打印当前阶段数，当前阶段已完成
                    print('************************************************************************************************************************************') # 阶段分隔符
                    break

            if new_flag == 0:  # 表明每个平面都不能变动，平滑重构失败
                stages = -1
                print('Reconfiguration failed.')
                break  # 跳出循环
            else:  # 表示当前阶段重构成功
                if STA[0, item] == 0 and STA[1, item] == 0:  # 待拆线、增线均为0，从remove中删除掉
                    i_p = remove.index(item)
                    del remove[i_p]  # 从chai中删除，后面元素前移
                elif STA[0, item] == 0 and STA[1, item] != 0:  # 待拆线为0，待增线不为0，重构失败
                    stages = -1
                    print('Reconfiguration failed.')
                    break  # 跳出循环

    print('stages =', stages)
    is_all_zero = np.all(Delta == 0)
    print(is_all_zero)

    return stages
