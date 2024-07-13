# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年07约04日
"""
import copy
import random

import numpy as np


def gener_topo(inputs, topo_index):
    """
    产生随机拓扑
    :param inputs:
    :param topo_index:
    :return:
    """
    Logical_topo_init_conn = np.zeros([inputs.nodes_num, inputs.nodes_num])
    Logical_topo_init_cap = np.zeros([inputs.nodes_num, inputs.nodes_num])
    logical_topo = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)
    logical_topo_cap = np.empty([inputs.group_num, inputs.oxc_num_a_group], dtype=object)

    for t in range(0, inputs.group_num):
        for k in range(0, inputs.oxc_num_a_group):

            logical_topo_1 = np.zeros([inputs.nodes_num, inputs.nodes_num])
            for i in range(0, inputs.nodes_num - 1):
                for j in range(i + 1, inputs.nodes_num):
                    if i != j:  # 只遍历上三角矩阵，因为逻辑拓扑都是对称矩阵
                        sum_i = np.sum(logical_topo_1, axis=0)[i]
                        sum_j = np.sum(logical_topo_1, axis=1)[j]
                        # 分别计算 node i 和 node j 的端口使用量
                        rest_cap1 = inputs.physical_conn_oxc - sum_i
                        rest_cap2 = inputs.physical_conn_oxc - sum_j
                        # 计算剩余端口数
                        rest_cap = min(rest_cap1, rest_cap2)
                        # node i 和 node j 间可以增加的最大连接数
                        if rest_cap > 0:
                            rand_i = random.randint(0, rest_cap)
                            # 随机从 0 到 rest_cap 取值
                        else:
                            rand_i = 0

                        logical_topo_1[i][j] = rand_i + 0
                        logical_topo_1[j][i] = rand_i + 0
                        # 给逻辑子拓扑 node 间连接赋值

            logical_topo[t][k] = copy.deepcopy(logical_topo_1)
            logical_topo_cap[t][k] = logical_topo[t][k] * inputs.connection_cap
            Logical_topo_init_conn += logical_topo[t][k]
            Logical_topo_init_cap += logical_topo_cap[t][k]

    if topo_index != 0:
        flow_requests = []
        for i in range(0, inputs.num_requests):
            flag = 0
            source = -1
            destination = -1
            while flag == 0:
                source = random.randint(0, inputs.nodes_num - 1)
                destination = random.randint(0, inputs.nodes_num - 1)
                if source != destination:
                    if len(flow_requests) > 0:
                        lia1 = [1 for k in range(0, len(flow_requests)) if destination == flow_requests[k][0] and
                                source == flow_requests[k][1]]
                        if len(lia1) > 0:
                            lia1 = 1
                        else:
                            lia1 = 0
                        lia2 = [1 for k in range(0, len(flow_requests)) if source == flow_requests[k][0] and
                                destination == flow_requests[k][1]]
                        if len(lia2) > 0:
                            lia2 = 1
                        else:
                            lia2 = 0
                        lia = [lia1, lia2]
                        if sum(lia) == 0:
                            flag = 1
                    else:
                        flag = 1

            update_total_bandwidth = 0
            total_bandwidth = round((inputs.group_num * inputs.oxc_ports * inputs.oxc_num_a_group *
                                     inputs.connection_cap) * inputs.cap_ratio)
            update_total_bandwidth = total_bandwidth - update_total_bandwidth
            if update_total_bandwidth > 0:
                ava_band_1hop = Logical_topo_init_cap[source][destination] + 0
                col = np.where(Logical_topo_init_conn[source])
                col = col[0]

                ava_bandwidth = 0
                for r in range(0, len(col)):
                    hop2_col1 = np.where(Logical_topo_init_conn[col[r]])[0]
                    hop2_col = np.where(hop2_col1 == destination)[0]
                    if len(hop2_col) > 0:
                        hop1_cap = Logical_topo_init_cap[source][col[r]] + 0
                        hop2_cap = Logical_topo_init_cap[col[r]][destination] + 0
                        ava_cap = min(hop1_cap, hop2_cap)
                        ava_bandwidth += ava_cap

                ava_bandwidth += ava_band_1hop
                max_val = min(ava_bandwidth, update_total_bandwidth)
                if max_val != 0:
                    require_bandwidth_band = random.randint(1, max_val)
                    update_total_bandwidth -= require_bandwidth_band
                    flow_requests.append([source + 1, destination + 1, require_bandwidth_band])

    else:
        flow_requests = []
    return Logical_topo_init_conn, Logical_topo_init_cap, logical_topo, logical_topo_cap, flow_requests
