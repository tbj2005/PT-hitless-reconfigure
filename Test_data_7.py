# -*- coding:utf-8 -*-
"""
作者：TBJ
日期：2024年06约23日
"""

# 用于仿真 5pod 场景下物理拓扑的计算和平滑重构的调度

import numpy as np
import Input_class
import distr_Traffic


inputs = Input_class.NetworkInformation()
inputs.nodes_num = 5
inputs.group_num = 2
inputs.oxc_ports = 20
inputs.oxc_num_a_group = 1
inputs.connection_cap = 1
inputs.physical_conn_oxc = 4
inputs.max_hop = 2
inputs.resi_cap = 0.65

inputs.request = [[2, 3, 2], [2, 4, 3]]
# inputs.request = [[2, 3, 3], [1, 4, 3], [2, 4, 1]] # 网络流量较满，无法疏导的情况

T = inputs.group_num
K = inputs.oxc_num_a_group

print(inputs.request)

for m in range(0, 3):
    inputs.method = m

    logical_topo = np.empty((T, K), dtype=object)
    logical_topo_cap = np.empty((T, K), dtype=object)
    logical_topo[0, 0] = np.array([[0, 1, 2, 0, 1], [1, 0, 0, 2, 1], [2, 0, 0, 1, 0], [0, 2, 1, 0, 0], [1, 1, 0, 0, 0]])
    logical_topo[1, 0] = np.array([[0, 1, 2, 0, 0], [1, 0, 1, 1, 1], [2, 1, 0, 1, 0], [0, 1, 1, 0, 1], [0, 1, 0, 1, 0]])
    logical_topo_cap[0, 0] = logical_topo[0, 0] * inputs.connection_cap
    logical_topo_cap[1, 0] = logical_topo[1, 0] * inputs.connection_cap
    Logical_topo_init_conn = logical_topo[0, 0] + logical_topo[1, 0]
    Logical_topo_init_cap = logical_topo_cap[0, 0] + logical_topo_cap[1, 0]
    Logical_topo_desi = np.array([[0, 0, 3, 0, 1], [0, 0, 3, 5, 0], [3, 3, 0, 2, 0], [0, 5, 2, 0, 1], [1, 0, 0, 1, 0]])

    distr_Traffic.distr_Traffic(Logical_topo_init_cap, inputs)
