# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06约23日
"""
# 通过初始带宽使用和输入参数，输出分别为：traffic_distr---一个元胞方阵，每一个元素的元素为一个三元组[S,D,R],表示流量的方向和带宽分配；
# flow_path---路径和资源分配，储存一跳和两跳通信的三元组[S,D,R]；break_flag---布尔值，1说明流量放不进拓扑；unavail_flow---一个表示无法放进拓扑的流量，每个元素表示一个流量三元组[S,D,超出的带宽资源]
import numpy as np
import copy


def distr_Traffic(init_topo_cap, inputs):
    """
    用于通过当前逻辑拓扑调度当前需求流量
    :param init_topo_cap: 初始逻辑拓扑带宽容量
    :param inputs: OXC和流量需求信息
    :return:
    """
    path_topo = copy.deepcopy(init_topo_cap)
    break_flag = 0
    traffic_distr = np.empty([inputs.nodes_num, inputs.nodes_num], dtype=object)
    request = inputs.request
    flow_path = np.empty(len(request), dtype=object)
    unavail_flow = []
    for r in range(0, len(request)):
        source = request[r][0] - 1
        destination = request[r][1] - 1
        flow_capacity = request[r][2]
        hop1_path = []
        hop2_path = []
        col1 = np.where(path_topo[source])
        col1 = col1[0]
        # col1 = np.nonzero(path_topo[source - 1, :])[0] + np.ones(np.count_nonzero(path_topo[source - 1, :]))
        # col1 = col1.astype(int)  # 该数组存放以需求流量源 pod 为源，可以与源直连的所有 pod
        # 寻找所有需求流量对应的一跳和两跳路径
        for ii in range(0, len(col1)):
            if col1[ii] == destination:  # 直连可以满足需求且直连剩余带宽容量足够
                hop1_path = [source, destination, path_topo[source, destination]]
            else:
                # col2 = np.nonzero(path_topo[col1[ii] - 1, :])[0] +
                # np.ones(np.count_nonzero(path_topo[col1[ii] - 1, :]))
                # col2 = col2.astype(int)  # 该数组存放以源 pod 可直连 pod ii 为中间 pod，中间 pod ii  可连接的所有其他 pod
                col2 = np.where(path_topo[col1[ii]])
                col2 = col2[0]
                col3 = np.where(col2 == destination)[0]
                Next = col1[ii]
                if len(col3) > 0:  # 如果通过中间 pod ii 可以到达目的 pod，说明两跳路径存在
                    hop2_path.append([[source, Next, path_topo[source, Next]],
                                      [Next, destination, path_topo[Next, destination]]])

        # 为流量分配路径
        flag = 0
        if hop1_path:  # 一跳链路不为空，则尽量直连
            if path_topo[source, destination] >= flow_capacity:  # 直连可以满足带宽要求
                flow_rest_cap = 0
                link_rest_cap = hop1_path[2] - flow_capacity
                path_topo[hop1_path[0], hop1_path[1]] = link_rest_cap
                path_topo[hop1_path[1], hop1_path[0]] = link_rest_cap
                flow_path[r] = [[hop1_path[0], hop1_path[1], flow_capacity]]
            else:  # 直连带宽不足，但是还是要用完所有直连带宽
                flow_path[r] = [[hop1_path[0], hop1_path[1], hop1_path[2]]]
                link_rest_cap = 0
                path_topo[hop1_path[0], hop1_path[1]] = link_rest_cap
                path_topo[hop1_path[1], hop1_path[0]] = link_rest_cap
                flow_rest_cap = flow_capacity - hop1_path[2]
                flag = 1
        else:  # 一开始就没有直连链路
            flag = 1
            flow_path[r] = []
            flow_rest_cap = flow_capacity

        if flag == 1:  # 直连带宽用完之后如果还没有满足流量需求
            used_path = copy.deepcopy(hop2_path)
            for i in range(0, len(hop2_path)):
                link_rest_cap1 = path_topo[hop2_path[i][0][0], hop2_path[i][0][1]]
                link_rest_cap2 = path_topo[hop2_path[i][1][0], hop2_path[i][1][1]]
                min_path_cap = min(link_rest_cap1, link_rest_cap2)
                if min_path_cap >= flow_rest_cap:  # 该两跳路径上的带宽容量可以满足剩余需求
                    used_path[i][0][2] = flow_rest_cap
                    used_path[i][1][2] = flow_rest_cap
                    flow_path[r] += used_path[i]

                    path_topo[hop2_path[i][0][0], hop2_path[i][0][1]] -= flow_rest_cap
                    path_topo[hop2_path[i][0][1], hop2_path[i][0][0]] -= flow_rest_cap
                    path_topo[hop2_path[i][1][0], hop2_path[i][1][1]] -= flow_rest_cap
                    path_topo[hop2_path[i][1][1], hop2_path[i][1][0]] -= flow_rest_cap
                    # 更新剩余带宽资源
                    flow_rest_cap = 0
                    break
                else:  # 两跳路径上的带宽容量无法满足剩余容量
                    used_path[i][0][2] = min_path_cap
                    used_path[i][1][2] = min_path_cap
                    flow_rest_cap -= min_path_cap
                    path_topo[hop2_path[i][0][0], hop2_path[i][0][1]] = max(0, (
                            path_topo[hop2_path[i][0][0], hop2_path[i][0][1]] - min_path_cap))
                    path_topo[hop2_path[i][0][1], hop2_path[i][0][0]] = max(0, (
                            path_topo[hop2_path[i][0][1], hop2_path[i][0][0]] - min_path_cap))
                    path_topo[hop2_path[i][1][0], hop2_path[i][1][1]] = max(0, (
                            path_topo[hop2_path[i][1][0], hop2_path[i][1][1]] - min_path_cap))
                    path_topo[hop2_path[i][1][1], hop2_path[i][1][0]] = max(0, (
                            path_topo[hop2_path[i][1][1], hop2_path[i][1][0]] - min_path_cap))
                    # 更新剩余带宽资源
                    flow_path[r] += used_path[i]

        # 若流量不满足要求，标记之
        if flow_rest_cap > 0:
            break_flag = 1
            unavail_flow.append([request[r][0], request[r][1], flow_rest_cap])
            # 存储流量溢出部分
        else:
            # 若流量满足要求，更新 traffic_distr 矩阵，矩阵中每个元素的位置表示流量位于哪两个 pod 间
            # 元素为一个元胞数组，数组中的每个元素都为一个三元组[S,D,R]，表示这条流的源和目的 pod 与带宽分配
            # 因为网络中存在两跳转发，位于两个 pod 间的流，其源 pod 和目的 pod 可能把并不是这两个 pod
            for j in range(0, len(flow_path[r])):
                if traffic_distr[flow_path[r][j][0], flow_path[r][j][1]]:
                    traffic_distr[flow_path[r][j][0], flow_path[r][j][1]] = (
                        traffic_distr[flow_path[r][j][0], flow_path[r][j][1]], [source, destination,
                                                                                flow_path[r][j][2]])
                    traffic_distr[flow_path[r][j][0], flow_path[r][j][1]] = list(
                        traffic_distr[flow_path[r][j][0], flow_path[r][j][1]])
                else:
                    traffic_distr[flow_path[r][j][0], flow_path[r][j][1]] = (
                        [source, destination, flow_path[r][j][2]])

    return traffic_distr, flow_path, break_flag, unavail_flow
