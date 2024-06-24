# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06约23日
"""
import copy

# 转化输入参数，以与后续平滑重构契合
import numpy as np
import random
import Input_class


def convert_inputs(inputs, flow_path, logical_topo):
    """

    :param inputs: 网络参数
    :param flow_path: 流量路径
    :param logical_topo: 逻辑拓扑
    :return:
    """
    Omega = inputs.nodes_num  # pod 数目
    T = inputs.group_num  # group 数目
    sum_port = inputs.oxc_ports  # 每个 oxc 的端口总数
    K = inputs.oxc_num_a_group  # 一个 group 内 oxc 数目
    B = inputs.connection_cap  # 连接带宽容量
    request = inputs.request  # 需求流量
    req_num = len(request)  # 需求流量数目
    ave = int(sum_port / Omega)  # 端口数目向下均分，即一个 pod 上的 oxc 端口数目
    remain = sum_port % Omega  # 求余，即平均分配后余下的 oxc 端口

    G = np.ones([Omega, K, T])
    G *= ave
    G = G.astype(int)  # 存放每个 pod 对第 t 个 group 中第 k 个 oxc 有多少端口连接

    if remain != 0:  # 如果端口并不能完全平均分配，需要随机放端口
        for i in range(0, T):
            for j in range(0, K):  # 遍历了所有的 oxc
                Rand = random.choices([t for t in range(0, Omega)], k=remain)  # 把每个 oxc 多出来的端口随机放给所有 pod
                for k in range(0, remain):
                    G[Rand[k], j, i] += 1

    port_allocation = np.empty(T, dtype=object)
    # 将连接具体分配到端口，首先建立了一个元胞数组，该元胞数组内的元素为 K × 1 元胞数组，这个数组内的每个元素为一个2 × num_port 矩阵
    # 其中第一行表示 第 t 个 group 第 k 个 oxc 的第 n 个 port 被分到了哪个 pod，第二行表示端口占用情况

    for i in range(0, T):
        port_allocation[i] = np.empty(K, dtype=object)
        for j in range(0, K):
            port_allocation[i][j] = np.zeros([2, sum_port])
            p = 0  # 遍历每个 oxc 时需要先初始化端口序号
            for k in range(0, Omega):
                for n in range(p, p + G[k, j, i]):
                    port_allocation[i][j][0][n] = k  # 按序把具体的端口分给 pod
                    port_allocation[i][j][1][n] = 0  # 初始化端口占用状态为 0
                p += G[k, j, i]

    # 获得 S 和 S_Conn 矩阵， S 为一个四维数组，表示初始物理拓扑，前两个元素分别表示一个 oxc 上的两个 port，后两个元素定位 oxc 位置
    # 元素为 0 ，说明这两个同一 oxc 的 port 没有相互连接
    S = np.zeros([sum_port, sum_port, K, T])
    port_allocation_inti_topo = copy.deepcopy(port_allocation)
    S_Conn = []  # list 中的元素是一个六元组
    for t in range(0, T):
        for k in range(0, K):
            conn_col, conn_row = np.where(np.tril(logical_topo[t, k]))  # 找到子拓扑连接需求
            for conn_ind in range(0, len(conn_row)):  # 遍历子拓扑所有连接需求
                pod_u_col = np.where(port_allocation_inti_topo[t][k][0][:] == conn_row[conn_ind])
                pod_u_col = pod_u_col[0]
                pod_v_col = np.where(port_allocation_inti_topo[t][k][0][:] == conn_col[conn_ind])
                pod_v_col = pod_v_col[0]
                for ii in range(0, logical_topo[t, k][conn_row[conn_ind], conn_col[conn_ind]]):
                    S[pod_u_col[ii], pod_v_col[ii], k, t] = 1
                    S[pod_v_col[ii], pod_u_col[ii], k, t] = 1  # 标记这两个 oxc 上的 port 相连
                    S_Conn.append([conn_row[conn_ind], conn_col[conn_ind], t, k, pod_u_col[ii], pod_v_col[ii]])
                    S_Conn.append([conn_col[conn_ind], conn_row[conn_ind], t, k, pod_v_col[ii], pod_u_col[ii]])
                    # 更新连接信息六元组，增加一个元素[pod1, pod2, k, t, port1, port2]，即pod 1 和 pod 2 通过第 t 个 group 第 k
                    # 个 oxc 上的 port 1 和 port 2 连接 且pod 1 连接 port 1， pod 2 连接 port 2
                    port_allocation_inti_topo[t][k][0][pod_u_col[ii]] = -1
                    port_allocation_inti_topo[t][k][0][pod_v_col[ii]] = -1
                    # 更新未使用端口分配，使用过的端口换成 -1，防止下次进循环找端口出错

    # 更新端口占用状态
    for i in range(0, T):
        for j in range(0, K):
            for k in range(0, sum_port - 1):
                for n in range(k + 1, sum_port):
                    if S[k, n, j, i] == 1:  # 如果端口被连接，那么就要更新状态为1
                        port_allocation[i][j][1][k] = 1
                        port_allocation[i][j][1][n] = 1

    logical_topo_traffic = np.empty([T, K], dtype=object)

    for t in range(0, T):
        for k in range(0, K):
            logical_topo_traffic[t, k] = np.zeros([Omega, Omega])  # 初始化 logical_topo_traffic 数组

    S_Conn_cap = [S_Conn[k] + [1 * B] for k in range(0, len(S_Conn))]
    # 在 S_Conn_cap 的每一个元素内加一个数，表示可用带宽容量
    R = []  # 需求结构体
    for r in range(0, req_num):
        R.append(Input_class.Request())
        R[r].source = request[r][0]
        R[r].destination = request[r][1]
        R[r].demands = request[r][2]
        for n in range(0, len(flow_path[r])):
            row_des = [k for k in range(0, len(flow_path[r])) if flow_path[r][k][1] == R[r].destination]
            # row_des 表征哪些行代表着一条流的最后一跳，因为网络中有一跳和两跳两种路由方案
            start = 0
            path_hop = []  # flow_path中并不是每一行都代表从源 pod 到目的 pod 间的路由方案，还有两跳的流量，这个数组用来分路由方案将路径分开
            flow_cap_r = []  # 和上条注释一样，用来存储不同方案的带宽分配
            for jj in range(0, len(row_des)):  # 遍历所有一跳或两跳路由方案
                path_hop.append(flow_path[r][start:row_des[jj] + 1])  # 将 flow_path 矩阵中的每一条流分开
                start += row_des[jj] + 1
                flow_cap_r.append(path_hop[jj][0][2])  # 储存每条一跳或两跳流量的带宽分配
                ava_ports = []
                ava_ports_num = []  # 存储可以用于传输该路由方案每一跳的连接数目
                for ii in range(0, len(path_hop[jj])):  # 循环一次或两次，对应流为一跳或两跳
                    Lialoc = [1 if S_Conn_cap[k][0:2] == [path_hop[jj][ii][k] - 1 for k in range(0, 2)]
                              else 0 for k in range(0, len(S_Conn))]
                    # 匹配 pod 连接情况与这一跳的路由方案
                    ava_ports_num.append(sum(Lialoc))
                    ava_rows = np.where(Lialoc)
                    ava_rows = ava_rows[0]  # 可用于传输该跳的连接位置
                    ava_port = [S_Conn_cap[ava_rows[k]][0:7] for k in range(0, len(ava_rows))]
                    # 这些连接对应的信息
                    A = [ava_port[k][6] for k in range(0, len(ava_port))]
                    sorted_ind = [i[0] for i in sorted(enumerate(A), key=lambda x: x[1])]  # 对这些连接的端口容量排序
                    ava_ports.append([ava_port[k][0:7] for k in sorted_ind])  # 放置这个路由方案可使用连接的信息

                R[r].route = []
                if len(path_hop[jj]) > 1:  # 路径为两跳
                    flag = 0
                    for ij in range(0, ava_ports_num[0]):
                        if flag == 1:  # 需求流量 r 被处理完
                            break
                        if ava_ports[0][ij][6] > 0:
                            for ji in range(0, ava_ports_num[1]):
                                if ava_ports[1][ji][6] > 0:
                                    flow_val = min(ava_ports[0][ij][6], ava_ports[1][ji][6], flow_cap_r[jj])
                                    R[r].route.extend([ava_ports[0][ij][2:6], ava_ports[1][ji][2:6], flow_val])

                                    t = ava_ports[0][ij][2]
                                    k = ava_ports[0][ij][3]
                                    sub_path = path_hop[jj][0][0:2]
                                    logical_topo_traffic[t][k][sub_path[0] - 1][sub_path[1] - 1] += flow_val

                                    t1 = ava_ports[1][ji][2]
                                    k1 = ava_ports[1][ji][3]
                                    logical_topo_traffic[t1][k1][path_hop[jj][1][0] - 1][path_hop[jj][1][1] - 1] += flow_val

                                    ava_ports[0][ij][6] -= flow_val
                                    ava_ports[1][ji][6] -= flow_val

                                    flow_cap_r[jj] -= flow_val

                                    loc = [k if ava_ports[0][n][2:6] == S_Conn_cap[k][2:6] else -1
                                           for n in range(0, len(ava_ports[0])) for k in range(0, len(S_Conn_cap))]
                                    loc1 = [k if [ava_ports[0][n][2], ava_ports[0][n][3], ava_ports[0][n][5],
                                            ava_ports[0][n][4]] == S_Conn_cap[k][2:6] else -1 for n in range(0,
                                            len(ava_ports[0])) for k in range(0, len(S_Conn_cap))]
                                    loc = [k for k in loc if k != -1]
                                    loc1 = [k for k in loc1 if k != -1]
                                    for k in range(0, len(loc1)):
                                        S_Conn_cap[loc1[k]][6] = ava_ports[0][k][6]
                                    for k in range(0, len(loc)):
                                        S_Conn_cap[loc[k]][6] = ava_ports[0][k][6]

                                    loc2 = [k if ava_ports[1][n][2:6] == S_Conn_cap[k][2:6] else -1
                                            for n in range(0, len(ava_ports[1])) for k in range(0, len(S_Conn_cap))]
                                    loc1_2 = [k if [ava_ports[1][n][2], ava_ports[1][n][3], ava_ports[1][n][5],
                                              ava_ports[1][n][4]] == S_Conn_cap[k][2:6] else -1 for n in range(0,
                                              len(ava_ports[1])) for k in range(0, len(S_Conn_cap))]
                                    loc2 = [k for k in loc2 if k != -1]
                                    loc1_2 = [k for k in loc1_2 if k != -1]
                                    for k in range(0, len(loc1_2)):
                                        S_Conn_cap[loc1_2[k]][6] = ava_ports[1][k][6]
                                    for k in range(0, len(loc2)):
                                        S_Conn_cap[loc2[k]][6] = ava_ports[1][k][6]

                                    if ava_ports[0][ij][6] <= 0:
                                        break

                                    if flow_cap_r[jj] <= 0:
                                        flag = 1
                                        break
                else:
                    for ij in range(0, ava_ports_num[0]):
                        if ava_ports[0][ij][6] > 0:
                            flow_value = min(ava_ports[0][ij][6], flow_cap_r[jj])
                            R[r].route.extend([ava_ports[0][ij][2:6], flow_value])

                            t = ava_ports[0][ij][2]
                            k = ava_ports[0][ij][3]
                            logical_topo_traffic[t][k][path_hop[0][0][0] - 1][path_hop[0][0][1] - 1] += flow_value

                            flow_cap_r[jj] -= flow_value
                            ava_ports[0][ij][6] -= flow_value

                            loc = [k if ava_ports[0][n][2:6] == S_Conn_cap[k][2:6] else -1
                                   for n in range(0, len(ava_ports[0])) for k in range(0, len(S_Conn_cap))]
                            loc1 = [k if [ava_ports[0][n][2], ava_ports[0][n][3], ava_ports[0][n][5],
                                    ava_ports[0][n][4]] == S_Conn_cap[k][2:6] else -1 for n in range(0,
                                    len(ava_ports[0])) for k in range(0, len(S_Conn_cap))]
                            loc = [k for k in loc if k != -1]
                            loc1 = [k for k in loc1 if k != -1]
                            for k in range(0, len(loc1)):
                                S_Conn_cap[loc1[k]][6] = ava_ports[0][k][6]
                            for k in range(0, len(loc)):
                                S_Conn_cap[loc[k]][6] = ava_ports[0][k][6]
                            if flow_cap_r[jj] == 0:
                                break

    return S, R, logical_topo_traffic, S_Conn_cap, port_allocation_inti_topo, port_allocation
