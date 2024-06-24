# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06约23日
"""
# 转化输入参数，以与后续平滑重构契合
import numpy as np
import random


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
    G = G.astype(int)  # pod 与 oxc 的连接数目

    if remain != 0:  # 如果端口并不能完全平均分配，需要随机放端口
        for i in range(0, T):
            for j in range(0, K):  # 遍历了所有的 oxc
                Rand = random.choices([t for t in range(0, Omega)], k=remain)  # 把每个 oxc 多出来的端口随机放给所有 pod
                for k in range(0, remain):
                    G[Rand[k], j, i] += 1

    port_allocation = np.empty([T, 1], dtype=object)

    for i in range(0, T):
        for j in range(0, K):
            p = 0
            for k in range(0, Omega):
                for n in range(p, p + G[k, j, i]):
                    port_allocation[i, 0][j, 0][0, n] = k
                    port_allocation[i, 0][j, 0][1, n] = 0
                p += G[k, j, i]

    print(port_allocation)
